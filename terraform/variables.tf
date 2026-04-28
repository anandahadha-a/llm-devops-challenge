variable "project_name" {
  description = "Name prefix used for all resources."
  type        = string
  default     = "llm-devops"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name must be 3-20 lowercase alphanumeric characters or hyphens."
  }
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

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner of the resources."
  type        = string
  default     = "devops"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "public_subnet_prefix" {
  description = "Address prefix for public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_prefix" {
  description = "Address prefix for private subnet where LLM workloads run."
  type        = string
  default     = "10.20.2.0/24"
}

variable "admin_ssh_public_key" {
  description = "SSH public key used for VM access."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa) ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be a valid SSH public key."
  }
}