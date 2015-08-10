=head1
	10_HM485.pm

	Version 0.7.14	
				 
=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013
	$Id$

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

# FHEM Inteface related functions
sub HM485_Initialize($);
sub HM485_Define($$);
sub HM485_Undefine($$);
sub HM485_Rename($$);
sub HM485_WaitForConfig($);
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

#PFE BEGIN
sub HM485_GetNewMsgQueue($$$$);
sub HM485_QueueStepFailed($);
sub HM485_QueueStepSuccess($);
#PFE END



my @attrListRO     = ();
my @attrListBindCh = ('model', 'serialNr', 'firmwareVersion', 'room', 'comment');

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

# Default get comands for channel
my %getsCh = ('state' => 'noArg');

# Bei vielen Modulen ist eine Wartezeit beim Define erforderlich
my $defWait  = 0;
my $defStart = 5;

#PFE BEGIN
# List of "message queues" for e.g. reading config 
my @msgQueueList = ();
my $currentQueueIndex = -1; #index of current queue
#PFE END


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

	$hash->{'AttrList'}       = 'do_not_notify:0,1 ' .
	                          'ignore:1,0 dummy:1,0 showtime:1,0 serialNr ' .
	                          'model:' . HM485::Device::getModelList() . ' ' .
	                          'subType stateFormat firmwareVersion setList ' .
	                          'event-min-interval event-aggregator ' .
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

	RemoveInternalTimer($hash);  # TODO: Wofuer? honk fragen?
	if (int(@a)!=3 || (defined($a[2]) && $a[2] !~ m/^[A-F0-9]{8}_{0,1}[A-F0-9]{0,2}$/i)) {
		$msg = 'wrong syntax: define <name> HM485 <8-digit-hex-code>[_<2-digit-hex-code>]';

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
				$hash->{chanNo}    = $chNr;						# reference the device to this channel
				

			} else {
				$msg = 'Please define the main device ' . $addr . ' before define the device channel';
			} 
			
		} else {
			# We defined a the device
			AssignIoPort($hash);

			HM485::Util::logger(
				HM485::LOGTAG_HM485, 2,
				'Assigned ' . $name . ' (' . $addr . ') to ' . $hash->{IODev}->{NAME}
			);
		}

		if (!$msg) {
			
			$modules{'HM485'}{'defptr'}{$hmwId} = $hash;
			$hash->{'DEF'} = $hmwId;
			
			if ( defined($hash->{'IODev'}{'STATE'}) && length($hmwId) == 8) {
			
#PFE BEGIN
				#PFE BEGIN
				$hash->{CONFIG_STATUS} = 'PENDING';
				#PFE END
# We can always use WaitForConfig. It will do it's job eventually in any case.		
				$hash->{'.waitforConfig'}{'hmwId'} 		= $addr;
				$hash->{'.waitforConfig'}{'counter'}	= 10;
				HM485_WaitForConfig($hash);	
				# if ($hash->{IODev}{STATE} eq 'open') {
					# # das hat er bei mir noch nie geschafft, da Raspi zu langsam
					# #PFE: Bei mir immer...
					# HM485::Util::logger(
						# HM485::LOGTAG_HM485, 2, 'Auto get info for : ' . $name
					# );	
					# HM485_GetInfos($hash, $addr, 0b111);
# #					HM485_GetConfig($hash, $addr);
				# } else {
					# # Todo: Maybe we must queue "auto get info" if IODev not opened yet 
					# # Moduldaten aus Eeprom holen, nach 4 Sec, um HM485_LAN vorher in den State opened zu bringen
					# #InternalTimer( gettimeofday() + $defStart + $defWait, 'HM485_GetInfos', $hash . ' ' . $addr . ' 7', 0);
					# # Konfiguration des Moduls in Speicher übernehmen und Channels anlegen und einlesen
					# #InternalTimer( gettimeofday() + $defStart + 4 + $defWait, 'HM485_GetConfig', $hash . ' ' . $addr, 0);
					# # ++++++++++++++++++++++
					# $hash->{'.waitforConfig'}{'hmwId'} 		= $addr;
					# $hash->{'.waitforConfig'}{'counter'}	= 10;
					# HM485_WaitForConfig($hash);
				# }
#PFE END				
				$defWait++;
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
	my ($hash, $name) = @_;

	my $devName        = $hash->{device};
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	if ($chNr > 0) {
		my $devHash = $defs{$devName};
		
		if ($devName) {
			# We delete a device with all channels
			delete $devHash->{'channel_' . $chNr} if ($devName);
		}

	} else {
		# Delete each channel of device
		foreach my $devName (grep(/^channel_/, keys %{$hash})) {
			CommandDelete(undef, $hash->{$devName})
		} 
	}
	
	delete($modules{HM485}{defptr}{$hmwId});
	
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
		$hash->{chanNo} = $chNr;
		my $devHash = HM485_GetHashByHmwid( substr( $hmwId, 0, 8));
		$hash->{device} = $devHash->{NAME};
		$devHash->{'channel_' . $hash->{chanNo}} = $name;

	} else{
		# we are a device - inform channels if exist
		foreach my $devName ( grep(/^channel_/, keys %{$hash})) {
			my $chnHash = $defs{ $hash->{$devName}};
			$chnHash->{device} = $name;
		} 
	}
}

#PFE BEGIN

# sub HM485_WaitForConfig($) {
	# my ($hash) = @_;
	
	# my $hmwId = $hash->{'.waitforConfig'}{'hmwId'};
	# my $counter = $hash->{'.waitforConfig'}{'counter'};
	
	# if (defined($hash->{'IODev'}{'STATE'})) {
		# if ($hash->{'IODev'}{'STATE'} eq 'open') {
			# if ( $hmwId) {
				# # Moduldaten aus Eeprom holen, nach 4 Sec, um HM485_LAN vorher in den State opened zu bringen
				# # Konfiguration des Moduls in Speicher übernehmen und Channels anlegen und einlesen
				# InternalTimer( gettimeofday() + $defStart + 4 + $defWait, 'HM485_GetConfig', $hash . ' ' . $hmwId, 0);
				# #HM485_GetInfos($hash, $hmwId, 0b111);
				# #HM485_GetConfig($hash, $hmwId);
				# delete $hash->{'.waitforConfig'};
				# RemoveInternalTimer($hash);
				# HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Initialisierung von Modul ' . $hmwId);
			# }
		# } else {
			# HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Warte auf Initialisierung Gateway');
			# if ($counter >= 0) {
				# $hash->{'.waitforConfig'}{'counter'} = $counter--;
				# InternalTimer (gettimeofday() + $defStart, 'HM485_WaitForConfig', $hash, 0);
			# } else {
				# delete $hash->{'.waitforConfig'};
				# RemoveInternalTimer($hash);
			# }
		# }
	# }
# }


