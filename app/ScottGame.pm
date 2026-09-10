# Adapted from Curtis "Ovid" Poe's scott.pl (2013), Perl 5 terms.
# Based on ScottFree 1.14, Swansea University Computer Society (1993-1995), GPLv2.
# See docs/upstream for the original notices and database specification.
package ScottGame;

use strict;
use warnings;
use feature 'say';
use Carp 'croak';
use Data::Dumper;

# verbs
use constant AUT       => 0;
use constant GO        => 1;
use constant JUMP      => 6;
use constant AT        => 7;
use constant CHO       => 8;
use constant GET       => 10;
use constant LIG       => 14;
use constant DROP      => 18;
use constant THR       => 24;
use constant QUI       => 26;
use constant SWI       => 27;
use constant RUB       => 28;
use constant LOO       => 29;
use constant STO       => 32;
use constant SCO       => 33;
use constant INVENTORY => 34;
use constant SAV       => 35;
use constant WAK       => 36;
use constant UNL       => 37;
use constant REA       => 38;
use constant ATT       => 39;
use constant DRI       => 42;
use constant FIN       => 45;
use constant HEL       => 47;
use constant SAY       => 48;
use constant SCR       => 51;
use constant FIL       => 55;
use constant CRO       => 56;
use constant DAM       => 57;
use constant MAK       => 58;
use constant WAV       => 60;
use constant OPE       => 69;

# nouns

# misc
use constant LIGHT_SOURCE => 9;      #  Always 9 how odd
use constant CARRIED      => 255;    #  Carried
use constant DESTROYED    => 0;      #  Destroyed
use constant DARKBIT      => 15;     #
use constant LIGHTOUTBIT  => 16;     #  Light gone out

sub new {
    my ($class, $database_fn)=@_;
    my $self=bless({
        Items => [], Rooms => [], Verbs => [], Nouns => [], Messages => [], Actions => [],
        Counters => [(0) x 16], RoomSaved => [(0) x 16], GameHeader => {},
        CurrentCounter => 0, SavedRoom => 0, BitFlags => 0, Redraw => 0,
        NounText => '', disable_sysfunc => 0, SECOND_PERSON => 1,
        SCOTTLIGHT => 0, PREHISTORIC_LAMP => 1, Options => 0, TRACE => 0,
        ended => 0, output => '', turns => 0,
    }, $class);
    $self->capture(sub {
        $self->load_database($database_fn);
        $self->perform_actions(0, 0);
    });
    return $self;
}


#  Capture only synchronous engine work. Nothing suspends with STDOUT localized.
#
sub capture {
    my ($self, $callback_cr)=@_;
    my $text='';
    my $error;
    {
        open(my $output_fh, '>', \$text) or die "cannot capture game output: $!";
        local *STDOUT=$output_fh;
        local $@;
        eval { $callback_cr->(); 1 } or $error=$@;
    }
    $self->{'output'}.=$text;
    die $error if $error;
    return;
}


sub finish {
    my $self=shift();
    $self->{'ended'}=1;
    print "The game is now over. Type /restart or /menu.\n";
    return;
}


sub save_game {
    print "Saving is disabled in this demo. Disconnecting resets your game.\n";
}


sub response {
    my $self=shift();
    my $output=$self->{'output'};
    $self->{'output'}='';
    return {output => $output, room => $self->look(),
        ended => $self->{'ended'}, turns => $self->{'turns'}};
}


sub command {
    my ($self, $line)=@_;
    return $self->response() if $self->{'ended'};
    $line=~s/^\s+|\s+$//g;
    return $self->response() unless length($line);
    $self->capture(sub {
        my ($verb, $noun)=split(/\s+/, $line, 2);
        my %short=(n => 'north', s => 'south', e => 'east', w => 'west',
            u => 'up', d => 'down', i => 'inventory');
        $verb=$short{lc($verb)} if !defined($noun) && exists($short{lc($verb)});
        $noun='' unless defined($noun);
        if (lc($verb) eq 'save' || lc($verb) eq 'load') {
            $self->save_game();
            return;
        }
        my $noun_no=$self->which_word($verb, $self->{'Nouns'});
        my $verb_no;
        if (defined($noun_no) && $noun_no>=1 && $noun_no<=6) {
            $verb_no=1;
        }
        else {
            $verb_no=$self->which_word($verb, $self->{'Verbs'});
            $noun_no=$self->which_word($noun, $self->{'Nouns'});
        }
        unless (defined($verb_no) && $verb_no>0) {
            print "You use word(s) I don't know!\n";
            return;
        }
        $self->{'NounText'}=$noun;
        $self->{'turns'}++;
        my $result=$self->perform_actions($verb_no, $noun_no);
        return if $self->{'ended'};
        print "I don't understand your command.\n" if defined($result) && $result==-1;
        print "I can't do that yet.\n" if defined($result) && $result==-2;
        $self->tick_light();
        $self->perform_actions(0, 0);
    });
    return $self->response();
}


