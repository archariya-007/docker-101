terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.29.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 1.2.2"
  backend "s3" {
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project = "Mecury"
      owner   = "Connect Squad"
      appid   = "Murcury_HealthCommunicationProcessor"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

################################################################################
# Cluster
################################################################################

resource "aws_ecs_cluster" "hulk-health-communication-cluster" {
  name = "hulk-health-communication-cluster-tf"
}

data "aws_iam_policy_document" "ecstaskexecution_assume_role-policy-document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

################################################################################
# Roles
################################################################################

resource "aws_iam_role" "hulk-health-communication_task_execution-role" {
  name               = "hulk_health_communication_task_execution-role-tf"
  assume_role_policy = data.aws_iam_policy_document.ecstaskexecution_assume_role-policy-document.json
}

resource "aws_iam_role_policy_attachment" "hulk-health-communication_task-role-policy" {
  role       = aws_iam_role.hulk_health_communication_task_execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# Secrets
################################################################################
# TODO


################################################################################
# VPC
################################################################################

data "aws_vpc" "vpc_data" {
  filter {
    name   = "tag:namealias"
    values = ["${var.vpc}"]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "tag:private"
    values = ["yes"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_data.id]
  }
}

data "aws_subnet" "private_selected_subnets" {
  for_each = toset(data.aws_subnets.private_subnets.ids)
  id       = each.value
}

output "container_subnets_ids" {
  value = [for subnet in data.aws_subnet.private_selected_subnets : subnet.id]
}

resource "aws_security_group" "hulk-health-communication_sg" {
  name        = "hulk_health_communication_sg-tf"
  description = "Allow all outbound traffic to communicate with RDS postgres, SMTP Server"
  vpc_id      = data.aws_vpc.vpc_data.id
  egress = [
    {
      description      = "Allow all outbound traffic to communicate with RDS postgres, SMTP Server"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    }
  ]
  ingress = [
    {
      description      = "Allow all inbound traffic for Crowdstrike"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    }
  ]
  tags = {
    Name = "hulk-health-communication-sg-tf"
  }
}

################################################################################
# Container Modules
################################################################################

module "containers_ingester" {
  source                                  = "./modules/containers"
  container_name                          = "ingester"
  region                                  = var.region
  hulk-health-communication_sg            = aws_security_group.hulk_healthcommunication_sg
  container_subnets_ids                   = data.aws_subnets.private_subnets.ids
  iam_role_arn                            = local.iam_role_arn
  container_environment                   = local.container_ingester_environment
  container_cluster                       = local.container_cluster
  hulk_health_communication_container_cpu_unit = var.hulk_health_communication_container_cpu_unit_ingester
  hulk_health_communication_container_memory   = var.hulk_health_communication_container_memory_ingester
  environment                             = var.environment
  container_dll                           = "mbe.hulk-health-communication-ingester.dll"
  account_id                              = var.account_id
}

module "crowdstrike_falcon_sensor" {
  source                                  = "./modules/crowdstrike"
  repository_name                         = "crowdstrike_falcon_sensor"
}
