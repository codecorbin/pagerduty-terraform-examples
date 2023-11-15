locals {
  region_brands = {
    for rb in setproduct(var.regions,var.brands) : "${rb[0]}${rb[1]}" => {
        region = rb[0]
        brand = rb[1]
    }
  }
}

data "pagerduty_escalation_policy" "ecommerce_ep" {
  name = "SN:E-Commerce"
}

resource "pagerduty_service" "brand_services" {
  for_each  = local.region_brands
  name                    = "cx-${each.value.region}-${each.value.brand}-service"
  auto_resolve_timeout    = 14400
  acknowledgement_timeout = 600
  escalation_policy       = data.pagerduty_escalation_policy.ecommerce_ep.id
  alert_creation          = "create_alerts_and_incidents"

  auto_pause_notifications_parameters {
    enabled = true
    timeout = 300
  }
}

resource "pagerduty_business_service" "brand_bservices" {
  for_each = pagerduty_service.brand_services
  name             = "${each.value.name}"
  description      = "Brands for North America region"

}

resource "pagerduty_business_service" "region_bservices" {
  name = "cx-${each.value}-region"
  description = "Business service for all brands in this region"
  for_each = var.regions
}

resource "pagerduty_service_dependency" "brand_dependencies" {
    for_each = local.region_brands
    dependency {
        dependent_service {
            id = pagerduty_business_service.brand_bservices["${each.value.region}${each.value.brand}"].id
            type = pagerduty_business_service.brand_bservices["${each.value.region}${each.value.brand}"].type
        }
        supporting_service {
            id = pagerduty_service.brand_services["${each.value.region}${each.value.brand}"].id
            type = pagerduty_service.brand_services["${each.value.region}${each.value.brand}"].type
        }
    }
}

resource "pagerduty_service_dependency" "region_brands_dependencies" {
  for_each = local.region_brands
  dependency {
    dependent_service {
      id = pagerduty_business_service.region_bservices[each.value.region].id
      type = pagerduty_business_service.region_bservices[each.value.region].type
    }
    supporting_service {
      id = pagerduty_business_service.brand_bservices["${each.value.region}${each.value.brand}"].id
      type = pagerduty_business_service.brand_bservices["${each.value.region}${each.value.brand}"].type
    }
  }
}

resource "pagerduty_business_service" "cx_global_service" {
    name = "cx-global-service"
    description = "Business Service for all regions globally"
}

resource "pagerduty_business_service" "online_prod_cx" {
    name = "online-prod-cx"
    description = "Top level business service for all online brands"
}

resource "pagerduty_service_dependency" "global_regions_dependencies" {
  for_each = var.regions
  dependency {
    dependent_service {
      id = pagerduty_business_service.cx_global_service.id
      type = pagerduty_business_service.cx_global_service.type
    }
    supporting_service {
      id = pagerduty_business_service.region_bservices[each.value].id
      type = pagerduty_business_service.region_bservices[each.value].type
    }
  }
}

resource "pagerduty_service_dependency" "top_global_dependencies" {
  dependency {
    dependent_service {
      id = pagerduty_business_service.online_prod_cx.id
      type = pagerduty_business_service.online_prod_cx.type
    }
    supporting_service {
      id = pagerduty_business_service.cx_global_service.id
      type = pagerduty_business_service.cx_global_service.type
    }
  }
}

resource "pagerduty_business_service" "brand1_all_regions_bservice" {
  name = "Brand 1 - All Regions"
  description = "Business service that represents a single brand across all regions"
}

resource "pagerduty_service_dependency" "brand1_all_regions_dependencies" {
  for_each = var.regions
  dependency {
    dependent_service {
      id = pagerduty_business_service.brand1_all_regions_bservice.id
      type = pagerduty_business_service.brand1_all_regions_bservice.type
    }
    supporting_service {
      id = pagerduty_business_service.brand_bservices["${each.value}${tolist(var.brands)[0]}"].id
      type = pagerduty_business_service.brand_bservices["${each.value}${tolist(var.brands)[0]}"].type
    }
  }
}