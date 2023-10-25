variable "environment" {
  description = "The name of the environment."
  type        = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}


variable "crowd_strike_cid" {
  type        = string
  description = "Customer ID for crowdstrike falcon sensor"
  default     = ""
}

variable "vpc" {
  description = "VPC name alias value."
  default     = "benefitexpress-wex-lnk"
  type        = string
}

locals {
  container_ingester_environment = [
    {
      "name" : "Environment",
      "value" : var.environment
    },
    {
      "value" : var.region,
      "name" : "Region"
    }    
  ]

  container_mapper_environment = [
    {
      "name" : "Environment",
      "value" : var.environment
    },
    {
      "value" : var.region,
      "name" : "Region"
    }
  ]


  iam_role_arn      = aws_iam_role.hulk_healthcommunication_task_execution-role.arn
  container_cluster = aws_ecs_cluster.hulk_healthcommunication-cluster.id
}
