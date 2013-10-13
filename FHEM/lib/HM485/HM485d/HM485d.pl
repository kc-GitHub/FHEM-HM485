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

=cut


=head1
doku Kommunikationsformat:

Nachrichten vom HMLAN

  HMLAN: HHM-LAN-IF,03C1,JEQ0185836,1ACAE5,1ACAE5,29B47EFE,0006

	0 = HHM-LAN-IF (Wird nach dem Starten und nach jedem Keepalife geschickt
		1 = Firmware Version (2 Bytes HEX) / 1000
		2 = Seriennummer (String)
		3 = 4. Stelle
		4 = HMLAN-ID
		5 = UPTIME
		6 = assignIDsReport ???

	0 = E|R...
		0 = Zeichen E oder R + src
		1 = Status (Hex)
		2 = msec (seit uptime)
		3 = ???
		4 = RSSI -> hex($mFld[4])-65536);
		5 = Message (A0 82 02 1860F1 186F30 0101000021) $mNo, $flg, $type, $src, $dst, data???
		
		#@mFld=($src, $status, $msec, $d2, $rssi, $msg)
		
	0 = I00....
		Ack from the HMLAN

Nachrichten zum HMLAN

  Initialisierungssequenz:
	A[$ID]									HM-LAN Id Setzen (Wenn nötig)
	C										???
	Y01,01,[$key]							??? Es wird kein $key gesetzt. AttrVal($name, "hmKey", "") ist auch nicht dokumentiert
	Y02,00,									???
	Y03,00,									???
	Y03,00,			
  	T[$timeSince2000],04,00,00000000");		Zeit stellen

  Keepalive-Nachricht
	K

  Lange Nachrichten (> 51 zeichen)
  	0 = S[$time]										Zeit in msec
  	1 = 00												???
  	2 = 00000000										???
  	3 = 01												???
  	4 = [$time]											Zeit in msec
  	5 = Message (01 B0 11 1ACAE5 178D3F 0201C80000)		$msgNo, $flg, $type, $src, $dst, $data???

Befehle senden:
on
SE48EBDBA,00,00000000,01,E48EBDBA,01B0111ACAE5178D3F0201C80000
SE48FAE69,00,00000000,01,E48FAE69,02B0111ACAE5178D3F0201C80000
SE4901400,00,00000000,01,E4901400,03B0111ACAE5178D3F0201C80000
SE4905000,00,00000000,01,E4905000,04B0111ACAE5178D3F0201C80000

off
SE4907D38,00,00000000,01,E4907D38,05B0111ACAE5178D3F0201000000	3.834.674.488
SE490854A,00,00000000,01,E490854A,06B0111ACAE5178D3F0201000000	3.834.676.554
SE4908AF9,00,00000000,01,E4908AF9,07B0111ACAE5178D3F0201000000	3.834.678.009




#######################

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

