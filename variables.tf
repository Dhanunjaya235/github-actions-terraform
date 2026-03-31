variable "aws_region" {
    description = "AWS region to deploy resources in"
    type        = string
    default     = "ap-south-1" 
}

variable "environment" {
    description = "Deployment environment (e.g., dev, staging, prod)"
    type        = string
    default     = "dev"  
}

variable "project_name" {
    description = "Name of the project for tagging purposes"
    type        = string
    default     = "github-actions-demo"  
}
