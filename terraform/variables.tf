variable "region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
  default     = "us-west-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "The CIDR block for the subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "key_name" {
  description = "Name of the SSH key pair to access the instances"
  type        = string
  default     = "my-aws-key"  # Replace with your actual key pair name
}

variable "instance_type" {
  description = "Type of EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "management_ip" {
  description = "Your IP address for RDP access to the instances"
  type        = string
  default     = "0.0.0.0/0"  # Replace with your actual IP (e.g., "203.0.113.0/32")
}

variable "cloud_shell_source" {
  description = "Source IP for CloudShell access"
  type        = string
  default     = "0.0.0.0/0"  # Replace with a more restrictive IP or range if needed
}

