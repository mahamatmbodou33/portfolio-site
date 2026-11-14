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

variable "contact_recipient_email" {
  description = "Inbox that receives contact form messages."
  type        = string
}

variable "create_dmarc_record" {
  type    = bool
  default = true # set false if your domain already has a DMARC record
}
