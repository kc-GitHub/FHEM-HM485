=head1
	00_HM485.pm

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
#use lib::HM485::Command;

use Scalar::Util qw(looks_like_number);

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

# Function prototypes

# FHEM Inteface related functions
sub HM485_Initialize($);
sub HM485_Define($$);
sub HM485_Undefine($$);
sub HM485_Rename($$);
sub HM485_Parse($$);
sub HM485_Set($@);
sub HM485_Get($@);
sub HM485_Attr ($$$$);
sub HM485_FhemwebShowConfig($$$);

# Device related functions
sub HM485_GetInfos($$$);
sub HM485_GetConfig($$);
sub HM485_CreateChannels($$);
sub HM485_SetConfig($@);
sub HM485_ValidateSettings($$$);
sub HM485_SetWebCmd($$);
sub HM485_GetHashByHmwid ($);

#Communication related functions
sub HM485_ProcessResponse($$$);
sub HM485_SetStateNack($$);
sub HM485_SetStateAck($$$);
sub HM485_SetAttributeFromResponse($$$);
sub HM485_ProcessEvent($$);
sub HM485_CheckForAutocreate($$;$$);
sub HM485_SendCommand($$$);
sub HM485_DoSendCommand($);
sub HM485_ProcessChannelState($$$$);
sub HM485_ChannelUpdate($$);
sub HM485_ChannelDoUpdate($);
sub HM485_ProcessEepromData($$$);

# External helper functions
sub HM485_DevStateIcon($);

my @attrListRO     = ();
my @attrListBindCh = ('model', 'serialNr', 'firmwareVersion', 'room', 'comment');

# Default set comands for device
my %setsDev = ('reset' => ' ', 'test' => ' ');

# Default set comands for channel
my %setsCh = ();

# Default set comands for device
my %getsDev = (
	'info'    => ' ', # maybe only for debugging
	'config'  => 'all',
	'state'   => ' ',
);

# Default get comands for channel
my %getsCh = ('state' => ' ');

###############################################################################
# Interface related functions
###############################################################################

=head2
	Implements Initialize function
	
	@param	hash	hash of device addressed
