output "alb_dns_name" {
  value = aws_lb.aws_lb.dns_name
}

output "alb_arn" {
  value = aws_lb.aws_lb.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.ecs.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}