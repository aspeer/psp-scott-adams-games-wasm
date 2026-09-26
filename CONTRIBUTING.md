# Contributing to Scott Adams Adventure Terminal

Bug reports and focused contributions are welcome. Search the
[GitHub issues](https://github.com/aspeer/psp-scott-adams-games-wasm/issues)
before opening a new one, and include a minimal reproduction where possible.

Fork the
[GitHub repository](https://github.com/aspeer/psp-scott-adams-games-wasm),
create a topic branch, keep changes focused, and submit a GitHub pull request.
Run the local checks before submitting:

```sh
npm ci
npm test
npm run check
```

Run `npm run test:socket` against a local server for transport or interface
changes. Do not add or replace copyrighted game databases without documented
permission, use production Cloudflare resources, or deploy as part of a
contribution. Report potential vulnerabilities privately as described in
[SECURITY.md](SECURITY.md).
