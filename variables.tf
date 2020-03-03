variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-west-1"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "1"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "1"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}

variable "service_desired" {
  description = "Desired numbers of instances in the ecs service"
  default     = "1"
}

variable "image" {
  description = "Docker image to run in Fargate"
  default     = "scottbrenner/hqtrackbot:latest"
}

variable "environment" {
  description = "Environment variables for container"
  default     = <<EOF
  {
    "name": "REDDIT_SUBREDDITS",
    "value": "hqtrackbot+electronicmusic+techno+liquiddubstep+house+tech_house+OldSkoolDance+ambientmusic+AtmosphericDnB+BigBeat+boogiemusic+chicagohouse+chillout+Chipbreak+Chiptunes+complextro+cxd+darkstep+DubStep+EBM+electronicdancemusic+ElectronicJazz+ElectronicBlues+electrohiphop+electrohouse+electronicmagic+electroswing+fidget+filth+frenchelectro+frenchhouse+funkhouse+fusiondancemusic+futurebeats+FutureGarage+futuresynth+gabber+glitch+glitchop+happyhardcore+hardhouse+idm+industrialmusic+ItaloDisco+latinhouse+mashups+mixes+moombahcore+nightstep+OldskoolRave+Outrun+partymusic+plunderphonics+PsyBreaks+psytrance+purplemusic+raggajungle+skweee+swinghouse+tranceandbas+trap+tribalbeats+TropicalHouse+ukfunky+witchhouse+wuuB+SirBerryDinglesDiscog+AfroBashment"
  }
  EOF
}

variable "cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "256"
}

variable "memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "512"
}