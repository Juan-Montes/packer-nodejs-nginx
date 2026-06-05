#!/bin/bash
# =============================================================================
# setup-azure.sh — Preparación completa del equipo local (Pop!_OS 22.04)
# Instala: Azure CLI + Packer CLI
# Configura: Resource Group + Service Principal para Packer
# Ejecutar UNA sola vez antes de correr packer build
# =============================================================================

set -euo pipefail

# --- Configuración ---
RESOURCE_GROUP="rg-packer-devops"
LOCATION="westus"
SP_NAME="sp-packer-devops"

# Pop!_OS 22.04 reporta "jammy" con lsb_release pero su ID es "pop"
# Forzamos el codename de Ubuntu base para que los repositorios funcionen
UBUNTU_CODENAME="jammy"

echo "============================================="
echo " Setup completo — Pop!_OS 22.04 (base Ubuntu Jammy)"
echo "============================================="

# =============================================================================
# FASE 1: Instalar Azure CLI
# =============================================================================
echo ""
echo "[FASE 1/3] Instalando Azure CLI..."

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

# Importar clave GPG de Microsoft
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | \
  gpg --dearmor | \
  sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

# Agregar repositorio de Azure CLI
# Usamos UBUNTU_CODENAME="jammy" porque Pop!_OS reporta "jammy" en lsb_release
# pero su ID es "pop", lo que puede confundir a algunos scripts
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${UBUNTU_CODENAME}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/microsoft.gpg" | \
  sudo tee /etc/apt/sources.list.d/azure-cli.sources

sudo apt-get update -y
sudo apt-get install -y azure-cli

echo "✅ Azure CLI instalado: $(az --version | head -1)"

# =============================================================================
# FASE 2: Instalar Packer CLI
# =============================================================================
echo ""
echo "[FASE 2/3] Instalando Packer CLI..."

# Importar clave GPG de HashiCorp
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Agregar repositorio de HashiCorp (forzamos jammy para Pop!_OS)
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com ${UBUNTU_CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -y
sudo apt-get install -y packer

echo "✅ Packer instalado: $(packer --version)"

# =============================================================================
# FASE 3: Configurar Azure — Resource Group y Service Principal
# =============================================================================
echo ""
echo "[FASE 3/3] Configurando Azure (Resource Group + Service Principal)..."
echo ""
echo "⚠️  Necesitas iniciar sesión en Azure primero."
echo "    Se abrirá el flujo de autenticación az login..."
echo ""

az login

# Obtener Subscription ID activa
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Crear Resource Group
echo ""
echo "Creando Resource Group '$RESOURCE_GROUP' en '$LOCATION'..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

# Crear Service Principal con rol Contributor en el Resource Group
echo ""
echo "Creando Service Principal '$SP_NAME'..."
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  --output json)

# Extraer valores
CLIENT_ID=$(echo "$SP_OUTPUT"     | python3 -c "import sys,json; print(json.load(sys.stdin)['appId'])")
CLIENT_SECRET=$(echo "$SP_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")
TENANT_ID=$(echo "$SP_OUTPUT"     | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant'])")

# Crear el archivo de variables listo para usar
cat > azure.pkrvars.hcl << EOF
# ⚠️  NO subir este archivo a Git
client_id       = "$CLIENT_ID"
client_secret   = "$CLIENT_SECRET"
subscription_id = "$SUBSCRIPTION_ID"
tenant_id       = "$TENANT_ID"

resource_group  = "$RESOURCE_GROUP"
location        = "West US"
image_name      = "ubuntu-nodejs-nginx"
EOF

echo ""
echo "============================================="
echo " ✅  Setup completado exitosamente"
echo "============================================="
echo ""
echo " Azure CLI:  $(az --version | head -1)"
echo " Packer:     $(packer --version)"
echo ""
echo " Resource Group : $RESOURCE_GROUP ($LOCATION)"
echo " Service Principal: $SP_NAME"
echo ""
echo " Se generó automáticamente el archivo: azure.pkrvars.hcl"
echo " ⚠️  Agrégalo a .gitignore — contiene credenciales sensibles."
echo ""
echo " Siguiente paso:"
echo "   packer init     azure-nodejs.pkr.hcl"
echo "   packer validate -var-file=azure.pkrvars.hcl azure-nodejs.pkr.hcl"
echo "   packer build    -var-file=azure.pkrvars.hcl azure-nodejs.pkr.hcl"
