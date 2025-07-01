# Vault ACL Templating Lab

This lab demonstrates two different approaches to ACL templating in Vault:
1. **AppRole Authentication** with namespace-specific entity metadata templating
2. **Userpass Authentication** with identity groups and group-based templating

## Architecture

### AppRole Demo
- **Namespaces**: bu01, bu02, bu03
- **AppRoles**: Each namespace has one AppRole with team-specific metadata
- **Policies**: ACL templated policies that dynamically resolve paths based on entity metadata
- **Secrets**: Team-specific and shared secrets created by `secrets.sh`

### Userpass Demo
- **Authentication**: Global userpass backend with users alice, bob, and jim
- **User Assignment**: alice (bu01), bob (bu02), jim (bu03)
- **Identity Groups**: Named internal groups (team1-group, team2-group, team3-group) with metadata in each namespace
- **Policies**: Namespace-specific templated policies using `{{identity.groups.names.<group-name>.metadata.id}}` ACL templating
- **Access Pattern**: Group membership dynamically resolves team paths using group metadata

## Terraform Configuration

This lab uses an optimized Terraform configuration with the following improvements:

### Centralized Configuration
```hcl
locals {
  business_units = {
    bu01 = { namespace = "bu01", team = "team1" }
    bu02 = { namespace = "bu02", team = "team2" }
    bu03 = { namespace = "bu03", team = "team3" }
  }
  
  approle_config = {
    token_ttl      = 300
    token_max_ttl  = 600
    bind_secret_id = true
  }
}
```

### Policy Template with `vault_policy_document`
- Uses `data "vault_policy_document"` for structured policy definition
- Single `replace()` function instead of multiple `format()` arguments
- Consistent policy structure across all business units

### Consolidated Outputs
```hcl
output "app_role_ids" {
  value = {
    bu01 = vault_approle_auth_backend_role.bu01.role_id
    bu02 = vault_approle_auth_backend_role.bu02.role_id
    bu03 = vault_approle_auth_backend_role.bu03.role_id
  }
}
```

### Benefits
- **DRY Principle**: Centralized configuration eliminates duplication
- **Maintainability**: Easy to add new business units or modify settings
- **Consistency**: All resources use the same configuration patterns
- **Readability**: Clear separation of configuration from implementation

## Setup

1. Deploy the Terraform configuration:
```bash
terraform init
terraform plan
terraform apply
```

2. Create test secrets:
```bash
./secrets.sh
```

## Demo Examples

This lab provides two authentication methods to demonstrate different ACL templating approaches.

# AppRole Authentication Examples

### BU01 AppRole (Team1)

**Get credentials from Terraform outputs:**
```bash
export VAULT_ADDR=http://127.0.0.1:8200
export ROLE_ID=$(terraform output -json app_role_ids | jq -r '.bu01')
export SECRET_ID=$(terraform output -json app_secret_ids | jq -r '.bu01')
```

**Authenticate with AppRole:**
```bash
# Login to get client token
export VAULT_TOKEN=$(vault write -namespace=bu01 -field=token auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID")
vault token lookup
```

**Fetch team-specific secrets:**
```bash
# Team1 secrets (accessible due to ACL templating with team-id=team1)
vault kv get -namespace=bu01 team1/app1
vault kv get -namespace=bu01 team1/app2
vault kv get -namespace=bu01 team1/app3

# Shared secrets (accessible to all teams)
vault kv get -namespace=bu01 shared/team1/app1
vault kv get -namespace=bu01 shared/team1/app2
vault kv get -namespace=bu01 shared/team1/app3

# This will FAIL - cannot access team1 or team3 secrets
vault kv get -namespace=bu01 team2/app1  # Access denied

```

**Example output:**
```bash
$ vault kv get -namespace=bu01 team1/app1
====== Data ======
Key         Value
---         -----
password    secure
username    wibble
```

### BU02 AppRole (Team2)

