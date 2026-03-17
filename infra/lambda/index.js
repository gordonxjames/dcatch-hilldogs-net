'use strict';
// dcatch-api Lambda — Phase 1 stub
// Full API routes added in Phase 2+.

exports.handler = async (event) => {
  // ── Cognito post-confirmation trigger ─────────────────────────────────────
  // New user registrations are visible in CloudWatch Logs and the Cognito console.
  // No admin alert email — Lambda has no internet route (private VPC, no NAT).
  if (event.triggerSource === 'PostConfirmation_ConfirmSignUp') {
    const username = event.userName;
    const email    = event.request?.userAttributes?.email || '';
    console.log(`New account registered: username=${username} email=${email} pool=${event.userPoolId}`);
    return event;
  }

  // ── HTTP routing (API Gateway proxy) ─────────────────────────────────────
  const method = event.httpMethod;
  const path   = event.path || '';

  const ok  = (body) => ({ statusCode: 200, headers: cors(), body: JSON.stringify(body) });
  const err = (msg, code = 500) => ({ statusCode: code, headers: cors(), body: JSON.stringify({ error: msg }) });

  if (path === '/health' && method === 'GET') {
    return ok({ status: 'ok', service: 'dcatch-api', ts: new Date().toISOString() });
  }

  return err('Not implemented', 501);
};

function cors() {
  return {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Content-Type': 'application/json',
  };
}
