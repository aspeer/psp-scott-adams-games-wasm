# adventure

The `ws($self, $param_hr)` handler is registered by `app.psp`. It accepts a PAGI
WebSocket connection and immediately sends a terminal catalogue. Each connection
owns its own `ScottGame` object; disconnect releases it.

The browser sends JSON text frames: `{"type":"command","line":"get axe"}`.
Lines are limited to 256 characters, JSON frames to 4096 characters, and control
characters are rejected. Game selection is restricted to the built-in catalogue.

Replies have `type` (`menu`, `turn`, `info`, or `error`) and `output`. A menu or
turn also supplies `title`, `room`, `turns`, and `prompt`. Turns may include
`started` and `ended` flags. The UI inserts scene text with `textContent` and
filters terminal control characters from game output.

Use a number or full game name in the menu. `/menu` and `q` discard the current
game; `/restart` creates a fresh instance of the selected game; `/help` explains
controls. There is no persistence, login, or shared play.
