# Specify the provider and access details
provider "aws" {
  region = var.aws_region
}

## Fargate

### Network

data "aws_availability_zones" "available" {}

resource "aws_vpc" "hqtrackbot-vpc" {
  cidr_block = "10.10.0.0/16"
}

# Create var.az_count public subnets
resource "aws_subnet" "hqtrackbot-public-subnet" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.hqtrackbot-vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.hqtrackbot-vpc.id
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "hqtrackbot-gateway" {
  vpc_id = aws_vpc.hqtrackbot-vpc.id
}

# Route the public subnet traffic through the IGW
resource "aws_route_table" "hqtrackbot-route-table" {
  vpc_id = aws_vpc.hqtrackbot-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hqtrackbot-gateway.id
  }
}

# Associate the newly route tables to the public subnet
resource "aws_route_table_association" "hqtrackbot-route-table-association" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.hqtrackbot-public-subnet.*.id, count.index)
  route_table_id = aws_route_table.hqtrackbot-route-table.id
}

### Compute

resource "aws_appautoscaling_target" "hqtrackbot-appautoscaling-target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.hqtrackbot-ecs-cluster.name}/${aws_ecs_service.hqtrackbot-ecs_service.name}"
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
    execution_role_arn = "arn:aws:iam::549655260017:role/ecsTaskExecutionRole"
    environment        = var.environment
    container_name     = "hqtrackbot"
    log_group_region   = var.aws_region
    log_group_name     = aws_cloudwatch_log_group.hqtrackbot-cloudwatch-log-group.name
  }
}

resource "aws_ecs_task_definition" "hqtrackbot-task_definition" {
  family                = "hqtrackbot-task_definition"
  container_definitions = data.template_file.hqtrackbot-task-definition-file.rendered
}

resource "aws_ecs_service" "hqtrackbot-ecs_service" {
  name            = "hqtrackbot-ecs_service"
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.hqtrackbot-ecs-cluster.id
  task_definition = aws_ecs_task_definition.hqtrackbot-task_definition.arn
  desired_count   = var.service_desired
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
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "hqtrackbot-ecs-service-iam-role-policy" {
  name = "hqtrackbot-ecs-service-iam-role-policy"
  role = "aws_iam_role.hqtrackbot-ecs-service-iam-role.name"

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

resource "aws_iam_instance_profile" "hqtrackbot-iam-instance-profile" {
  name = "hqtrackbot-iam-instance-profile"
  role = "aws_iam_role.hqtrackbot-ecs-service-iam-role.name"
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "hqtrackbot-cloudwatch-log-group" {
  name = "hqtrackbot-cloudwatch-log-group"
}