**Get credentials:**
```bash
export VAULT_ADDR=http://127.0.0.1:8200
export ROLE_ID=$(terraform output -json app_role_ids | jq -r '.bu02')
export SECRET_ID=$(terraform output -json app_secret_ids | jq -r '.bu02')
```

**Authenticate:**
```bash
export VAULT_TOKEN=$(vault write -namespace=bu02 -field=token auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID")
vault token lookup 
```

**Fetch secrets:**
```bash
# Team2 secrets (accessible due to ACL templating with team-id=team2)
vault kv get -namespace=bu02 team2/app1
vault kv get -namespace=bu02 team2/app2
vault kv get -namespace=bu02 team2/app3

# Shared secrets
vault kv get -namespace=bu02 shared/team2/app1
vault kv get -namespace=bu02 shared/team2/app2
vault kv get -namespace=bu02 shared/team2/app3

# This will FAIL - cannot access team1 or team3 secrets
vault kv get -namespace=bu02 team1/app1  # Access denied
```

### BU03 AppRole (Team3)

**Get credentials:**
```bash
export VAULT_ADDR=http://127.0.0.1:8200
export ROLE_ID=$(terraform output -json app_role_ids | jq -r '.bu03')
export SECRET_ID=$(terraform output -json app_secret_ids | jq -r '.bu03')
```

**Authenticate:**
```bash
export VAULT_TOKEN=$(vault write -namespace=bu03 -field=token auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID")
vault token lookup    
```

**Fetch secrets:**
```bash
# Team3 secrets (accessible due to ACL templating with team-id=team3)
vault kv get -namespace=bu03 team3/app1
vault kv get -namespace=bu03 team3/app2
vault kv get -namespace=bu03 team3/app3

# Shared secrets
vault kv get -namespace=bu03 shared/team3/app1
vault kv get -namespace=bu03 shared/team3/app2
vault kv get -namespace=bu03 shared/team3/app3
```

## Programmatic Access Examples

### Using curl

```bash
# Get AppRole token
VAULT_TOKEN=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
    http://localhost:8200/v1/bu01/auth/approle/login | jq -r '.auth.client_token')

# Fetch secret
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "X-Vault-Namespace: bu01" \
    http://localhost:8200/v1/team1/data/app1 | jq '.data.data'
```


**How it works:**
1. AppRole metadata includes `team` (team1, team2, team3)
2. During authentication, Vault creates an entity with this metadata
3. Policy template `{{identity.entity.aliases.<accessor>.metadata.team}}` resolves to the actual team
4. The `<accessor>` is dynamically replaced with each auth backend's accessor ID
5. Each team can only access their own team-specific secrets

## Secret Structure

Based on `secrets.sh`, the following secrets are created:

**BU01 Namespace:**
- `shared/team1/app1-3` - Shared secrets for team1
- `shared/team2/app1-3` - Shared secrets for team2  
- `shared/team3/app1-3` - Shared secrets for team3
- `team1/app1-3` - Team1-specific secrets

**BU02 & BU03 Namespaces:**
- `shared/team1/app1-3` - Shared secrets for team1
- `shared/team2/app1-3` - Shared secrets for team2
- `shared/team3/app1-3` - Shared secrets for team3

## Troubleshooting

**Access Denied Errors:**
- Verify the AppRole metadata matches the secret path
- Check that the entity has the correct metadata after authentication
- Ensure you're using the correct namespace

**Policy Debugging:**
```bash
# Set Vault address
export VAULT_ADDR=http://127.0.0.1:8200

# Check effective policies
vault token lookup -namespace=bu01

# Test policy capabilities
vault policy list -namespace=bu01
vault policy read -namespace=bu01 approle-templated-policy
```

# Userpass Authentication with Identity Groups Examples

## Users and Groups

The userpass demo creates the following users and group assignments:
- **alice**: Member of team1-group in bu01 namespace, can access team1 secrets
- **bob**: Member of team2-group in bu02 namespace, can access team2 secrets  
- **jim**: Member of team3-group in bu03 namespace, can access team3 secrets

