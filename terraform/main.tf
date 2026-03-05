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
# User-data shared logic: install chef-solo,
# clone the repo, run the k8s_setup cookbook
# ──────────────────────────────────────────────
locals {
  chef_master_userdata = <<-EOF
    #!/bin/bash
    exec > /var/log/chef-bootstrap.log 2>&1
    set -e

    apt-get update -y
    apt-get install -y curl git

    # Install Chef via omnitruck (pre-built binary — ~60 sec vs 15 min for gem install)
    curl -L https://omnitruck.chef.io/install.sh | bash

    # Clone the repo so chef-solo can find the cookbook
    git clone https://github.com/${var.github_owner}/${var.github_repo}.git /opt/mini-calc

    cat > /tmp/solo.rb <<SOLORB
node_name "master"
cookbook_path "/opt/mini-calc/chef/cookbooks"
SOLORB

    cat > /tmp/node.json <<JSON
{
  "k8s_setup": { "role": "master" },
  "run_list": ["recipe[k8s_setup]"]
}
JSON

    chef-solo -c /tmp/solo.rb -j /tmp/node.json

    # Signal file: pipeline waits for this
    touch /tmp/chef_done
  EOF

  chef_worker_userdata = <<-EOF
    #!/bin/bash
    exec > /var/log/chef-bootstrap.log 2>&1
    set -e

    apt-get update -y
    apt-get install -y curl git

    curl -L https://omnitruck.chef.io/install.sh | bash

    git clone https://github.com/${var.github_owner}/${var.github_repo}.git /opt/mini-calc

    cat > /tmp/solo.rb <<SOLORB
node_name "worker"
cookbook_path "/opt/mini-calc/chef/cookbooks"
SOLORB

    cat > /tmp/node.json <<JSON
{
  "k8s_setup": { "role": "worker" },
  "run_list": ["recipe[k8s_setup]"]
}
JSON

    chef-solo -c /tmp/solo.rb -j /tmp/node.json
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