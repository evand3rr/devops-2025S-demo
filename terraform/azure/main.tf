# main.tf
# Builds on Azure: one resource group, one network, and two Ubuntu servers
# (an app server and a database server) with firewall rules.

# ---------------------------------------------------------------------------
# Resource group: the folder that holds everything. Destroying it removes all.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Network: a private network with one subnet that both servers sit in.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "campus-notifier-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "campus-notifier-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ---------------------------------------------------------------------------
# Public IPs: Static + Standard so the address exists as soon as it is created
# and can be printed in outputs.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "app" {
  name                = "campus-notifier-app-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "db" {
  name                = "campus-notifier-db-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ---------------------------------------------------------------------------
# Network interfaces (NICs): each server's connection to the subnet.
# Each gets a private IP (inside Azure) and a public IP (from the internet).
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "app" {
  name                = "campus-notifier-app-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

resource "azurerm_network_interface" "db" {
  name                = "campus-notifier-db-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.db.id
  }
}

# ---------------------------------------------------------------------------
# Firewall for the app server (Azure calls it a network security group, NSG).
# Only your laptop can reach SSH (22) and the app port. Priority: lower number
# is checked first.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "app" {
  name                = "campus-notifier-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "ssh-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "app-from-my-ip"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.app_port)
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------------------------
# Firewall for the database server.
# SSH from your laptop; Postgres (5432) from the app server ONLY.
# Azure allows all traffic inside a virtual network by default, so we add an
# explicit "deny" for 5432 at a later priority to block everyone except the app.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "db" {
  name                = "campus-notifier-db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "ssh-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "postgres-from-app-server"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_network_interface.app.private_ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "postgres-deny-everyone-else"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Attach each firewall to its server's network interface.
resource "azurerm_network_interface_security_group_association" "app" {
  network_interface_id      = azurerm_network_interface.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_network_interface_security_group_association" "db" {
  network_interface_id      = azurerm_network_interface.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

# ---------------------------------------------------------------------------
# The two servers: empty Ubuntu 24.04 machines. Nothing is installed on them;
# you set up Postgres and Docker by hand in the next tasks.
# Login is by SSH key only (password login is switched off).
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "app_server" {
  name                  = "campus-notifier-app"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.app.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = {
    Name = "campus-notifier-app"
  }
}

resource "azurerm_linux_virtual_machine" "db_server" {
  name                  = "campus-notifier-db"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.db.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = {
    Name = "campus-notifier-db"
  }
}
