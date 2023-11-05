terraform {
  required_providers {
    namecheap = {
      source  = "namecheap/namecheap"
      version = "2.1.0"
    }
  }
}

resource "namecheap_domain_records" "main" {
  domain = var.domain
  mode   = "OVERWRITE"

  nameservers = var.name_servers
}
