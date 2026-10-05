terraform {
	required_version = ">= 1.5.0"
	required_providers {
		azurerm = {
			source  = "hashicorp/azurerm"
			version = "~> 4.0"
		}
	}
}

provider "azurerm" {
	features {}
	subscription_id = var.subscription_id
	client_id       = var.client_id
	client_secret   = var.client_secret
	tenant_id       = var.tenant_id
}

variable "subscription_id" {
	description = "Azure Subscription ID"
	type        = string
	sensitive   = true
}

variable "client_id" {
	description = "Azure Client ID"
	type        = string
	sensitive   = true
}

variable "client_secret" {
	description = "Azure Client Secret"
	type        = string
	sensitive   = true
}

variable "tenant_id" {
	description = "Azure Tenant ID"
	type        = string
	sensitive   = true
}

variable "location" {
	description = "Azure deployment region."
	type        = string
	default     = "East US"
}

variable "admin_username" {
	description = "Local Windows administrator username."
	type        = string
	default     = "azureadmin"
}

variable "admin_password" {
	description = "Local Windows administrator password. Set this as a protected CI/CD secret."
	type        = string
	sensitive   = true
	default     = "DefaultP@ssw0rd123!"
}

resource "azurerm_resource_group" "main" {
	name     = "rg-windows-vm"
	location = var.location
}

resource "azurerm_virtual_network" "main" {
	name                = "vnet-windows-vm"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name
	address_space       = ["172.168.0.0/16"]
}

resource "azurerm_subnet" "vm" {
	name                 = "snet-vm"
	resource_group_name  = azurerm_resource_group.main.name
	virtual_network_name = azurerm_virtual_network.main.name
	address_prefixes     = ["172.168.1.0/24"]
}

resource "azurerm_network_security_group" "vm" {
	name                = "nsg-windows-vm"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_interface" "vm" {
	name                = "nic-windows-vm"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name

	ip_configuration {
		name                          = "internal"
		subnet_id                     = azurerm_subnet.vm.id
		private_ip_address_allocation = "Dynamic"
	}
}

resource "azurerm_network_interface_security_group_association" "vm" {
	network_interface_id      = azurerm_network_interface.vm.id
	network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_windows_virtual_machine" "main" {
	name                = "vm-windows-private"
	computer_name       = "winprivatevm"
	resource_group_name = azurerm_resource_group.main.name
	location            = azurerm_resource_group.main.location
	size                = "Standard_B2s"
	admin_username      = var.admin_username
	admin_password      = var.admin_password
	network_interface_ids = [
		azurerm_network_interface.vm.id
	]

	os_disk {
		caching              = "ReadWrite"
		storage_account_type = "Standard_LRS"
	}

	source_image_reference {
		publisher = "MicrosoftWindowsServer"
		offer     = "WindowsServer"
		sku       = "2022-datacenter-azure-edition"
		version   = "latest"
	}
}

output "vm_private_ip" {
	description = "Private IP address of the Windows VM."
	value       = azurerm_network_interface.vm.private_ip_addresses[0]
}
