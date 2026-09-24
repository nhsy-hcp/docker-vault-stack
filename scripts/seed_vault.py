#!/usr/bin/env python3
"""Seed a dev Vault instance with dummy namespaces, auth methods, secrets engines, and KV v2 data."""

# /// script
# requires-python = ">=3.12"
# dependencies = ["hvac>=2.2.0", "requests>=2.32"]
# ///

import argparse
import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import hvac
import requests

VAULT_ADDR = os.getenv("VAULT_ADDR", "http://localhost:8200")
VAULT_TOKEN = os.getenv("VAULT_TOKEN", "root")

_stats_lock = threading.Lock()
_stats: dict[str, int] = {"added": 0, "skipped": 0, "errors": 0}

# Errors a Vault API call can raise; anything else is a bug and should surface
VAULT_ERRORS = (hvac.exceptions.VaultError, requests.exceptions.RequestException)


def _record(key: str, n: int = 1) -> None:
    with _stats_lock:
        _stats[key] += n


# Top-level namespaces use tenant IDs (tn001-tn010); children/grandchildren
# use meaningful names reflecting the workloads each tenant runs.
TOP_LEVEL_NAMESPACES = [
    "tn001",
    "tn002",
    "tn003",
    "tn004",
    "tn005",
    "tn006",
    "tn007",
    "tn008",
    "tn009",
    "tn010",
]

CHILD_NAMESPACES: dict[str, list[str]] = {
    "tn001": ["kubernetes", "ci-cd", "observability"],  # platform engineering
    "tn002": ["payments-service", "auth-service", "notification-service"],  # eng
    "tn003": ["secrets-mgmt", "iam", "threat-intel"],  # security
    "tn004": ["data-warehouse", "ml-platform", "streaming"],  # data platform
    "tn005": ["accounting", "treasury", "regulatory-reporting"],  # finance
    "tn006": ["network", "storage", "cloud-compute"],  # infrastructure
    "tn007": ["web-app", "mobile-app", "api-gateway"],  # product
    "tn008": ["incident-mgmt", "deployment", "monitoring"],  # operations
    "tn009": ["gdpr", "pci-dss", "soc2"],  # compliance
    "tn010": ["experiments", "prototypes", "training"],  # sandbox
}

_GRANDCHILD_ENVS = ["prod", "staging", "dev"]
GRANDCHILD_NAMESPACES: dict[str, list[str]] = {
    child: _GRANDCHILD_ENVS
    for child in [
        "kubernetes",
        "ci-cd",
        "observability",
        "payments-service",
        "auth-service",
        "notification-service",
        "secrets-mgmt",
        "iam",
        "threat-intel",
        "data-warehouse",
        "ml-platform",
        "streaming",
        "accounting",
        "treasury",
        "regulatory-reporting",
        "network",
        "storage",
        "cloud-compute",
        "web-app",
        "mobile-app",
        "api-gateway",
        "incident-mgmt",
        "deployment",
        "monitoring",
        "gdpr",
        "pci-dss",
        "soc2",
        "experiments",
        "prototypes",
        "training",
    ]
}

ACL_POLICIES: dict[str, str] = {
    "read-only": """
path "secret/data/*" { capabilities = ["read", "list"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
""",
    "kv-writer": """
path "secret/data/*" { capabilities = ["create", "read", "update", "delete", "list"] }
path "secret/metadata/*" { capabilities = ["read", "list", "delete"] }
""",
    "pki-issuer": """
path "pki/issue/*" { capabilities = ["create", "update"] }
path "pki/cert/*"  { capabilities = ["read"] }
path "pki/crl"     { capabilities = ["read"] }
""",
    "transit-encrypt": """
path "transit/encrypt/*" { capabilities = ["create", "update"] }
path "transit/decrypt/*" { capabilities = ["create", "update"] }
""",
    "db-creds-reader": """
path "database/creds/*" { capabilities = ["read"] }
path "database/roles/*" { capabilities = ["read", "list"] }
""",
    "approle-login": """
path "auth/approle/login" { capabilities = ["create", "read"] }
""",
    "admin": """
path "*" { capabilities = ["create", "read", "update", "delete", "list", "sudo"] }
""",
    "auditor": """
path "sys/audit"        { capabilities = ["read", "list"] }
path "sys/audit/*"      { capabilities = ["read"] }
path "secret/data/*"   { capabilities = ["read", "list"] }
path "auth/*"           { capabilities = ["read", "list"] }
""",
}