sub tick_light {
    my $self=shift();
        #  Brian Howarth games seem to use -1 for forever
        if ( $self->{'Items'}[LIGHT_SOURCE]{Location} != DESTROYED && $self->{'GameHeader'}{LightTime} != -1 ) {
            $self->{'GameHeader'}{LightTime}--;
            if ( $self->{'GameHeader'}{LightTime} < 1 ) {
                $self->{'BitFlags'} |= ( 1 << LIGHTOUTBIT );
                if (   $self->{'Items'}[LIGHT_SOURCE]{Location} == CARRIED
                    || $self->{'Items'}[LIGHT_SOURCE]{Location} == $self->my_loc() )
                {
                    if ($self->{'SCOTTLIGHT'}) {
                        say("Light has run out! ");
                    }
                    else {
                        say("Your light has run out. ");
                    }
                }
                if ( $self->{'Options'} & $self->{'PREHISTORIC_LAMP'} ) {
                    $self->{'Items'}[LIGHT_SOURCE]{Location} = DESTROYED;
                }
            }
            elsif ( $self->{'GameHeader'}{LightTime} < 25 ) {
                if (   $self->{'Items'}[LIGHT_SOURCE]{Location} == CARRIED
                    || $self->{'Items'}[LIGHT_SOURCE]{Location} == $self->my_loc() )
                {

                    if ($self->{'SCOTTLIGHT'}) {
                        say("Light runs out in $self->{'GameHeader'}{LightTime} turns");
                    }
                    else {
                        if ( $self->{'GameHeader'}{LightTime} % 5 == 0 ) {
                            say("Your light is growing dim.");
                        }
                    }
                }
            }
        }
}

sub strncasecmp {
    my $self=shift();
    my ( $word1, $word2, $length ) = @_;
    return lc( substr $word1, 0, $length ) eq lc( substr $word2, 0, $length );
}

sub map_synonym {
    my $self=shift();
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->map_synonym(@_)";
    }
    my $word = shift;
    my $lastword;

    for my $i ( 0 .. $self->{'GameHeader'}{NumWords} ) {
        my $curr_word = $self->{'Nouns'}[$i];
        unless ( $curr_word =~ s/^\*// ) {
            $lastword = $curr_word;
        }
        if ( $self->strncasecmp( $curr_word, $word, $self->{'GameHeader'}{WordLength} ) ) {
            return $lastword;
        }
    }
    return;
}

sub which_word {
    my $self=shift();
    my ( $word, $list ) = @_;
    my $lastword;
    foreach my $index ( 0 .. $self->{'GameHeader'}{NumWords} ) {
        my $curr_word = $list->[$index];
        unless ( $curr_word =~ s/^\*// ) {
            $lastword = $index;
        }
        if ( $self->strncasecmp( $curr_word, $word, $self->{'GameHeader'}{WordLength} ) ) {
            return $lastword;
        }
    }
    return;
}

sub match_up_item {
    my $self=shift();
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->match_up_item(@_)";
    }
    my ( $text, $loc ) = @_;
    my $word = $self->map_synonym($text) // $text;

    for my $i ( 0 .. $self->{'GameHeader'}{NumItems} ) {
        my $item = $self->{'Items'}[$i];
        if (   $item->{AutoGet}
            && $item->{Location} == $loc
            && $self->strncasecmp( $item->{AutoGet}, $word, $self->{'GameHeader'}{WordLength} ) )
        {
            return $i;
        }
    }
    return;
}

sub my_loc {
    my $self=shift(); $self->{'GameHeader'}{PlayerRoom} }



sub random_percent {
    my $self=shift();
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->random_percent(@_)";
        return $_[0] < 50;
    }
    my $n  = shift;
    my $rv = int(rand(100));
    $rv %= 100;
    return $rv < $n;
}

sub count_carried {
    my $self=shift();
    my $num = 0;
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->count_carried(@_)";
    }
    for my $ct ( 0 .. $self->{'GameHeader'}{NumItems} ) {
        if ( $self->item_is( $ct, CARRIED ) ) {
            $num++;
        }
    }
    return $num;
}

sub item_is {
    my $self=shift();
    my ( $i, $status ) = @_;
    return $self->{'Items'}[$i]{Location} == $status;
}

