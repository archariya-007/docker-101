########################################################################
# Repositories
########################################################################
resource "aws_ecr_repository" "crowdstrike-repo" {
  name                 = "crowdstrike_falcon_sensor-repo-tf"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}