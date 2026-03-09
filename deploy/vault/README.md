# Single-Node Vault

This deployment keeps Vault as a host process and lets Caddy terminate TLS
for `vault.svc.plus`, proxying to `127.0.0.1:8200`.

## Topology

- `vault server` listens on `127.0.0.1:8200`
- Raft data is stored under `/opt/vault/data`
- Caddy serves `https://vault.svc.plus`

## Config files

- Vault config template: `deploy/vault/vault.hcl.example`
- Host config path: `/etc/vault.d/vault.hcl`
- Local secret file: repository root `.env` with `VAULT_SERVER_ACCESS_TOKEN=<initial-root-token>`
- Caddy site block:

```caddy
vault.svc.plus {
  tls internal
  encode zstd gzip
  reverse_proxy 127.0.0.1:8200
}
```

Use `tls internal` until `vault.svc.plus` resolves to the target host. Once DNS
is in place, remove `tls internal` and let Caddy obtain a public certificate.

## Initialization

Initialize and unseal once after the service first starts:

```bash
vault operator init -address=http://127.0.0.1:8200 -key-shares=1 -key-threshold=1 -format=json
vault operator unseal -address=http://127.0.0.1:8200 <unseal-key>
```

Store the init output in a root-only file or secret manager. Do not commit it.

## Local access token

After `vault operator init`, append the initial root token to the repository
root `.env` file, which is already ignored by Git:

```bash
VAULT_SERVER_ACCESS_TOKEN=<initial-root-token>
```

That value can then be used locally for CLI checks:

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="$VAULT_SERVER_ACCESS_TOKEN"
vault status
```
