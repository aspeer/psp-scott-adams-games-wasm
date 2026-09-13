# npm upgrade review — 2026-09-13

The application passes against published npm ZeroPerl 1.0.15. No Worker was published.

## Changes and findings

- Pin `@webdyne/webdyne-zeroperl` to 1.0.15 and regenerate the npm lockfile. It contains WebDyne 3.029, Perl 5.44.0 and Wrangler 4.131.1.
- Change the HTML title separator to ASCII. The original `&middot;` rendered as byte `b7` under an HTTP UTF-8 declaration, producing a replacement character in the browser. A numeric entity reproduced the same problem. This application workaround avoids the problematic title character without patching the installed npm package.
- Decode HTTP test output with a fatal UTF-8 decoder. The previous `response.text()` silently replaced malformed bytes and the mojibake assertion missed this failure.
- Extend the HTTP/WebSocket suite to assert 404 for both Perl modules, the module sidecar and a game database.

No game-engine or WebSocket API migration is needed. The handler already uses connection-local state, explicit receive/send callbacks and awaited operations. Existing static-assets configuration keeps game databases and modules in the VFS. The `enable_request_signal` flag is already present. Existing observability edits are preserved.

## Isolation and provenance

Working files were copied to `/tmp/webdyne-npm-review-20260913/psp-scott-adams-games-wasm`, excluding existing dependencies, generated output, secrets and Wrangler state. Packages were downloaded from `https://registry.npmjs.org` into a fresh task npm cache with `--ignore-scripts`. No file/git dependencies or local package links were used. Runtime commands unset `NODE_PATH` and `PERL5LIB`.

The downloaded WASM matches the package manifest SHA256:

```
d052a09b9c57a859177f254c5a59ffcb33e956c750c7c0555dcf4ad396a90c8f
```

Wrangler ran locally on 127.0.0.1:8788, with separate task configuration/logs. The application has no remote resource bindings. The lockfile records the exact npm tarball URL and integrity hash.

## Results

Fresh `npm ci --ignore-scripts` also passes in a second empty directory using the final repository manifest and lockfile.

- `npm test`: 26 tests/subtests pass across engine and menu suites.
- `APP_URL=http://127.0.0.1:8788/ npm run test:socket`: passes after the title fix. Covers strict UTF-8 HTTP, assets, private-file 404s, malformed/binary/oversized/control input, all 16 games, independent concurrent players, restart, reconnect and a complete mini-adventure walkthrough scoring 100. The second player remains usable after the first wins.
- Browser: corrected title, connected terminal, Adventureland selection, and moving east from the forest to the sunny meadow all verified.
- Native `wdlint` and main-page `wdrender` pass as supplementary syntax/render checks. The compatibility conclusion uses the published WASM Worker, not native or sibling runtime packages.
- Build and `npm run check` deployment dry run pass. Final compressed Worker upload: 4724.83 KiB, with public assets separate.

Reproduce from a clean directory using `npm ci`, `npm run check`, and `npm run dev -- -- --local --port 8788`; then run `APP_URL=http://127.0.0.1:8788/ npm run test:socket`.

## Limits

No new edge deployment, load test or complete walkthrough of the other 15 adventures was performed. The title issue is worked around in the application; the npm runtime was not modified. Wrangler reported an assets-watcher platform-limit warning on this host; final server changes were explicitly rebuilt. The earlier deployed-runtime qualification in `VALIDATION.md` remains historical evidence for the earlier release only.
