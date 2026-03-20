# Phase 5 Summary — Keep-Warm + API Gateway Migration to HTTP API v2

## Overview

Phase 5 delivered two related changes:
1. **Keep-warm EventBridge rule** (`dcatch-lambda-keepwarm`) — fires every 5 minutes to prevent Lambda cold starts.
2. **API Gateway migration** — REST API v1 (`0rsdzot34a`) replaced with HTTP API v2 (`lz3ukvdl4h`), switching from Cognito User Pools authorizer to JWT authorizer. This aligns with the REPL project pattern and reduces cost.

## Resources Built / Changed

| Resource | Name / ID | Notes |
|---|---|---|
| EventBridge Rule | `dcatch-lambda-keepwarm` | `rate(5 minutes)`, ENABLED, targets `dcatch-lambda` |
| HTTP API v2 | `dcatch-api` / `lz3ukvdl4h` | Replaced REST API v1 `0rsdzot34a` (deleted) |
| JWT Authorizer | `dcatch-cognito-jwt` / `zr31wd` | Audience=Cognito client, Issuer=Cognito pool URL |
| API Route | `GET /health` | No auth, proxies to Lambda |
| API Route | `$default` | JWT auth, proxies to Lambda |
| API Stage | `$default` | Auto-deploy enabled |

## Decisions Made

| Concern | Decision | Rationale |
|---|---|---|
| Keep-warm schedule | `rate(5 minutes)` | Prevents Lambda cold starts; cold start with VPC attachment can be 1-2s |
| Keep-warm handler | Early-exit when `event.source === 'aws.events'` | Avoids routing overhead |
| API type | HTTP API v2 (not REST API v1) | 71% cheaper; simpler CORS config; JWT authorizer is lighter |
| JWT authorizer | Audience=Cognito client ID, Issuer=Cognito pool URL | Standard Cognito JWT setup; validates `id_token` from frontend |
| CORS origin | `https://dcatch.hilldogs.net` (specific, not `*`) | Security improvement over wildcard; API-level CORS handles OPTIONS preflight |
| Lambda payload format | 2.0 | HTTP API v2 default; handler supports both v1 and v2 event formats for robustness |
| Base URL | `https://lz3ukvdl4h.execute-api.us-east-2.amazonaws.com` | No `/v1` stage segment; HTTP API uses `$default` stage with no prefix |
| CloudWatch log retention | 7 days | Prevents unbounded log accumulation at no meaningful cost |

## Known Gaps (at time of writing)

- SMS MFA (DCATCH-23) remains deferred — unrelated to this phase.
