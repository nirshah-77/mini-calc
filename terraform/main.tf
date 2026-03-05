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

# ─────────────────────────────────────────────────────────────────
# User-data: Chef installs Docker, pulls image, runs container
# Workflow: GitHub → Docker Hub → Terraform EC2 → Chef → Container
# ─────────────────────────────────────────────────────────────────
locals {
  chef_userdata = <<-EOF
    #!/bin/bash
    exec > /var/log/chef-bootstrap.log 2>&1
    set -ex

    # ── 1. Prerequisites ─────────────────────────────────────────
    apt-get update -y
    apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release

    # ── 2. Add Docker CE apt repository ──────────────────────────
    mkdir -p /usr/share/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y

    # ── 3. Install Chef via omnitruck (pre-built binary ~60s) ────
    curl -L https://omnitruck.chef.io/install.sh | bash

    # ── 4. Write Chef cookbook inline — no git clone needed ───────
    mkdir -p /var/chef/cookbooks/k8s_setup/recipes

    cat > /var/chef/cookbooks/k8s_setup/metadata.rb <<'METADATA'
name 'k8s_setup'
version '1.0.0'
chef_version '>= 16'
METADATA

    # Recipe: install Docker, pull image, run container
    cat > /var/chef/cookbooks/k8s_setup/recipes/default.rb <<'RECIPE'
# Step 1 — Install Docker CE
%w[docker-ce docker-ce-cli containerd.io].each { |pkg| package pkg }

# Step 2 — Enable Docker service
service 'docker' do
  action [:enable, :start]
end

# Step 3 — Pull the application image from Docker Hub
execute 'pull_sqrt_image' do
  command 'docker pull nirshah77/sqrt-app:latest'
end

# Step 4 — Run the container (idempotent: skips if already running)
execute 'run_sqrt_container' do
  command 'docker run -d --name sqrt-app --restart unless-stopped nirshah77/sqrt-app:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^sqrt-app$"'
end
RECIPE

    cat > /tmp/solo.rb <<'SOLORB'
cookbook_path ["/var/chef/cookbooks"]
SOLORB

    cat > /tmp/node.json <<'NODEJSON'
{"run_list":["recipe[k8s_setup]"]}
NODEJSON

    # ── 5. Run Chef → installs Docker, pulls image, runs container ─
    chef-solo -c /tmp/solo.rb -j /tmp/node.json

    # Signal file: pipeline waits on this to confirm bootstrap done
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
  user_data              = local.chef_userdata

  tags = {
    Name = "docker-app-server-1"
  }
}

# ──────────────────────────────────────────────
# EC2 — Docker App Server 2
# ──────────────────────────────────────────────
resource "aws_instance" "k8s_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  user_data              = local.chef_userdata

  tags = {
    Name = "docker-app-server-2"
  }
}