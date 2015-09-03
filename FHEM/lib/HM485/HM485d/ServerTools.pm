##############################################
# $Id: $

package main;

use strict;
use warnings;
use Net::Ping;
use Time::HiRes qw(gettimeofday);
use Getopt::Long;

use vars qw(%selectlist);  # devices which want a "select"
use vars qw(%attr);        # Attributes
use vars qw(%hash);
use vars qw($winService);  # the Windows Service object
use vars qw($init_done);

##################################################
# Variables:
my $sigTerm = 0;           # if set to 1, terminate (saving the state)

my %timeoutList;
my $timeoutNext = 0;
my $timeoutElCount = 0;
my $currlogfile;           # logfile, without wildcards
my $logopened = 0;         # logfile opened or using stdout

my $clientCount = 0;
my $serverParseFn = '';
my $serialDevice = '';
my $initFnSerial = '';
my $clientWelcomeFn = '';
my $clientCloseFn = '';
my $serverName = '';

sub ServerTools_init($$$$$$) {
	my (
		$myServerName, $pathFHEM, $logFile, $logVerbose, $localPort,
		$parseFnServer, $welcomeClientFn, $myClientCloseFn,
		$mySerialDevice, $parseFnSerial, $myInitFnSerial
	) = @_;

	$serverName = $myServerName;
	$serverParseFn = $parseFnServer;
	$clientWelcomeFn = $welcomeClientFn;
	$clientCloseFn = $myClientCloseFn;
	$serialDevice = $mySerialDevice;
	$initFnSerial = $myInitFnSerial;
	
	ServerTools_initLogging(
		defined($logFile) ? $logFile : '-',
		defined($logVerbose) ? $logVerbose : 0
	);

	# SignalHandling
	if($^O ne "MSWin32") {
		$SIG{'INT'}  = sub {$sigTerm = 1;};
		$SIG{'TERM'} = sub {$sigTerm = 1;};
		$SIG{'PIPE'} = 'IGNORE';
		$SIG{'CHLD'} = 'IGNORE';
		$SIG{'HUP'}  = 'IGNORE'
	}

	my $dirname = dirname(abs_path($0)) . '/';
	
	require $dirname.'DevIo485.pm';
	require $pathFHEM . 'TcpServerUtils.pm';
	
	$hash{$serverName}->{NAME} = $serverName;
	ServerTools_serverInit($hash{$serverName}, $localPort);

	# Go to background if the logfile is a real file (not stdout)
	# This needs to be done before init of the serial interface.
	# Otherwise stopping the foreground process can reset the 
	# serial interface.
	if($currlogfile ne "-") {
		defined(my $pid = fork) || die "Can't fork: $!";
		exit(0) if $pid;
	}
	
	$hash{'SERIAL'}->{NAME} = 'SERIAL';
	ServerTools_serialInit($hash{'SERIAL'}, $serialDevice, $initFnSerial);
}

sub ServerTools_initLogging() {
	my ($logFile, $verbose) = @_;

	$attr{global}{mseclog} = 1;
	$attr{global}{verbose} = $verbose;
	$currlogfile = $logFile;
}

sub ServerTools_main () {
	Log (1, 'Server started ...');

	while (1) {
		my ($rout, $rin) = ('', '');
		my $timeout = handleTimeout();

		foreach my $p (keys %selectlist) {
			vec($rin, $selectlist{$p}{FD}, 1) = 1;
		}

		my $nfound = select($rout = $rin, undef, undef, $timeout);
		my $readytimeout = ($^O eq "MSWin32") ? 0.1 : 5.0;

		if ($sigTerm) {
			ServerTools_serverShutdown();
		}

		if($nfound < 0) {
			my $err = int($!);
			next if ($err == 0);

		 	my $msg = 'ERROR: Select error ' . $nfound . ' (' . $err . ')';
			Log (0, $msg);
			die($msg . "\n");
		}

		###############################
		# Message from the hardware (FHZ1000/WS3000/etc) via select or the Ready
		# Function. The latter ist needed for Windows, where USB devices are not
		# reported by select, but is used by unix too, to check if the device is
		# attached again.
		foreach my $p (keys %selectlist) {
			next if(!$selectlist{$p} || !$selectlist{$p}{NAME}); # due to rereadcfg/del

			if(vec($rout, $selectlist{$p}{FD}, 1)) {
				my $name = $selectlist{$p}{NAME};
				$name = ($name eq $serverName) ? $selectlist{$p}{NAME} . '.' . $selectlist{$p}{PORT} : $name;
				$name = ($name eq 'SERIAL') ? $selectlist{$p}{NAME} . '.' . $selectlist{$p}{DeviceName} : $name;
				CallFn($name, "ReadFn", $selectlist{$p})
			}
		}

#		foreach my $p (keys %readyfnlist) {
#			next if(!$readyfnlist{$p});                 # due to rereadcfg / delete
#
#			if(CallFn($readyfnlist{$p}{NAME}, "ReadyFn", $readyfnlist{$p})) {
#				if($readyfnlist{$p}) {                    # delete itself inside ReadyFn
#					CallFn($readyfnlist{$p}{NAME}, "ReadFn", $readyfnlist{$p});
#				}
#			}
#		}

	}
}

