'use strict';
// dcatch-api Lambda — Phase 2 (HTTP API v2)
// Full API routes added in Phase 2+.

exports.handler = async (event) => {
  // ── Keep-warm ping (EventBridge scheduled rule) ────────────────────────────
  if (event.source === 'aws.events' || event['detail-type'] === 'Scheduled Event') {
    return { statusCode: 200, headers: cors(), body: JSON.stringify({ warmed: true }) };
  }

  // ── Cognito post-confirmation trigger ─────────────────────────────────────
  // New user registrations are visible in CloudWatch Logs and the Cognito console.
  // No admin alert email — Lambda has no internet route (private VPC, no NAT).
  if (event.triggerSource === 'PostConfirmation_ConfirmSignUp') {
    const username = event.userName;
    const email    = event.request?.userAttributes?.email || '';
    console.log(`New account registered: username=${username} email=${email} pool=${event.userPoolId}`);
    return event;
  }

  // ── HTTP routing (API Gateway HTTP v2 proxy) ─────────────────────────────
  const method = event.requestContext?.http?.method || '';
  const path   = event.rawPath || '';

  const ok  = (body) => ({ statusCode: 200, headers: cors(), body: JSON.stringify(body) });
  const err = (msg, code = 500) => ({ statusCode: code, headers: cors(), body: JSON.stringify({ error: msg }) });

  if (path === '/health' && method === 'GET') {
    return ok({ status: 'ok', service: 'dcatch-api', ts: new Date().toISOString() });
  }

  return err('Not implemented', 501);
};

function cors() {
  return {
    'Access-Control-Allow-Origin':  process.env.ALLOWED_ORIGIN || 'https://dcatch.hilldogs.net',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Content-Type': 'application/json',
  };
}