CHILD_NS_POLICIES: dict[str, dict[str, str]] = {
    "kubernetes": {
        "k8s-pod-identity": 'path "auth/kubernetes/login" { capabilities = ["create", "read"] }',
        "k8s-secret-reader": 'path "secret/data/k8s/*" { capabilities = ["read", "list"] }',
        "k8s-namespace-admin": 'path "sys/namespaces/*" { capabilities = ["read", "list"] }\npath "sys/auth/*" { capabilities = ["read"] }',
    },
    "ci-cd": {
        "ci-deploy-secrets": 'path "secret/data/ci/*" { capabilities = ["read"] }\npath "auth/approle/login" { capabilities = ["create"] }',
        "artifact-writer": 'path "secret/data/artifacts/*" { capabilities = ["create", "update", "read"] }',
        "pipeline-token-creator": 'path "auth/token/create" { capabilities = ["create", "update"] }',
    },
    "observability": {
        "metrics-reader": 'path "secret/data/metrics/*" { capabilities = ["read", "list"] }',
        "log-writer": 'path "secret/data/logs/*" { capabilities = ["create", "update"] }',
        "trace-admin": 'path "secret/data/traces/*" { capabilities = ["create", "read", "update", "delete", "list"] }',
    },
    "payments-service": {
        "payments-pci-reader": 'path "secret/data/payments/*" { capabilities = ["read"] }',
        "stripe-key-accessor": 'path "secret/data/stripe/*" { capabilities = ["read"] }',
        "fraud-analyst": 'path "secret/data/fraud/*" { capabilities = ["read", "list"] }',
    },
    "auth-service": {
        "oauth2-token-manager": 'path "auth/token/create" { capabilities = ["create", "update"] }\npath "auth/token/lookup" { capabilities = ["read"] }',
        "mfa-secret-reader": 'path "secret/data/mfa/*" { capabilities = ["read"] }',
        "session-invalidator": 'path "auth/token/revoke" { capabilities = ["update"] }',
    },
    "notification-service": {
        "email-sender-creds": 'path "secret/data/email/*" { capabilities = ["read"] }',
        "sms-gateway-reader": 'path "secret/data/sms/*" { capabilities = ["read"] }',
        "push-cert-reader": 'path "secret/data/push/*" { capabilities = ["read"] }',
    },
    "secrets-mgmt": {
        "rotation-operator": 'path "secret/data/*" { capabilities = ["create", "update"] }\npath "secret/metadata/*" { capabilities = ["list"] }',
        "lease-revoker": 'path "sys/leases/revoke" { capabilities = ["update"] }',
        "audit-log-reader": 'path "sys/audit" { capabilities = ["read"] }',
    },
    "iam": {
        "sso-integrator": 'path "auth/oidc/*" { capabilities = ["create", "read", "update"] }',
        "rbac-policy-manager": 'path "sys/policies/acl/*" { capabilities = ["create", "read", "update", "delete", "list"] }',
        "service-account-creator": 'path "identity/entity/*" { capabilities = ["create", "update", "read"] }',
    },
    "threat-intel": {
        "siem-log-writer": 'path "secret/data/siem/*" { capabilities = ["create", "update"] }',
        "alert-manager": 'path "secret/data/alerts/*" { capabilities = ["create", "read", "update", "list"] }',
        "playbook-executor": 'path "secret/data/playbooks/*" { capabilities = ["read"] }',
    },
    "data-warehouse": {
        "dw-read-only": 'path "secret/data/warehouse/*" { capabilities = ["read", "list"] }',
        "etl-writer": 'path "secret/data/etl/*" { capabilities = ["create", "update"] }',
        "analyst-token": 'path "auth/token/create" { capabilities = ["create"] }',
    },
    "ml-platform": {
        "model-artifact-reader": 'path "secret/data/models/*" { capabilities = ["read", "list"] }',
        "training-job-secrets": 'path "secret/data/training/*" { capabilities = ["read"] }',
        "feature-store-writer": 'path "secret/data/features/*" { capabilities = ["create", "update", "read"] }',
    },
    "streaming": {
        "kafka-producer-creds": 'path "secret/data/kafka/*" { capabilities = ["read"] }',
        "flink-job-secrets": 'path "secret/data/flink/*" { capabilities = ["read"] }',
        "connector-config-reader": 'path "secret/data/connectors/*" { capabilities = ["read", "list"] }',
    },
    "accounting": {
        "gl-writer": 'path "secret/data/ledger/*" { capabilities = ["create", "update"] }',
        "ap-ar-reader": 'path "secret/data/accounts/*" { capabilities = ["read", "list"] }',
        "reconciliation-auditor": 'path "secret/data/reconciliation/*" { capabilities = ["read"] }',
    },
    "treasury": {
        "fx-rates-reader": 'path "secret/data/fx/*" { capabilities = ["read", "list"] }',
        "liquidity-manager": 'path "secret/data/liquidity/*" { capabilities = ["read", "update"] }',
        "investment-reporter": 'path "secret/data/investments/*" { capabilities = ["read"] }',
    },
    "regulatory-reporting": {
        "basel3-submitter": 'path "secret/data/basel3/*" { capabilities = ["read", "update"] }',
        "mifid2-reporter": 'path "secret/data/mifid2/*" { capabilities = ["read"] }',
        "audit-trail-writer": 'path "secret/data/audit-trail/*" { capabilities = ["create", "update"] }',
    },
    "network": {
        "vpn-cert-reader": 'path "pki/issue/vpn" { capabilities = ["create", "update"] }',
        "dns-config-reader": 'path "secret/data/dns/*" { capabilities = ["read"] }',
        "lb-cert-manager": 'path "pki/issue/lb" { capabilities = ["create", "update"] }',
    },
    "storage": {
        "object-store-writer": 'path "secret/data/s3/*" { capabilities = ["create", "update", "read"] }',
        "block-storage-admin": 'path "secret/data/block/*" { capabilities = ["create", "read", "update", "delete"] }',
        "backup-reader": 'path "secret/data/backup/*" { capabilities = ["read", "list"] }',
    },
    "cloud-compute": {
        "aws-iam-reader": 'path "secret/data/aws/*" { capabilities = ["read"] }',
        "gcp-sa-accessor": 'path "secret/data/gcp/*" { capabilities = ["read"] }',
        "azure-sp-reader": 'path "secret/data/azure/*" { capabilities = ["read"] }',
    },
    "web-app": {
        "cdn-config-reader": 'path "secret/data/cdn/*" { capabilities = ["read"] }',
        "frontend-deploy-token": 'path "auth/token/create" { capabilities = ["create"] }',
        "design-token-writer": 'path "secret/data/design/*" { capabilities = ["create", "update"] }',
    },
    "mobile-app": {
        "ios-cert-reader": 'path "pki/issue/ios" { capabilities = ["create", "update"] }',
        "android-keystore-reader": 'path "secret/data/android/*" { capabilities = ["read"] }',
        "push-notification-creds": 'path "secret/data/push/*" { capabilities = ["read"] }',
    },
    "api-gateway": {
        "rate-limit-config-reader": 'path "secret/data/ratelimit/*" { capabilities = ["read"] }',
        "routing-config-writer": 'path "secret/data/routing/*" { capabilities = ["create", "update"] }',
        "auth-proxy-token": 'path "auth/token/lookup" { capabilities = ["read"] }',
    },
    "incident-mgmt": {
        "oncall-reader": 'path "secret/data/oncall/*" { capabilities = ["read", "list"] }',
        "runbook-editor": 'path "secret/data/runbooks/*" { capabilities = ["create", "update", "read"] }',
        "postmortem-writer": 'path "secret/data/postmortems/*" { capabilities = ["create", "update"] }',
    },
    "deployment": {
        "canary-deployer": 'path "secret/data/canary/*" { capabilities = ["read", "update"] }',
        "blue-green-switcher": 'path "auth/token/create" { capabilities = ["create"] }',
        "rollback-executor": 'path "secret/data/rollback/*" { capabilities = ["read", "update"] }',
    },
    "monitoring": {
        "alerting-config-writer": 'path "secret/data/alerting/*" { capabilities = ["create", "update"] }',
        "dashboard-reader": 'path "secret/data/dashboards/*" { capabilities = ["read", "list"] }',
        "capacity-planner": 'path "secret/data/capacity/*" { capabilities = ["read", "update"] }',
    },
    "gdpr": {
        "consent-record-writer": 'path "secret/data/consent/*" { capabilities = ["create", "update"] }',
        "data-request-processor": 'path "secret/data/data-requests/*" { capabilities = ["read", "update"] }',
        "retention-policy-manager": 'path "secret/data/retention/*" { capabilities = ["read", "update"] }',
    },
    "pci-dss": {
        "cardholder-data-reader": 'path "secret/data/cardholder/*" { capabilities = ["read"] }',
        "scanner-config-reader": 'path "secret/data/scanner/*" { capabilities = ["read"] }',
        "remediation-writer": 'path "secret/data/remediation/*" { capabilities = ["create", "update"] }',
    },
    "soc2": {
        "controls-auditor": 'path "secret/data/controls/*" { capabilities = ["read", "list"] }',
        "evidence-collector": 'path "secret/data/evidence/*" { capabilities = ["create", "update", "read"] }',
        "audit-report-writer": 'path "secret/data/audit-reports/*" { capabilities = ["create", "update"] }',
    },
    "experiments": {
        "ab-test-config-writer": 'path "secret/data/ab-tests/*" { capabilities = ["create", "update", "read"] }',
        "feature-flag-manager": 'path "secret/data/feature-flags/*" { capabilities = ["create", "update", "delete", "read"] }',
        "analytics-reader": 'path "secret/data/analytics/*" { capabilities = ["read", "list"] }',
    },
    "prototypes": {
        "mvp-deploy-token": 'path "auth/token/create" { capabilities = ["create"] }',
        "demo-secret-writer": 'path "secret/data/demos/*" { capabilities = ["create", "update", "read", "delete"] }',
        "poc-reader": 'path "secret/data/poc/*" { capabilities = ["read", "list"] }',
    },
    "training": {
        "workshop-env-reader": 'path "secret/data/workshops/*" { capabilities = ["read"] }',
        "lab-secret-writer": 'path "secret/data/labs/*" { capabilities = ["create", "update", "delete"] }',
        "cert-tracker": 'path "secret/data/certs/*" { capabilities = ["create", "update", "read"] }',
    },
}

