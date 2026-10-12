mock_provider "azurerm" {}

run "reject_padded_vnet" {
  command = plan
  variables {
    vnet_cidr = "10.020.0.0/16"
  }
  expect_failures = [var.vnet_cidr]
}

run "reject_invalid_prefix" {
  command = plan
  variables {
    prefix = "Bad_prefix!"
  }
  expect_failures = [var.prefix]
}

run "reject_unsupported_environment" {
  command = plan
  variables {
    environment = "prod"
  }
  expect_failures = [var.environment]
}

run "reject_public_vnet" {
  command = plan
  variables {
    vnet_cidr = "8.8.0.0/16"
  }
  expect_failures = [var.vnet_cidr]
}

run "reject_narrow_vnet" {
  command = plan
  variables {
    vnet_cidr = "10.0.0.0/24"
  }
  expect_failures = [var.vnet_cidr]
}

run "reject_noncanonical_vnet" {
  command = plan
  variables {
    vnet_cidr = "10.0.1.0/16"
  }
  expect_failures = [var.vnet_cidr]
}

run "reject_malformed_vnet" {
  command = plan
  variables {
    vnet_cidr = "not-a-cidr"
  }
  expect_failures = [var.vnet_cidr]
}

run "reject_invalid_octet" {
  command = plan
  variables {
    vnet_cidr = "10.999.0.0/16"
  }
  expect_failures = [var.vnet_cidr]
}

run "reject_public_https_source" {
  command = plan
  variables {
    https_source_cidrs = ["8.8.8.8/32"]
  }
  expect_failures = [var.https_source_cidrs]
}

run "reject_open_https_source" {
  command = plan
  variables {
    https_source_cidrs = ["0.0.0.0/0"]
  }
  expect_failures = [var.https_source_cidrs]
}

run "reject_overbroad_private_source" {
  command = plan
  variables {
    https_source_cidrs = ["10.0.0.0/7"]
  }
  expect_failures = [var.https_source_cidrs]
}

run "reject_noncanonical_https_source" {
  command = plan
  variables {
    https_source_cidrs = ["10.42.0.1/24"]
  }
  expect_failures = [var.https_source_cidrs]
}

run "reject_ipv6_https_source" {
  command = plan
  variables {
    https_source_cidrs = ["fd00::/64"]
  }
  expect_failures = [var.https_source_cidrs]
}

run "reject_malformed_https_source" {
  command = plan
  variables {
    https_source_cidrs = ["10.42.0.0/nope"]
  }
  expect_failures = [var.https_source_cidrs]
}

run "reject_null_https_entry" {
  command = plan
  variables {
    https_source_cidrs = [null]
  }
  expect_failures = [var.https_source_cidrs]
}
