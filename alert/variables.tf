variable "rg" {
  type = string
  default = ""
}

variable "vm_id" {
  type = string
  default = ""
}

variable "email_receiver" {
  default = "fabrice.pringuet@inetum.com"
  description = "email receiver for monitoring with action group"
}