AUTH_METHODS: dict[str, list[dict]] = {
    "userpass": [{"path": "userpass", "description": "Username/password auth"}],
    "approle": [{"path": "approle", "description": "AppRole auth"}],
    "jwt": [{"path": "jwt", "description": "JWT / OIDC auth"}],
}

USERPASS_USERS: list[dict] = [
    {
        "username": "alice",
        "password": "Password1!",
        "policies": ["default", "kv-writer"],
    },
    {"username": "bob", "password": "Password1!", "policies": ["default", "read-only"]},
    {"username": "carol", "password": "Password1!", "policies": ["default", "auditor"]},
    {
        "username": "dave",
        "password": "Password1!",
        "policies": ["default", "read-only"],
    },
]

SECRETS_ENGINES: list[dict] = [
    {
        "path": "secret",
        "type": "kv",
        "options": {"version": "2"},
        "description": "KV v2 general secrets",
    },
    {
        "path": "database",
        "type": "database",
        "options": {},
        "description": "Database secrets engine",
    },
    {
        "path": "transit",
        "type": "transit",
        "options": {},
        "description": "Transit encryption",
    },
    {"path": "pki", "type": "pki", "options": {}, "description": "PKI / certificates"},
]

APPROLES: list[dict] = [
    {
        "name": "app-backend",
        "token_ttl": "1h",
        "token_max_ttl": "4h",
        "policies": ["default", "kv-writer"],
    },
    {
        "name": "app-worker",
        "token_ttl": "30m",
        "token_max_ttl": "2h",
        "policies": ["default", "read-only"],
    },
    {
        "name": "ci-deploy",
        "token_ttl": "15m",
        "token_max_ttl": "1h",
        "policies": ["default", "read-only"],
    },
]