##################################################
# Constants:
use constant {
	HM485D_NAME      => 'HM485d',
	INTERFACE_NAME   => 'HMW-SOFT-GW',
	VERSION          => '0.2.1',
	PROTOCOL_VERSION => 1,
	SERIALNUMBER_DEF => 'SGW0123456',
	CRLF             => "\r\n"
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
my $msgCounter     = 0;

################################################

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

=head2 NAME
# Daten Empfangen

# Startzeichen FD (hab noch kein FE gesehen)
# |  Länge der Nachricht inkl. MessageCounter
# |  |  MessageCounter, wird mit jedem KeepAlive oder anderer Message hochgezählt, Overflow bei 0xFF --> 0x01, startet nach Transparenzbefehl mit 01
# |  |  |  Befehl (z.B. E steht für Event)
# |  |  |  |  ab hier kommen die Nutzdaten
# |  |  |  |  ---------------------------------------
# |  |  |  |  Zieladresse
# |  |  |  |  |           CTRL-Byte
# |  |  |  |  |           |  Absenderadresse
# |  |  |  |  |           |  |           Nutzdaten, könnte das der Jalousie-Aktor-Status sein?
# |  |  |  |  |           |  |           |
# -- -- -- -- ----------- -- -- -------- -----------
# FD 0F 15 65 00 00 00 01 5E 00 00 8F 14 69 02 C8 00
=cut
sub clientRead($) {
	my ($msg) = @_;
	my @messages = split(chr(0xFD), $msg);

	foreach my $message (@messages) {
		if ($message) {
			$message = chr(0xFD) . $message;
			
			### Debug ###
#			my $m = $message;
#			my $l = uc( unpack ('H*', $m) );
#			$m =~ s/^.*CRLF//g;
#			Log3 ('', 1, $l . ' (RX: ' . $m . ')' . "\n");
		
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
#	my $m = $msg;
#	my $l = uc( unpack ('H*', $m) );
#	$m =~ s/^.*CRLF//g;
#	Log3 ('', 1, $l . ' (TX: ' . $m . ')' . "\n");

	if ($clientCount > 0) {
		ServerTools_serverWriteClient($msg);
	} else {
		push(@deviceRxBuffer, $msg);
	}	
}

# Dispatch Welcome Message
sub clientWelcome($) {
	my ($cHash, $clientNum) = @_;
	my $retVal = 0;
	
	if ($clientNum == 1) {
		my $welcomeMsg = sprintf(
			'H%02X,%02X,%s,%s,%s%s',
			($msgCounter-1), PROTOCOL_VERSION, INTERFACE_NAME, VERSION , $serialNumber, CRLF
		); 

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
	} else {
		ServerTools_serverWriteClient('Connection refused. Only on Client allowed');
	}
	
	return $retVal;
}

sub clientClose($) {
	my ($cHash) = @_;
	$clientCount = ($clientCount>0) ? $clientCount-1 : 0;
}

sub interfaceRead($) {
	my ($hash) = @_;

	my $rawMsg = '';
	my $msg = '';
	my $buffer = DevIo_SimpleRead($hash);

	if (defined($buffer)) {
		if ($hm485Protocoll->checkStateDiscoveryWait()) {
			# We found a discovery ACK
			$hm485Protocoll->discoveryFound(
				ord(substr($buffer, 0, 1))
			);
		} else {
			if ($hm485Protocoll->checkStateIdle()) {
				$hm485Protocoll->readFrame($buffer);
			}
		}
	}
}

sub interfaceWrite($) {
	my ($buffer) = @_;

	interfaceSetGpio(1);               # set gpio pin for RS485 TX enable if necesarry
	ServerTools_serialWrite($buffer);  # send out buffer to IO device
	interfaceSetGpio(0);               # reset gpio pin for RS485 TX enable if necesarry
}

=head2 interfaceSetGpio
	Title:		interfaceSetGpio
	Function:	Set or reset specific gpio line for enable the transmitter in RS485 tranceiver.
				Set or reset executes only if attr "gpioTxenCmd_0" and "gpioTxenCmd_1" are defined.
				If you use a USB-RS485 converter or a Network-RS485 converter no set or reset are required. 
	Returns:	nothing
	Args:		named arguments:
				-argument1 => int:	$value			1: execute set comand, 0: execute reset comand
=cut
sub interfaceSetGpio ($) {
	my ($value) = @_;

	if ($gpioTxenCmd0 ne '' && $gpioTxenCmd0 ne '') {
		my $cmd = ($value == 1) ? $gpioTxenCmd1 : $gpioTxenCmd0;
		parseCommand($cmd);
	}
}

################################################################################

=head2 interfaceInit

 Title    : interfaceInit
 Function : Implements DoInit function. Initialize the interface device
 Returns  : string | undef
 Args     : named arguments:
            -argument1 => hash: hash of device addressed
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

	Log3 ($hash, 2, $name . ' connected to device ' . $dev);
	$hash->{ReadFn} = 'interfaceRead';
	$hash->{STATE} = 'open';
	
	return undef;
}

sub checkResendQueueItems () {
	$hm485Protocoll->checkResendQueueItems();
}

################################################################################
# HM485d initialization

init();
ServerTools_main();

exit(0);

1;
