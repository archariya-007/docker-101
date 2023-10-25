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

variable "carriernotification_sg"{
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

variable "health_communication_container_cpu_unit" {
  type = number
  default = 256
}
variable "health_communication_container_memory" {
  type = number
  default = 1024
}
variable "container_dll" {
  type = string
  default = ""
}

variable "account_id" {
  description = "Account id"
  default     = "123456789012"
  type        = string
}

variable "datadog_api_key" {
  description = "datadogs api key"
  type = string
}

variable "datadog_version" {
  description = "datadog integration version"
  default = "1.091323"
  type = string
}

variable "datadog_service_name" {
	description = "the service name"
	default = ""
	type = string
}