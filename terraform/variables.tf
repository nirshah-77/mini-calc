variable "region" {
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (t2.medium recommended for Kubernetes)"
  default     = "t2.medium"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access (set via TF_VAR_key_name or GitHub secret)"
}
