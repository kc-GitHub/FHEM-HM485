=head1
	00_HM485_SERIAL.pm

=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013
	$Id$

=head1 DESCRIPTION
	00_HM485_SERIAL is the interface for communicate with HomeMatic Wired (HM485) devices
	over USB / UART / RS232 -> RS485 Converter

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
=cut
 
package main;

use strict;
use warnings;
use Data::Dumper;

use vars qw {%attr %defs %selectlist}; #supress errors in Eclipse EPIC

# FHEM Inteface related functions
sub HM485_SERIAL_Initialize($);
sub HM485_SERIAL_Define($$);
sub HM485_SERIAL_Ready($);
sub HM485_SERIAL_Init($);
sub HM485_SERIAL_Undef($$);
sub HM485_SERIAL_Attr(@);
sub HM485_SERIAL_Read($);
sub HM485_SERIAL_Set($@);

my %sets = (
	'raw' => 1,
	'discovery' => 1,
);

=head2 HM485_SERIAL_Initialize
	Title		: HM485_SERIAL_Initialize
	Usage		: HM485_SERIAL_Initialize(\%hash);
	Function	: Implements Initialize function
	Returns 	: nothing
	Args 		: named arguments:
				: -argument1 => hash	: hash of device addressed
=cut
sub HM485_SERIAL_Initialize($) {
	my ($hash) = @_;

	require $attr{global}{modpath} . '/FHEM/DevIo.pm';
	require $attr{global}{modpath} . '/FHEM/HM485/lib/Communication.pm';
	require $attr{global}{modpath} . '/FHEM/HM485/lib/Device.pm';
	require $attr{global}{modpath} . '/FHEM/HM485/lib/Command.pm';
	require $attr{global}{modpath} . '/FHEM/HM485/lib/Util.pm';
	require $attr{global}{modpath} . '/FHEM/Blocking.pm';

	my $ret = FHEM::HM485::Device::init();
	if (defined($ret)) {
		Log (1, $ret);
	} else {

		$hash->{DefFn}		= 'HM485_SERIAL_Define';
		$hash->{ReadyFn}	= 'HM485_SERIAL_Ready';
		$hash->{UndefFn}	= 'HM485_SERIAL_Undef';
		$hash->{AttrFn}		= "HM485_SERIAL_Attr";
		$hash->{AttrList}	= 'hmwId do_not_notify:0,1 dummy:1,0 showtime:1,0 '.
							  'loglevel:0,1,2,3,4,5,6 gpioTxenInit gpioTxenCmd_0 gpioTxenCmd_1';
		$hash->{Clients}	= ':HM485:';
		my %mc = (
			'1:HM485'	=> '^........',
		);
		$hash->{MatchList}	= \%mc;
	
		# Provider
		$hash->{ReadFn}		= 'HM485_SERIAL_Read';
		$hash->{SetFn}		= 'HM485_SERIAL_Set';
	}
}

=head2 HM485_SERIAL_Define
	Title		: HM485_SERIAL_Define
	Function	: Implements DefFn function
	Returns 	: string | undef
	Args 		: named arguments:
				: -argument1 => hash	: hash of device addressed
				: -argument2 => string	: definition string
=cut
sub HM485_SERIAL_Define($$) {
	my ($hash, $def) = @_;
	my @a = split('[ \t][ \t]*', $def);

	my $name = $a[0];
	my $dev = $a[2];

	my $msg = '';
	if( (@a < 3)) {
		$msg = 'wrong syntax: define <name> HM485 {none | devicename | hostname:port}';
	}

	# create default hmwId on define, modify is possible e.g. via "attr <name> hmwId 00000002"
	$msg = CommandAttr(undef, $name . ' hmwId 00000001');

	if ($msg) {
		Log (1, $msg);
		return $msg;
	}

	if($dev eq 'none') {
		Log (1, 'HM485 device is none, commands will be echoed only');
		$attr{$name}{dummy} = 1;
		delete($selectlist{$name . '.' . $hash->{DEF}});
		return undef;
	}

	DevIo_CloseDev($hash);

	$hash->{DeviceName} = $dev;
	my $ret = DevIo_OpenDev($hash, 0, 'HM485_SERIAL_Init');

	# init gpio-ports if attribute gpioTxenInit set	
	my $gpioTxenInit = main::AttrVal($name, 'gpioTxenInit', '');
	main::Log(1, 'gpioTxenInit: ' . $gpioTxenInit);
	if ($gpioTxenInit ne '') {
		FHEM::HM485::Util::parseCommand($gpioTxenInit);
	}

	return $ret;
}

=head2 HM485_SERIAL_Ready
	Title:		HM485_SERIAL_Ready
	Function:	Implements ReadyFn function.
	Returns:	boolean
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
=cut
sub HM485_SERIAL_Ready($) {
	my ($hash) = @_;

	return DevIo_OpenDev($hash, 1, 'HM485_SERIAL_Init') if($hash->{STATE} eq 'disconnected');

	# This is relevant for windows/USB only
	my $po = $hash->{USBDev};
	my ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags) = $po->status;
	return ($InBytes>0);
}

=head2 HM485_SERIAL_Init
	Title		: HM485_SERIAL_Init
	Function	: Implements DoInit function. Initialize the serial device
	Returns 	: string | undef
	Args 		: named arguments:
				: -argument1 => hash	: hash of device addressed
