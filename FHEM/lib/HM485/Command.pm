package HM485::Command;

use strict;
use warnings;
use Data::Dumper;

use lib '.';
use Constants;

# HM485 for all Devices
sub discovery($$);

sub HM485_SERIAL_cmdDiscoveryStart($$);
sub HM485_SERIAL_cmdDiscoveryStop($$);

sub discovery($$) {
	my ($hash, $name) = @_;
#	my $msg = $name . ' - Start discovery mode.';

#	return $msg;
}

# TODO: make ready
=head2 HM485_SERIAL_cmdDiscoveryStop
	Title:		HM485_SERIAL_cmdDiscoveryStop
	Usage:		TODO:
	Function:	Start the discovery on the RS485 bus to determin all connected modules
	Returns:	string
	Args:		named arguments:
				-argument1 => hash		$hash	hash of device
				-argument1 => string	$name
=cut
sub HM485_SERIAL_cmdDiscoveryStart($$) {
	my ($hash, $name) = @_;
	my $msg = $name . ' - Start discovery mode.';

	return $msg;
}

# TODO: make ready
=head2 HM485_SERIAL_cmdDiscoveryStop
	Title:		HM485_SERIAL_cmdDiscoveryStop
	Usage:		TODO:
	Function:	Stop the discoery on the RS485 bus. No connected modules are detected.
	Returns:	string
	Args:		named arguments:
				-argument1 => hash		$hash	hash of device
				-argument1 => string	$name
=cut
sub HM485_SERIAL_cmdDiscoveryStop($$) {
	my ($hash, $name) = @_;
	my $msg = $name . ' - Stop discovery mode.';

#	HM485::Communication::sendRaw($hash, '000059ED 1D 00000001 02 5300');
#	HM485::Communication::sendRaw($hash, 'FFFFFFFF 5A 00000001 05 780FC8');

	return $msg;
}

sub parseCommand($) {
	my ($data) = @_;
	
	my $cmd = hex(substr($data, 0, 2));
	my $sensorNr = 0;

	if (defined($HM485::commands{$cmd})) {
		my $logTxt2 = '';
		my $logTxt = sprintf('%s.%s > ', $cmd, $HM485::commands{$cmd});
		
		if ($cmd eq '41') {														# (A), Announce
			$sensorNr = hex(substr($data, 2, 2));

			my $deviceType	= hex(substr($data, 4, 2));
			my $deviceHW	= hex(substr($data, 6, 2));
			my $deviceFW	= hex(substr($data, 8, 2)) + (hex(substr($data, 10, 2)) / 10); 
			my $deviceSer	= substr($data, 12, 20);

			my $logTxt = $cmd . '.' . $HM485::commands{$cmd};

			$logTxt2 = sprintf('sensor: %s, type: %s, HW: %s, FW: %s, Serial: %s',
				$sensorNr, $deviceType, $deviceHW, $deviceFW, $deviceSer
			);

		} elsif ($cmd == 0x4B) {												# (K), Key Event frame

		} elsif ($cmd == 0x69) {												#(i), Info frame

		}
	}
}

1;