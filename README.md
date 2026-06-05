# Packer Labs 🧪

Repositorio de prácticas con HashiCorp Packer para la creación de imágenes
de máquina virtual inmutables en entornos multinube.

## Prácticas

| Lab | Descripción | Nube | Stack |
|-----|-------------|------|-------|
| [lab1-nodejs-nginx](./lab1-nodejs-nginx) | Imagen con Node.js + PM2 + Nginx | Azure (West US) | Ubuntu 22.04 LTS |

## Requisitos generales

- [Packer CLI](https://developer.hashicorp.com/packer/downloads) v1.10+
- [Azure CLI](https://learn.microsoft.com/es-mx/cli/azure/install-azure-cli) v2.50+
- Cuenta Azure con suscripción activa

## Estructura
packer-labs/
├── README.md
├── .gitignore
└── lab1-nodejs-nginx/
├── azure-nodejs.pkr.hcl        # Template Packer HCL2
├── azure.pkrvars.hcl.example   # Variables de ejemplo (sin credenciales)
├── deploy.sh                   # Despliegue automatizado
├── setup-azure.sh              # Script de prerrequisitos
└── app/
├── hello.js                # Aplicación Node.js
└── ecosystem.config.js     # Configuración PM2

## Materia
Herramientas de DevOps — UNIR — Maestría en Desarrollo y Operaciones de Software
