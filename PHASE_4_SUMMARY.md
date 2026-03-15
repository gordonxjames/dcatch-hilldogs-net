# Phase 4 Summary — React Frontend Build & Deploy

## Resources Built

| Artifact | Location | Notes |
|---|---|---|
| React frontend | `frontend/src/` | Vite 5, React 18, React Router 6, amazon-cognito-identity-js v6 |
| Login page | `frontend/src/pages/Login.jsx` | Two-panel, amber gradient, 6 auth tabs |
| Home page | `frontend/src/pages/Home.jsx` | Protected route, welcome message |
| Settings page | `frontend/src/pages/Settings.jsx` | Email/phone/password update with verification |
| NavBar | `frontend/src/components/NavBar.jsx` | Gear icon → /settings; Log Out button |
| Footer | `frontend/src/components/Footer.jsx` | Amber theme, social links, privacy policy |
| Auth context | `frontend/src/auth/AuthContext.jsx` | Session: null/false/{ idToken, username, sub } |
| Cognito client | `frontend/src/auth/cognitoClient.js` | signIn, signUp, confirmSignUp, MFA, forgot/reset, updateAttr, changePassword |
| Config | `frontend/src/config.js` | Pool ID, client ID, API base — not secrets |
| Deploy script | `deploy.ps1` | Reads outputs.env at runtime; build → S3 sync → CF invalidation |
| Phase 4 tests | `tests/phase4.sh` | S3 content, HTTPS 200, HTTP→HTTPS redirect, SPA routing |

## Decisions Made

| Concern | Decision | Rationale |
|---|---|---|
| Auth identifier | Username (not email) for sign in | Cognito pool is username-primary; email is alias |
| MFA flow | `mfaRequired` callback in signIn → 'mfa' tab | SMS mandatory; UI prompts for code inline |
| Session shape | `{ idToken, username, sub }` | Username needed for Home/Settings display |
| No initUser call | AuthContext omits API call on sign-in | DCATCH has no DB rows to initialize (Phase 2 Lambda is minimal) |
| Settings | Three sections: email (verify), phone (verify), password | Maps to Cognito updateAttributes + verifyAttribute + changePassword |
| NavBar settings | Gear SVG icon upper-right → /settings | Per CLAUDE.md spec |
| deploy.ps1 | Parses outputs.env at runtime | Works after rebuild with new CF distribution ID |

## Test Results

- **Phase 4**: 8/8 new tests pass
- **All phases cumulative**: 121/121 pass

## Known Gaps

- Auth flow testing (sign-in, MFA, create account, verify) not automated — requires live user accounts. Documented in `tests/phase4.sh` header.
- No favicon.png included (not specified in requirements).
