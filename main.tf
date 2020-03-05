# Specify the provider and access details
provider "aws" {
  region = var.aws_region
}

# Create & use S3 remote state

terraform {
  backend "s3" {
    bucket  = "scottbrenner-tf-state-bucket"
    key     = "hqtrackbot/terraform.tfstate"
    region  = "us-west-1"
    encrypt = true
  }
}

## Fargate

### Network

data "aws_availability_zones" "available" {}

resource "aws_vpc" "hqtrackbot-vpc" {
  cidr_block = "10.10.0.0/16"
}

# Create var.az_count public subnets
resource "aws_subnet" "hqtrackbot-public-subnet" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.hqtrackbot-vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.hqtrackbot-vpc.id
  map_public_ip_on_launch = true
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "hqtrackbot-gateway" {
  vpc_id = aws_vpc.hqtrackbot-vpc.id
}

# Route the public subnet traffic through the IGW
resource "aws_route" "hqtrackbot-route" {
  route_table_id         = aws_vpc.hqtrackbot-vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hqtrackbot-gateway.id
}

### Compute

resource "aws_appautoscaling_target" "hqtrackbot-appautoscaling-target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.hqtrackbot-ecs-cluster.name}/${aws_ecs_service.hqtrackbot-ecs-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

### Security

resource "aws_security_group" "hqtrackbot-ecs-security-group" {
  description = "controls access to the application"

  vpc_id = aws_vpc.hqtrackbot-vpc.id
  name   = "hqtrackbot-ecs-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

## ECS

resource "aws_ecs_cluster" "hqtrackbot-ecs-cluster" {
  name = "hqtrackbot_ecs_cluster"
}

data "template_file" "hqtrackbot-task-definition-file" {
  template = file("./task-definition.json")

  vars = {
    image              = var.image
    execution_role_arn = aws_iam_role.hqtrackbot-ecs-service-iam-role.arn
    environment        = var.environment
    container_name     = "hqtrackbot-tf"
    cpu                = var.cpu
    memory             = var.memory
    log_group_region   = var.aws_region
    log_group_name     = aws_cloudwatch_log_group.hqtrackbot-cloudwatch-log-group.name
  }
}

resource "aws_ecs_task_definition" "hqtrackbot-task_definition" {
  family                   = "hqtrackbot-task_definition"
  execution_role_arn       = aws_iam_role.hqtrackbot-ecs-service-iam-role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions    = data.template_file.hqtrackbot-task-definition-file.rendered
}

resource "aws_ecs_service" "hqtrackbot-ecs-service" {
  name            = "hqtrackbot-ecs-service"
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.hqtrackbot-ecs-cluster.id
  task_definition = aws_ecs_task_definition.hqtrackbot-task_definition.arn
  desired_count   = var.service_desired

  network_configuration {
    security_groups  = [aws_security_group.hqtrackbot-ecs-security-group.id]
    subnets          = aws_subnet.hqtrackbot-public-subnet.*.id
    assign_public_ip = true
  }
}

## IAM

resource "aws_iam_role" "hqtrackbot-ecs-service-iam-role" {
  name = "hqtrackbot-ecs-service-iam-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "hqtrackbot-execution-policy" {
  name        = "hqtrackbot-execution-policy"
  description = "hqtrackbot-execution-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ssm:Describe*",
          "ssm:Get*",
          "ssm:List*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "hqtrackbot-ecs-execution-role-attachment" {
  role       = aws_iam_role.hqtrackbot-ecs-service-iam-role.name
  policy_arn = aws_iam_policy.hqtrackbot-execution-policy.arn
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "hqtrackbot-cloudwatch-log-group" {
  name = "hqtrackbot-cloudwatch-log-group"
}
