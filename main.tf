terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.29.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "0caa5aea-9c32-4a54-a463-61c09fd1b91c"
}

variable "prefix" {
  default = "testTerraform"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = "Central India"
}

resource "azurerm_virtual_network" "vnet" {
  name = "${var.prefix}-vnet"
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name = "${var.prefix}-subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.0.2.0/24"]
  depends_on = [ azurerm_virtual_network.vnet ]
}

resource "azurerm_public_ip" "publicip" {
  name = "${var.prefix}-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  allocation_method = "Static"
  depends_on = [ azurerm_virtual_network.vnet ]
}

resource "azurerm_network_interface" "netinterface" {
  name = "${var.prefix}-netinterface"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name = "${var.prefix}-ipconfig"
    subnet_id = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.publicip.id
  }
  depends_on = [ azurerm_virtual_network.vnet ]
}

resource "azurerm_network_security_group" "nsgrules" {
  name = "${var.prefix}-nsgrules"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  security_rule {
    name = "inbound-ssh"
    direction = "Inbound"
    priority = 100
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    access = "Allow"
  }
}

resource "azurerm_network_interface_security_group_association" "nsgrules-asso" {
  network_interface_id = azurerm_network_interface.netinterface.id
  network_security_group_id = azurerm_network_security_group.nsgrules.id
}

resource "azurerm_linux_virtual_machine" "testvm" {
  name = "${var.prefix}-testvm"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_F2"
  admin_username = "testadmin"
  admin_password = "testAdmin@Pass"
  network_interface_ids = [ azurerm_network_interface.netinterface.id ]
  admin_ssh_key {
    username = "testadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "canonical"
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts"
    version = "latest"
  }
}

output "public-ip" {
  value = azurerm_linux_virtual_machine.testvm.public_ip_address
}