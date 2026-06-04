# =============================================================================
# Ejercicio 1 - Template Packer para Azure
# Imagen: Ubuntu 22.04 LTS + Node.js 20 LTS + PM2 + Nginx (reverse proxy)
# Materia: Herramientas DevOps - UNIR 2025
# =============================================================================

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables de configuración
# -----------------------------------------------------------------------------

variable "client_id" {
  type        = string
  description = "Client ID del Service Principal de Azure"
  sensitive   = true
}

variable "client_secret" {
  type        = string
  description = "Client Secret del Service Principal de Azure"
  sensitive   = true
}

variable "subscription_id" {
  type        = string
  description = "ID de la suscripción de Azure"
}

variable "tenant_id" {
  type        = string
  description = "Tenant ID del directorio de Azure AD"
}

variable "resource_group" {
  type        = string
  description = "Resource Group donde se almacenará la imagen"
  default     = "rg-packer-devops"
}

variable "location" {
  type        = string
  description = "Región de Azure"
  default     = "West US"
}

variable "image_name" {
  type        = string
  description = "Nombre de la imagen generada"
  default     = "ubuntu-nodejs-nginx"
}

# -----------------------------------------------------------------------------
# Builder: azure-arm
# Crea una VM temporal en Azure, la provisiona y genera una Managed Image
# -----------------------------------------------------------------------------

source "azure-arm" "nodejs_nginx" {

  # Autenticación con Service Principal
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Imagen base: Ubuntu 22.04 LTS (Canonical)
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  image_version   = "latest"

  # Tamaño de la VM temporal de build
  vm_size = "Standard_D2s_v3"

  # Destino de la imagen resultante
  managed_image_name                = var.image_name
  managed_image_resource_group_name = var.resource_group

  # Ubicación del recurso
  location = var.location

  # Habilitar IP pública para el agente Packer
  # (requerido para que el provisioner SSH pueda conectarse)
  private_virtual_network_with_public_ip = false

  # Comunicador SSH (Packer se conecta así a la VM temporal)
  os_type        = "Linux"
  communicator   = "ssh"
  ssh_username   = "packer"
  ssh_timeout    = "20m"

  # Tags de la imagen final
  azure_tags = {
    Environment = "DevOps-Maestria"
    Project     = "Actividad1-Packer"
    Stack       = "NodeJS-Nginx"
    CreatedBy   = "Packer"
  }
}

# -----------------------------------------------------------------------------
# Build: secuencia de provisioners que configuran el software
# Sigue los pasos del tutorial de DigitalOcean adaptados a Ubuntu 22.04
# -----------------------------------------------------------------------------

build {
  name    = "nodejs-nginx-azure"
  sources = ["source.azure-arm.nodejs_nginx"]

  # --- Paso 1: Actualizar el sistema operativo ---
  provisioner "shell" {
    inline = [
      "echo '>>> [1/6] Actualizando el sistema operativo...'",
      "sudo apt-get update -y || true",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl wget git build-essential"
    ]
  }

  # --- Paso 2: Instalar Node.js 20 LTS via NodeSource ---
  provisioner "shell" {
    inline = [
      "echo '>>> [2/6] Instalando Node.js 20 LTS...'",
      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "node --version",
      "npm --version"
    ]
  }

  # --- Paso 3: Instalar PM2 (process manager para Node.js) ---
  provisioner "shell" {
    inline = [
      "echo '>>> [3/6] Instalando PM2...'",
      "sudo npm install -g pm2",
      "pm2 --version",
      # Configurar PM2 para iniciar automáticamente en el arranque
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u packer --hp /home/packer || true"
    ]
  }

  # --- Paso 4: Copiar la aplicación Node.js de ejemplo ---
  provisioner "file" {
    source      = "app/hello.js"
    destination = "/tmp/hello.js"
  }

  provisioner "file" {
    source      = "app/ecosystem.config.js"
    destination = "/tmp/ecosystem.config.js"
  }

  provisioner "shell" {
    inline = [
      "echo '>>> [4/6] Instalando la aplicacion Node.js...'",
      "sudo mkdir -p /opt/myapp",
      "sudo mkdir -p /var/log/pm2",
      "sudo chown -R packer:packer /var/log/pm2",
      "sudo cp /tmp/hello.js /opt/myapp/hello.js",
      "sudo cp /tmp/ecosystem.config.js /opt/myapp/ecosystem.config.js",
      "sudo chown -R packer:packer /opt/myapp",
      # Iniciar la app con PM2 y guardar el estado
      "cd /opt/myapp && pm2 start ecosystem.config.js",
      "pm2 save"
    ]
  }

  # --- Paso 5: Instalar y configurar Nginx como reverse proxy ---
  provisioner "shell" {
    inline = [
      "echo '>>> [5/6] Instalando y configurando Nginx...'",
      "sudo apt-get install -y nginx",

      # Eliminar configuración default de Nginx
      "sudo rm -f /etc/nginx/sites-enabled/default",

      # Crear configuración del reverse proxy: Nginx (80) → Node.js (3000)
      "sudo bash -c 'cat > /etc/nginx/sites-available/myapp << EOF",
      "server {",
      "    listen 80;",
      "    server_name _;",
      "",
      "    location / {",
      "        proxy_pass http://localhost:3000;",
      "        proxy_http_version 1.1;",
      "        proxy_set_header Upgrade \\$http_upgrade;",
      "        proxy_set_header Connection keep-alive;",
      "        proxy_set_header Host \\$host;",
      "        proxy_set_header X-Real-IP \\$remote_addr;",
      "        proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for;",
      "        proxy_cache_bypass \\$http_upgrade;",
      "    }",
      "}",
      "EOF'",

      # Habilitar el sitio
      "sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp",

      # Verificar configuración de Nginx
      "sudo nginx -t",

      # Habilitar e iniciar Nginx
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx"
    ]
  }

  # --- Paso 6: Generalizar la imagen (requerido por Azure ARM) ---
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "echo '>>> [6/6] Generalizando la imagen para Azure...'",
      "/usr/sbin/waagent -force -deprovision+user",
      "sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