sub HM485_WaitForConfig($) {
	my ($hash) = @_;
	
	my $hmwId = $hash->{'.waitforConfig'}{'hmwId'};
	my $counter = $hash->{'.waitforConfig'}{'counter'};
	
	if (defined($hash->{'IODev'}{'STATE'})) {
		if ($hash->{'IODev'}{'STATE'} eq 'open') {
			if ( $hmwId) {
			    # Tell them that we are reading config
			    HM485_SetConfigStatus($hash, 'READING');
				# the queue definition below will start GetConfig after successful GetInfos
				my $queue = HM485_GetNewMsgQueue('HM485_GetConfig',[$hash,$hmwId],
				                                 'HM485_SetConfigStatus',[$hash,'FAILED']);
				HM485_GetInfos($hash, $hmwId, 0b111, $queue);
				#HM485_GetInfos($hash, $hmwId, 0b111);
				#HM485_GetConfig($hash, $hmwId);
				delete $hash->{'.waitforConfig'};
				RemoveInternalTimer($hash);
				HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Initialisierung von Modul ' . $hmwId);
			}
		} else {
			HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Warte auf Initialisierung Gateway');
			if ($counter >= 0) {
				$hash->{'.waitforConfig'}{'counter'} = $counter--;
				InternalTimer (gettimeofday() + $defStart, 'HM485_WaitForConfig', $hash, 0);
			} else {
				delete $hash->{'.waitforConfig'};
				RemoveInternalTimer($hash);
			}
		}
	}
}

#PFE END

=head2
	Implements the parse function
	
	@param	hash	the hash of the IO device
	@param	string	message to parse
