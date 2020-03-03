variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-west-1"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "1"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "1"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}

variable "service_desired" {
  description = "Desired numbers of instances in the ecs service"
  default     = "1"
}

variable "image" {
  description = "Docker image to run in Fargate"
  default     = "scottbrenner/hqtrackbot:latest"
}

variable "environment" {
  description = "Environment variables for container"
  default     = ""
}