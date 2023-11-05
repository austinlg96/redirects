variable "name" {
  type        = string
  description = "The name of the lambda function. Also used by default for the source code and build paths."
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
