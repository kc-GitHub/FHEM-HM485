=head1
	Util.pm

=head1 SYNOPSIS
	Helper module for HomeMatic Wired (HM485) for FHEM
	contributed by Dirk Hoffmann 2012 - 2013
	$Id$

=head1 DESCRIPTION
	Some helper functions for HomeMatic Wired (HM485) support for FHEM

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
=cut

package HM485::Util;

use strict;
use warnings;
use Data::Dumper;

###############################################################################
# Define prototypes
###############################################################################




###############################################################################

sub searchValueInDefs($$) {
	my ($key, $value) = @_;
	my $retVal = undef;

	foreach my $d (keys %main::defs) {
		if (defined($main::defs{$d}{$key}) && $main::defs{$d}{$key} eq $value) {
			$retVal = $d;
			last
		}
	}
	
	return $retVal;
}

sub checkForAutocreate() {
	my $retValue = 0;
	
	my $autocreate = searchValueInDefs('TYPE', 'autocreate');
	if (defined($autocreate) && !main::IsDisabled($autocreate)) {
		$retValue = 1;
	}
	
	return $retValue;
}

=head2 logger
	Title:		logger
	Function:	Logger for HM485 messages
	Returns:	nothing
	Args:		named arguments:
				-argument1 => int		$level		Loglevel
				-argument1 => string	$tag		Log tag for identification
				-argument1 => string	$txt		Log text
				-argument1 => hash		$dataHash	optional logdata
=cut
sub logger ($$$;$) {
	my ($tag, $level, $txt, $dataHash) = @_;
	my $logTxt = '';

	my $logCCU = 1;
	my $logRaw = 0;
	my $logDiscovery = 1;
	my $formatHex = (!defined($dataHash->{formatHex}) || !$dataHash->{formatHex}) ? 0 : 1; 
	
	if (defined($dataHash) && exists($dataHash->{data})) {
		my $data = printByte($dataHash->{data}, $formatHex);

		if ($logCCU) {
			# TODO: Loglevel, settings relevant!
			if (defined($dataHash->{cb}) && ctrlIsDiscovery($dataHash->{cb}) ) {
				if ($logDiscovery) {
					$logTxt.= ' DISCOVERY(' . ctrlDiscoveryMask($dataHash->{cb}) . ') 00000000';
					$logTxt.= ' -> ' . printByte($dataHash->{target}, $formatHex);
				} else {
					$txt = '';
				}
			} else {
				my $ctrlTxt = '';
				$ctrlTxt.= 'I[' . ctrlTxNum($dataHash->{cb}) . ']' if (ctrlIsIframe($dataHash->{cb}));
				$ctrlTxt.= 'ACK'                                   if (ctrlIsAck($dataHash->{cb}));
				$ctrlTxt.= '(' . ctrlAckNum($dataHash->{cb});

				if (ctrlIsIframe($dataHash->{cb})) {
					$ctrlTxt.= ctrlSynSet($dataHash->{cb})   ? ',Y' : '';
					$ctrlTxt.= ctrlFinalSet($dataHash->{cb}) ? ',F' : '';
				}
				$ctrlTxt.= (ctrlHasSender($dataHash->{cb})   ? ',B' : '') . ')';
				
				$logTxt.= ' '    . $ctrlTxt;
				$logTxt.= ' '    . printByte($dataHash->{sender}, $formatHex);
				$logTxt.= ' -> ' . printByte($dataHash->{target}, $formatHex);

				my $dataLen = (exists($dataHash->{dataLen})) ? $dataHash->{dataLen} : length($dataHash->{data});

				$logTxt.= ' ['   . $dataLen . ']';
				
				if (!exists($dataHash->{dataLen}) || $dataHash->{dataLen} > 2) {
					$logTxt.= ' '    . substr($data, 0, 2);
					$logTxt.= '('    . chr(hex(substr($data, 0, 2))) . ')';
					$logTxt.= ' '    . substr($data, 2, -4);
				}
				$logTxt.= ' {'   . substr($data, -4) . '}'  if (exists($dataHash->{dataLen}));
			}
		}

		if ($logRaw) {
			$logTxt.= ' ' . sprintf('%02X', $dataHash->{start}) . '.';
			$logTxt.= printByte($dataHash->{target}, $formatHex);
			$logTxt.= sprintf('%02X', $dataHash->{cb}) . '.';
			$logTxt.= printByte($dataHash->{sender}, $formatHex) . '.'   if defined($dataHash->{sender});
			$logTxt.= sprintf('%02X', $dataHash->{dataLen}) . '.';
			$logTxt.= $data;
		}
	}
	
	if ($txt . $logTxt) {
		main::Log3('', $level, $tag . ': ' . $txt . $logTxt);
	}
}

