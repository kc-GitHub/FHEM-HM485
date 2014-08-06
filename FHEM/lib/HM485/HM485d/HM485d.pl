#!/usr/bin/perl

=head1 NAME

HM485d.pl

=head1 SYNOPSIS

HM485d.pl --device <device> [options]

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-hmwId>

The HMW-ID (8 digit hex value) hmwId must be 8 digit hex address within 00000001 and 000000FF'

=item B<-localPort>

The local port of HM485d listening on localhost.

=item B<-device>

the device for the interface e.g. /dev/ttyUSB0, 179.168.178.10:5000 or so on

=item B<-serialNumber>

Should be a unique alphanumerical identifyer for identifying the running process.

=item B<-gpioTxenInit>

command to init the gpio pin to controll txen

=item B<-gpioTxenCmd1>

command to set txen gpio pin

=item B<-gpioTxenCmd0>

command to reset txen gpio pin

=item B<-logfile>

Logfile for logging. "-" for logging on STDIN

=item B<-verbose>

verbose level

=back

=head1 DESCRIPTION

This is the HM485 communication stack for raw communication via "stupid" serial
interface devices for instance simple USB-RS485 or Network-RS485 adaptor.
Contributed by Dirk Hoffmann 2013

Todo:
	Discovery at LXCCU don't work at the moment
	
=cut

