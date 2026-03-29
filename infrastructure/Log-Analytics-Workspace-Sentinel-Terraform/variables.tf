variable "logAnalyticsWorkspace" {
  type        = string
  description = "Name of the Log Analytics Workspace"
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Location/region for resources."
}

variable "retentionDays" {
  type        = number
  description = "Number of days to retain logs. Between 30 and 730."
  validation {
    condition = var.retentionDays >= 30 && var.retentionDays <= 730
    error_message = "Retention days must be between 30 and 730."
  }
}

variable "sku" {
  type        = string
  description = "SKU for the Log Analytics Workspace."
  validation {
    condition = contains([
    "PerGB2018", "PerNode", "Premium", "Standalone",
      "Standard", "CapacityReservation", "Free"
  ], var.sku)
  error_message = "Invalid SKU value."
  }
}

variable "resourceGroupName" {
  description = "Name of the resource group to deploy resources into."
  type        = string
}