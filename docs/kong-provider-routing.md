# Kong Provider Routing Template

This document adds a provider-level routing template on top of the multi-gateway remote ingress design.

The goal is to let `Kong` centralize:

- provider selection
- token and secret injection
- rate limits
- provider-specific routing
- upstream isolation between commercial models and open-source model pools

This keeps each OpenClaw gateway simpler. A gateway node should only need:

- the Kong provider proxy endpoint such as `https://llm.openclaw.svc.plus`
- its own gateway auth token or internal trust path to Kong
- logical model names or provider route prefixes

Provider-specific API keys should stay in Kong plus Vault rather than being duplicated into every `openclaw.json`.

## Recommended Split

Use two distinct layers:

1. **Gateway ingress layer**
   This is the remote OpenClaw layer already described in [Kong Routing Draft](/kong-routing).

2. **Provider proxy layer**
   This is where Kong routes requests to upstream LLM providers such as OpenAI, ZAI, Anthropic, NVIDIA, and Chutes.

Keep those layers separate. Do not mix gateway failover logic with provider routing logic in the same service object unless there is a concrete operational reason.

## Provider Matrix

| Provider | Suggested Kong Route Prefix | Upstream Style | Auth/Header Notes |
| :------- | :-------------------------- | :------------- | :---------------- |
| OpenAI | `/providers/openai` | OpenAI native REST | Bearer token |
| ZAI | `/providers/zai` | OpenAI-compatible REST | Bearer token |
| Anthropic native | `/providers/anthropic` | Anthropic native REST | `x-api-key` + `anthropic-version` |
| Anthropic OpenAI-compatible | `/providers/anthropic-openai` | OpenAI-compatible chat layer | Bearer-style SDK client with Anthropic base URL |
| NVIDIA Build / NIM | `/providers/nvidia` | OpenAI-compatible REST | Bearer token |
| Chutes | `/providers/chutes/<model>` | model-specific endpoint | depends on chosen chute host and API key model |

## Practical Notes by Provider

### OpenAI

Use OpenAI as the baseline commercial provider. The OpenAI docs currently recommend the Responses API over older Chat Completions for new text generation work. Requests authenticate with Bearer auth against `https://api.openai.com/v1`. Source: [OpenAI API overview](https://platform.openai.com/docs/api-reference/overview) and [OpenAI text generation guide](https://developers.openai.com/api/docs/guides/text).

### ZAI

ZAI can be routed as an OpenAI-compatible provider. The official Forge Code guide explicitly shows `OPENAI_URL=https://open.bigmodel.cn/api/coding/paas/v4` for the coding endpoint. Source: [智谱开放文档 Forge Code](https://docs.bigmodel.cn/cn/guide/develop/forge).

### Anthropic

Anthropic works in two modes:

- native Anthropic API via `https://api.anthropic.com/v1`
- OpenAI SDK compatibility mode with the same Anthropic base URL

For native calls, preserve Anthropic-specific headers. For OpenAI-compatible calls, keep it isolated from native traffic because request semantics differ. Source: [Anthropic OpenAI SDK compatibility](https://platform.claude.com/docs/en/api/openai-sdk).

### NVIDIA Build / NVIDIA NIM

NVIDIA's hosted LLM APIs currently use `https://integrate.api.nvidia.com` and expose OpenAI-compatible `POST /v1/chat/completions`. The model catalog includes many open-source and partner-hosted models under one endpoint. Source: [NVIDIA LLM APIs](https://docs.api.nvidia.com/nim/reference/llm-apis).

### Chutes

Chutes should be treated as a model-specific open-source pool rather than a single universal REST base URL. The Chutes developer pages confirm an API and documentation hub exists, and public examples show model-specific subdomains such as `https://chutes-wan-2-2-i2v-14b-fast.chutes.ai/generate`. This is an inference from public Chutes materials rather than a single canonical universal LLM base URL doc, so use a per-chute service pattern in Kong and keep the host configurable. Sources: [Chutes developer docs hub](https://chutes.ai/resources) and [Chutes AI SDK demo](https://npm-demo.chutes.ai/).

## Routing Pattern

### Host layout

Recommended provider proxy host:

- `llm.openclaw.svc.plus`

Suggested usage:

- `https://llm.openclaw.svc.plus/providers/openai/...`
- `https://llm.openclaw.svc.plus/providers/zai/...`
- `https://llm.openclaw.svc.plus/providers/anthropic/...`
- `https://llm.openclaw.svc.plus/providers/nvidia/...`
- `https://llm.openclaw.svc.plus/providers/chutes/<model>/...`

### Why path prefixes work well

- keeps one external hostname
- makes auth and rate-limiting policy easier to reason about
- keeps upstream-specific observability separated by route name
- avoids overloading the remote gateway ingress hostname

## Secret Handling Pattern

Use Kong as the secret boundary:

- OpenAI token stays in Kong secret management
- ZAI token stays in Kong secret management
- Anthropic API key and version header are injected by Kong
- NVIDIA token stays in Kong secret management
- Chutes API key or per-chute credential stays in Kong

Recommended implementation:

- Vault plugin or secret reference at Kong
- provider-specific request transformation at Kong
- OpenClaw nodes call the Kong provider proxy rather than storing every upstream credential locally

## Gateway-Side Contract

From the perspective of `openclaw-local.svc.plus`, `openclaw-remote.svc.plus`, and `openclaw-cloud-run.svc.plus`, the provider contract should be:

1. send model traffic to Kong's provider proxy layer
2. identify the desired route by logical model family or provider path
3. let Kong inject the correct upstream token, vendor headers, and routing policy

This keeps gateway node configs independent while still centralizing provider governance.

## Open-Source Model Split

For open-source model routing, split by operational profile rather than only by vendor:

- `commercial-default`
- `reasoning-default`
- `open-source-general`
- `open-source-code`
- `open-source-cheap`

Example mapping:

- OpenAI -> commercial-default
- ZAI -> reasoning-default or code-default
- Anthropic -> commercial-default
- NVIDIA Build -> open-source-general or open-source-code
- Chutes -> open-source-general, open-source-vision, or open-source-specialized

This lets Kong route by policy instead of hard-coding every node to every upstream.

## Files

See:

- `deploy/kong/kong.yaml`
- `deploy/kong/kong-providers.yaml`

The first file handles remote gateway ingress.

The second file handles provider proxy routing and upstream examples.
