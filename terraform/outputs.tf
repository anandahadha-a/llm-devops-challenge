output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "private_subnet_id" {
  value = azurerm_subnet.private.id
}

output "storage_account_name" {
  value = azurerm_storage_account.model_storage.name
}

output "servicebus_namespace" {
  value = azurerm_servicebus_namespace.main.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.llm_vm.name
}