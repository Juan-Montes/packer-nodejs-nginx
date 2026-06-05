#!/bin/bash
# =============================================================================
# deploy.sh — Ejercicio 2: Despliegue totalmente automático
# Encadena: packer build → az vm create → verificación con curl
# Sin intervención manual en ningún paso
# Materia: Herramientas DevOps - UNIR
# =============================================================================

set -euo pipefail

# --- Configuración ---
RESOURCE_GROUP="rg-packer-devops"
LOCATION="westus"
IMAGE_NAME="ubuntu-nodejs-nginx"
VM_NAME="vm-nodejs-nginx-auto"
ADMIN_USER="azureuser"
VAR_FILE="azure.pkrvars.hcl"
TEMPLATE="azure-nodejs.pkr.hcl"

echo "============================================="
echo " Ejercicio 2 — Despliegue Automatizado"
echo " Stack: Node.js + PM2 + Nginx en Azure"
echo "============================================="
echo ""

# =============================================================================
# PASO 1: Build de la imagen con Packer
# =============================================================================
echo "[PASO 1/4] Construyendo imagen con Packer..."
echo " Template : $TEMPLATE"
echo " Variables: $VAR_FILE"
echo ""

packer build -force -var-file="$VAR_FILE" "$TEMPLATE"

echo ""
echo "✅ Imagen '$IMAGE_NAME' generada exitosamente en Azure."
echo ""

# =============================================================================
# PASO 2: Crear la VM desde la imagen generada
# =============================================================================
echo "[PASO 2/4] Creando VM desde la imagen Packer..."

# Eliminar VM anterior si existe (idempotencia)
if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &>/dev/null; then
  echo " VM existente encontrada, eliminando..."
  az vm delete \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --yes --no-wait
  sleep 15
fi

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --image "$IMAGE_NAME" \
  --admin-username "$ADMIN_USER" \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  --size Standard_D2s_v3 \
  --location "$LOCATION" \
  --output table

echo ""
echo "✅ VM '$VM_NAME' creada exitosamente."
echo ""

# =============================================================================
# PASO 3: Abrir puerto 80 en el NSG
# =============================================================================
echo "[PASO 3/4] Abriendo puerto 80 (HTTP)..."

az vm open-port \
  --port 80 \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --output table

echo ""
echo "✅ Puerto 80 abierto."
echo ""

# =============================================================================
# PASO 4: Verificar que la aplicación responde
# =============================================================================
echo "[PASO 4/4] Verificando la aplicación..."

# Obtener IP pública
PUBLIC_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps \
  --output tsv)

echo " IP pública: $PUBLIC_IP"
echo " Esperando 30 segundos para que los servicios arranquen..."
sleep 30

# Verificar respuesta HTTP con reintentos
MAX_RETRIES=5
COUNT=0
SUCCESS=false

while [ $COUNT -lt $MAX_RETRIES ]; do
  echo " Intento $((COUNT + 1))/$MAX_RETRIES..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$PUBLIC_IP" || true)

  if [ "$HTTP_STATUS" = "200" ]; then
    SUCCESS=true
    break
  fi
  COUNT=$((COUNT + 1))
  sleep 10
done

echo ""
if [ "$SUCCESS" = true ]; then
  echo "============================================="
  echo " ✅ DESPLIEGUE COMPLETADO EXITOSAMENTE"
  echo "============================================="
  echo ""
  echo " URL: http://$PUBLIC_IP"
  echo ""
  echo " Respuesta de la aplicación:"
  curl -s "http://$PUBLIC_IP" | python3 -m json.tool
else
  echo "⚠️  La aplicación no respondió en $MAX_RETRIES intentos."
  echo "   Verifica manualmente: curl http://$PUBLIC_IP"
fi

echo ""
echo " VM Name      : $VM_NAME"
echo " Resource Group: $RESOURCE_GROUP"
echo " Región        : $LOCATION"
echo " IP Pública    : $PUBLIC_IP"
