# ===========================================================================
# Network Module
# Provisions: VNet, Subnets, NSGs, NAT Gateway, Private DNS Zones,
#             Azure Bastion (Standard SKU), Azure Front Door Standard
#             (WAF, HTTPS-only), APIM (External VNet, FDID header validation)
# ===========================================================================

locals {
  prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Virtual Network
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "aca_infra" {
  name                 = "snet-aca-infra"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.0.0/23"]

  delegation {
    name = "aca-infra-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "aca_apps" {
  name                 = "snet-aca-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.2.0/23"]

  delegation {
    name = "aca-apps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                                          = "snet-privateendpoints"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = ["10.10.4.0/24"]
  private_endpoint_network_policies_enabled     = false
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.5.0/26"]
}

resource "azurerm_subnet" "redis" {
  name                 = "snet-redis"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.6.0/27"]
}

resource "azurerm_subnet" "devops_agents" {
  name                 = "snet-devops-agents"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.7.0/26"]
}

resource "azurerm_subnet" "bastion" {
  # Must be named AzureBastionSubnet
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.8.0/27"]
}

# APIM requires a dedicated /27 or larger subnet when using VNet integration.
resource "azurerm_subnet" "apim" {
  name                 = "snet-apim"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.9.0/27"]
}

# ---------------------------------------------------------------------------
# NSGs
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "aca_infra" {
  name                = "nsg-aca-infra-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowACAInfraInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aca_infra" {
  subnet_id                 = azurerm_subnet.aca_infra.id
  network_security_group_id = azurerm_network_security_group.aca_infra.id
}

resource "azurerm_network_security_group" "aca_apps" {
  name                = "nsg-aca-apps-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aca_apps" {
  subnet_id                 = azurerm_subnet.aca_apps.id
  network_security_group_id = azurerm_network_security_group.aca_apps.id
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-pe-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-appgw-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_network_security_group" "redis" {
  name                = "nsg-redis-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Only SSL port 6380 is permitted. Port 6379 (non-SSL) is blocked because
  # non_ssl_port_enabled = false is set on the Redis cache resource.
  security_rule {
    name                       = "AllowRedisSSLInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "redis" {
  subnet_id                 = azurerm_subnet.redis.id
  network_security_group_id = azurerm_network_security_group.redis.id
}

resource "azurerm_network_security_group" "devops_agents" {
  name                = "nsg-agents-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowOutboundHTTPS"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "devops_agents" {
  subnet_id                 = azurerm_subnet.devops_agents.id
  network_security_group_id = azurerm_network_security_group.devops_agents.id
}

# NSG for APIM subnet — required ports per Microsoft documentation
resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowAPIMManagementInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowFrontDoorToAPIMInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

# ---------------------------------------------------------------------------
# NAT Gateway (deterministic outbound IP for ACA apps subnet)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                    = "natgw-${local.prefix}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aca_apps" {
  subnet_id      = azurerm_subnet.aca_apps.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ---------------------------------------------------------------------------
# Azure Bastion (Standard SKU)
# Note: session_recording_enabled is not supported in azurerm ~> 3.110.
# Session recording must be configured manually or via az cli after deployment.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "bas-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  shareable_link_enabled = false

  ip_configuration {
    name                 = "bas-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# ---------------------------------------------------------------------------
# Private DNS Zones
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "pdnsl-sql-${local.prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "pdnsl-kv-${local.prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "pdnsl-acr-${local.prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "pdnsl-redis-${local.prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "pdnsl-blob-${local.prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# ---------------------------------------------------------------------------
# Azure Front Door Standard + WAF
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "afd-${local.prefix}"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "fdep-${local.prefix}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                     = "og-web"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "web" {
  name                          = "origin-web"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                       = true

  certificate_name_check_enabled = true
  host_name                      = var.web_ca_fqdn != "" ? var.web_ca_fqdn : "placeholder.azurecontainerapps.io"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = var.web_ca_fqdn != "" ? var.web_ca_fqdn : "placeholder.azurecontainerapps.io"
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_rule_set" "main" {
  name                     = "defaultruleset"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

resource "azurerm_cdn_frontdoor_rule" "https_redirect" {
  name                      = "EnforceHTTPS"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.main.id
  order                     = 1
  behavior_on_match         = "Continue"

  conditions {
    request_scheme_condition {
      operator     = "Equal"
      match_values = ["HTTP"]
    }
  }

  actions {
    url_redirect_action {
      redirect_type        = "PermanentRedirect"
      redirect_protocol    = "Https"
      destination_hostname = ""
    }
  }
}

resource "azurerm_cdn_frontdoor_rule" "cache_static" {
  name                      = "CacheStaticAssets"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.main.id
  order                     = 2
  behavior_on_match         = "Continue"

  conditions {
    url_path_condition {
      operator     = "BeginsWith"
      match_values = ["/images/", "/css/", "/js/", "/fonts/"]
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior                = "OverrideIfOriginMissing"
      cache_duration                = "1.00:00:00"
      query_string_caching_behavior = "IgnoreQueryString"
    }
  }
}

resource "azurerm_cdn_frontdoor_route" "web" {
  name                          = "route-web"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.web.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.main.id]

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Https"]
  link_to_default_domain = true
  enabled                = true
}

# ---------------------------------------------------------------------------
# WAF Policy
# ---------------------------------------------------------------------------
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                              = "wafpolicy${replace(local.prefix, "-", "")}"
  resource_group_name               = var.resource_group_name
  sku_name                          = "Standard_AzureFrontDoor"
  enabled                           = true
  mode                              = "Prevention"
  redirect_url                      = "https://contoso.com/blocked"
  custom_block_response_status_code = 403
  tags                              = var.tags

  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  custom_rule {
    name                           = "RateLimitLogin"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 5
    rate_limit_threshold           = 100
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["/account/login"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "secpol-${local.prefix}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Azure API Management (External VNet integration)
# ---------------------------------------------------------------------------
resource "azurerm_api_management" "main" {
  name                = "apim-${local.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "eShopOnWeb"
  publisher_email     = var.apim_publisher_email
  sku_name            = "Developer_1"
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  virtual_network_type = "External"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  protocols {
    enable_http2 = true
  }

  security {
    enable_backend_ssl30  = false
    enable_backend_tls10  = false
    enable_backend_tls11  = false
    enable_frontend_ssl30 = false
    enable_frontend_tls10 = false
    enable_frontend_tls11 = false
  }
}

resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.main.id

  xml_content = <<XML
<policies>
  <inbound>
    <choose>
      <when condition="@(context.Request.Headers.GetValueOrDefault(&quot;X-Azure-FDID&quot;, &quot;&quot;) != &quot;${var.front_door_profile_resource_guid}&quot;)">
        <return-response>
          <set-status code="403" reason="Forbidden" />
          <set-body>Access denied: requests must originate via Azure Front Door.</set-body>
        </return-response>
      </when>
    </choose>
    <base />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ---------------------------------------------------------------------------
# Diagnostic settings for NAT GW and Front Door
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "nat_gw" {
  name                       = "diag-natgw-${local.prefix}"
  target_resource_id         = azurerm_nat_gateway.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "front_door" {
  name                       = "diag-afd-${local.prefix}"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
