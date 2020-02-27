output "ecs_security_group" {
  value = "${aws_security_group.ecs_sg.id}"
}

output "asg_name" {
  value = "${aws_appautoscaling_target.target.id}"
}