sub perform_line {
    my $self=shift();
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->perform_line(@_)";
    }
    my $ct           = shift;
    my $continuation = 0;
    my @param;
    my $pptr = 0;
    my @act;
    my $cc = 0;
    while ( $cc < 5 ) {
        my $cv = $self->{'Actions'}[$ct]{Condition}[$cc];
        my $dv = int( $cv / 20 );
        $cv %= 20;
        if ($self->{'TRACE'}) {
            say STDERR "PerformLine top:\n\tcc: $cc\n\tdv: $dv\n\tcv: $cv\n\tpptr: $pptr";
        }
        {
            my $condition = $cv;
            if ($condition == 0) { $param[ $pptr++ ] = $dv; }
            elsif ($condition == 1) {
                if ( !$self->item_is( $dv, CARRIED ) ) { return 0; }
            }
            elsif ($condition == 2) {
                if ( !$self->item_is( $dv, $self->my_loc() ) ) { return 0; }
            }
            elsif ($condition == 3) {
                if ( !$self->item_is( $dv, CARRIED ) && !$self->item_is( $dv, $self->my_loc() ) ) { return 0; }
            }
            elsif ($condition == 4) {
                if ( $self->my_loc() != $dv ) { return 0; }
            }
            elsif ($condition == 5) {
                if ( $self->item_is( $dv, $self->my_loc() ) ) { return 0; }
            }
            elsif ($condition == 6) {
                if ( $self->item_is( $dv, CARRIED ) ) { return 0; }
            }
            elsif ($condition == 7) {
                if ( $self->my_loc() == $dv ) { return 0; }
            }
            elsif ($condition == 8) {
                if ( ( $self->{'BitFlags'} & ( 1 << $dv ) ) == 0 ) { return 0; }
            }
            elsif ($condition == 9) {
                if ( $self->{'BitFlags'} & ( 1 << $dv ) ) {
                    if ($self->{'TRACE'}) {
                        print STDERR "Returning from case 9\n";
                    }
                    return 0;
                }
            }
            elsif ($condition == 10) {
                if ( $self->count_carried() == 0 ) { return 0; }
            }
            elsif ($condition == 11) {
                if ( $self->count_carried() ) { return 0; }
            }
            elsif ($condition == 12) {
                if ( $self->item_is( $dv, CARRIED ) || $self->item_is( $dv, $self->my_loc() ) ) { return 0; }
            }
            elsif ($condition == 13) {
                if ( $self->item_is( $dv, 0 ) ) { return 0; }
            }
            elsif ($condition == 14) {
                if ( $self->{'Items'}[$dv]{Location} ) { return 0; }
            }
            elsif ($condition == 15) {
                if ( $self->{'CurrentCounter'} > $dv ) { return 0; }
            }
            elsif ($condition == 16) {
                if ( $self->{'CurrentCounter'} <= $dv ) { return 0; }
            }
            elsif ($condition == 17) {
                if ( $self->{'Items'}[$dv]{Location} != $self->{'Items'}[$dv]{InitialLoc} ) { return 0; }
            }
            elsif ($condition == 18) {
                if ( $self->{'Items'}[$dv]{Location} == $self->{'Items'}[$dv]{InitialLoc} ) { return 0; }
            }
            elsif ($condition == 19) {    #  Only seen in Brian Howarth games so far
                if ( $self->{'CurrentCounter'} != $dv ) { return 0; }
            }
        }
        $cc++;
    }

    # Actions
    $act[0] = $self->{'Actions'}[$ct]{Action}[0];
    $act[2] = $self->{'Actions'}[$ct]{Action}[1];
    $act[1] = $act[0] % 150;
    $act[3] = $act[2] % 150;
    $act[0] /= 150;
    $act[2] /= 150;
    $_    = int($_) foreach @act[ 0, 2 ];
    $cc   = 0;
    $pptr = 0;
    while ( $cc < 4 ) {

        if ($self->{'TRACE'}) {
            say STDERR "ct: $ct\ncc: $cc\nact[cc]: $act[$cc]";
        }
        if ( $act[$cc] >= 1 && $act[$cc] < 52 ) {
            say STDERR "\tPerformLine First" if $self->{'TRACE'};
            say( $self->{'Messages'}[ $act[$cc] ] );
        }
        elsif ( $act[$cc] > 101 ) {
            say STDERR "\tPerformLine Second" if $self->{'TRACE'};
            say( $self->{'Messages'}[ $act[$cc] - 50 ] );
        }
        else {
            say STDERR "\tPerformLine Switch" if $self->{'TRACE'};
            {
                my $action = $act[$cc];
                if ($action == 0) {}    #  NOP
                elsif ($action == 52) {
                    if ( $self->count_carried() == $self->{'GameHeader'}{MaxCarry} ) {
                        if   ($self->{'SECOND_PERSON'}) { say("You are carrying too much. "); }
                        else                  { say("I've too much to carry! "); }
                    }
                    else {
                        if ( $self->{'Items'}[ $param[$pptr] ]{Location} == $self->my_loc() ) { $self->{'Redraw'} = 1; }
                        $self->{'Items'}[ $param[ $pptr++ ] ]{Location} = CARRIED;
                    }
                }
                elsif ($action == 53) {
                    $self->{'Redraw'} = 1;
                    $self->{'Items'}[ $param[ $pptr++ ] ]{Location} = $self->my_loc();
                }
                elsif ($action == 54) {
                    $self->{'Redraw'} = 1;
                    $self->{'GameHeader'}{PlayerRoom} = $param[ $pptr++ ];
                }
                elsif ($action == 55) {
                    if ( $self->{'Items'}[ $param[$pptr] ]{Location} == $self->my_loc() ) { $self->{'Redraw'} = 1; }
                    $self->{'Items'}[ $param[ $pptr++ ] ]{Location} = 0;
                }
                elsif ($action == 56) {
                    $self->{'BitFlags'} |= 1 << DARKBIT;
                }
                elsif ($action == 57) {
                    $self->{'BitFlags'} &= ~( 1 << DARKBIT );
                }
                elsif ($action == 58) {
                    $self->{'BitFlags'} |= ( 1 << $param[ $pptr++ ] );
                }
                elsif ($action == 59) {
                    if ( $self->{'Items'}[ $param[$pptr] ]{Location} == $self->my_loc() ) { $self->{'Redraw'} = 1; }
                    $self->{'Items'}[ $param[ $pptr++ ] ]{Location} = 0;
                }
                elsif ($action == 60) {
                    $self->{'BitFlags'} &= ~( 1 << $param[ $pptr++ ] );
                }
                elsif ($action == 61) {
                    if   ($self->{'SECOND_PERSON'}) { say("You are dead.\n"); }
                    else                  { say("I am dead.\n"); }
                    $self->{'BitFlags'} &= ~( 1 << DARKBIT );
                    $self->{'GameHeader'}{PlayerRoom} = $self->{'GameHeader'}{NumRooms};    #  It seems to be what the code says!
                    say $self->look();
                }
                elsif ($action == 62) {
                    {

                        #  Bug fix for some systems - before it could get parameters wrong
                        my $i = $param[ $pptr++ ];
                        $self->{'Items'}[$i]{Location} = $param[ $pptr++ ];
                        $self->{'Redraw'} = 1;
                    }
                }
                elsif ($action == 63) {
                    $self->finish();
                    return 1;
                }
                elsif ($action == 64) {
                    say $self->look();
                }
                elsif ($action == 65) {
                    my $ct = 0;
                    my $n  = 0;
                    while ( $ct <= $self->{'GameHeader'}{NumItems} ) {
                        if (   $self->{'Items'}[$ct]{Location} == $self->{'GameHeader'}{TreasureRoom}
                            && $self->{'Items'}[$ct]{Text} =~ /^\*/ )
                        {
                            $n++;
                        }
                        $ct++;
                    }
                    if   ($self->{'SECOND_PERSON'}) { say("You have stored "); }
                    else                  { say("I've stored "); }
                    print("$n treasures.  On a scale of 0 to 100, that rates ");
                    say( $self->{'GameHeader'}{Treasures} ? int( ( $n * 100 ) / $self->{'GameHeader'}{Treasures} ) : 0 );

                    if ( $self->{'GameHeader'}{Treasures} && $n == $self->{'GameHeader'}{Treasures} ) {
                        say("Well done.\n");
                        $self->finish();
                        return 1;
                    }
                }
                elsif ($action == 66) {
                    my $ct = 0;
                    my $f  = 0;
                    if   ($self->{'SECOND_PERSON'}) { say("You are carrying:\n"); }
                    else                  { say("I'm carrying:\n"); }
                    while ( $ct <= $self->{'GameHeader'}{NumItems} ) {
                        if ( $self->item_is( $ct, CARRIED ) ) {
                            $f = 1;
                            say("  - $self->{'Items'}[$ct]{Text}");
                        }
                        $ct++;
                    }
                    if ( $f == 0 ) { say("Nothing"); }
                }
                elsif ($action == 67) {
                    $self->{'BitFlags'} |= ( 1 << 0 );
                }
                elsif ($action == 68) {
                    $self->{'BitFlags'} &= ~( 1 << 0 );
                }
                elsif ($action == 69) {
                    $self->{'GameHeader'}{LightTime} = $self->{'LightRefill'};
                    if ( $self->{'Items'}[LIGHT_SOURCE]{Location} == $self->my_loc() ) { $self->{'Redraw'} = 1; }
                    $self->{'Items'}[LIGHT_SOURCE]{Location} = CARRIED;
                    $self->{'BitFlags'} &= ~( 1 << LIGHTOUTBIT );
                }
                elsif ($action == 70) {

                    #ClearScreen(); #  pdd.
                    #OutReset();
                }
                elsif ($action == 71) {
                    $self->save_game();
                }
                elsif ($action == 72) {
                    my $i1 = $param[ $pptr++ ];
                    my $i2 = $param[ $pptr++ ];
                    my $t  = $self->{'Items'}[$i1]{Location};
                    if ( $t == $self->my_loc() || $self->item_is( $i2, $self->my_loc() ) ) { $self->{'Redraw'} = 1; }
                    $self->{'Items'}[$i1]{Location} = $self->{'Items'}[$i2]{Location};
                    $self->{'Items'}[$i2]{Location} = $t;
                }
                elsif ($action == 73) {
                    $continuation = 1;
                }
                elsif ($action == 74) {
                    if ( $self->{'Items'}[ $param[$pptr] ]{Location} == $self->my_loc() ) { $self->{'Redraw'} = 1; }
                    $self->{'Items'}[ $param[ $pptr++ ] ]{Location} = CARRIED;
                }
                elsif ($action == 75) {
                    my $i1 = $param[ $pptr++ ];
                    my $i2 = $param[ $pptr++ ];
                    if ( $self->item_is( $i1, $self->my_loc() ) ) { $self->{'Redraw'} = 1; }
                    $self->{'Items'}[$i1]{Location} = $self->{'Items'}[$i2]{Location};
                    if ( $self->item_is( $i2, $self->my_loc() ) ) { $self->{'Redraw'} = 1; }
                }
                elsif ($action == 76) {    #  Looking at adventure ..
                    say $self->look();
                }
                elsif ($action == 77) {
                    if ( $self->{'CurrentCounter'} >= 0 ) { $self->{'CurrentCounter'}--; }
                }
                elsif ($action == 78) {
                    say($self->{'CurrentCounter'});
                }
                elsif ($action == 79) {
                    $self->{'CurrentCounter'} = $param[ $pptr++ ];
                }
                elsif ($action == 80) {
                    my $t = $self->my_loc();
                    $self->{'GameHeader'}{PlayerRoom} = $self->{'SavedRoom'};
                    $self->{'SavedRoom'}              = $t;
                    $self->{'Redraw'}                 = 1;
                }
                elsif ($action == 81) {

                    # This is somewhat guessed. Claymorgue always
                    # seems to do select counter n, thing, select counter n,
                    # but uses one value that always seems to exist. Trying
                    # a few options I found this gave sane results on ageing
                    my $t  = $param[ $pptr++ ];
                    my $c1 = $self->{'CurrentCounter'};
                    $self->{'CurrentCounter'} = $self->{'Counters'}[$t];
                    $self->{'Counters'}[$t] = $c1;
                }
                elsif ($action == 82) {
                    $self->{'CurrentCounter'} += $param[ $pptr++ ];
                }
                elsif ($action == 83) {
                    $self->{'CurrentCounter'} -= $param[ $pptr++ ];
                    if ( $self->{'CurrentCounter'} < -1 ) { $self->{'CurrentCounter'} = -1; }

                    # Note: This seems to be needed. I don't yet
                    # know if there is a maximum value to limit too
                }
                elsif ($action == 84) {
                    say($self->{'NounText'});
                }
                elsif ($action == 85) {
                    say($self->{'NounText'});
                    say("\n");
                }
                elsif ($action == 86) {
                    say("\n");
                }
                elsif ($action == 87) {

                    # Changed this to swap location<->roomflag[x]
                    # not roomflag 0 and x
                    my $p  = $param[ $pptr++ ];
                    my $sr = $self->my_loc();
                    $self->{'GameHeader'}{PlayerRoom} = $self->{'RoomSaved'}[$p];
                    $self->{'RoomSaved'}[$p]          = $sr;
                    $self->{'Redraw'}                 = 1;
                }
                elsif ($action == 88) {

                    #wrefresh(Top);
                    #wrefresh(Bottom);
                    # Delay opcode: output is delivered as a single turn; no blocking sleep.    #  DOC's say 2 seconds. Spectrum times at 1.5
                }
                elsif ($action == 89) {
                    $pptr++;

                    #  SAGA draw picture n
                    #  Spectrum Seas of Blood - start combat ?
                    #  Poking this into older spectrum games causes a crash
                }
                else { die(
                    sprintf "Unknown action %d [Param begins %d %d]\n",
                    $act[$cc], $param[$pptr], $param[ $pptr + 1 ]
                ); }
            }
        }
        $cc++;
    }
    return 1 + $continuation;
}

