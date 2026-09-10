# WebDyne / aspeer-zeroperl observations

No WebDyne or ZeroPerl source was modified. The app uses
`@webdyne/webdyne-zeroperl` 1.0.6 and its bundled Wrangler 4.127.1.
These observations were made on 2026-09-10.

## Literal non-ASCII PSP text is mojibake under native PAGI

Observed with the installed native `webdyne.pagi` 3.026: a UTF-8 PSP title
containing a literal middle dot appeared as `Scott Adams Â· Adventure Terminal`.
A literal copyright symbol in the body similarly appeared as `Â©`; filled
circles were also corrupted. The generated markup already declared UTF-8.
`wdrender --raw` printed the intended characters but reported "Wide character
in print" at its output step. The precise decoding/encoding layer has not been
isolated, so this is an observed native-path issue rather than a confirmed
ZeroPerl defect.

Minimal reproduction to investigate:

```html
<start_html title="Scott Adams · Adventure Terminal">
<p>Games © Scott Adams · ●</p>
```

Serve the UTF-8 file with native `webdyne.pagi` and compare browser text and HTTP
bytes with `wdrender --raw` output. Check source decoding, renderer encoding,
and PAGI response-byte conversion for double encoding.

App workaround: use `&middot;` and `&copy;` in PSP markup and draw status dots
with CSS. Browser verification now displays correct characters. No global
encoding override or runtime patch is used.

## Caught exception text gains a stack trace in native PAGI

An early engine version used `die "SCOTT_GAME_OVER\n"` inside an `eval` and
compared `$@` with that exact sentinel. Unit tests passed, but the native server
appended a stack trace, so the exact-string comparison failed and a normal game
over was treated as an error. This may be installed diagnostic handler behavior,
not WebDyne itself; the cause has not been isolated.

App resolution: game-over is now ordinary instance state and returns normally.
There is no exception sentinel, global signal override, or WebDyne modification.
A complete mini-adventure win passes through both native and ZeroPerl sockets.
Potential upstream improvement: document how exception hooks affect errors
caught inside application `eval` blocks.

## Informational lifespan startup is logged as an error by ZeroPerl

Local Wrangler prints the normal message
`zeroperl: [lifespan] WebDyne PAGI handler startup...` at ERROR severity, although
startup succeeds and HTTP/WebSocket tests pass. The runtime appears to map this
stderr output to error logging. No app workaround is necessary. Consider
preserving informational severity for normal lifecycle messages.

## Pinned toolchain dependency advisory

`npm audit` reports a high-severity libheif advisory through
`@webdyne/webdyne-zeroperl -> wrangler -> miniflare -> sharp`, referencing
GHSA-g89c-p67h-r497 and GHSA-2jg2-4ch7-h545. npm reports no available fix for this
pinned dependency chain. The demo does not use image processing or accept image
uploads. No overrides or runtime updates were applied. Revisit the bundled
Wrangler/Miniflare/sharp versions in a subsequent ZeroPerl package release.

## Integration notes

- Native `webdyne.pagi` must be restarted after editing required `.pm` modules.
- ZeroPerl's dev command builds the server VFS once; restart it after server
  edits. The npm forwarding syntax is `npm run dev -- -- --port 8787`.
- The app has no extra Wasm CPAN dependencies. `cpanfile.native` documents native
  prerequisites without triggering duplicate runtime-module installation in
  the ZeroPerl build.
- A project-owned `wrangler.jsonc` selects the bundled workerd's supported compatibility date, preserves
  `enable_request_signal`, disables Perl static serving, and enables logs/traces.
- The source `.assetsignore` keeps Perl modules and `.dat` game files in the VFS;
  Cloudflare serves JavaScript/CSS and the original game notice as static assets.

## Bundled workerd compatibility-date ceiling

The package's workerd rejects `2026-09-10`: its newest supported date is
`2026-09-04`. The app therefore pins `2026-09-04` in `wrangler.jsonc` for identical
local and deployed behavior. This is a normal toolchain-version constraint,
not a game/runtime viability blocker; no package upgrade was needed.