PKI_ROLES: list[dict] = [
    {"name": "web-server", "allowed_domains": ["example.com"], "allow_subdomains": True, "max_ttl": "720h"},
    {"name": "client-auth", "allowed_domains": [], "client_flag": True, "max_ttl": "24h"},
    {"name": "internal-ca", "allowed_domains": ["internal"], "allow_subdomains": True, "max_ttl": "8760h"},
]

TRANSIT_KEYS: list[str] = ["app-encryption", "backup-key", "session-tokens"]

IDENTITY_ENTITIES: list[dict] = [
    {
        "name": "alice",
        "metadata": {"email": "alice@example.com", "team": "engineering"},
    },
    {"name": "bob", "metadata": {"email": "bob@example.com", "team": "platform"}},
    {"name": "carol", "metadata": {"email": "carol@example.com", "team": "security"}},
    {"name": "dave", "metadata": {"email": "dave@example.com", "team": "data"}},
    {"name": "svc-api", "metadata": {"type": "service", "owner": "engineering"}},
    {"name": "svc-worker", "metadata": {"type": "service", "owner": "engineering"}},
    {"name": "ci-bot", "metadata": {"type": "service", "owner": "platform"}},
]

IDENTITY_GROUPS: list[dict] = [
    {
        "name": "engineering-team",
        "policies": ["default"],
        "members": ["alice", "svc-api", "svc-worker"],
    },
    {
        "name": "platform-team",
        "policies": ["default"],
        "members": ["bob", "ci-bot"],
    },
    {
        "name": "security-team",
        "policies": ["default"],
        "members": ["carol"],
    },
    {
        "name": "data-team",
        "policies": ["default"],
        "members": ["dave"],
    },
]

