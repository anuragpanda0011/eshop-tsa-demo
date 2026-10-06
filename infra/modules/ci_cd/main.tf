###############################################################################
# Azure Front Door Premium — WAF + CDN + Global LB
###############################################################################
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                     = "afd-${var.project}-${var.environment}"
  resource_group_name      = var.resource_group_name
  sku_name                 = "Premium_AzureFrontDoor"
  response_timeout_seconds = 60
  tags                     = var.tags
}

###############################################################################
# Front Door Endpoints
###############################################################################
resource "azurerm_cdn_frontdoor_endpoint" "web" {
  name                     = "fde-${var.project}-web-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "api" {
  name                     = "fde-${var.project}-api-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

###############################################################################
# Origin Groups
###############################################################################
resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                     = "og-web-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "api" {
  name                     = "og-api-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

###############################################################################
# Origins
###############################################################################
resource "azurerm_cdn_frontdoor_origin" "web" {
  name                          = "origin-web-${var.environment}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                       = true

  host_name          = var.web_app_hostname
  origin_host_header = var.web_app_hostname
  priority           = 1
  weight             = 1000

  certificate_name_check_enabled = true

  private_link {
    request_message        = "Please approve eShop Front Door private link"
    target_type            = "sites"
    location               = var.location
    private_link_target_id = var.web_app_id
  }
}

resource "azurerm_cdn_frontdoor_origin" "api" {
  name                          = "origin-api-${var.environment}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api.id
  enabled                       = true

  host_name          = var.api_app_hostname
  origin_host_header = var.api_app_hostname
  priority           = 1
  weight             = 1000

  certificate_name_check_enabled = true

  private_link {
    request_message        = "Please approve eShop API Front Door private link"
    target_type            = "sites"
    location               = var.location
    private_link_target_id = var.api_app_id
  }
}

###############################################################################
# WAF Policy
###############################################################################
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                              = "wafpolicy${var.project}${var.environment}"
  resource_group_name               = var.resource_group_name
  sku_name                          = azurerm_cdn_frontdoor_profile.main.sku_name
  enabled                           = true
  mode                              = "Prevention"
  redirect_url                      = "https://${var.custom_domain_name}/error/blocked"
  custom_block_response_status_code = 403
  tags                              = var.tags

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  custom_rule {
    name                           = "RateLimitPerIP"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 1000
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "SocketAddr"
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["255.255.255.255/32"]
    }
  }

  custom_rule {
    name     = "BlockNonHTTPS"
    enabled  = true
    priority = 200
    type     = "MatchRule"
    action   = "Redirect"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["http://"]
    }
  }
}

###############################################################################
# Security Policy (attach WAF to profile)
###############################################################################
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "sec-policy-${var.project}-${var.environment}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.web.id
        }
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.api.id
        }
      }
    }
  }
}

###############################################################################
# Rule Sets
###############################################################################
resource "azurerm_cdn_frontdoor_rule_set" "caching" {
  name                     = "cachingrules"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

# Cache product images for 7 days
resource "azurerm_cdn_frontdoor_rule" "cache_images" {
  depends_on                = [azurerm_cdn_frontdoor_origin.web, azurerm_cdn_frontdoor_origin_group.web]
  name                      = "CacheProductImages"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.caching.id
  order                     = 1
  behavior_on_match         = "Continue"

  conditions {
    url_path_condition {
      operator         = "BeginsWith"
      negate_condition = false
      match_values     = ["/images/products/"]
      transforms       = ["Lowercase"]
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior                = "OverrideIfOriginMissing"
      cache_duration                = "7.00:00:00"
      query_string_caching_behavior = "IgnoreQueryString"
      compression_enabled           = true
    }
  }
}

# Cache static assets for 30 days
resource "azurerm_cdn_frontdoor_rule" "cache_static" {
  depends_on                = [azurerm_cdn_frontdoor_origin.web, azurerm_cdn_frontdoor_origin_group.web]
  name                      = "CacheStaticAssets"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.caching.id
  order                     = 2
  behavior_on_match         = "Continue"

  conditions {
    url_path_condition {
      operator         = "BeginsWith"
      negate_condition = false
      match_values     = ["/css/", "/js/", "/lib/"]
      transforms       = ["Lowercase"]
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior                = "OverrideIfOriginMissing"
      cache_duration                = "30.00:00:00"
      query_string_caching_behavior = "IgnoreQueryString"
      compression_enabled           = true
    }
  }
}

# No cache for API routes
resource "azurerm_cdn_frontdoor_rule" "no_cache_api" {
  depends_on                = [azurerm_cdn_frontdoor_origin.api, azurerm_cdn_frontdoor_origin_group.api]
  name                      = "NoCacheAPI"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.caching.id
  order                     = 3
  behavior_on_match         = "Continue"

  conditions {
    url_path_condition {
      operator         = "BeginsWith"
      negate_condition = false
      match_values     = ["/api/"]
      transforms       = ["Lowercase"]
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior = "Disabled"
    }
  }
}

###############################################################################
# Routes
###############################################################################
resource "azurerm_cdn_frontdoor_route" "web" {
  name                          = "route-web-${var.environment}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.web.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.web.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.caching.id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true
}

resource "azurerm_cdn_frontdoor_route" "api" {
  name                          = "route-api-${var.environment}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.api.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.api.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.caching.id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/api/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true
}

###############################################################################
# Custom Domain + TLS (managed certificate)
###############################################################################
resource "azurerm_cdn_frontdoor_custom_domain" "web" {
  name                     = "custom-domain-web"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  dns_zone_id              = data.azurerm_dns_zone.main.id
  host_name                = var.custom_domain_name

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "web" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.web.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.web.id]
}

###############################################################################
# DNS Zone data source + CNAME record
###############################################################################
data "azurerm_dns_zone" "main" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

resource "azurerm_dns_cname_record" "web" {
  name                = split(".", var.custom_domain_name)[0]
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 300
  record              = azurerm_cdn_frontdoor_endpoint.web.host_name
}

resource "azurerm_dns_txt_record" "web_validation" {
  name                = "_dnsauth.${split(".", var.custom_domain_name)[0]}"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 300

  record {
    value = azurerm_cdn_frontdoor_custom_domain.web.validation_token
  }
}

###############################################################################
# Diagnostic Settings — Front Door
###############################################################################
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = "diag-afd-${var.environment}"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontDoorAccessLog"
  }
  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }
  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
