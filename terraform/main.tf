locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Workload    = "SelfHostedLLM"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = local.common_tags
}

resource "azurerm_subnet" "public" {
  name                 = "snet-public-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_prefix]
}

resource "azurerm_subnet" "private" {
  name                 = "snet-private-llm-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_prefix]
}

resource "azurerm_network_security_group" "public" {
  name                = "nsg-public-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_network_security_group" "private" {
  name                = "nsg-private-llm-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

resource "azurerm_storage_account" "model_storage" {
  name                     = "st${replace(var.project_name, "-", "")}${var.environment}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  tags = local.common_tags
}

resource "azurerm_storage_container" "models" {
  name                  = "models"
  storage_account_name  = azurerm_storage_account.model_storage.name
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "llm_identity" {
  name                = "id-${var.project_name}-${var.environment}-llm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_role_assignment" "llm_storage_reader" {
  scope                = azurerm_storage_account.model_storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.llm_identity.principal_id
}

resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_servicebus_queue" "inference_jobs" {
  name         = "inference-jobs"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count                   = 5
  lock_duration                        = "PT5M"
  default_message_ttl                  = "P1D"
  dead_lettering_on_message_expiration = true
}

resource "azurerm_network_interface" "llm_nic" {
  name                = "nic-${var.project_name}-${var.environment}-llm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_linux_virtual_machine" "llm_vm" {
  name                = "vm-${var.project_name}-${var.environment}-llm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_NC6" # GPU-enabled VM

  admin_username = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.llm_nic.id
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.llm_identity.id]
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCScCz43e0orV1MuLhyecnf0nOR0jBvl/+V+TwsbBbjogj8buV+I8Xwsr3gtoXAw15Uss5uAKCd6ENVuQrisxRCZDBUlv523XjS6cX4V5awuYQGjDIx4RK4ByTlvnFPX4LwwnPguFrW7O+jfRkkK3iv9BlBi8VwA/EmhkzhTv28C71nRZkK9xoJnd5sF76JwQwHxlbzl+6RbpKMcd8Alv9j7vVUm14Swu2nfGkKDMmlk6kD7RVBug6AToQdP33HEUG3HCEYiat+52y+y4eUp4N6lPfOPZkijnAfdv6NhmY3Y2anMItxjW/J2N8fx/jWfIObwJakP5n1YgqZWA6msa7DbCOoKxC6LpWI2ka+DQH8WomlmIWiwKxg/MP9x70MXkJpS6QI+nAN6i3HAeRm6T4kIEc98LRIFRIb0WkCwfIKlKoKIXio+Qv/fr6P/I+LJLUe0w/IXNDcsCq7g1IB9Ep2rqmwEhaDnuMiXACRZD40S97R5MyxTRqJ347PvB8vRuLcZ2TFcoxmH/P7UDMMRUw2f19oFvsG1z6hDdXr5hjV6WwRA0P7TpRZoD8xKqCI5Xvwy27n8jI0MaGXtMXiB4k9JQwJiFSLrcox7WXdbxLpGsPPpNLmyqiUouSLSGxE3sM+uy/mV7sCqYzC58/PpwDyWQl2ySfxYzCvFlr3K591/w== anand@AnanDahadha"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = local.common_tags
}