KV_SECRETS: dict[str, dict[str, str]] = {
    "app/api": {
        "api_key": "dummy-api-key-abc123",  # gitleaks:allow
        "endpoint": "https://api.example.com",
    },
    "app/database": {
        "username": "db_user",
        "password": "s3cr3t!",
        "host": "db.internal",
    },
    "app/redis": {"password": "r3dis-p@ss", "port": "6379"},
    "infra/tls": {
        "cert": "-----BEGIN CERTIFICATE-----\nMIIDummy...",  # gitleaks:allow
        "key": "-----BEGIN PRIVATE KEY-----\nMIIDummy...",  # gitleaks:allow
    },
    "infra/ssh": {"private_key": "-----BEGIN RSA PRIVATE KEY-----\nMIIDummy..."},  # gitleaks:allow
    "service/payments": {
        "stripe_key": "sk_test_dummykey",
        "webhook_secret": "whsec_dummy",
    },
    "service/notifications": {
        "sendgrid_key": "SG.dummy",
        "from_email": "no-reply@example.com",
    },
    "team/devops": {
        "aws_access_key": "AKIADUMMY",
        "aws_secret_key": "dummysecret/dummy",
    },
}


def get_client(namespace: str | None = None) -> hvac.Client:
    client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN, namespace=namespace)
    # is_authenticated() raises on transport failure rather than returning False,
    # so an unreachable Vault must be caught separately from a bad token.
    try:
        authenticated = client.is_authenticated()
    except requests.exceptions.RequestException as exc:
        print(
            f"ERROR: cannot reach Vault at {VAULT_ADDR}: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)
    if not authenticated:
        print(
            f"ERROR: not authenticated (addr={VAULT_ADDR}, ns={namespace})",
            file=sys.stderr,
        )
        sys.exit(1)
    return client


def create_namespace(root_client: hvac.Client, path: str) -> bool:
    """Create a namespace using path-based routing from the root client.

    For nested namespaces (e.g. 'engineering/backend'), uses
    POST /v1/engineering/sys/namespaces/backend so the root token's privileges
    apply without switching namespace context.
    """
    try:
        if "/" in path:
            parent, name = path.rsplit("/", 1)
            root_client.adapter.request("POST", f"/v1/{parent}/sys/namespaces/{name}", json={})
        else:
            root_client.sys.create_namespace(path)
        print("  [+] created")
        _record("added")
        return True
    except VAULT_ERRORS as exc:
        msg = str(exc)
        if "already exists" in msg.lower() or "existing" in msg.lower():
            print("  [skip] already exists")
            _record("skipped")
            return True
        if "404" in msg or "unsupported" in msg.lower() or "path not found" in msg.lower():
            print("  [skip] namespaces not supported (OSS/dev mode)")
            _record("skipped")
            return False
        _record("errors")
        raise RuntimeError(f"cannot create namespace {path}: {exc}") from exc


def enable_auth(client: hvac.Client, method_type: str, path: str, description: str) -> None:
    try:
        client.sys.enable_auth_method(method_type=method_type, path=path, description=description)
        print(f"    [+] auth/{path}")
        _record("added")
    except VAULT_ERRORS as exc:
        if "already in use" in str(exc).lower() or "path is taken" in str(exc).lower():
            _record("skipped")
            return
        raise


def enable_secrets_engine(client: hvac.Client, path: str, engine_type: str, options: dict, description: str) -> None:
    try:
        client.sys.enable_secrets_engine(
            backend_type=engine_type,
            path=path,
            options=options,
            description=description,
        )
        print(f"    [+] {path}/ ({engine_type})")
        _record("added")
    except VAULT_ERRORS as exc:
        if "already in use" in str(exc).lower() or "path is taken" in str(exc).lower() or "existing mount" in str(exc).lower():
            _record("skipped")
            return
        raise


def create_approles(client: hvac.Client) -> None:
    for role in APPROLES:
        try:
            client.auth.approle.create_or_update_approle(
                role_name=role["name"],
                token_ttl=role["token_ttl"],
                token_max_ttl=role["token_max_ttl"],
                token_policies=role["policies"],
            )
            print(f"    [+] approle/{role['name']}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] approle/{role['name']}: {exc}")
            _record("errors")


def seed_kv(client: hvac.Client, mount: str = "secret") -> None:
    for secret_path, data in KV_SECRETS.items():
        client.secrets.kv.v2.create_or_update_secret(
            path=secret_path,
            secret=data,
            mount_point=mount,
        )
    print(f"    [+] {len(KV_SECRETS)} secrets written to {mount}/")
    _record("added", len(KV_SECRETS))


def _has_pki_issuer(client: hvac.Client, mount: str) -> bool:
    try:
        resp = client.list(f"{mount}/issuers")
    except hvac.exceptions.InvalidPath:
        return False
    return bool(resp and resp.get("data", {}).get("keys"))


def seed_pki(client: hvac.Client, mount: str = "pki") -> None:
    try:
        # Re-runs would otherwise add another root issuer each time (multi-issuer PKI)
        if not _has_pki_issuer(client, mount):
            client.write_data(f"{mount}/root/generate/internal", data={"common_name": "Example Root CA", "ttl": "87600h"})
            print(f"    [+] {mount}/root CA")
            _record("added")
        client.write_data(
            f"{mount}/config/urls",
            data={"issuing_certificates": f"{VAULT_ADDR}/v1/{mount}/ca", "crl_distribution_points": f"{VAULT_ADDR}/v1/{mount}/crl"},
        )
    except VAULT_ERRORS as exc:
        print(f"    [warn] {mount}/root CA: {exc}")
        _record("errors")
    for role in PKI_ROLES:
        name = role["name"]
        try:
            client.write_data(f"{mount}/roles/{name}", data={k: v for k, v in role.items() if k != "name"})
            print(f"    [+] {mount}/roles/{name}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] {mount}/roles/{name}: {exc}")
            _record("errors")


def seed_transit(client: hvac.Client, mount: str = "transit") -> None:
    for key_name in TRANSIT_KEYS:
        try:
            client.write_data(f"{mount}/keys/{key_name}")
            print(f"    [+] {mount}/keys/{key_name}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] {mount}/keys/{key_name}: {exc}")
            _record("errors")


def create_userpass_users(client: hvac.Client) -> None:
    for user in USERPASS_USERS:
        try:
            client.auth.userpass.create_or_update_user(
                username=user["username"],
                password=user["password"],
                policies=user["policies"],
            )
            print(f"    [+] userpass/{user['username']}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] userpass/{user['username']}: {exc}")
            _record("errors")


def generate_userpass_clients(client: hvac.Client) -> None:
    """Login via each userpass account and read KV secrets to generate client activity."""
    kv_paths = list(KV_SECRETS.keys())
    for user in USERPASS_USERS:
        try:
            login_resp = client.auth.userpass.login(
                username=user["username"],
                password=user["password"],
                use_token=False,
            )
            user_token = login_resp["auth"]["client_token"]
            user_client = hvac.Client(
                url=VAULT_ADDR,
                token=user_token,
                namespace=client.adapter.namespace,
            )
            reads = denied = 0
            for path in kv_paths:
                try:
                    user_client.secrets.kv.v2.read_secret_version(path=path, mount_point="secret", raise_on_deleted_version=True)
                    reads += 1
                except VAULT_ERRORS:
                    denied += 1
            print(f"    [+] userpass client activity: {user['username']} ({reads} reads, {denied} denied)")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] userpass client activity {user['username']}: {exc}")
            _record("errors")


