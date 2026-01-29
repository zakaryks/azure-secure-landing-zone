# Azure Secure Landing Zone (Terraform)

Ce projet déploie une infrastructure de base sécurisée sur Microsoft Azure en utilisant l'Infrastructure as Code (Terraform).

## Objectifs
- **Automatisation :** Déploiement complet sans intervention manuelle.
- **Sécurité by Design :**
  - Segmentation réseau (VNet / Subnets).
  - Filtrage strict des flux via Network Security Groups (NSG).
  - Blocage par défaut des ports d'administration (SSH/RDP) exposés.
- **Conformité :** Code audité via Trivy (IaC Scanning).

## Architecture
- **Resource Group :** Conteneur logique isolé.
- **VNet :** 10.0.0.0/16
- **Subnet App :** 10.0.1.0/24 (Protégé par NSG).
- **NSG :** Règles Inbound strictes (Deny All sauf HTTPS).

## Comment déployer
1. Pré-requis : Terraform & Azure CLI.
2. Initialiser : `terraform init`
3. Vérifier le plan : `terraform plan`
4. Appliquer : `terraform apply`

## Audit de Sécurité
Le code est scanné avec **Trivy** pour détecter les mauvaises configurations cloud avant le déploiement.