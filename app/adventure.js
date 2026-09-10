(() => {
  'use strict';
  const term = new Terminal({
    cursorBlink: true, convertEol: true, scrollback: 3000,
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
    fontSize: 13, lineHeight: 1.3,
    theme: {background: '#101820', foreground: '#c1d0d6', cursor: '#80e2b7',
      selectionBackground: '#38554f', black: '#101820', green: '#80e2b7',
      cyan: '#7fc7d9', yellow: '#e5be7a', red: '#eaa58e', brightBlack: '#65818e'}
  });
  const fit = new FitAddon.FitAddon();
  term.loadAddon(fit);
  term.open(document.getElementById('terminal'));
  const status = document.getElementById('connection-status');
  const room = document.getElementById('room');
  let socket, line = '', prompt = 'Select adventure > ', busy = true;
  let history = [], historyIndex = 0;
  const safe = value => String(value ?? '').replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f]/g, '');
  const write = value => term.write(safe(value));
  function drawPrompt() { term.write('\x1b[32m'); write(prompt); term.write('\x1b[0m'); write(line); }
  function replaceLine(value) {
    // Input is bounded ASCII and cannot contain terminal control sequences.
    term.write('\b \b'.repeat(line.length));
    line = value;
    write(line);
  }
  function connect() {
    busy = true;
    line = '';
    history = [];
    historyIndex = 0;
    status.textContent = 'Connecting';
    status.dataset.state = 'connecting';
    const url = new URL('app.psp', window.location.href);
    url.protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    socket = new WebSocket(url);
    socket.addEventListener('message', event => {
      let message;
      try { message = JSON.parse(event.data); } catch { socket.close(); return; }
      if (message.type === 'menu') {
        term.clear();
        term.write('\r\n\x1b[36m');
        document.getElementById('scene-index').textContent = 'LIBRARY / 16 ADVENTURES';
      } else if (message.started) {
        term.write('\r\n\x1b[36m');
        write(`── ${message.title} ──\n\n`);
        document.getElementById('scene-index').textContent = 'ADVENTURE IN PROGRESS';
      } else {
        term.write(message.type === 'error' ? '\x1b[31m' : '\x1b[0m');
      }
      if (message.title !== undefined) document.getElementById('game-title').textContent = message.title;
      if (message.room !== undefined) room.textContent = message.room.replace(/\n{3,}/g, '\n\n').trim();
      if (message.turns !== undefined) document.getElementById('turn-count').textContent = `TURN ${String(message.turns).padStart(3, '0')}`;
      if (message.ended) document.getElementById('scene-index').textContent = 'ADVENTURE COMPLETE';
      if (message.prompt) prompt = message.prompt;
      write(message.output);
      term.write('\x1b[0m');
      if (message.output) term.write('\r\n');
      busy = false;
      status.textContent = 'Connected';
      status.dataset.state = 'connected';
      drawPrompt();
    });
    socket.addEventListener('close', () => {
      busy = true;
      line = '';
      status.textContent = 'Reconnect · new session';
      status.dataset.state = 'disconnected';
      document.getElementById('scene-index').textContent = 'SESSION ENDED';
      room.textContent = 'Your connection has closed. Reconnect to choose a new adventure.';
      term.write('\r\n\x1b[33mConnection closed. Reconnecting starts a fresh session.\x1b[0m\r\n');
    });
    socket.addEventListener('error', () => socket.close());
  }
  term.onData(data => {
    if (busy || socket.readyState !== WebSocket.OPEN) return;
    if (data === '\r') {
      const command = line.trim();
      term.write('\r\n');
      if (!command) { line = ''; drawPrompt(); return; }
      history.push(command);
      if (history.length > 100) history.shift();
      historyIndex = history.length;
      line = '';
      busy = true;
      socket.send(JSON.stringify({type: 'command', line: command}));
    } else if (data === '\x7f' || data === '\b') {
      if (line.length) { line = line.slice(0, -1); term.write('\b \b'); }
    } else if (data === '\x1b[A') {
      if (historyIndex > 0) replaceLine(history[--historyIndex]);
    } else if (data === '\x1b[B') {
      if (historyIndex < history.length) replaceLine(history[++historyIndex] || '');
    } else if (data === '\x03' || data === '\x15') {
      replaceLine('');
    } else if (!data.includes('\x1b')) {
      const input = data.replace(/[^\x20-\x7e]/g, '').slice(0, 256 - line.length);
      line += input;
      write(input);
    }
  });
  status.addEventListener('click', () => { if (status.dataset.state === 'disconnected') { connect(); term.focus(); } });
  new ResizeObserver(() => fit.fit()).observe(document.getElementById('terminal'));
  fit.fit();
  connect();
  term.focus();
})();