def _get_mount_accessor(client: hvac.Client, mount_path: str) -> str | None:
    """Return the accessor for a given auth mount path (e.g. 'userpass/')."""
    try:
        mounts = client.sys.list_auth_methods().get("data", {})
    except VAULT_ERRORS:
        return None
    entry = mounts.get(mount_path) or mounts.get(f"{mount_path}/")
    return entry.get("accessor") if entry else None


def seed_identity(client: hvac.Client) -> None:
    entity_ids: dict[str, str] = {}
    for e in IDENTITY_ENTITIES:
        try:
            client.write_data(
                "identity/entity",
                data={
                    "name": e["name"],
                    "metadata": e.get("metadata", {}),
                },
            )
            # Always look up by name to get the canonical ID (write may return None on update)
            lookup = client.read(f"identity/entity/name/{e['name']}")
            if lookup and "data" in lookup and lookup["data"].get("id"):
                entity_ids[e["name"]] = lookup["data"]["id"]
            print(f"    [+] identity/entity/{e['name']}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] identity/entity/{e['name']}: {exc}")
            _record("errors")

    # Create userpass aliases for human users so the identity page shows aliases
    userpass_names = {u["username"] for u in USERPASS_USERS}
    userpass_accessor = _get_mount_accessor(client, "userpass/")
    if userpass_accessor:
        for name, entity_id in entity_ids.items():
            if name not in userpass_names:
                continue
            try:
                client.write_data(
                    "identity/entity-alias",
                    data={
                        "name": name,
                        "canonical_id": entity_id,
                        "mount_accessor": userpass_accessor,
                    },
                )
                print(f"    [+] identity/alias userpass/{name}")
                _record("added")
            except VAULT_ERRORS as exc:
                if "already exists" in str(exc).lower():
                    print(f"    [skip] identity/alias userpass/{name} (exists)")
                    _record("skipped")
                else:
                    print(f"    [warn] identity/alias userpass/{name}: {exc}")
                    _record("errors")

    # Create approle aliases for service entities
    approle_accessor = _get_mount_accessor(client, "approle/")
    service_to_approle = {
        "svc-api": "app-backend",
        "svc-worker": "app-worker",
        "ci-bot": "ci-deploy",
    }
    if approle_accessor:
        for entity_name, role_name in service_to_approle.items():
            entity_id = entity_ids.get(entity_name)
            if not entity_id:
                continue
            try:
                # AppRole logins map to aliases named after the role_id, not the role name
                role_id = client.auth.approle.read_role_id(role_name=role_name)["data"]["role_id"]
                client.write_data(
                    "identity/entity-alias",
                    data={
                        "name": role_id,
                        "canonical_id": entity_id,
                        "mount_accessor": approle_accessor,
                    },
                )
                print(f"    [+] identity/alias approle/{role_name} -> {entity_name}")
                _record("added")
            except VAULT_ERRORS as exc:
                if "already exists" in str(exc).lower():
                    print(f"    [skip] identity/alias approle/{role_name} (exists)")
                    _record("skipped")
                else:
                    print(f"    [warn] identity/alias approle/{role_name}: {exc}")
                    _record("errors")

    for g in IDENTITY_GROUPS:
        member_ids = [entity_ids[n] for n in g.get("members", []) if n in entity_ids]
        try:
            client.write_data(
                "identity/group",
                data={
                    "name": g["name"],
                    "type": "internal",
                    "member_entity_ids": member_ids,
                    "policies": g.get("policies", []),
                },
            )
            print(f"    [+] identity/group/{g['name']}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] identity/group/{g['name']}: {exc}")
            _record("errors")


