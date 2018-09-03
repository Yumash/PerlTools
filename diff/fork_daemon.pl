#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(:sys_wait_h);
use List::Util qw(min);
use Proc::Daemon;
use Getopt::Long;
use File::Basename;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;

use XPortal::Settings;
use XPortal::General;
use XPortal::DB;

use Data::Dumper;

my	$pidfile 						= '/var/run/'.basename($0).'.pid';
our $name    						= q[Recount Slices Tree];
my	$daemonize					= 0;
our $verbose						=	0;
our $default_slots_num	=	20;

my $daemon = Proc::Daemon->new( pid_file => $pidfile );
my $pid = $daemon->Status($pidfile);

our %worker_pid;
our $tasks = [];
our $worker_slots;

# TRACE
# DEBUG
# INFO
# WARN
# ERROR
# FATAL
Log::Log4perl->init(\ <<'EOT');
log4perl.category                                   = ERROR, Screen
log4perl.appender.Screen                            = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.Screen.layout                     = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern   = %d %F{1} %L> %m %n
log4perl.appender.Screen.color.DEBUG=bold yellow
log4perl.appender.Screen.color.ERROR=bold red
log4perl.appender.Screen.color.INFO=white
log4perl.appender.Screen.color.WARN=bold magenta
EOT
our $logger = get_logger();

GetOptions(
	'd|daemon!' 	=>	\$daemonize,
	"v|verbose!"	=>	\$verbose,
	"h|help"			=>	\&help,
	"s|slots=i"		=>	\$worker_slots,
	"start"			=>	\&run,
	"status"		=>	\&status,
	"stop"			=>	\&stop,
	"destroy"		=>	\&destroy,
);


$SIG{CHLD} = 'IGNORE';

$SIG{KILL} = sub {
	$0 = "$name - one two freddy is coming for you";
	destroy();
};

$SIG{TERM} = sub {
	$0 = "$name - gentle stop";
	stop();
};

sub help {
	print "\n\nRecount Slice Trees script. Recounts deep trees of slices (genres only for now) to get actual number of arts.\n\n";
	print "Example:\n\nStarts script as a daemon with 20 max forks\n\n\tperl $0 -v -s=20 -d --start\n\n";
	print "Options (order matters):\n\n";
	print "\t-d --daemon\t\tact as daemon\n";
	print "\t-v --verbose\t\tbe noisy\n";
	print "\t-h --help\t\tthis help\n";
	print "\t-s=i --slots=i\t\tset max forking processes\n";
	print "\t--start\t\t\tstart work\n";
	print "\t--status\t\tprint status of daemon\n";
	print "\t--stop\t\t\tgently stop daemon (children resume to work and than die\n";
	print "\t--destroy\t\ttotally kills daemon (children die instantly with SIGKILL)\n";
	exit;
}

sub destroy {	stop(1); }

sub stop {
	my $kill = shift;
	if ($pid) {
		print "Stopping pid $pid...\n";
		if ($daemon->Kill_Daemon($pid)) {
			kill(9, keys %worker_pid) if $kill;
			print "Successfully stopped.\n";
		}
		else {
			print "Could not find $pid.	Was it running?\n";
		}
	}
	else {
		print "Not running, nothing to stop.\n";
	}
}

sub status {
	print $pid ? "Running with pid $pid.\n" : 'Not running';
	exit;
}

sub run {
	$logger->level($verbose ? $TRACE : $ERROR);
	$worker_slots = $worker_slots || $default_slots_num;
	if (!$pid) {
		INFO "Starting with $worker_slots slots - $name...\n";
		$daemon->Init if $daemonize;
		work();
	}

	INFO "Already Running with pid $pid\n";
}

sub work {

	while (1) {
		$tasks = setTaskQueue() if @$tasks == 0;
		$0 = "$name master, waiting for " . keys(%worker_pid) . " workers";
		foreach my $pid (keys %worker_pid){
			if (waitpid( $pid, WNOHANG ) == -1) {
				delete $worker_pid{$pid};
				$worker_slots++;
			}
		}
		if ($worker_slots > 0) {
			for (1 .. min( $worker_slots, scalar @$tasks)){
				my $task = shift @$tasks;
				last unless defined $task;
				my $pid = fork;
				if ($pid == 0) {
					process_task($task);
					exit;
				}
				$worker_pid{$pid} = 1;
				$0 = "$name master, waiting for " . keys(%worker_pid) . " workers";
				$worker_slots--;
			}
		}
		last if keys %worker_pid == 0;
	}
	exit;
}

sub process_task {
	my $id = shift;
	$0 = qq[$name child with $id];
	DEBUG "$id got";
	sleep( rand(10) );
	return 1;
}

sub setTaskQueue {
	# Сообразно worker_slots мы выбираем нужное количество задач и работаем с ними
	my @tasks;
	for ( 0 .. 10000 ) {
		push( @tasks, $_ );
	}
	return \@tasks;
}
