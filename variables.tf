variable "location" {
  description = "Région Azure du lab."
  type        = string
  default     = "francecentral"
  nullable    = false
}

variable "prefix" {
  description = "Préfixe des ressources (3 à 20 caractères minuscules, chiffres ou tirets)."
  type        = string
  default     = "demo-sec"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.prefix))
    error_message = "Le préfixe doit commencer par une lettre, finir par une lettre ou un chiffre et contenir 3 à 20 caractères."
  }
}

variable "environment" {
  description = "Étiquette d'environnement ; le lab n'est pas une plateforme de production."
  type        = string
  default     = "lab"
  nullable    = false

  validation {
    condition     = contains(["lab", "dev", "test"], var.environment)
    error_message = "Les environnements acceptés sont lab, dev et test."
  }
}

variable "vnet_cidr" {
  description = "Réseau IPv4 privé /16. Les sous-réseaux app et data sont dérivés en /24."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false

  validation {
    condition = can(regex(
      "^(10\\.([0-9]{1,3})|172\\.(1[6-9]|2[0-9]|3[01])|192\\.168)\\.0\\.0/16$",
      var.vnet_cidr
    )) && can(cidrnetmask(var.vnet_cidr)) && try(cidrsubnet(var.vnet_cidr, 0, 0) == var.vnet_cidr, false)
    error_message = "Utiliser un réseau privé /16 valide, par exemple 10.20.0.0/16, 172.16.0.0/16 ou 192.168.0.0/16."
  }
}

variable "https_source_cidrs" {
  description = "Réseaux IPv4 privés autorisés à joindre app en HTTPS. Vide : aucun accès entrant. La connectivité VPN/peering est à fournir séparément."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = length(var.https_source_cidrs) <= 20 && alltrue([
      for cidr in var.https_source_cidrs : try(
        cidrnetmask(cidr) != "" && cidrsubnet(cidr, 0, 0) == cidr && (
          (can(regex("^10\\.", cidr)) && tonumber(split("/", cidr)[1]) >= 8) ||
          (can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", cidr)) && tonumber(split("/", cidr)[1]) >= 12) ||
          (can(regex("^192\\.168\\.", cidr)) && tonumber(split("/", cidr)[1]) >= 16)
        ), false
      )
    ])
    error_message = "Fournir au plus 20 CIDR IPv4 privés canoniques (RFC 1918), sans adresse publique ni plage trop large."
  }
}