def generate_approle_clients(client: hvac.Client) -> None:
    """Login via each AppRole and read KV secrets to generate client activity."""
    kv_paths = list(KV_SECRETS.keys())
    for role in APPROLES:
        role_name = role["name"]
        try:
            role_id_resp = client.auth.approle.read_role_id(role_name=role_name)
            role_id = role_id_resp["data"]["role_id"]

            secret_id_resp = client.auth.approle.generate_secret_id(role_name=role_name)
            secret_id = secret_id_resp["data"]["secret_id"]

            # use_token=False prevents hvac from mutating client.token to the approle token,
            # which would cause subsequent read_role_id calls for other roles to fail (permission denied).
            login_resp = client.auth.approle.login(role_id=role_id, secret_id=secret_id, use_token=False)
            approle_token = login_resp["auth"]["client_token"]

            approle_client = hvac.Client(
                url=VAULT_ADDR,
                token=approle_token,
                namespace=client.adapter.namespace,
            )
            reads = denied = 0
            for path in kv_paths:
                try:
                    approle_client.secrets.kv.v2.read_secret_version(path=path, mount_point="secret", raise_on_deleted_version=True)
                    reads += 1
                except VAULT_ERRORS:
                    denied += 1
            print(f"    [+] approle client activity: {role_name} ({reads} reads, {denied} denied)")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] approle client activity {role_name}: {exc}")
            _record("errors")


def seed_policies(client: hvac.Client) -> None:
    for name, rules in ACL_POLICIES.items():
        try:
            client.sys.create_or_update_acl_policy(name=name, policy=rules.strip())
            print(f"    [+] policy/{name}")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] policy/{name}: {exc}")
            _record("errors")


def seed_child_policies(client: hvac.Client, child_name: str) -> None:
    """Seed workload-specific ACL policies for a child namespace."""
    policies = CHILD_NS_POLICIES.get(child_name, {})
    for name, rules in policies.items():
        try:
            client.sys.create_or_update_acl_policy(name=name, policy=rules.strip())
            print(f"    [+] policy/{name} (child-specific)")
            _record("added")
        except VAULT_ERRORS as exc:
            print(f"    [warn] policy/{name}: {exc}")
            _record("errors")


