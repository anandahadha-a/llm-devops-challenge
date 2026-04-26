variable "project_name" {
  description = "Name prefix used for all resources."
  type        = string
  default     = "llm-devops"
}

variable "location" {
  description = "Azure region where resources would be deployed."
  type        = string
  default     = "uaenorth"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources."
  type        = string
  default     = "devops"
}