sub ServerTools_serverInit() {
	my ($hash, $port) = @_;

	if (defined($port) && $port > 0 and $port <= 65536) {
		# allow connections on all interfaces (for debugging only)
		my $result = TcpServer_Open($hash, $port, 1);
#		my $result = TcpServer_Open($hash, $port, undef);
		if ($result) {
			my $msg = 'Cannot create socket ' . $result;
			Log(0, $msg);
			die $msg . "\n";
		}
	} else {
		my $msg = 'localPort must between 0 an 65536';
		Log(0, $msg);
		die $msg . "\n";
	}

	$hash->{ReadFn} = 'ServerTools_serverAccept';
	Log(3, 'server waiting for client connection on port ' . $port);
}

sub ServerTools_serverAccept($) {
	my ($hash) = @_;

	if($hash->{SERVERSOCKET}) {	# Accept and create a child
		my $cHash = TcpServer_Accept($hash, "telnet");
		if($cHash && $cHash->{CD}) {
			$cHash->{ReadFn} = 'ServerTools_serverRead';
			
			$clientCount++;
			if ($clientWelcomeFn ne '') {
				no strict "refs";
				my $res = &{$clientWelcomeFn}($cHash, $clientCount);
				use strict "refs";

				if (!$res) {
					ServerTools_serverClientClose($cHash);
				}
			}
		}
	}
}

sub ServerTools_serverRead($) {
	my ($hash) = @_;

	my $ret = sysread($hash->{CD}, my $buf, 10240);
	if(!defined($ret) || $ret <= 0) {
		ServerTools_serverClientClose($hash);
	} else {
		if ($serverParseFn ne '') {
			no strict "refs";
			&{$serverParseFn}($buf);
			use strict "refs";
		}
	}
}

sub ServerTools_serverClientClose($) {
	my ($hash) = @_;

	TcpServer_Close($hash);
	if ($clientCount > 0) {
		$clientCount--;
	}

	if ($clientCloseFn ne '') {
		no strict "refs";
		my $res = &{$clientCloseFn}($hash);
		use strict "refs";
	}
}

sub ServerTools_serverShutdown() {
	# todo
#	$socketLocal->close();
	Log (0, 'Server stopped ...');
	exit(0);
}

sub ServerTools_serverWriteClient($) {
	my ($buffer) = @_;
	
	foreach my $p (keys %selectlist) {
		if($selectlist{$p} && $selectlist{$p}{SNAME} && $selectlist{$p}{SNAME} eq $serverName) {
			syswrite($selectlist{$p}->{CD}, $buffer);
			select(undef, undef, undef, 0.001);
		}
	}
}

sub ServerTools_serialInit($$) {
	my ($hash, $dev) = @_;
	my $name = $hash->{NAME};
	my $msg = '';
	
	if(!defined($dev) || !$dev) {
		$msg = 'serialDevice not given';

	} elsif($dev eq 'none') {
		Log (1, 'HM485 device is none, commands will be echoed only');
		$attr{$name}{dummy} = 1;
		delete($selectlist{$name . '.' . $hash->{DEF}});
		return undef;
	}

	DevIo_CloseDev($hash);

	if (!$msg) {
		$hash->{DeviceName} = $dev;
		my $ret = DevIo_OpenDev($hash, 0, $initFnSerial);
	} else {
		Log (0, $msg);
		die ($msg);
	}
}

sub ServerTools_serialWrite($) {
	my ($buffer) = @_;

	DevIo_SimpleWrite($hash{'SERIAL'}, $buffer, 0);
}

sub ServerTools_serialReconnect() {
	ServerTools_serialInit($hash{'SERIAL'}, $serialDevice);
	Log(2, 'RECONNECTED');
}

sub CallFn(@) {
	my $d = shift;
	my $n = shift;

	if(!$selectlist{$d}) {
		my $msg = 'Strange call for nonexistent ' . $d;
		Log (0, $msg);
		die($serverName . ': ' . $msg);
	}

	my $fn = $selectlist{$d}{$n};
	if($fn) {
		no strict "refs";
		if(wantarray) {
			my @ret = &{$fn}(@_);
			use strict "refs";
			return @ret;
		} else {
			my $ret = &{$fn}(@_);
			use strict "refs";
			return $ret;
		}
	} else {
		my $msg = 'Strange call for nonexistent ' . $n . ' in  ' .  $d;
		Log (0, $msg);
		die($serverName . ': ' . $msg);
	}
		
	return '';
}

###############################################################################


