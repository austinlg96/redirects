variable "region" {
  type    = string
  default = null
}

variable "encrypt_arns" {
  type    = list(string)
  default = []
}

variable "decrypt_arns" {
  type    = list(string)
  default = []
}


variable "management_arns" {
  type    = list(string)
  default = null
}
