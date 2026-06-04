variable "project_name" {
  description = "streaming platform name"
  type        = string
}

variable "environment" {
  description = "working environment"
  type        = string
}

variable "vpc_id" {
  description = "streaming platform vpc id"
  type        = string
}

variable "public_subnet_ids" {
  description = "public subnets"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "application load balancer security group"
  type        = string
}