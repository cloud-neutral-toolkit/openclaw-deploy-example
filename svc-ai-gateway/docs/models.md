# svc-ai-gateway Models

## External alias contract

External model names should be gateway aliases, not raw provider names.

Current aliases:

- `glm-5:cloud`
- `glm-5:nvidia`
- `kimi-k2.5:cloud`
- `minimax-m2.5:cloud`
- `chat-default:cloud`
- `text-embedding-3-small:cloud`

## Alias mapping

| External alias | Endpoint | Gateway plugin | Upstream model source |
| :------------- | :------- | :------------- | :-------------------- |
| `glm-5:cloud` | `/v1/chat/completions` | `ai-proxy` | `OLLAMA_CHAT_MODEL` |
| `glm-5:nvidia` | `/v1/chat/completions` | `ai-proxy` | `NVIDIA_CHAT_MODEL` |
| `kimi-k2.5:cloud` | `/v1/chat/completions` | `ai-proxy` | `KIMI_CHAT_MODEL` |
| `minimax-m2.5:cloud` | `/v1/chat/completions` | `ai-proxy` | `MINIMAX_CHAT_MODEL` |
| `chat-default:cloud` | `/v1/chat/completions` | `ai-proxy-multi` | ordered fallback chain |
| `text-embedding-3-small:cloud` | `/v1/embeddings` | `ai-proxy` | `EMBEDDINGS_MODEL` |

## Why keep aliases provider-neutral

- clients only talk to `api.svc.plus`
- provider swaps do not require client changes
- fallback and quota policy can stay in the gateway
- model naming can stay stable even if upstream provider names drift