=head1
Nachrichten vom HMW-LG
Das hier ist noch spekulation:

	0 = E|R...
		0 = E|R + src
		1 = msec (set uptime)
		2 = Message (FD 000059ED 98 00000001 780F00) $startZeichen, $target, $cc, $source, $data

  Initialisierungssequenz:

  HMW-LGW: H13,01,eQ3-HMW-LGW,1.0.4,KEQ0360763
	0 = H13				H + Fortlaufende Hex-Nummer vermutlich 00 - FF mit Überlauf (scheinbar =+2) 
	1 = 01				???
	2 = eQ3-HMW-LGW		Interface Indetifyer ???
	3 = Firmware Version (String)
	4 = Seriennummer (String)

  Sxx (Wird gleich nach dem Initialisierungsstring gesendet 
	0 = Sxx				S + Irgendeine Fortlaufende Nummer (scheinbar =+2)

Nachrichten zum HMW-LG (nur Spekulattion)
	0 = S...
		0 = S + $time	???
		1 = Message (FD 000059ED 98 00000001 780F00) $startZeichen, $target, $cc, $source, $data

=cut

package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use Cwd qw(abs_path);
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use bytes;

use FindBin;
use lib abs_path("$FindBin::Bin/..");

use Constants;
use Util;
use HM485d::HM485_Protocol;

use vars qw(%selectlist);  # devices which want a "select"
use vars qw(%readyfnlist); # devices which want a "readyfn"
use vars qw($devcount);	   # To sort the devices
use vars qw(%defs);        # FHEM device/button definitions
use vars qw(%hash);

# Todo: for development only.
use Data::Dumper;

##################################################
# Forward declarations
#
sub init();
sub clientRead($);
sub clientWrite($$$);
sub clientWelcome($$);
sub clientClose($);
sub interfaceRead($);
sub interfaceWrite($);
sub interfaceSetGpio ($);
sub interfaceInit($);
sub checkResendQueueItems();

##################################################
# Constants:
use constant {
	HM485D_NAME      => 'HM485d',
	INTERFACE_NAME   => 'HMW-SOFT-GW',
	VERSION          => '0.2.1',
	PROTOCOL_VERSION => 1,
	SERIALNUMBER_DEF => 'SGW0123456',
	CRLF             => "\r\n",
	LOGTAG           => 'HM485d'
};

##################################################
# Variables:
my $hm485Protocoll;

my $device         = '';
my $gpioTxenInit   = '';
my $gpioTxenCmd1   = '';
my $gpioTxenCmd0   = '';
my @deviceRxBuffer = ();
my $clientCount    = 0;
my $serialNumber   = SERIALNUMBER_DEF;
my $msgCounter     = 1;

=head2
	Initialize the daemon
=cut
sub init() {
	my $scriptPath = '';
	$scriptPath = dirname(abs_path($0)) . '/';

	my $pathFHEM = $scriptPath . '../../../';

	require $pathFHEM . 'ServerTools.pm';
	
	my $help = 0;
	my $man = 0;
	my $logFile = '-';
	my $logVerbose = 0;
	my $hmwId = '00000001';
	my $localPort = 2000;
	GetOptions (
		'hmwId=s'        => \$hmwId,        # The HMW-ID (8 digit hex value)
		'localPort=i'    => \$localPort,    # The local port of HM485d listening on localhost.
		'device=s'       => \$device,       # the device for the interface e.g. /dev/ttyUSB0, 179.168.178.10:5000 or so on
		'serialNumber=s' => \$serialNumber, # Should be a unique alphanumerical identifyer for identifying the running process.
		'gpioTxenInit=s' => \$gpioTxenInit, # command to init the gpio pin to controll txen
		'gpioTxenCmd1=s' => \$gpioTxenCmd1, # command to set txen gpio pin
		'gpioTxenCmd0=s' => \$gpioTxenCmd0, # command to reset txen gpio pin
		'logfile=s'      => \$logFile,      # command to reset txen gpio pin
		'verbose=i'      => \$logVerbose,   # verbose level
		'help|?'         => \$help,
		'man'            => \$man
	);
	
	pod2usage(pod2usage(1)) if ($help);
	pod2usage(-verbose => 2) if ($man);

	my $res;
	if (!defined($hmwId) || $hmwId !~ m/^[A-F0-9]{8}$/i || hex($hmwId) > 255 || hex($hmwId) < 1) {
		$res = 'Wrong hmwId given. hmwId must be 8 digit hex address within 00000001 and 000000FF';
	}

	ServerTools_init(
		HM485D_NAME,
		$pathFHEM,
		$logFile,
		$logVerbose,
		$localPort,
		'clientRead',
		'clientWelcome',
		'clientClose',
		$device,
		'interfaceRead',
		'interfaceInit'
	);

	# Init for GPIO usage (e.g. on Raspberry Pi)
	if ($gpioTxenInit ne '') {
		parseCommand($gpioTxenInit);
	}

	$hm485Protocoll = HM485_Protocol->new($hmwId);
	$hm485Protocoll->setStateIdle();
}

=head2
	Receive data from client

	Start byte FD
	|  message lenth incl message counter
	|  |  message counter, incements with each message, also KeepAlive, overflow at 0xFF --> 0x01, start after "Transparenzbefehl" with 01
	|  |  |  Command (e.g. e (Event)
	|  |  |  |  target address
	|  |  |  |  |           CTRL byte
	|  |  |  |  |           |  source address
	|  |  |  |  |           |  |           payload ...
	|  |  |  |  |           |  |           |
	-- -- -- -- ----------- -- -- -------- -----------
	FD 0F 15 65 00 00 00 01 5E 00 00 8F 14 69 02 C8 00


	@param	string  the message
=cut
sub clientRead($) {
	my ($msg) = @_;
	my @messages = split(chr(0xFD), $msg);

	# todo:
	# in case of buffer overflow in ServerTools_serverRead we lost the last mesage
	# there only 10240 bytes buffer
	foreach my $message (@messages) {
		if ($message) {
			$message = chr(0xFD) . $message;
			
			### Debug ###
			HM485::Util::debugBinData(LOGTAG, 4, $message, 'Rx', 1);
		
			my $msgFirstByte = substr($message, 0, 1);
			my $msgId        = ord(substr($message, 2, 1));
			my $msgCmd       = (length($message) >2) ? substr($message, 3, 1) : '';
	
			if ($msgId == 0) {
				$msgId = ($msgCounter >= 0xFF) ? 1 : ($msgCounter + 1);
				$msgCounter = $msgId;
			}
			
			if ($msgCmd eq 'K') {                                 # Keepalive
				clientWrite($msgId, 0x61, chr(0x00));
		
			} elsif ($message eq chr(0xFD) . chr(0x51) . chr(0x0D). chr(0x0A)) { # send Q + CR + LF in telnet
				# Quit command for telnet connection
				ServerTools_serverShutdown();
		
			} elsif ($msgFirstByte ne '>' && $msgCmd) {	
				$hm485Protocoll->parseCommand(
					HM485::Util::unescapeMessage($message), $msgId
				);
			}
		}
	}
}

=head2
	Send data to Client

	@param	integer the message id
	@param	integer the command
	@param	string  the payload
=cut
sub clientWrite($$$) {
	my ($msgId, $msgCmd, $msgData) = @_;
	my $len = 2 + length($msgData);

	if ($msgId == 0) {
		$msgId = ($msgCounter >= 0xFF) ? 1 : ($msgCounter + 1);
	}
	$msgCounter = $msgId;

	my $msg = chr(0xFD) . chr($len) . chr($msgId) . chr($msgCmd) . $msgData;

	$msg = HM485::Util::escapeMessage($msg);

	### Debug ###
	HM485::Util::debugBinData(LOGTAG, 4, $msg, 'Tx', 1);

	if ($clientCount > 0) {
		ServerTools_serverWriteClient($msg);
	} else {
		push(@deviceRxBuffer, $msg);
	}	
}

=head2
	Dispatch welcome message

	@param	hash    the client hash (not used)
	@param	integer the client count
	
	@return integer 1 if welcome mesage was sent 
=cut
sub clientWelcome($$) {
	my ($cHash, $clientNum) = @_;
	my $retVal = 0;
	
	if ($clientNum > 1) {
		ServerTools_serverWriteClient('Connection refused. Only on Client allowed');
	} else {
		my $welcomeMsg = sprintf(
			'H%02X,%02X,%s,%s,%s%s',
			($msgCounter-1), PROTOCOL_VERSION, INTERFACE_NAME, VERSION , $serialNumber, CRLF
		); 

		# Debug
		HM485::Util::debugBinData(LOGTAG, 4, $welcomeMsg, 'Tx', 2);

		# switch protocol command
		$welcomeMsg.= sprintf('S%02X%s', $msgCounter, CRLF); 
		
		ServerTools_serverWriteClient($welcomeMsg);
		
		if (scalar(@deviceRxBuffer) > 0) {
			foreach (@deviceRxBuffer){
				ServerTools_serverWriteClient ($_);
			}
			@deviceRxBuffer = ();
		}
		
		$clientCount = $clientNum;
		$retVal = 1;
	}
	
	return $retVal;
}

=head2
	Close the connection to client.

	@param	hash    the client hash (not used)
=cut
sub clientClose($) {
	my ($cHash) = @_;
	$clientCount = ($clientCount>0) ? $clientCount-1 : 0;
}

=head2
	Read bytes from serial Interface
	
	@param	hash    the client hash
=cut
sub interfaceRead($) {
	my ($hash) = @_;

	my $rawMsg = '';
	my $msg = '';
	my $buffer = DevIo_SimpleRead($hash);

	if (defined($buffer)) {
		if ($hm485Protocoll->checkStateDiscoveryWait()) {
			# We found a discovery ACK
			$hm485Protocoll->discoveryFound(ord(substr($buffer, 0, 1)));

		} else {
			if ($hm485Protocoll->checkStateIdle()) {
				$hm485Protocoll->readFrame($buffer);
			}
		}
	}
}

=head2
	Write bytes to serial Interface
	
	@param	string  the buffer to write
=cut
sub interfaceWrite($) {
	my ($buffer) = @_;

	interfaceSetGpio(1);               # set gpio pin for RS485 TX enable if necesarry
	ServerTools_serialWrite($buffer);  # send out buffer to IO device
	interfaceSetGpio(0);               # reset gpio pin for RS485 TX enable if necesarry
}

=head2
	Set or reset specific gpio line for enable the transmitter in RS485 tranceiver.
	Set or reset works only if attr "gpioTxenCmd_0" and "gpioTxenCmd_1" are defined.

	@param	integer  the value, 1: execute set comand, 0: execute reset comand
=cut
sub interfaceSetGpio ($) {
	my ($value) = @_;

	if ($gpioTxenCmd0 ne '' && $gpioTxenCmd0 ne '') {
		my $cmd = ($value == 1) ? $gpioTxenCmd1 : $gpioTxenCmd0;
		parseCommand($cmd);
	}
}

=head2
	Implements DoInit function. Initialize the interface device

	@param	hash of device addressed
	@return string | undef
=cut
sub interfaceInit($) {
	my ($hash) = @_;

	my $name = $hash->{NAME};
	my $dev = $hash->{DeviceName};

	# Comport settings not, if dev like 192.168.2.11:5000 
	if ( !($dev=~/([\w.]+):(\d{1,5})/) ) {
		my $po = $hash->{USBDev};
		# Parameter 19200, 8, 1, even, none
		$po->reset_error();
		$po->baudrate(19200);
		$po->databits(8);
		$po->parity('even');
		$po->stopbits(1);
		$po->handshake('none');

		Log (3, 'Setting ' . $name . 'baudrate=19200, databits=8, parity=even, stopbits=1, handshake=none');

		if (!$po->write_settings) {
			undef $po;
			$hash->{STATE} = 'Error on write serial line settings on device ' . $dev;
			Log (1, $hash->{STATE});
			return $hash->{STATE} . "\n";
		}
	}

	HM485::Util::logger(LOGTAG, 2, $name . ' connected to device ' . $dev);
	$hash->{ReadFn} = 'interfaceRead';
	$hash->{STATE} = 'open';
	
	return undef;
}

=head2
	Wrapper for $hm485Protocoll->checkResendQueueItems

	In $hm485Protocoll we execute checkResendQueueItems via main::setTimeout.
	To setTimeout we can only pass function name without package name.
	So the checkResendQueueItems function in main was executed.
=cut
sub checkResendQueueItems () {
	$hm485Protocoll->checkResendQueueItems();
}

################################################################################
# HM485d initialization

init();
ServerTools_main();

exit(0);

1;
