variable "domain" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "deploy_stages_set" {
  type        = set(string)
  default     = ["all"]
  description = "Allows a staged roll out of infrastructure in situations whwere multiple applies are required."
}
