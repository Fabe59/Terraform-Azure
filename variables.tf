variable "prefix" {
  type = string
  default = "test-fprgt"
}

variable "resource_group_location" {
  type = string
  default     = "West Europe"
  description = "Location of the resource group."
}

/*variable "user_assigned_identity_id" {
  type = string
  default = "xx"
}*/

variable "system_assigned_identity_id" {
  type = string
  default = "xx"
}

variable "subscription_id" {
  type = string
  default = "xx"
}

variable "rg_name" {
  type = string
  default = "test-fprgt-resources"  
}

variable "vm_list" {
  type = string
  default = "test-fprgt-vm" 
}
