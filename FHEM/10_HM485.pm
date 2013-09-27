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
#use lib::HM485::Command;

use Scalar::Util qw(looks_like_number);

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

# Function prototypes

# FHEM Inteface related functions
sub HM485_Initialize($);
sub HM485_Define($$);

my @attrListRO     = ();
my @attrListBindCh = ('model', 'serialNr', 'firmwareVersion', 'room', 'comment');

# Default set comands for device
my %setsDev = (
	'reset'      => ' ',
	'test'       => ' ',
#	'regRaw'     => 'regRaw',		# ???
);

# Default set comands for channel
my %setsCh = (
#	'pair'       => 'pair',			# ???
);

# Default set comands for device
my %getsDev = (
	'info'       => ' ', # maybe only for debugging
	'state'      => ' ',
#	'config'     => ' ',
#	'regRaw'     => ' ',
#	'regList'    => ' ',
	);

# Default get comands for channel
my %getsCh = (
	'state'      => ' ',
);


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

	$hash->{AttrList}       = 'do_not_notify:0,1 ' .
	                          'ignore:1,0 dummy:1,0 showtime:1,0 serialNr ' .
	                          'model:' . HM485::Device::getModelList() . ' ' .
	                          'subType ' .
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
	my $addr   = substr($hmwId, 0, 8);
	my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
	my $msg    = undef;

	if (int(@a)!=3 || (defined($a[2]) && $a[2] !~ m/^[A-F0-9]{8}_{0,1}[A-F0-9]{0,2}$/i)) {
		$msg = 'wrong syntax: define <name> HM485 <8-digit-hex-code>[_<2-digit-hex-code>]';

	} elsif ($modules{HM485}{defptr}{$hmwId}) {
		$msg = 'Device ' . $hmwId . ' already defined.'

	} else {
		my $name = $hash->{NAME};
		
		if (defined($chNr)) {
			# We defined a channel of a device
			my $devHash = $modules{HM485}{defptr}{$addr};

			if (defined($devHash) && $devHash) {
				my $devName = $devHash->{NAME};
				$devHash->{'channel_' .  $chNr} = $name;                        # reference this channel to the device entity
				$hash->{device} = $devName;                                     # reference the device to this channel
				$hash->{chanNo} = $chNr;

				# copy definded attributes to channel
				foreach my $attrBindCh (@attrListBindCh) {
#			Log3('', 1, "CommandAttr(undef, $name . ' ' . $attrBindCh . ' ' . $val);");
					my $val = AttrVal($devName, $attrBindCh, undef);
					if (defined($val) && $val) {
						CommandAttr(undef, $name . ' ' . $attrBindCh . ' ' . $val);
					}
				}
				
				# ToDo: check for needing
				#$attr{$name}{peerIDs} = AttrVal($devName, 'peerIDs', '');
				#$hash->{READINGS}{peerList}{VAL} = ReadingsVal($devName, 'peerList', '');
				#$hash->{peerList} = $devHash->{peerList} ? $devHash->{peerList} : undef;
				
			} else {
				$msg = 'Please define the main device ' . $addr . ' before define the device channel';
			} 

		} else {
			# We defined a the device
			AssignIoPort($hash);

			Log3 ($hash, 1, 'Assigned ' . $name . ' (' . $addr . ') to ' . $hash->{IODev}->{NAME});
		}

		if (!$msg) {
			$modules{HM485}{defptr}{$hmwId} = $hash;
			$hash->{DEF} = $hmwId;
			
			if(defined($hash->{IODev}{STATE}) && $hash->{IODev}{STATE} eq 'open') {
				Log3 ($hash, 1, 'Auto get config for : ' . $hmwId);
				HM485_getInfos($hash, $addr, 0b0011);
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

	my $devName = $hash->{device};
	my $hmwId   = $hash->{DEF};
	my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;

	if ($chNr) {                                                                # We delete a channel of the device
		my $devHash = $defs{$devName};
		
		if ($devName) {
			delete $devHash->{'channel_' . $chNr} if ($devName);
		}

	} else {                                                                    # We delete a device with all channels
	
		# Delete each chennel of device
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
	my $hmwId = HM485_getHmwidByName($name);
	my $hash  = $defs{$name};
	my $addr  = substr($hmwId,0,8);
	my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;

	if ($chNr){
		# we are channel, inform the device
		$hash->{chanNo} = $chNr;
		my $devHash = HM485_getHashByHmwid($addr);
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
sub HM485_Parse($$$) {
	my ($ioHash, $message) = @_;

	my $msgId   = ord(substr($message, 2, 1));
	my $msgCmd  = ord(substr($message, 3, 1));
	my $msgData = uc( unpack ('H*', substr($message, 4)));
	
	if ($msgCmd == HM485::CMD_RESPONSE || $msgCmd == HM485::CMD_ALIVE) {
		my $ack = ($msgCmd == HM485::CMD_RESPONSE) ? 1 : 0;
		$msgData = substr($msgData,2);
		HM485_ProcessResponse($ioHash, $msgId, $ack, $msgData);

	} elsif ($msgCmd == HM485::CMD_EVENT) {
		HM485_ProcessEvent($ioHash, $msgId, $msgData);

	}
	
	return $ioHash->{NAME};
}

sub HM485_ProcessResponse($$$$) {
	my ($ioHash, $msgId, $ack, $msgData) = @_;

#Log3('', 1, "msgId: $msgId");
	if (exists($ioHash->{'.waitForInfo'}{$msgId})) {
		my $type   = $ioHash->{'.waitForInfo'}{$msgId}{requestType};
		my $target = $ioHash->{'.waitForInfo'}{$msgId}{target};

		my $hash = $modules{HM485}{defptr}{$target};
		my $name = $hash->{NAME};
		
		my $attrName  = $HM485::responseAttrMap{$type};
		my $model = '';

		if ($ack) {
			# We got an ACK
	
			# Check if main device exists or we need create it
			if(exists($hash->{DEF}) && $hash->{DEF} eq $target) {
	
				my $attrVal  = '';

				if ($type eq '4B' || $type eq '53' || $type eq '78' || $type eq 'CB') { # K (report State)
					#HM485_processStateData($msgData);

				} elsif ($type eq '52') {                                       # R (report Eeprom Data)
					#HM485_processEepromData($msgData);

				} elsif ($type eq '68') {                                       # h (report module type)
					$attrVal = HM485_parseModuleType($msgData);

					# we query detail infos only of no model defined
					if (!AttrVal($name, 'model', undef)) {
						HM485_getInfos($hash, $target, 0b1100);
						
						$model = HM485::Device::getModelFromType(
							hex(substr($msgData,0,2))
						);
						my $modelName  = HM485::Device::getModelName($model);
						if (defined($modelName) && $modelName) {
							CommandAttr(undef, $name . ' comment ' . $modelName);
						}
					}

				} elsif ($type eq '6E') {                                       # n (report serial number)
					$attrVal = HM485_parseSerialNumber($msgData);

				} elsif ($type eq '70') {                                       # p (report packet size, only in bootloader mode)
				} elsif ($type eq '72') {                                       # r (report firmwared data, only in bootloader mode)
	
				} elsif ($type eq '76') {                                       # v (report firmware version)
					$attrVal = HM485_parseFirmwareVersion($msgData);

				}
	
				if ($attrVal) {
					CommandAttr(undef, $name . ' ' . $attrName . ' ' . $attrVal);
				}
				
				if ($model) {
					# Create subdevices if we have a modeltype
					# ToDo: this should create only on deiscovery?
					HM485_CreateSubdevices($hash, $model);
				}
				
				HM485_ProcessChannelState($hash, $target, $msgData);
	
			} else {
				$ioHash->{'.forAutocreate'}{$target}{$attrName} = $msgData;
		
				if ( exists($ioHash->{'.forAutocreate'}{$target}{$HM485::responseAttrMap{'68'}}) &&
				     exists($ioHash->{'.forAutocreate'}{$target}{$HM485::responseAttrMap{'6E'}}) ) {
		
				 	HM485_autocreate($ioHash, $target);
				}
			}

			readingsSingleUpdate(
				$hash, 'state', $HM485::commands{$type}, 1
			);

		} else {
			#$hash->{STATE} = 'NACK';
			readingsSingleUpdate(
				$hash, 'lastError', 'RESPONSE TIMEOUT: ' . $HM485::commands{$type}, 1
			);

			# We got an NACK
			Log3 ($hash, 1, 'NACK from ' . $target . ' | ' . $type);
		}
	}
	
	delete ($ioHash->{'.waitForInfo'}{$msgId});
}

sub HM485_ProcessChannelState($$$) {
	my ($hash, $target, $msgData) = @_;
	
	my $name      = $hash->{NAME};
	my $frameType = substr($msgData, 0,2);
	my $data      = substr($msgData, 2);
	my $model     = AttrVal($name, 'model', undef);
	
#	if (defined($model) && $model) {
#		my $affectedChannel = HM485::Device::getChannelfieldByModelAndFrametype(
#			$model, $frameType
#		);
#		print Dumper($hash);
#
#		Log3('', 1, "msgData: $msgData, target: $target, frameType: $frameType, data: $data");
#	}
	
#	my $chHash = $modules{HM485}{defptr}{$target};
#	my $hmwId  = $chHash->{DEF};
#	my $name   = $chHash->{NAME};
#	my $addr   = substr($hmwId, 0, 8);
#	my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
#	
#	print Dumper($ioHash);
	
}

sub HM485_getHmwidByName(@) { #in: name or HMid ==>out: HMid, "" if no match
	my ($name) = @_;

	my $hash = $defs{$name};
	my $retVal = '';
	
	if ($hash) {
		$retVal = $hash->{DEF};           #name is entity

	} elsif ($name =~ m/(.*)_chn:(..)/) {
		$retVal = $defs{$1}->{DEF}.$2;
		
	} elsif ($name =~ m/^[A-F0-9]{8,11}$/i) {
		$retVal = $name;
	}
	
	return $retVal;
}

sub HM485_getHashByHmwid ($) {
	my ($hmwId) = @_;
	
	my $retVal;
	if ($modules{HM485}{defptr}{$hmwId}) {
		$retVal = $modules{HM485}{defptr}{$hmwId}
	} else {
		$retVal = $modules{HM485}{defptr}{substr($hmwId,0,8)}
	}
	
	return $retVal;
}







sub HM485_ProcessEvent() {
	my ($hash, $msgId, $msgData) = @_;

	my $source  = substr($msgData, 0,8);      # needed?
	my $cb      = hex(substr($msgData, 8,2));
	my $target  = substr($msgData, 10,8);
	my $data    = substr($msgData, 18);

	my $devHash = $modules{HM485}{defptr}{$target};
	if(!defined($devHash) || !exists($devHash->{DEF}) ) {

		# Module not defined yet. We must query some informations for autocreate
		Log3 ($hash, 1, "Device ($target) not defined yet. Query aditional informations.");
		
		HM485_sendCommand($hash, $target, '68');   # (h) request the module type
		HM485_sendCommand($hash, $target, '6E');   # (n) request the module serial number
		
	} else {

		Log3('', 1, 'Prozess Events');
		HM485_ProcessChannelState($hash, $target, $data);
	}
}

sub HM485_autocreate($$) {
	my ($ioHash, $target) = @_;
	
	my $serialNr = HM485_parseSerialNumber ($ioHash->{'.forAutocreate'}{$target}{$HM485::responseAttrMap{'6E'}});

	my $modelType = $ioHash->{'.forAutocreate'}{$target}{$HM485::responseAttrMap{'68'}};
	my $model     = HM485_parseModuleType($modelType);

	delete ($ioHash->{'.forAutocreate'});

	# Todo: Prevent Loop if Autocreate fails
	# request firmware version and state infos
	HM485_getInfos($ioHash, $target, 0b1100);

	my $deviceName = '_' . $serialNr;
	$deviceName = ($model ne $modelType) ? $model . $deviceName : 'HMW_' . $model . $deviceName;
		
	DoTrigger("global",  'UNDEFINED ' . $deviceName . ' HM485 '.$target);
}

sub HM485_getInfos($$$) {
	my ($hash, $target, $infoMask) = @_;
	$infoMask = defined($infoMask) ? $infoMask : 0;

	Log3 ($hash, 1, "Request aditional informations for device ($target).");

	if ($infoMask & 0b0001) {
		HM485_sendCommand($hash, $target, '68');   # (h) request module type
	}
	
	if ($infoMask & 0b0010) {
		HM485_sendCommand($hash, $target, '6E');   # (n) request serial number
	}
	
	if ($infoMask & 0b0100) {
		HM485_sendCommand($hash, $target, '76');   # (v) request firmware version
	}

	if ($infoMask & 0b1000) {
		Log3('', 1, 'Todo: Get state infos');
	}
}

sub HM485_parseModuleType($) {
	my ($data) = @_;
	
	my $modelNr = hex(substr($data,0,2));
	my $retVal   = HM485::Device::getModelFromType($modelNr);
	$retVal =~ s/-/_/g;
	
	return $retVal;
}

sub HM485_parseSerialNumber($) {
	my ($data) = @_;
	
	my $retVal = substr(pack('H*',$data), 0, 10);
	
	return $retVal;
}

sub HM485_parseFirmwareVersion($) {
	my ($data) = @_;
	
	my $retVal = hex(substr($data,0,2));
	$retVal = $retVal + (hex(substr($data,2,2))/100);

	return $retVal;
}

sub HM485_sendCommand($$$) {
	my ($hash, $target, $data) = @_;
	my $ioHash = $hash->{IODev};

	if (exists($hash->{msgCounter})) {
		# we recocnise the IODev hash with msgCounter
		$ioHash = $hash;
		$hash = $modules{HM485}{defptr}{$target};
		$hash->{IODev} = $ioHash;
		$hash->{NAME} = '.tmp';
	}

	my %params = (target => $target, data   => $data);
	my $requestId = IOWrite($hash, HM485::CMD_SEND, \%params);
	
	my @validRequestTypes = ('4B', '52', '53', '52', '68', '6E', '70', '72', '76', '78', 'CB');
	my $requestType = substr($data, 0,2); 
	if ($requestId && grep $_ eq $requestType, @validRequestTypes) {
		$ioHash->{'.waitForInfo'}{$requestId}{requestType} = $requestType;
		$ioHash->{'.waitForInfo'}{$requestId}{target}      = $target;
	}
} 

sub HM485_CreateSubdevices($$) {
	my ($hash, $hwType) = @_;
	my $name = $hash->{NAME};
	my $hmwId = $hash->{DEF};

	# get related subdevices for this device from config
	my $modelGroup = HM485::Device::getModelGroup($hwType);

	my $subTypes = HM485::Device::getValueFromDefinitions($modelGroup . '/channels');
	if (ref($subTypes) eq 'HASH') {
		my $ch = 1;
		foreach my $subType (sort keys %{$subTypes}) {
			if ($subType ne 'Maintenance') {
				if ( defined($subTypes->{$subType}{count}) && $subTypes->{$subType}{count} > 0) {
					for(my $i = 0; $i < $subTypes->{$subType}{count}; $i++) {
						my $txtCh = sprintf ('%02d' , $ch);
						my $room = AttrVal($name, 'room', '');
						my $devName = $name . '_' . $txtCh;
						my $chHmwId = $hmwId . '_' . $txtCh;
						
						if (!exists($modules{HM485}{defptr}{$chHmwId})) {
							CommandDefine(undef, $devName . ' ' . ' HM485 ' . $chHmwId);
							CommandAttr(undef, $devName . ' subType ' . $subType);
							if ($subType eq 'Key') {
								# Key subtypes don't have a state
								delete($modules{HM485}{defptr}{$chHmwId}{STATE});
							}
						}
						$ch++;
					} 
				}
			}
		}
	}
}

# TODO:
sub HM485_Set($@) {
	my ($hash, @a) = @_;

	my $name =$a[0];
	my $cmd = $a[1];
	my $msg = undef;

	my $hmwId = $hash->{DEF};
	my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
	
	my %sets = ();
	
	if (defined($chNr)) {
		%sets = %setsCh;
		my $allowedSets = HM485_getAllowedSets($hash);
		if ($allowedSets) {
			foreach my $allowedSet (split(':', HM485_getAllowedSets($hash))) {
				$sets{$allowedSet} = '';
			}
		}
		
	} else {
		%sets = %setsDev;
	}
	
	if (@a < 2) {
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
#				$modules{$defs{$name}{TYPE}}{AttrList} =~ s/$item//;
				
			} elsif ($cmd eq 'Press_Long' || $cmd eq 'Press_Short') {
				#Todo: Make ready
				$msg = 'set ' . $name . ' ' . $cmd . ' not yet implemented'; 

			} elsif ($cmd eq 'on' || $cmd eq 'off') {
				#Todo: Make ready
				my $hmwId = $hash->{DEF};
				my $devHash = $modules{HM485}{defptr}{substr($hmwId,0,8)};
				
				my $addr  = substr($hmwId,0,8);
				my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
				my $state = ($cmd eq 'on') ? '01' : '00';
				my $data  = sprintf('78%02X%02X', ($chNr-1), $state);
				HM485_sendCommand($devHash, $addr, $data);
			}
		}
	}

	return $msg;
}

sub HM485_Get($@) {
	my ($hash, @a) = @_;

	my $name =$a[0];
	my $cmd = $a[1];
	my $msg = undef;

	my $hmwId = $hash->{DEF};
	my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
	my %gets  = defined($chNr) ? %getsCh : %getsDev;

	if (@a < 2) {
		$msg =  '"get ' . $name . '" needs one or more parameter'

	} else {
		if(!defined($gets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %gets) {
				$arguments.= $arg . ($gets{$arg} ? (':' . $gets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;

		} elsif ($cmd eq 'info') {
			# all infos (moduleType, serialNumber, firmwareVersion, state
			HM485_getInfos($hash, $hmwId, 0b1111);
		}
	}

	return $msg;
}





=head2 HM485_Attr
	Title:		HM485_Attr
	Function:	Implements AttrFn function.
	Returns:	string|undef
	Args:		named arguments:
				-argument1 => array
=cut
sub HM485_Attr (@) {
	my (undef, $name, $attrName, $val) =  @_;

	my $hash  = $defs{$name};
	my $msg   = '';
	
	my $hmwId = $hash->{DEF};
	my $addr  = substr($hmwId, 0, 8);
	my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;

	if ($attrName) {
		foreach my $attrRO (@attrListRO) {
			if ( $attrName eq $attrRO && AttrVal($name, $attrName, undef) ) {
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

					if (!$msg && defined($chNr)) {
						# if we are a channel, we set webCmd attribute
						HM485_setWebCmd($hash, $val);
					}
				}
			}
		}
		
		if (!$msg) {
			if (!defined($chNr)) {
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

sub HM485_getAllowedSets($;$) {
	my ($hash, $model) = @_;

	my $retVal = undef;
	
	my $name = $hash->{NAME};
	if (!defined($model)) {
		$model = AttrVal($name, 'model', undef);
	}
	
	if (defined($model) && $model) {
		my $hmwId = $hash->{DEF};
		my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
	
		if (defined($chNr)) {
			my $modelGroup = HM485::Device::getModelGroup($model);
			my $subType = HM485::Device::getSubtypeFromChannelNo($modelGroup, $chNr);
			
			if ($subType eq 'Key') {
				$retVal = 'Press_Short:Press_Long';
	
			} elsif ($subType eq 'Switch') {
				$retVal = 'on:off';
			}
		}
	}

	return $retVal;
}

sub HM485_setWebCmd($$) {
	my ($hash, $model) = @_;
	my $name = $hash->{NAME};
	
	my $webCmd = HM485_getAllowedSets($hash, $model);
	if ($webCmd) {
		CommandAttr(undef, $name . ' webCmd ' . $webCmd);
	}
}

1;