=cut
sub HM485_Parse($$) {
	my ($ioHash, $message) = @_;
	my $msgId   = ord(substr($message, 2, 1));
	HM485::Util::logger('HM485_Parse', 5, 'MsgId: '.$msgId);
	my $msgCmd  = ord(substr($message, 3, 1));
	my $msgData = uc( unpack ('H*', substr($message, 4)));

	if ($msgCmd == HM485::CMD_RESPONSE) {
		HM485_SetStateAck($ioHash, $msgId, $msgData);
		HM485::Util::logger('HM485_Parse', 5, 'ProcessResponse');
		HM485_ProcessResponse($ioHash, $msgId, substr($msgData,2));

	} elsif ($msgCmd == HM485::CMD_EVENT) {
		HM485_SetStateAck($ioHash, $msgId, $msgData);
    	HM485::Util::logger('HM485_Parse', 5, 'ProcessEvent');
		HM485_ProcessEvent($ioHash, $msgData);
	} elsif ($msgCmd == HM485::CMD_ALIVE && substr($msgData, 0, 2) eq '01') {
		#PFE BEGIN
	    # Stop queue if running
	    HM485_QueueStepFailed($msgId);
	    #PFE END
		HM485_SetStateNack($ioHash, $msgData);
		my $requestType = $ioHash->{'.waitForResponse'}{$msgId}{requestType};
		my $hmwId = substr( $msgData, 2, 8);
		my $devHash = HM485_GetHashByHmwid( $hmwId);
		if ( $requestType && $requestType eq '52') {
			if ( !exists( $devHash->{'.waitforConfig'}{'counter'})) {
				# Konfiguration des Moduls erneut abfragen in Speicher uebernehmen und Channels anlegen und einlesen
				InternalTimer( gettimeofday() + 17, 'HM485_GetInfos', $devHash . ' ' . $hmwId . ' 7', 0);
				InternalTimer( gettimeofday() + 20, 'HM485_GetConfig', $devHash . ' ' . $hmwId, 0);
			#	$devHash->{'.Reconfig'} = 1;
				HM485::Util::HM485_Log( 'HM485_Parse: fuer Modul = ' . $hmwId . ' wird Configuration erneut abgefragt');
			}
		}
	}
	
	return $ioHash->{NAME};
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
	
	# HM485::Util::HM485_Log( 'HM485_Set: name = ' . $name . ' cmd = ' . $cmd . ' value = ' . $value . ' hmwId = ' . $hmwId . ' chNr = ' .  $chNr);
	my %sets = ();
	my $peerList;
	
	if ( $chNr > 0) {
		%sets = %setsCh;
		my $allowedSets = HM485::Device::getAllowedSets($hash);
		# HM485::Util::HM485_Log( 'HM485_Set: name = ' . $name . ' chNr = ' .  $chNr . ' allowedSets = ' . $allowedSets);
		if ($allowedSets) {
			foreach my $setValue (split(' ', $allowedSets)) {
				my($setValue, $param) = split(':', $setValue);
				if ($param) {
					if ($param eq 'noArg') {
						$param = '';
					}
				}
				$sets{$setValue} = $param;
				# HM485::Util::HM485_Log( 'HM485_Set', 3, $setValue . ' = ' . $param);
			}
		}
		
		$peerList = HM485::PeeringManager::getPeerableChannels($hash);
				
		if ($peerList->{'peerable'}) {
			$sets{'peer'} = $peerList->{'peerable'};
		}
		if ($peerList->{'peered'}) {
			$sets{'unpeer'} = $peerList->{'peered'};
		}
	} else {
		#HM485::PeeringManager::getLinksFromDevice($hash);
		%sets = %setsDev;
	}

	# add config setter if config for this device or channel available
	#my $configHash = HM485::ConfigurationManager::getConfigFromDevice($hash, $chNr);
	#if (scalar (keys %{$configHash})) {
    #		$sets{'config'} = '';
	#}
	
	if ($hash->{'.configManager'}) {
		$sets{'config'} = '';
		$sets{'settings'} = '';
	}
	
	
	#PFE BEGIN
	# raw geht immer beim Device
	if(!$chNr) {
	  $sets{'raw'} = '';
	};
	#PFE END	

	# HM485::Util::HM485_Log( 'HM485_Set', 3, 'cmd = ' . $cmd);
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
				readingsSingleUpdate($hash, 'state', $cmd .' '.$counter, 1);
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
				readingsSingleUpdate($hash, $cmd, $value, 1);
				$msg = HM485_SetChannelState($hash, $cmd, $value);			
			} elsif ( $cmd eq 'on-for-timer') {
				my $state = uc( ReadingsVal( $name, 'state', 'off'));
				if ( $value && $value > 0) {
					$state = 'on';
					$msg = HM485_SetChannelState($hash, $state, $value);
					HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'set ' . $name . ' on-for-timer ' . $value);
					$state = 'off';
					InternalTimer( gettimeofday() + $value, 'fhem', 'set ' . $name . ' ' . $state, 0 );
				} else {
					$state = 'off';
					$msg = HM485_SetChannelState($hash, $state, $value);
				}
			} elsif ($cmd eq 'raw') {
				HM485_SendCommand($hash, $hmwId, $value);
			# "else" includes level, stop, on, off, toggle
			} else {  
				my $state = 'set_'.$cmd;
				if($value) { $state .= '_'.$value; }
				readingsSingleUpdate($hash, 'state', $state, 1);
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
				# HM485::Util::logger( 'HM485_Get', 3, 'arg = ' . $arg);
				$arguments.= $arg . ($gets{$arg} ? (':' . $gets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;

		} elsif ($cmd eq 'info') {
			# all infos (moduleType, serialNumber, firmwareVersion)
			HM485_GetInfos($hash, $hmwId, 0b111);

		} elsif ($cmd eq 'config') {
			# get module config (eeprom data)
			HM485_GetConfig($hash, $hmwId);
		} elsif ($cmd eq 'state') {
			# abfragen des aktuellen Status
			# HM485::Util::HM485_Log( 'HM485_Get: get state fuer name = ' . $name . ' chNr = ' . $chNr);
			$data = sprintf ('53%02X', $chNr-1);  # Channel als hex- Wert
			HM485_SendCommand( $hash, $hmwId, $data);
		} elsif ($cmd eq 'peersettings') {
			HM485_GetPeerSettings($hash, $args);	
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

	# HM485::Util::logger( 'HM485_FhemwebShowConfig', 3, 'fwName = ' . $fwName . ' name = ' . $name . ' roomName = ' . $roomName);
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

#PFE BEGIN
sub HM485_SetConfigStatus($$) {
  my ($hash, $status) = @_;
  HM485::Util::logger( 'HM485_SetConfigStatus', 5, 'Hash: '.$hash);
  $hash->{CONFIG_STATUS} = $status;
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
	
	# HM485::Util::HM485_Log( 'HM485_GetInfos: hmwId = ' . $hmwId . ' infoMask = ' . $infoMask);
	
	$infoMask = defined($infoMask) ? $infoMask : 0;
	#if not started with a queue, then create an own one, but without callbacks
	$queue = defined($queue) ? $queue : HM485_GetNewMsgQueue(undef,undef,undef,undef);
	
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
	
	HM485_QueueStart($queue);
}
#PFE END


=head2
	Request device config stoerd in the eeprom of a device
	ToDo: check model var and if we must clear eepromdata before 
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
=cut



















#Last step of config, after reading of EEPROM
sub HM485_CreateAndReadChannels($$) {
	my ($devHash, $hmwId) = @_;
	# Channels anlegen
	my $deviceKey = uc( HM485::Device::getDeviceKeyFromHash($devHash));
	HM485::Util::logger( HM485::LOGTAG_HM485, 4, 'Channels initialisieren ' . substr($hmwId, 0, 8));
	HM485_CreateChannels( $devHash);
	# HM485_Log( 'HM485_GetConfig: ' . 'deviceKey = ' . $deviceKey . ' hmwId = ' . $hmwId);
	# State der Channels ermitteln
	my $configHash = HM485::Device::getValueFromDefinitions( $deviceKey . '/channels/');
	HM485::Util::logger( HM485::LOGTAG_HM485, 4, 'State der Channels ermitteln ' . substr($hmwId, 0, 8));
	#create a queue, so we can set the config status afterwards
	my $queue = HM485_GetNewMsgQueue('HM485_SetConfigStatus',[$devHash,'OK'],
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
	HM485_QueueStart($queue);
}


sub HM485_GetPeerSettings($$) {
	my ($hash, $arg) = @_;
	
	my $sensor   = $hash->{DEF};
	my $peerHash = HM485::PeeringManager::getPeerSettingsFromDevice($arg, $sensor);
	
	$hash->{peerings} = $peerHash;
	
	HM485::Util::logger(
		HM485::LOGTAG_HM485, 4, 'Get peer settings for device ' . $sensor . ' -> ' . $arg
	);
	
	FW_directNotify("#FHEMWEB:WEB", "location.reload(true);","" ); 
	
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
		HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Request config for device ' . substr($hmwId, 0, 8));
		my $eepromMap = HM485::Device::getEmptyEEpromMap($devHash);
		
		# write eeprom map to readings
		foreach my $adrStart (sort keys %{$eepromMap}) {
			setReadingsVal($devHash, '.eeprom_' . $adrStart, $eepromMap->{$adrStart}, TimeNow());
		}
				
		HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Lese Eeprom ' . substr($hmwId, 0, 8));
		
		# Tell them that we are reading config
		HM485_SetConfigStatus($hash, 'READING');
		#Get a new queue for reading the EEPROM
		#This definition will automatically start reading the channels after EEPROM reading
		#is successful
		my $queue = HM485_GetNewMsgQueue('HM485_CreateAndReadChannels',[$devHash,$hmwId],
				                         'HM485_SetConfigStatus',[$hash,'FAILED']);
		
		foreach my $adrStart (sort keys %{$eepromMap}) {
			# (R) request eeprom data
			HM485_QueueCommand($queue, $devHash, $hmwId, '52' . $adrStart . '10'); 
		}
		# start the queue, create and read channels afterwards.
		HM485_QueueStart($queue);		
	#	delete( $devHash->{'.Reconfig'});
	} else {
		HM485::Util::logger( HM485::LOGTAG_HM485, 3, 'Initialisierungsfehler ' . substr( $hmwId, 0, 8) . ' ModelName noch nicht vorhanden');
		if ( !exists( $devHash->{'.waitforConfig'}{'counter'})) {
			$devHash->{'.waitforConfig'}{'hmwId'} 	= $hmwId;
			$devHash->{'.waitforConfig'}{'counter'}	= 10;
			HM485_WaitForConfig($devHash);
		}
	}
}
#PFE END

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
	
	if (ref($subTypes) eq 'HASH') {
		foreach my $subType (sort keys %{$subTypes}) {
			if ( $subType && uc( $subType) ne 'MAINTENANCE') {
				# HM485::Util::HM485_Log('HM485_CreateChannels deviceKey = ' . $deviceKey . ' subType = ' . $subType);
				if ( defined($subTypes->{$subType}{count}) && $subTypes->{$subType}{count} > 0) {
					my $chStart = $subTypes->{$subType}{index};
					my $chCount = $subTypes->{$subType}{count};
					for(my $ch = $chStart; $ch < ($chStart + $chCount); $ch++) {
						my $txtCh = sprintf ('%02d' , $ch);
						my $room = AttrVal($name, 'room', '');
						my $devName = $name . '_' . $txtCh;
						my $chHmwId = $hmwId . '_' . $txtCh;
						
						# HM485::Util::HM485_Log('HM485_CreateChannels deviceKey = ' . $deviceKey . ' devName = ' . $devName . ' chHmwId = ' . $chHmwId);
						if (!$modules{HM485}{defptr}{$chHmwId}) {
							CommandDefine(undef, $devName . ' ' . ' HM485 ' . $chHmwId); # HM485_Define wird aufgerufen
						} else {
							# Channel- Name aus define wird gesucht, um weitere Attr zuzuweisen
							my $devHash = $modules{HM485}{defptr}{$chHmwId};
							$devName    = $devHash->{NAME};
							# HM485::Util::HM485_Log('HM485_CreateChannels devName = ' . $devName);
						}
						CommandAttr(undef, $devName . ' subType ' . $subType);
						
						if ($subType eq 'key') {
								# Key subtypes don't have a state
								delete($modules{HM485}{defptr}{$chHmwId}{STATE});
						}
						if($subType eq 'blind') {
							# Blinds go up and down
							CommandAttr(undef, $devName . ' webCmd up:down');
						}
						# copy definded attributes to channel
						foreach my $attrBindCh (@attrListBindCh) {
							my $val = AttrVal($name, $attrBindCh, undef);
							my $cval= AttrVal($devName, $attrBindCh, undef);
							# Bereits definierte Attr weren nicht ueberschrieben
							if ( !defined( $cval)) {
								if (defined($val) && $val) {
									CommandAttr(undef, $devName . ' ' . $attrBindCh . ' ' . $val);
								}
							}
						}
					} 
				}
			}
		}
	}
}


sub HM485_SetReset($@) {
	my ($hash, @values) =@_;
	
	my $value;
	my $emtyMap = HM485::Device::getEmptyEEpromMap($hash);
	
	#todo get default settings from xml
	foreach my $adr (keys %{$emtyMap}) {
		if ($adr eq '0000') {
			$value = 'FF1400000001FEFFFFFFFFFFFFFFFFFF';
			HM485_SendCommand($hash, $hash->{'DEF'}, '57' . $adr . 10 . $value);
		} else {
			
			$value = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
			HM485_SendCommand($hash, $hash->{'DEF'}, '57' . $adr . 10 . $value);
		}
		
	}
	
	HM485_SendCommand($hash, $hash->{'DEF'}, '43');
}


sub HM485_SetPeer($@) {
	my ($hash, @values) = @_;
	
	shift(@values);
	shift(@values);

	my $msg = '';
	
	
	if (@values == 1) {
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
		$peering->{'sen'} = HM485::PeeringManager::loadDefaultPeerSettings($chType);
		$peering->{'sen'}{'channel'} 	= int ($actCh -1);
		$peering->{'sen'}{'actuator'} 	= $hmwId;
		$peering->{'sen'}{'sensor'} 	= substr($hash->{'DEF'},0,8);
	
		my $aktParams = HM485::PeeringManager::getLinkParams($devHash);
		my $senParams = HM485::PeeringManager::getLinkParams($senDevHash);
		my $freeAct   = HM485::PeeringManager::getFreePeerId($devHash,'actuator');
		my $freeSen   = HM485::PeeringManager::getFreePeerId($senDevHash,'sensor');
		
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
			if (!defined($peering->{'sen'}{$sen})) {
				$peering->{'sen'}{$sen} = HM485::PeeringManager::loadDefaultPeerSettingsneu($configTypeHash);
				#print Dumper ("validate $sen",$configTypeHash->{logical}{default},$peering->{'sen'}{$sen});
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
				HM485::Util::logger (
						HM485::LOGTAG_HM485, 4,
						'Set peersetting for ' . $hash->{'NAME'} . ': ' . $convActSettings->{$adr}{'text'}
					);

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
			#}
			foreach my $adr (sort keys %$convSenSettings) {
				
				HM485::Util::logger (
						HM485::LOGTAG_HM485, 4,
						'Set peersetting for ' . $senHash->{'NAME'} . ': ' . $convSenSettings->{$adr}{'text'}
					);
		
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
		$msg = 'set peer needs 1 parameter';
	}
	
	return $msg;
}

sub HM485_SetUnpeer($@) {
	my ($hash, @values) = @_;
	
	shift(@values);
	shift(@values);
	my ($senHmwId, $senCh) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $actHmwId 	   	   = HM485::PeeringManager::getHmwIdByDevName($values[0]);
	my $actCh 		  	   = int(substr($actHmwId,9,2));

	my $msg = '';
	
	if (@values == 1) {
		
		my $config;
		my $actHash = $main::modules{'HM485'}{'defptr'}{substr($actHmwId,0,8)};
		my $senHash = $main::modules{'HM485'}{'defptr'}{substr($hash->{'DEF'},0,8)};
		my $actParams = HM485::PeeringManager::getLinkParams($actHash);
		my $senParams = HM485::PeeringManager::getLinkParams($senHash);
		my $actPeerId = HM485::PeeringManager::getPeerId($actHash,$senHmwId,$actCh,0);
		my $senPeerId = HM485::PeeringManager::getPeerId($senHash,$actHmwId,int($senCh),1);
		
		$config->{'sen'}{'sensor'}{'value'} = 'FFFFFFFFFF';
		$config->{'sen'}{'sensor'}{'config'} = $actParams->{'sensor'}{'parameter'}{'sensor'};
		$config->{'sen'}{'sensor'}{'chan'} = $actCh;
		$config->{'sen'}{'channel'}{'value'} = hex('FF');
		$config->{'sen'}{'channel'}{'config'} = $actParams->{'sensor'}{'parameter'}{'channel'};
		$config->{'sen'}{'channel'}{'peerId'} = $actPeerId;
		
		$config->{'act'}{'actuator'}{'value'} = 'FFFFFFFFFF';
		$config->{'act'}{'actuator'}{'config'} = $senParams->{'actuator'}{'parameter'}{'actuator'};
		$config->{'act'}{'actuator'}{'chan'} = $senCh;
		$config->{'act'}{'channel'}{'value'} = hex('FF');
		$config->{'act'}{'channel'}{'config'} = $senParams->{'actuator'}{'parameter'}{'channel'};
		$config->{'act'}{'channel'}{'peerId'} = $senPeerId;
		
		my $senSettings = HM485::PeeringManager::convertPeeringsToEepromData(
					$actHash, $config->{'sen'});
		my $actSettings = HM485::PeeringManager::convertPeeringsToEepromData(
					$senHash, $config->{'act'});
		
		foreach my $adr (sort keys %$senSettings) {
		
			my $size  = $senSettings->{$adr}{'size'} ? $senSettings->{$adr}{'size'} : 1;
			my $value = $senSettings->{$adr}{'value'};
			
			if ($senSettings->{$adr}{'le'}) {
					if ($size >= 1) {
						$value = sprintf ('%0' . ($size*2) . 'X' , $value);
						$value = reverse( pack('H*', $value) );
						$value = hex(unpack('H*', $value));
					}
				}
				
			$size     = sprintf ('%02X' , $size);
				
			if (index($senSettings->{$adr}{'text'}, 'sensor') > -1) {						
				$value = sprintf ('%s', $value);
			} else {
				$value = sprintf ('%0' . ($size * 2) . 'X', $value);
			}
				
			HM485::Util::logger ( HM485::LOGTAG_HM485, 4,
				'Set unpeer for ' . $actHmwId . ': ' .
				$senSettings->{$adr}{'text'}
			);
			
			$adr = sprintf ('%04X' , $adr);
			HM485::Device::internalUpdateEEpromData($actHash,$adr . $size . $value);
			HM485_SendCommand($actHash, $actHmwId, '57' . $adr . $size . $value);
			

		}
		
		foreach my $adr (sort keys %$actSettings) {
			
			my $size  = $actSettings->{$adr}{'size'} ? $actSettings->{$adr}{'size'} : 1;
			my $value = $actSettings->{$adr}{'value'};
			
			if ($actSettings->{$adr}{'le'}) {
				if ($size >= 1) {
					$value = sprintf ('%0' . ($size*2) . 'X' , $value);
					$value = reverse( pack('H*', $value) );
					$value = hex(unpack('H*', $value));
				}
			}
					
			$size = sprintf ('%02X' , $size);
			if (index($actSettings->{$adr}{'text'}, 'actuator') > -1) {						
				$value = sprintf ('%s', $value);
			} else {
				$value = sprintf ('%0' . ($size * 2) . 'X', $value);
			}
			
			HM485::Util::logger ( HM485::LOGTAG_HM485, 4,
				'Set unpeer for ' . $senHmwId . ': ' . 
				$actSettings->{$adr}{'text'}
			);
			
			$adr = sprintf ('%04X' , $adr);
			HM485::Device::internalUpdateEEpromData($senHash,$adr . $size . $value);
			HM485_SendCommand($hash, $senHmwId, '57' . $adr . $size . $value);
							
		}
		
		HM485_SendCommand($hash, $senHmwId, '43');
	}
	
	return $msg;
}


sub HM485_SetConfig($@) {
	my ($hash, @values) = @_;

	my $name = $hash->{NAME};
	shift(@values);
	shift(@values);

	my $msg = '';
	my ($hmwId1, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash        = $main::modules{HM485}{defptr}{substr($hmwId1,0,8)};
	# my $deviceKey      = HM485::Device::getDeviceKeyFromHash($devHash);
	if (@values > 1) {
		# Split list of configurations
		my $cc = 0;
		my $configType;
		my $setConfigHash = {};
		foreach my $value (@values) {
			#HM485_Log( 'HM485_SetConfig: name = ' . $name . ' value = ' . $value);
			#HM485::Util::logger( 'HM485_SetConfig', 3, 'name = ' . $name . ' value = ' . $value);
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
		if (scalar (keys %{$setConfigHash})) {
			$configHash = HM485::ConfigurationManager::getConfigSettings($hash);
			$configHash = $configHash->{parameter};
			
			foreach my $setConfig (keys %{$setConfigHash}) {
				my $configTypeHash = $configHash->{$setConfig};	# hash von behaviour
				# HM485::Util::logger( 'HM485_SetConfig', 3, 'name = ' . $name . ' Key = ' . $setConfig . ' Wert = ' . $setConfigHash->{$setConfig} . ' msg = ' . $msg);
				$msg = HM485_ValidateSettings(
					$configTypeHash, $setConfig, $setConfigHash->{$setConfig}
				);
				# HM485_Log( 'HM485_SetConfig: name = ' . $name . ' Key = ' . $setConfig . ' Wert = ' . $setConfigHash->{$setConfig} . ' msg = ' . $msg);
				HM485::Util::logger( 'HM485_SetConfig', 3, 'name = ' . $name . ' Key = ' . $setConfig . ' Wert = ' . $setConfigHash->{$setConfig} . ' msg = ' . $msg);
				if (!$msg) {
					$validatedConfig->{$setConfig}{value} = $setConfigHash->{$setConfig};	# Wert
					$validatedConfig->{$setConfig}{config} = $configHash->{$setConfig};  	# hash von behaviour
					$validatedConfig->{$setConfig}{valueName} = $setConfig;
				} else {
					last;
				}
			}
		}
		
		# If validation success
		if (!$msg) {
			my $convertetSettings = HM485::ConfigurationManager::convertSettingsToEepromData(
				$hash, $validatedConfig
			);

			if (scalar (keys %{$convertetSettings})) {
			 	my $hmwId = $hash->{DEF};

			#	my $stateFormat = HM485::ConfigurationManager::configToSateFormat($validatedConfig);
				
			#	if (ref $stateFormat eq 'HASH') {
			#		CommandAttr(undef, "$hash->{NAME} stateFormat ". $stateFormat->{'stateFormat'});
			#		$hash->{STATE} = '???';
			#		CommandAttr(undef, "$hash->{NAME} webCmd ". $stateFormat->{'webCmd'});
			#	}
				
				foreach my $adr (keys %{$convertetSettings}) {
					HM485::Util::logger(
						HM485::LOGTAG_HM485, 3,
						'Set config for ' . $name . ': ' . $convertetSettings->{$adr}{text}
					);
	
					my $size  = $convertetSettings->{$adr}{size} ? $convertetSettings->{$adr}{size} : 1;
					$size     = sprintf ('%02X' , $size);
	
					my $value = $convertetSettings->{$adr}{value};
					$value    = sprintf ('%0' . ($size * 2) . 'X', $value);
					$adr      = sprintf ('%04X' , $adr);

					HM485::Util::logger('Test', 3, 'HM485_SetConfig fuer ' . $name . ' Schreiben Eeprom ' . $hmwId . ' 57 ' . $adr . ' ' . $size . ' ' . $value);
					
					HM485_SendCommand($hash, $hmwId, '57' . $adr . $size . $value);   # (W) write eeprom data
				}
				# InternalTimer( gettimeofday() + 2, 'HM485_SendCommand', $hash . ' ' . $hmwId . ' 43', 0 );	# Dem Bus 2s Zeit lassen vor der Aktuallisierung
				HM485_SendCommand($hash, $hmwId, '43');                             # (C) reread config funktioniert nur bedingt
				# InternalTimer( gettimeofday() + 5, 'HM485_GetConfig', $hash . ' ' . $hmwId, 0);		# deshalb muessen haertere Geschuetze aufgefahren werden
																									# mit Zeitverzoegerung, damit die Daten erst geschrieben 
																									# werden koennen
				
				my $data = '53';
				my $channelBehaviour = HM485::Device::getChannelBehaviour($hash);
				# HM485::Util::HM485_Log( 'HM485_SetConfig: deviceKey = ' . $deviceKey . ' name = ' . $name . ' channelBehaviour = ' . $channelBehaviour);
				# TODO: Warum werden hier readings geloescht?
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
				
					$data = sprintf ('53%02X', $chNr-1);
					InternalTimer( gettimeofday() + 1, 'HM485_SendCommand', $hash . ' ' . $hmwId . ' ' . $data, 0);
				}
				
			}
		}
	} else {
		$msg = '"set config needs 2 more parameter';
	}
	
	return $msg;
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
				
					HM485::Util::logger (
						HM485::LOGTAG_HM485, 4,
						'Set setting for ' . $actHash->{'NAME'} . ': ' .
						$convertetSettings->{$adr}{'text'}
					);
		
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


sub HM485_SetChannelState($$$) {
	my ($hash, $cmd, $value) = @_;
	
	my $retVal            		= '';
	my $frameData;
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
	if(!$valueKey) { return $retVal; }
		
	my $onlyAck = 0;  # TODO this onlyAck stuff is not really used, is it?
	my $valueHash  = $values->{$valueKey} ? $values->{$valueKey} : '';
	my $control    = $valueHash->{'control'} ? $valueHash->{'control'} : '';
	my $frameValue = undef;
			
	if ($control eq 'digital_analog_output.frequency')	{
		#deviec sends ACK only no Info frame. Need a only_ack bit for this control
		$onlyAck = 0;				
	}

	if (index('on:off:toggle:up:down', $cmd) != -1) {
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
	HM485_SendCommand($hash, $hmwId, $data, $onlyAck) if length $data;

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
									
								readingsSingleUpdate($hash, 'sim_counter', $frameValue, 1);
								
								HM485::Util::logger ( HM485::LOGTAG_HM485, 3,
									'Send ' .$frameType. ' for ' . $hash->{'NAME'} . ': ' .
									$peerHash->{'actuators'}{$peerId}{'actuator'}
								);
								
								HM485_SendCommand($hash,
									substr($peerHash->{'actuators'}{$peerId}{'actuator'}, 0, 8),
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

	# HM485::Util::HM485_Log( 'HM485_ValidateSettings cmdSet = ' . $cmdSet . ' value = ' . $value);
	# HM485_Log( 'HM485_ValidateSettings: configHash = ' . $configHash . ' cmdSet = ' . $cmdSet . ' value = ' . $value);
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
			if ($cmd ne 'inhibit' && $cmd ne 'install_test' && $cmd ne 'frequency2' 
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
	
	HM485::Util::logger( 'HM485_ProcessResponse', 5, 'msgData = ' . $msgData);
	
	if ($ioHash->{'.waitForResponse'}{$msgId}{hmwId}) {
		my $requestType = $ioHash->{'.waitForResponse'}{$msgId}{requestType};
		my $hmwId       = $ioHash->{'.waitForResponse'}{$msgId}{hmwId};
		my $requestData = $ioHash->{'.waitForResponse'}{$msgId}{requestData};
		my $hash        = $modules{HM485}{defptr}{$hmwId};
		my $chHash		= undef;
		my $Logging		= 'off';
		my $chNr 		= 0;
		my $deviceKey	= '';
		my $LoggingTime = 2;
		
		# Check if main device exists or we need create it
		if ( $hash->{DEF} && $hash->{DEF} eq $hmwId) {
			if ($requestType ne '52') { 
				HM485::Util::logger( 'HM485_ProcessResponse', 5, 'deviceKey = ' . $deviceKey . ' requestType = ' . $requestType . ' requestData = ' . $requestData . ' msgData = ' . $msgData);
			}
			if (grep $_ ne $requestType, ('68', '6E', '76')) { 
				my $configHash  = HM485::ConfigurationManager::getConfigFromDevice($hash, 0);
				$LoggingTime = $configHash->{logging_time}{value} ? $configHash->{logging_time}{value} : 2;
				$deviceKey 	= uc( HM485::Device::getDeviceKeyFromHash($hash));

				if (( $deviceKey eq 'HMW_LC_BL1_DR' or $deviceKey eq 'HMW_LC_DIM1L_DR') && ( defined( $requestData) && $requestData)) {
					$chNr = substr( $requestData, 0, 2);
					if ( $chNr lt "FF") {
						$chHash 	= HM485_GetHashByHmwid( $hmwId . '_' . sprintf( "%02d", $chNr+1));
						my $cHash	= HM485::ConfigurationManager::getConfigFromDevice( $chHash, 0);
						if ( defined( $cHash->{logging}{posibleValues}) && $cHash->{logging}{posibleValues}) {
							$Logging = HM485::ConfigurationManager::convertValueToOption( $cHash->{logging}{posibleValues}, $cHash->{logging}{value});
						}
					}
				}
			}
					
			if (grep $_ eq $requestType, ('53', '78')) {                # S (level_get), x (level_set) reports State
				if ( $deviceKey eq 'HMW_LC_BL1_DR') { # or $deviceKey eq 'HMW_LC_DIM1L_DR') {
					if ( $Logging eq 'on') {
						if ( $msgData && $msgData ne '') {
							my $bewegung = substr( $msgData, 6, 2);  		# Fuer Rolloaktor 10 = hoch, 20 = runter, 00 = Stillstand 
							my $level    = substr( $msgData, 4, 2);			# 53ccllbb
							$data = '5302';									# Channel 03 Level abfragen
							my %params = (hash => $hash, hmwId => $hmwId, data => $data);
							if ( $bewegung ne '00') {
								# if ( $level ne '00' && $level ne 'C8') {
									# kontinuierliche Levelabfrage starten, wenn sich Rollo bewegt, 
									# es nicht ganz zu ist (und nicht ganz geöffnet ist)
									#InternalTimer(gettimeofday() + $LoggingTime, 'HM485_SendCommandState', \%params, 0); 
									InternalTimer(gettimeofday() + $LoggingTime, 'HM485_SendCommand', $hash . ' ' . $hmwId . ' ' . $data, 0); 
								#}
							}
						}
					}
				}
				
				if ( $deviceKey eq 'HMW_IO12_SW14_DR') {
					# HM485::Util::HM485_Log( 'HM485_ProcessResponse deviceKey = ' . $deviceKey . ' msgData = ' . $msgData);
					#HM485_Log( 'HM485_ProcessResponse: ioHash = ' . $ioHash . ' hmwId = ' . $hmwId . ' msgData = ' . $msgData . ' requestType = ' . $requestType);
					#	my $ch =  substr( $msgData, 2 ,2);
					#	$data = '53' . $ch;
					#	my %params = (hash => $hash, hmwId => $hmwId, data => $data);
					# Eeeprom Daten zur Ueberpruefung ausgeben
					#if ($hash->{READINGS}{'.eeprom_0000'}{VAL}) {
					#	HM485::Util::HM485_Log( 'HM485_ProcessResponse hmwId = ' . $hmwId . ' .eeprom_0000 = ' . $hash->{READINGS}{'.eeprom_0000'}{VAL});
					#	HM485::Util::logger( 'HM485_ProcessResponse', 3, ' hmwId = ' . $hmwId . ' .eeprom_0000 = ' . $hash->{READINGS}{'.eeprom_0000'}{VAL});
					#}
				}
				
				HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');
				
			} elsif (grep $_ eq $requestType, ('4B', 'CB')) {       # K (Key), Ë (Key-sim) report State
				if ( $deviceKey eq 'HMW_LC_BL1_DR' or $deviceKey eq 'HMW_LC_DIM1L_DR') {
					if ( $Logging eq 'on') {
						my $bewegung = substr( $msgData, 6, 2);  		# Fuer Rolloaktor 10 = hoch, 20 = runter, 00 = Stillstand 
						my $level    = substr( $msgData, 4, 2);
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

# Todo: check if we need this
#			readingsSingleUpdate(
#				$hash, 'state', $HM485::commands{$requestType}, 1
#			);

		} else {
		 	HM485_CheckForAutocreate($ioHash, $hmwId, $requestType, $msgData);
		}
		
		#PFE BEGIN
		#Message queue processing
	    HM485_QueueStepSuccess($msgId);
		#PFE END

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
#	$devHash->{STATE} = 'NACK';
	readingsSingleUpdate($devHash, 'state', $txt, 1);

	HM485::Util::logger(HM485::LOGTAG_HM485, 3, $txt . ' for ' . $hmwId);
	if ( !exists( $devHash->{'.waitforConfig'}{'counter'})) {
		$devHash->{'.waitforConfig'}{'hmwId'} 	= $hmwId;
		$devHash->{'.waitforConfig'}{'counter'}	= 10;
		InternalTimer( gettimeofday() + $defStart + $defWait, 'HM485_WaitForConfig', $devHash, 0);
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
			readingsSingleUpdate($devHash, 'state', 'ACK', 1);
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
	
	# HM485::Util::HM485_Log( 'HM485_SetAttributeFromResponse: requestType = ' . $requestType . ' msgData = ' . $msgData);
	if ($requestType eq '68') {
		$attrVal = HM485::Device::parseModuleType($msgData);  # ModulTyp z.B.: HMW_LC_Bl1_DR
		#HM485::Util::HM485_Log( 'HM485_SetAttributeFromResponse: attrVal = ' . $attrVal);
		# Todo: maybe we should create subdevices only once?
		# Create subdevices if we have a modeltype
		#HM485_CreateChannels($hash);
	
	} elsif ($requestType eq '6E') {
		$attrVal = HM485::Device::parseSerialNumber($msgData);
	
	} elsif ($requestType eq '76') {
		$attrVal = HM485::Device::parseFirmwareVersion($msgData);
	}

	if ($attrVal) {
		my $name     = $hash->{NAME};
		my $attrName = $HM485::responseAttrMap{$requestType};
		# HM485::Util::HM485_Log( 'HM485_SetAttributeFromResponse: name = ' . $name . ' attrName = ' . $attrName . ' attrVal = ' . $attrVal);
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
	HM485::Util::HM485_Log( 'HM485_ProcessEvent: hmwId = ' . $hmwId . ' msgData = ' . $msgData);

	if ($msgData) {
		my $devHash = $modules{HM485}{defptr}{$hmwId};

		# Check if main device exists or we need create it
		if ( $devHash->{DEF} && $devHash->{DEF} eq $hmwId) {
			HM485_ProcessChannelState($devHash, $hmwId, $msgData, 'frame');
			my $deviceKey = HM485::Device::getDeviceKeyFromHash($devHash);
			my $event = substr( $msgData, 0, 2);
			if ( $event eq '4B') {
				# Taster wurde gedrueckt 4B
				
				# HM485::Util::HM485_Log('HM485_ProcessEvent: $hmwId = ' . $hmwId . ' deviceKey = ' . $deviceKey . ' msgData = ' . $msgData);

				if ( uc( $deviceKey) eq 'HMW_LC_BL1_DR') { # or $deviceKey eq 'HMW_LC_DIM1L_DR') {
					my $data = '5302';
					#my %params = (hash => $devHash, hmwId => $hmwId, data => $data);
					# kontinuierliche Abfrage des Levels starten
					InternalTimer( gettimeofday() + 2, 'HM485_SendCommand', $devHash . ' ' . $hmwId . ' ' . $data, 0); 
				}
			}
			# Bei Channels vom Typ KEY das Reading PRESS_SHORT oder PRESS_LONG loeschen
			# PFE BEGIN (according to Ralf9)
			# Wozu das reading loeschen?
			# my $chNr	= sprintf ('%02d' , hex( substr( $msgData, 2, 2)) + 1);
			# my $chTyp 	= HM485::Device::getChannelType( $deviceKey, $chNr);
			# if ( $chTyp eq 'key') {
				# my $chHash = HM485_GetHashByHmwid( $hmwId . '_' . $chNr);
				# my $chName = $chHash->{NAME};
				# if ( defined( ReadingsVal( $chName, 'press_short', undef))) {
					# fhem( "deletereading $chName press_short");
				# } elsif ( defined( ReadingsVal( $chName, 'press_long', undef))) {
					# fhem( "deletereading $chName press_long");
				# } else {
					# # kein reading zu loeschen
				# }
			# }
			# PFE END
		} else {
			# my $type = substr($msgData, 0, 2);
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
sub HM485_CheckForAutocreate($$;$$) {
	my ($ioHash, $hmwId, $requestType, $msgData) = @_;
	
#print Dumper("$hmwId, $requestType, $msgData");	
	my $logTxt = 'Device %s not defined yet. We need the %s for autocreate';

	if ($requestType && $msgData) {
		$ioHash->{'.forAutocreate'}{$hmwId}{$requestType} = $msgData;
	}

	if (!$ioHash->{'.forAutocreate'}{$hmwId}{'68'}) {
		HM485::Util::logger(
			HM485::LOGTAG_HM485, 4, sprintf($logTxt , $hmwId, 'type')
		);
		HM485_GetInfos($ioHash, $hmwId, 0b001);

	} elsif (!$ioHash->{'.forAutocreate'}{$hmwId}{'6E'}) {
		HM485::Util::logger(
			HM485::LOGTAG_HM485, 4, sprintf($logTxt , $hmwId, 'serial number')
		);
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
		DoTrigger("global",  'UNDEFINED ' . $deviceName . ' HM485 ' . $hmwId);
	}
}

=head2
	Dispatch a command for sending to device by InternalTimer
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
	@param	string  the data to send
=cut
sub HM485_SendCommand($$$;$) {
	my ($hash, $hmwId, $data, $onlyAck) = @_;
	if ( !$hmwId) {
		my @param = split(' ', $hash);
		$hash     = $param[0];
		$hmwId    = $param[1];
		$data     = $param[2];
		$onlyAck  = $param[3] ? $param[3] : 0;
	}
	$hmwId = substr($hmwId, 0, 8);
	
	if ( $data && length( $data) > 1) {
		# on send need the hash of the main device
		my $devHash = $modules{HM485}{defptr}{$hmwId};
		if (!$devHash) {
			$devHash = {
				IODev => $hash,
				NAME  => '.tmp',
			};
		}
	
		$onlyAck = $onlyAck ? $onlyAck : 0;
		
		my %params = (hash => $devHash, hmwId => $hmwId, data => $data, ack => $onlyAck);
		InternalTimer(gettimeofday(), 'HM485_DoSendCommand', \%params, 0);
		HM485::Util::logger( 'HM485_SendCommand',5, $data);
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
	my $requestType = substr( $data, 0, 2);  # z.B.: 53
	my $hash        = $paramsHash->{hash};
	my $ioHash      = $hash->{IODev};
	my $onlyAck		= $paramsHash->{'ack'};

	my %params      = (target => $hmwId, data   => $data);
	
	# send command to device and get the request id
	my $requestId = IOWrite($hash, HM485::CMD_SEND, \%params);

	HM485::Util::logger( 'HM485_DoSendCommand', 5, 'hmwId = ' . $hmwId . ' data = ' . $data . ' requestId = ' . $requestId);
	
	# frame types which must return values
	my @validRequestTypes = ('4B', '52', '53', '68', '6E', '70', '72', '73', '76', '78', 'CB');

	# frame types which must be acked only
	my @waitForAckTypes   = ('21', '43', '57', '67', '6C', '73');

	if ($requestId && !$onlyAck && grep $_ eq $requestType, @validRequestTypes) {
		$ioHash->{'.waitForResponse'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForResponse'}{$requestId}{hmwId}       = $hmwId;
		$ioHash->{'.waitForResponse'}{$requestId}{requestData} = substr($data, 2);

	} elsif ($requestId && grep $_ eq $requestType, @waitForAckTypes) {
		$ioHash->{'.waitForAck'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForAck'}{$requestId}{hmwId}       = $hmwId;
		$ioHash->{'.waitForAck'}{$requestId}{requestData} = substr($data, 2);
	}
	#PFE BEGIN
	#Tell Queue system
	HM485_QueueSetRequestId($requestId);
	#PFE END
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
	  HM485::Util::logger( 'HM485_ProcessChannelState', 3, ' hmwId = ' . $hmwId .' No message');
	  return;
	}
	if(!$hash->{MODEL}) {
	  HM485::Util::logger( 'HM485_ProcessChannelState', 3, ' hmwId = ' . $hmwId . ' No model');
	  return;
	}
	# parse frame data, this also knows whether there is a channel
	my $valueHash = HM485::Device::parseFrameData($hash, $msgData, $actionType);	# hash, 690E03FF, response
	# is there a channel?
	# (This could be an announce message, which does not have channels.)
	if(!defined($valueHash->{ch})) {
	  HM485::Util::logger( 'HM485_ProcessChannelState', 5, ' hmwId = ' . $hmwId . ' No channel');
	  return;
	}
								 
	HM485::Util::logger( 'HM485_ProcessChannelState', 5, 'name2 = ' . $hash->{NAME} . ' hmwId = ' . $hmwId . ' Channel = ' . $valueHash->{ch} . ' msgData = ' . $msgData . ' actionType = ' . $actionType);
	my $chHash = HM485_GetHashByHmwid($hash->{DEF} . '_' . $valueHash->{ch});
	HM485_ChannelUpdate( $chHash, $valueHash->{value});
}
# PFE END

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
	
	HM485::Util::HM485_Log( 'HM485_ChannelDoUpdate: name = ' . $name);
	readingsBeginUpdate($chHash);
	
	foreach my $valueKey (keys %{$valueHash}) {
		my $value = $valueHash->{$valueKey};
		
		if (defined($value)) {
			my $oldValue = $chHash->{READINGS}{$valueKey}{VAL} ? $chHash->{READINGS}{$valueKey}{VAL} : 'empty';
			HM485::Util::logger( 'HM485_ChannelDoUpdate', 5, 'valueKey = ' . $valueKey .
				' value = ' . $value . ' Alter Wert = ' . $oldValue);
	
			readingsBulkUpdate( $chHash, $valueKey, $value);
			
			HM485::Util::logger(
				HM485::LOGTAG_HM485, 4, $name . ': ' . $valueKey . ' -> ' . $value
			);
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
	
	# HM485_Log( 'HM485_ProcessEepromData: name = ' . $name . ' requestData = ' . $requestData . ' eepromData = ' . $eepromData . ' adr = ' . $adr);
	
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
	
	# HM485::Util::logger('HM485_DevStateIcon', 3, 'name = ' . $name);
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
sub HM485_GetNewMsgQueue($$$$) {
  my ($successFn, $successParams, $failureFn, $failureParams) = @_;
  HM485::Util::logger( 'HM485_GetNewMsgQueue',5, "bla");
  return { successFn => $successFn, successParams => $successParams,
           failureFn => $failureFn, failureParams => $failureParams,
		   entries => [], currentIndex => -1 };
}

# append command to queue
sub HM485_QueueCommand($$$$;$) {
	my ($queue, $hash, $hmwId, $data, $onlyAck) = @_;
	HM485::Util::logger( 'HM485_QueueCommand',5, $data);
	$onlyAck = $onlyAck ? $onlyAck : 0;
	${$queue->{entries}}[$#{$queue->{entries}} +1] = {hash => $hash, hmwId => $hmwId, data => $data, onlyAck => $onlyAck};
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
sub HM485_QueueStart($) {
  my ($queue) = @_;
  # empty queues are not really started, we just call the success function
     #success callback function
  if($#{$queue->{entries}} == -1) {     
	if($queue->{successFn}) {
	  # the success function is called via internal timer
	  # because it is usually called asynchrnously for non-empty queues
	  InternalTimer(gettimeofday(), 'HM485_QueueSuccessViaTimer', $queue, 0);
	};  
	return;
  };
  
  push(@msgQueueList, $queue);
  HM485::Util::logger( 'HM485_QueueStart',5, "Num: ".$#msgQueueList);
  if($#msgQueueList == 0) {
    # HM485::Util::logger( 'HM485_QueueStart',3, 'Call step');
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
  
  HM485::Util::logger( 'HM485_QueueProcessStep',5, $currentEntry);
  HM485_SendCommand($currentEntry->{hash}, $currentEntry->{hmwId}, 
                    $currentEntry->{data}, $currentEntry->{onlyAck});
}


# set request ID into current queue
sub HM485_QueueSetRequestId($) {
  my ($requestId) = @_;
  HM485::Util::logger( 'HM485_QueueSetRequestId',5, 'start');
  if($#msgQueueList < 0){ return };  # ready, no Queues
  my $currentQueue = $msgQueueList[$currentQueueIndex];
  $currentQueue->{currentRequestId} = $requestId;
  HM485::Util::logger( 'HM485_QueueSetRequestId',5, 'Id: '. $requestId);
}

#called from ProcessResponse
sub HM485_QueueStepSuccess($) {
   my ($requestId) = @_;
  # are we in queue processing?
  if($currentQueueIndex < 0) { return; };
  HM485::Util::logger( 'HM485_QueueStepSuccess',5, 'called');
  # if($requestId) {
    # HM485::Util::logger( 'HM485_QueueStepSuccess',3, 'Request ID defined');
	# HM485::Util::logger( 'HM485_QueueStepSuccess',3, 'Request ID: '.$requestId);
  # }else{
	# HM485::Util::logger( 'HM485_QueueStepSuccess',3, 'Request ID undefined');  
  # }
  # ok, go to the next queue entry
  # get current queue
  my $currentQueue = $msgQueueList[$currentQueueIndex]; 
  # correct request?
  if($currentQueue->{currentRequestId} != $requestId) { 
    HM485::Util::logger( 'HM485_QueueStepSuccess',5, 'Foreign request ID: '.$requestId.' '.$currentQueue->{currentRequestId});
    return; 
  };
  # have we processed the last entry?
  HM485::Util::logger( 'HM485_QueueStepSuccess',5, 'Entries: '.$#{$currentQueue->{entries}}.' Index: '.$currentQueue->{currentIndex});
  if($#{$currentQueue->{entries}} == $currentQueue->{currentIndex}) {
    # yes, last entry. Remove from list of queues
	HM485::Util::logger( 'HM485_QueueStepSuccess',5, 'Splice1: '.$#msgQueueList);
	splice(@msgQueueList,$currentQueueIndex,1);
	HM485::Util::logger( 'HM485_QueueStepSuccess',5, 'Splice2: '.$#msgQueueList);
	$currentQueueIndex = -1;
	# process next entry. This is done in any case as there might be other queues
	# however, it needs to be done before the callback as this might already create 
	# a new queue and call queueStart
	# HM485::Util::logger( 'HM485_QueueStepSuccess',3, 'Call step');
	HM485_QueueProcessStep();
    #success callback function
	if($currentQueue->{successFn}) {
	  no strict "refs";
      &{$currentQueue->{successFn}}(@{$currentQueue->{successParams}});
	  use strict "refs";
	};  
  }else{
  # process next entry. This is done in any case as there might be other queues
    # HM485::Util::logger( 'HM485_QueueStepSuccess',3, 'Call step');
    HM485_QueueProcessStep();
  };
}


#called from SetStateNack
sub HM485_QueueStepFailed($) {
  my ($requestId) = @_;
  HM485::Util::logger( 'HM485_QueueStepFailed',5, 'Request ID: '.$requestId);
  if($currentQueueIndex < 0) { return };
  # get current queue
  my $currentQueue = $msgQueueList[$currentQueueIndex]; 
  # correct request?
  if($currentQueue->{currentRequestId} != $requestId) { 
    HM485::Util::logger( 'HM485_QueueStepFailed',5, 'Foreign request ID');
    return; 
  };  
  # remove complete queue
  splice(@msgQueueList,$currentQueueIndex,1);
  $currentQueueIndex = -1;
  # next step, there might be multiple queues
  # call this now, just in case the callback creates a new queue
  HM485::Util::logger( 'HM485_QueueStepFailed',3, 'Call step');
  HM485_QueueProcessStep();
  # failure callback
  if($currentQueue->{failureFn}) {
    no strict "refs";
    &{$currentQueue->{failureFn}}(@{$currentQueue->{failureParams}});
	use strict "refs";
  };	

}

#PFE END

1;
