variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "vpc_name" {
  description = "Name of the custom VPC network."
  type        = string
}

variable "subnet_connector_cidr" {
  description = "CIDR for the Serverless VPC Connector subnet (/28 required)."
  type        = string
}

variable "subnet_cloudsql_cidr" {
  description = "CIDR for the Cloud SQL private subnet."
  type        = string
}

variable "psa_range_name" {
  description = "Name for the PSA IP range allocation."
  type        = string
}

variable "psa_cidr_prefix" {
  description = "CIDR block for the PSA allocated range."
  type        = string
}

variable "connector_name" {
  description = "Name of the Serverless VPC Access Connector."
  type        = string
}

variable "connector_min_instances" {
  description = "Minimum VPC connector instances."
  type        = number
  default     = 2
}

variable "connector_max_instances" {
  description = "Maximum VPC connector instances."
  type        = number
  default     = 3
}

variable "connector_machine_type" {
  description = "Machine type for VPC connector."
  type        = string
  default     = "e2-micro"
}

variable "labels" {
  description = "Labels to apply to resources."
  type        = map(string)
  default     = {}
}