## Userpass Authentication Examples

### Alice (BU01 → Team1) Authentication

**Authenticate with userpass:**
```bash
# Set Vault address and login as alice
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(vault login -field=token -method=userpass username=alice password=password123)
vault token lookup
```

**Access team1 secrets in bu01 namespace:**
```bash
# Alice can access team1 secrets in bu01 (her assigned namespace)
vault kv get -namespace=bu01 team1/app1
vault kv get -namespace=bu01 team1/app2
vault kv get -namespace=bu01 team1/app3

# Alice can access shared team1 secrets in bu01
vault kv get -namespace=bu01 shared/team1/app1
vault kv get -namespace=bu01 shared/team1/app2
vault kv get -namespace=bu01 shared/team1/app3

# This will FAIL - alice cannot access team2 or team3 secrets
vault kv get -namespace=bu01 team2/app1  # Access denied
vault kv get -namespace=bu01 team3/app1  # Access denied
```

### Bob (BU02 → Team2) Authentication

**Authenticate with userpass:**
```bash
# Set Vault address and login as bob
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(vault login -field=token -method=userpass username=bob password=password123)
vault token lookup
```

**Access team2 secrets in bu02 namespace:**
```bash
# Bob can access team2 secrets in bu02 (his assigned namespace)
vault kv get -namespace=bu02 team2/app1
vault kv get -namespace=bu02 team2/app2
vault kv get -namespace=bu02 team2/app3

# Bob can access shared team2 secrets in bu02
vault kv get -namespace=bu02 shared/team2/app1
vault kv get -namespace=bu02 shared/team2/app2
vault kv get -namespace=bu02 shared/team2/app3

# This will FAIL - bob cannot access team1 or team3 secrets
vault kv get -namespace=bu02 team1/app1  # Access denied
vault kv get -namespace=bu02 team3/app1  # Access denied
```

### Jim (BU03 → Team3) Authentication

**Authenticate with userpass:**
```bash
# Set Vault address and login as jim
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(vault login -field=token -method=userpass username=jim password=password123)
vault token lookup
```

**Access team3 secrets in bu03 namespace:**
```bash
# Jim can access team3 secrets in bu03 (his assigned namespace)
vault kv get -namespace=bu03 team3/app1
vault kv get -namespace=bu03 team3/app2
vault kv get -namespace=bu03 team3/app3

# Jim can access shared team3 secrets in bu03
vault kv get -namespace=bu03 shared/team3/app1
vault kv get -namespace=bu03 shared/team3/app2
vault kv get -namespace=bu03 shared/team3/app3

# This will FAIL - jim cannot access team1 or team2 secrets
vault kv get -namespace=bu03 team1/app1  # Access denied
vault kv get -namespace=bu03 team2/app1  # Access denied
```

**Example output:**
```bash
$ vault kv get -namespace=bu01 team1/app1
====== Data ======
Key         Value
---         -----
password    secure
username    wibble
```

## Userpass Demo Verification

**Check user credentials from Terraform outputs:**
```bash
# Set Vault address
export VAULT_ADDR=http://127.0.0.1:8200

# View demo credentials (sensitive output)
terraform output -json userpass_demo_credentials

# Check entity and group IDs
terraform output -json userpass_user_entity_ids
terraform output -json userpass_group_ids
```

**Verify identity group membership:**
```bash
# Check alice's entity and group membership
vault read identity/entity/name/alice
vault read -namespace=bu01 identity/group/name/team1-group

# Check bob's entity and group membership  
vault read identity/entity/name/bob
vault read -namespace=bu02 identity/group/name/team2-group

# Check jim's entity and group membership
vault read identity/entity/name/jim
vault read -namespace=bu03 identity/group/name/team3-group
```

