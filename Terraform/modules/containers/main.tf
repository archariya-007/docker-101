########################################################################
# Repositories and tasks
########################################################################
resource "aws_ecr_repository" "healthcommunication-repo" {
  name                 = "healthcommunication_${var.container_name}-repo-tf"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "health-communication-task-logs" {
  name              = "healthcommunication_${var.container_name}-task-logs-tf"
  retention_in_days = 90
}

resource "aws_ecs_task_definition" "health-communication-task" {
  family = "healthcommunication_${var.container_name}-task-tf"
  container_definitions = jsonencode(
      [
         {
            name: "health-communication-agent",
            image:  "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/health-communication-repo-tf:latest",
            cpu: 10,
            memory: 256,
            essential: false,
            dockerLabels: {
                "com.datadoghq.tags.env": "${var.environment == "dv" ? "dev" : var.environment}",
                "com.datadoghq.tags.service": "${var.datadog_service_name}",
                "com.datadoghq.tags.version": "${var.datadog_version}"
            },
            environment: [
                {
                    "name": "DD_API_KEY",
                    "value": "${var.datadog_api_key}"
                },
                {
                    "name": "ECS_FARGATE",
                    "value": "true"
                },
                {
                    "name": "DD_SITE",
                    "value": "datadoghq.com"
                },
                {
                    "name": "DD_APM_ENABLED",
                    "value": "true"
                },
                {
                    "name": "DD_PROCESS_AGENT_ENABLED",
                    "value": "true"
                },
                {
                    "name": "DD_DOGSTATSD_NON_LOCAL_TRAFFIC",
                    "value": "true"
                },
                {
                    "name": "DD_ENV",
                    "value": "${var.environment == "dv" ? "dev" : var.environment}"
                },
                {
                    "name": "DD_SERVICE",
                    "value": "${var.datadog_service_name}"
                },
                {
                    "name": "DD_VERSION",
                    "value": "${var.datadog_version}"
                }
            ]
         },
         {
            name : "healthcommunication_${var.container_name}-task-tf",
            image: "${aws_ecr_repository.healthcommunication-repo.repository_url}:latest",
            essential: true,
            memory: tonumber("${var.health_communication_container_memory}") - 256,
            cpu: tonumber("${var.health_communication_container_cpu_unit}") - 10,
            environment : "${var.container_environment}",
            logConfiguration : {
               "logDriver" : "awslogs",
               "options" : {
               "awslogs-group" : "${aws_cloudwatch_log_group.health-communication-task-logs.name}",
               "awslogs-region" : "${var.region}",
               "awslogs-stream-prefix" : "ecs"
               }
            },
            dependsOn : [
               {
                  "condition": "COMPLETE",
                  "containerName": "crowdstrike-falcon-init-container"
               }
            ],
            entryPoint : [
               "/tmp/CrowdStrike/rootfs/lib64/ld-linux-x86-64.so.2",
               "--library-path",
               "/tmp/CrowdStrike/rootfs/lib64",
               "/tmp/CrowdStrike/rootfs/bin/bash",
               "/tmp/CrowdStrike/rootfs/entrypoint-ecs.sh",
               "dotnet",
               "${var.container_dll}"
            ],
            linuxParameters : {
               "capabilities": {
                  "add": [
                     "SYS_PTRACE"
                  ]
               }
            },
            mountPoints : [
               {
                  "sourceVolume": "crowdstrike-falcon-volume-${var.container_name}",
                  "containerPath": "/tmp/CrowdStrike",
                  "readOnly": true                  
               },
               {
                  "sourceVolume": "crowdstrike-healthcommunication-volume-${var.container_name}",
                  "containerPath": "/tmp/CrowdStrike-private",
                  "readOnly": false
               }
            ],
            "portMappings": [],
            "volumesFrom": []
         },
         {
            name : "crowdstrike-falcon-init-container",
            image : "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/crowdstrike_falcon_sensor-repo-tf:latest",
            user : "0:0",
            essential : false,
            logConfiguration : {
               "logDriver" : "awslogs",
               "options" : {
               "awslogs-group" : "${aws_cloudwatch_log_group.health-communication-task-logs.name}",
               "awslogs-region" : "${var.region}",
               "awslogs-stream-prefix" : "falcon"
               }
            },
            entryPoint : [
               "/bin/bash",
               "-c",
               "chmod u+rwx /tmp/CrowdStrike && mkdir /tmp/CrowdStrike/rootfs && cp -r /bin /etc /lib64 /usr /entrypoint-ecs.sh /tmp/CrowdStrike/rootfs && chmod -R a=rX /tmp/CrowdStrike && chmod -R a=rwX /tmp/CrowdStrike-private-healthcommunication_${var.container_name}-task-tf"
            ],
            mountPoints : [
               {
                  "sourceVolume": "crowdstrike-falcon-volume-${var.container_name}",
                  "containerPath": "/tmp/CrowdStrike",
                  "readOnly": false
               },
               {
                  "sourceVolume": "crowdstrike-healthcommunication-volume-${var.container_name}",
                  "containerPath": "/tmp/CrowdStrike-private-healthcommunication_${var.container_name}-task-tf",
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
  memory             = tonumber("${var.health_communication_container_memory}")
  cpu                = tonumber("${var.health_communication_container_cpu_unit}")
  execution_role_arn = var.iam_role_arn
  task_role_arn      = var.iam_role_arn
  volume {
      name = "crowdstrike-falcon-volume-${var.container_name}"
      efs_volume_configuration {
         file_system_id = aws_efs_file_system.crowdstrike-falcon-volume.id
      }
   }
   volume {
      name = "crowdstrike-healthcommunication-volume-${var.container_name}"
      efs_volume_configuration {
         file_system_id = aws_efs_file_system.crowdstrike-healthcommunication-volume.id
      }
   }
}

########################################################################
# Service
########################################################################
resource "aws_ecs_service" "healthcommunication-service" {
  name            = "healthcommunication_${var.container_name}-service-tf"
  cluster         = var.container_cluster
  task_definition = aws_ecs_task_definition.health-communication-task.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  tags = {
    env = "${var.environment == "dv" ? "dev" : var.environment}"
    service = "${var.datadog_service_name}"
    version = "${var.datadog_version}"
  }
  network_configuration {
    subnets         = var.container_subnets_ids
    security_groups = [var.healthcommunication_sg.id]
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
  security_groups = [var.healthcommunication_sg.id]
}

resource "aws_efs_mount_target" "crowdstrike-healthcommunication-mount-target" {
  count = length(var.container_subnets_ids)
  file_system_id = aws_efs_file_system.crowdstrike-healthcommunication-volume.id
  subnet_id      = var.container_subnets_ids[count.index]
  security_groups = [var.healthcommunication_sg.id]
}

resource "time_sleep" "wait-30s" {
  depends_on = [
    aws_efs_mount_target.crowdstrike-falcon-mount-target,
    aws_efs_mount_target.crowdstrike-healthcommunication-mount-target
  ]

  create_duration = "30s"
}