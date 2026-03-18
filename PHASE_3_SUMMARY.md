# Phase 3 Summary — CloudFront and DNS

## Resources Built

| Resource | Name/ID | Notes |
|---|---|---|
| CloudFront OAC | E2HC19CJC7ET7N | sigv4, always, s3 |
| CloudFront Distribution | E1BFXVAS6JB4C4 | dcatch.hilldogs.net |
| CloudFront Domain | d166oqa1rcdpok.cloudfront.net | — |
| S3 Bucket Policy | dcatch-s3-frontend | OAC-only access |
| Route 53 A ALIAS | dcatch.hilldogs.net | → CloudFront |

## Decisions Made

- **Price class PriceClass_100** — US + Europe only; consistent with REPL project
- **SPA error handling** — 403 and 404 both return `/index.html` with HTTP 200; required for React Router client-side routing
- **OAC over OAI** — Origin Access Control (newer AWS mechanism) used instead of Origin Access Identity
- **Managed cache policy** — AWS `CachingOptimized` (`658327ea-f89d-4fab-a63d-7e88639e58f6`) avoids manual TTL configuration
- **No CloudFront logging** — can be enabled later; cost saving for now
- **UPSERT DNS** — Route 53 change uses `Action: UPSERT` so provision script is safe to re-run

## Test Approach Fix

The S3 bucket policy tests initially used `node -e` with `/dev/stdin` for JSON parsing, which fails on Git Bash (Windows). Replaced with `grep -o` + `cut` to extract values from the flat JSON string — simpler and reliable.

## Script Fix Notes

- REPL reference used `python3` for JSON parsing from `create-distribution` output; replaced with two separate `--query` AWS CLI calls (one for `Distribution.Id`, one for `Distribution.DomainName`)
- No `jq` or `python3` needed anywhere in the script

## Known Gaps

- Site returns 403 until Phase 4 deploys frontend content to S3
- No CloudFront access logging configured

## Test Results

113/113 tests pass across Phases 1–3.
