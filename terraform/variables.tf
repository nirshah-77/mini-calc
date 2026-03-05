variable "region" {
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (t2.medium recommended for Kubernetes)"
  default     = "t2.medium"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access (set via TF_VAR_key_name)"
}

variable "s3_bucket" {
  description = "Name of the S3 bucket used to store the Terraform remote state (set via TF_VAR_s3_bucket)"
}

variable "github_owner" {
  description = "GitHub username / org that owns the repository"
}

variable "github_repo" {
  description = "GitHub repository name (e.g. mini-calc)"
  default     = "mini-calc"
}