output "load_balancer_dns_name" {
  description = "Public DNS name of the API load balancer"
  value       = aws_lb.api.dns_name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}
