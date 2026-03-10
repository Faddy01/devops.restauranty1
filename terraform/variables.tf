variable "prefix" {
  description = "Prefix for all Azure resource names"
  type        = string
  default     = "FHS-restauranty"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment name (dev / staging / production)"
  type        = string
  default     = "production"
}

variable "kubernetes_version" {
  description = "FHS AKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_count" {
  description = "Initial node count for the AKS default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "FHS VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}
