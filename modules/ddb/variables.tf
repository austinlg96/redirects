variable "name" {
  type = string
}

variable "put_item_role_names" {
  type    = list(string)
  default = []
}

variable "stream_table_role_names" {
  type    = list(string)
  default = []
}
