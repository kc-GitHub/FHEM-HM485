#!/usr/bin/perl
#
use strict;
use IO::File;

my $DEV = '/dev/ttyUSB1';

#use Device::SerialPort;
use Time::HiRes qw(gettimeofday tv_interval);

my $hs485 = Device::SerialPort->new($DEV) || die "Can't open $DEV: $!";
$hs485->reset_error();
$hs485->baudrate(19200);
$hs485->databits(8);
$hs485->parity('even');
$hs485->stopbits(1);
#$hs485->handshake('none');

my ($count,$buf);

my $start = (times)[0];
while (1) {
	if ($buf = $hs485->read(255)) {
	
		for (my $i=0; $i < length($buf); $i++){

			my $buf2 = substr($buf,$i,1);
			if ( (unpack('H*', $buf2) eq "fd") || (unpack('H*', $buf) eq "fe")) {
				print STDERR "\n";

#				my $result = (times)[0]-$start;
#				printf STDERR $result . " - ";
			}
			printf STDERR uc(unpack('H*', $buf2)) . " ";
#			printf STDERR ord($buf) . " ";
		}
	}
}

undef $hs485;

1;

__END__

