# svc-ai-gateway API

`svc-ai-gateway` is the OpenAI-compatible front door for upstream model access.

## Public entrypoint

- Base URL: `https://api.svc.plus`

## Endpoints

- `POST /v1/chat/completions`
- `POST /v1/embeddings`
- `GET /v1/models`

## Deployment mode

- APISIX standalone mode
- YAML file-driven config
- no etcd
- no dashboard
- config stored in Git under `conf/`
- Caddy runs on the host as the public TLS entrypoint and reverse proxies to `127.0.0.1:9080`

## Current route model

- `POST /v1/chat/completions`
  Route selection is based on `post_arg.model`.
- `POST /v1/embeddings`
  Route selection is based on `post_arg.model`.
- `GET /v1/models`
  Returns a static gateway-maintained model catalog.

## Supported chat aliases

- `glm-5:cloud`
- `kimi-k2.5:cloud`
- `minimax-m2.5:cloud`
- `chat-default:cloud`

## Supported embedding aliases

- `text-embedding-3-small:cloud`

## Important limitation

This YAML-only version maps aliases to providers by APISIX route matching on request-body fields. It works for a fixed alias catalog, but it is not yet a full dynamic model registry. If you want arbitrary aliases loaded from a database or dynamic policy engine, add a thin adapter service or a custom APISIX plugin later.

## Run

```bash
cd svc-ai-gateway
docker compose up -d
```

## Validate

```bash
cd svc-ai-gateway
./scripts/validate.sh
```

## Reload

```bash
cd svc-ai-gateway
./scripts/reload.sh
```
