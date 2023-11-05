variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "role_names" {
  type        = list(string)
  description = "The list of role names that the policy should be attached to."
}


variable "statements" {
  type = list(object(
    {
      effect    = string
      actions   = list(string)
      resources = list(string)
    }

  ))
  validation {
    condition     = can([for s in var.statements[*].effect : regex("^(Allow)|(Deny)]$", s)])
    error_message = "Statements must have an effect of either 'Allow' or 'Deny'.}"
  }
  description = "The statements that should be added to the policy document."
}
