// Minimal Xen Orchestra JSON-RPC client, for the few calls its REST API lacks
// (such as vm.convertToTemplate and disk.import from a URL).
//
// Usage: XO_URL=https://... XO_TOKEN=... node xo-rpc.mjs <method> '<json params>'
// Prints the result as JSON; exits 1 on an error. Needs Node 22 or later
// (built-in WebSocket). Ran on 2026-11-16 with Node 26.
//
// Xen Orchestra's certificate is self-signed (CN=xo-ce, read 2026-11-16), so
// certificate checks are off for this one process.
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const [method, rawParams = '{}'] = process.argv.slice(2);
if (!method || !process.env.XO_URL || !process.env.XO_TOKEN) {
  console.error('usage: XO_URL=... XO_TOKEN=... node xo-rpc.mjs <method> [json params]');
  process.exit(2);
}

const ws = new WebSocket(process.env.XO_URL.replace(/^http/, 'ws') + '/api/');
let nextId = 0;
const pending = new Map();

const call = (name, params = {}) =>
  new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ jsonrpc: '2.0', id, method: name, params }));
  });

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  const waiter = pending.get(msg.id);
  if (!waiter) return; // notifications
  pending.delete(msg.id);
  if (msg.error) waiter.reject(new Error(JSON.stringify(msg.error)));
  else waiter.resolve(msg.result);
};

ws.onopen = async () => {
  try {
    await call('session.signInWithToken', { token: process.env.XO_TOKEN });
    console.log(JSON.stringify(await call(method, JSON.parse(rawParams))));
  } catch (err) {
    console.error(err.message);
    process.exitCode = 1;
  }
  ws.close();
};

ws.onerror = (event) => {
  console.error('websocket error:', event.message ?? event.type);
  process.exit(1);
};
