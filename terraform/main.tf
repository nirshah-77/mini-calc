# ──────────────────────────────────────────────
# Remote backend: S3 stores Terraform state
# ──────────────────────────────────────────────
terraform {
  backend "s3" {
    # bucket is passed at init time via:
    #   terraform init -backend-config="bucket=$TF_VAR_S3_BUCKET"
    # Variables are NOT allowed directly in backend blocks.
    key    = "mini-calc/terraform.tfstate"
    region = "us-east-1"
  }
}

# ──────────────────────────────────────────────
# Provider
# ──────────────────────────────────────────────
provider "aws" {
  region = var.region
}

# ──────────────────────────────────────────────
# Auto-fetch latest Ubuntu 22.04 LTS AMI
# (no need to hardcode or store as a secret)
# ──────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical official account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ──────────────────────────────────────────────
# Security Group
# ──────────────────────────────────────────────
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  description = "Allow SSH, Kubernetes API, and NodePort traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort Service"
    from_port   = 30007
    to_port     = 30007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Kubelet & internal cluster traffic"
    from_port   = 10250
    to_port     = 10260
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-sg"
  }
}

# ──────────────────────────────────────────────
# User-data: install Chef + Docker + K8s inline
# No git clone needed — cookbook embedded here
# ──────────────────────────────────────────────
locals {
  # ── shared bootstrap steps (repos + Chef + packages) ───────────
  common_bootstrap = <<-COMMON
    #!/bin/bash
    exec > /var/log/chef-bootstrap.log 2>&1
    set -ex

    # ── 1. Disable swap (Kubernetes requirement) ─────────────────
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab

    # ── 2. Kernel modules ────────────────────────────────────────
    modprobe overlay
    modprobe br_netfilter
    printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf
    printf 'net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1\n' > /etc/sysctl.d/k8s.conf
    sysctl --system

    # ── 3. Package prerequisites ─────────────────────────────────
    apt-get update -y
    apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release

    # ── 4. Docker repository ─────────────────────────────────────
    mkdir -p /usr/share/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    # ── 5. Kubernetes repository ─────────────────────────────────
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list

    apt-get update -y

    # ── 6. Install Chef (pre-built binary, ~60s — NOT gem install) ─
    curl -L https://omnitruck.chef.io/install.sh | bash

    # ── 7. Write Chef cookbook inline (NO git clone needed) ───────
    mkdir -p /var/chef/cookbooks/k8s_setup/recipes

    cat > /var/chef/cookbooks/k8s_setup/metadata.rb <<'METADATA'
name 'k8s_setup'
version '1.0.0'
chef_version '>= 16'
METADATA

    cat > /var/chef/cookbooks/k8s_setup/recipes/default.rb <<'RECIPE'
# Install Docker CE and Kubernetes packages
%w[
  docker-ce docker-ce-cli containerd.io
  kubelet kubeadm kubectl
].each { |pkg| package pkg }

# Enable and start services
service('docker')   { action [:enable, :start] }
service('kubelet')  { action [:enable, :start] }
RECIPE

    cat > /tmp/solo.rb <<'SOLORB'
cookbook_path ["/var/chef/cookbooks"]
SOLORB

    cat > /tmp/node.json <<'NODEJSON'
{"run_list":["recipe[k8s_setup]"]}
NODEJSON

    # ── 8. Run Chef-solo ─────────────────────────────────────────
    chef-solo -c /tmp/solo.rb -j /tmp/node.json

    # ── 9. Configure containerd with systemd cgroup driver ───────
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl restart kubelet
  COMMON

  chef_master_userdata = <<-EOF
    ${local.common_bootstrap}

    # ── MASTER ONLY: initialise the Kubernetes cluster ───────────
    kubeadm init --pod-network-cidr=10.244.0.0/16

    # Set up kubeconfig for ubuntu user
    mkdir -p /home/ubuntu/.kube
    cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Apply Flannel CNI overlay network
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

    # Remove control-plane taint so pods can schedule on master
    # (enables single-node cluster — worker is additional capacity)
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

    # Save join command so worker can use it
    kubeadm token create --print-join-command > /home/ubuntu/join_command.sh
    chmod +x /home/ubuntu/join_command.sh

    # Signal: bootstrap complete
    touch /tmp/chef_done
  EOF

  chef_worker_userdata = <<-EOF
    ${local.common_bootstrap}

    # Worker node: packages are installed by Chef above.
    # The actual `kubeadm join` is run by the pipeline after
    # it retrieves the join command from the master node.
    touch /tmp/chef_done
  EOF
}


# ──────────────────────────────────────────────
# EC2 — Kubernetes Master node
# ──────────────────────────────────────────────
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  user_data              = local.chef_master_userdata

  tags = {
    Name = "calc-k8s-master"
  }
}

# ──────────────────────────────────────────────
# EC2 — Kubernetes Worker node
# ──────────────────────────────────────────────
resource "aws_instance" "k8s_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  user_data              = local.chef_worker_userdata

  tags = {
    Name = "calc-k8s-worker"
  }
}