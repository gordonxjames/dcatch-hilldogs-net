'use strict';
// dcatch-api Lambda — Phase 1 stub
// Full API routes added in Phase 2+.

const { SESv2Client, SendEmailCommand } = require('@aws-sdk/client-sesv2');
const ses = new SESv2Client({ region: 'us-east-1' });

exports.handler = async (event) => {
  // ── Cognito post-confirmation trigger ─────────────────────────────────────
  // NOTE: This SES call will silently fail until DCATCH-1 is resolved.
  // The user account is already confirmed before this trigger fires, so
  // failure here does not affect the end user's registration flow.
  if (event.triggerSource === 'PostConfirmation_ConfirmSignUp') {
    const username = event.userName;
    const email    = event.request?.userAttributes?.email || '';
    const bodyText = [
      'New DCATCH Delta Catcher account created',
      '='.repeat(50),
      '',
      `Username: ${username}`,
      `Email:    ${email}`,
      `Time:     ${new Date().toUTCString()}`,
      `Pool:     ${event.userPoolId}`,
    ].join('\n');
    try {
      await ses.send(new SendEmailCommand({
        FromEmailAddress: process.env.ALERT_FROM_EMAIL,
        Destination: { ToAddresses: [process.env.ALERT_TO_EMAIL] },
        Content: {
          Simple: {
            Subject: { Data: 'DCATCH: New Account Created', Charset: 'UTF-8' },
            Body:    { Text: { Data: bodyText,               Charset: 'UTF-8' } },
          },
        },
      }));
    } catch (err) {
      // Non-fatal — log and continue. See DCATCH-1 for fix.
      console.error('Admin alert email failed (DCATCH-1):', err.message);
    }
    return event;
  }

  // ── Keep-warm ping ────────────────────────────────────────────────────────
  if (event.source === 'aws.events') {
    return { statusCode: 200, body: 'warm' };
  }

  // ── HTTP routing (API Gateway proxy) ─────────────────────────────────────
  const method = event.httpMethod;
  const path   = event.path || '';

  const ok  = (body) => ({ statusCode: 200, headers: cors(), body: JSON.stringify(body) });
  const err = (msg, code = 500) => ({ statusCode: code, headers: cors(), body: JSON.stringify({ error: msg }) });

  if (path === '/v1/health' && method === 'GET') {
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
