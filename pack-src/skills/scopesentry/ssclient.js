#!/usr/bin/env node
// ssclient.js — dependency-free Streamable-HTTP MCP client for a deployed
// ScopeSentry instance, invoked by the agent through Bash.
//
// The ngu kernel only launches stdio MCP servers and cannot reach a bundled
// local script by relative path, so this helper speaks JSON-RPC over HTTP on
// demand instead of being registered as an auto-started server.
//
// Env:
//   SS_BASE_URL   e.g. http://127.0.0.1:8082 (trailing /mcp appended if absent)
//   SS_API_KEY    ssk_... secret from the Web UI API-key page
//   SS_AUTH       optional: "x-api-key" (default) | "bearer"
//   SS_PROTOCOL   optional MCP-Protocol-Version (default 2025-06-18)
//
// Usage:
//   node ssclient.js health
//   node ssclient.js tools
//   node ssclient.js call <tool-name> '<json arguments>'
//
// Every invocation runs a fresh initialize handshake, performs the requested
// call, and exits. JSON-RPC errors and HTTP failures print to stderr with a
// non-zero exit code; results print to stdout.

'use strict';

const BASE = (process.env.SS_BASE_URL || '').trim().replace(/\/+$/, '');
const KEY = (process.env.SS_API_KEY || '').trim();
const AUTH = (process.env.SS_AUTH || 'x-api-key').toLowerCase();
const PROTOCOL = process.env.SS_PROTOCOL || '2025-06-18';

function fail(message) {
  process.stderr.write(`ssclient: ${message}\n`);
  process.exit(1);
}

if (!BASE) fail('SS_BASE_URL is not set (e.g. http://127.0.0.1:8082)');
if (!KEY) fail('SS_API_KEY is not set (the ssk_... secret from the Web UI)');

let endpoint = BASE;
if (!/\/mcp\/?$/i.test(endpoint)) endpoint = `${endpoint}/mcp`;

let sessionId = '';
let nextId = 1;

function headers(extra) {
  const h = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
    'MCP-Protocol-Version': PROTOCOL,
    ...extra,
  };
  if (AUTH === 'bearer') h.Authorization = `Bearer ${KEY}`;
  else h['X-API-Key'] = KEY;
  if (sessionId) h['Mcp-Session-Id'] = sessionId;
  return h;
}

// Parse either a plain JSON body or a text/event-stream body; return the frame
// whose id matches wantId (server-initiated frames are ignored).
function parseBody(contentType, text, wantId) {
  if (/text\/event-stream/i.test(contentType)) {
    let buf = '';
    for (const rawLine of text.split(/\r?\n/)) {
      const line = rawLine.trimEnd();
      if (line === '') {
        if (buf) {
          const frame = tryParse(buf);
          if (frame && frame.id === wantId) return frame;
          buf = '';
        }
        continue;
      }
      if (line.startsWith('data:')) buf += line.slice(5).trim();
    }
    if (buf) {
      const frame = tryParse(buf);
      if (frame && frame.id === wantId) return frame;
    }
    fail('no matching JSON-RPC frame in SSE stream');
  }
  const frame = tryParse(text);
  if (!frame) fail('server returned a non-JSON response');
  return frame;
}

function tryParse(text) {
  try { return JSON.parse(text); } catch { return null; }
}

async function rpc(method, params, expectResponse = true) {
  const id = expectResponse ? nextId++ : null;
  const body = { jsonrpc: '2.0', method, params: params || {} };
  if (id !== null) body.id = id;

  let res;
  try {
    res = await fetch(endpoint, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(body),
    });
  } catch (err) {
    fail(`cannot reach ${endpoint}: ${err.message}`);
  }

  const sid = res.headers.get('mcp-session-id');
  if (sid && !sessionId) sessionId = sid;

  const text = await res.text();
  if (res.status < 200 || res.status >= 300) {
    fail(`HTTP ${res.status}: ${text.slice(0, 500)}`);
  }
  if (!expectResponse) return null; // notification: 202 Accepted, no body

  const frame = parseBody(res.headers.get('content-type') || '', text, id);
  if (frame.error) fail(`rpc ${method} error ${frame.error.code}: ${frame.error.message}`);
  return frame.result;
}

async function handshake() {
  await rpc('initialize', {
    protocolVersion: PROTOCOL,
    capabilities: {},
    clientInfo: { name: 'artex-ssclient', version: '1.0' },
  });
  await rpc('notifications/initialized', {}, false);
}

async function main() {
  const [, , command, toolName, argsJson] = process.argv;
  await handshake();

  if (command === 'health') {
    const result = await rpc('tools/list', {});
    process.stdout.write(`ok: ${(result.tools || []).length} tools available\n`);
    return;
  }

  if (command === 'tools') {
    const result = await rpc('tools/list', {});
    process.stdout.write(JSON.stringify(result.tools || [], null, 2) + '\n');
    return;
  }

  if (command === 'call') {
    if (!toolName) fail('usage: call <tool-name> <json-arguments>');
    let args = {};
    if (argsJson && argsJson.trim()) {
      try { args = JSON.parse(argsJson); }
      catch (err) { fail(`arguments are not valid JSON: ${err.message}`); }
    }
    const result = await rpc('tools/call', { name: toolName, arguments: args });
    if (result.isError) fail(`tool ${toolName} reported an error: ${flatten(result)}`);
    process.stdout.write(flatten(result) + '\n');
    return;
  }

  fail('usage: health | tools | call <tool-name> <json-arguments>');
}

function flatten(result) {
  if (!result || !Array.isArray(result.content)) {
    return typeof result === 'string' ? result : JSON.stringify(result ?? {});
  }
  return result.content
    .filter((b) => b && b.type === 'text')
    .map((b) => b.text)
    .join('\n');
}

main().catch((err) => fail(err.message));
