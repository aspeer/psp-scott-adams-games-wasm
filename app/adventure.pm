package adventure;

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;
use Future::AsyncAwait;
use JSON::PP ();

require File::Spec->catfile(dirname(__FILE__), 'ScottGame.pm');

my @GAMES=(
    ['adventureland', 'Adventureland'],
    ['pirate_adventure', 'Pirate Adventure'],
    ['mission_impossible', 'Mission Impossible'],
    ['voodoo_castle', 'Voodoo Castle'],
    ['the_count', 'The Count'],
    ['strange_odyssey', 'Strange Odyssey'],
    ['strange_fun_house', 'Mystery Fun House'],
    ['pyramid_of_doom', 'Pyramid of Doom'],
    ['ghost_town', 'Ghost Town'],
    ['savage_island_part_1', 'Savage Island, Part I'],
    ['savage_island_part_2', 'Savage Island, Part II'],
    ['the_golden_voyage', 'The Golden Voyage'],
    ['sorcerer_of_claymorgue_castle', 'Sorcerer of Claymorgue Castle'],
    ['return_to_pirate_island', 'Return to Pirate Island'],
    ['adventures_of_buckaroo_banzai', 'The Adventures of Buckaroo Banzai'],
    ['mini-adventure', 'Mini Adventure'],
);
my $JSON=JSON::PP->new()->canonical();


sub menu {
    my $text="SCOTT ADAMS  /  ADVENTURE LIBRARY\n\n";
    foreach my $ix (0..7) {
        $text.=sprintf("  %2d  %-32s  %2d  %s\n", $ix+1, $GAMES[$ix][1],
            $ix+9, $GAMES[$ix+8][1]);
    }
    $text.="\nChoose an adventure by number or name.\n";
    return {type => 'menu', output => $text, title => 'Choose your adventure',
        room => "Sixteen worlds. Two words at a time.\n\nEnter a number in the terminal below to begin.\nYour adventure lasts for this connection.",
        turns => 0, prompt => 'Select adventure > '};
}


sub selection {
    my $line=shift();
    return $line-1 if $line=~/\A\d{1,2}\z/ && $line>=1 && $line<=@GAMES;
    my $normalized=lc($line);
    $normalized=~s/[^a-z0-9]//g;
    foreach my $ix (0..$#GAMES) {
        foreach my $label ($GAMES[$ix][0], $GAMES[$ix][1]) {
            my $normalized_label=lc($label);
            $normalized_label=~s/[^a-z0-9]//g;
            return $ix if $normalized_label eq $normalized;
        }
    }
    return;
}


#  The game object belongs to this connection. No game state survives disconnect.
#
async sub ws {
    my ($self, $param_hr)=@_;
    my $request_or=$self->r();
    my ($receive_cr, $send_cr)=@{$request_or}{qw(receive send)};
    my $root_dn=$self->cwd();
    my ($game_or, $game_ix);

    await $send_cr->({type => 'websocket.accept'});
    await $send_cr->({type => 'websocket.send', text => $JSON->encode(menu())});
    while (my $event_hr=await $receive_cr->()) {
        last if $event_hr->{'type'} eq 'websocket.disconnect';
        next unless $event_hr->{'type'} eq 'websocket.receive';
        my ($message_hr, $error, $reply_hr);
        {
            local $@;
            eval {
                die "invalid message\n" unless defined($event_hr->{'text'})
                    && length($event_hr->{'text'})<=4096;
                $message_hr=$JSON->decode($event_hr->{'text'});
                die "invalid command\n" unless ref($message_hr) eq 'HASH'
                    && ($message_hr->{'type'} || '') eq 'command'
                    && defined($message_hr->{'line'}) && !ref($message_hr->{'line'})
                    && length($message_hr->{'line'})<=256
                    && $message_hr->{'line'}!~/[\x00-\x1f\x7f]/;
                1;
            } or $error=$@;
        }
        if ($error) {
            $reply_hr={type => 'error', output => "Use a text command of at most 256 characters.\n"};
        }
        else {
            my $line=$message_hr->{'line'};
            $line=~s/^\s+|\s+$//g;
            if ($line=~m{\A/(?:menu|quit)\z}i || lc($line) eq 'q') {
                undef($game_or);
                undef($game_ix);
                $reply_hr=menu();
            }
            elsif ($line=~m{\A/help\z}i) {
                $reply_hr={type => 'info', output => "Use one or two words: LOOK, GET AXE, GO NORTH.\nN S E W U D move; I lists inventory. HELP asks the game for a hint.\n/menu returns to the library; /restart starts this game over.\nArrow keys recall commands. Saving is disabled; disconnecting resets the game.\n"};
            }
            else {
                my $start_fg=!$game_or || lc($line) eq '/restart';
                my $next_ix=$game_or ? $game_ix : selection($line);
                if ($start_fg && !defined($next_ix)) {
                    $reply_hr={type => 'info', output => "Choose a number from 1 to 16, or enter the full adventure name.\n"};
                }
                else {
                    {
                        local $@;
                        eval {
                            if ($start_fg) {
                                $game_or=ScottGame->new(File::Spec->catfile($root_dn, 'games', $GAMES[$next_ix][0].'.dat'));
                                $game_ix=$next_ix;
                            }
                            my $result_hr=$start_fg ? $game_or->response() : $game_or->command($line);
                            $reply_hr={%{$result_hr}, type => 'turn', title => $GAMES[$game_ix][1],
                                prompt => $result_hr->{'ended'} ? '/menu or /restart > ' : 'What shall I do? > ',
                                started => $start_fg ? 1 : 0};
                            1;
                        } or $error=$@;
                    }
                    if ($error) {
                        warn "adventure engine error: $error";
                        undef($game_or);
                        undef($game_ix);
                        $reply_hr=menu();
                        $reply_hr->{'output'}="This adventure encountered an error and was reset.\n\n".$reply_hr->{'output'};
                    }
                }
            }
        }
        await $send_cr->({type => 'websocket.send', text => $JSON->encode($reply_hr)});
    }
    return;
}

1;