=cut
sub HM485_SERIAL_Init($) {
	my ($hash) = @_;

	my $po = $hash->{USBDev};
	my $dev = $hash->{DeviceName};
	my $name = $hash->{NAME};

	# Comport settings not, if dev like 192.168.2.11:5000 
	if ( !($dev=~/([\w.]+):(\d{1,5})/) ) {
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

	Log (GetLogLevel($name,3), $name . ' connected to device ' . $dev);
	$hash->{STATE} = 'open';
	$hash->{TX_STATE} = $FHEM::HM485::Communication::STATE_IDLE;

	return undef;
}

=head2 HM485_SERIAL_Undef
	Title:		HM485_SERIAL_Undef
	Function:	Implements UndefFn function.
	Returns:	string|undef
	Args:		named arguments:
				-argument1 => hash:		$hash	hash of device addressed
				-argument1 => string:	$name	name of device
=cut
sub HM485_SERIAL_Undef($$) {
	my ($hash, $name) = @_;

	foreach my $d (sort keys %defs) {
		if(defined($defs{$d}) && defined($defs{$d}{IODev}) && $defs{$d}{IODev} == $hash) {
			Log (GetLogLevel($name,4), 'deleting port for ' . $d);
			delete $defs{$d}{IODev};
		}
	}

	DevIo_CloseDev($hash);
	return undef;
}

=head2 HM485_SERIAL_Attr
	Title:		HM485_SERIAL_Attr
	Function:	Implements AttrFn function.
	Returns:	string|undef
	Args:		named arguments:
				-argument1 => array
=cut
sub HM485_SERIAL_Attr (@) {
	my (undef, $name, $attr, $val) =  @_;
	my $hash = $defs{$name};
	my $msg = '';

	if ($attr eq 'hmwId') {
		my $hexVal = (defined($val)) ? hex($val) : 0;
		if (!defined($val) || $val !~ m/^[A-F0-9]{8}$/i || $hexVal > 255 || $hexVal < 1) {
			$msg = 'Wrong hmwId defined. hmwId must be 8 digit hex address within 00000001 and 000000FF';
		} else {
			
			foreach my $d (keys %defs) {
				next if($d eq $name);
		
				if($defs{$d}{TYPE} eq 'HM485_SERIAL') {
					if(AttrVal($d, 'hmwId', '00000001') eq $val) {
						$msg = 'hmwId ' . $val . ' already used. Please use another one.';
					}
				}
			}
		}
	}

	return ($msg) ? $msg : undef;
}

=head2 HM485_SERIAL_Read
	Title:		HM485_SERIAL_Read
	Function:	Implements ReadFn function.
				called from the global loop, when the select for hash->{FD} reports data
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash	$hash	hash of device
=cut
sub HM485_SERIAL_Read($) {
	my ($hash) = @_;

	my $buffer = DevIo_SimpleRead($hash);
	
	if (defined($buffer)) {
		FHEM::HM485::Communication::readFrame($hash, $buffer);
	}
}

=head2 HM485_SERIAL_Set
	Title:		HM485_SERIAL_Set
	Function:	Implements SetFn function.
	Returns:	string
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => array:	@a		argument array
=cut
sub HM485_SERIAL_Set($@) {
	my ($hash, @a) = @_;

	my $name =$a[0];
	my $cmd = $a[1];
	my $msg = '';
	
	return '"set HM485" needs one or more parameter' if(@a < 2);
	
	if(!defined($sets{$cmd})) {
		return 'Unknown argument ' . $cmd . ', choose one of ' . join(' ', keys %sets)
	}

	if ($cmd eq 'raw') {
		my $paramError = 0;
		if (@a == 6 || @a == 7) {
			if (($a[2] ne 'FE' && $a[2] ne 'FD' && $a[2] !~ m/^[A-F0-9]{8}$/i ) ||
				 $a[3] !~ m/^[A-F0-9]{8}$/i || $a[4] !~ m/^[A-F0-9]{2}$/i ||
				 $a[5] !~ m/^[A-F0-9]{8}$/i || $a[6] !~ m/^[A-F0-9]{1,251}$/i ) {
					
					$paramError = 1
			}
		} else {
			$paramError = 1;
		}

		return	'"set HM485 raw" needs 5 or 6 parameter Sample: [SS] TTTTTTTT CC SSSSSSSS D...' . "\n" .
				'Set sender address to 00000000 to use address from configuration.' . "\n\n" . 
				'[SS]: optional Startbyte (FD or FE),' . "\n" .
				'   T: 8 byte target address, C: Control byte, S: 8 byte sender address, D: data bytes' . "\n"
				if ($paramError);

		FHEM::HM485::Communication::sendRawQueue(
			$hash, pack('H*', $a[3]), hex($a[4]), pack('H*', $a[5]), pack('H*', $a[6])
		);

	} elsif ($cmd eq 'discovery') {
		if (FHEM::HM485::Util::checkForAutocreate()) {
			# TODO: set timeout from outer
			my $timeout = 30;
	
			$msg = FHEM::HM485::Communication::cmdDiscovery($hash, $timeout);
		} else {
			$msg = 'Please activate and enable autocreate first.'
		}

	} elsif ($cmd eq 'test') {
		# TODO: delete later
		my $senderAddr = pack ('H*', AttrVal($hash->{NAME}, 'hmwId', '00000001'));

		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x31));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x32));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x33));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x34));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x35));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x36));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x37));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x38));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x39));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x3A));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x3B));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x3C));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x3E));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x3F));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x40));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x41));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x42));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x43));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x44));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x45));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x46));
		FHEM::HM485::Communication::sendRawQueue($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x47));
		
		$msg = 'Test done';
	}

	return $msg;
}

1;

=pod
=begin html

<a name="HM485"></a>
	<h3>HM485</h3>
	<p> FHEM module to commmunicate with HM485 devices</p>
	<ul>
		<li>...</li>
		<li>...</li>
		<li>...</li>
	</ul>

=end html
=cut
