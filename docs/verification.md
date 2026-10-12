# Vérifier le lab

## Contrôles sans Azure

`terraform test` contrôle la configuration calculée, avec des appels Azure simulés. Le test des associations utilise des IDs fictifs au format Azure. Le scan Trivy détecte certaines mauvaises configurations ; un scan vert n'est pas un certificat de sécurité.

La CI ne possède aucun identifiant Azure et n'exécute pas de déploiement réel.

## Après un déploiement

Les commandes ci-dessous utilisent les noms par défaut. Les adapter si `prefix` change.

```sh
terraform plan -detailed-exitcode
az network vnet subnet list --resource-group demo-sec-rg --vnet-name demo-sec-vnet --query "[].{name:name,cidr:addressPrefix,nsg:networkSecurityGroup.id,defaultOutbound:defaultOutboundAccess}" -o json
az network nsg rule list --resource-group demo-sec-rg --nsg-name demo-sec-nsg -o table
az network nsg rule list --resource-group demo-sec-rg --nsg-name demo-sec-data-nsg -o table
```

Le second plan doit terminer avec le code **0** (aucune différence). Le code 2 indique des changements, le code 1 une erreur. Vérifier que chaque sous-réseau possède son propre NSG et que `defaultOutbound` vaut `false`.

Avec les valeurs par défaut, le NSG app contient une autorisation sortante TCP 5432 et deux refus globaux. Le NSG data contient l'autorisation entrante correspondante et deux refus globaux. Aucun `AllowHTTPS` n'apparaît tant que la liste des sources est vide.

## Vérifier une décision réseau avec Network Watcher

Cette étape est facultative et nécessite **deux VM de test en marche**, une par sous-réseau, ainsi que Network Watcher dans leur région et les droits de lecture/diagnostic. Ces ressources ne sont pas créées par ce dépôt et peuvent être facturées. Ne pas ouvrir SSH ou ajouter une IP publique pour ce contrôle.

Exemple Bash, après avoir remplacé les noms des VM et des interfaces :

```sh
RG="demo-sec-rg"
APP_VM="nom-vm-app"
APP_NIC="nom-interface-app"
DATA_VM="nom-vm-data"
DATA_NIC="nom-interface-data"
APP_IP="$(az network nic show -g "$RG" -n "$APP_NIC" --query 'ipConfigurations[0].privateIPAddress' -o tsv)"
DATA_IP="$(az network nic show -g "$RG" -n "$DATA_NIC" --query 'ipConfigurations[0].privateIPAddress' -o tsv)"

# App peut initier le flux PostgreSQL.
az network watcher test-ip-flow -g "$RG" --vm "$APP_VM" --nic "$APP_NIC" --direction Outbound --protocol TCP --local "$APP_IP:50000" --remote "$DATA_IP:5432"

# Data peut le recevoir.
az network watcher test-ip-flow -g "$RG" --vm "$DATA_VM" --nic "$DATA_NIC" --direction Inbound --protocol TCP --local "$DATA_IP:5432" --remote "$APP_IP:50000"

# SSH doit être refusé.
az network watcher test-ip-flow -g "$RG" --vm "$DATA_VM" --nic "$DATA_NIC" --direction Inbound --protocol TCP --local "$DATA_IP:22" --remote "$APP_IP:50000"

# Data ne peut pas initier une connexion vers app.
az network watcher test-ip-flow -g "$RG" --vm "$DATA_VM" --nic "$DATA_NIC" --direction Outbound --protocol TCP --local "$DATA_IP:50000" --remote "$APP_IP:443"
```

Résultats attendus, dans l'ordre : `Allow`, `Allow`, `Deny`, `Deny`. Si une NIC porte aussi un NSG, ses règles s'appliquent également.

[IP flow verify](https://learn.microsoft.com/azure/network-watcher/ip-flow-verify-overview) explique la décision des règles réseau ; il ne teste ni un serveur PostgreSQL, ni TLS, ni le routage de bout en bout. Un test applicatif demande un service réellement en écoute et un client déjà connecté au réseau privé. Tester de nouvelles connexions après un changement de règle, car les connexions existantes sont conservées.

## Depuis la première version

- Sauvegarder le state et rester dans le même dossier de travail, avec les mêmes variables de noms et de région. Lire le [guide AzureRM 4](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide) et définir `ARM_SUBSCRIPTION_ID`.
- Exécuter `terraform init` pour installer la version 4 verrouillée, puis `terraform plan`. Ne pas utiliser `init -upgrade` à chaque déploiement : le lock est versionné.
- Les adresses Terraform du groupe, VNet, sous-réseau app et NSG app restent identiques. Le bloc `moved` renomme l'association `example` en `app` sans la recréer.
- Avec les valeurs initiales, app reste en `10.0.1.0/24`. Le plan ajoute data et son NSG, ferme HTTPS par défaut et remplace les règles permissives par des refus explicites. Cela peut couper des accès existants : vérifier les besoins avant d'appliquer.
- Pour des VM déjà présentes, désactiver l'accès sortant implicite peut nécessiter leur désallocation puis redémarrage. Prévoir cette interruption avant de modifier un lab utilisé ; voir les [subnets privés Azure](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access).
- Aucun `destroy` n'est nécessaire pour migrer. Une proposition de remplacement inattendue doit être examinée avant application.

## Garder une preuve utile

Après avoir réellement fait le déploiement, conserver la date, le commit testé, un lien vers la CI et un court résultat du second plan et des diagnostics. Masquer les IDs d'abonnement et les informations personnelles avant publication. Après nettoyage, vérifier `terraform state list` (vide) et `az group exists --name demo-sec-rg` (`false`).

Ces éléments permettent d'expliquer ce qui a été testé, ce qui ne l'a pas été et pourquoi un flux est autorisé ou refusé.
