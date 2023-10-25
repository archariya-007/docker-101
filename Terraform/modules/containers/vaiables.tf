variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  description = "The name of the environment."
  type        = string
}

variable "container_name"{
  type = string
}

variable "hulk-healthcommunication_sg"{
  type  = any
}

variable "container_subnets_ids"{
  type = list(string)
}

variable "container_environment" {
  type = any
  default = ""
}

variable "iam_role_arn" {
  type        = string
  description = "Variable to pass iam roles to container builds"
  default     = ""
}

variable "container_cluster"{
  type = string
  description = "Variable to pass cluster configurations to container builds"
  default = ""
}

variable "hulk_health_communication_container_cpu_unit" {
  type = number
  default = 256
}
variable "hulk_health_communication_container_memory" {
  type = number
  default = 1024
}
variable "container_dll" {
  type = string
  default = ""
}

variable "account_id" {
  description = "Account id"
  type        = string
}