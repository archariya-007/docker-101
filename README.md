docker build -t <tag name> .

pre_build : login to ECR
aws ecr get-login-password --region us-east-1 --no-verify-ssl| docker login

build : build image 
post_build : push to ECR
docker push 028954361857.dkr.ecr.us-east-1.amazonaws.com/hulk_repository:latest

