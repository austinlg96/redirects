variable "name_prefix" {
  type        = string
  description = "The name_prefix from the parent module. Used to generate the function name."
  default     = ""
}
variable "friendly_name" {
  type        = string
  description = "The local name of the lambda function. Also used by default for the source code path, build path, and as part of the function name."
}

variable "excluded_files" {
  type        = list(string)
  description = "List of files that should be excluded from the final binary."
  default     = []
}

variable "source_dir" {
  type        = string
  description = "Path to directory of lambda source code."
  default     = null
}

variable "build_path" {
  type        = string
  description = "Path to file where source code will be built to."
  default     = null
}

variable "environment_vars" {
  type    = map(any)
  default = {}
}

variable "handler" {
  type    = string
  default = "main.lambda_hanlder"
}

variable "parent_module_root" {
  type = string
}
