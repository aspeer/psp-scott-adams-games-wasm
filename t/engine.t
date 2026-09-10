use strict;
use warnings;
use Test::More;
use ScottGame;

foreach my $file (glob('app/games/*.dat')) {
    subtest $file => sub {
        my @warnings;
        local $SIG{'__WARN__'}=sub { push(@warnings, @_); };
        my $game_or=ScottGame->new($file);
        my $first_hr=$game_or->response();
        ok(length($first_hr->{'room'}), 'initial room rendered');
        like($first_hr->{'output'}, qr/Version/, 'database version parsed');
        foreach my $command ('inventory', 'look', 'help', 'score') {
            my $reply_hr=$game_or->command($command);
            ok(length($reply_hr->{'room'}), "$command returns a scene");
        }
        is_deeply(\@warnings, [], 'no engine warnings');
    };
}

subtest 'independent players and restart' => sub {
    my $one_or=ScottGame->new('app/games/mini-adventure.dat');
    my $two_or=ScottGame->new('app/games/mini-adventure.dat');
    $one_or->response();
    $two_or->response();
    like($one_or->command('e')->{'room'}, qr/sunny meadow/, 'first player moves');
    like($two_or->command('look')->{'room'}, qr/in a forest/, 'second player stays');
    $one_or->command('e');
    like($one_or->command('get axe')->{'output'}, qr/O.K./, 'first player takes axe');
    $two_or->command('e');
    like($two_or->command('e')->{'room'}, qr/Rusty axe/, 'second player still sees own axe');
    unlike($one_or->command('look')->{'room'}, qr/Rusty axe/, 'first player no longer sees carried axe');
    like($one_or->command('i')->{'output'}, qr/Rusty axe/, 'inventory shortcut');
    like($one_or->command('drop axe')->{'room'}, qr/Rusty axe/, 'drop restores room item');
    my $fresh_or=ScottGame->new('app/games/mini-adventure.dat');
    like($fresh_or->response()->{'room'}, qr/in a forest/, 'fresh game starts at beginning');
};

subtest 'invalid input and random event range' => sub {
    my $game_or=ScottGame->new('app/games/mini-adventure.dat');
    $game_or->response();
    like($game_or->command('xyzzy')->{'output'}, qr/don't know/, 'unknown vocabulary handled');
    is($game_or->{'turns'}, 0, 'unknown word does not consume a turn');
    like($game_or->command('save')->{'output'}, qr/Saving is disabled/, 'save is explicit');
    like($game_or->command('go')->{'output'}, qr/direction/, 'missing direction handled');
    my $hits=0;
    $hits+=$game_or->random_percent(50) foreach (1..1000);
    ok($hits>300 && $hits<700, 'random events can both fire and not fire');
    is($game_or->random_percent(0), '', 'zero percent never fires');
    ok($game_or->random_percent(100), '100 percent always fires');
};

subtest 'mini-adventure complete walkthrough' => sub {
    my $game_or=ScottGame->new('app/games/mini-adventure.dat');
    $game_or->response();
    my @commands=('Go East', 'Go East', 'Get Axe', 'Go North', 'Get Ox',
        'Say Bunyon', 'Swim', 'Go South', 'Go West', 'Take mud', 'Go West',
        'Get Axe', 'Get Ox', 'Get Fruit', 'Go East', 'Take mud', 'Chop Tree',
        'Drop Axe', 'Get Mud', 'Go Stump', 'Drop Mud', 'Drop Ox', 'Drop Fruit',
        'Go Down', 'Get Rubies', 'Go Up', 'Drop Rubies', 'Score');
    my $reply_hr;
    foreach my $command (@commands) {
        $reply_hr=$game_or->command($command);
        note("$command: $reply_hr->{'output'}");
    }
    like($reply_hr->{'output'}, qr/100/, 'all treasures scored');
    ok($reply_hr->{'ended'}, 'winning ends only this game');
    my $next_or=ScottGame->new('app/games/mini-adventure.dat');
    like($next_or->response()->{'room'}, qr/forest/, 'interpreter still runs after game over');
};

done_testing();
