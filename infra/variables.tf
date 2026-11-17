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

variable "alert_email" {
  type = string
}

variable "monthly_budget_usd" {
  type    = number
  default = 6
}

variable "github_repo" {
  description = "owner/name, e.g. mahamatmbodou33/portfolio-site"
  type        = string
}

variable "state_bucket_name" {
  type = string # from Phase 2
}

variable "create_github_oidc_provider" {
  type    = bool
  default = true # false if your account already has one (e.g. from your three-tier project)
}

variable "github_owner_id" {
  description = "Numeric GitHub owner ID (part of the OIDC subject)"
  type        = string
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID (part of the OIDC subject)"
  type        = string
}
