resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "${var.prefix}-publicIP"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Staging"
  }
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

#Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "test"
  }

}

#Azure backup
resource "azurerm_recovery_services_vault" "vault" {
  name                = "${var.prefix}-recovery-vault"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Standard"

  soft_delete_enabled = true
}

resource "azurerm_backup_policy_vm" "example" {
  name                = "${var.prefix}-recovery-vault-policy"
  resource_group_name = azurerm_resource_group.example.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "17:00"
  }

  retention_daily {
    count = 10
  }

  retention_weekly {
    count    = 42
    weekdays = ["Sunday", "Wednesday", "Friday", "Saturday"]
  }

  retention_monthly {
    count    = 7
    weekdays = ["Sunday", "Wednesday"]
    weeks    = ["First", "Last"]
  }

  retention_yearly {
    count    = 77
    weekdays = ["Sunday"]
    weeks    = ["Last"]
    months   = ["January"]
  }
}

resource "azurerm_log_analytics_workspace" "loganalytics-fprgt" {
  name                = "loganalytics-fprgt"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_backup_protected_vm" "test-fprgt-vm" {
  resource_group_name = azurerm_resource_group.example.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = azurerm_virtual_machine.main.id
  backup_policy_id    = azurerm_backup_policy_vm.example.id
}

#System assigned identity and Automation account
data "azurerm_subscription" "current" {}

resource "azurerm_automation_account" "aa-fprgt-demo" {
  name                = "aa-fprgt-demo"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  public_network_access_enabled = false

  sku_name = "Basic"

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_role_assignment" "aa-fprgt-demo" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.aa-fprgt-demo.identity[0].principal_id
}

#Start VMs Runbook and Schedule
data "local_file" "start-ps1" {
  filename = "Start_VMs.ps1"
}

resource "azurerm_automation_runbook" "Start_VMs" {
  name                    = "Start_VMs"
  location                = azurerm_resource_group.example.location
  resource_group_name     = azurerm_resource_group.example.name
  automation_account_name = azurerm_automation_account.aa-fprgt-demo.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Demo Start VM runbook"
  runbook_type            = "PowerShellWorkflow"
  content                 = data.local_file.start-ps1.content
}

resource "azurerm_automation_schedule" "testStart" {
  name                    = "startvm-automation-schedule"
  resource_group_name     = azurerm_resource_group.example.name
  automation_account_name = azurerm_automation_account.aa-fprgt-demo.name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2023-03-17T07:00:00+01:00"
  description             = "Scheduled VM startup example"
  #week_days               = ["Friday"] only if frequency is "Week"
}

resource "azurerm_automation_job_schedule" "demo_sched" {
  resource_group_name     = azurerm_resource_group.example.name
  automation_account_name = azurerm_automation_account.aa-fprgt-demo.name
  schedule_name           = azurerm_automation_schedule.testStart.name
  runbook_name            = azurerm_automation_runbook.Start_VMs.name
  
  parameters = {
    #account_id = var.system_assigned_identity_id
    subscription_id = var.subscription_id
    resource_group = azurerm_resource_group.example.name
    vm_list = var.vm_list
    }

  depends_on = [azurerm_automation_schedule.test]
}


#Stop VMs Runbook and Schedule
data "local_file" "stop-ps1" {
  filename = "Stop_VMs.ps1"
}

resource "azurerm_automation_runbook" "Stop_VMs" {
  name                    = "Stop_VMs"
  location                = azurerm_resource_group.example.location
  resource_group_name     = azurerm_resource_group.example.name
  automation_account_name = azurerm_automation_account.aa-fprgt-demo.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Demo Stop VM runbook"
  runbook_type            = "PowerShellWorkflow"
  content                 = data.local_file.stop-ps1.content
}

resource "azurerm_automation_schedule" "testStop" {
  name                    = "stopvm-automation-schedule"
  resource_group_name     = azurerm_resource_group.example.name
  automation_account_name = azurerm_automation_account.aa-fprgt-demo.name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2023-03-16T18:00:00+01:00"
  description             = "Scheduled VM shutdown example"
  #week_days               = ["Friday"] only if frequency is "Week"
}

resource "azurerm_automation_job_schedule" "demo_sched_stop" {
  resource_group_name     = azurerm_resource_group.example.name
  automation_account_name = azurerm_automation_account.aa-fprgt-demo.name
  schedule_name           = azurerm_automation_schedule.testStop.name
  runbook_name            = azurerm_automation_runbook.Stop_VMs.name
  depends_on = [azurerm_automation_schedule.teststop]

  parameters = {
    #account_id = var.system_assigned_identity_id
    subscription_id = var.subscription_id
    resource_group = azurerm_resource_group.example.name
    vm_list = var.vm_list
    }
}

#Alert Module
module "alert" {
  source = "./alert"

  rg    = azurerm_resource_group.example.name
  vm_id = azurerm_virtual_machine.main.id
}

#Create Service Principal
#data "azuread_client_config" "current" {}

#resource "azuread_application" "script_express_route" {
#  display_name = "service_principal_fprgt"
#  owners       = [data.azuread_client_config.current.object_id]
#}

#resource "azuread_application_password" "script_express_route" {
#  application_object_id = azuread_application.script_express_route.id
#}

#resource "azuread_service_principal" "script_express_route" {
#  application_id = azuread_application.script_express_route.application_id
#"}

#resource "azuread_service_principal_password" "script_express_route" {
#  service_principal_id = azuread_service_principal.script_express_route.object_id
#}

#resource "azurerm_role_assignment" "script_express_route" {
#  scope                = data.azurerm_subscription.current.id
#  role_definition_name = "Contributor"
#  principal_id         = azuread_service_principal.script_express_route.object_id
#}