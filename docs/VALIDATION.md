# Validation — 2026-09-10

Both milestones are complete:

1. Native `webdyne.pagi` at `http://127.0.0.1:3000/`.
2. ZeroPerl on Cloudflare Workers at
   `https://psp-scott-adams-games-wasm.andrew-speer.workers.dev/`.

The native and local Worker servers were run with the same application files.
`npm test` passes 26 top-level tests/subtests covering all databases, independent
instances, inventory changes, restart state, command parsing, random percentages,
menu selection stability, and the mini-adventure walkthrough.

The real WebSocket suite passed against native PAGI, local workerd/ZeroPerl,
and the deployed HTTPS/WSS endpoint. It verifies:

- HTTP page and static assets, including the original game notice.
- Rejection of malformed JSON, binary messages, oversized commands, controls,
  and attempts to select a filesystem path.
- Starting all 16 games and issuing inventory commands.
- Two simultaneous players moving independently.
- Menu transitions, restart, and fresh state after disconnect/reconnect.
- A complete mini-adventure walkthrough ending with 100 points.
- Continued operation of the other player after one player wins.

Public requests for `ScottGame.pm`, `adventure.pm`, and
`games/adventureland.dat` return 404. Deployment uploaded only six static assets;
Perl source and databases stay in the VFS.

`wdlint`, Perl module syntax checks, JavaScript syntax checks, and the Wrangler
deployment dry run passed. `wdrender` renders successfully with a nonfatal
wide-character output warning, documented in `WEBDYNE.md`.

Browser checks covered the terminal catalogue, selecting an adventure, current
room rendering, WebSocket connection state, and the desktop layout. The game
library is a two-column terminal menu. Native and deployed pages use the same
xterm frontend.

The remaining adventures have startup/command smoke coverage, not complete
puzzle walkthroughs. This is a demo with no persistence or load-test guarantee.
The pinned toolchain's npm advisory and observed runtime issues are recorded in
`WEBDYNE.md`; no upstream source was changed.
