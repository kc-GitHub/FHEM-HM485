=head1
	Util.pm
	
=head1 SYNOPSIS
	Helper module for HomeMatic Wired (HM485) for FHEM
	contributed by Dirk Hoffmann 2012 - 2013
	               Thorsten Pferdekaemper 2014 - today  
	$Id$

=head1 DESCRIPTION
	Some helper functions for HomeMatic Wired (HM485) support for FHEM

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
	   AUTHOR - Thorsten Pferdekaemper
=cut

package HM485::Util;

use strict;
use warnings;
use Data::Dumper;
use POSIX;

###############################################################################
# Define prototypes
###############################################################################

sub getHashKeyBySubkey($$$);

my $Version = '0.5.136';
sub HM485_Log($);
my $Zeit = strftime( "%Y-%m-%d\x5f%H-%M-%S", localtime);
my $LogOffen = undef;


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


# Read an entry from an Array of Hashes where Id = $2
sub getArrayEntryWithId($$){
    my ($array,$id) = @_;
	foreach my $entry (@{$array}) {
	    next unless(ref($entry) eq "HASH"); 
		next unless(defined($entry->{id}));
	    return $entry if($entry->{id} eq $id);
	}
	return undef;
};


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
					$logTxt.= 'DISCOVERY(' . ctrlDiscoveryMask($dataHash->{cb}) . ') 00000000';
					$logTxt.= ' -> ' . printByte($dataHash->{target}, $formatHex);
				} else {
					$txt = '';
				}
			} else {
				my $ctrlTxt = '';
				$ctrlTxt.= ' I[' . ctrlTxNum($dataHash->{cb}) . ']' if (ctrlIsIframe($dataHash->{cb}));
				$ctrlTxt.= 'ACK'                                   if (ctrlIsAck($dataHash->{cb}));
				$ctrlTxt.= '(' . ctrlAckNum($dataHash->{cb});

				if (ctrlIsIframe($dataHash->{cb})) {
					$ctrlTxt.= ctrlSynSet($dataHash->{cb})   ? ',Y' : '';
					$ctrlTxt.= ctrlFinalSet($dataHash->{cb}) ? ',F' : '';
				}
				$ctrlTxt.= (ctrlHasSender($dataHash->{cb})   ? ',B' : '') . ')';
				
				$logTxt.= $ctrlTxt . '(' . sprintf('%02X', $dataHash->{cb}) . ')';
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

sub debugBinData($$$;$$) {
	my ($logtag, $level, $msg, $prefix, $logMask) = @_;
	$prefix  = $prefix ? $prefix . ': ' : '';
	$logMask = $logMask ? $logMask : 1;

	my $hexMsg = '';

	if ($logMask & 0b01) {
		$hexMsg = uc( unpack ('H*', $msg) );
	} else {
		$hexMsg = '';
	}

	if ($logMask & 0b10) {
		$msg =~ s/^.*CRLF//g;
		if ($logMask & 0b01) {
			$msg = ' (' . $msg . ')';
		}
	} else {
		$msg = '';
	}

	HM485::Util::logger($logtag, $level, $prefix . $hexMsg . $msg);	
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

sub getHmwIdAndChNrFromHash($) {
	my ($hash) = @_;
	
	my $hmwId = $hash->{DEF};
	my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : 0;
	
	return ($hmwId, $chNr); 
}

sub getHashKeyBySubkey($$$) {
	my ($hash, $type, $value) = @_;
	my $retVal = undef;

	foreach my $key (keys %{$hash}) {
		if (defined($hash->{$key}{$type} && $hash->{$key}{$type} eq $value)) {
			$retVal = $key;
			last;
		}
	}

	return $retVal;
}

sub convertIdToHash($) {
	my ($configSettings) = @_;
	
	my $ConvertHash = {};
	my $id = $configSettings->{'id'};

	if ($id) {
			$ConvertHash->{$id} = $configSettings;
			#delete $ConvertHash->{$id}{'id'}; wenn ich die id lösche gehts nimmer Warum?
	}
	return $ConvertHash;
}


sub HM485_Log($){
	my ( $LogText) = @_;
	my $ZeitStr = strftime( "%Y-%m-%d\x5f%H:%M:%S", localtime);
	my $LogName = "$main::attr{global}{modpath}/log/HM485-log" . $Zeit . ".log";	
	if ( $LogOffen) {
#		print Datei "$ZeitStr $LogText\n";
	} else {
#		open( Datei, ">$LogName") || die "Datei nicht gefunden\n";    # Datei zum Schreiben oeffnen
#		Datei->autoflush(1);
		$LogOffen = "offen";
#		print Datei "aktuelle Version ist jetzt $Version\n";
#		print Datei "$ZeitStr $LogText\n";
	}
}

# Make Log3 a bit simpler
sub Log3($$$){
  my ($hash,$level,$text) = @_;
  my $name = defined($hash->{NAME}) ? $hash->{NAME} : 'HM485';
  main::Log3($hash,$level,$name.': '.$text);
}


# Function queue handling
# queues data structure
# Each queue has a priority
# For each priority, there can be multiple queues
# if this is the case, elements are processed round robin
# prioQueues: 
#    HASH { priority -> 
#           queues:
#              ARRAY ( HASH { function,
#                             arguments } )
# add: function, arguments, priority

 use List::Util qw(min);
 use Scalar::Util qw(looks_like_number);

  my %prioQueues;
  my $queueRunning = 0;

  use Sub::Identify qw(sub_name); 
  
 sub PQprocess($) {

 	my $start = main::gettimeofday();
	my $dauer = 0;
	while(1){
		my $prio = min(keys %prioQueues);
		my $toCall = shift(@{$prioQueues{$prio}});
		delete $prioQueues{$prio} unless @{$prioQueues{$prio}};
		&{$toCall->{function}}(@{$toCall->{arguments}});
		$dauer = (main::gettimeofday() - $start) * 1000;
	# if(sub_name($toCall->{function}) eq "HM485_Set") {
		# Log3(undef,3,"PQprocess: ".sub_name($toCall->{function})." ".$toCall->{arguments}[1]);
	# }else{
		# Log3(undef,3,"PQprocess: ".sub_name($toCall->{function})." ".$dauer);
	#};
	# allow to process very fast stuff together
		last unless($dauer < 5 and %prioQueues);
	};	
	
	if(%prioQueues) {
		main::InternalTimer(main::gettimeofday(),\&PQprocess,"HM485::PrioQueue");
	}else{
		$queueRunning = 0;
	};	
 };

 
# add entry to PrioQueues
 sub PQadd($$;$) {
    my ($function, $arguments, $nice) = @_;
	$nice =   0 if(not defined($nice) or  not looks_like_number($nice));
    $nice = -20 if($nice <-20);
    $nice =  19 if($nice > 19);

	$prioQueues{$nice} = [] unless defined $prioQueues{$nice};
	push(@{$prioQueues{$nice}},{"function" => $function, "arguments" => $arguments});

	# start timer if not anyway running
	if(not $queueRunning) {
		main::InternalTimer(main::gettimeofday(),\&PQprocess,"HM485::PrioQueue");
		$queueRunning = 1;
	};	
 };


 # TODO:
# The following PrioQueue implementation uses the PrioQueue mechanism of fhem.pl
# However, this does currently not work with apptime. Once this is fixed, the
# PrioQueue implementation from above should be replaced by the below.
#sub PQadd ($$;$) {
#    my ($func, $params, $niceness) = @_;
#	main::PrioQueue_add(sub {&{${$_[0]}[0]}(@{${$_[0]}[1]})}, [$func, $params], $niceness);
#};


1; 
