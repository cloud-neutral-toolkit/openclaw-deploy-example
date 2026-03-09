# svc-ai-gateway Providers

## Plugin choice

- `ai-proxy`
  Use for one fixed upstream provider per alias.
- `ai-proxy-multi`
  Use for ordered fallback, retries, and multi-provider policy.

## Current upstream env contract

| Alias group | Required env |
| :---------- | :----------- |
| GLM chat | `GLM_API_KEY`, `GLM_CHAT_ENDPOINT`, `GLM_CHAT_MODEL` |
| Kimi chat | `KIMI_API_KEY`, `KIMI_CHAT_ENDPOINT`, `KIMI_CHAT_MODEL` |
| MiniMax chat | `MINIMAX_API_KEY`, `MINIMAX_CHAT_ENDPOINT`, `MINIMAX_CHAT_MODEL` |
| Embeddings | `EMBEDDINGS_API_KEY`, `EMBEDDINGS_ENDPOINT`, `EMBEDDINGS_MODEL` |

## Fallback route

`chat-default:cloud` uses `ai-proxy-multi` with this order:

1. GLM
2. Kimi
3. MiniMax

Fallback is triggered on:

- `429`
- `5xx`
- provider rate-limiting signals

## Secret handling

This repository keeps only placeholder values in `.env`.

For production:

- render `.env` from your secret manager
- reload APISIX after rotating credentials
- keep provider credentials out of client-side configs
