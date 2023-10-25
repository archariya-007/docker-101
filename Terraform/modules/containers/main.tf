data "aws_caller_identity" "current" {}

########################################################################
# Repositories and tasks
########################################################################
resource "aws_ecr_repository" "healthcommunication-repo" {
  name                 = "hulk_healthcommunication_${var.container_name}-repo-tf"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "hulk-health-communication-task-logs" {
  name              = "hulk_healthcommunication_${var.container_name}-task-logs-tf"
  retention_in_days = 90
}
########################################################################
# ECS Task Definition
########################################################################
resource "aws_ecs_task_definition" "health-communication-task" {
  family = "hulk_healthcommunication_${var.container_name}-task-tf"
  container_definitions = jsonencode(
      [
         {
            name: "health-communication-agent",
            image:  "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/hulk-health-communication-repo-tf:latest",
            cpu: 10,
            memory: 256,
            essential: true,
            environment: [
               {
                  "name": "aws_account_id",
                  "value": "${data.aws_caller_identity.current.account_id}"
               },
               {
                  "name": "aws_region",
                  "value": "${data.aws_region.current.name}"
               }
            ]
         },
         {
            name : "hulk_healthcommunication_${var.container_name}-task-tf",
            image: "${aws_ecr_repository.healthcommunication-repo.repository_url}:latest",
            essential: true,
            memory: tonumber("${var.hulk_health_communication_container_memory}") - 256,
            cpu: tonumber("${var.hulk_health_communication_container_cpu_unit}") - 10,
            environment : "${var.container_environment}",
            logConfiguration : {
               "logDriver" : "awslogs",
               "options" : {
               "awslogs-group" : "${aws_cloudwatch_log_group.hulk-health-communication-task-logs.name}",
               "awslogs-region" : "${var.region}",
               "awslogs-stream-prefix" : "ecs"
               }
            }
         },
         {
            name : "hulk-crowdstrike-falcon-init-container",
            image : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/hulk_crowdstrike_falcon_sensor-repo-tf:latest",
            user : "0:0",
            essential : false,
            logConfiguration : {
               "logDriver" : "awslogs",
               "options" : {
               "awslogs-group" : "${aws_cloudwatch_log_group.hulk-health-communication-task-logs.name}",
               "awslogs-region" : "${var.region}",
               "awslogs-stream-prefix" : "falcon"
               }
            },
            entryPoint : [
               "/bin/bash",
               "-c",
               "chmod u+rwx /tmp/CrowdStrike && mkdir /tmp/CrowdStrike/rootfs && cp -r /bin /etc /lib64 /usr /entrypoint-ecs.sh /tmp/CrowdStrike/rootfs && chmod -R a=rX /tmp/CrowdStrike && chmod -R a=rwX /tmp/CrowdStrike-private-hulk-healthcommunication_${var.container_name}-task-tf"
            ],
            mountPoints : [
               {
                  "sourceVolume": "hulk-crowdstrike-falcon-volume-${var.container_name}",
                  "containerPath": "/tmp/CrowdStrike",
                  "readOnly": false
               },
               {
                  "sourceVolume": "hulk-crowdstrike-healthcommunication-volume-${var.container_name}",
                  "containerPath": "/tmp/CrowdStrike-private-hulk-healthcommunication_${var.container_name}-task-tf",
                  "readOnly": false
               }
            ]
         }
      ]
   )
  
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
  }
  memory             = tonumber("${var.hulk_health_communication_container_memory}")
  cpu                = tonumber("${var.hulk_health_communication_container_cpu_unit}")
  execution_role_arn = var.iam_role_arn
  task_role_arn      = var.iam_role_arn
  volume {
      name = "hulk-crowdstrike-falcon-volume-${var.container_name}"
      efs_volume_configuration {
         file_system_id = aws_efs_file_system.crowdstrike-falcon-volume.id
      }
   }
   volume {
      name = "hulk-crowdstrike-healthcommunication-volume-${var.container_name}"
      efs_volume_configuration {
         file_system_id = aws_efs_file_system.crowdstrike-healthcommunication-volume.id
      }
   }
}

########################################################################
# Service
########################################################################
resource "aws_ecs_service" "healthcommunication-service" {
  name            = "hulk_healthcommunication_${var.container_name}-service-tf"
  cluster         = var.container_cluster
  task_definition = aws_ecs_task_definition.health-communication-task.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  tags = {
    env = "${var.environment == "dv" ? "dev" : var.environment}"
    service = "hulk-test-poc"
    version = "100.0.0.1"
  }
  network_configuration {
    subnets         = var.container_subnets_ids
    security_groups = [var.hulk_healthcommunication_sg.id]
  }
}

#######################################################################
# Volumes - Used by CrowdStrike Falcon Sensor Delivery
#######################################################################
resource "aws_efs_file_system" "crowdstrike-falcon-volume" {
  creation_token = "crowdstrike-falcon-volume-${var.container_name}"
  tags = {
    Name = "crowdstrike-falcon-volume-${var.container_name}"
  } 
}

resource "aws_efs_file_system" "crowdstrike-healthcommunication-volume" {
  creation_token = "crowdstrike-healthcommunication-volume-${var.container_name}"
  tags = {
    Name = "crowdstrike-healthcommunication-volume-${var.container_name}"
  }
}

########################################################################
# Mount Targets - This is the connection from the imgages to the volumes above (must be on same vpc and subnet)
########################################################################
resource "aws_efs_mount_target" "crowdstrike-falcon-mount-target" {
  count = length(var.container_subnets_ids)
  file_system_id = aws_efs_file_system.crowdstrike-falcon-volume.id
  subnet_id      = var.container_subnets_ids[count.index]
  security_groups = [var.hulk_healthcommunication_sg.id]
}

resource "aws_efs_mount_target" "crowdstrike-healthcommunication-mount-target" {
  count = length(var.container_subnets_ids)
  file_system_id = aws_efs_file_system.crowdstrike-healthcommunication-volume.id
  subnet_id      = var.container_subnets_ids[count.index]
  security_groups = [var.hulk_healthcommunication_sg.id]
}

resource "time_sleep" "wait-30s" {
  depends_on = [
    aws_efs_mount_target.crowdstrike-falcon-mount-target,
    aws_efs_mount_target.crowdstrike-healthcommunication-mount-target
  ]

  create_duration = "30s"
}