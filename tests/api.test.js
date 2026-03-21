#!/usr/bin/env node
// =============================================================================
// DCATCH — API Integration Tests                                    DCATCH-30
// Regression coverage for Lambda route handlers via the HTTP API v2 endpoint.
// Node.js 18+ (uses native fetch). No external dependencies.
// Usage: node tests/api.test.js [--verbose]
// =============================================================================
'use strict';

// Read config from infra/outputs.env
const path = require('path');
const fs   = require('fs');

const outputsPath = path.resolve(__dirname, '../infra/outputs.env');
if (!fs.existsSync(outputsPath)) {
  console.error('ERROR: infra/outputs.env not found. Cannot run API tests.');
  process.exit(1);
}

const outputs = {};
for (const line of fs.readFileSync(outputsPath, 'utf8').split('\n')) {
  if (line.startsWith('#') || !line.includes('=')) continue;
  const [k, ...rest] = line.split('=');
  outputs[k.trim()] = rest.join('=').trim();
}

const API_BASE = outputs['APIGW_BASE_URL'];
if (!API_BASE) {
  console.error('ERROR: APIGW_BASE_URL not set in infra/outputs.env.');
  process.exit(1);
}

const VERBOSE = process.argv.includes('--verbose');

// =============================================================================
// Colour helpers
// =============================================================================
const GREEN  = s => `\x1b[32m${s}\x1b[0m`;
const RED    = s => `\x1b[31m${s}\x1b[0m`;
const YELLOW = s => `\x1b[33m${s}\x1b[0m`;
const CYAN   = s => `\x1b[36m${s}\x1b[0m`;
const BOLD   = s => `\x1b[1m${s}\x1b[0m`;
const DIM    = s => `\x1b[2m${s}\x1b[0m`;

// =============================================================================
// Test runner
// =============================================================================
let passed = 0, failed = 0;
const failures = [];

function section(name) {
  console.log(`\n${BOLD(CYAN(`── ${name} ──`))}`);
}

function log(msg) { if (VERBOSE) console.log(DIM(`   ${msg}`)); }

async function test(name, fn) {
  const start = Date.now();
  try {
    await fn();
    const ms = Date.now() - start;
    console.log(`  ${GREEN('✓')} ${name} ${DIM(`(${ms}ms)`)}`);
    passed++;
  } catch (e) {
    const ms = Date.now() - start;
    console.log(`  ${RED('✗')} ${name} ${DIM(`(${ms}ms)`)}`);
    console.log(`    ${RED(e.message)}`);
    failures.push({ name, error: e.message });
    failed++;
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg);
}

function assertEqual(actual, expected, label) {
  assert(actual === expected,
    `${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

// =============================================================================
// HTTP helpers
// =============================================================================
async function apiGet(path, token) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  const body = await res.json().catch(() => ({}));
  log(`GET ${path} → ${res.status} ${JSON.stringify(body).substring(0, 120)}`);
  return { status: res.status, headers: res.headers, body };
}

// =============================================================================
// Tests
// =============================================================================
(async () => {
  console.log(`\n${BOLD('DCATCH API Integration Tests')}`);
  console.log(`  Endpoint: ${API_BASE}`);

  // ---------------------------------------------------------------------------
  section('GET /health — unauthenticated');

  await test('returns 200', async () => {
    const { status } = await apiGet('/health');
    assertEqual(status, 200, 'status');
  });

  await test('body has status:ok', async () => {
    const { body } = await apiGet('/health');
    assertEqual(body.status, 'ok', 'body.status');
  });

  await test('body has service:dcatch-api', async () => {
    const { body } = await apiGet('/health');
    assertEqual(body.service, 'dcatch-api', 'body.service');
  });

  await test('body has ts timestamp', async () => {
    const { body } = await apiGet('/health');
    assert(typeof body.ts === 'string' && body.ts.length > 0, 'body.ts should be a non-empty string');
  });

  // ---------------------------------------------------------------------------
  section('CORS headers — GET /health with Origin');

  await test('returns Access-Control-Allow-Origin', async () => {
    const res = await fetch(`${API_BASE}/health`, {
      headers: { Origin: 'https://dcatch.hilldogs.net' },
    });
    const origin = res.headers.get('access-control-allow-origin');
    assert(origin !== null, 'Access-Control-Allow-Origin header missing');
    assertEqual(origin, 'https://dcatch.hilldogs.net', 'Allow-Origin value');
  });

  // ---------------------------------------------------------------------------
  section('JWT-protected routes — no token');

  await test('unknown authenticated path returns 401 or 403', async () => {
    const { status } = await apiGet('/protected-test-probe');
    assert(status === 401 || status === 403,
      `expected 401 or 403, got ${status}`);
  });

  // ---------------------------------------------------------------------------
  const total = passed + failed;
  console.log(`\n${BOLD('Results:')} ${GREEN(passed + ' passed')}, ${failed > 0 ? RED(failed + ' failed') : DIM('0 failed')}, ${total} total`);

  if (failures.length > 0) {
    console.log(`\n${RED('Failures:')}`);
    for (const f of failures) console.log(`  ${RED('✗')} ${f.name}: ${f.error}`);
    process.exit(1);
  }
})();
