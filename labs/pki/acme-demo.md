# Vault PKI ACME Demo

Issue a certificate from Vault's ACME server using certbot and an HTTP-01 challenge, all on the `docker-vault-stack` Docker network.

## Prerequisites

- Core stack running and unsealed
- PKI lab applied (`task tf:apply`) - this configures everything ACME needs:
  - `config/cluster` path `http://vault.localhost:8200/v1/admin/tn001/pki`
  - `Link`, `Location` and `Replay-Nonce` allowed as response headers on the mount
  - `config/acme`: enabled, `default_directory_policy = role:default`, `allowed_roles = [default]`, `eab_policy = always-required`
- Docker

Verify the ACME config:

```bash
source ../../.env
export VAULT_NAMESPACE=admin/tn001
vault read pki/config/acme
curl -s "$VAULT_ADDR/v1/admin/tn001/pki/acme/directory" | jq
```

## 1. Prepare and start the HTTP-01 webroot

```bash
task acme:init   # creates acme/etc and acme/web
task acme:web    # nginx on the network with alias acme-demo.example.com
```

Vault reaches `http://acme-demo.example.com/.well-known/acme-challenge/...` through the Docker network alias.

## 2. Request a certificate

```bash
task acme:certbot
```

`scripts/acme-certbot.sh`:
1. Creates fresh EAB credentials with `vault write -f pki/acme/new-eab` (EAB is always required).
2. Runs `certbot/certbot` on the network with `acme/certbot-entrypoint.sh`, which calls `certbot certonly --webroot` against `http://vault.localhost:8200/v1/admin/tn001/pki/acme/directory` using a 4096-bit RSA key (required by the `default` role).
3. Prints the issued certificate and the certbot log. The container exits when done.

Override with `CERTBOT_CERT_NAME` (must be under `example.com`) or `ACME_VAULT_ADDR` (Vault address as seen from inside the network).

## 3. Show a policy failure

```bash
task acme:certbot-fail
```

Requests the same certificate with a 2048-bit key. Vault rejects the order:
`role requires a minimum of a 4096-bit key, but CSR's key is 2048 bits`.

## 4. Inspect the issued certificate

```bash
openssl x509 -in acme/etc/live/acme-demo.example.com/cert.pem -noout -subject -issuer -dates -ext crlDistributionPoints
```

## 5. Show Vault issued and tracked the certificate

```bash
task certs-list
vault read pki/roles/default
```

## 6. Clean up

```bash
task acme:down            # stop acme-web / acme-certbot
task acme:certbot:clean   # remove acme/etc (certbot accounts, keys, certs)
```

## What to say while demoing

- ACME lets a client prove domain control automatically.
- Vault exposes an ACME directory under the PKI mount, per namespace.
- External Account Binding ties ACME accounts to a Vault-authenticated request.
- The client creates an HTTP-01 challenge response in a webroot; Vault validates it.
- Role policy still applies - the 2048-bit request is refused.
- The issued cert is tracked in Vault like any other PKI issuance.
