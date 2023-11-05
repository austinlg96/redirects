variable "base_path" {
  type    = string
  default = "redirect"
}

variable "domain" {
  type = string
}

variable "protocol" {
  type    = string
  default = "https"
}

variable "sns_sub_proto" {
  type    = string
  default = "email-json"
}

variable "sns_sub_endpoint" {
  type = string
}

variable "error_destination" {
  type = string
}

variable "project_name" {
  type    = string
  default = "redirects"
}

variable "environment" {
  type        = string
  description = "A label to distinguish between multiple deployments of the same project."
  default     = "main"
}

variable "class" {
  type        = string
  description = "Identifies the type of deploymnet. (eg: prod, dev, etc...)."
  default     = "prod"
}
variable "use_base_default_tags" {
  type        = bool
  default     = true
  description = "Use the default_tags assigned by the project."
}
variable "custom_default_tags" {
  type        = map(string)
  description = "Additional default_tags that should be included."
  default     = {}
}

variable "region" {
  type        = string
  description = "The AWS region that resources should be deployed to."
}
