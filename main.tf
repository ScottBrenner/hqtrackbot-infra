# Specify the provider and access details
provider "aws" {
  region                      = var.aws_region
}

## Fargate

### Network

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
}

# Create var.az_count public subnets
resource "aws_subnet" "main" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route the public subnet traffic through the IGW
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate the newly route tables to the public subnet
resource "aws_route_table_association" "a" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.main.*.id, count.index)
  route_table_id = aws_route_table.r.id
}

### Compute

resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.hqtrackbot-ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 1
}

### Security

resource "aws_security_group" "ecs_sg" {
  description = "controls access to the application"

  vpc_id = aws_vpc.main.id
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

resource "aws_ecs_cluster" "main" {
  name = "hqtrackbot_ecs_cluster"
}

data "template_file" "task_definition" {
  template = file("./task-definition.json")

  vars = {
    image            = var.image
    executionRoleArn = ""
    environment      = var.environment
    container_name   = "hqtrackbot"
    log_group_region = var.aws_region
    log_group_name   = aws_cloudwatch_log_group.hqtrackbot.name
  }
}

resource "aws_ecs_task_definition" "hqtrackbot-task_definition" {
  family                = "hqtrackbot-task_definition"
  container_definitions = data.template_file.task_definition.rendered
}

resource "aws_ecs_service" "hqtrackbot-ecs_service" {
  name            = "hqtrackbot-ecs_service"
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hqtrackbot-task_definition.arn
  desired_count   = var.service_desired
}

## IAM

resource "aws_iam_role" "ecs_service" {
  name = "tf_hqtrackbot_ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "tf_hqtrackbot_ecs_policy"
  role = "aws_iam_role.ecs_service.name"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "hqtrackbot" {
  name = "tf-ecs-instprofile"
  role = "aws_iam_role.hqtrackbot_instance.name"
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name = "tf-ecs-group/ecs-agent"
}

resource "aws_cloudwatch_log_group" "hqtrackbot" {
  name = "tf-ecs-group/hqtrackbot"
}
