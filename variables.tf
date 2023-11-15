variable "pagerduty_token" {
  description = "PagerDuty API Token"
  type        = string
  sensitive   = true
}

variable "brands" {
  type = set(string)
  default = [ 
    "brand1",
    "brand2",
    "brand3",
    "brand4",
    "brand5",
    "brand6"
   ]
}
variable "regions" {
  type = set(string)
  default = [ 
    "na",
    "emea",
    "apj"
    ]
}