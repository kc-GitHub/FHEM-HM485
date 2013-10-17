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
sub logger ($$$;$$) {
	my ($tag, $level, $txt, $dataHash, $return) = @_;
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
				
				$logTxt.= ' '    . $ctrlTxt . '(' . sprintf('%02X', $dataHash->{cb}) . ')';
				$logTxt.= ' '    . printByte($dataHash->{sender}, $formatHex);
				$logTxt.= ' -> ' . printByte($dataHash->{target}, $formatHex);

				my $dataLen = (exists($dataHash->{dataLen})) ? $dataHash->{dataLen} : length($dataHash->{data});

				$logTxt.= ' ['   . $dataLen . ']';
				
				if (!exists($dataHash->{dataLen}) || $dataHash->{dataLen} > 2) {
					$logTxt.= ' '    . substr($data, 0, 2);
					$logTxt.= '('    . chr(hex(substr($data, 0, 2))) . ')';
					if (length($data) > 2) {
						$logTxt.= ' '    . substr($data, 2, -4);
					}
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
	
	my $retVal = '';
	if ($txt . $logTxt) {
		$retVal = $tag . ': ' . $txt . $logTxt;

		if (!defined($return)) {
			main::Log3('', $level, $tag . ': ' . $txt . $logTxt);					
		}
	}
	
	return $retVal;
}

sub printByte($$) {
	my ($data, $formatHex) = @_;
	
	my $retVal = '';
	
	if ($data) {
		if (defined($formatHex) && $formatHex) {
			$retVal = $data;
		} else {
		 	$retVal = uc( unpack ('H*', $data) );
		}
	}
	
	return $retVal;
}

sub removeValuesFromList($$@) {
	my ($hash, $list, @removeArray) = @_;
	my $name = $hash->{NAME};
	
	my $retVal = $list;

	foreach my $item (@removeArray){
		$retVal =~ s/$item//;
	}
	
	return $retVal;
}

sub escapeMessage($) {
	my ($message) = @_;

	my $start;

	if ($message) {
		$start = substr($message, 0,1);
		$message = substr($message, 1);
		
		$message =~ s/\xFC/\xFC\x7C/g;
		$message =~ s/\xFD/\xFC\x7D/g;
#		$message =~ s/\xFE/\xFC\x7E/g;
	}

	return $start . $message;
}

sub unescapeMessage($) {
	my ($message) = @_;

	if ($message) {
		$message =~ s/\xFC\x7C/\xFC/g;
		$message =~ s/\xFC\x7D/\xFD/g;
#		$message =~ s/\xFC\x7E/\xFE/g;
	}
	
	return $message
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

sub setCtrlTxNum     ($$) {return ((0b11111001 & $_[0]) | ($_[1] << 1));}
sub setCtrlRxNum     ($$) {return ((0b10011111 & $_[0]) | ($_[1] << 5));}



################################################################################

sub getHmwIdAndChNrFromHash($) {
	my ($hash) = @_;
	
	my $hmwId = $hash->{DEF};
	my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
	
	return ($hmwId, $chNr); 
}
1;