=cut
sub HM485_Initialize($) {
	my ($hash) = @_;

	$hash->{Match}          = '^FD.*';
	$hash->{DefFn}          = 'HM485_Define';
	$hash->{UndefFn}        = 'HM485_Undefine';
	$hash->{RenameFn}       = 'HM485_Rename';
	$hash->{ParseFn}        = 'HM485_Parse';
	$hash->{SetFn}          = 'HM485_Set';
	$hash->{GetFn}          = 'HM485_Get';
	$hash->{AttrFn}         = 'HM485_Attr';
	
	# For FHEMWEB
	$hash->{FW_detailFn}    = 'HM485_FhemwebShowConfig';

	$hash->{AttrList}       = 'do_not_notify:0,1 ' .
	                          'ignore:1,0 dummy:1,0 showtime:1,0 serialNr ' .
	                          'model:' . HM485::Device::getModelList() . ' ' .
	                          'subType stateFormat ' .
	                          ' firmwareVersion';

	#@attrListRO = ('serialNr', 'firmware', 'hardwareType', 'model' , 'modelName');
	@attrListRO = ('serialNr', 'firmware');
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

	if (int(@a)!=3 || (defined($a[2]) && $a[2] !~ m/^[A-F0-9]{8}_{0,1}[A-F0-9]{0,2}$/i)) {
		$msg = 'wrong syntax: define <name> HM485 <8-digit-hex-code>[_<2-digit-hex-code>]';

	} elsif ($modules{HM485}{defptr}{$hmwId}) {
		$msg = 'Device ' . $hmwId . ' already defined.'

	} else {
		my $name = $hash->{NAME};
		
		if ($chNr) {
			# We defined a channel of a device
			my $devHash = $modules{HM485}{defptr}{$addr};

			if (defined($devHash) && $devHash) {
				my $devName = $devHash->{NAME};
				$devHash->{'channel_' .  $chNr} = $name;                        # reference this channel to the device entity
				$hash->{device} = $devName;                                     # reference the device to this channel
				$hash->{chanNo} = $chNr;

				# copy definded attributes to channel
				foreach my $attrBindCh (@attrListBindCh) {
					my $val = AttrVal($devName, $attrBindCh, undef);
					if (defined($val) && $val) {
						CommandAttr(undef, $name . ' ' . $attrBindCh . ' ' . $val);
					}
				}
				
				# ToDo: check if wee need this here
				#$attr{$name}{peerIDs} = AttrVal($devName, 'peerIDs', '');
				#$hash->{READINGS}{peerList}{VAL} = ReadingsVal($devName, 'peerList', '');
				#$hash->{peerList} = $devHash->{peerList} ? $devHash->{peerList} : undef;
				
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
			$modules{HM485}{defptr}{$hmwId} = $hash;
			$hash->{DEF} = $hmwId;
			
			if (defined($hash->{IODev}{STATE})) {
				if ($hash->{IODev}{STATE} eq 'open') {
					HM485::Util::logger(
						HM485::LOGTAG_HM485, 2, 'Auto get info for : ' . $name
					);

					HM485_GetInfos($hash, $hmwId, 0b111);
	#				HM485_GetConfig($hash, $addr);
				} else {
					# Todo: Maybe we must queue "auto get info" if IODev not opened yet 
				}
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

	if ($chNr) {
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

	if ($chNr){
		# we are channel, inform the device
		$hash->{chanNo} = $chNr;
		my $devHash = HM485_GetHashByHmwid(substr($hmwId,0,8));
		$hash->{device} = $devHash->{NAME};
		$devHash->{'channel_' . $hash->{chanNo}} = $name;

	} else{
		# we are a device - inform channels if exist
		foreach my $devName (grep(/^channel_/, keys %{$hash})) {
			my $chnHash = $defs{$hash->{$devName}};
			$chnHash->{device} = $name;
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
	my $msgCmd  = ord(substr($message, 3, 1));
	my $msgData = uc( unpack ('H*', substr($message, 4)));

	if ($msgCmd == HM485::CMD_RESPONSE) {
		HM485_SetStateAck($ioHash, $msgId, $msgData);
		HM485_ProcessResponse($ioHash, $msgId, substr($msgData,2));

	} elsif ($msgCmd == HM485::CMD_EVENT) {
		HM485_SetStateAck($ioHash, $msgId, $msgData);

		# Todo: check if events triggered on ack only?
		HM485_ProcessEvent($ioHash, $msgData);

	} elsif ($msgCmd == HM485::CMD_ALIFE && substr($msgData, 0, 2) eq '01') {
		HM485_SetStateNack($ioHash, $msgData);
	}
	
	return $ioHash->{NAME};
}

sub HM485_Parse_old($$$) {
	my ($ioHash, $message) = @_;

	my @messages = split(chr(HM485::FRAME_START_LONG), $message);
	foreach my $message (@messages) {

		if ($message && length($message) > 3) {
			my $msgId   = ord(substr($message, 1, 1));
			my $msgCmd  = ord(substr($message, 2, 1));
			my $msgData = uc( unpack ('H*', substr($message, 3)));

			if ($msgCmd == HM485::CMD_RESPONSE || $msgCmd == HM485::CMD_ALIFE) {
				my $ack = ($msgCmd == HM485::CMD_RESPONSE) ? 1 : 0;
#				HM485_ProcessResponse($ioHash, $msgId, $ack, substr($msgData,2));
		
			} elsif ($msgCmd == HM485::CMD_EVENT) {
				# Todo: check if events triggered on ack only?
				HM485_ProcessEvent($ioHash, $msgData);
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
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	my %sets    = ();
	
	if ($chNr) {
		%sets = %setsCh;
		my $allowedSets = HM485::Device::getAllowedSets($hash);
		if ($allowedSets) {
			foreach my $setValue (split(' ', $allowedSets)) {
				my($setValue, $param) = split(':', $setValue);
				$sets{$setValue} = $param ? $param : '';
			}
		}
	} else {
		%sets = %setsDev;
	}
	
	# add config setter if config for this device or channel avilable
	my $configHash = HM485::ConfigurationManager::getConfigFromDevice($hash, $chNr);
	if (scalar (keys %{$configHash})) {
		$sets{'config'} = '';
	}
	
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
			
			if ($cmd eq 'test') {
				# Todo for development
				HM485_SetTest($hash);
				
			} elsif ($cmd eq 'press_long' || $cmd eq 'press_short') {
				#Todo: Make ready
				$msg = 'set ' . $name . ' ' . $cmd . ' not yet implemented'; 

			} elsif ($cmd eq 'config') {
				$msg = HM485_SetConfig($hash, @params);

			} elsif ($cmd eq 'on' || $cmd eq 'off') {
				#Todo: Make ready
				my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
				my $state = ($cmd eq 'on') ? '01' : '00';
				my $data  = sprintf('78%02X%02X', ($chNr-1), $state);
				HM485_SendCommand($hash, $hmwId, $data);

			} elsif ($cmd eq 'level') {
				#Todo: Make ready
				my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
				my $state = $value * 2;
				my $data  = sprintf('78%02X%02X', ($chNr-1), $state);
				HM485_SendCommand($hash, $hmwId, $data);
			}
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
	my %gets = $chNr ? %getsCh : %getsDev;
	my $msg  = '';

	if (@params < 2) {
		$msg =  '"get ' . $name . '" needs one or more parameter'

	} else {
		if(!defined($gets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %gets) {
				$arguments.= $arg . ($gets{$arg} ? (':' . $gets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;

		} elsif ($cmd eq 'info') {
			# all infos (moduleType, serialNumber, firmwareVersion
			HM485_GetInfos($hash, $hmwId, 0b111);

		} elsif ($cmd eq 'config') {
			# get module config (eeprom data)
			HM485_GetConfig($hash, $hmwId);
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
sub HM485_Attr ($$$$) {
	my (undef, $name, $attrName, $val) =  @_;

	my $hash  = $defs{$name};
	my $msg   = '';

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	if ($attrName) {
		foreach my $attrRO (@attrListRO) {
			if ( $attrName eq $attrRO && AttrVal($name, $attrName, undef) ) {
# Todo:
#				$msg = 'Attribute ' . $attrName . ' is read only after definition.';
			}
		}
	
		if (!$msg) {
			if ( $attrName eq 'serialNr' && (!defined($val) || $val !~ m/^[A-Za-z0-9]{10}$/i) ) {
				$msg = 'Wrong serialNr (' . $val . ') defined. serialNr must be 10 characters (A-Z, a-z or 0-9).';
		
			} elsif ( $attrName eq 'firmwareVersion' && (!defined($val) || !looks_like_number($val)) ) {
				$msg = 'Firmware version must be a number.';

			} elsif ($attrName eq 'model') {
				my @modelList = split(',', HM485::Device::getModelList());

				$msg = 'model of "' . $name . '" must one of ' . join(' ', @modelList);
				if ($val) {
					foreach my $model (@modelList) {
						if ($model eq $val) {
							$msg = '';
							last;
						}
					}

					$hash->{MODEL} = $val;
					if (!$msg && $chNr) {
						# if we are a channel, we set webCmd attribute
						HM485_SetWebCmd($hash, $val);
					}
				}
			}
		}
		
		if (!$msg) {
			if (!$chNr) {
				# we are a device we try to copy some attributes to all defined channels
				foreach my $attrBindCh (@attrListBindCh) {
					if ( $attrName eq $attrBindCh && AttrVal($name, $attrName, undef) ) {
						foreach my $chName (grep(/^channel_/, keys %{$hash})) {
							my $devName = $hash->{$chName};
							CommandAttr(undef, $devName . ' ' . $attrName . ' ' . $val);
						} 
					}
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

	# Todo: make ready
	my $peerHash = $hash->{PEERINGS};

	my $content = HM485::FhemWebHelper::showConfig($hash, $configHash, $peerHash);

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
sub HM485_GetInfos($$$) {
	my ($hash, $hmwId, $infoMask) = @_;
	$infoMask = defined($infoMask) ? $infoMask : 0;

	if ($infoMask & 0b001) {
		# (h) request module type
		HM485_SendCommand($hash, $hmwId, '68');
	}
	
	if ($infoMask & 0b010) {
		# (n) request serial number
		HM485_SendCommand($hash, $hmwId, '6E');
	}
	
	if ($infoMask & 0b100) {
		# (v) request firmware version
		HM485_SendCommand($hash, $hmwId, '76');
	}
}

=head2
	Request device config stoerd in the eeprom of a device
	ToDo: check model var and if we must clear eepromdata before 
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
=cut
sub HM485_GetConfig($$) {
	my ($hash, $hmwId) = @_;

	my $devHash = $modules{HM485}{defptr}{substr($hmwId,0,8)};

	HM485::Util::logger(
		HM485::LOGTAG_HM485, 3, 'Request config for device ' . substr($hmwId,0,8)
	);

	# here we query eeprom data wit device settings
	my $model = $devHash->{MODEL};
	if ($model) {
		my $eepromMap = HM485::Device::getEmptyEEpromMap($model);
		
		# write eeprom map to readings
		foreach my $adrStart (sort keys %{$eepromMap}) {
			setReadingsVal($devHash, '.eeprom_' . $adrStart, $eepromMap->{$adrStart}, TimeNow());
		}

		foreach my $adrStart (sort keys %{$eepromMap}) {
			# (R) request eeprom data
			HM485_SendCommand($devHash, $hmwId, '52' . $adrStart . '10');   
		}
	}
}

=head2
	Create all channels of a device
	
	@param	hash    hash of device addressed
	@param	string  hex value of hardware type
=cut
sub HM485_CreateChannels($$) {
	my ($hash, $hwType) = @_;

	my $name  = $hash->{NAME};
	my $hmwId = $hash->{DEF};

	# get related subdevices for this device from config
	my $modelGroup = HM485::Device::getModelGroup($hwType);

	my $subTypes = HM485::Device::getValueFromDefinitions($modelGroup . '/channels');
	if (ref($subTypes) eq 'HASH') {
		
		foreach my $subType (sort keys %{$subTypes}) {
			if ($subType ne 'maintenance') {
				if ( defined($subTypes->{$subType}{count}) && $subTypes->{$subType}{count} > 0) {
					my $chStart = $subTypes->{$subType}{id};
					my $chCount = $subTypes->{$subType}{count};
					
					for(my $ch = $chStart; $ch < ($chStart + $chCount); $ch++) {
						my $txtCh = sprintf ('%02d' , $ch);
						my $room = AttrVal($name, 'room', '');
						my $devName = $name . '_' . $txtCh;
						my $chHmwId = $hmwId . '_' . $txtCh;
						
						if (!$modules{HM485}{defptr}{$chHmwId}) {
							CommandDefine(undef, $devName . ' ' . ' HM485 ' . $chHmwId);
							CommandAttr(undef, $devName . ' subType ' . $subType);
							if ($subType eq 'key') {
								# Key subtypes don't have a state
								delete($modules{HM485}{defptr}{$chHmwId}{STATE});
							}
						}
					} 
				}
			}
		}
	}
}

sub HM485_SetConfig($@) {
	my ($hash, @values) = @_;

	my $name = $hash->{NAME};
	shift(@values);
	shift(@values);

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
	my $msg = '';
	my $validatedConfig = {};
	my $configHash = {};
	if (scalar (keys %{$setConfigHash})) {
		$configHash = HM485::ConfigurationManager::getConfigSettings($hash);
#		print Dumper($configHash);
		foreach my $setConfig (keys %{$setConfigHash}) {
			my $configTypeHash = $configHash->{$setConfig};
			$msg = HM485_ValidateSettings(
				$configTypeHash, $setConfig, $setConfigHash->{$setConfig}
			);
			
			if (!$msg) {
				$validatedConfig->{$setConfig}{value} = $setConfigHash->{$setConfig};
				$validatedConfig->{$setConfig}{config} = $configHash->{$setConfig};
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
			foreach my $adr (keys %{$convertetSettings}) {
				HM485::Util::logger(
					HM485::LOGTAG_HM485, 3,
					'Set config for ' . $name . ': ' . $convertetSettings->{$adr}{text}
				);

			 	my $hmwId = $hash->{DEF};
				my $size  = $convertetSettings->{$adr}{size} ? $convertetSettings->{$adr}{size} : 1;
				$size     = sprintf ('%02X' , $size);

				my $value = $convertetSettings->{$adr}{value};
				$value    = sprintf('%0' . ($size * 2) . 'X', $value);

				$adr      = sprintf ('%04X' , $adr);

				HM485_SendCommand($hash, $hmwId, '57' . $adr . $size . $value);     # (W) write eeprom data
			}
		}
	}

	return $msg;
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

			} elsif ($logical->{type} eq 'option') {
				my @optionValues = HM485::ConfigurationManager::optionsToArray($logical->{options});
#				my @optionValues = map {s/ //g; $_; } split(',', $logical->{options});
				if ( !(grep $_ eq $value, @optionValues) ) {
					$msg = 'must be on of: ' . join(', ', @optionValues);					
				} 
			}
		}
		$msg = ($msg) ? $cmdSet . ' ' . $msg : '';
	} else {
		$msg = 'no value given for ' . $cmdSet;
	}
	
	return $msg;
} 

sub HM485_SetWebCmd($$) {
	my ($hash, $model) = @_;
	my $name = $hash->{NAME};
	
#	my $webCmd = HM485::Device::getAllowedSets($hash, $model);
#	if ($webCmd) {
#		CommandAttr(undef, $name . ' webCmd ' . $webCmd);
#	}
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

	if ($ioHash->{'.waitForResponse'}{$msgId}{hmwId}) {
		my $requestType = $ioHash->{'.waitForResponse'}{$msgId}{requestType};
		my $hmwId       = $ioHash->{'.waitForResponse'}{$msgId}{hmwId};
		my $requestData = $ioHash->{'.waitForResponse'}{$msgId}{requestData};
		my $hash        = $modules{HM485}{defptr}{$hmwId};

		# Check if main device exists or we need create it
		if($hash->{DEF} && $hash->{DEF} eq $hmwId) {
	
			if (grep $_ eq $requestType, ('53', '78')) {                    # S (level_get), x (level_set) reports State
#				HM485_processStateData($msgData);

#			} elsif (grep $_ eq $requestType, ('4B', 'CB')) {                # K (Key), Ë (Key-sim) report State
				#HM485_processStateData($msgData);

			} elsif ($requestType eq '52') {                                # R (report Eeprom Data)
				HM485_ProcessEepromData($hash, $requestData, $msgData);

			} elsif (grep $_ eq $requestType, ('68', '6E', '76')) {         # h (module type), n (serial number), v (firmware version)
				HM485_SetAttributeFromResponse($hash, $requestType, $msgData);
	
#			} elsif ($requestType eq '70') {                                # p (report packet size, only in bootloader mode)

#			} elsif ($requestType eq '72') {                                # r (report firmwared data, only in bootloader mode)

			}

			HM485_ProcessChannelState($hash, $hmwId, $msgData, 'response');

# Todo: check if we need this
#			readingsSingleUpdate(
#				$hash, 'state', $HM485::commands{$requestType}, 1
#			);
			
		} else {
		 	HM485_CheckForAutocreate($ioHash, $hmwId, $requestType, $msgData);
		}

	} elsif ($ioHash->{'.waitForAck'}{$msgId}{hmwId}) {
		my $requestType = $ioHash->{'.waitForAck'}{$msgId}{requestType};
		my $hmwId       = $ioHash->{'.waitForAck'}{$msgId}{hmwId};
		my $requestData = $ioHash->{'.waitForAck'}{$msgId}{requestData};
		my $hash        = $modules{HM485}{defptr}{$hmwId};

		if($hash->{DEF} eq $hmwId) {
			if ($requestType eq '57') {                                     # W (ACK written Eeprom Data)
				# AKC for write EEprom data
				my $devHash = HM485_GetHashByHmwid(substr($hmwId, 0,8));
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
	my $hmwId = substr($msgData, 2,8);	

	my $devHash = HM485_GetHashByHmwid($hmwId);
	
	my $txt = 'RESPONSE TIMEOUT';
#	$devHash->{STATE} = 'NACK';
	readingsSingleUpdate($devHash, 'state', $txt, 1);

	HM485::Util::logger(HM485::LOGTAG_HM485, 3, $txt . ' for ' . $hmwId);
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
		my $hmwId = substr($msgData, 2,8);		
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
	
	if ($requestType eq '68') {
		$attrVal = HM485::Device::parseModuleType($msgData);

		# Todo: maybe we should create subdevices only once?
		# Create subdevices if we have a modeltype
		HM485_CreateChannels($hash, $attrVal);
	
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

	my $hmwId = substr($msgData, 10,8);
	$msgData  = (length($msgData) > 17) ? substr($msgData, 18) : '';;

	if ($msgData) {
		my $devHash = $modules{HM485}{defptr}{$hmwId};

		# Check if main device exists or we need create it
		if($devHash->{DEF} && $devHash->{DEF} eq $hmwId) {
			HM485_ProcessChannelState($devHash, $hmwId, $msgData, 'frame');
	
		} else {
			my $type = substr($msgData, 0, 2);
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
			HM485::LOGTAG_HM485, 4, sprintf ($logTxt , $hmwId, 'type')
		);
		HM485_GetInfos($ioHash, $hmwId, 0b001);

	} elsif (!$ioHash->{'.forAutocreate'}{$hmwId}{'6E'}) {
		HM485::Util::logger(
			HM485::LOGTAG_HM485, 4, sprintf ($logTxt , $hmwId, 'serial number')
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
		DoTrigger("global",  'UNDEFINED ' . $deviceName . ' HM485 '.$hmwId);
	}
}

=head2
	Dispatch a command for sending to device by InternalTimer
	
	@param	hash    hash of device addressed
	@param	string  the HMW id
	@param	string  the data to send
=cut
sub HM485_SendCommand($$$) {
	my ($hash, $hmwId, $data) = @_;
	$hmwId = substr($hmwId, 0, 8);

	# on send need the hash of the main device
	my $devHash = $modules{HM485}{defptr}{$hmwId};
	if (!$devHash) {
		$devHash = {
			IODev => $hash,
			NAME  => '.tmp',
		};
	}

	my %params = (hash => $devHash, hmwId => $hmwId, data => $data);
	InternalTimer(gettimeofday(), 'HM485_DoSendCommand', \%params, 0);
} 

=head2
	Send a command to device
	
	@param	hash    parameter hash
=cut
sub HM485_DoSendCommand($) {
	my ($paramsHash) = @_;

	my $hmwId       = $paramsHash->{hmwId};
	my $data        = $paramsHash->{data};
	my $requestType = substr($data, 0,2); 
	my $hash        = $paramsHash->{hash};
	my $ioHash      = $hash->{IODev};

	my %params      = (target => $hmwId, data   => $data);

	# send command to device and get the request id
	my $requestId = IOWrite($hash, HM485::CMD_SEND, \%params);

	# frame types which must return values
	my @validRequestTypes = ('4B', '52', '53', '52', '68', '6E', '70', '72', '76', '78', 'CB');

	# frame types which must be acked only
	my @waitForAckTypes   = ('21', '43', '57', '67', '6C', '73');

	if ($requestId && grep $_ eq $requestType, @validRequestTypes) {
		$ioHash->{'.waitForResponse'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForResponse'}{$requestId}{hmwId}      = $hmwId;
		$ioHash->{'.waitForResponse'}{$requestId}{requestData} = substr($data, 2);

	} elsif ($requestId && grep $_ eq $requestType, @waitForAckTypes) {
		$ioHash->{'.waitForAck'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForAck'}{$requestId}{hmwId}      = $hmwId;
		$ioHash->{'.waitForAck'}{$requestId}{requestData} = substr($data, 2);
	}
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

	my $name = $hash->{NAME};
	if ($msgData) {
		my $data  = substr($msgData, 2);
		my $model = $hash->{MODEL};

		if (defined($model) && $model) {
			my $valueHash = HM485::Device::parseFrameData($model, $msgData, $actionType);
			
			if ($valueHash->{ch}) {
				my $chHash = HM485_GetHashByHmwid($hash->{DEF} . '_' . $valueHash->{ch});
				HM485_ChannelUpdate($chHash, $valueHash->{value});
			}
		}
	}
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

	readingsBeginUpdate($chHash);
	foreach my $valueKey (keys %{$valueHash}) {
		my $value = $valueHash->{$valueKey};

		if (defined($value)) {
			# we trigger events only if necesary
			if (!defined($chHash->{READINGS}{$valueKey}{VAL}) ||
			    $chHash->{READINGS}{$valueKey}{VAL} ne $value) {

				readingsBulkUpdate($chHash, $valueKey, $value);
				HM485::Util::logger(
					HM485::LOGTAG_HM485, 2, $name . ': ' . $valueKey . ' -> ' . $value
				);
			}
		}
	}

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
	my @dimValues = (6,12,18,25,31,37,43,50,56,62,68,75,81,78,93);
	
	my $level = ReadingsVal($name, 'level', '???');
	my $retVal = 'dim06%';

	if ($level == 0) {
		$retVal = 'off';

	} elsif ($level == 100) {
		$retVal = 'on';

	} else {
		foreach my $dimValue (@dimValues) {
			if ($level <= $dimValue) {
				$retVal =  sprintf ('dim%02d' , $dimValue);
				$retVal.='%';
				last;
			}
		}
	}
	
	return $retVal;
}

###############################################################################

sub HM485_SetTest ($) {
	my ($hash) = @_;
	
#				$modules{$defs{$name}{TYPE}}{AttrList} =~ s/$item//;
				# debug
#				my $valueHash = HM485::Device::parseFrameData(
#					'HMW_IO_12_Sw7_DR',
##					'690C01',
#					'4B0B0032',
#					'event',
#					'frame'
#				);

#				my $eepromMap = HM485::Device::getEmptyEEpromMap('HMW_IO_12_Sw14_DR');
#				print Dumper($eepromMap);
#				print Dumper("HMW_IO_12_Sw7_DR -----------------------");
#				$eepromMap = HM485::Device::getEmptyEEpromMap('HMW_IO_12_Sw7_DR');
#				print Dumper($eepromMap);

#my $start = 18;
#my $len = 20;
#my $data = 'CCDDEEqqwweerrttzzuuiiooppüüaassddffgghh';
#HM485::Device::setRawEEpromData($hash, $start, $len, $data);

#				my $t = HM485::Device::getRawEEpromData($hash, 0x101, 7);	
}

1;
