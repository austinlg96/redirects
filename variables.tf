variable "base_path" {
  type = string
  default = "redirect"
}

variable "domain" {
  type = string
}

variable "protocol" {
  type = string
  default = "https"
}

variable "sns_sub_proto" {
  type = string
  default = "email-json"
}

variable "sns_sub_endpoint" {
  type = string
}
