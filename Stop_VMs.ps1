workflow Stop_VMs
{

Param(
    #[Parameter(Mandatory=$True)]
    #[String] $account_id,
    [Parameter(Mandatory=$True)]
    [String] $subscription_id,
    [Parameter(Mandatory=$True)]
    [String] $resource_group,
    [Parameter(Mandatory=$True)]
    [String] $vm_list
    )

# Connect to Azure with system-assigned managed identity
Connect-AzAccount -Identity
    
$AzureContext = Set-AzContext –SubscriptionId $subscription_id

#foreach ($VM in $VM_List) {
    Stop-AzVM -force -Name $vm_list -ResourceGroupName $resource_group -DefaultProfile $AzureContext
#}


}

