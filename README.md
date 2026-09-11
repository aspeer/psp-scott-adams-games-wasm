# Scott Adams Adventure Terminal

A terminal-based library of 16 Scott Adams adventures. The Perl game engine runs
on the server, driven by a WebDyne::PAGI WebSocket. The same app runs under native
`webdyne.pagi` and inside `@webdyne/webdyne-zeroperl` on Cloudflare Workers.

Play the deployed demo: https://psp-scott-adams-games-wasm.andrew-speer.workers.dev/

## Native PAGI

Use a Perl environment with WebDyne::PAGI, PAGI::Server, PAGI::Tools, and
Future::AsyncAwait installed (also listed in `cpanfile.native`). Then, from this
repository:

```sh
npm start
# Equivalent:
webdyne.pagi --host 127.0.0.1 --port 3000 --index=app.psp app
```

Open http://127.0.0.1:3000/. Restart the server after changing `.pm` modules.
The native server binds only to loopback; the public demo is the Worker deployment.

## ZeroPerl / Cloudflare

Node 22 or newer is needed for the integration test's built-in WebSocket client.
Install the locked dependencies and run the Worker locally:

```sh
npm ci
npm run check
npm run dev -- -- --port 8787
```

Open http://127.0.0.1:8787/. Restart `npm run dev` after changing server files
so they are repackaged into the virtual filesystem. Static assets are served by
Cloudflare; modules and game databases remain in the Perl VFS.

To publish to the authenticated Cloudflare account:

```sh
npm run whoami
npm run deploy
```

The Worker name is `psp-scott-adams-games-wasm`, defined in `wrangler.jsonc`.
No database, Durable Object, KV namespace, or other state service is required.

## Playing

Enter a number or full game name at the terminal menu. Use one or two words,
for example `LOOK`, `GET AXE`, `GO NORTH`, or `HELP`.

- `N S E W U D` move; `I` shows inventory.
- Up/Down recall commands; Backspace edits; Ctrl-U/C clears the input.
- `/help` explains controls without consuming a game turn.
- `/menu` or `q` discards the current game and returns to the catalogue.
- `/restart` starts the selected adventure over.

The current room, exits, and objects stay above the transcript. Every connection
has an independent game. Disconnect, refresh, or Worker restart discards the
session; reconnecting returns to the catalogue. Saving and loading are disabled.
Original timed pause opcodes execute immediately; game turns still advance only
when commands are submitted. The game data and classic puzzle rules are preserved.

## Validation

```sh
npm test
npm run test:socket
APP_URL=http://127.0.0.1:8787/ npm run test:socket
wdlint app/app.psp
wdrender --raw app/app.psp > /tmp/adventure.html
npm run check
```

Start the corresponding server before running socket tests. The same socket suite
can target the deployed HTTPS URL using `APP_URL`. It checks HTTP/static assets,
message validation, all 16 games, independent players, restart, disconnect/reconnect,
and a complete mini-adventure walkthrough scoring 100. Engine tests also check
inventory, room changes, unknown commands, random events, and game-over handling.
The other adventures are smoke-tested, not verified with complete walkthroughs.

## Source layout

- `app/app.psp`: WebDyne page and WebSocket registration.
- `app/adventure.pm`: terminal catalogue and per-connection lifecycle.
- `app/ScottGame.pm`: adapted instance-based interpreter.
- `app/adventure.js` and `app/adventure.css`: xterm interface and scene panel.
- `app/games/`: bundled game databases and original copyright notice.
- `t/` and `scripts/test-socket.mjs`: engine and transport tests.

All required game files were copied into this repository. The original
`scott-adams-games` and `psp-WebDyne-ws-Terminal-WASM` repositories are references;
this app does not depend on their paths or modify their files.

## Attribution

The interpreter is adapted from Curtis "Ovid" Poe's 2013 `scott.pl`, distributed
under the same terms as Perl 5, itself based on ScottFree 1.14 from Swansea
University Computer Society (1993–1995), distributed under GPLv2. Original
notices and database-format documentation are preserved in `docs/upstream/`.

The original Github repo the games were sourced from is
<https://github.com/Ovid/scott-adams-games.git>

The games remain copyright Scott Adams; they are not public domain. Their
original notice is `app/games/readme_sa.txt`; the source distribution's bundling
permission statement is preserved in `docs/upstream/README-perl.md`.

MIT notice is included in each asset and in `docs/upstream/LICENSE-xterm.txt`.
The ZeroPerl package carries its own third-party notices.