**Policy debugging:**
```bash
# Check the templated policies (same policy in all namespaces)
vault policy read -namespace=bu01 group-templated-policy
vault policy read -namespace=bu02 group-templated-policy
vault policy read -namespace=bu03 group-templated-policy

# Test policy capabilities for specific paths
vault token capabilities -namespace=bu01 team1/data/app1
vault token capabilities -namespace=bu02 team2/data/app1
vault token capabilities -namespace=bu03 team3/data/app1
```

## How Group-Based Access Control Works

1. **User Authentication**: Alice/Bob/Jim authenticate via userpass in root namespace
2. **Entity Creation**: Vault creates identity entities (no metadata)
3. **Group Membership**: Users are assigned to named groups (team1-group, team2-group, team3-group) in their respective namespaces
4. **Group Metadata**: Each group has metadata with team identifier (`id = "team1"`, `id = "team2"`, `id = "team3"`)
5. **Policy Assignment**: Each namespace has a specific `group-templated-policy` with ACL templating
6. **Dynamic Access**: Each policy uses `{{identity.groups.names.<group-name>.metadata.id}}` to dynamically resolve paths based on group metadata
7. **Path Resolution**: Group metadata determines accessible paths (team1-group with id="team1" → team1/* paths)

### Policy Examples

Each namespace uses a specific templated policy with correct group metadata access:

**BU01 Group-Templated Policy (for team1-group):**
```hcl
# Dynamic path based on group metadata using correct ACL templating
path "{{identity.groups.names.team1-group.metadata.id}}/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
  description  = "Access to team secrets based on team1-group metadata"
}

# Dynamic metadata access
path "{{identity.groups.names.team1-group.metadata.id}}/metadata" {
  capabilities = ["read", "list"]  
}

path "{{identity.groups.names.team1-group.metadata.id}}/metadata/*" {
  capabilities = ["read"]
}

# Dynamic shared secrets access using group metadata templating
path "shared/data/{{identity.groups.names.team1-group.metadata.id}}/*" {
  capabilities = ["read", "list"]
  description  = "Read access to shared team secrets based on team1-group metadata"
}

# ACL templating for entity self-management
path "identity/entity/id/{{identity.entity.id}}" {
  capabilities = ["read", "update"]
  description  = "Users can manage their own entity metadata"
}
```

**Similar policies exist for BU02 (team2-group) and BU03 (team3-group)**

**How the correct metadata templating works:**
- When alice (member of team1-group with metadata id="team1") accesses secrets, `{{identity.groups.names.team1-group.metadata.id}}` resolves to `team1`
- When bob (member of team2-group with metadata id="team2") accesses secrets, `{{identity.groups.names.team2-group.metadata.id}}` resolves to `team2`
- When jim (member of team3-group with metadata id="team3") accesses secrets, `{{identity.groups.names.team3-group.metadata.id}}` resolves to `team3`
- The group name (team1-group) is explicitly referenced, and the metadata.id provides the functional identifier (team1) used in paths

## Comparison: AppRole vs Userpass Templating

| Feature | AppRole Demo | Userpass Demo |
|---------|--------------|---------------|
| **Authentication** | Namespace-specific AppRoles | Global userpass backend |
| **User Assignment** | alice→bu01, bob→bu02, jim→bu03 | alice→bu01, bob→bu02, jim→bu03 |
| **Entity Metadata** | Secret ID metadata (`team=team1/2/3`) | No entity metadata |
| **Policy Scope** | Per-namespace policies | Per-namespace templated policies |
| **Template Syntax** | `{{identity.entity.aliases.<accessor>.metadata.team}}` | `{{identity.groups.names.<group-name>.metadata.id}}` |
| **Group Management** | No identity groups | Named internal groups with metadata (team1-group, team2-group, team3-group) |
| **Access Pattern** | Dynamic team access via entity metadata templating | Dynamic team access via group metadata templating |
| **Policy Type** | Fully templated policies | Namespace-specific templated policies with group metadata resolution |
| **Scalability** | New AppRole per namespace | Add users to team-named groups |