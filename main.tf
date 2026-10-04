terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terformyogistorage"
    container_name       = "tfstate"
    key                  = "main.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region in which to deploy the VM."
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Linux administrator account name."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key used to authenticate to the VM."
  type        = string
  sensitive   = true
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJlAt8TqLnpXZ6cL5W/cWCHzumC6Te3NWdmo937Ttqv4eUlVo1y/oa/2HVlrgCJU7j4AxrD2p1XHXclNm1tHVQQXUbnCrm8qxTlF7sBw7ZZF8we0LMXqNEtA9ObN/nmCGpiHihZfYHHjj4PHNSuR72rr0yU3yCeryWlooItbsinyT7uzjENoKh/cBnPvBGGsvZG4GVETI9Oc/jPLqUymVBaYfMcmAKQrkS8qeb0v6b4PtvmDrXDkn4ZMh3vNVXqqI1pxXcjkuqkJHwZxqTKd4USzjRSjh6pQD/Mv1q6QhrX01AX4OUzZ/oXva7T4y+UcXb+XPpuYR5mkpglWKUJAhLOL3h295km0gDcurIu4wk9CUIzm5C3CS9xDuxBB5vouux2ddR2nulSEweuVu8qKpWBgDiuhIK6ZxXzq/zrzNsZLloKtjuObfXvAD0BrxGsjXIGZakrzXQ8LDOefUTGW+0VqOvlly4SdaD6cEm2uhrpX1WKbFyTtv/ekj4SSgYog3CCmAAw4OEcNJz35VMPE3qP2+X7kF/wno7UIvLy0JAGsgD/krucc/AbkzBwh+muc97YJjOjDIyVCxvG3wQD3U/h+L3y1Xvz7AjZpPGAqCRZcWnrYOZ4XA0ndwXEsO29E7reBGMgCinYdA3d3gynzq0OTc4esfKzxai/WraoIl+OQ== terraform-vm-admin"
}

variable "ssh_source_cidr" {
  description = "CIDR allowed to reach SSH. 0.0.0.0/0 allows SSH from anywhere."
  type        = string
  default     = "0.0.0.0/0"
}

resource "azurerm_resource_group" "vm" {
  name     = "terraform-vm-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vm" {
  name                = "terraform-vm-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
}

resource "azurerm_subnet" "vm" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.vm.name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "vm" {
  name                = "terraform-vm-pip"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "vm" {
  name                = "terraform-vm-nsg"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm" {
  name                = "terraform-vm-nic"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "terraform-linux-vm"
  resource_group_name = azurerm_resource_group.vm.name
  location            = azurerm_resource_group.vm.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

output "vm_public_ip" {
  description = "Public IP address assigned to the VM."
  value       = azurerm_public_ip.vm.ip_address
}
