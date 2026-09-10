import assert from 'node:assert/strict';

const base = process.env.APP_URL || 'http://127.0.0.1:3000/';
const url = new URL('app.psp', base);
url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
const connections = [];

async function connect() {
  const socket = new WebSocket(url);
  connections.push(socket);
  const queue = [], waiting = [];
  let failure;
  function fail(error) {
    failure = error;
    for (const waiter of waiting.splice(0)) waiter.reject(error);
  }
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    const waiter = waiting.shift();
    if (waiter) waiter.resolve(message); else queue.push(message);
  });
  socket.addEventListener('error', () => fail(new Error(`WebSocket failed: ${url}`)));
  socket.addEventListener('close', () => fail(new Error('WebSocket closed unexpectedly')));
  const next = () => {
    if (queue.length) return Promise.resolve(queue.shift());
    if (failure) return Promise.reject(failure);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Response timed out')), 15000);
      waiting.push({resolve: value => { clearTimeout(timer); resolve(value); },
        reject: error => { clearTimeout(timer); reject(error); }});
    });
  };
  assert.equal((await next()).type, 'menu');
  return {socket, next, async command(line) {
    socket.send(JSON.stringify({type: 'command', line}));
    return next();
  }};
}

try {
  const response = await fetch(base);
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Adventure Terminal/);
  assert.doesNotMatch(html, /Â|â€|\$\{/, 'HTML encoding and substitutions are clean');
  for (const asset of ['adventure.js', 'adventure.css', 'terminal-xterm.js', 'games/readme_sa.txt']) {
    assert.equal((await fetch(new URL(asset, base))).status, 200, `asset ${asset}`);
  }
  const [one, two] = await Promise.all([connect(), connect()]);
  assert.equal((await one.command('../ScottGame.pm')).type, 'info', 'selection is allowlisted');
  one.socket.send('not json');
  assert.equal((await one.next()).type, 'error');
  one.socket.send(new Uint8Array([1, 2, 3]));
  assert.equal((await one.next()).type, 'error', 'binary input rejected');
  assert.equal((await one.command('x'.repeat(257))).type, 'error');
  assert.equal((await one.command('\u001b[31m')).type, 'error');
  assert.equal((await one.command('1')).title, 'Adventureland');
  assert.equal((await two.command('1')).title, 'Adventureland');
  assert.match((await one.command('e')).room, /sunny meadow/);
  assert.match((await two.command('look')).room, /in a forest/);
  assert.match((await one.command('/restart')).room, /in a forest/);
  assert.equal((await one.command('/menu')).type, 'menu');
  for (let number = 1; number <= 16; number++) {
    const reply = await one.command(String(number));
    assert.equal(reply.type, 'turn', `start game ${number}`);
    assert.ok(reply.room.length, `game ${number} scene`);
    assert.equal((await one.command('inventory')).type, 'turn');
    await one.command('/menu');
  }
  await one.command('16');
  const commands = ['e', 'e', 'get axe', 'n', 'get ox', 'say bunyon', 'swim', 's',
    'w', 'take mud', 'w', 'get axe', 'get ox', 'get fruit', 'e', 'take mud',
    'chop tree', 'drop axe', 'get mud', 'go stump', 'drop mud', 'drop ox',
    'drop fruit', 'go down', 'get rubies', 'go up', 'drop rubies', 'score'];
  let last;
  for (const command of commands) last = await one.command(command);
  assert.match(last.output, /100/);
  assert.equal(last.ended, 1, 'mini-adventure won over real WebSocket');
  assert.equal((await two.command('look')).type, 'turn', 'other player survives game over');
  one.socket.close();
  const fresh = await connect();
  assert.match((await fresh.command('1')).room, /in a forest/, 'reconnect starts fresh');
  console.log(`PASS ${base}: HTTP/assets, validation, all 16 games, independent sessions, restart, reconnect, and complete mini-adventure.`);
} finally {
  for (const socket of connections) socket.close();
}
