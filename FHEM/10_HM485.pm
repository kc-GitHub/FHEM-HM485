=head1
	10_HM485.pm

# $Id: 10_HM485.pm 0801 2017-05-17 22:00:00Z ThorstenPferdekaemper $	
	
	Version 0.8.01
				 
=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013
	               Thorsten Pferdekaemper (afterwards)

=head1 DESCRIPTION
	10_HM485 handle individual HomeMatic Wired (HM485) devices via the
	00_HM485_LAN interface

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
=cut

package main;

use strict;
use warnings;
use Data::Dumper;    # for debugging only

use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin");

use lib::HM485::Constants;
use lib::HM485::Device;
use lib::HM485::Util;
use lib::HM485::ConfigurationManager;
use lib::HM485::PeeringManager;
#use lib::HM485::Command;

use Scalar::Util qw(looks_like_number);

use vars qw {%attr %defs %modules %data $FW_ME};

# Function prototypes

# FHEM Interface related functions
sub HM485_Initialize($);
sub HM485_Define($$);
sub HM485_Undefine($$);
sub HM485_Rename($$);
sub HM485_WaitForConfig($);
sub HM485_WaitForConfigCond($);
sub HM485_GetAutoReadConfig($);
sub HM485_GetConfigReadRetries($);
sub HM485_Parse($$);
sub HM485_Set($@);
sub HM485_Get($@);
sub HM485_Attr($$$$);
sub HM485_FhemwebShowConfig($$$);

# Device related functions
sub HM485_GetInfos($$$;$);  #PFE last parameter
sub HM485_GetConfig($$);
sub HM485_CreateChannels($);
sub HM485_SetConfig($@);
sub HM485_SetSettings($@);
sub HM485_SetFrequency($@);
sub HM485_SetKeyEvent($$);
sub HM485_SetChannelState($$$);
sub HM485_ValidateSettings($$$);
sub HM485_SetWebCmd($;$);
sub HM485_GetHashByHmwid ($);

#Communication related functions
sub HM485_ProcessResponse($$$);
sub HM485_SetStateNack($$);
sub HM485_SetStateAck($$$);
sub HM485_SetAttributeFromResponse($$$);
sub HM485_ProcessEvent($$);
sub HM485_CheckForAutocreate($$;$$);
sub HM485_SendCommand($$$;$);
#sub HM485_SendCommandState($);
sub HM485_DoSendCommand($);
sub HM485_ProcessChannelState($$$$;$);
sub HM485_ChannelUpdate($$$);
sub HM485_ChannelDoUpdate($);
sub HM485_ProcessEepromData($$$);

# External helper functions
sub HM485_DevStateIcon($);

#Message queues
sub HM485_GetNewMsgQueue($$$$$);
sub HM485_QueueStepFailed($$);
sub HM485_QueueStepSuccess($$);


# Default get commands for device
my %getsDev = (
	'config'  => 'noArg'
);

# Default get commands for channel
my %getsCh = ('state' => 'noArg',
              'config' => 'noArg');

my $defStart = 5;

# List of "message queues" for e.g. reading config 
my @msgQueueList = ();
my $currentQueueIndex = -1; #index of current queue


# Helper function to set a single reading asynchronously
# It seems that it only works properly like this
sub HM485_ReadingUpdate($$$) {
	my ($hash, $name, $value) = @_;
	
    if($name){  # do it later
		InternalTimer(gettimeofday(),'HM485_ReadingUpdate',[$hash,$name, $value],0);
	}else{	# this is the "later" call
	    ($hash, $name, $value) = @$hash;
		readingsSingleUpdate($hash, $name, $value, 1);
	}
}



###############################################################################
# Interface related functions
###############################################################################

=head2
	Implements Initialize function
	
	@param	hash	hash of device addressed
=cut
sub HM485_Initialize($) {
	my ($hash) = @_;

	my $initResult = HM485::Device::init();
	HM485::Util::Log3($hash, 1, $initResult) if ($initResult);
	
	$hash->{'Match'}          = '^FD.*';
	$hash->{'DefFn'}          = 'HM485_Define';
	$hash->{'UndefFn'}        = 'HM485_Undefine';
	$hash->{'RenameFn'}       = 'HM485_Rename';
	$hash->{'ParseFn'}        = 'HM485_Parse';
	$hash->{'SetFn'}          = 'HM485_Set';
	$hash->{'GetFn'}          = 'HM485_Get';
	
	# For FHEMWEB
	$hash->{'FW_detailFn'}    = 'HM485_FhemwebShowConfig';
	# The following line means that the overview is shown
	# as header, even though there is a FW_detailFn
	$hash->{'FW_deviceOverview'} = 1;
	$data{'webCmdFn'}{'textField'}  = "HM485_FrequencyFormField";

	my $attrlist = 'autoReadConfig:atstartup,always,never '. 
							  'configReadRetries '.	
							  'do_not_notify:0,1 ' .
	                          'ignore:1,0 dummy:1,0 showtime:1,0 ' .
	                          'stateFormat setList ' .
	                          'event-min-interval event-aggregator IODev ' .
	                          'event-on-change-reading event-on-update-reading';

	$hash->{'AttrList'}  =	$attrlist.' model subType firmwareVersion serialNr ';   
	                                       # deprecated, but to avoid error messages
	# remove deprecated attributes after init
    InternalTimer(gettimeofday(), sub {$hash->{'AttrList'} = $attrlist}, $hash, 0);	
}

=head2
	Implements DefFn function
	
	@param	hash    hash of device addressed
	@param	string  definition string
	
	@return string | undef
=cut
sub HM485_Define($$) {
	my ($hash, $def) = @_;

	my @a      = split('[ \t][ \t]*', $def);
	my $hmwId  = uc($a[2]);

	my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
	my $addr   = substr($hmwId, 0, 8);

	RemoveInternalTimer($hash);  
	return 'wrong syntax: define <name> HM485 <8-digit-hex-code>[_<2-digit-hex-code>] [<IO-Device>]'
	     if (int(@a)!=3 && int(@a)!=4 || (defined($a[2]) && $a[2] !~ m/^[A-F0-9]{8}_{0,1}[A-F0-9]{0,2}$/i)); 
    return 'Device ' . $hmwId . ' already defined.'
	     if ($modules{'HM485'}{'defptr'}{$hmwId}); 
	
	my $name = $hash->{'NAME'};
	if ($chNr) {
		# We defined a channel of a device
		my $devHash = $modules{'HM485'}{'defptr'}{$addr};
		return 'Define the main device ' . $addr . ' before define the device channel'
		    unless($devHash);
	    # when creating a new channel, the cache needs to be deleted
		# because it contains channel specific information
    	delete $devHash->{cache};
		my $devName = $devHash->{'NAME'};
		$devHash->{'channel_' .  $chNr} = $name;
		$hash->{device}    = $devName;                  # reference this channel to the device entity
		$hash->{devHash} = $devHash;
		$hash->{chanNo}    = $chNr;						# reference the device to this channel
	} else {
		# We defined the device
		# if there is an IODevice in the define, we can directly assign it
		# otherwise, we can assume that this is done later via attribute IODev
	    # In this case, it is better to do it after init
		if($a[3]) {
		    AssignIoPort($hash, $a[3]); 
		    HM485::Util::Log3($hash->{IODev}, 2, 'Assigned '.$addr.' as '.$name);
		}else{
            InternalTimer(gettimeofday(), 'AssignIoPort',$hash,0);
        }			
	}
	$modules{'HM485'}{'defptr'}{$hmwId} = $hash;
	$hash->{'DEF'} = $hmwId;
	# get peer role for channels (the routine checks whether it is a channel
	HM485::PeeringManager::getPeerRole($hash);
	if (length($hmwId) == 8) {
		HM485_ReadingUpdate($hash, 'configStatus', 'PENDING');
        # We can always use WaitForConfig. It will do it's job eventually in any case.	
		$hash->{FailedConfigReads} = 0;
		InternalTimer (gettimeofday(), 'HM485_WaitForConfigCond', $hash, 0);
	}
	# delete deprecated attributes
	InternalTimer(gettimeofday(), 
	      sub { delete($attr{$name}{model}); 
		        delete($attr{$name}{subType}); 
				delete($attr{$name}{firmwareVersion}); 
				delete($attr{$name}{serialNr});
		  }, $hash, 0);
	return undef;
}

=head2
	Implements the undefine function
	
	@param	hash	hash of device addressed
	@param	string	name of device

	@return	undef