### Timer functions ###
sub setTimeout($$$) {
	my ($timeMs, $fn, $arg) = @_;

	$timeoutElCount++;
	$timeoutList{$timeoutElCount}{TRIGGERTIME} = gettimeofday() + $timeMs / 1000;
	$timeoutList{$timeoutElCount}{FN} = $fn;
	$timeoutList{$timeoutElCount}{ARG} = $arg;
	
	$timeoutNext = $timeMs if(!$timeoutNext || $timeoutNext > $timeMs);

	return $timeoutElCount;
}

sub clearTimeout($) {
	my ($timerId) = @_;
	if ($timeoutList{$timerId}) {
		delete ($timeoutList{$timerId});
	}
}

sub handleTimeout() {

	my $now = gettimeofday();
	return ($timeoutNext - $now) if($now < $timeoutNext);
	
	$now += 0.01;# need to cover min delay at least
	$timeoutNext = 0;

	# Check the internal list.
	foreach my $i (sort { $timeoutList{$a}{TRIGGERTIME} <=> $timeoutList{$b}{TRIGGERTIME} } keys %timeoutList) {
		my $timeMs = $timeoutList{$i}{TRIGGERTIME};
		my $fn = $timeoutList{$i}{FN};

		if(!defined($timeMs) || !defined($fn)) {
			delete($timeoutList{$i});
			next;
		} elsif($timeMs <= $now) {
			no strict "refs";
#			&{$fn}($timeoutList{$i}{ARG});
			&{\&{$fn}}($timeoutList{$i}{ARG});
			
			use strict "refs";
			delete($timeoutList{$i});
		} else {
			$timeoutNext = $timeMs if(!$timeoutNext || $timeoutNext > $timeMs);
		}
	}

	return undef if(!$timeoutNext);
	$now = gettimeofday(); # possibly some tasks did timeout in the meantime we will cover them 
	return ($now+ 0.01 < $timeoutNext) ? ($timeoutNext - $now) : 0.01;
}



### Functions for Logging
sub Log($$) {
	my ($loglevel, $msg) = @_;
	Log3 ($serverName, $loglevel, $serverName . ': ' . $msg);
}

sub Log3($$$) {
	my ($dev, $loglevel, $text) = @_;

	$dev = $dev->{NAME} if(defined($dev) && ref($dev) eq "HASH");
	if(defined($dev) && defined($attr{$dev}) && defined (my $devlevel = $attr{$dev}{verbose})) {
		return if($loglevel > $devlevel);
	} else {
		return if($loglevel > $attr{global}{verbose});
	}

	my ($seconds, $microseconds) = gettimeofday();
	my @t = localtime($seconds);
#	my $nfile = ResolveDateWildcards($attr{global}{logfile}, @t);
#	my $nfile = '-';
#	OpenLogfile($nfile) if(!$currlogfile || $currlogfile ne $nfile);
	OpenLogfile($currlogfile);

	my $tim = sprintf(
		"%04d.%02d.%02d %02d:%02d:%02d",
		$t[5]+1900,$t[4]+1,$t[3], $t[2],$t[1],$t[0]
	);

	if($attr{global}{mseclog}) {
		$tim .= sprintf(".%03d", $microseconds/1000);
	}

	if($logopened) {
		print LOG "$tim $loglevel: $text\n";
	} else {
		print "$tim $loglevel: $text\n";
	}

	return undef;
}

sub OpenLogfile($) {
	my $param = shift;

	close(LOG);
	$logopened=0;
	$currlogfile = $param;

	# STDOUT is closed in windows services per default
	if(!$winService->{AsAService} && $currlogfile eq "-") {
		open LOG, '>&STDOUT' || die "Can't dup stdout: $!";
	} else {
#		HandleArchiving($defs{global}) if($defs{global}{currentlogfile});
		$defs{global}{currentlogfile} = $param;
		$defs{global}{logfile} = $attr{global}{logfile};

		open(LOG, ">>$currlogfile") || return("Can't open $currlogfile: $!");
		redirectStdinStdErr() if($init_done);
	}
	LOG->autoflush(1);
	$logopened = 1;
	return undef;
}

sub redirectStdinStdErr() {
	# Redirect stdin/stderr
	return if(!$currlogfile || $currlogfile eq "-");

	open STDIN,  '</dev/null'      or print "Can't read /dev/null: $!\n";

	close(STDERR);
	open(STDERR, ">>$currlogfile") or print "Can't append STDERR to log: $!\n";
	STDERR->autoflush(1);

	close(STDOUT);
	open STDOUT, '>&STDERR'        or print "Can't dup stdout: $!\n";
	STDOUT->autoflush(1);
}



sub parseCommand($) {
	my ($cmd) = @_;

	# execute shell code in forderground
	if($cmd =~ m/^"(.*)"$/s) {
		my $out = '';
		$out = '>> ' . $currlogfile . ' 2>&1' if($currlogfile ne '-' && $^O ne 'MSWin32');

		system($1 . ' ' . $out);
	}
}



### DoTrigger
sub DoTrigger($$) {
	my ($name, $text) = @_;
	
	Log(2, $text);
	ServerTools_serialReconnect();
}

1;
