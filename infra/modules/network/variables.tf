variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "subnet_aca_infra_cidr" {
  type    = string
  default = "10.10.0.0/23"
}

variable "subnet_aca_apps_cidr" {
  type    = string
  default = "10.10.2.0/23"
}

variable "subnet_pe_cidr" {
  type    = string
  default = "10.10.4.0/24"
}

variable "subnet_appgw_cidr" {
  type    = string
  default = "10.10.5.0/26"
}

variable "subnet_redis_cidr" {
  type    = string
  default = "10.10.6.0/27"
}

variable "subnet_agents_cidr" {
  type    = string
  default = "10.10.7.0/26"
}

variable "subnet_bastion_cidr" {
  type    = string
  default = "10.10.8.0/27"
}

variable "subnet_apim_cidr" {
  type        = string
  default     = "10.10.9.0/27"
  description = "CIDR block for the APIM dedicated subnet (External VNet mode requires /27 or larger)."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics Workspace for diagnostic settings and flow log traffic analytics."
}

variable "log_analytics_workspace_guid" {
  type        = string
  description = "Workspace GUID (not resource ID) required by traffic analytics in NSG flow logs."
}

variable "custom_domain" {
  type    = string
  default = "shop.contoso.com"
}

variable "dns_zone_name" {
  type    = string
  default = "contoso.com"
}

variable "dns_zone_resource_group" {
  type    = string
  default = "rg-dns"
}

variable "aca_web_fqdn" {
  type        = string
  default     = ""
  description = "FQDN of the ACA web container app (populated after compute module runs, used by Front Door origin). Empty on first apply — use two-phase apply documented in README."
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID used to configure CMK on the flow-log storage account."
}

variable "data_protection_key_name" {
  type        = string
  description = "Key Vault key name for CMK on the flow-log storage account. Must match the key created in the security module."
}

variable "network_watcher_name" {
  type        = string
  default     = "NetworkWatcher_eastus2"
  description = "Name of the Azure Network Watcher. Defaults to the Azure-created default for the primary region. Override if your subscription uses a custom name."
}

variable "network_watcher_resource_group" {
  type        = string
  default     = "NetworkWatcherRG"
  description = "Resource group containing the Azure Network Watcher. Override if your subscription uses a non-default resource group."
}
