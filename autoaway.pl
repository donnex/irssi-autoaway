# /AUTOAWAY <n> - Mark user away after <n> seconds of inactivity
# /AWAY - play nice with autoaway
# New, brighter, whiter version of my autoaway script. Actually works :)
# (c) 2000 Larry Daffner (vizzie@airmail.net)
#     You may freely use, modify and distribute this script, as long as
#      1) you leave this notice intact
#      2) you don't pretend my code is yours
#      3) you don't pretend your code is mine
#
# share and enjoy!

# A simple script. /autoaway <n> will mark you as away automatically if
# you have not typed any commands in <n> seconds.
# It will also automatically unmark you away the next time you type a command.
# Note that using the /away command will disable the autoaway mechanism, as
# well as the autoreturn. (when you unmark yourself, the autoaway will
# restart again)

use Irssi;
use Irssi::Irc;

use vars qw($VERSION %IRSSI);
$VERSION = '0.1';
%IRSSI = (
    authors => 'Daniel Johansson',
    contact => 'donnex@donnex.net',
    name => 'Autoaway',
    description => 'Automatically goes away after defined inactivity.',
    license => 'BSD',
    url => 'https://github.com/donnex/irssi-autoaway'
);

use constant {
    USER_NOT_AWAY => 0,
    USER_AWAY_AUTOAWAY => 1,
    USER_AWAY_MANUAL => 2,
    USER_AWAY_PROCESSING => 3
};

my ($autoaway_to_tag, $autoaway_state, $autoaway_timeout);

sub cmd_autoaway {
    my ($data, $server, $channel) = @_;

    if ($data =~ /^[0-9]+m$/) {
        $autoaway_timeout = $data * 60;
    } elsif ($data =~ /^([0-9]+)s?$/) {
        $autoaway_timeout = $1;
    } else {
        Irssi::print('Autoaway usage: /autoaway [<secs>[s] | <mins>m]');
        $autoaway_current_timeout = Irssi::settings_get_int('autoaway_timeout');
        Irssi::print('Autoaway current: '.$autoaway_current_timeout.' s');
        return;
    }

    if ($autoaway_timeout) {
        Irssi::print('Autoaway timeout set to '.$autoaway_timeout.' seconds');
        Irssi::settings_set_int('autoaway_timeout', $autoaway_timeout);
        setup_timer();
    }
}

sub cmd_away {
    my ($data, $server, $channel) = @_;
	return unless $server;

    # /AWAY without argument (remove away status)
    if (!$data) {
        return unless ($autoaway_state == USER_AWAY_AUTOAWAY || $autoaway_state == USER_AWAY_MANUAL);
        $autoaway_state = USER_NOT_AWAY;
        setup_timer();
    # /AWAY with argument (manual away)
    } else {
        $autoaway_state = USER_AWAY_MANUAL;
        remove_timer();
    }
}

sub auto_timeout {
    return unless $autoaway_state == USER_NOT_AWAY;

    my (@servers) = Irssi::servers();
    $server = $servers[0];
    if (!$server) {
        setup_timer();
        return;
    }

    $autoaway_state = USER_AWAY_PROCESSING;

    do_command('/AWAY not here ...');
    remove_timer();

    $autoaway_state = USER_AWAY_AUTOAWAY;
}

sub reset_timer {
    my ($cmd) = @_;
    return if ($cmd =~ /^\/(\^(NOTICE|WHOIS) |AWAY)/i || $cmd =~ /^\/.+(auth|invite).+/i);

    if ($autoaway_state == USER_AWAY_AUTOAWAY) {
        $autoaway_state = USER_AWAY_PROCESSING;

        do_command('/AWAY');
        setup_timer();

        $autoaway_state = USER_NOT_AWAY;
    } elsif ($autoaway_state == USER_NOT_AWAY) {
        setup_timer();
    }
}

sub setup_timer {
    $autoaway_timeout = Irssi::settings_get_int('autoaway_timeout');

    remove_timer();

    if ($autoaway_timeout) {
        $autoaway_to_tag = Irssi::timeout_add($autoaway_timeout*1000, 'auto_timeout', '');
    }
}

sub remove_timer {
    return unless defined($autoaway_to_tag);

    Irssi::timeout_remove($autoaway_to_tag);
    $autoaway_to_tag = undef;
}

sub do_command {
    my ($cmd) = @_;

    my (@servers) = Irssi::servers();
    $server = $servers[0];
    if ($server) {
        $server->command($cmd);
    }
}

# Setting
Irssi::settings_add_int('misc', 'autoaway_timeout', 0);
$autoaway_timeout = Irssi::settings_get_int('autoaway_timeout');

# Help message if autoaway_timeout isn't set
if (!$autoaway_timeout) {
    Irssi::print('%G>>%n Autoaway timeout not set. Use /autoaway to set it.');
}

# Make sure we're not away when setting up the timers
do_command('/AWAY');
$autoaway_state = USER_NOT_AWAY;

Irssi::command_bind('autoaway', 'cmd_autoaway');
Irssi::command_bind('away', 'cmd_away');
Irssi::signal_add('send command', 'reset_timer');