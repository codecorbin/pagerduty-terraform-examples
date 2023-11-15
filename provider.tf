terraform {
  required_providers {
    pagerduty = {
      source = "PagerDuty/pagerduty"
    }
  }
}

provider "pagerduty" {
  # Configuration options
  token = var.pagerduty_token
}
