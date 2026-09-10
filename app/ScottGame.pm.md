# ScottGame

An instance-based adaptation of the supplied Scott Adams Perl interpreter.
The database format and action opcodes follow the original driver; game state
belongs to the instance. The original notices and format definition are in
`docs/upstream/`.

```perl
my $game_or=ScottGame->new('app/games/adventureland.dat');
my $opening_hr=$game_or->response();
my $turn_hr=$game_or->command('go north');
```

`new($database_fn)` loads a trusted, bundled database and executes opening
automatic actions. `response()` returns the current scene and drains accumulated
output. `command($line)` processes one command, updates the lamp and automatic
actions, and returns the same response shape:

- `output`: text produced since the previous response.
- `room`: current room, visible objects, and exits.
- `turns`: number of accepted game commands.
- `ended`: true when a game-ending action has occurred.

Unknown verbs do not consume a turn. N/S/E/W/U/D and I are expanded. Remaining
text after the verb is retained for database actions such as SAY. Save and load
report that persistence is disabled. The transport handles `/menu`, `/restart`,
`/help`, and `q` before calling the engine.

The engine is synchronous and never awaits, sleeps, exits the process, starts a
subprocess, or reads terminal input. Output capture is scoped to each synchronous
call. Discard the object to discard the session. No state is kept in package
globals. Unexpected parsing/action errors throw; ordinary game completion is
represented by `ended` and does not throw.

Changes from the supplied driver include replacing `given/when`, instance-owned
state and recursion guards, initializing saved counters/rooms, correcting random
percentages and missing direction handling, guarding zero-treasure scores,
removing an inventory debug dump, accepting signed database integers, and
replacing process-exit and delay opcodes. Delay opcodes are immediate in this demo.
