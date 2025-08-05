# Azure AD Groups
resource "azuread_group" "groups" {
  for_each = var.azure_groups

  display_name     = each.value.display_name
  description      = each.value.description
  security_enabled = true
}

# Azure AD Users
resource "azuread_user" "users" {
  for_each = var.azure_users

  user_principal_name   = "${each.key}@${data.azuread_domains.tenant.domains[0].domain_name}"
  display_name          = each.value.display_name
  given_name            = each.value.given_name
  surname               = each.value.surname
  password              = each.value.password
  force_password_change = false
}

# Data source for existing users
data "azuread_user" "existing_users" {
  for_each            = var.existing_users
  user_principal_name = "${each.key}@${data.azuread_domains.tenant.domains[0].domain_name}"
}

# Group Memberships
locals {
  # Flatten user-to-group mappings for created users
  user_group_memberships = flatten([
    for user_key, user in var.azure_users : [
      for group_name in user.group_memberships : {
        user_key  = user_key
        group_key = group_name
        user_id   = azuread_user.users[user_key].object_id
        group_id  = azuread_group.groups[group_name].object_id
      }
    ]
  ])

  # Add existing users to their specified groups
  existing_user_memberships = flatten([
    for user_key, user in var.existing_users : [
      for group_name in user.groups : {
        user_key  = user_key
        group_key = group_name
        user_id   = data.azuread_user.existing_users[user_key].object_id
        group_id  = azuread_group.groups[group_name].object_id
      }
    ]
  ])

  # Combine both managed and existing user memberships
  all_memberships = concat(local.user_group_memberships, local.existing_user_memberships)
}

resource "azuread_group_member" "memberships" {
  for_each = {
    for membership in local.all_memberships :
    "${membership.user_key}-${membership.group_key}" => membership
  }

  group_object_id  = each.value.group_id
  member_object_id = each.value.user_id
}