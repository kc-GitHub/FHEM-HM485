=head1
	10_HM485.pm

# $Id: 10_HM485.pm 0744 2017-01-19 06:54:00Z ThorstenPferdekaemper $	
	
	Version 0.7.44
				 
=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013

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
use lib::HM485::FhemWebHelper;
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
sub HM485_GetPeerSettings($$);

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
sub HM485_ProcessChannelState($$$$);
sub HM485_ChannelUpdate($$);
sub HM485_ChannelDoUpdate($);
sub HM485_ProcessEepromData($$$);

# External helper functions
sub HM485_DevStateIcon($);

#Message queues
sub HM485_GetNewMsgQueue($$$$$);
sub HM485_QueueStepFailed($$);
sub HM485_QueueStepSuccess($$);




my @attrListRO     = ();

# Default set comands for device
my %setsDev = ('reset' => 'noArg');

# Default set comands for channel
my %setsCh = ();

# Default get commands for device
my %getsDev = (
	'info'    => 'noArg', # maybe only for debugging
	'config'  => 'all',
	'state'   => 'noArg',
);

# Default get commands for channel
my %getsCh = ('state' => 'noArg');

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

	$hash->{'Match'}          = '^FD.*';
	$hash->{'DefFn'}          = 'HM485_Define';
	$hash->{'UndefFn'}        = 'HM485_Undefine';
	$hash->{'RenameFn'}       = 'HM485_Rename';
	$hash->{'ParseFn'}        = 'HM485_Parse';
	$hash->{'SetFn'}          = 'HM485_Set';
	$hash->{'GetFn'}          = 'HM485_Get';
	$hash->{'AttrFn'}         = 'HM485_Attr';
	
	# For FHEMWEB
	$hash->{'FW_detailFn'}    = 'HM485_FhemwebShowConfig';
	# The following line means that the overview is shown
	# as header, even though there is a FW_detailFn
	$hash->{'FW_deviceOverview'} = 1;

	$hash->{'AttrList'}       =	'autoReadConfig:atstartup,always,never '. 
							  'configReadRetries '.	
							  'do_not_notify:0,1 ' .
	                          'ignore:1,0 dummy:1,0 showtime:1,0 serialNr ' .
	                          'model:' . HM485::Device::getModelList() . ' ' .
	                          'subType stateFormat firmwareVersion setList ' .
	                          'event-min-interval event-aggregator IODev ' .
	                          'event-on-change-reading event-on-update-reading';

	#@attrListRO = ('serialNr', 'firmware', 'hardwareType', 'model' , 'modelName');
	@attrListRO = ('serialNr', 'firmware');
	
	$data{'webCmdFn'}{'textField'}  = "HM485_FrequencyFormField";
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
	my $msg    = undef;

	RemoveInternalTimer($hash);  
	if (int(@a)!=3 && int(@a)!=4 || (defined($a[2]) && $a[2] !~ m/^[A-F0-9]{8}_{0,1}[A-F0-9]{0,2}$/i)) {
		$msg = 'wrong syntax: define <name> HM485 <8-digit-hex-code>[_<2-digit-hex-code>] [<IO-Device>]';

	} elsif ($modules{'HM485'}{'defptr'}{$hmwId}) {
		$msg = 'Device ' . $hmwId . ' already defined.'

	} else {
		my $name = $hash->{'NAME'};
		
		if ($chNr) {
			
			# We defined a channel of a device
			my $devHash = $modules{'HM485'}{'defptr'}{$addr};
			
			if ($devHash) {
				my $devName = $devHash->{'NAME'};
				
				$devHash->{'channel_' .  $chNr} = $name;
				$hash->{device}    = $devName;                  # reference this channel to the device entity
				$hash->{devHash} = $devHash;
				$hash->{chanNo}    = $chNr;						# reference the device to this channel
				

			} else {
				$msg = 'Please define the main device ' . $addr . ' before define the device channel';
			} 
			
		} else {
			# We defined the device
			AssignIoPort($hash, $a[3]); 
			HM485::Util::Log3($hash->{IODev}, 2, 'Assigned '.$addr.' as '.$name);
		}

		if (!$msg) {
			$modules{'HM485'}{'defptr'}{$hmwId} = $hash;
			$hash->{'DEF'} = $hmwId;
			
			if ( defined($hash->{'IODev'}{'STATE'}) && length($hmwId) == 8) {
				HM485_ReadingUpdate($hash, 'configStatus', 'PENDING');
# We can always use WaitForConfig. It will do it's job eventually in any case.	
				$hash->{FailedConfigReads} = 0;
				InternalTimer (gettimeofday(), 'HM485_WaitForConfigCond', $hash, 0);
			}
		}
	}
	
	return $msg;
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
	
	my $hmwId = $hash->{DEF};
	
	if (defined($hash->{'IODev'}{'STATE'})) {
		if ($hash->{'IODev'}{'STATE'} eq 'opened') {
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
		HM485_SetStateAck($ioHash, $msgId, $msgData);
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
	my $cmd   = $params[1];
	my $value = $params[2];
	
	my $msg = '';
	my $data = '';
	my $state = 0xC8;
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	
	my %sets = ();
	my $peerList;
	
	if ( $chNr > 0) {
		%sets = %setsCh;
		my $allowedSets = HM485::Device::getAllowedSets($hash);
		if ($allowedSets) {
			foreach my $setValue (split(' ', $allowedSets)) {
				my($setValue, $param) = split(':', $setValue);
				$sets{$setValue} = $param;
			}
		}
		
		$peerList = HM485::PeeringManager::getPeerableChannels($hash);
				
		if ($peerList->{'peerable'}) {
			$sets{'peer'} = $peerList->{'peerable'};
		}
		if ($peerList->{'peered'}) {
			$sets{'unpeer'} = $peerList->{'peered'};
		} elsif ($peerList->{'actpeered'}){
			$sets{'unpeer'} = $peerList->{'actpeered'};
		}
	} else {
		#HM485::PeeringManager::getLinksFromDevice($hash);
		%sets = %setsDev;
	}
	
	if ($hash->{'.configManager'}) {
		$sets{'config'} = '';
		$sets{'settings'} = '';
	}
	
	# raw geht immer beim Device
	if(!$chNr) {
	  $sets{'raw'} = '';
	};

	if (@params < 2) {
		$msg =  '"set ' . $name . '" needs one or more parameter'

	} else {
		if(!defined($sets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %sets) {
				$arguments.= $arg . ($sets{$arg} ? (':' . $sets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;

		} else {
			if ($cmd eq 'press_long' || $cmd eq 'press_short') {
				my $counter = $hash->{'READINGS'}{'sim_counter'}{'VAL'} ?
							  $hash->{'READINGS'}{'sim_counter'}{'VAL'} : 0;
				HM485_ReadingUpdate($hash, 'state', $cmd .' '.$counter);
				$msg = HM485_SetKeyEvent($hash, $cmd);

			} elsif ($cmd eq 'peer') {
				$msg = HM485_SetPeer($hash, @params);
			
			} elsif ($cmd eq 'unpeer') {
				$msg = HM485_SetUnpeer($hash, @params);
			
			} elsif ($cmd eq 'reset') {
				#readingsSingleUpdate($hash, 'state', 'reset', 1);
				$msg = HM485_SetReset($hash, $cmd);
			
			} elsif ($cmd eq 'config') {
				$msg = HM485_SetConfig($hash, @params);
			
			} elsif ($cmd eq 'settings') {
				$msg = HM485_SetSettings($hash, @params);
			
			} elsif ($cmd eq 'frequency') {
				HM485_ReadingUpdate($hash, $cmd, $value);
				$msg = HM485_SetChannelState($hash, $cmd, $value);			
			} elsif ( $cmd eq 'on-for-timer') {
				if ( $value && $value > 0) {
					# remove any internal timer, which switches the channel off
					my $offcommand = 'set ' . $name . ' off';
					RemoveInternalTimer($offcommand);
					# switch channel on	
					$msg = HM485_SetChannelState($hash, 'on', $value);
					HM485::Util::Log3($hash, 5, 'set ' . $name . ' on-for-timer ' . $value);
					# set internal timer to switch channel off
					InternalTimer( gettimeofday() + $value, 'fhem', $offcommand, 0 );
				} else {
					$msg = HM485_SetChannelState($hash, 'off', $value);
				}
			} elsif ($cmd eq 'raw') {
				HM485_SendCommand($hash, $hmwId, $value);
			} elsif ($cmd eq 'toggle') {
				# toggle is a bit special
				$msg = HM485_SetToggle($hash);
			# "else" includes level, stop, on, off
			} else {  
				my $state = 'set_'.$cmd;
				if($value) { $state .= '_'.$value; }
				HM485_ReadingUpdate($hash, 'state', $state);
				$msg = HM485_SetChannelState($hash, $cmd, $value);
			}
			return ($msg,1);  # do not trigger events from set commands
		}
	}

	return $msg;  
}


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
	my $args = $params[2];
	my $peerList = $chNr ? HM485::PeeringManager::getPeerableChannels($hash) : undef;
	my %gets = $chNr > 0 ? %getsCh : %getsDev;
	my $msg  = '';
	my $data = '';
	
	if ($peerList->{'peered'}) {
		$gets{'peersettings'} = $peerList->{'peered'};
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

		} elsif ($cmd eq 'info') {
			# all infos (moduleType, serialNumber, firmwareVersion)
			HM485_GetInfos($hash, $hmwId, 0b111);

		} elsif ($cmd eq 'config') {
			# get module config (eeprom data)
			# This triggers a manual config read
			# i.e. old errors don't matter
			$hash->{FailedConfigReads} = 0;
			HM485_GetConfig($hash, $hmwId);
		} elsif ($cmd eq 'state') {
			# abfragen des aktuellen Status
			$data = sprintf ('53%02X', $chNr-1);  # Channel als hex- Wert
			HM485_SendCommand( $hash, $hmwId, $data);
		} elsif ($cmd eq 'peersettings') {
			$msg = HM485_GetPeerSettings($hash, $args);	
		}
	}

	return $msg;
}

=head2
	Implements AttrFn function.
	
	@param	undef   is alway "set" we dont need this
	@param	string	name of device
	@param	string	attribute name
	@param	string	attribute value
=cut
sub HM485_Attr($$$$) {
	my (undef, $name, $attrName, $val) =  @_;

	my $hash  = $defs{$name};
	my $msg   = undef;

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	if ($attrName) {
		if (!$msg) {
			if ( $attrName eq 'serialNr' && (!defined($val) || $val !~ m/^[A-Za-z0-9]{10}$/i) ) {
				$msg = 'Wrong serialNr (' . $val . ') defined. serialNr must be 10 characters (A-Z, a-z or 0-9).';
		
			} elsif ($attrName eq 'firmwareVersion') {
				if ($val && looks_like_number($val)) {
					$hash->{FW_VERSION} = $val;
				} else {
					$msg = 'Firmware version must be a number.';
				}

			} elsif ($attrName eq 'model') {
				my @modelList = split(',', HM485::Device::getModelList());
				$msg = 'model of "' . $name . '" must one of ' . join(' ', @modelList);
				if ($val) {
					foreach my $model (@modelList) {
						if ($model eq $val) {
							$msg = undef;
							last;
						}
					}

					$hash->{MODEL} = $val;
				}
			}
		}
	}
	
	return ($msg) ? $msg : undef;
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
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	my $configHash = HM485::ConfigurationManager::getConfigFromDevice($hash, $chNr);

	#TODO newer FHEM Versions changed, so we need a trigger or something to update Fhemweb
    my $linkHash 		= $hash->{'peerings'};
	my $content = HM485::FhemWebHelper::showConfig($hash, $configHash, $linkHash);

	return $content;
}

###############################################################################
# Device related functions
###############################################################################

=head2
	Get Infos from device depends on $infoMask
	bit 1 = 1 -> request module type
	bit 2 = 1 -> request serial number
	bit 2 = 1 -> request firmware version
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
	@param	int     binary bitmask denined wich infos was requestet from device 
=cut

sub HM485_SetConfigStatus($$) {
	my ($hash, $status) = @_;
	HM485_ReadingUpdate($hash, 'configStatus', $status);
	if($status eq 'OK') {
		$hash->{FailedConfigReads} = 0;
	};
	if($status eq 'FAILED') {
		my $maxReads = HM485_GetConfigReadRetries($hash);
		if(!defined($maxReads) || $maxReads > $hash->{FailedConfigReads} ) {
			$hash->{FailedConfigReads}++;
			InternalTimer( gettimeofday() + $defStart, 'HM485_WaitForConfig', $hash, 0);
		}
	}
}



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
	# TODO: Performance: This always reads and sets everything
	# TODO: Performance: Use bulk update for readings
	
	my ($hash) = @_;
	
	if(ref($hash) eq "ARRAY") {
		# This is a call from a timer (ACK of writing EEPROM)
		($hash, undef) = @$hash;
		# Remove timer-tag
		delete $hash->{".updateConfigReadingsTimer"};
	};
	
	HM485::Util::Log3($hash, 4, 'HM485_UpdateConfigReadings called');
	
	my $configHash = HM485::ConfigurationManager::getConfigFromDevice($hash, 0);
	
	foreach my $cKey (keys %{$configHash}) {
		my $config = $configHash->{$cKey};
		next if($config->{hidden} && $cKey ne 'central_address');
		HM485_ReadingUpdate($hash, 'R-'.$cKey, HM485::ConfigurationManager::convertValueToDisplay($cKey, $config));
	}
	foreach my $chName (grep(/^channel_/, keys %{$hash})) {
		my $cHash = $defs{$hash->{$chName}};		
		$configHash = HM485::ConfigurationManager::getConfigFromDevice($cHash, 0);
		foreach my $cKey (keys %{$configHash}) {
			my $config = $configHash->{$cKey};
			next if($config->{hidden});
			HM485_ReadingUpdate($cHash, 'R-'.$cKey, HM485::ConfigurationManager::convertValueToDisplay($cKey, $config));
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
	my $configHash = HM485::ConfigurationManager::getConfigFromDevice($devHash, 0);

	my $central_address = $configHash->{central_address}{value};
	$central_address = sprintf('%08X',$central_address);
    # if this is not the address of the IO-Device, try to change it
	# TODO: This should probably be queued as well, but we cannot queue ACK-only commands
	if($central_address ne $devHash->{IODev}{hmwId}){
		HM485_SetConfig($devHash, (0,0,'central_address',hex($devHash->{IODev}{hmwId})));
	};	
	
	# Channels anlegen
	my $deviceKey = uc( HM485::Device::getDeviceKeyFromHash($devHash));
	HM485::Util::Log3($devHash, 4, 'Channels initialisieren ' . substr($hmwId, 0, 8));
	HM485_CreateChannels( $devHash);
	
	# Create R-Readings
	HM485_UpdateConfigReadings($devHash); 
	
	# State der Channels ermitteln
	$configHash = HM485::Device::getValueFromDefinitions( $deviceKey . '/channels/');
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


sub HM485_GetPeerSettings($$) {
	my ($hash, $arg) = @_;
	
	my $sensor   = $hash->{DEF};
	HM485::Util::Log3($hash, 4, 'Get peer settings for device ' . $sensor . ' -> ' . $arg);
	my $peerHash = HM485::PeeringManager::getPeerSettingsFromDevice($arg, $sensor);
	if(!defined($peerHash)) {
	  return 'Device '.$arg.' does not exist or is not peered with '.$hash->{NAME};
	}
	
	$hash->{peerings} = $peerHash;
		
	FW_directNotify("#FHEMWEB:WEB", "location.reload(true);","" ); 
	return '';
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
	if ($devHash->{MODEL}) {
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
		HM485::Util::Log3($devHash, 3, 'Initialisierungsfehler ' . substr( $hmwId, 0, 8) . ' ModelName noch nicht vorhanden');
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
					}
					CommandAttr(undef, $devName . ' subType ' . $subType);
						
					if($subType eq 'blind') {
						# Blinds go up and down by default (but only by default)
						my $val = AttrVal($devName, 'webCmd', undef);
						if(!defined($val)){
							CommandAttr(undef, $devName . ' webCmd up:down');
						};
					}
					# copy model 
					my $model = AttrVal($name, 'model', undef);
					CommandAttr(undef, $devName . ' model ' . $model);	
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

	my $msg = '';
	my $pList	 = HM485::PeeringManager::getPeerableChannels($hash);
	my @peerList = split(',',$pList->{peerable});
	
	if (@values == 1 && grep {$_ eq $values[0]} @peerList) {
		
		my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
		my $valId 	   	   = HM485::PeeringManager::getHmwIdByDevName($values[0]);
		my $actHmwId 	   = substr($valId,0,8);
		my $actCh 		   = int(substr($valId,9,2));
		
		my $senHash 	   = $main::modules{'HM485'}{'defptr'}{$valId};
		my $senDevHash 	   = $main::modules{'HM485'}{'defptr'}{$actHmwId};
		my $devHash		   = $main::modules{'HM485'}{'defptr'}{substr($hmwId,0,8)};
		
		my $deviceKey  	   = HM485::Device::getDeviceKeyFromHash($senHash);
		my $chType         = HM485::Device::getChannelType($deviceKey, $actCh);
		
		my $peering;
				
		$peering->{'act'}{'channel'} 	= int ($chNr - 1);
		$peering->{'act'}{'actuator'} 	= $actHmwId;
		$peering->{'act'}{'sensor'} 	= substr($hash->{'DEF'},0,8);
		#TODO here we can load predefined settings from a file (treppenhauslicht, blinklicht...)
		$peering->{'sen'} = HM485::PeeringManager::loadPeerSettingsfromFile($chType);
		$peering->{'sen'}{'channel'} 	= int ($actCh -1);
		$peering->{'sen'}{'actuator'} 	= $hmwId;
		$peering->{'sen'}{'sensor'} 	= substr($hash->{'DEF'},0,8);
	
		my $aktParams = HM485::PeeringManager::getLinkParams($devHash);
		my $senParams = HM485::PeeringManager::getLinkParams($senDevHash);
		my $freeAct   = HM485::PeeringManager::getFreePeerId($devHash,'actuator');
		my $freeSen   = HM485::PeeringManager::getFreePeerId($senDevHash,'sensor');
		
		if (!defined($freeAct) || !defined($freeSen)) {
			$msg = 'set peer ' . $values[0] .' no free PeerId found';
			return $msg;
		}
		
		my $configTypeHash;
		my $validatedConfig;
		
		foreach my $act (keys %{$aktParams->{'actuator'}{'parameter'}}) {
			
			$configTypeHash = $aktParams->{'actuator'}{'parameter'}{$act};
			#todo validate address data
			$msg = HM485_ValidateSettings($configTypeHash, $act, $peering->{'act'}{$act});
			if (!$msg) {
				
				$validatedConfig->{'actuator'}{$act}{'value'} = $peering->{'act'}{$act};
				$validatedConfig->{'actuator'}{$act}{'config'} = $aktParams->{'actuator'}{'parameter'}{$act};
				if ($act eq 'actuator') {
					$validatedConfig->{'actuator'}{$act}{'chan'} = $peering->{'sen'}{'channel'};
				}
				$validatedConfig->{'actuator'}{$act}{'peerId'} = $freeAct;
			}
		}
		
		foreach my $sen (keys %{$senParams->{'sensor'}{'parameter'}}) {
			
			$configTypeHash = $senParams->{'sensor'}{'parameter'}{$sen};
			# we only need stuff which is written to the EEPROM	
			#if($configTypeHash->{physical}{interface} ne 'eeprom') {
			#	next;
			#};	
			if (!defined($peering->{'sen'}{$sen})) {
				$peering->{'sen'}{$sen} = HM485::PeeringManager::loadDefaultPeerSettings($configTypeHash);
			}
			
			#todo validate address data
			$msg = HM485_ValidateSettings($configTypeHash, $sen, $peering->{'sen'}{$sen});
			
			if (!$msg) {
				$validatedConfig->{'sensor'}{$sen}{'value'} = $peering->{'sen'}{$sen};
				$validatedConfig->{'sensor'}{$sen}{'config'} = $senParams->{'sensor'}{'parameter'}{$sen};
				if ($sen eq 'sensor') {
					$validatedConfig->{'sensor'}{$sen}{'chan'} = $peering->{'act'}{'channel'};
				}
				$validatedConfig->{'sensor'}{$sen}{'peerId'} = $freeSen;
			}
		}
		
		if (!$msg) {
			
			my $old_set;
			my $convSenSettings = HM485::PeeringManager::convertPeeringsToEepromData(
				$senHash, $validatedConfig->{'sensor'});
			
			
			my $convActSettings = HM485::PeeringManager::convertPeeringsToEepromData(
				$hash, $validatedConfig->{'actuator'});
				
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
				#todo concatenate the data and send it once
				#if ($old_set->{'act'}{'adr'} && (hex ($old_set->{'act'}{'adr'}) + 1) == hex($adr)) {
				#	$adr = $old_set->{'act'}{'adr'};
				#	$size = sprintf ('%02X' , $size + $old_set->{'act'}{'size'});
					#$value .= sprintf ('%02X',$old_set->{'act'}{'value'});
				
				HM485::Device::internalUpdateEEpromData($devHash,$adr . $size . $value);		
				HM485_SendCommand($hash, $hmwId, '57' . $adr . $size . $value);
					
				$old_set->{'act'}{'adr'} = $adr;
				$old_set->{'act'}{'size'} = $size;
				$old_set->{'act'}{'value'} = $value;
			}
			
			foreach my $adr (sort keys %$convSenSettings) {
				
				HM485::Util::Log3($senHash, 4,'Set peersetting: ' . $convSenSettings->{$adr}{'text'});
		
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
				
				HM485::Device::internalUpdateEEpromData($senDevHash,$adr . $size . $value);
				HM485_SendCommand($senHash, $senHash->{'DEF'}, '57' . $adr . $size . $value);
				
				$old_set->{'sen'}{'adr'} = $adr;
				$old_set->{'sen'}{'size'} = $size;
				$old_set->{'sen'}{'value'} = $value;
				
			}
			
			#todo verify the correct sending, then send 0x43
			HM485_SendCommand($senHash, $senHash->{'DEF'}, '43');
		}
	} else {
		$msg = 'set peer argument "' . $values[0] . '" must be one of ' . join(', ', $peerList[0],$peerList[1],$peerList[2],'...');
	}
	
	return $msg;
}

sub HM485_SetUnpeer($@) {
	my ($hash, @values) = @_;
	
	shift(@values);
	shift(@values);
	
	my $pList	 = HM485::PeeringManager::getPeerableChannels($hash);
	
	my @peerList;
	my $fromAct = 0;
	
	if ($pList->{peered}) {
		@peerList = split(',',$pList->{peered});
	} elsif ($pList->{actpeered}) {
		@peerList = split(',',$pList->{actpeered});
		$fromAct = 1;
		HM485::Util::Log3 ($hash, 4, 'Set unpeer from actuator');
	}
	
	my $msg = '';
	
	if (@values == 1 && grep {$_ eq $values[0]} @peerList) {
		
		my ($senHmwId, $senCh) = HM485::Util::getHmwIdAndChNrFromHash($hash);
		my $actHmwId 	   	   = HM485::PeeringManager::getHmwIdByDevName($values[0]);
		
		$msg = HM485::PeeringManager::sendUnpeer($senHmwId, $actHmwId, $fromAct);
		
	} else {
		$msg = 'set unpeer argument "' . $values[0] . '" must be one of ' . join(',', @peerList);
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
	$configHash = $configHash->{parameter};
	# print(Dumper($configHash));
	foreach my $setConfig (keys %{$setConfigHash}) {
		my $configTypeHash = $configHash->{$setConfig};	# hash von behaviour
		$msg = HM485_ValidateSettings(
			$configTypeHash, $setConfig, $setConfigHash->{$setConfig}
		);
		HM485::Util::Log3( $hash, 4, 'HM485_SetConfig: name = ' . $name . ' Key = ' . $setConfig . ' Wert = ' . $setConfigHash->{$setConfig} . ' msg = ' . $msg);
		# Fehler? ...und tschuess
		if($msg) {
			return $msg;
		};
		$validatedConfig->{$setConfig}{value} = $setConfigHash->{$setConfig};	# Wert
		$validatedConfig->{$setConfig}{config} = $configHash->{$setConfig};  	# hash von behaviour
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


sub HM485_SetSettings($@) {
	my ($hash, @values) = @_;
	
	my $name = $hash->{'NAME'};
	shift(@values);
	shift(@values);

	my $msg = '';
	my $msgValueName = '';
	
	if (@values > 1) {
		my $peerId;
		my $actuator;
		# Split list of configurations
		my $cc = 0;
		my $configType;
		my $setSettingsHash = {};
		foreach my $value (@values) {
			$cc++;
			if ($cc % 2) {
				$configType = $value;
			} else {
				#changed values
				if ($configType) {
					if ($configType eq 'peerId') {
						$peerId = $value;	
					} elsif ($configType eq 'actuator') {
						$actuator = $value;
					} elsif ($value ne $hash->{'peerings'}{$configType}{'value'}) {
						$setSettingsHash->{$configType} = $value;	
						$configType = undef;
					}
				}
			}
		}
		
		my $actHash = $main::modules{'HM485'}{'defptr'}{$actuator};
		my $params = HM485::PeeringManager::getLinkParams($actHash);
		
		my $validatedConfig = {};
		foreach my $param (keys %{$setSettingsHash}) {
			$setSettingsHash->{$param} = HM485::PeeringManager::valueToSettings (
				$params->{'sensor'}{'parameter'}{$param},
				$setSettingsHash->{$param}
			);

			#validate settings
			$msg = HM485_ValidateSettings (
				$params->{'sensor'}{'parameter'}{$param},
				$param, $setSettingsHash->{$param}
			);
		
			if (!$msg) {
				$validatedConfig->{$param}{'value'} = $setSettingsHash->{$param};
				$validatedConfig->{$param}{'config'} = $params->{'sensor'}{'parameter'}{$param};
			} else {
				last;
			}
		}
		
		# If validation success
		if (!$msg) {
			$validatedConfig->{'sensor'}{'dummy'} = '0';
			$validatedConfig->{'channel'}{'peerId'} = $peerId;
			$validatedConfig->{'channel'}{'id'} = 'peer';
			$validatedConfig->{'channel'}{'value'} = $peerId;
						
			my $convertetSettings = HM485::PeeringManager::convertPeeringsToEepromData(
				$actHash, $validatedConfig
			);
			
			foreach my $adr (sort keys %$convertetSettings) {
				
				if ($adr) {
				
					HM485::Util::Log3($actHash, 4, 'Set setting: ' . $convertetSettings->{$adr}{'text'});
		
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
				
					HM485_SendCommand($actHash, $actHash->{'DEF'}, '57' . $adr . $size . $value);
				}
				
			}
			HM485_SendCommand($actHash, $actHash->{'DEF'}, '43');
			#update peerings
			delete $hash->{'peerings'};
		}
	} else {
		$msg = "direct set setting is not implemented. set the setting over the get peersettings mask";
	}
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
	
	if ($values->{'id'}) {
		#todo validate, if needed anymore
		print Dumper ("OJE eine ID SetChannelState"); 
		$values = HM485::Util::convertIdToHash($values);
	}
	
	# The command is either directly listed as parameter (level, state, frequency, stop,...)
	# or it is on,off,toggle
	my $valueKey = undef;
	if($values->{$cmd}) {
		$valueKey = $cmd;
	}elsif(index('on:off:toggle:up:down', $cmd) != -1) {
		# in this case use state, level or frequency
		foreach my $vKey (keys %{$values}) {
			if ($vKey eq 'state' || $vKey eq 'level' || $vKey eq 'frequency') {
				$valueKey = $vKey; #perl is weird sometimes
				last;
			}
		}
	}
	
	# now $valueKey is something sensible or empty/undef
	# (we are assuming that this routine is only called for sensible commands)
	if(!$valueKey) { return undef; }
		
	return ($valueKey, $values->{$valueKey});

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
	
	foreach my $valueKey (keys %{$values}) {
		if ($valueKey eq 'press_short'  || $valueKey eq 'press_long') {
			
			my $valueHash  = $values->{$valueKey} ? $values->{$valueKey} : '';
			my $control    = $valueHash->{'control'} ? $valueHash->{'control'} : '';
			my $frameValue = undef;
			my $peerHash;
			
			if (($cmd eq 'press_short' && $control eq 'button.short') || ($cmd eq 'press_long' && $control eq 'button.long')) {
				if ($control eq 'button.short' || $control eq 'button.long') {
					#we need the last counter from the readings
					my $lastCounter = $hash->{'READINGS'}{'sim_counter'}{'VAL'};
					$frameValue = HM485::Device::simCounter($valueHash, $cmd, $lastCounter);
				} else {
					$retVal = 'no press_short / press_long for this channel';
				}
				$frameData->{$valueKey} = {
					value    => $frameValue,
					physical => $valueHash->{'physical'}
				};
				
				if ($frameData) {
					my $frameType  = $valueHash->{'physical'}{'set'}{'request'};
					if (($frameType eq 'key_sim_short' && $cmd eq 'press_short') || 
						($frameType eq 'key_sim_long'  && $cmd eq 'press_long')) {
							
						$peerHash = HM485::PeeringManager::getLinksFromDevice($devHash);
						if ($peerHash->{'actuators'}) {
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
						} else {
							$retVal = 'no peering for this channel';
						}
					}
				}
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
		if ($logical->{type}) {

			if ($logical->{type} eq 'float' || $logical->{type} eq 'int') {
				if (HM485::Device::isNumber($value)) {
					if ($logical->{min} && $logical->{max}) {
						if ($value < $logical->{min}) {
							$msg = 'must be greater or equal then ' . $logical->{min};
						} elsif ($value > $logical->{max}) {
							$msg = 'must be smaller or equal then ' . $logical->{max};
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
		my $chNr 		= substr( $msgData, 2, 2);
		my $deviceKey	= '';
		my $LoggingTime = 2;
		
		# Check if main device exists or we need create it
		if ( $hash->{DEF} && $hash->{DEF} eq $hmwId) {
			if ($requestType ne '52') { 
				HM485::Util::Log3( $ioHash, 5, 'HM485_ProcessResponse: deviceKey = ' . $deviceKey . ' requestType = ' . $requestType . ' requestData = ' . $requestData . ' msgData = ' . $msgData);
			}
			
			$deviceKey 	= uc( HM485::Device::getDeviceKeyFromHash($hash));
			
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
				} elsif ( $deviceKey eq 'HMW_IO12_SW14_DR') {
					#
				}
			
				HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');
			
			} elsif ($requestType eq '52') {                                # R (report Eeprom Data)
				HM485_ProcessEepromData($hash, $requestData, $msgData);

			} elsif (grep $_ eq $requestType, ('68', '6E', '76')) {         # h (module type), n (serial number), v (firmware version)
				HM485_SetAttributeFromResponse($hash, $requestType, $msgData);
	
#			} elsif ($requestType eq '70') {                                # p (report packet size, only in bootloader mode)

#			} elsif ($requestType eq '72') {                                # r (report firmwared data, only in bootloader mode)
			} elsif ($requestType eq '73') {                                # s ( Aktor setzen)
				#if ( $deviceKey eq 'HMW_IO12_SW14_DR') {
					HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');
				#}
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
	
	if ($requestType eq '68') {
		$attrVal = HM485::Device::parseModuleType($msgData);  # ModulTyp z.B.: HMW_LC_Bl1_DR	
	} elsif ($requestType eq '6E') {
		$attrVal = HM485::Device::parseSerialNumber($msgData);
	
	} elsif ($requestType eq '76') {
		$attrVal = HM485::Device::parseFirmwareVersion($msgData);
	}

	if ($attrVal) {
		my $name     = $hash->{NAME};
		my $attrName = $HM485::responseAttrMap{$requestType};
		CommandAttr(undef, $name . ' ' . $attrName . ' ' . $attrVal);
	}
}

=head2
	Parse a event frame
	
	@param	hash    the hash of the io device
	@param	string  the message data
	
=cut
sub HM485_ProcessEvent($$) {
	my ($ioHash, $msgData) = @_;

	my $hmwId = substr( $msgData, 10, 8);
	$msgData  = (length($msgData) > 17) ? substr($msgData, 18) : '';
	HM485::Util::Log3( $ioHash, 5, 'HM485_ProcessEvent: hmwId = ' . $hmwId . ' msgData = ' . $msgData);

	if ($msgData) {
		my $devHash = $modules{HM485}{defptr}{$hmwId};

		# Check if main device exists or we need create it
		if ( $devHash->{DEF} && $devHash->{DEF} eq $hmwId) {
			HM485_ProcessChannelState($devHash, $hmwId, $msgData, 'frame');
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

	} elsif ( $ioHash->{'.forAutocreate'}{$hmwId}{'68'} &&
	     $ioHash->{'.forAutocreate'}{$hmwId}{'6E'} ) {

		my $serialNr = HM485::Device::parseSerialNumber (
			$ioHash->{'.forAutocreate'}{$hmwId}{'6E'}
		);
	
		my $modelType = $ioHash->{'.forAutocreate'}{$hmwId}{'68'};
		my $model     = HM485::Device::parseModuleType($modelType);
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
	my @waitForAckTypes   = ('21', '43', '57', '67', '6C', '73');

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
sub HM485_ProcessChannelState($$$$) {
	my ($hash, $hmwId, $msgData, $actionType) = @_;

    # device and message ok?
	if(!$msgData) {
	  HM485::Util::Log3( $hash, 3, 'HM485_ProcessChannelState: hmwId = ' . $hmwId .' No message');
	  return;
	}
	if(!$hash->{MODEL}) {
	  HM485::Util::Log3( $hash, 3, 'HM485_ProcessChannelState: hmwId = ' . $hmwId . ' No model');
	  return;
	}
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
	HM485_ChannelUpdate( $chHash, $valueHash->{value});
}


=head2
	Dispatch channel update by InternalTimer
	
	@param	hash    hash of the channel
	@param	hash    parameter hash	
=cut
sub HM485_ChannelUpdate($$) {
	my ($chHash, $valueHash) = @_;
	my $name = $chHash->{NAME};

	if ($valueHash && !AttrVal($name, 'ignore', 0)) {
		my %params = (chHash => $chHash, valueHash => $valueHash, doTrigger => 1);
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
	
	my $state = undef;  # in case we do not update state anyway, use the last parameter
    my $updateState = 1;
	
	HM485::Util::Log3($chHash, 4,'HM485_ChannelDoUpdate');
	readingsBeginUpdate($chHash);
	
	foreach my $valueKey (keys %{$valueHash}) {
		my $value = $valueHash->{$valueKey};
		
		if (defined($value)) {
			my $oldValue = $chHash->{READINGS}{$valueKey}{VAL} ? $chHash->{READINGS}{$valueKey}{VAL} : 'empty';
			HM485::Util::Log3( $chHash, 5, 'HM485_ChannelDoUpdate: valueKey = '.$valueKey.' value = '.$value.' Alter Wert = '.$oldValue);
			readingsBulkUpdate( $chHash, $valueKey, $value);
			HM485::Util::Log3( $chHash, 4, $valueKey . ' -> ' . $value);
			# State noch aktualisieren
			if ( $valueKey eq 'state') {
				$updateState = 0; # anyway updated
			} elsif(!defined($state) || $valueKey eq 'level' || $valueKey eq 'sensor' || $valueKey eq 'frequency') {
				$state = $valueKey . '_' . $value;
			}
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
	#todo .helper for witch chache should be deleted
	delete $hash->{'cache'};
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
	HM485 supports eQ-3 HomeMaticWired (HMW) devices<br>
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
	<ul>
		<li><code>set &lt;name&gt; <b>config</b> &lt;parameter&gt; &lt;value&gt; ...</code><br>
		This can be used to set configuration options in the HMW device. It only exists if there are configuration options. The configuration is stored directly in the device EEPROM. Instead of using this command, it is usually easier to change the configuration directly in the user interface.
		<ul>
			<li>&lt;parameter&gt;: This is the name of the configuration parameter, like "logging_time". Available parameters differ by the model of the device. They can be seen directly on the user interface.</li>
			<li>&lt;value&gt;: This is the new value to be set. For boolean parameters or options (like yes/no or switch/pushbutton), the internal values (like 0/1) need to be used.</li>
		</ul>
		You can use multiple &lt;parameter&gt; &lt;value&gt; pairs in one command. The following command would set both "input_locked" to "yes" and "long_press_time" to 5 seconds.<br>
		<code>set &lt;name&gt; config input_locked 1 long_press_time 5.00</code>
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
		<li><code>set &lt;name&gt; <b>settings</b> ...</code><br>
		This is used internally to set configuration parameters for peerings. It cannot be used directly and it might even happen that this command is removed in the future.</li>
	</ul>
	<br>
	The set options config, peer, settings and unpeer are generally available on channel level.
	<ul>
		<li><code>set &lt;channel&gt; <b>config</b> &lt;parameter&gt; &lt;value&gt; ...</code><br>
		This is the same as <code>set &lt;name&gt; config</code> on device level, only for configuration options on channel level. See <code>set &lt;name&gt; config</code> on device level for details.
		</li>
		<br>
		<li><code>set &lt;sensor-channel&gt; <b>peer</b> &lt;actor-channel&gt;</code><br>
		Channels of Homematic Wired devices can be peered directly. This e.g. can trigger to switch on an actor when a key is pressed on a sensor, even if FHEM is down. However, it depends on the sensor-actor combination what the peering actually does. In FHEM, peering of HMW channels is done from the sensor channel (e.g. the key). Consequently, <code>set ... peer</code> is not possible for actor channels.<br>
		When using <code>set ... peer</code> from the input mask in Fhemweb, a drop down list shows the actor channels which are available for peering.
		</li>
		<br>
		<li><code>set &lt;channel&gt; <b>settings</b> ...</code><br>
		This is used internally to set configuration parameters for peerings. It cannot be used directly and it might even happen that this command is removed in the future.</li>
		<br>
		<li><code>set &lt;channel&gt; <b>unpeer</b> &lt;peered-channel&gt;</code><br>
		This command is used to delete a peering. It can be used from both the sensor and the actor side. When using it from the input mask in Fhemweb, a drop down list with currently peered channel is provided.
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
		The get options <code>config</code> and <code>info</code> are available on device level. <code>state</code> and <code>peersettings</code> are for channels. (<code>state</code> also appears on device level, but does not do anything sensible. It might be removed.)  
		<br>
		<ul>
		<li><code>get &lt;device&gt; <b>config all</b></code><br>
		For HMW devices, the configuration data is stored in the device itself. <code>get ... config all</code> triggers reading the configuration data from the device. This also includes the state of all channels. In normal operation, this command is not needed as FHEM automatically reads the configuration data from the device at least on startup and when a new device is created in FHEM. When changing configuration data from FHEM, everything is synchronized automatically as well. However, when the device configuration is changed outside FHEM, an explicit <code>get ... config all</code> is needed. (This e.g. happens when devices are peered using the buttons on the devices directly.) In addition, things go wrong. If in doubt, you can do a <code>get ... config all</code>, but give the system the chance to read all the data. (Also see reading <code>configStatus</code>.)
		</li>
		<br>
		<li><code>get &lt;device&gt; <b>info</b></code><br>
		This reads the device information only, i.e. module type, serial number and firmware version. The command is usually not needed as reading this information is included in <code>get ... config all</code>.
		</li>
		<br>
		<li><code>get &lt;channel&gt; <b>state</b></code><br>
		This command updates the state of a channel, if possible. Technically, it sends a request to the device to send back the state of the channel. This is usually only implemented by actor channels. In this case, the readings <code>state</code> and other readings showing the channel's state are updated (like e.g. <code>working</code> and <code>level</code> for shutter actors). 
		</li>
		<br>
		<li><code>get &lt;sensor-channel&gt; <b>peersettings</b> &lt;actor-channel&gt;</code><br>
		This command is used to show and maintain the settings of a peering. Each peering has a number of settings which influences what the peering actually does. E.g. <code>short_on_time</code> controls how long a switch stays switched on when triggered by a short key press. These settings are attributes of the peering itself, i.e. (basically) the combination of the sensor channel and the actor channel.<br>
		When using the <code>get ... peersettings</code> command, the view is extended by the possible settings of the peering. You can then change the values and hit &lt;enter&gt; or the "Save Settings" button at the end of the list.
		</li>
		</ul>
		<br>
		<b>Readings</b>
		<br>
		<ul>
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
		<br>
		The following attributes are read from the device itself and cannot be changed.
		<br>
		<ul>
		<li><b>serialNr</b>: Serial number of the device.</li>
		<li><b>model</b>: Model of the device, like "HMW_LC_Sw2_DR".</li>
		<li><b>firmwareVersion</b>: Version of the device firmware.</li>
		<li><b>subType</b>: Type of a channel, like e.g. "switch", "key" or "blind".</li>
		</ul>
	
</ul>
=end html
=cut
