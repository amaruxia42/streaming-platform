output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "ecs_service_sg_id" {
  value = aws_security_group.ecs_service_sg.id
}

output "vpc_endpoint_sg_id" {
  value = aws_security_group.vpc_endpoints_sg.id
}