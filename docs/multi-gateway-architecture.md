# OpenClaw Multi-Gateway Architecture

This document describes the recommended multi-gateway topology for a personal OpenClaw assistant that must remain reachable at all times while still preserving strong interactive capabilities on a local macOS node.

## Goals

- Keep one always-online remote entrypoint.
- Preserve strong interactive browser tasks on the local macOS node.
- Allow multiple gateway nodes to exist without sharing the same `openclaw.json`.
- Share long-lived memory and artifacts across nodes without sharing the full hot runtime state.
- Centralize auth, secrets, rate limiting, and upstream AI API access behind Kong.

## Domains and Node Roles

| Domain | Node Role | Primary Purpose |
| :----- | :-------- | :-------------- |
| `openclaw.svc.plus` | Kong | Unified remote entrypoint, auth, token/API governance, upstream routing |
| `openclaw-local.svc.plus` | Local macOS Gateway | Strong interactive tasks, browser sessions, desktop-local tools |
| `openclaw-remote.svc.plus` | VPS Remote Gateway | Default 24x7 remote gateway, message ingress, non-interactive online tasks |
| `openclaw-cloud-run.svc.plus` | Cloud Run Gateway | Elastic overflow and failover for non-interactive online tasks |

## Responsibility Split

### Kong

Kong remains in the design because it reduces glue code for:

- token/API brokering
- AI Gateway plugin based upstream routing
- Vault backed secret injection
- auth and rate limiting
- consistent remote entrypoint
- VPS to Cloud Run failover

Kong should **not** become the scheduler for local-vs-remote execution or the owner of session state.

For a concrete route and upstream sketch, see [Kong Routing Draft](/kong-routing).

## Gateway-to-Model Contract

Each OpenClaw gateway should talk to Kong's AI Gateway layer rather than carrying a full set of upstream provider credentials locally.

- gateway nodes call the Kong provider proxy such as `llm.openclaw.svc.plus`
- gateway nodes request logical model routes or provider paths, not raw upstream secrets
- Kong plus AI Gateway plus Vault own provider token injection, model routing, and provider-specific headers
- local, VPS, and Cloud Run nodes can share the same logical provider contract while still keeping different node-local `openclaw.json` files

### Local macOS Gateway

The local macOS gateway is the only node that should handle strong interactive tasks:

- browser login sessions
- desktop-local automation
- tasks that require a local browser profile
- tasks that need low latency user interaction

It should stay local-first by default. Do not make `/opt/data` the default hot runtime state for `openclaw-local.svc.plus`.

### VPS Remote Gateway

The VPS node is the default remote gateway:

- always online
- receives remote traffic from `openclaw.svc.plus`
- runs non-interactive online tasks
- acts as the primary remote control plane for agents and channels

### Cloud Run Gateway

Cloud Run is not a peer of the macOS node for interactive work. It is reserved for:

- VPS failover
- burst capacity
- stateless or weak-state non-interactive work

## Routing Policy

### Client-side preference

Clients should prefer the local macOS gateway first:

1. Try `openclaw-local.svc.plus`
2. If unavailable, fall back to `openclaw.svc.plus`

This decision should stay on the client side. Kong should only decide how remote traffic is split between VPS and Cloud Run.

### Remote-side preference

For remote traffic:

1. `openclaw.svc.plus` enters Kong
2. Kong routes to `openclaw-remote.svc.plus` by default
3. Kong fails over to `openclaw-cloud-run.svc.plus` when VPS health or capacity is insufficient

## Configuration Model

Each node keeps its own config file:

- `config/openclaw-local.json`
- `config/openclaw-remote.json`
- `config/openclaw-cloud-run.json`

These files should not be shared or overwritten by other nodes. Node-local concerns differ by design:

- bind mode
- Control UI origin
- browser capabilities
- local paths
- trusted proxy lists
- deployment-specific env

## Shared Memory Model

Nodes should share memory and artifacts, but not the entire runtime state directory.

### Shared across nodes

- long-term memory
- session summaries
- exported artifacts
- attachments
- rebuildable snapshots

### Node-private

- full `OPENCLAW_STATE_DIR`
- browser profiles
- credentials
- lock files
- temporary files
- logs
- hot session caches

## Recommended Storage Layout

### Local macOS Gateway

- `OPENCLAW_CONFIG_PATH=$HOME/.openclaw/openclaw-local.json`
- `OPENCLAW_STATE_DIR=$HOME/.openclaw/local-state`
- optional shared mount: `/opt/data` for shared memory import or export, snapshots, and recovery workflows

### VPS Remote Gateway

- `OPENCLAW_CONFIG_PATH=/data/config/openclaw-remote.json`
- `OPENCLAW_STATE_DIR=/data/remote-state`

### Cloud Run Gateway

- `OPENCLAW_CONFIG_PATH=/data/config/openclaw-cloud-run.json`
- `OPENCLAW_STATE_DIR=/data/cloudrun-state`

### Shared object storage

Use GCS/S3/OSS for shared memory and artifacts only:

- `memory/<user>/<agent>/events/*.jsonl`
- `memory/<user>/<agent>/summary.json`
- `artifacts/<user>/<agent>/...`
- `snapshots/<node>/...`

Prefer append-only or shard-based writes over direct multi-node overwrites of a single `data.json`.

For macOS specifically, keep the live local gateway on local disk first and merge memory artifacts into shared storage on a schedule or at explicit sync points. Keep `scripts/macos_mount_gcs_openclaw.sh` as an optional mount path for `/opt/data`, but do not treat it as the default live state path for `openclaw-local.svc.plus`.

## Execution Policy

### Interactive tasks

Run only on the local macOS gateway:

- browser-based tasks
- tasks requiring existing local login state
- human-in-the-loop interaction

### Non-interactive online tasks

Run on VPS by default, with Cloud Run as overflow:

- crawlers
- fetch pipelines
- async research
- scheduled remote tasks

## Final Principle

The architecture should be treated as:

- `Kong` = remote ingress and governance layer
- `Local macOS Gateway` = interactive execution layer
- `VPS / Cloud Run` = online computation layer
- `Object Storage` = shared memory and artifact layer

Do not collapse those four roles back into a shared full-state multi-writer system.
