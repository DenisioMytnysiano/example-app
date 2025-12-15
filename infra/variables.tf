variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "example-api"
}

variable "app_image" {
  description = "Docker image (e.g. 123456789012.dkr.ecr.us-west-1.amazonaws.com/example-api:latest or public image)"
  type        = string
}

variable "app_port" {
  description = "Container and load balancer port to expose"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}
