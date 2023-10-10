
/*data "azurerm_virtual_machine" "main" {
  name                = var.vm
  resource_group_name = var.rg
}*/

resource "azurerm_monitor_activity_log_alert" "test-fprgt-vm-resourceHealth" {
    name                = "test-fprgt-vm-resourceHealth"
    resource_group_name = var.rg
    scopes              = [var.vm_id]
    description         = "Action will be triggered when ResourceHealth is not Available"
    enabled             = true

    criteria {
        category = "ResourceHealth"
        
        resource_health  {
            current  = ["Degraded","Available","Unknown"]
            previous = ["Unavailable"]
            reason   = ["PlatformInitiated","UserInitiated","Unknown"]
        }
    }

        action {
            action_group_id = azurerm_monitor_action_group.email.id
    }
    
}


resource "azurerm_monitor_action_group" "email" {
    name                = "Action_Group_fprgt"
    resource_group_name = var.rg
    short_name          = "agfprgt"

  email_receiver {
    name = "email"
    email_address = var.email_receiver
  }

}
