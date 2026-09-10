use strict;
use warnings;
use Test::More;
use adventure;

my $original_hr=adventure::menu();
is(adventure::selection('ADVENTURELAND'), 0, 'case insensitive title selection');
is(adventure::selection('the count'), 4, 'full title selection');
is(adventure::selection('16'), 15, 'mini-adventure selection');
ok(!defined(adventure::selection('../ScottGame.pm')), 'path input rejected');
ok(!defined(adventure::selection('0')), 'zero rejected');
ok(!defined(adventure::selection('17')), 'out of range rejected');
is_deeply(adventure::menu(), $original_hr, 'selection does not mutate catalogue names');
done_testing();
