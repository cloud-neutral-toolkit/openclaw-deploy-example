# Kong Routing Draft

This document captures a practical Kong routing draft for the multi-gateway topology described in [OpenClaw Multi-Gateway Architecture](/multi-gateway-architecture).

## Design Intent

Kong is the unified **remote** ingress for:

- `openclaw.svc.plus`
- upstream AI API governance
- token and secret handling
- rate limiting
- routing and failover between remote gateways

Kong is **not** the owner of local-first routing. Local macOS clients should still prefer `openclaw-local.svc.plus` directly and only fall back to `openclaw.svc.plus` when the local gateway is unavailable.

## Domain Plan

| Domain | Recommended Path | Notes |
| :----- | :--------------- | :---- |
| `openclaw.svc.plus` | Through Kong | Unified remote entrypoint |
| `openclaw-remote.svc.plus` | Through Kong | Direct route to VPS gateway for ops/debug |
| `openclaw-cloud-run.svc.plus` | Through Kong | Direct route to Cloud Run gateway for ops/debug |
| `openclaw-local.svc.plus` | Usually bypass Kong | Direct tunnel or local/private route to macOS gateway |

## Routing Matrix

| Host | Route Target | Purpose |
| :--- | :----------- | :------ |
| `openclaw.svc.plus` | `openclaw-unified` service | Default remote traffic |
| `openclaw-remote.svc.plus` | `openclaw-remote-direct` service | Force traffic to VPS |
| `openclaw-cloud-run.svc.plus` | `openclaw-cloud-run-direct` service | Force traffic to Cloud Run |

## Upstream Split Strategy

### Default mode

Default remote mode should be:

- `openclaw.svc.plus -> Kong -> VPS`
- Cloud Run stays provisioned but is **not** the default target in the unified upstream

### Failover / burst mode

When VPS becomes unhealthy or capacity is insufficient:

- add Cloud Run into the unified upstream target set
- keep Cloud Run behind Kong instead of exposing it as a separate public primary
- remove the Cloud Run target again after recovery if you want remote traffic to settle back onto the VPS

This keeps the baseline simple:

- one default remote node
- one elastic overflow node
- direct debug routes for both

## Recommended Plugin Chain

### On the unified remote service

- `correlation-id`
- `request-transformer` or `response-transformer` for upstream headers
- `rate-limiting`
- auth plugin of choice

### At the Kong layer, outside OpenClaw

This is where Kong can reduce glue code for:

- token API handling
- AI Gateway plugin based upstream model routing
- Vault backed secret retrieval
- auth unification across AI providers
- auditing and rate controls

Because plugin schemas differ by Kong version and edition, keep those plugin blocks environment-specific. The declarative sample in `deploy/kong/kong.yaml` focuses on route and upstream structure rather than hard-coding AI Gateway or Vault plugin schemas that may drift across versions.

## Health and Failover Guidance

Prefer one of these patterns:

1. Passive health checks only
   Use this if upstream requests already carry the same auth that production traffic uses.

2. Narrow active probe endpoint
   Expose a small probe endpoint such as `/healthz` on remote gateways and let Kong probe that path.

For an OpenClaw gateway behind strict auth, active health checks are easiest when you reserve a narrow internal health path that does not require the full user-facing auth flow.

## Declarative Config Sample

See:

- `deploy/kong/kong.yaml`
- `deploy/kong/kong-providers.yaml`
- `docs/kong-provider-routing.md`

That sample includes:

- unified remote service for `openclaw.svc.plus`
- direct VPS route for `openclaw-remote.svc.plus`
- direct Cloud Run route for `openclaw-cloud-run.svc.plus`
- upstream pools with placeholders for failover and overflow

## Example Operations

### Normal steady state

- unified pool contains only the VPS target
- Cloud Run remains reachable via `openclaw-cloud-run.svc.plus`

### Remote failover

- add Cloud Run target to `openclaw-unified-pool`
- optionally reduce or remove VPS target if it is unhealthy

### Burst mode

- keep VPS in the unified pool
- add Cloud Run with a lower weight
- scale Cloud Run down again by removing the target after the burst

## Principle

Use Kong to centralize remote ingress and API governance, but keep gateway role separation intact:

- local macOS gateway for interactive work
- VPS as default remote execution node
- Cloud Run as overflow and failover

That separation is the simplest way to preserve availability without turning the whole deployment into a shared-state multi-writer system.