def seed_contents(client: hvac.Client) -> None:
    seed_policies(client)
    for method_type, mounts in AUTH_METHODS.items():
        for m in mounts:
            enable_auth(client, method_type, m["path"], m["description"])
    create_approles(client)
    create_userpass_users(client)
    for engine in SECRETS_ENGINES:
        enable_secrets_engine(
            client,
            engine["path"],
            engine["type"],
            engine["options"],
            engine["description"],
        )
    seed_kv(client, mount="secret")
    seed_pki(client, mount="pki")
    seed_transit(client, mount="transit")
    seed_identity(client)
    generate_approle_clients(client)
    generate_userpass_clients(client)


def _seed_grandchildren(root_client: hvac.Client, child_full: str) -> None:
    child = child_full.rsplit("/", maxsplit=1)[-1]
    for grandchild in GRANDCHILD_NAMESPACES.get(child, []):
        gc_full = f"{child_full}/{grandchild}"
        gc_indent = "  " * (gc_full.count("/") + 1)
        print(f"\n{gc_indent}[ns] {gc_full}")
        supported = create_namespace(root_client, path=gc_full)
        if not supported:
            break
        gc_client = get_client(namespace=gc_full)
        seed_contents(gc_client)
        seed_child_policies(gc_client, child)


def seed_namespace_tree(
    ns: str,
    parent_ns: str | None = None,
    root_client: hvac.Client | None = None,
    seed_self: bool = True,
) -> None:
    if root_client is None:
        root_client = get_client(namespace=None)
    full_path = f"{parent_ns}/{ns}" if parent_ns else ns
    indent = "  " * (full_path.count("/") + 1)
    print(f"\n{indent}[ns] {full_path}")

    supported = create_namespace(root_client, path=full_path)
    if not supported:
        print(f"{indent}  [skip] namespaces not supported on this Vault edition")
        return

    if seed_self:
        client = get_client(namespace=full_path)
        seed_contents(client)
    else:
        print(f"{indent}  [skip] no resources seeded in tenant namespace")

    children = CHILD_NAMESPACES.get(ns, [])
    if not children:
        return

    # Create all child namespaces first using root client + full path (must be sequential)
    active_children: list[str] = []
    for child in children:
        child_full = f"{full_path}/{child}"
        child_indent = "  " * (child_full.count("/") + 1)
        print(f"\n{child_indent}[ns] {child_full}")
        supported = create_namespace(root_client, path=child_full)
        if not supported:
            break
        active_children.append(child)

    # Seed child contents + grandchildren in parallel
    def _seed_child(child: str) -> None:
        child_full = f"{full_path}/{child}"
        child_client = get_client(namespace=child_full)
        seed_contents(child_client)
        _seed_grandchildren(root_client, child_full)

    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(_seed_child, child): child for child in active_children}
        for fut in as_completed(futures):
            exc = fut.exception()
            if exc:
                print(f"  [error] child {futures[fut]}: {exc}")
                _record("errors")


def is_enterprise() -> bool:
    """Return True if the connected Vault cluster is Enterprise edition."""
    try:
        client = get_client(namespace=None)
        health = client.sys.read_health_status(method="GET")
        return bool(health.get("enterprise", False))
    except VAULT_ERRORS:
        return False


def main() -> None:
    # Parse first so --help and bad flags exit before any Vault connection.
    argparse.ArgumentParser(
        description=__doc__,
        epilog=(
            "Configured entirely via environment variables:\n"
            "  VAULT_ADDR   Vault address (default: http://localhost:8200)\n"
            "  VAULT_TOKEN  token with write access (default: root)\n"
            "\n"
            "Run 'source .env' first, or use 'task seed' (alias vault:seed) which supplies\n"
            "the root token automatically. This script takes no options and\n"
            "always performs a full seed."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    ).parse_args()

    print(f"Seeding Vault at {VAULT_ADDR}")
    root_client = get_client(namespace=None)
    enterprise = is_enterprise()
    print(f"Edition: {'Enterprise' if enterprise else 'OSS/dev'}")

    if not enterprise:
        # OSS/dev: seed root namespace directly
        print("\n[root]")
        seed_contents(get_client())

    if not enterprise:
        return

    # Seed top-level tenant namespaces in parallel.
    # tnXXX namespaces are admin boundaries only — no resources seeded directly.
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {
            pool.submit(
                seed_namespace_tree,
                ns,
                None,
                root_client,
                not enterprise,  # seed_self=False on Enterprise
            ): ns
            for ns in TOP_LEVEL_NAMESPACES
        }
        for fut in as_completed(futures):
            exc = fut.exception()
            if exc:
                print(f"  [error] top-level {futures[fut]}: {exc}")
                _record("errors")

    print(f"\nDone.  added={_stats['added']}  skipped={_stats['skipped']}  errors={_stats['errors']}")


if __name__ == "__main__":
    main()