sub perform_actions {
    my $self=shift();
    $_[1] //= -1;
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->perform_actions(@_)";
    }
    my ( $verb, $noun ) = @_;


    my $d = $self->{'BitFlags'} & ( 1 << DARKBIT );

    if ( $verb == 1 && $noun == -1 ) {
        say("Give me a direction too.");
        return 0;
    }
    if ( $verb == 1 && $noun >= 1 && $noun <= 6 ) {
        my $nl;
        if (   $self->{'Items'}[LIGHT_SOURCE]{Location} == $self->my_loc()
            || $self->{'Items'}[LIGHT_SOURCE]{Location} == CARRIED )
        {
            $d = 0;
        }
        if ($d) {
            say("Dangerous to move in the dark! ");
        }
        $nl = $self->{'Rooms'}[$self->my_loc()]{Exits}[ $noun - 1 ];

        if ( $nl != 0 ) {
            $self->{'GameHeader'}{PlayerRoom} = $nl;
            say $self->look();
            return 0;
        }
        if ($d) {
            if ($self->{'SECOND_PERSON'}) {
                say("You fell down and broke your neck. ");
            }
            else {
                say("I fell down and broke my neck. ");
            }
            $self->finish();
            return 0;
        }
        if ($self->{'SECOND_PERSON'}) {
            say("You can't go in that direction. ");
        }
        else {
            say("I can't go in that direction. ");
        }
        return 0;
    }
    my $fl      = -1;
    my $doagain = 0;
    ACTIONS: foreach my $ct ( 0 .. $self->{'GameHeader'}{NumActions} ) {
        my $vv = $self->{'Actions'}[$ct]{Vocab};

        # Think this is now right. If a line we run has an action73
        # run all following lines with vocab of 0,0
        if ( $verb && ( $doagain && $vv != 0 ) ) {
            last ACTIONS;
        }

        # Oops.. added this minor cockup fix 1.11
        if ( $verb && !$doagain && $fl == 0 ) {
            last ACTIONS;
        }
        my $nv = $vv % 150;
        $vv = int( $vv / 150 );

        if ($self->{'TRACE'}) {
            say STDERR "vv: $vv\nvb: $verb\ndoagain: $doagain\nVocab: $self->{'Actions'}[$ct]{Vocab}\nnv: $nv\nno: $noun\nfl: $fl",
        }
        if ( ( $vv == $verb ) || ( $doagain && $self->{'Actions'}[$ct]{Vocab} == 0 ) ) {
            if (   ( $vv == 0 && $self->random_percent($nv) )
                || $doagain
                || ( $vv != 0 && ( $nv == ( $noun // -666 ) || $nv == 0 ) ) )
            {
                my $f2;
                if ( $fl == -1 ) { $fl = -2 }
                if ( ( $f2 = $self->perform_line($ct) ) > 0 ) {
                    return 0 if $self->{'ended'};

                    # ahah finally figured it out !
                    $fl = 0;
                    if ( $f2 == 2 ) {
                        $doagain = 1;
                    }
                    if ( $verb != 0 && $doagain == 0 ) {
                        return;
                    }
                }
            }
        }
        $ct++;
        if ($self->{'TRACE'}) {
            printf STDERR "doagain reset:\n\tct: $ct\nVocab: %s\n\t", $self->{'Actions'}[$ct]{Vocab} // '0';
        }

        # XXX worried that // 0 is a mistake
        # Looks like there may be a bug here, but it accidentally works. ct
        # at one point has a value of 278 (return_to_pirate_island.dat before
        # first prompt), but by accident, we overshoot the array and hit
        # random, non-zero data in the C code
        if ( ( $self->{'Actions'}[$ct]{Vocab} // 0 ) != 0 ) {
            $doagain = 0;
        }
    }
    if ( $fl != 0 && $self->{'disable_sysfunc'} == 0 ) {
        my $i;
        if (   $self->{'Items'}[LIGHT_SOURCE]{Location} == $self->my_loc()
            || $self->{'Items'}[LIGHT_SOURCE]{Location} == CARRIED )
        {
            $d = 0;
        }
        if ( $verb == GET || $verb == DROP ) {

            # Yes they really _are_ hardcoded values
            if ( $verb == GET ) {
                if ( $self->strncasecmp( $self->{'NounText'}, "ALL", $self->{'GameHeader'}{WordLength} ) ) {
                    my $f = 0;
                    if ($d) {
                        say("It is dark.\n");
                        return 0;
                    }
                    for my $ct ( 0 .. $self->{'GameHeader'}{NumItems} ) {
                        if (   $self->item_is( $ct, $self->my_loc() )
                            && defined $self->{'Items'}[$ct]{AutoGet}
                            && $self->{'Items'}[$ct]{AutoGet} !~ /^\*/ )
                        {
                            $noun = $self->which_word( $self->{'Items'}[$ct]{AutoGet}, $self->{'Nouns'} );
                            $self->{'disable_sysfunc'} = 1;    #  Don't recurse into auto get !
                            $self->perform_actions( $verb, $noun );    #  Recursively check each items table code
                            $self->{'disable_sysfunc'} = 0;
                            if ( $self->count_carried() == $self->{'GameHeader'}{MaxCarry} ) {
                                if ($self->{'SECOND_PERSON'}) {
                                    say("You are carrying too much. ");
                                }
                                else {
                                    say("I've too much to carry. ");
                                }
                                return 0;
                            }
                            $self->{'Items'}[$ct]{Location} = CARRIED;
                            say( $self->{'Items'}[$ct]{Text} . ": O.K." );
                            $f = 1;
                        }
                    }
                    if ( $f == 0 ) {
                        say("Nothing taken.");
                    }
                    return 0;
                }
                if ( not defined $noun ) {
                    say("What ? ");
                    return 0;
                }
                if ( $self->count_carried() == $self->{'GameHeader'}{MaxCarry} ) {
                    if ($self->{'SECOND_PERSON'}) {
                        say("You are carrying too much. ");
                    }
                    else {
                        say("I've too much to carry. ");
                    }
                    return 0;
                }
                my $i = $self->match_up_item( $self->{'NounText'}, $self->my_loc() );
                if ( not defined $i ) {
                    if ($self->{'SECOND_PERSON'}) {
                        say("It is beyond your power to do that. ");
                    }
                    else {
                        say("It's beyond my power to do that. ");
                    }
                    return 0;
                }
                $self->{'Items'}[$i]{Location} = CARRIED;
                say("O.K. ");
                return 0;
            }
            if ( $verb == DROP ) {
                if ( $self->strncasecmp( $self->{'NounText'}, "ALL", $self->{'GameHeader'}{WordLength} ) ) {
                    my $f = 0;
                    foreach my $ct ( 0 .. $self->{'GameHeader'}{NumItems} ) {
                        if (   $self->item_is( $ct, CARRIED )
                            && $self->{'Items'}[$ct]{AutoGet}
                            && $self->{'Items'}[$ct]{AutoGet} !~ /^\*/ )
                        {
                            $noun = $self->which_word( $self->{'Items'}[$ct]{AutoGet}, $self->{'Nouns'} );
                            $self->{'disable_sysfunc'} = 1;
                            $self->perform_actions( $verb, $noun );
                            $self->{'disable_sysfunc'} = 0;
                            $self->{'Items'}[$ct]{Location} = $self->my_loc();
                            say( $self->{'Items'}[$ct]{Text} . ": O.K.\n" );
                            $f = 1;
                        }
                    }
                    if ( $f == 0 ) {
                        say("Nothing dropped.\n");
                    }
                    return 0;
                }
                if ( !defined $noun ) {
                    say("What ? ");
                    return 0;
                }
                $i = $self->match_up_item( $self->{'NounText'}, CARRIED );
                if ( not defined $i ) {
                    if ($self->{'SECOND_PERSON'}) {
                        say("It's beyond your power to do that.\n");
                    }
                    else {
                        say("It's beyond my power to do that.\n");
                    }
                    return 0;
                }
                $self->{'Items'}[$i]{Location} = $self->my_loc();
                say("O.K. ");
                return 0;
            }
        }
    }
    return $fl;
}

sub get_int {
    my $self=shift();
    my $fh = shift;
    my $int=<$fh>;
    defined($int) or croak('unexpected end of game database');
    chomp($int);
    $int =~ s/^\s+|\s+$//g;
    unless ( $int =~ /^-?[0-9]+$/ ) {
        croak("Read '$int' from database. Need an int");
    }
    return $int;
}

sub read_string {
    my $self=shift();
    my $fh = shift;
    my $word = <$fh>;
    my $leading_newline = $word =~ /^"\n/;
    chomp($word);
    if ( $word eq '"' ) {

        # This handles the case where a quoted multi-line string might start
        # with a single quote on a line by itself.
        chomp( $word .= <$fh> );
    }
    while ( $word !~ /"$/ ) {
        chomp( $word .= "\n" . <$fh> );
        if ( eof($fh) ) {
            croak(<<'END');
PANIC: eof reached in ReadString.

Maybe run dos2unix or unix2dos on the game file?
END
        }
    }
    $word =~ s/^"|"$//g;
    $word =~ s/`/"/g;
    $word = "\n$word" if $leading_newline;
    return $word;
}

sub read_item {
    my $self=shift();
    my $fh = shift;

    my $line .= '';
    do {
        $line .= <$fh>;
        if ( eof($fh) ) {
            croak(<<'END');
PANIC: eof reached in ReadItem.

Maybe run dos2unix or unix2dos on the game file?
END
        }
    } until $line =~ /"\s+-?\d+\s*$/;

    chomp($line);
    my ( $item, $location, $autoget );

    ( $item, $location ) = ( $line =~ /^"(.*)"\s+(-?[0-9]+)\s*$/s );
    unless ( defined $item and defined $location ) {
        croak("Bad item read at data file line $.: $line");
    }

    if ( $item =~ s!/([^/]+)/$!! ) {
        $autoget = $1;
    }
    if ( -1 == $location ) {

        # in the C, it's an unsigned char
        $location = CARRIED;
    }
    return $item, $location, $autoget;
}

sub load_database {
    my $self=shift();
    my ( $db, $debugging ) = @_;
    open my $fh, '<', $db;

    my @headers = qw(
      Unknown1
      NumItems  NumActions  NumWords     NumRooms
      MaxCarry  PlayerRoom  Treasures    WordLength
      LightTime NumMessages TreasureRoom
    );
    foreach my $header (@headers) {
        $self->{'GameHeader'}{$header} = $self->get_int($fh);
    }
    if ($debugging) {
        say "Header loaded at line $.";
        print Data::Dumper->Dump( [ $self->{'GameHeader'} ] => ['*GameHeader'] );
    }

    $self->{'LightRefill'} = $self->{'GameHeader'}{LightTime};

    for my $i ( 0 .. $self->{'GameHeader'}{NumActions} ) {
        my %action = (
            Vocab     => $self->get_int($fh),
            Condition => [],
            Action    => [],
        );
        for ( 1 .. 5 ) {
            push @{ $action{Condition} } => $self->get_int($fh);
        }
        $action{Action}[0] = $self->get_int($fh);
        $action{Action}[1] = $self->get_int($fh);
        push @{$self->{'Actions'}} => \%action;

        if ( $i == 0 && $debugging ) {
            print Data::Dumper->Dump( [ $self->{'Actions'}[0] ] => ['*first_action'] );
        }
    }
    if ($debugging) {
        say "Actions loaded at line $.";
        print Data::Dumper->Dump( [ $self->{'Actions'}[-1] ] => ['*last_action'] );
    }

    for ( 0 .. $self->{'GameHeader'}{NumWords} ) {
        push @{$self->{'Verbs'}} => $self->read_string($fh);
        push @{$self->{'Nouns'}} => $self->read_string($fh);
        if ( $_ == 0 && $debugging ) {
            print Data::Dumper->Dump(
                [ $self->{'Verbs'}[0], $self->{'Nouns'}[0] ],
                [qw/*first_verb *first_noun/],
            );
        }
    }
    if ($debugging) {
        say "Words loaded at line $.";
        print Data::Dumper->Dump(
            [ $self->{'Verbs'}[-1], $self->{'Nouns'}[-1] ],
            [qw/*last_verb *last_noun/],
        );
    }

    foreach ( 0 .. $self->{'GameHeader'}{NumRooms} ) {
        my %room = (
            Text  => undef,
            Exits => [],
        );
        for ( 1 .. 6 ) {
            push @{ $room{Exits} } => $self->get_int($fh);
        }
        $room{Text} = $self->read_string($fh);
        push @{$self->{'Rooms'}} => \%room;
        if ( $_ == 0 && $debugging ) {
            print Data::Dumper->Dump( [ $self->{'Rooms'}[0] ] => ['*first_room'] );
        }
    }
    if ($debugging) {
        say "Rooms loaded at line $.";
        print Data::Dumper->Dump( [ $self->{'Rooms'}[-1] ] => ['*last_room'] );
    }


    for ( 0 .. $self->{'GameHeader'}{NumMessages} ) {    # XXX what happened here?
        push @{$self->{'Messages'}} => $self->read_string($fh);
        if ($self->{'TRACE'}) {
            say STDERR "Message $_: $self->{'Messages'}[$_]";
        }
        if ( $_ == 0 && $debugging ) {
            print Data::Dumper->Dump( [ $self->{'Messages'}[0] ] => ['*first_message'] );
        }
    }
    if ($debugging) {
        say "Messages loaded at line $.";
        print Data::Dumper->Dump( [ $self->{'Messages'}[-1] ] => ['*last_message'] );
    }

    for my $i ( 0 .. $self->{'GameHeader'}{NumItems} ) {
        my ( $item, $location, $autoget ) = $self->read_item($fh);
        push @{$self->{'Items'}} => {
            Text       => $item,
            Location   => $location,
            InitialLoc => $location,
            AutoGet    => $autoget,
        };
        if ( $i == 0 && $debugging ) {
            print Data::Dumper->Dump( [ $self->{'Items'}[-1] ] => ['*first_item'] );
        }
    }

    if ($debugging) {
        say "Items loaded at line $.";
        print Data::Dumper->Dump( [ $self->{'Items'}[-1] ] => ['*last_item'] );
    }
    $self->read_string($fh) for 0 .. $self->{'GameHeader'}{NumActions};    # skip comment strings

    my $version = $self->get_int($fh);
    printf(
        "Version %d.%02d of Adventure \n\n",
        $version / 100, $version % 100
    );

}

sub look {
    my $self=shift();
    if ($self->{'TRACE'}) {
        local $" = ', ';
        say STDERR "$self->look(@_)";
    }
    my @ExitNames = qw(North South East West Up Down);

    my $look = '';
    my $r    = $self->{'Rooms'}[$self->my_loc()];

    if (   ( $self->{'BitFlags'} & ( 1 << DARKBIT ) )
        && $self->{'Items'}[LIGHT_SOURCE]{Location} != CARRIED
        && $self->{'Items'}[LIGHT_SOURCE]{Location} != $self->my_loc() )
    {
        if ($self->{'SECOND_PERSON'}) {
            return "You can't see. It is too dark!";
        }
        else {
            return "I can't see. It is too dark!";
        }
    }
    my $text = $r->{Text};
    if ( $text =~ s/^\*// ) {    # XXX ???
        $look .= $text;
    }
    else {
        if ($self->{'SECOND_PERSON'}) {
            $look .= "You are in a $text\n";
        }
        else {
            $look .= "I'm in a $text\n";
        }
    }
    $look .= "\n";

    my $f = 0;
    $look .= "\nObvious exits:\n";
    foreach ( 0 .. 5 ) {
        if ( $r->{Exits}[$_] ) {
            if ( !$f ) {
                $f = 1;
            }
            else {
                $look .= ", ";
            }
            $look .= $ExitNames[$_];
        }
    }

    if ( !$f ) {
        $look .= "none\n";
    }
    else {
        $look .= "\n\n";
    }

    $f = 0;
    my $pos = 0;

    foreach my $i ( 0 .. $self->{'GameHeader'}{NumItems} ) {
        if ( $self->item_is( $i, $self->my_loc() ) ) {
            if ( !$f ) {
                $look .=
                  $self->{'SECOND_PERSON'}
                  ? "You can also see:\n"
                  : "I can also see:\n";
                $pos = 16;
                $f++;
            }
            else {
                $look .= "\n";
            }
            $look .= "  - " . $self->{'Items'}[$i]{Text};
        }
    }
    return "$look\n\n";
}

1;
