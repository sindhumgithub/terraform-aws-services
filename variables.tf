variable "project_name" {
  type        = string
}

variable "environment" {
  type        = string
}

variable "instance_type" {
  type        = string
}

variable "service_name" {
  type = string
}

variable "ssh_user" {
  type        = string
}

variable "ssh_password" {
  type        = string
}

variable "health_check_interval" {
  type        = number
}


variable "priority" {
  type = number
}

variable "domain_name" {
  type = string
}