=cut
sub HM485_Undefine($$) {
	my ($hash, undef) = @_;

	my ($hmwid, $chnr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	
	if ($chnr > 0 ){  
		# this is a channel, delete it from the device
		delete $hash->{devHash}{'channel_' . $chnr};
	} else {
		# Delete each channel of device
		foreach my $devName (grep(/^channel_/, keys %{$hash})) {
			CommandDelete(undef, $hash->{$devName})
		} 
	}
	delete($modules{HM485}{defptr}{$hmwid});
	return undef;
}

=head2
	Implements the rename function
	
	@param	string	name of device
	@param	string	old name of device
=cut
sub HM485_Rename($$) {
	my ($name, $oldName) = @_;

	my $hash           = $defs{$name};
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	if ($chNr > 0){
		# we are channel, inform the device
		my $devHash = $hash->{devHash};
		$hash->{device} = $devHash->{NAME};
		$devHash->{'channel_' . $chNr} = $name;
	} else{
		# we are a device - inform channels if exist
		foreach my $devName ( grep(/^channel_/, keys %{$hash})) {
			my $chnHash = $defs{ $hash->{$devName}};
			$chnHash->{device} = $name;
		} 
	}
}


# Conditional wait for config, depending on
# attribute autoReadConfig
# Own function to enable start with timer
sub HM485_WaitForConfigCond($) {
	my ($hash) = @_;
	if(HM485_GetAutoReadConfig($hash) ne 'never') {
		HM485_WaitForConfig($hash);	
	};	
}


sub HM485_WaitForConfig($) {
	my ($hash) = @_;
	
	# not if issue with device files
	return if($HM485::Device::deviceFilesOutdated);
	
	my $hmwId = $hash->{DEF};
	
	if (defined($hash->{'IODev'}) and defined($hash->{'IODev'}{'STATE'}) 
	           and $hash->{'IODev'}{'STATE'} eq 'opened') {
		if ( $hmwId) {
		    # Tell them that we are reading config
		    HM485_SetConfigStatus($hash, 'READING');
			# the queue definition below will start GetConfig after successful GetInfos
			my $queue = HM485_GetNewMsgQueue($hash->{'IODev'}, 'HM485_GetConfig',[$hash,$hmwId],
			                                 'HM485_SetConfigStatus',[$hash,'FAILED']);
			HM485_GetInfos($hash, $hmwId, 0b111, $queue);
			HM485::Util::Log3($hash->{'IODev'}, 3, 'Initialisierung von Modul ' . $hmwId);
		}
	} else {
		HM485::Util::Log3($hash->{'IODev'}, 3, 'Warte auf Initialisierung Gateway');
		InternalTimer (gettimeofday() + $defStart, 'HM485_WaitForConfig', $hash, 0);
	}
}


=head2
	Implements the parse function
	
	@param	hash	the hash of the IO device
	@param	string	message to parse
=cut
sub HM485_Parse($$) {
	my ($ioHash, $message) = @_;
	my $msgId   = ord(substr($message, 2, 1));
	HM485::Util::Log3($ioHash, 5, 'HM485_Parse: MsgId: '.$msgId);
	my $msgCmd  = ord(substr($message, 3, 1));
	my $msgData = uc( unpack ('H*', substr($message, 4)));

	if ($msgCmd == HM485::CMD_RESPONSE) {
		HM485_SetStateAck($ioHash, $msgId, $msgData);
		HM485::Util::Log3($ioHash, 5, 'HM485_Parse: ProcessResponse');
		HM485_ProcessResponse($ioHash, $msgId, substr($msgData,2));
	} elsif ($msgCmd == HM485::CMD_EVENT) {
	    # if the central is the target address, then this is an implicit ACK
		HM485_SetStateAck($ioHash, $msgId, $msgData) if(substr($msgData,0,8) eq $ioHash->{hmwId});
    	HM485::Util::Log3($ioHash, 5, 'HM485_Parse: ProcessEvent');
		HM485_ProcessEvent($ioHash, $msgData);
	} elsif ($msgCmd == HM485::CMD_ALIVE && substr($msgData, 0, 2) eq '01') {
	    # Stop queue if running
	    HM485_QueueStepFailed($ioHash, $msgId);
		HM485_SetStateNack($ioHash, $msgData);
	}
	
	return $ioHash->{NAME};
}


# Toggle is special
sub HM485_SetToggle($) {
	my ($hash) = @_;
	# Toggle seems to be a bit special.
	# Channels where state/conversion/true = 200 scheinen 
	# ein direktes Toggeln zu koennen
	# andere (vielleicht nur HMW_IO12_SW14_DR) koennen das nicht
	
	# get the value hash
	my ($valueKey, $valueHash) = HM485_GetValueHash($hash, 'toggle');
	if(!$valueKey || !$valueHash) { return 'no toggle for this channel' };
	
	my $control    = $valueHash->{'control'} ? $valueHash->{'control'} : '';	
	# nur devices mit control "switch.state" koennen toggle
	if($control ne 'switch.state') {
		return 'no toggle for this channel';
	}
	my $frameValue;
	if(defined($valueHash->{conversion}{true}) && $valueHash->{conversion}{true} == 200) {
		$frameValue = 0xFF;
		HM485_ReadingUpdate($hash, 'state', 'set_toggle');
	} else {
		# dieses Device braucht etwas Hilfe
	    my $state = 'on';
		if(defined($hash->{READINGS}{'state'}{VAL})) {
			$state = $hash->{READINGS}{'state'}{VAL};
		};			
		my $newState;
		if($state eq 'on' || $state eq 'set_on') {
			$newState = 'off';
		}else{
			$newState = 'on';
		}	
		HM485_ReadingUpdate($hash, 'state', 'set_'.$newState);
		$frameValue = HM485::Device::onOffToState($valueHash, $newState);
	}

	my $frameData->{$valueKey} = {
		value    => $frameValue,
		physical => $valueHash->{'physical'}
	};
			
	my $frameType = $valueHash->{'physical'}{'set'}{'request'};
	my $data      = HM485::Device::buildFrame($hash, $frameType, $frameData);
	HM485_SendCommand($hash, $hash->{DEF}, $data) if length $data;

	return '';			
				
}


=head2
	Implements the SetFn
	
	@param	hash	the hash of the IO device
	@param	array	set parameter array
=cut
sub HM485_Set($@) {
	my ($hash, @params) = @_;
	my $name  = $params[0];

	return '"set ' . $name . '" needs one or more parameter' unless(@params >= 2);
	
	my $cmd   = $params[1];
	my $value = $params[2];
	
	# Default set commands for device
	my %sets = ();
    my $devHash;  
	my $isChannel;
    if(defined($hash->{devHash})) {
	    $devHash = $hash->{devHash};
		$isChannel = 1;
		my $allowedSets = HM485::Device::getAllowedSets($hash);
		if ($allowedSets) {
			foreach my $setValue (split(' ', $allowedSets)) {
				my($setValue, $param) = split(':', $setValue);
				$sets{$setValue} = $param;
			}
		}
	}else{
        $devHash = $hash;
        %sets = ('reset' => 'noArg',
             'getConfig' => 'noArg',
                   'raw' => '' );
		$isChannel = 0;
    };		
	
	# first handle stuff which should be "fast"
	# i.e. not config or so
	if($isChannel && defined($sets{$cmd})) {
		if ($cmd eq 'press_long' || $cmd eq 'press_short') {
			my $counter = $hash->{'READINGS'}{'sim_counter'}{'VAL'} ?
						  $hash->{'READINGS'}{'sim_counter'}{'VAL'} : 0;
			HM485_ReadingUpdate($hash, 'state', $cmd .' '.$counter);
			return (HM485_SetKeyEvent($hash, $cmd),1);
		} elsif ( $cmd eq 'on-for-timer') {
			if ( $value && $value > 0) {
				# remove any internal timer, which switches the channel off
				my $offcommand = 'set ' . $name . ' off';
				RemoveInternalTimer($offcommand);
				# switch channel on	
				my $msg = HM485_SetChannelState($hash, 'on', $value);
				return ($msg,1) if($msg);
				HM485::Util::Log3($hash, 5, 'set ' . $name . ' on-for-timer ' . $value);
				# set internal timer to switch channel off
				InternalTimer( gettimeofday() + $value, 'fhem', $offcommand, 0 );
				return ('',1);
			} else {
				return (HM485_SetChannelState($hash, 'off', $value),1);
			}
		} elsif ($cmd eq 'toggle') {
			# toggle is a bit special
			return (HM485_SetToggle($hash),1);
		# "else" includes level, stop, on, off
		} else {  
			my $state = 'set_'.$cmd;
			if($value) { $state .= '_'.$value; }
			HM485_ReadingUpdate($hash, 'state', $state);
			return (HM485_SetChannelState($hash, $cmd, $value),1);
		}
	};
	
	# now stuff which should always work for devices (not channels)
	if(!$isChannel && defined($sets{$cmd})) {
		if ($cmd eq 'reset') {
			return (HM485_SetReset($hash, $cmd),1);
	    }elsif ($cmd eq 'getConfig') {
		    # get module config (eeprom data)
		    # This triggers a manual config read
		    # i.e. old errors don't matter
		    $hash->{FailedConfigReads} = 0;
		    HM485_WaitForConfig($hash);
			return ('',1);
		}elsif ($cmd eq 'raw') {
			HM485_SendCommand($hash, $hash->{DEF}, $value);
			return ('',1);
		};	
	};
	
	# for channels and devices
    if($devHash->{READINGS}{configStatus}{VAL} eq 'OK') {
	    if ($cmd eq 'config') {
		    return (HM485_SetConfig($hash, @params),1);
		};	
		# config command would be possible
		$sets{'config'} = '';
	};

    # now we only have peer, unpeer and peeringdetails left
	# this is "allowed" to be a bit more expensive
	if($isChannel) {
	    # unpeer, peeringdetails or sth unknown
	    if($cmd ne "peer") {
		    my $peered = HM485::PeeringManager::getPeeredChannels($hash);
		    if (@{$peered}) {
			    $sets{unpeer} = join(",", @{$peered});
			    $sets{peeringdetails} = 0;
		    };
		};
		# peer or something unknown
		if($cmd ne "unpeer" and $cmd ne "peeringdetails") {
			my $peerable = HM485::PeeringManager::getPeerableChannels($hash);
		    if (@{$peerable}) {
			    $sets{peer} = join(",", @{$peerable});
		    };
		};
	    if(defined($sets{$cmd})){
			if ($cmd eq 'peer') {
			    return (HM485_SetPeer($hash, @params),1);
		    } elsif ($cmd eq 'unpeer') {
			    return (HM485_SetUnpeer($hash, @params),1);
		    } elsif ($cmd eq 'peeringdetails') {
			    return (HM485_SetPeeringDetails($hash, @params),1);			
            };
		};
	};
	
	# if we reach here, it is either "?" or total rubbish
	my $arguments = ' ';
	foreach my $arg (sort keys %sets) {
		$arguments.= $arg . ($sets{$arg} ? (':' . $sets{$arg}) : '') . ' ';
	}
	return 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;
}


sub HM485_ConfigVar2Json($);  # wegen Rekursion

sub HM485_ConfigVar2Json($){
    my ($var) = @_;
	my $result = "";
	return "\"\"" if(!defined($var)); 
	if(ref($var) eq "HASH") {
		$result = '{';
	    my $afterfirst = 0;
	    foreach my $key (sort keys %{$var}) {
	        if($afterfirst) {
		        $result .= ',';
		    }else{
                $afterfirst = 1;
            };			
	        $result .= "\n";
	        $result .= '"'.$key.'":';
			if($key eq "possibleValues") {
		        $result .= " [ ";
	            for(my $i = 0; $i < int(@{$var->{$key}}); $i++) {
		            $result .= "," if($i > 0);
			        $result .= HM485_ConfigVar2Json($var->{$key}[$i]{id});	
                };
		        $result .= " ] ";
			}else{
			    $result .= HM485_ConfigVar2Json($var->{$key});
			};	
	    };
	    $result .= "\n}";
	}elsif(ref($var) eq "ARRAY") {
		$result .= " [ ";
	    for(my $i = 0; $i < int(@{$var}); $i++) {
		    $result .= "," if($i > 0);
			$result .= HM485_ConfigVar2Json($var->[$i]);	
        };
		$result .= " ] ";
    }else{	
	    $result .= '"'.$var.'"';
	};	
    return $result;
};


# FindPeering
# params: hash, peername
# finds peering between devices
# if allowbroken, then some issues are tolerated 
# returns a hash:
#   sensor => hash of sensor
#   actuator => hash of actuator
#   sensorPeerid => peerid in sensor device
#   actuatorPeerid => peerid in actuator device
# in case of errors, an error text is returned
# if allowbroken, then some parts of the returned hash might be undef
sub HM485_FindPeering($$){
    my ($hash, $peername, $allowbroken) = @_;
	my %retVal;
    # Both devices need to be channels and defined in FHEM
	return "Get Peering Details: ".$hash->{NAME}." must be a channel" unless(defined($hash->{devHash}));
	my $peerhash = $main::defs{$peername};
	return $peername." not found. (It must be a HM485 channel)" 
	                                  unless(defined($peerhash) and $peerhash->{TYPE} eq 'HM485');
	return $peerhash->{NAME}." must be a channel" unless(defined($peerhash->{devHash}));
	# Both devices need to be ready to be configured
	return "Device ".$hash->{devHash}{NAME}." not completely loadad. Try again later."
	                   unless($hash->{devHash}{READINGS}{configStatus}{VAL} eq 'OK');
	return "Device ".$peerhash->{devHash}{NAME}." not completely loadad. Try again later."
	                   unless($peerhash->{devHash}{READINGS}{configStatus}{VAL} eq 'OK');
    # now one needs to be a sensor and one an actuator
    my $peerrole = HM485::PeeringManager::getPeerRole($hash);
    return $hash->{NAME}." does not allow peerings" if($peerrole eq "none"); 
    $retVal{$peerrole} = $hash;
    $peerrole = HM485::PeeringManager::getPeerRole($peerhash);
    return $peerhash->{NAME}." does not allow peerings" if($peerrole eq "none"); 
    $retVal{$peerrole} = $peerhash;
	return "Peering ".$hash->{NAME}.", ".$peerhash->{NAME}.": Needs exactly one sensor and one actuator" unless(defined($retVal{sensor}) and defined($retVal{actuator}));
	
	# Now we have a channel hash in $sensor and one in $actuator
	# Try to find the channels in each other's peerings
    $retVal{sensorPeerid} = HM485::PeeringManager::getPeerId ($retVal{sensor}{devHash}, $retVal{actuator}{DEF}, $retVal{sensor}{chanNo}, 1); 
	return $retVal{actuator}{NAME}." is not peered with ".$retVal{sensor}{NAME} unless(defined($retVal{sensorPeerid}));
    $retVal{actuatorPeerid} = HM485::PeeringManager::getPeerId ($retVal{actuator}{devHash}, $retVal{sensor}{DEF}, $retVal{actuator}{chanNo}, 0); 
	return $retVal{sensor}{NAME}." is not peered with ".$retVal{actuator}{NAME} unless(defined($retVal{actuatorPeerid}));
	
	return \%retVal;
}



# GetPeeringDetails
# Ermittelt zu einem Sensor- und einem Aktorkanal, die miteinander
# gepeert sind die zugehörigen Settings 
# Bei Erfolg wird ein hash zurückgeliefert, ansonsten ein Text
sub HM485_GetPeeringDetails($$) {
    my ($hash, $peername) = @_;
	my $peering = HM485_FindPeering($hash,$peername);
    # error?
	return $peering unless(ref($peering) eq "HASH");
    # prepare retval
	my $retVal = { sensorname => $peering->{sensor}{NAME},
	               actuatorname => $peering->{actuator}{NAME},
				   sensorconfig => [],
				   actuatorconfig => [] };
				   
	my $linkParams	= HM485::PeeringManager::getLinkParams($peering->{sensor}{devHash});
	if(ref($linkParams->{actuator}) eq 'HASH') {
	    my $adrStart = $linkParams->{actuator}{address_start} +
		        ($peering->{sensorPeerid} * $linkParams->{actuator}{address_step});
	    my $parameter = $linkParams->{actuator}{parameter};
        for(my $i = 0; $i < @{$parameter}; $i++) {	
		    my $settingHash = HM485::ConfigurationManager::writeConfigParameter($peering->{sensor}{devHash},
				    $parameter->[$i], $adrStart, $linkParams->{actuator}{address_step});
		    next unless($settingHash);
            $settingHash->{id} = $parameter->[$i]{id};		
		    push(@{$retVal->{sensorconfig}}, $settingHash);
	    };
    };

	$linkParams	= HM485::PeeringManager::getLinkParams($peering->{actuator}{devHash});
	if(ref($linkParams->{sensor}) eq 'HASH'){
	    my $adrStart = $linkParams->{sensor}{address_start} +
		        ($peering->{actuatorPeerid} * $linkParams->{sensor}{address_step});
	    my $parameter = $linkParams->{sensor}{parameter};
        for(my $i = 0; $i < @{$parameter}; $i++) {	
		    my $settingHash = HM485::ConfigurationManager::writeConfigParameter($peering->{actuator}{devHash},
			    	$parameter->[$i], $adrStart, $linkParams->{sensor}{address_step});
		    next unless($settingHash);
            $settingHash->{id} = $parameter->[$i]{id};		
		    push(@{$retVal->{actuatorconfig}}, $settingHash);
	    }
    }
	return $retVal;
}


# Check whether the device EEPROM is completely loaded
sub HM485_GetCheckCompletelyLoadad($){
    my ($hash) = @_;
	# do we have a valid config?
	my $devHash = (defined($hash->{devHash}) ? $hash->{devHash} : $hash);
	return undef if($devHash->{READINGS}{configStatus}{VAL} eq 'OK');
    return { ".message" =>
			    { "value" => "Device not completely loaded yet. Try again later.",
			      "input" => 0,
				  "type" => "text" } };			
};


=head2
	Implements getFn
	
	@param	hash    hash of device addressed
	@param	string	name of device
	@param	string	old name of device
=cut
sub HM485_Get($@) {
	my ($hash, @params) = @_;

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	my $name = $params[0];
	my $cmd  = $params[1];
	my $args = $params[2] ? $params[2] : "";
	my %gets = $chNr > 0 ? %getsCh : %getsDev;
	my $msg  = '';
	my $data = '';
	
	my $peered;
    if($chNr){	
		$gets{'peerlist'} = 'noArg';
		$peered = HM485::PeeringManager::getPeeredChannels($hash);
		if (@{$peered}) {
			$gets{'peeringdetails'} = join(",", @{$peered});
		};
	}
	
	if (@params < 2) {
		$msg =  '"get ' . $name . '" needs one or more parameter';

	} else {
		if(!defined($gets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %gets) {
				$arguments.= $arg . ($gets{$arg} ? (':' . $gets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;
		} elsif ($cmd eq 'config') {
		    # do we have a valid config?
			my $config = HM485_GetCheckCompletelyLoadad($hash);
            if(!$config) { # i.e. no error message
		        $config = HM485::ConfigurationManager::getConfigFromDevice($hash, $chNr);
			};			
		    $msg = HM485_ConfigVar2Json($config);
		} elsif ($cmd eq 'peeringdetails') {
		    my $details = HM485_GetPeeringDetails($hash,$args);
			if(ref($details) eq 'HASH') {
			    $msg = HM485_ConfigVar2Json($details);
			}else{
			    $msg = HM485_ConfigVar2Json({ ".message" =>
			    { "value" => $details,
			      "input" => 0,
				  "type" => "text" } });			
			};       
		} elsif ($cmd eq 'state') {
			# abfragen des aktuellen Status
			$data = sprintf ('53%02X', $chNr-1);  # Channel als hex- Wert
			HM485_SendCommand( $hash, $hmwId, $data);
		} elsif ($cmd eq 'peerlist') {
		    # do we have a valid config?
			my $peerings = HM485_GetCheckCompletelyLoadad($hash);
            if(!$peerings) { # i.e. no error message
                $peerings = $peered;
            };
			$msg = HM485_ConfigVar2Json($peerings);
		}
	}

	return $msg;
}


=head2
	Implements FW_detailFn function.
	
	@param	string	name of FHEMWEB definition
	@param	string	device name in detail view
	@param	string	room name
=cut
sub HM485_FhemwebShowConfig($$$) {
	my ($fwName, $name, $roomName) = @_;
	my $hash = $defs{$name};
	
	# This all does not make sense if the device files are not ok
	if($HM485::Device::deviceFilesOutdated) {
	    return "<div style='color:red'>Device definition files could not be updated.<br>You cannot configure your devices and they will not work properly. Make sure that perl module XML::Simple is installed. Check the FHEM Logfile for HM485 messages for more details.</div>";
	};
	
	# get html to show config
	my $devHash = (defined($hash->{devHash}) ? $hash->{devHash} : $hash);
	my $configReady = ($devHash->{READINGS}{configStatus}{VAL} eq 'OK');
	
	# do we have anything peered with this one?
	# TODO: This is relatively expensive
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
    my $isChannel = $chNr ? "yes" : "no";
	# if this is a channel, does it have peerings?
	my $peerRole = "none";
	my $peered = "no";
	if($isChannel eq "yes") { # && HM485::PeeringManager::getPeerRole($hash) eq "actuator") {
	    $peerRole = HM485::PeeringManager::getPeerRole($hash);
		if($peerRole ne "none"){
			if($configReady) {
	            my $peeredChannels = HM485::PeeringManager::getPeeredChannels($hash);
	            if(@{$peeredChannels}) {
	                $peered = "yes";
		        };
			}else{
                # config not ready, so we assume peerings. An error message will come on click.
                $peered = "yes";				
            };			
        };			
	};
    # does this channel/device have config?
	my $hasConfig = 'no';
	if($configReady) {
        my $configArray = HM485::ConfigurationManager::getConfigFromDevice($hash, $chNr);
        foreach my $entry (@{$configArray}) {
            next if($entry->{hidden});
		    $hasConfig = 'yes';
		    last;
	    };
	}else{
        # see above...
		$hasConfig = "yes";
    };	
	
	return '<script type="text/javascript" src="/fhem/pgm2/hm485.js"></script>'.
	       '<div id="configArea" data-name="'.$name.'" data-hasconfig="'.$hasConfig.'" data-ischannel="'.$isChannel.'" data-peerrole="'.$peerRole.'" data-peered="'.$peered.'"></div>'. 
	'<script type="text/javascript">{ FW_HM485CloseConfigDialog();} </script>';
}


sub HM485_SetConfigStatus($$) {
	my ($hash, $status) = @_;
	HM485_ReadingUpdate($hash, 'configStatus', $status);
	if($status eq 'OK') {
		$hash->{FailedConfigReads} = 0;
		# trigger peerings re-read
		InternalTimer(gettimeofday(), "HM485::PeeringManager::getLinksFromDevice", $hash,0);
	};
	if($status eq 'FAILED') {
		my $maxReads = HM485_GetConfigReadRetries($hash);
		if(!defined($maxReads) || $maxReads > $hash->{FailedConfigReads} ) {
			$hash->{FailedConfigReads}++;
			InternalTimer( gettimeofday() + $defStart, 'HM485_WaitForConfig', $hash, 0);
		}
	}
}


=head2
	Get Infos from device depends on $infoMask
	bit 1 = 1 -> request module type
	bit 2 = 1 -> request serial number
	bit 2 = 1 -> request firmware version
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
	@param	int     binary bitmask denined wich infos was requestet from device 
=cut
sub HM485_GetInfos($$$;$) {
	my ($hash, $hmwId, $infoMask, $queue) = @_;
	if ( !$hmwId) {
		my @param = split(' ', $hash);
		$hash     = $param[0];
		$hmwId    = $param[1];
		$infoMask = $param[2];
	}
	# TODO: Clean up
	if(!$hmwId) {
	  $hash = ${$_[0]}[0];
	  $hmwId = ${$_[0]}[1];
	  $infoMask = ${$_[0]}[2];
	}
	
	$infoMask = defined($infoMask) ? $infoMask : 0;
	#if not started with a queue, then create an own one, but without callbacks
	$queue = defined($queue) ? $queue : HM485_GetNewMsgQueue($hash->{'IODev'}, undef,undef,undef,undef);
	
	if ($infoMask & 0b001) {
		# (h) request module type
		HM485_QueueCommand($queue, $hash, $hmwId, '68');
	}
	
	if ($infoMask & 0b010) {
		# (n) request serial number
		HM485_QueueCommand($queue, $hash, $hmwId, '6E');
	}
	
	if ($infoMask & 0b100) {
		# (v) request firmware version
		HM485_QueueCommand($queue, $hash, $hmwId, '76');
	}
	
	HM485_QueueStart($hash, $queue);
}


# UpdateConfigReadings updates the R-Readings determined from 
# device config (EEPROM)
sub HM485_UpdateConfigReadings($) {
	
	my ($hash) = @_;
	
	if(ref($hash) eq "ARRAY") {
		# This is a call from a timer (ACK of writing EEPROM)
		($hash, undef) = @$hash;
		# Remove timer-tag
		delete $hash->{".updateConfigReadingsTimer"};
	};
	
	HM485::Util::Log3($hash, 4, 'HM485_UpdateConfigReadings called');
	
	# always delete all R-Readings to support changes of the device file
	# and changes in "behaviour"
	foreach my $reading (grep(/^R\-/, keys %{$hash->{READINGS}})) {
	    delete $hash->{READINGS}{$reading};
	}
	
	my $configArray = HM485::ConfigurationManager::getConfigFromDevice($hash, 0);
	foreach my $entry (@{$configArray}) {
		next if($entry->{hidden} && $entry->{id} ne 'central_address');
		HM485_ReadingUpdate($hash, 'R-'.$entry->{id}, HM485::ConfigurationManager::convertValueToDisplay($entry->{id}, $entry));
	}
	foreach my $chName (grep(/^channel_/, keys %{$hash})) {
		my $cHash = $defs{$hash->{$chName}};		
		foreach my $cReading (grep(/^R\-/, keys %{$cHash->{READINGS}})) {
	        delete $cHash->{READINGS}{$cReading};
	    };
		# remove caching for peerRole
		delete $cHash->{peerRole};
		$configArray = HM485::ConfigurationManager::getConfigFromDevice($cHash, 0);
		foreach my $entry (@{$configArray}) {
			next if($entry->{hidden});
			HM485_ReadingUpdate($cHash, 'R-'.$entry->{id}, HM485::ConfigurationManager::convertValueToDisplay($entry->{id}, $entry));
		}
	}
}



=head2
	Request device config stoerd in the eeprom of a device
	ToDo: check model var and if we must clear eepromdata before 
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
=cut
#Last step of config, after reading of EEPROM
sub HM485_CreateAndReadChannels($$) {
	my ($devHash, $hmwId) = @_;
	
	# Wenn diese Funktion aufgerufen wird, dann wurden vorher die aktuellen
	# Daten vom EEPROM geholt, d.h. wir koennen Readings setzen, die davon
	# abhaengen
	my $configArray = HM485::ConfigurationManager::getConfigFromDevice($devHash, 0);
	my $cEntry = HM485::Util::getArrayEntryWithId($configArray,"central_address");
    # the generic device does not have a central_address
	if($cEntry && ref($cEntry) eq "HASH") {  
	    my $central_address = sprintf('%08X',$cEntry->{value});
        # if this is not the address of the IO-Device, try to change it
	    # TODO: This should probably be queued as well, but we cannot queue ACK-only commands
	    if($central_address ne $devHash->{IODev}{hmwId}){
		    HM485_SetConfig($devHash, (0,0,'central_address',hex($devHash->{IODev}{hmwId})));
	    };	
	};
	# Channels anlegen
	my $deviceKey = uc( HM485::Device::getDeviceKeyFromHash($devHash));
	HM485::Util::Log3($devHash, 4, 'Channels initialisieren ' . substr($hmwId, 0, 8));
	HM485_CreateChannels( $devHash);
	
	# Create R-Readings
	HM485_UpdateConfigReadings($devHash); 
	
	# State der Channels ermitteln
	my $configHash = HM485::Device::getValueFromDefinitions( $deviceKey . '/channels/');
	HM485::Util::Log3($devHash, 4, 'State der Channels ermitteln ' . substr($hmwId, 0, 8));
	#create a queue, so we can set the config status afterwards
	my $queue = HM485_GetNewMsgQueue($devHash->{'IODev'}, 'HM485_SetConfigStatus',[$devHash,'OK'],
			                         'HM485_SetConfigStatus',[$devHash,'FAILED']);
	foreach my $chType (keys %{$configHash}) {
		if ( $chType && $chType ne "key" && $chType ne "maintenance") {
			my $chStart = $configHash->{$chType}{index};
			my $chCount = $configHash->{$chType}{count};
			for ( my $ch = $chStart; $ch < $chStart + $chCount; $ch++){
				my $data = sprintf ('53%02X', $ch-1);  # Channel als hex- Wert
				HM485_QueueCommand( $queue, $devHash, $hmwId . '_' . $ch, $data);
			}
		}
	}
	HM485_QueueStart($devHash, $queue);
}


sub HM485_GetAutoReadConfig($) {
	my ($devHash) = @_; 
	my $autoReadConfig = AttrVal($devHash->{NAME},'autoReadConfig','');   # vom Device selbst
	if($autoReadConfig) { return $autoReadConfig };
	return AttrVal($devHash->{IODev}{NAME},'autoReadConfig','atstartup'); # vom IO-Device
}


sub HM485_GetConfigReadRetries($) {
	my ($devHash) = @_; 
	my $configReadRetries = AttrVal($devHash->{NAME},'configReadRetries', undef);   # vom Device selbst
	if(defined($configReadRetries)) { return $configReadRetries };
	return AttrVal($devHash->{IODev}{NAME},'configReadRetries', undef); # vom IO-Device
}


sub HM485_GetConfig($$) {
	my ($hash, $hmwId) = @_;
	if ( !$hmwId) {
		my @param = split(' ', $hash);
		$hash     = $param[0];
		$hmwId    = $param[1];
	}
	
	my $data;
	my $devHash = $modules{HM485}{defptr}{substr($hmwId,0,8)};

	# here we query eeprom data with device settings
	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
	if ($deviceKey) {
		HM485::Util::Log3($devHash, 3, 'Request config for device ' . substr($hmwId, 0, 8));
		my $eepromMap = HM485::Device::getEmptyEEpromMap($devHash);
		
		# write eeprom map to readings
		foreach my $adrStart (sort keys %{$eepromMap}) {
			setReadingsVal($devHash, '.eeprom_' . $adrStart, $eepromMap->{$adrStart}, TimeNow());
		}
		
		# TODO: Es sieht so aus als ob zumindest manche Geraete ihre eigenen Defaults nicht 
		#       kennen. Vielleicht sollte die Zentrale automatisch Default-Werte ins EEPROM
		#       schreiben, wenn dort 0xFF steht.
		HM485::Util::Log3($devHash, 3, 'Lese Eeprom ' . substr($hmwId, 0, 8));
		
		# Tell them that we are reading config
		HM485_SetConfigStatus($hash, 'READING');
		#Get a new queue for reading the EEPROM
		#This definition will automatically start reading the channels after EEPROM reading
		#is successful
		my $queue = HM485_GetNewMsgQueue($devHash->{'IODev'}, 'HM485_CreateAndReadChannels',[$devHash,$hmwId],
				                         'HM485_SetConfigStatus',[$hash,'FAILED']);
		
		foreach my $adrStart (sort keys %{$eepromMap}) {
			# (R) request eeprom data
			HM485_QueueCommand($queue, $devHash, $hmwId, '52' . $adrStart . '10'); 
		}
		# start the queue, create and read channels afterwards.
		HM485_QueueStart($hash, $queue);		
	#	delete( $devHash->{'.Reconfig'});
	} else {
		HM485::Util::Log3($devHash, 3, 'Initialisierungsfehler ' . substr( $hmwId, 0, 8) . ' DeviceKey noch nicht vorhanden');
		HM485_WaitForConfig($devHash);
	}
}


=head2
	Create all channels of a device
	
	@param	hash    hash of device addressed
	@param	string  hex value of hardware type
=cut
sub HM485_CreateChannels($) {
	my ($hash, $hwType) = @_;


	my $name  = $hash->{NAME};
	my $hmwId = $hash->{DEF};

	# get related subdevices for this device from config
	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);

	my $subTypes = HM485::Device::getValueFromDefinitions($deviceKey . '/channels/');
	
	return if (ref($subTypes) ne 'HASH');
	foreach my $subType (sort keys %{$subTypes}) {
		if ( $subType && uc( $subType) ne 'MAINTENANCE') {
			if ( defined($subTypes->{$subType}{count}) && $subTypes->{$subType}{count} > 0) {
				my $chStart = $subTypes->{$subType}{index};
				my $chCount = $subTypes->{$subType}{count};
				for(my $ch = $chStart; $ch < ($chStart + $chCount); $ch++) {
					my $txtCh = sprintf ('%02d' , $ch);
					my $room = AttrVal($name, 'room', '');
					my $devName = $name . '_' . $txtCh;
					my $chHmwId = $hmwId . '_' . $txtCh;
						
					if (!$modules{HM485}{defptr}{$chHmwId}) {
						CommandDefine(undef, $devName . ' ' . ' HM485 ' . $chHmwId); # HM485_Define wird aufgerufen
					} else {
						# Channel- Name aus define wird gesucht, um weitere Attr zuzuweisen
						my $devHash = $modules{HM485}{defptr}{$chHmwId};
						$devName    = $devHash->{NAME};
					};
					# sub type in reading schreiben
					HM485_ReadingUpdate($modules{HM485}{defptr}{$chHmwId}, "D-subType", $subType);				
					if($subType eq 'blind') {
						# Blinds go up and down by default (but only by default)
						my $val = AttrVal($devName, 'webCmd', undef);
						if(!defined($val)){
							CommandAttr(undef, $devName . ' webCmd up:down');
						};
					}
					# copy room if there is no room yet
					# this is mainly for proper autocreate
					if(defined($room) && $room) {
						my $croom = AttrVal($devName, 'room', undef);
						if(!$croom) {
							CommandAttr(undef, $devName . ' room ' . $room);
						}
					}
				} 
			}
		}
	}
}


sub HM485_SetReset($@) {
	my ($hash, @values) =@_;
	
	my $value = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
	my $emtyMap = HM485::Device::getEmptyEEpromMap($hash);
	
	foreach my $adr (keys %{$emtyMap}) {
    	HM485_SendCommand($hash, $hash->{'DEF'}, '57' . $adr . 10 . $value);
	}
	
	HM485_SendCommand($hash, $hash->{'DEF'}, '43');
}


sub HM485_SetPeer($@) {
	my ($hash, @values) = @_;
	
	shift(@values);
	shift(@values);

	my $peerable	 = HM485::PeeringManager::getPeerableChannels($hash);
	
	return 'set peer argument "' . $values[0] . '" must be one of ' . join(', ', $peerable->[0],$peerable->[1],$peerable->[2],'...') unless (@values == 1 && grep {$_ eq $values[0]} @{$peerable});

	# get the hash of the other side
	my $otherHash = $main::defs{$values[0]};
    return "Device ".$values[0]." does not exist" unless($otherHash);
	# find out which is the sensor and which is the actor
	my $ownRole = HM485::PeeringManager::getPeerRole($hash);
	return $hash->{NAME}." cannot be peered" if($ownRole eq "none");
	my $sensorHash = $ownRole eq "sensor" ? $hash : $otherHash;
	my $actuatorHash = $ownRole eq "actuator" ? $hash : $otherHash;
	
	my $peering;			
	$peering->{'act'}{'channel'} 	= $sensorHash->{chanNo} - 1;
	$peering->{'act'}{'actuator'} 	= $actuatorHash->{devHash}{DEF};
	$peering->{'act'}{'sensor'} 	= $sensorHash->{devHash}{DEF};
	$peering->{'sen'}{'channel'} 	= $actuatorHash->{chanNo} -1;
	$peering->{'sen'}{'actuator'} 	= $actuatorHash->{devHash}{DEF};
	$peering->{'sen'}{'sensor'} 	= $sensorHash->{devHash}{DEF};
	
	my $actParams = HM485::PeeringManager::getLinkParams($sensorHash->{devHash});
	my $senParams = HM485::PeeringManager::getLinkParams($actuatorHash->{devHash});
	my $freeAct   = HM485::PeeringManager::getFreePeerId($sensorHash->{devHash},'actuator');
	my $freeSen   = HM485::PeeringManager::getFreePeerId($actuatorHash->{devHash},'sensor');
		
	return 'set peer ' . $values[0] .' no free PeerId found' if (!defined($freeAct) || !defined($freeSen));
		
	my $configTypeHash;
	my $validatedConfig;
    my $msg;
	foreach my $act (@{$actParams->{actuator}{parameter}}) {
		$msg = HM485_ValidateSettings($act, $act->{id}, $peering->{'act'}{$act->{id}});
		return $msg if($msg);
		$validatedConfig->{actuator}{$act->{id}}{value} = $peering->{act}{$act->{id}};
		$validatedConfig->{actuator}{$act->{id}}{config} = $act;
		if ($act->{id} eq 'actuator') {
			$validatedConfig->{actuator}{actuator}{chan} = $peering->{sen}{channel};
		}
		$validatedConfig->{actuator}{$act->{id}}{peerId} = $freeAct;
	}
	foreach my $sen (@{$senParams->{sensor}{parameter}}) {			
	    # only EEPROM
		next if(ref($sen->{physical}) eq "HASH" && $sen->{physical}{interface} ne "eeprom");
		# load default values 
		if (!defined($peering->{sen}{$sen->{id}})) {
			$peering->{sen}{$sen->{id}} = HM485::PeeringManager::loadDefaultPeerSettings($sen);
		}
		$msg = HM485_ValidateSettings($sen, $sen->{id}, $peering->{'sen'}{$sen->{id}});
        return $msg if($msg);			
		$validatedConfig->{sensor}{$sen->{id}}{value} = $peering->{sen}{$sen->{id}};
		$validatedConfig->{sensor}{$sen->{id}}{config} = $sen;
		if ($sen->{id} eq 'sensor') {
			$validatedConfig->{sensor}{sensor}{chan} = $peering->{act}{channel};
		}
		$validatedConfig->{sensor}{$sen->{id}}{peerId} = $freeSen;
	}

	my $convSenSettings = HM485::PeeringManager::convertPeeringsToEepromData(
				$actuatorHash, $validatedConfig->{sensor}, "sensor");
	my $convActSettings = HM485::PeeringManager::convertPeeringsToEepromData(
				$sensorHash, $validatedConfig->{actuator}, "actuator");
	foreach my $adr (sort keys %$convActSettings) {
		HM485::Util::Log3($hash, 4,	'Set peersetting: ' . $convActSettings->{$adr}{'text'});
		my $size  = $convActSettings->{$adr}{'size'} ? $convActSettings->{$adr}{'size'} : 1;
		my $value = $convActSettings->{$adr}{'value'};
		if ($convActSettings->{$adr}{'le'}) {
			if ($size >= 1) {
				$value = sprintf ('%0' . ($size*2) . 'X' , $value);
				$value = reverse( pack('H*', $value) );
				$value = hex(unpack('H*', $value));
			}
		}
		$size = sprintf ('%02X' , $size);
		if (index($convActSettings->{$adr}{'text'}, 'actuator') > -1) {
			$value .= sprintf ('%02X', $peering->{'sen'}{'channel'});
		} else {
			$value = sprintf ('%0' . ($size * 2) . 'X', $value);
		}
		$adr = sprintf ('%04X' , $adr);
		HM485::Device::internalUpdateEEpromData($sensorHash->{devHash},$adr . $size . $value);		
		HM485_SendCommand($sensorHash, $sensorHash->{DEF}, '57' . $adr . $size . $value);
	}
	
	foreach my $adr (sort keys %$convSenSettings) {
		HM485::Util::Log3($actuatorHash, 4,'Set peersetting: ' . $convSenSettings->{$adr}{'text'});
		my $size  = $convSenSettings->{$adr}{'size'} ? $convSenSettings->{$adr}{'size'} : 1;
		my $value = $convSenSettings->{$adr}{'value'};
		if ($convSenSettings->{$adr}{'le'}) {
			if ($size >= 1) {
				$value = sprintf ('%0' . ($size*2) . 'X' , $value);
				$value = reverse( pack('H*', $value) );
				$value = hex(unpack('H*', $value));
			}
		}
		$size     = sprintf ('%02X' , $size);
		if (index($convSenSettings->{$adr}{'text'}, 'sensor') > -1) {
			#don't convert the address add the channel
			$value .= sprintf ('%02X', $peering->{'act'}{'channel'});
		} else {
			$value = sprintf ('%0' . ($size * 2) . 'X', $value);
		}
		$adr = sprintf ('%04X' , $adr);
		HM485::Device::internalUpdateEEpromData($actuatorHash->{devHash},$adr . $size . $value);
		HM485_SendCommand($actuatorHash, $actuatorHash->{DEF}, '57' . $adr . $size . $value);
	}
	#todo verify the correct sending, then send 0x43
	HM485_SendCommand($sensorHash, $sensorHash->{DEF}, '43');
	HM485_SendCommand($actuatorHash, $actuatorHash->{DEF}, '43');
	return '';
}


sub HM485_SetUnpeer($@) {
	my ($hash, @values) = @_;
	
	shift(@values);
	shift(@values);
	
	my $peered	 = HM485::PeeringManager::getPeeredChannels($hash);
	my $msg = '';
	
	if (@values == 1 && grep {$_ eq $values[0]} @{$peered}) {
		
		my ($senHmwId, $senCh) = HM485::Util::getHmwIdAndChNrFromHash($hash);
		my $actHmwId 	   	   = HM485::PeeringManager::getHmwIdByDevName($values[0]);
        my $fromAct = (HM485::PeeringManager::getPeerRole($hash) eq "actuator") ? 1 : 0;		
		$msg = HM485::PeeringManager::sendUnpeer($senHmwId, $actHmwId, $fromAct);
	} else {
		$msg = 'set unpeer argument "' . $values[0] . '" must be one of ' . join(',', @{$peered});
	}
	return $msg;
}


sub HM485_SetConfig($@) {
	my ($hash, @values) = @_;

	my $name = $hash->{NAME};
	shift(@values);
	shift(@values);

	# print(Dumper(@values));
	
	my $msg = '';
	my ($hmwId1, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash        = $hash->{devHash};

	if (@values <= 1) {
		return "set config needs at least two parameters";
	};	
	# Split list of configurations
	my $cc = 0;
	my $configType;
	my $setConfigHash = {};
	foreach my $value (@values) {
		$cc++;
		if ($cc % 2) {
			$configType = $value;
		} else {
			if ($configType) {
				$setConfigHash->{$configType} = $value;
				$configType = undef;
			}
		}
	}
	
	#here we validate the config settings 
	my $validatedConfig = {};
	my $configHash = {};
	if (! scalar (keys %{$setConfigHash})) {
		return "";
	};	
	$configHash = HM485::ConfigurationManager::getConfigSettings($hash);
	my $configArray = $configHash->{parameter};
	# print(Dumper($configHash));
	for(my $i = 0; $i < @{$configArray}; $i++) {
	    # is this parameter in the values to set?
		my $setConfig = $configArray->[$i]{id};
	    next unless exists($setConfigHash->{$setConfig});
		my $configTypeHash = $configArray->[$i];	# hash von behaviour
		$msg = HM485_ValidateSettings(
			$configTypeHash, $setConfig, $setConfigHash->{$setConfig}
		);
		HM485::Util::Log3( $hash, 4, 'HM485_SetConfig: name = ' . $name . ' Key = ' . $setConfig . ' Wert = ' . $setConfigHash->{$setConfig} . ' msg = ' . $msg);
		# Fehler? ...und tschuess
		if($msg) {
			return $msg;
		};
		$validatedConfig->{$setConfig}{value} = $setConfigHash->{$setConfig};	# Wert
		$validatedConfig->{$setConfig}{config} = $configTypeHash;  	# hash von behaviour
		$validatedConfig->{$setConfig}{valueName} = $setConfig;
	}
		
	# print Dumper($validatedConfig);	
		
	# If validation success
	# set R-readings to "set-<new value>"
	# TODO: The following (update of R-readings)should be an own routine
	# TODO: Performance
	foreach my $cKey (keys %{$validatedConfig}) {
		my $config = HM485::ConfigurationManager::convertSettingsToDataFormat($validatedConfig->{$cKey}{config});
		next if($config->{hidden} && $cKey ne 'central_address');
		$config->{value} = $validatedConfig->{$cKey}{value};
		my $setValue = "set-".HM485::ConfigurationManager::convertValueToDisplay($cKey, $config);
		HM485_ReadingUpdate($hash, 'R-'.$cKey, $setValue);
	}


	my $convertetSettings = HM485::ConfigurationManager::convertSettingsToEepromData(
		$hash, $validatedConfig
	);
	if (! scalar (keys %{$convertetSettings})) {
		return;
	};	
 	my $hmwId = $hash->{DEF};
			
	foreach my $adr (keys %{$convertetSettings}) {
		HM485::Util::Log3($hash, 3,	'Set config ' . $name . ': ' . $convertetSettings->{$adr}{text});

		my $size  = $convertetSettings->{$adr}{size} ? $convertetSettings->{$adr}{size} : 1;
		$size     = sprintf ('%02X' , $size);
	
		my $value = $convertetSettings->{$adr}{value};
		$value    = sprintf ('%0' . ($size * 2) . 'X', $value);
		$adr      = sprintf ('%04X' , $adr);

		HM485::Util::Log3($hash, 5, 'HM485_SetConfig fuer ' . $name . ' Schreiben Eeprom ' . $hmwId . ' 57 ' . $adr . ' ' . $size . ' ' . $value);
		# Write data to EEPROM			
		HM485_SendCommand($hash, $hmwId, '57' . $adr . $size . $value);   
	}
	# Send "reread config" to device (this is not always working, but this is the best we can do)
	HM485_SendCommand($hash, $hmwId, '43');                             
				
	my $channelBehaviour = HM485::Device::getChannelBehaviour($hash);
	# TODO: Sollten die Readings nicht nur dann geloescht werden, wenn sich
	#       das "Behaviour" aendert?
	if ( defined( $channelBehaviour) && $channelBehaviour) {
		if ( defined( ReadingsVal( $name, 'state', undef))) {
			fhem( "deletereading $name state");
		} elsif ( defined( ReadingsVal( $name, 'press_short', undef))) {
			fhem( "deletereading $name press_short");
		} elsif ( defined( ReadingsVal( $name, 'press_long', undef))) {
			fhem( "deletereading $name press_long");
		} elsif ( defined( ReadingsVal( $name, 'value', undef))) {
			fhem( "deletereading $name value");
		} else {
			# kein reading zu loeschen
		}
		# Zustand des Kanals nachlesen		
		my $data = sprintf ('53%02X', $chNr-1);
		InternalTimer( gettimeofday() + 1, 'HM485_SendCommand', $hash . ' ' . $hmwId . ' ' . $data, 0);
	}
	
	# if we reach this, everything should be ok	
	return "";
}


# SetPeeringDetails
# 
sub HM485_SetPeeringDetails($@) {
	my ($hash, @values) = @_;
		
	shift(@values); # name
	shift(@values); # command
    my $peername = shift(@values);
	# get sensor, actuator and peerIds
	my $peering = HM485_FindPeering($hash,$peername);
	# error?
	return $peering unless(ref($peering) eq "HASH");
	
	my $msg = '';
	
	return "set peeringdetails needs at least 3 parameters" if (@values < 2);
	
	# Split list of configurations
	my $setSettingsHash = {};
	for(my $i = 0; $i < @values; $i += 2) {
	    return "set peeringdetails needs an odd number of parameters" unless(defined($values[$i+1]));
		$setSettingsHash->{$values[$i]} = $values[$i+1];
	}
	my $params = HM485::PeeringManager::getLinkParams($peering->{actuator}{devHash});
	my $validatedConfig = {};
	for my $entry (@{$params->{sensor}{parameter}}){
	    my $param = $entry->{id};
		next unless exists($setSettingsHash->{$param});
		$setSettingsHash->{$param} = HM485::PeeringManager::valueToSettings($entry,$setSettingsHash->{$param});
		#validate settings
		$msg = HM485_ValidateSettings ($entry,	$param, $setSettingsHash->{$param});
		return $msg if($msg);
		$validatedConfig->{$param}{value} = $setSettingsHash->{$param};
		$validatedConfig->{$param}{config} = $entry;
	}
	# If validation success
	$validatedConfig->{channel}{peerId} = $peering->{actuatorPeerid};
	$validatedConfig->{channel}{id} = 'peer';
	$validatedConfig->{channel}{value} = $peering->{actuatorPeerid};;
	my $convertetSettings = HM485::PeeringManager::convertPeeringsToEepromData(
				$peering->{actuator}, $validatedConfig, "sensor");
	foreach my $adr (sort keys %$convertetSettings) {
		next unless($adr);
		HM485::Util::Log3($peering->{actuator}, 4, 'Set peerdetails: ' . $convertetSettings->{$adr}{'text'});
		my $size  = $convertetSettings->{$adr}{'size'} ? $convertetSettings->{$adr}{'size'} : 1;
		my $value = $convertetSettings->{$adr}{'value'};
		if ($convertetSettings->{$adr}{'le'}) {
			if ($size >= 1) {
				$value = sprintf ('%0' . ($size*2) . 'X' , $value);
				$value = reverse( pack('H*', $value) );
				$value = hex(unpack('H*', $value));
			}
		}
		$size     = sprintf ('%02X' , $size);
		$value 	  = sprintf ('%0' . ($size * 2) . 'X', $value);
		$adr 	  = sprintf ('%04X' , $adr);
		HM485_SendCommand($peering->{actuator}, $peering->{actuator}{'DEF'}, '57' . $adr . $size . $value);
	}
	HM485_SendCommand($peering->{actuator}, $peering->{actuator}{'DEF'}, '43');
	#update peerings
	delete $hash->{'peerings'};
	return $msg;
}


sub HM485_GetValueHash($$) {
	my ($hash, $cmd) = @_;
	

	my ($hmwId, $chNr)    		= HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash           		= $main::modules{'HM485'}{'defptr'}{substr($hmwId,0,8)};
	my $deviceKey         		= HM485::Device::getDeviceKeyFromHash($devHash);
	my $chType            		= HM485::Device::getChannelType($deviceKey, $chNr);
	my ($behaviour,$bool,$role) = HM485::Device::getChannelBehaviour($hash);
	
	if ($role && $role eq 'switch') {
		$behaviour = $role .'_ch';
	}
	
	my $valuePrafix       		= $bool ? '/subconfig/paramset/hmw_'. $behaviour. 
		'_values/parameter' : '/paramset/values/parameter/';
	my $values            		= HM485::Device::getValueFromDefinitions(
		$deviceKey . '/channels/' . $chType . $valuePrafix
	);
	
	# The command is either directly listed as parameter (level, state, frequency, stop,...)
	# or it is on,off,toggle
	my $entry = HM485::Util::getArrayEntryWithId($values,$cmd);
	return ($entry->{id},$entry) if($entry); 
	if(index('on:off:toggle:up:down', $cmd) != -1) {
		# in this case use state, level or frequency
		foreach $entry (@{$values}) {
			next unless($entry->{id} eq 'state' || $entry->{id} eq 'level' || $entry->{id} eq 'frequency');
	        return ($entry->{id},$entry) if($entry); 
		}
	}
    return undef;
}


sub HM485_SetChannelState($$$) {
	my ($hash, $cmd, $value) = @_;
	
	my $retVal            		= '';
	my $frameData;
	my ($hmwId, $chNr)    		= HM485::Util::getHmwIdAndChNrFromHash($hash);
	my ($valueKey, $valueHash) = HM485_GetValueHash($hash, $cmd);
	if(!$valueKey || !$valueHash) { return $retVal; }
		
	my $control    = $valueHash->{'control'} ? $valueHash->{'control'} : '';
	my $frameValue = undef;
	
	if (index('on:off:up:down', $cmd) != -1) {
		if ($control eq 'switch.state' || $control eq 'blind.level' ||
			$control eq 'dimmer.level' || $control eq 'valve.level') {
			$frameValue = HM485::Device::onOffToState($valueHash, $cmd);
		} else {
			$retVal = 'no on / off for this channel';
		}
	} else {
		$frameValue = HM485::Device::valueToState(
			$valueHash, $value);
	}

	$frameData->{$valueKey} = {
		value    => $frameValue,
		physical => $valueHash->{'physical'}
	};
			
	my $frameType = $valueHash->{'physical'}{'set'}{'request'};
	my $data      = HM485::Device::buildFrame($hash, $frameType, $frameData);
	HM485_SendCommand($hash, $hmwId, $data) if length $data;

	return $retVal;
}


sub HM485_SetKeyEvent($$) {
	my ($hash, $cmd) = @_;
	
	my $retVal            		= '';
	my $frameData;
	my ($hmwId, $chNr)    		= HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash           		= $main::modules{'HM485'}{'defptr'}{substr($hmwId,0,8)};
	my $deviceKey         		= HM485::Device::getDeviceKeyFromHash($devHash);
	my $chType            		= HM485::Device::getChannelType($deviceKey, $chNr);
	my ($behaviour,$bool,$role) = HM485::Device::getChannelBehaviour($hash);
	my $Logging		= 'off';
	my $LoggingTime = 2;
	
	if ($role && $role eq 'switch') {
		$behaviour = $role .'_ch';
	}
	
	my $valuePrafix       		= $bool ? '/subconfig/paramset/hmw_'. $behaviour. 
		'_values/parameter' : '/paramset/values/parameter/';
	my $values            		= HM485::Device::getValueFromDefinitions(
		$deviceKey . '/channels/' . $chType . $valuePrafix
	);

	for my $valueHash (@{$values}){
		next unless($valueHash->{id} eq 'press_short'  || $valueHash->{id} eq 'press_long');
		my $control    = $valueHash->{control} ? $valueHash->{control} : '';
		my $frameValue = undef;
		my $peerHash;
		next unless(($cmd eq 'press_short' && $control eq 'button.short') || ($cmd eq 'press_long' && $control eq 'button.long')); 
		#we need the last counter from the readings
		my $lastCounter = $hash->{READINGS}{sim_counter}{VAL};
		$frameValue = HM485::Device::simCounter($valueHash, $cmd, $lastCounter);
		$frameData->{$valueHash->{id}} = {
			value    => $frameValue,
			physical => $valueHash->{physical}
		};
		my $frameType  = $valueHash->{physical}{set}{request};
		next unless(($frameType eq 'key_sim_short' && $cmd eq 'press_short') || 
						($frameType eq 'key_sim_long'  && $cmd eq 'press_long'));
		$peerHash = HM485::PeeringManager::getLinksFromDevice($devHash);
		return "no peering for this channel" unless($peerHash->{actuators});
		foreach my $peerId (keys %{$peerHash->{'actuators'}}) {
			if ($peerHash->{'actuators'}{$peerId}{'actuator'}  && $peerHash->{'actuators'}{$peerId}{'channel'} eq $chNr) {
				my $data = HM485::Device::buildFrame($hash, 
								$frameType, $frameData, $peerHash->{'actuators'}{$peerId}{'actuator'});
				HM485_ReadingUpdate($hash, 'sim_counter', $frameValue);
				HM485::Util::Log3( $hash, 3, 'Send ' .$frameType. ': ' .$peerHash->{'actuators'}{$peerId}{'actuator'});
				HM485_SendCommand($hash,
								substr( $peerHash->{'actuators'}{$peerId}{'actuator'}, 0, 8),
								$data) if length $data;									
			}
		}
	}	
	return $retVal;
}


sub HM485_ValidateSettings($$$) {
	my ($configHash, $cmdSet, $value) = @_;
	my $msg = '';
	if (defined($value)) {
		my $logical = $configHash->{logical};
		# special values are always ok
		return $msg if(defined($logical->{special_value}) && $logical->{special_value}{id} eq $value);
		if ($logical->{type}) {
			if ($logical->{type} eq 'float' || $logical->{type} eq 'int') {
				if (HM485::Device::isNumber($value)) {
				    if (defined($logical->{min}) && defined($logical->{max})) {
						if ($value < $logical->{min}) {
							$msg = 'must be greater than or equal to ' . $logical->{min};
						} elsif ($value > $logical->{max}) {
							$msg = 'must be smaller than or equal to ' . $logical->{max};
						}
					}
				} else {
					$msg = 'must be a number';
				}

			} elsif ($logical->{type} eq 'boolean') {
				if ($value ne 0 && $value ne 1) {
					$msg = 'must be 1 or 0';
				}

			} elsif ($logical->{'type'} eq 'option') {
				my $optionValues = HM485::ConfigurationManager::optionsToList( $logical->{option});
				my $found = 0;
				#Todo option to Value
				my @Values = map {s/ //g; $_; } split(',', $optionValues);
				foreach my $val (@Values) {
					my ($item,$num) = split(':',$val);	
					if ($num eq $value) {
						$found = 1;
					}				
				}

				if ($found eq '0') {
					$msg = 'must be one of: ' . join(', ', $optionValues);					
				} 
			}
		}
		$msg = ($msg) ? $cmdSet . ' ' . $msg : '';
	} else {
		$msg = 'no value given for ' . $cmdSet;
	}
	
	return $msg;
} 

sub HM485_SetWebCmd($;$) {
	my ($hash, $model) = @_;
	#Todo model is not needed ?
	
	my $name 		= $hash->{'NAME'};
	my $webCmdList  = HM485::Device::getAllowedSets($hash);
	
	if ($webCmdList) {
		my @webCmds;
		my $stateFormat;
		my @Values = split(' ', $webCmdList);
		#todo activate press_long and press_short on peered channels only
		foreach my $val (@Values) {
			my ($cmd, $arg) = split(':',$val);
			if ($cmd ne 'inhibit' && $cmd ne 'install_test'  
			 && $cmd ne 'on'  && $cmd ne 'off') {
			 	push (@webCmds, $cmd);
			}
			if ($cmd eq 'frequency') {
				$stateFormat = "frequency";
			}
		}
		
		if (@webCmds) {
			CommandAttr(undef, $name . ' webCmd ' . join(":",@webCmds)) 
				if (!AttrVal($name, 'webCmd', undef)
			);
			
		}
		if ($stateFormat) {
			CommandAttr(undef, $name . ' stateFormat '. $stateFormat);
			$hash->{'STATE'} = "???";
		}
	}
}


=head2
	Returns the hash by HMW id
	
	@param	string  the HMW id of hash which sould returned
=cut
sub HM485_GetHashByHmwid ($) {
	my ($hmwId) = @_;
	
	my $retVal;
	if ($modules{HM485}{defptr}{$hmwId}) {
		$retVal = $modules{HM485}{defptr}{$hmwId}
	} else {
		$retVal = $modules{HM485}{defptr}{substr($hmwId,0,8)}
	}
	
	return $retVal;
}

###############################################################################
# Communication related functions
###############################################################################

=head2
	Parse a response frame depends on the $requestType
	
	@param	hash    the hash of the io device
	@param	int     the message id
	@param	int     1 if the respose was acked, 0 if we got a nack
	@param	string  the message data
	
=cut
sub HM485_ProcessResponse($$$) {
	my ($ioHash, $msgId, $msgData) = @_;
	my $data = '';
	
	HM485::Util::Log3( $ioHash,  5, 'HM485_ProcessResponse: msgData = ' . $msgData);
	
	if ($ioHash->{'.waitForResponse'}{$msgId}{hmwId}) {
		my $requestType = $ioHash->{'.waitForResponse'}{$msgId}{requestType};
		my $hmwId       = $ioHash->{'.waitForResponse'}{$msgId}{hmwId};
		my $requestData = $ioHash->{'.waitForResponse'}{$msgId}{requestData};
		my $hash        = $modules{HM485}{defptr}{$hmwId};
		my $chHash		= undef;
		my $Logging		= 'off';
		my $chNr 		= $msgData ? substr( $msgData, 2, 2) : undef;
		my $deviceKey	= '';
		my $LoggingTime = 2;
		
		# Check if main device exists or we need create it
		if ( $hash->{DEF} && $hash->{DEF} eq $hmwId) {
			$deviceKey 	= uc( HM485::Device::getDeviceKeyFromHash($hash));
			if ($requestType ne '52') { 
				HM485::Util::Log3( $ioHash, 5, 'HM485_ProcessResponse: deviceKey = ' . $deviceKey . ' requestType = ' . $requestType . ' requestData = ' . $requestData . ' msgData = ' . $msgData);
			}
            # special handling for 0x73 and ACK instead of proper response
            # we assume that the device has a matching "INFO_LEVEL" message
            # this is at least true for the known devices
            if(!$msgData and $requestType eq "73" and length($requestData) > 2) {
				HM485_ProcessChannelState($hash, $hmwId, "69".$requestData, 'response');
				# this should not be in any queue, so just return
				delete ($ioHash->{'.waitForResponse'}{$msgId});
				return;
            };   			
			
			if (grep $_ ne $requestType, ('68', '6E', '76')) {
				if ( $deviceKey eq 'HMW_LC_BL1_DR' && ( defined( $msgData) && $msgData)) {
					if ( $chNr lt "FF") {
						$chHash 	= HM485_GetHashByHmwid( $hmwId . '_' . sprintf( "%02d", $chNr+1));
						$Logging	= ReadingsVal( $chHash->{'NAME'}, 'R-logging', 'off');
						$LoggingTime = ReadingsVal( $hash->{'NAME'}, 'R-logging_time', 2);
					}
				}
			}
					
			if (grep $_ eq $requestType, ('53', '78')) {                # S (level_get), x (level_set) reports State
				if ( $deviceKey eq 'HMW_LC_BL1_DR') { # or $deviceKey eq 'HMW_LC_DIM1L_DR') {
					if ( $Logging eq 'on') {
						if ( $msgData && $msgData ne '') {
							my $bewegung = substr( $msgData, 6, 2);  		# Fuer Rolloaktor 10 = hoch, 20 = runter, 00 = Stillstand 
							$data = '5302';									# Channel 03 Level abfragen
							my %params = (hash => $hash, hmwId => $hmwId, data => $data);
							if ( $bewegung ne '00') {
								# kontinuierliche Levelabfrage starten, wenn sich Rollo bewegt, 
								# es nicht ganz zu ist (und nicht ganz geöffnet ist)			
								InternalTimer(gettimeofday() + $LoggingTime, 'HM485_SendCommand', $hash . ' ' . $hmwId . ' ' . $data, 0); 
							}
						}
					}
				}
				
				HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');
				
			} elsif (grep $_ eq $requestType, ('4B', 'CB')) {       # K (Key), Ë (Key-sim) report State
				if ( $deviceKey eq 'HMW_LC_BL1_DR') {
					if ( $Logging eq 'on') {
						my $bewegung = substr( $msgData, 6, 2);  		# Fuer Rolloaktor 10 = hoch, 20 = runter, 00 = Stillstand 
						$data = '5302';									# Channel 03 Level abfragen
						my %params = (hash => $hash, hmwId => $hmwId, data => $data);
						if ( $bewegung ne '00') {
							InternalTimer(gettimeofday() + $LoggingTime, 'HM485_SendCommand', $hash . ' ' . $hmwId . ' ' . $data, 0);
						}
					}
				}
			
				HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');
			
			} elsif ($requestType eq '52') {                                # R (report Eeprom Data)
				HM485_ProcessEepromData($hash, $requestData, $msgData);

			} elsif (grep $_ eq $requestType, ('68', '6E', '76')) {         # h (module type), n (serial number), v (firmware version)
				HM485_SetAttributeFromResponse($hash, $requestType, $msgData);
	
#			} elsif ($requestType eq '70') {                                # p (report packet size, only in bootloader mode)

#			} elsif ($requestType eq '72') {                                # r (report firmwared data, only in bootloader mode)
			} elsif ($requestType eq '73') {                                # s ( Aktor setzen)
					HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');
			}

		} else {
		 	HM485_CheckForAutocreate($ioHash, $hmwId, $requestType, $msgData);
		}
		
		#Message queue processing
	    HM485_QueueStepSuccess($ioHash, $msgId);

	} elsif ($ioHash->{'.waitForAck'}{$msgId}{hmwId}) {
		my $requestType = $ioHash->{'.waitForAck'}{$msgId}{requestType};
		my $hmwId       = $ioHash->{'.waitForAck'}{$msgId}{hmwId};
		my $requestData = $ioHash->{'.waitForAck'}{$msgId}{requestData};
		my $hash        = $modules{HM485}{defptr}{$hmwId};

		if($hash->{DEF} eq $hmwId) {
			if ($requestType eq '57') {                                     # W (ACK written Eeprom Data)
				# ACK for write EEprom data
				my $devHash = HM485_GetHashByHmwid( substr( $hmwId, 0, 8));
				HM485::Device::internalUpdateEEpromData($devHash, $requestData);
				# Trigger to update R-readings, but only once in a second
				if(defined($devHash->{".updateConfigReadingsTimer"})) {
					RemoveInternalTimer($devHash->{".updateConfigReadingsTimer"});
				} else {
					$devHash->{".updateConfigReadingsTimer"} = [$hash, "UpdateConfigReadings"];
				}
				InternalTimer(gettimeofday() + 1,'HM485_UpdateConfigReadings',$devHash->{".updateConfigReadingsTimer"},0);
			}
		}
	}
	
	delete ($ioHash->{'.waitForAck'}{$msgId});
	delete ($ioHash->{'.waitForResponse'}{$msgId});
}

=head2
	Notify the device if we got a nack
	
	@param	hash    the hash of the device
	@param	string  the message data

=cut
sub HM485_SetStateNack($$) {
	my ($hash, $msgData) = @_;
	my $hmwId = substr( $msgData, 2, 8);	

	my $devHash = HM485_GetHashByHmwid($hmwId);
	
	my $txt = 'RESPONSE TIMEOUT';
	HM485_ReadingUpdate($devHash, 'state', $txt);

	HM485::Util::Log3($devHash, 3, $txt . ' for ' . $hmwId);
	
	# Config wird neu gelesen, wenn...
	#  - CONFIG_STATUS ist OK (d.h. wir versuchen nicht sowieso schon, die config zu lesen)
	#  - Attribut autoReadConfig ist auf "always"
	my $doIt = 0;
	if($devHash->{READINGS}{configStatus}{VAL} eq 'OK' && HM485_GetAutoReadConfig($devHash) eq 'always'){
		InternalTimer( gettimeofday() + $defStart, 'HM485_WaitForConfig', $devHash, 0);
	}
}

=head2
	Notify the device if we got a ack
	
	@param	hash    the hash of the io device
	@param	string  the message data
=cut
sub HM485_SetStateAck($$$) {
	my ($ioHash, $msgId, $msgData) = @_;

	my $hmwId = $ioHash->{'.waitForResponse'}{$msgId}{hmwId};
	if (!$hmwId) {
		if (length ($msgData) >= 25) {
			$hmwId = substr($msgData, 10,8);
		} elsif (length ($msgData) >= 10 ) {
			$hmwId = substr($msgData, 2,8);
		}		
	}
	
	if ($hmwId) {
		my $devHash = HM485_GetHashByHmwid($hmwId);
		if ($devHash->{NAME}) {
			HM485_ReadingUpdate($devHash, 'state', 'ACK');
		}
	}
}

=head2
	Parse spechial frames and store values to device attribute
	
	@param	hash    the hash of the device
	@param	string  the request type
	@param	string  the message data

=cut
sub HM485_SetAttributeFromResponse($$$) {
	my ($hash, $requestType, $msgData) = @_;

	my $attrVal = '';
	
	if ($requestType eq '68') {  # module type
	    $hash->{RawDeviceType} = hex(substr($msgData,0,2));
		delete($hash->{READINGS}{"D-deviceKey"});
	} elsif ($requestType eq '6E') {
		$attrVal = HM485::Device::parseSerialNumber($msgData);
		HM485_ReadingUpdate($hash,"D-serialNr",$attrVal) if($attrVal); 
	} elsif ($requestType eq '76') {
	    $hash->{RawFwVersion} = hex(substr($msgData,0,4));
		delete($hash->{READINGS}{"D-deviceKey"});
		$attrVal = HM485::Device::parseFirmwareVersion($msgData);
		HM485_ReadingUpdate($hash,"D-fwVersion",$attrVal) if($attrVal); 
	}
}

=head2
	Parse a event frame
	
	@param	hash    the hash of the io device
	@param	string  the message data
	
=cut
sub HM485_ProcessEvent($$) {
	my ($ioHash, $msgData) = @_;

	my $target = substr($msgData,0,8);
	my $hmwId = substr( $msgData, 10, 8);
	$msgData  = (length($msgData) > 17) ? substr($msgData, 18) : '';
	HM485::Util::Log3( $ioHash, 5, 'HM485_ProcessEvent: hmwId = ' . $hmwId . ' msgData = ' . $msgData);

	if ($msgData) {
		my $devHash = $modules{HM485}{defptr}{$hmwId};

		# Check if main device exists or we need create it
		if ( $devHash->{DEF} && $devHash->{DEF} eq $hmwId) {
			HM485_ProcessChannelState($devHash, $hmwId, $msgData, 'frame', $target);
			my $deviceKey = HM485::Device::getDeviceKeyFromHash($devHash);
			my $event = substr( $msgData, 0, 2);
			if ( $event eq '4B') {
				# Taster wurde gedrueckt 4B
				if ( uc( $deviceKey) eq 'HMW_LC_BL1_DR') { # or $deviceKey eq 'HMW_LC_DIM1L_DR') {
					my $data = '5302';
					#my %params = (hash => $devHash, hmwId => $hmwId, data => $data);
					# kontinuierliche Abfrage des Levels starten
					InternalTimer( gettimeofday() + 2, 'HM485_SendCommand', $devHash . ' ' . $hmwId . ' ' . $data, 0); 
				}
			}
		} else {
			HM485_CheckForAutocreate($ioHash, $hmwId);
		}
	}
}

=head2
	Request and collect data necessary for define a device
	(module type, serial number)
	
	After all data have collected the device was dispatched to autocreate
	via DoTrigger
	
	@param	hash    the hash of the io device
	@param	string  the HMW id
	@param	string  the request type
	@param	string  the message data
	
=cut
# TODO: Is this really good? Could cause multiple getConfig-Like things
sub HM485_CheckForAutocreate($$;$$) {
	my ($ioHash, $hmwId, $requestType, $msgData) = @_;
	
	my $logTxt = 'Device %s not defined yet. We need the %s for autocreate';

	if ($requestType && $msgData) {
		$ioHash->{'.forAutocreate'}{$hmwId}{$requestType} = $msgData;
	}

	if (!$ioHash->{'.forAutocreate'}{$hmwId}{'68'}) {
		HM485::Util::Log3($ioHash, 4, sprintf($logTxt , $hmwId, 'type'));
		HM485_GetInfos($ioHash, $hmwId, 0b001);
	} elsif (!$ioHash->{'.forAutocreate'}{$hmwId}{'6E'}) {
		HM485::Util::Log3($ioHash, 4, sprintf($logTxt , $hmwId, 'serial number'));
		HM485_GetInfos($ioHash, $hmwId, 0b010);
	} elsif (!$ioHash->{'.forAutocreate'}{$hmwId}{'76'}) {
		HM485::Util::Log3($ioHash, 4, sprintf($logTxt , $hmwId, 'firmware version'));
		HM485_GetInfos($ioHash, $hmwId, 0b100);

	} elsif ( $ioHash->{'.forAutocreate'}{$hmwId}{'68'} &&
	          $ioHash->{'.forAutocreate'}{$hmwId}{'6E'} &&
			  $ioHash->{'.forAutocreate'}{$hmwId}{'76'} ) {

		my $serialNr = HM485::Device::parseSerialNumber (
			$ioHash->{'.forAutocreate'}{$hmwId}{'6E'}
		);
		
	    my $rawFwVersion = hex(substr($ioHash->{'.forAutocreate'}{$hmwId}{'76'},0,4));
		my $modelType = $ioHash->{'.forAutocreate'}{$hmwId}{'68'};
		my $model     = HM485::Device::parseModuleType($modelType,$rawFwVersion);
		delete ($ioHash->{'.forAutocreate'});
	
		my $deviceName = '_' . $serialNr;
		$deviceName = ($model ne $modelType) ? $model . $deviceName : 'HMW_' . $model . $deviceName;
		DoTrigger("global",  'UNDEFINED ' . $deviceName . ' HM485 ' . $hmwId.' '.$ioHash->{NAME});
	}
}

=head2
	Dispatch a command for sending to device by InternalTimer
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
	@param	string  the data to send
=cut
sub HM485_SendCommand($$$;$) {
	my ($hash, $hmwId, $data, $queued) = @_;
	if ( !$hmwId) {
		my @param = split(' ', $hash);
		$hash     = $param[0];
		$hmwId    = $param[1];
		$data     = $param[2];
	}
	$hmwId = substr($hmwId, 0, 8);
			
	if ( $data && length( $data) > 1) {
		# on send need the hash of the main device
		my $devHash 	= $modules{HM485}{defptr}{$hmwId};
		if (!$devHash) {
			$devHash = {
				IODev => $hash,
				NAME  => '.tmp',
			};
		}
	
		my %params = (hash => $devHash, hmwId => $hmwId, data => $data, queued => $queued);
		InternalTimer(gettimeofday(), 'HM485_DoSendCommand', \%params, 0);
		HM485::Util::Log3( $devHash, 5, 'HM485_SendCommand: '.$data);
	}
} 

=head2
	Send a command to device
	
	@param	hash    parameter hash
=cut
sub HM485_DoSendCommand($) {
	my ($paramsHash) = @_;

	my $hmwId       = $paramsHash->{hmwId};
	my $data        = $paramsHash->{data};
	my $queued      = $paramsHash->{queued};
	my $requestType = substr( $data, 0, 2);  # z.B.: 53
	my $hash        = $paramsHash->{hash};
	my $ioHash      = $hash->{IODev};

	my %params      = (target => $hmwId, data   => $data);
	
	# send command to device and get the request id
	my $requestId = IOWrite($hash, HM485::CMD_SEND, \%params);

	HM485::Util::Log3( $hash,  5, 'HM485_DoSendCommand: hmwId = ' . $hmwId . ' data = ' . $data . ' requestId = ' . $requestId);
	
	# frame types which must return values
	my @validRequestTypes = ('4B', '52', '53', '68', '6E', '70', '72', '73', '76', '78', 'CB');

	# frame types which must be acked only
	my @waitForAckTypes   = ('21', '43', '57', '67', '6C');

	if ($requestId && grep $_ eq $requestType, @validRequestTypes) {
		$ioHash->{'.waitForResponse'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForResponse'}{$requestId}{hmwId}       = $hmwId;
		$ioHash->{'.waitForResponse'}{$requestId}{requestData} = substr($data, 2);

	} elsif ($requestId && grep $_ eq $requestType, @waitForAckTypes) {
		$ioHash->{'.waitForAck'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForAck'}{$requestId}{hmwId}       = $hmwId;
		$ioHash->{'.waitForAck'}{$requestId}{requestData} = substr($data, 2);
	}
	#Tell Queue system
	if($queued) {
		HM485_QueueSetRequestId($ioHash, $requestId);
	};
}

=head2
	Process channel state and dispatch a channel update
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
	@param	string  the message data
	@param	string  action type such us response, frame, ...
=cut
sub HM485_ProcessChannelState($$$$;$) {
	my ($hash, $hmwId, $msgData, $actionType, $target) = @_;

    # device and message ok?
	if(!$msgData) {
	  HM485::Util::Log3( $hash, 3, 'HM485_ProcessChannelState: hmwId = ' . $hmwId .' No message');
	  return;
	}
	if(!HM485::Device::getDeviceKeyFromHash($hash)) {	
	    $DB::single = 1;
        HM485::Util::Log3( $hash, 3, 'HM485_ProcessChannelState: hmwId = ' . $hmwId . ' No Device Key');
        return;
	};
	# parse frame data, this also knows whether there is a channel
	my $valueHash = HM485::Device::parseFrameData($hash, $msgData, $actionType);	# hash, 690E03FF, response
	# is there a channel?
	# (This could be an announce message, which does not have channels.)
	if(!defined($valueHash->{ch})) {
	  HM485::Util::Log3( $hash, 5, 'HM485_ProcessChannelState: hmwId = ' . $hmwId . ' No channel');
	  return;
	}
								 
	HM485::Util::Log3($hash, 5, 'HM485_ProcessChannelState: hmwId = ' . $hmwId . ' Channel = ' . $valueHash->{ch} . ' msgData = ' . $msgData . ' actionType = ' . $actionType);
	my $chHash = HM485_GetHashByHmwid($hash->{DEF} . '_' . $valueHash->{ch});
	HM485_ChannelUpdate( $chHash, $valueHash->{value},$target);
}


=head2
	Dispatch channel update by InternalTimer
	
	@param	hash    hash of the channel
	@param	hash    parameter hash	
=cut
sub HM485_ChannelUpdate($$$) {
	my ($chHash, $valueHash, $target) = @_;
	my $name = $chHash->{NAME};

	if ($valueHash && !AttrVal($name, 'ignore', 0)) {
		my %params = (chHash => $chHash, valueHash => $valueHash, doTrigger => 1, target => $target);
		if (AttrVal($name, 'do_not_notify', 0)) {
			$params{doTrigger} = 0;
		}
		
		InternalTimer(gettimeofday(), 'HM485_ChannelDoUpdate', \%params, 1);
	}
}

=head2
	perform an update of a channel
	
	@param	hash    parameter hash
=cut
sub HM485_ChannelDoUpdate($) {
	my ($params)    = @_;
	
	my $chHash    = $params->{chHash};
	my $valueHash = $params->{valueHash};
	my $name      = $chHash->{NAME};
	my $doTrigger = $params->{doTrigger} ? 1 : 0;
	my $target    = $params->{target};
	
	my $state = undef;  # in case we do not update state anyway, use the last parameter
    my $updateState = 1;
	
	HM485::Util::Log3($chHash, 4,'HM485_ChannelDoUpdate');
	
	# is this for the central or does it go somewhere else?
	my $targetName = undef;
	if($target and $target ne "FFFFFFFF" and $target ne $chHash->{devHash}{IODev}{hmwId}) {
        # target is some device
		$targetName = HM485::PeeringManager::getDevNameByHmwId($target);
		$updateState = 0;
	};	
	
	readingsBeginUpdate($chHash);
	
	foreach my $valueKey (keys %{$valueHash}) {
		my $value = $valueHash->{$valueKey};
		
		if (defined($value)) {
			my $oldValue = $chHash->{READINGS}{$valueKey}{VAL} ? $chHash->{READINGS}{$valueKey}{VAL} : 'empty';
			HM485::Util::Log3( $chHash, 5, 'HM485_ChannelDoUpdate: valueKey = '.$valueKey.' value = '.$value.' Alter Wert = '.$oldValue);
			if($targetName) {
			    readingsBulkUpdate( $chHash, "P-".$valueKey, $value." to ".$targetName);
				HM485::Util::Log3( $chHash, 4, $valueKey . ' -> ' . $value." to ".$targetName);
			}else{
			    readingsBulkUpdate( $chHash, $valueKey, $value);
				HM485::Util::Log3( $chHash, 4, $valueKey . ' -> ' . $value);
			    # State noch aktualisieren
			    if ( $valueKey eq 'state') {
				    $updateState = 0; # anyway updated
			    } elsif(!defined($state) || $valueKey eq 'level' || $valueKey eq 'sensor' || $valueKey eq 'frequency') {
				    $state = $valueKey . '_' . $value;
			    };
			};
		}
	}
	if(defined($state) && $updateState) {
		readingsBulkUpdate( $chHash, 'state', $state);
	};	
	readingsEndUpdate($chHash, $doTrigger);
	
}

=head2
	Process incomming eeprom data and write it to device readings 
	
	@param	hash    hash of device addressed
	@param	string  request data
	@param	string  the eeprom data
=cut
sub HM485_ProcessEepromData($$$) {
	my ($hash, $requestData, $eepromData) = @_;

	my $name = $hash->{NAME};
	my $adr  = substr($requestData, 0, 4); 
	
	setReadingsVal($hash, '.eeprom_' . $adr, $eepromData, TimeNow());
	#todo .helper for witch cache should be deleted
	delete $hash->{cache};
}

###############################################################################
# External helper functions
###############################################################################

=head2
	Provide dimmer functions for using in FHEMWEB
	
	Todo:
	
	@param	string  the device name
=cut
sub HM485_DevStateIcon($) {
	my ($name) = @_;
	my @dimValues = (6,12,18,25,31,37,43,50,56,62,68,75,81,87,93);
	
	my $value = ReadingsVal($name, 'level', '???');
	my $retVal = 'dim06%';
	my (undef,$level) = split('_', $value);
	if (!defined $level) {
		$level = $value;
	}

	if ($level == 0) {
		$retVal = '.*:off';
	} elsif ($level >= 93) {  
 		$retVal = '.*:dim93%';  
	} elsif ($level == 100) {
		$retVal = '.*:on';

	} else {
		foreach my $dimValue (@dimValues) {
			if ($level <= $dimValue) {
				$retVal =  sprintf ('.*:dim%02d%%' , $dimValue);
				last;
			}
		}
	}
	
	return $retVal;
}

sub HM485_FrequencyFormField($$$) {
	my ($FW_wname, $d, $FW_room, $cmd, $values) = @_;

	my $retVal = undef;
	
	if ( lc( $cmd) eq 'frequency') {
		my $value = ReadingsVal($d, $cmd, 0);
		$retVal = '<td><form method="post" action="/fhem">' .
			'<input type="hidden" name="arg.set' . $d . '" value="' . $cmd . '">' .
			'<input type="hidden" name="room" value="' . $FW_room . '">' .
			'<input type="hidden" name="dev.set' . $d . '" value="' . $d . '">' .
			'<input type="text" size="5" class="set" name="val.set' . $d . '" value="' . $value . '">' .
			'<input type="submit" name="cmd.set' . $d . '" value="set" class="set">' . 
			'</form></td>';
	}

	return $retVal;
}

#PFE BEGIN

# TODO: Das ganze funktioniert wahrscheinlich nicht,
#       wenn irgend ein anderer Befehl (nicht queued)
#       zwischendurch ausgefuehrt wird.
# TODO: Auch fuer Befehle, die nur mit ACK beantwortet werden

# Create new entry in the list of message queues
# Parameter:
# Success-Callback Name
# Success-Callback Parameters
# Failure-Callback Name
# Failure-Callback Parameters 
sub HM485_GetNewMsgQueue($$$$$) {
  my ($hash,$successFn, $successParams, $failureFn, $failureParams) = @_;
  HM485::Util::Log3( $hash, 5, 'HM485_GetNewMsgQueue');
  return { successFn => $successFn, successParams => $successParams,
           failureFn => $failureFn, failureParams => $failureParams,
		   entries => [], currentIndex => -1 };
}

# append command to queue
sub HM485_QueueCommand($$$$) {
	my ($queue, $hash, $hmwId, $data) = @_;
	HM485::Util::Log3( $hash, 5, 'HM485_QueueCommand'.$data);
	${$queue->{entries}}[$#{$queue->{entries}} +1] = {hash => $hash, hmwId => $hmwId, data => $data};
}	

# This function is a wrapper to be able to call 
# queue success callbacks via InternalTimer
sub HM485_QueueSuccessViaTimer($){
  my ($queue) = @_;
  no strict "refs";
  &{$queue->{successFn}}(@{$queue->{successParams}});
  use strict "refs";
}

# start processing a queue 
sub HM485_QueueStart($$) {
  my ($hash, $queue) = @_;
  # empty queues are not really started, we just call the success function
     #success callback function
  if($#{$queue->{entries}} == -1) {     
	if($queue->{successFn}) {
	  # the success function is called via internal timer
	  # because it is usually called asynchronously for non-empty queues
	  InternalTimer(gettimeofday(), 'HM485_QueueSuccessViaTimer', $queue, 0);
	};  
	return;
  };
  
  push(@msgQueueList, $queue);
  HM485::Util::Log3( $hash, 5, 'HM485_QueueStart: Num: '.$#msgQueueList);
  if($#msgQueueList == 0) {
    # This is the first one, need to start
	HM485_QueueProcessStep();
  }
};
 

#next step in queue processing
#called for first step or if step before was successful
sub HM485_QueueProcessStep() {
  if($#msgQueueList < 0){ return };  # ready, no Queues
# TODO: smarter order of processing 
  $currentQueueIndex = 0;
  my $currentQueue = $msgQueueList[$currentQueueIndex];
  # process next entry in this queue
  $currentQueue->{currentIndex}++;
  my $currentEntry = ${$currentQueue->{entries}}[$currentQueue->{currentIndex}];
  
  HM485::Util::Log3( $currentEntry->{hash}, 5, 'HM485_QueueProcessStep: '.$currentEntry);
  # Clear current request id. The current request id is then set when really sending the command
  $currentQueue->{currentRequestId} = undef;
  HM485_SendCommand($currentEntry->{hash}, $currentEntry->{hmwId}, 
                    $currentEntry->{data}, 1);
}


# set request ID into current queue
sub HM485_QueueSetRequestId($$) {
  my ($hash, $requestId) = @_;
  HM485::Util::Log3( $hash, 5, 'HM485_QueueSetRequestId start');
  if($#msgQueueList < 0){ return };  # ready, no Queues
  my $currentQueue = $msgQueueList[$currentQueueIndex];
  if(defined($currentQueue->{currentRequestId})) {
	HM485::Util::Log3( $hash, 5, 'HM485_QueueSetRequestId: Request Id already defined');
    return;
  }
  $currentQueue->{currentRequestId} = $requestId;
  HM485::Util::Log3( $hash, 5, 'HM485_QueueSetRequestId: Id: '. $requestId);
}

#called from ProcessResponse
sub HM485_QueueStepSuccess($$) {
   my ($hash, $requestId) = @_;
  # are we in queue processing?
  if($currentQueueIndex < 0) { return; };
  HM485::Util::Log3($hash, 5, 'HM485_QueueStepSuccess called');
  # ok, go to the next queue entry
  # get current queue
  my $currentQueue = $msgQueueList[$currentQueueIndex]; 
  # correct request?
  if($currentQueue->{currentRequestId} != $requestId) { 
    HM485::Util::Log3($hash, 5, 'HM485_QueueStepSuccess: Foreign request ID: '.$requestId.' '.$currentQueue->{currentRequestId});
    return; 
  };
  # have we processed the last entry?
  HM485::Util::Log3($hash, 5, 'HM485_QueueStepSuccess: Entries: '.$#{$currentQueue->{entries}}.' Index: '.$currentQueue->{currentIndex});
  if($#{$currentQueue->{entries}} == $currentQueue->{currentIndex}) {
    # yes, last entry. Remove from list of queues
	splice(@msgQueueList,$currentQueueIndex,1);
	$currentQueueIndex = -1;
	# process next entry. This is done in any case as there might be other queues
	# however, it needs to be done before the callback as this might already create 
	# a new queue and call queueStart
	HM485_QueueProcessStep();
    #success callback function
	if($currentQueue->{successFn}) {
	  no strict "refs";
      &{$currentQueue->{successFn}}(@{$currentQueue->{successParams}});
	  use strict "refs";
	};  
  }else{
    # process next entry. This is done in any case as there might be other queues
    HM485_QueueProcessStep();
  };
}


sub HM485_QueueStepFailed($$) {
  my ($hash, $requestId) = @_;
  HM485::Util::Log3($hash, 5, 'HM485_QueueStepFailed Request ID: '.$requestId);
  if($currentQueueIndex < 0) { return };
  # get current queue
  my $currentQueue = $msgQueueList[$currentQueueIndex]; 
  # correct request?
  if($currentQueue->{currentRequestId} != $requestId) { 
    HM485::Util::Log3($hash, 5, 'HM485_QueueStepFailed Foreign request ID');
    return; 
  };  
  # remove complete queue
  splice(@msgQueueList,$currentQueueIndex,1);
  $currentQueueIndex = -1;
  # next step, there might be multiple queues
  # call this now, just in case the callback creates a new queue
  HM485::Util::Log3($hash, 3, 'HM485_QueueStepFailed Call step');
  HM485_QueueProcessStep();
  # failure callback
  if($currentQueue->{failureFn}) {
    no strict "refs";
    &{$currentQueue->{failureFn}}(@{$currentQueue->{failureParams}});
	use strict "refs";
  };	
}

1;

=pod
=begin html

<a name="HM485"></a>
<h3>HM485</h3>
<ul>
	HM485 supports eQ-3 HomeMaticWired (HMW) and compatible "Homebrew" devices<br>
	If you want to connect HMW devices to FHEM, at least one <a href="#HM485_LAN">HM485_LAN</a> is needed as IO-Device.
	<br><br>
	<b>How to create an HMW device in FHEM</b><br>
	Usually, it is not needed to create any HMW device manually. You should either use the discovery mode (see <a href="#HM485_LAN">HM485_LAN</a>) or you make the device send any message over the bus by e.g. pressing a button on the device. In both cases, FHEM automatically detects the new device and creates it in FHEM. The device is automatically assigned to the correct HM485_LAN, in case you have more than one.<br>
	The device is also automatically paired, i.e. the physical device itself then knows that it is connected to a central device and sends messages directed to this device accordingly. 
	<br><br>
    <b>Define</b>
	<ul>
		<code>define &lt;name&gt; HM485 &lt;hmwid&gt; [&lt;io-device&gt;]</code><br>
		&lt;hmwid&gt; is the address of the device. This is an 8-digit hex code, which is unique to each device. For original HMW devices, this is set at the factory and cannot be changed.<br>
		&lt;io-device&gt; is the name of the IO-device (HM485_LAN) of the gateway where the device is attached to. This can be omitted if you have only one gateway. 		
	</ul>	
	<br>
	<b>Set</b>
	<br>
	The set options config, raw, reset and settings are generally available on device level.
    <br>	
	<ul>
		<li><code>set &lt;device&gt; <b>getConfig</b></code><br>
		For HMW devices, the configuration data is stored in the device itself. <code>set ... getConfig</code> triggers reading the configuration data from the device. This also includes the state of all channels. In normal operation, this command is not needed as FHEM automatically reads the configuration data from the device at least on startup and when a new device is created in FHEM. When changing configuration data from FHEM, everything is synchronized automatically as well. However, when the device configuration is changed outside FHEM, an explicit <code>set ... getConfig</code> is needed. (This e.g. happens when devices are peered using the buttons on the devices directly.) In addition, things sometimes do go wrong. If in doubt, you can do a <code>set ... getConfig</code>, but give the system the chance to read all the data. (Also see reading <code>configStatus</code>.)
		</li>
		<br>
		<li><code>set &lt;name&gt; <b>raw</b> &lt;data&gt;</code><br>
		This command sends raw messages to the device. For normal operation, this is not needed. However, it can be helpful for troubleshooting, especially when developing own devices. Using it requires knowledge about the HM485 protocol.<br>
		&lt;data&gt; is the message to be sent in hex code. Other than the <code>set ... RAW</code> of a HM485_LAN device, you only need to give the message itself, without target address, sender address and control byte.<br>
		Example:<br>
		<code>set &lt;name&gt; raw 7802C8</code><br>
		sets channel 3 of device &lt;name&gt; to "on", assuming that it is a switch. 
		</li>
		<br>
		<li><code>set &lt;name&gt; <b>reset</b></code><br>
		This does a factory reset of the device. I.e. the whole EEPROM is overwritten with hex FF, which is interpreted by the device as "empty". FHEM also sends a "re-read config" command afterwards, but some devices seem to ignore this. It is recommended to unpower the device for a moment after a factory reset.
		</li>
		<br>
		<li><code>set &lt;name&gt; <b>config</b> &lt;parameter&gt; &lt;value&gt; ...</code><br>
		This can be used to set configuration options in the EEPROM of the HMW device. It only exists if there are configuration options on device level. Instead of using this command, it is usually easier to change the configuration directly in the user interface.
		<ul>
			<li>&lt;parameter&gt;: This is the name of the configuration parameter, like "logging_time". Available parameters differ by the model of the device. They can be seen directly on the user interface.</li>
			<li>&lt;value&gt;: This is the new value to be set. For boolean parameters or options (like yes/no or switch/pushbutton), the internal values (like 0/1) need to be used.</li>
		</ul>
		You can use multiple &lt;parameter&gt; &lt;value&gt; pairs in one command. The following command would set both "input_locked" to "yes" and "long_press_time" to 5 seconds.<br>
		<code>set &lt;name&gt; config input_locked 1 long_press_time 5.00</code>
		</li>
		<br>

	</ul>
	<br>
	The set options config, peer, peeringdetails and unpeer are available on channel level.
	<ul>
		<li><code>set &lt;channel&gt; <b>config</b> &lt;parameter&gt; &lt;value&gt; ...</code><br>
		This is the same as <code>set &lt;name&gt; config</code> on device level, only for configuration options on channel level. See <code>set &lt;name&gt; config</code> on device level for details.
		</li>
		<br>
		<li><code>set &lt;channel&gt; <b>peer</b> &lt;peer-channel&gt;</code><br>
		Channels of Homematic Wired devices can be peered directly. This e.g. can trigger to switch on an actor when a key is pressed on a sensor, even if FHEM is down. However, it depends on the sensor-actor combination what the peering actually does. You can only peer a sensor channel (e.g. a key) with an actor channel (e.g. a switch). However, it does not matter in FHEM, whether you peer from the sensor to the actor or vice versa.
		When using <code>set ... peer</code> from the input mask in Fhemweb, a drop down list shows the channels which are available for peering.
		</li>
		<br>
		<li><code>set &lt;channel&gt; <b>peeringdetails</b> ...</code><br>
		This is used internally to set configuration parameters for peerings. It should not be used directly. Instead, use the "Peering Configuration" dialog which appears as soon as a channel is peered.</li>
		<br>
		<li><code>set &lt;channel&gt; <b>unpeer</b> &lt;peered-channel&gt;</code><br>
		This command is used to delete a peering. It can be used from both the sensor and the actor side. When using it from the input mask in Fhemweb, a drop down list with currently peered channels is provided.
		</li>
		</ul>
		<br>
		Apart from the general set options, HMW devices have specific set options on channel level. They are used to directly manipulate the channel's state. The easiest way to find out which set options are possible is by using the drop down list on the related input field in Fhemweb. Here are some of set options for a switch channel as an example:
		<br>
		<ul>
		<li><code>set &lt;switch-channel&gt; <b>on</b></code><br>
		    <code>set &lt;switch-channel&gt; <b>off</b></code><br>
		This switches the channel on or off.
		</li>
		<br>
		<li><code>set &lt;switch-channel&gt; <b>on-for-timer</b> &lt;seconds&gt;</code><br>
		This switches the channel on. After &lt;seconds&gt; seconds, the channel is switched off.<br>
		Normally, commands to change the state of a channel are implemented by just sending the related command to the device and letting the device do the rest. However, there is no <code>on-for-timer</code>, which could be directly triggered for HMW devices. The <code>set ... on-for-timer</code> is implemented in FHEM using an internal <code>at</code>.
		</li>
		<br>
		<li><code>set &lt;switch-channel&gt; <b>toggle</b></code><br>
		This switches the channel on, when it is currently off and vice versa. There are HMW devices, which have a toggle command themselves. In these cases, FHEM uses this directly. However, some devices do not have a toggle command, even though they have on and off. In these cases, <code>set ... toggle</code> is implemented in FHEM. This implementation relies on the state of the channel being correctly synchronized with FHEM, which is usually not the case directly after switching the channel.
		</li>
		</ul>
		<br>
		<b>Get</b>
		<br>
		The get option <code>config</code> is available on device and channel level. <code>state</code>, <code>peeringdetails</code> and <code>peerlist</code> are for channels. The options <code>config</code>, <code>peerlist</code> and <code>peeringdetails</code> are normally only needed internally. From a user's perspective, it is better to use the "Device Configuration", "Channel Configuration" and "Peering Configuration" dialogs.  
		<br>
		<ul>
		<li><code>get &lt;channel&gt; <b>state</b></code><br>
		This command updates the state of a channel, if possible. Technically, it sends a request to the device to send back the state of the channel. This is usually only implemented by actor channels. In this case, the readings <code>state</code> and other readings showing the channel's state are updated (like e.g. <code>working</code> and <code>level</code> for shutter actors). 
		</li>
		<br>
		<li><code>get &lt;device/channel&gt; <b>config</b></code><br>
		This command returns the device or channel configuration in json format.  
		</li>
        <br>
		<li><code>get &lt;channel&gt; <b>peerlist</b></code><br>
		This command returns a list of all peered channels in json format.  
		</li>
        <br>
		<li><code>get &lt;channel&gt; <b>peeringdetails</b> &lt;peered-channel&gt;</code><br>
		This command returns the peering configuration in json format.  
		Each peering has a number of settings which influences what the peering actually does. E.g. <code>short_on_time</code> controls how long a switch stays switched on when triggered by a short key press. These settings are attributes of the peering itself, i.e. (basically) the combination of the sensor channel and the actor channel.<br>
		</li>
		</ul>
		<br>
		<b>Readings</b>
		<br>
		<ul>
		<li><b>D-serialNr</b>: Serial number of the device.</li><br>
		<li><b>D-deviceKey</b>: In principle, this is the model of the device, like "HMW_LC_Sw2_DR". However, some devices have different versions. In this case, this reading usually contains some version information as well. (Technically, it is the file name of the device description file.)</li><br>
		<li><b>D-fwVersion</b>: Version of the device firmware.</li><br>
		<li><b>D-subType</b>: Type of a channel, like e.g. "switch", "key" or "blind".</li><br>
		<li><b>R-central_address</b> shows the central address the device is paired to. This reading is available on device level for every paired device. If it is not there or it shows FFFFFFFF, something is wrong. The address shown should be the same as shown in the attribute <code>hmwId</code> of the HM485_LAN device, which is assigned. In most cases, this is 00000001.</li>
		<br>
		<li><b>configStatus</b> shows the status of the synchronization of the device configuration with FHEM. It can have the following values:
			<ul>
			<li><b>PENDING</b> means that FHEM has not started yet to read the data from the device. This only happens at startup.</li>
			<li><b>READING</b> means that FHEM is currently reading the configuration data from the device. This happens at startup, when a device is created and when <code>get ... config all</code> is used.</li>
			<li><b>FAILED</b> means that FHEM tried to read the data from the device, but this was not successful. In this case, FHEM re-tries after a few seconds. I.e. you usually won't see FAILED very long. It switches to READING (and maybe back to FAILED etc.) automatically.</li>
			<li><b>OK</b> means that the data has been read successfully. Normally, it will stay like that unless <code>get ... config all</code> is used.</li>
			</ul>
		You should only do anything with the device if <code>configStatus</code> shows OK. In case it shows PENDING or READING, just wait. Especially if you have a lot of devices, this can take a few minutes at startup. If it shows FAILED or keeps changing between READING and FAILED, then you need to fix the underlying problem first.
		</li>
		<br>
		<li><b>state</b> (on device level) can have the values "ACK" and "NACK". This shows whether the latest communication with the device was successful (ACK) or not (NACK). If you see "NACK" more often than almost never, then your bus might have an issue.</li>
		<br>
		<li><b>state</b> (on channel level) is a bit more complicated:
		<ul>
		<li>If the channel provides the value "state" according to the device definition, then FHEM shows this value as <code>state</code> as well. Only if a set-command like on, off, toggle etc. has been used, state shows "set_" followed by the command, like e.g. "set_toggle".</li>
		<li>If the channel does not provide the value "state", then the "main value" of the latest event sent from the device is shown, prefixed by the name of this value. E.g. for key channels, state is usually something like "press_short_7" and for shutter controls, you should see something like "level_75". Like above, when issuing a set command, which influences the channel values, the reading <code>state</code> shows "set_" followed by the command. E.g. for a shutter control this might be "set_level_75".</li>
		</ul>
		Usually, the "set_" values in <code>state</code> vanish again after a few seconds. However, this might not always be the case. If e.g. a switch is switched on and logging is disabled, FHEM never receives the new state. This means that <code>state</code> will stay "set_on". To change this, an explicit <code>get ... state</code> is needed.<br>
		If possible, do not use <code>state</code> at all. It is better to use the channel specific readings like <code>press_short</code> for keys or <code>level</code> for shutter controls.
		</li>
		<br>
		<li><b>R-&lt;config-option&gt;</b> shows the value of the configuration parameter &lt;config-option&gt;. For each of these parameters on device and channel level, FHEM generates a reading. E.g. if a channel has a configuration option named <code>long_press_time</code>, then there is a reading <code>R-long_press_time</code>. Each of these parameters can be changed using the <code>set ... config</code>. When using this command, you see the new parameter value prefixed by "set-" for a moment before the new value only is shown. If the "set-" prefix stays there, then there is an issue with the communication to the device.</li>  	
		<br>
		<li><b>&lt;channel-value&gt;</b>: HMW device channels usually have a set of values, which are part of the channel's state or sent in events (e.g. when a key is pressed). These readings are generated from the device description when the device sends the related values. They depend on the device type and on the type of the channel. E.g. a key channel has the readings <code>press_long</code> and <code>press_short</code>, while a shutter control has the readings <code>level</code>, <code>working</code> and <code>direction</code>.</li>
		</ul>	
		<br>
		<b>Attributes</b>
		<ul>
		<br>
		<li><b>autoReadConfig</b>: When to read device configuration<br>
			This attribute controls whether the device configuration is read automatically once at startup, everytime the device is disconnected or not at all.<br>
			The following values are possible:
			<ul>
				<li><b>atstartup</b>: The configuration is only read from the device when it is created and when it is explicitly triggered using the command <code>get ... config all</code>. This includes restarting FHEM. 
				</li>
				<li><b>always</b>: Everytime the device does not answer to a message, FHEM tries to re-read the configuration. 
				</li>
				<li><b>never</b>: FHEM does not read the device configuration automatically.  To read the config, it needs to be triggered explicitly using <code>get ... config all</code>. This also means that the configuration cannot be changed before <code>get ... config all</code> has been called.
				</li>
			</ul>
			If this attribute is set in the assigned HM485_LAN device, then this value is used by default. Otherwise, the standard value is "atstartup". Changing the default only makes sense in special cases.
		</li>
		<br>
		<li><b>configReadRetries</b>: Number of re-tries when reading the device configuration<br>
			When this attribute is <b>not</b> set, FHEM tries to read the device configuration until successful. This might be problematic when there are a lot of devices and the communication is not really reliable. You actually control the number of re-tries, i.e. if <code>configReadRetries</code> is 0, FHEM might still try to read the configuration once, depending on the attribute <code>autoReadConfig</code>. If you want no automatic reading of the configuration at all, then set attribute <code>autoReadConfig</code> to <code>never</code>.<br>
			It is possible to change <code>configReadRetries</code> while the system tries to read the configuration. This is helpful if e.g. a device stops working while startup. Then you can set <code>configReadRetries</code> to 0 to stop FHEM re-trying infinitely.<br>
			It does not matter whether the configuration reading process is triggered automatically or by <code>get ... config all</code>. The system always considers <code>configReadRetries</code>.<br> 
			If this attribute is set in the assigned HM485_LAN device, then this value is used by default. This way you can control the behaviour for all HM485 devices.
		</li>
		<br>
		<li><b>IODev</b>: IO-Device the HM485 device is assigned to<br>
			Normally, you do not need to change this. The device should be automatically created with the correct IO-Device (HM485_LAN) assigned. However, if you restructure your HM485 bus, devices might get a new gateway. You can then change the attribute <code>IODev</code> manually.<br>
			Consider that direct peerings only work for devices which are directly connected. I.e. direct peerings won't work for devices which are assigned to different IO-Devices. 	
		</li>
		</ul>	
</ul>
=end html
=cut
