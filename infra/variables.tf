variable "project_name" {
  type    = string
  default = "portfolio"
}

variable "domain_name" {
  description = "Apex domain, e.g. bodu.dev. Its Route 53 hosted zone must exist."
  type        = string
}

variable "include_www" {
  type    = bool
  default = true
}
