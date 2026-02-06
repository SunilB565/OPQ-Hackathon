variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "order_image" {
  type = string
}

variable "storage_image" {
  type = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type = string
  default = "10.180.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type = list(string)
  default = ["10.180.3.0/24","10.180.4.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs"
  type = list(string)
  default = ["10.180.1.0/24","10.180.2.0/24"]
}

variable "availability_zones" {
  type = list(string)
  default = ["us-east-1a","us-east-1b"]
}

variable "admin_token" {
  description = "Admin token for storage approve endpoint"
  type = string
  default = ""
}

variable "domain_name" {
  description = "Root domain name to create Route53 hosted zone and DNS records (leave empty to skip)"
  type = string
  default = ""
}

variable "create_hosted_zone" {
  description = "If true, create a Route53 hosted zone for `domain_name`. If false, the zone must exist and its ID supplied via hosted_zone_id var."
  type = bool
  default = true
}

variable "hosted_zone_id" {
  description = "If the hosted zone already exists, provide its ID here (skips creation)."
  type = string
  default = ""
}