sub printByte($$) {
	my ($data, $formatHex) = @_;
	
	my $retVal = '';
	if (defined($formatHex) && $formatHex) {
		$retVal = $data;
	} else {
	 	uc( unpack ('H*', $data) );
	}
}

###############################################################################
# ctrlByte related stuff
###############################################################################
sub ctrlHasSender     ($) {return (((shift) & (1 << 3)) == (1 << 3));}
sub ctrlIsDiscovery   ($) {return (((shift) & 0x07) == 0x03);}
sub ctrlDiscoveryMask ($) {return (((shift) >> 0x03) +1);}
sub ctrlIsAck         ($) {return (((shift) & 0x97) == 0x11);}
sub ctrlIsIframe      ($) {return (((shift) & 0x01) == 0x00);}
sub ctrlSynSet        ($) {return (((shift) & (1<<7)) == (1<<7));}
sub ctrlFinalSet      ($) {return (((shift) & (1<<4)) == (1<<4));}
sub ctrlAckNum        ($) {return ((shift >> 5) & 0x03);}
sub ctrlTxNum         ($) {return ((shift >> 1) & 0x03);}

# TODO: some loggings
# CCU1 Log
# Mar 19 16:44:39 (none) user.err hs485d: HS485PhysicalDataInterfaceCommand::PutData SendMessage() failed
# Mar 19 16:44:39 (none) user.err hs485d: HSSParameter::SetValue() 1.000000 Put failed
# Mar 19 16:45:02 (none) user.debug hs485d: RX: I[1](0,Y,F,B) #52 00000001 -> FFFFFFFF: Z
# Mar 19 16:45:02 (none) user.debug hs485d: RX: ACK(1,B) #53 00008F14 -> 00000001:
# Mar 19 16:45:02 (none) user.debug hs485d: Event: JEQ0271055:0.UNREACH=0

# Mar 19 16:45:14 (none) user.debug hs485d: TX: I[2](0,F,B) #51 00000001 -> 00008F14: x 02 C8
# Mar 19 16:45:14 (none) user.debug hs485d: RX: Response I[0](2,Y,F,B) on #51 : 69 02 64 10
# Mar 19 16:45:14 (none) user.debug hs485d: Event: JEQ0271055:3.LEVEL=0.500000
# Mar 19 16:45:14 (none) user.debug hs485d: Event: JEQ0271055:3.WORKING=true
# Mar 19 16:45:14 (none) user.debug hs485d: Event: JEQ0271055:3.DIRECTION=1
# Mar 19 16:45:16 (none) user.debug hs485d: RX: I[1](2,F,B) #52 00008F14 -> 00000001: i 02 8C 10
# Mar 19 16:45:16 (none) user.debug hs485d: Event: JEQ0271055:3.LEVEL=0.700000
# Mar 19 16:45:16 (none) user.debug hs485d: Event: JEQ0271055:3.WORKING=true
# Mar 19 16:45:16 (none) user.debug hs485d: Event: JEQ0271055:3.DIRECTION=1
# Mar 19 16:45:28 (none) user.debug hs485d: RX: I[2](2,F,B) #53 00008F14 -> 00000001: i 02 C8 00
# Mar 19 16:45:28 (none) user.debug hs485d: Event: JEQ0271055:3.LEVEL=1.000000
# Mar 19 16:45:28 (none) user.debug hs485d: Event: JEQ0271055:3.WORKING=false
# Mar 19 16:45:28 (none) user.debug hs485d: Event: JEQ0271055:3.DIRECTION=0

1;
