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

use lib '..';
use HM485::lib::Constants;
use HM485::lib::Device;
use HM485::lib::Command;
use HM485::lib::Util;

use Scalar::Util qw(looks_like_number);

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

# Function prototypes

# FHEM Inteface related functions
sub HM485_Initialize($);
sub HM485_Define($$);

my %sets       = ();
my %gets       = ();
my %stdFrames  = ();
my @attrListRO = [];

=head2
	Implements Initialize function
	
	@param	hash	hash of device addressed
=cut
sub HM485_Initialize($) {
	my ($hash) = @_;

	$hash->{Match}    = '^FD.*';
	$hash->{DefFn}    = 'HM485_Define';
	$hash->{UndefFn}  = 'HM485_Undefine';
	$hash->{RenameFn} = 'HM485_Rename';
	$hash->{ParseFn}  = 'HM485_Parse';
	$hash->{SetFn}    = 'HM485_Set';
	$hash->{GetFn}    = 'HM485_Get';
	$hash->{AttrFn}   = 'HM485_Attr';

	$hash->{AttrList} = 'do_not_notify:0,1 ' .
	                     'ignore:1,0 dummy:1,0 showtime:1,0 serialNr ' .
	                     'model:' . HM485::Device::getModelList() . ' ' .
	                     'subType ' .
	                     ' firmwareVersion';

	%sets = (
		'reset'      => ' ',
	#	'devicepair' => 'devicepair',	# ???
	#	'pair'       => 'pair',			# ???
	#	'regRaw'     => 'regRaw',		# ???
	
		# device specific
	#	'on'         => 'on',
	#	'off'        => 'off',

		# channel specific
		'state'      => 'on,off',
	);

	%stdFrames = (
	#	'52' =>	'readEeprom',      # R
	#	'53' => 'levelGet',        # S
		'68' => 'moduleType',      # h
		'6E' => 'serialNumber',    # n
	#	'70' => 'packetSize',      # p
	#	'72' => 'firmwareData',    # q
		'76' => 'firmwareVersion' # v
	);
	
	%gets = (
		'info'         => ' ',
#		'config'     => ' ',
#		'devicepair' => ' ',
#		'regRaw'     => ' ',
#		'regList'    => ' ',
	
		# channel specific
#		'state'      => ' ',
	);
	
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
		
		if (defined($chNr)) {                                                   # We defined a channel of a device
			my $devHash = $modules{HM485}{defptr}{$addr};

			if ($devHash) {
				my $devName = $devHash->{NAME};
				$devHash->{'channel_' .  $chNr} = $name;                        # reference this channel to the device entity
				$hash->{device} = $devName;                                     # reference the device to this channel
				$hash->{chanNo} = $chNr;

				$attr{$name}{model} = AttrVal($devName, 'model', undef);        # Register the model

				# ToDo: check for needing
				#$attr{$name}{peerIDs} = AttrVal($devName, 'peerIDs', '');
				#$hash->{READINGS}{peerList}{VAL} = ReadingsVal($devName, 'peerList', '');
				#$hash->{peerList} = $devHash->{peerList} ? $devHash->{peerList} : undef;
				
			} else {
				$msg = 'Please define the main device ' . $addr . ' before define the device channel';
			} 

		} else {                                                                # We defined a the device
			AssignIoPort($hash);

			Log3 ($hash, 1, 'Assigned ' . $name . ' (' . $addr . ') to ' . $hash->{IODev}->{NAME});
		}

		if (!$msg) {
			$modules{HM485}{defptr}{$hmwId} = $hash;
			$hash->{DEF} = $hmwId;
			
			# Todo: Auto get config for this device?
#			HM485_getInfos($hash, $addr);
			Log3 ($hash, 1, 'Auto get config for : ' . $hmwId . '???');
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
		$devHash->{"channel_".$hash->{chanNo}} = $name;

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

	if (exists($ioHash->{'.waitForInfo'}{$msgId})) {
		my $type   = $ioHash->{'.waitForInfo'}{$msgId}{requestType};
		my $target = $ioHash->{'.waitForInfo'}{$msgId}{target};

		my $hash = $modules{HM485}{defptr}{$target};
		my $name = $hash->{NAME};
		
		my $attrName = $HM485::responseAttrMap{$type};

		if ($ack) {
			# We got an ACK
	
			# Check if main device exists or we need create it
			if(exists($hash->{DEF}) && $hash->{DEF} eq $target) {
	
				my $attrVal  = '';
				if ($type eq '68') {			# model (module type)
					my $modelType = HM485_parseModuleType($msgData);
					$attrVal = HM485::Device::getModel($modelType);
	
				} elsif ($type eq '6E') {
					$attrVal = HM485_parseSerialNumber($msgData);
	
				} elsif ($type eq '76') {
					$attrVal = HM485_parseFirmwareVersion($msgData);
				}
	
				CommandAttr(undef, $name . ' ' . $attrName . ' ' . $attrVal);
	
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
				$hash, 'state', 'RESPONSE TIMEOUT: ' . $HM485::commands{$type}, 1
			);
			print Dumper($HM485::commands);
			# We got an NACK
			Log3 ($hash, 1, 'NACK from ' . $target . ' | ' . $type);
		}
	}
	
	delete ($ioHash->{'.waitForInfo'}{$msgId});
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
	if(!exists($devHash->{DEF}) ) {

		# Module not defined yet. We must query some informations for autocreate
		Log3 ($hash, 1, "Device ($target) not defined yet. Query aditional informations.");
		HM485_requestInfo($hash, $target, '68');   # (h) request the module type
		HM485_requestInfo($hash, $target, '6E');   # (n) request the module serial number
		
	} else {

		my $response = 0;
		my $sentCmd = '0';

		my $name = $devHash->{NAME};

		my $devNew = 0;
		if ($response) {
			if ($sentCmd eq '76') {
				CommandAttr(undef, $name . ' firmware ' . hex(substr($response,0,2)) . '.' . hex(substr($response,2,2)));
#				$attr{$name}{firmware} = hex(substr($response,0,2)) . '.' . hex(substr($response,2,2));
		
			} elsif ($sentCmd eq '68') {
				my $hwType = hex(substr($response,0,2));
				CommandAttr(undef, $name . ' hardwareType ' . $hwType);
#				$attr{$name}{hardwareType} = hex(substr($response,0,2));

#				if (!defined($adrSub) || $adrSub > 0) {
#					HM485_CreateSubdevices($hash, 0x18);
#				}

#				HM485_CreateSubdevices($hash, $hwType);
				
			} elsif ($sentCmd eq '6E') {
				CommandAttr(undef, $name . ' serialNr ' . pack ('H*', $response));
#				$attr{$name}{serialNr} = pack ('H*', $response);
			}
		}
		
		# New device flag is set. Query for device details
		if ($devNew) {
			getInitialDeviceInfos($hash, $source, $target);
		}

	}

	return $hash->{NAME};
}

sub HM485_autocreate($$) {
	my ($ioHash, $target) = @_;
	
	my $serialNr = HM485_parseSerialNumber ($ioHash->{'.forAutocreate'}{$target}{$HM485::responseAttrMap{'6E'}});

	my $modelType = $ioHash->{'.forAutocreate'}{$target}{$HM485::responseAttrMap{'68'}};
	my $model     = HM485_parseModuleType   ($modelType);

	delete ($ioHash->{'.forAutocreate'});

	# Todo: Prevent Loop if Autocreate fails
	# todo query informations on define
	HM485_getInfos($ioHash, $target);

	my $deviceName = '_' . $serialNr;
	$deviceName = ($model ne $modelType) ? $model . $deviceName : 'HMW_' . $model . $deviceName;
		
	DoTrigger("global",  'UNDEFINED ' . $deviceName . ' HM485 '.$target);
}

sub HM485_getInfos($$) {
	my ($hash, $target) = @_;

	Log3 ($hash, 1, "Request aditional informations for device ($target).");

	HM485_requestInfo($hash, $target, '68');   # (h) request module type
	HM485_requestInfo($hash, $target, '6E');   # (n) request serial number
	HM485_requestInfo($hash, $target, '76');   # (v) request firmware version
}

sub HM485_parseModuleType($) {
	my ($data) = @_;
	
	my $modelNr = hex(substr($data,0,2));
	my $retVal   = HM485::Device::getModel($modelNr);
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

sub HM485_requestInfo($$$) {
	my ($hash, $target, $frameType) = @_;
	my $ioHash;

	if ($hash->{DEF} ne $target) {
		$ioHash = $hash;
		$hash = $modules{HM485}{defptr}{$target};
		$hash->{IODev} = $ioHash;
		$hash->{NAME} = '.tmp';
	} else {
		$ioHash = $hash->{IODev};
	}

	# request module type
	my $requestId = HM485_sendCommand($hash, $target, $frameType);
	if ($requestId) {
		$ioHash->{'.waitForInfo'}{$requestId}{requestType} = $frameType;
		$ioHash->{'.waitForInfo'}{$requestId}{target}      = $target;
	}
} 

sub HM485_requestInfo_old($$$) {
	my ($interfaceHash, $target, $frameType) = @_;

	my $hash = $modules{HM485}{defptr}{$target};
	$hash->{IODev} = $interfaceHash;
	$hash->{NAME} = '.tmp';

	# request module type
	my $requestId = HM485_sendCommand($hash, $target, $frameType);
Log3 ('', 1, '$requestId: ' . $requestId);
	if ($requestId) {
		$interfaceHash->{'.waitForInfo'}{$requestId}{requestType} = $stdFrames{$frameType};
		$interfaceHash->{'.waitForInfo'}{$requestId}{target} = $target;
	}
} 


sub HM485_sendCommand($$$) {
	my ($ioHash, $target, $data) =  @_;
	
	my %params = (
		target => $target,
		data   => $data
	);
	
	my $msgId = IOWrite($ioHash, HM485::CMD_SEND, \%params);

	return $msgId;
}

sub HM485_CreateSubdevices($$) {
	my ($hash, $hwType) = @_;
	my $name = $hash->{NAME};
	my $addr = $hash->{DEF};

	# get related subdevices for this device from config
	my $modelGroup = HM485::Device::getModelGroup($hwType);
	my $subTypes = HM485::Device::getValueFromDefinitions($modelGroup . '/channels');

	if (ref($subTypes) eq 'HASH') {
		my $ch = 1;
		foreach my $subType (sort keys %{$subTypes}) {
			if ($subType > 0) {
				if ( defined($subTypes->{$subType}{count}) && $subTypes->{$subType}{count} > 0) {
					for(my $i = 0; $i < $subTypes->{$subType}{count}; $i++) {
						my $txtCh = sprintf ('%02d' , $ch);
						my $room = AttrVal($name, 'room', '');
						my $devName = 'HM485DEV_' . $addr . ':';
						CommandDefine(undef, $devName . ' ' . ' HM485 ' . $addr . ':' . $ch);
						CommandAttr(undef, $devName . ' subType ' . $subTypes->{$subType}{type});
						CommandAttr(undef, $devName . ' room ' . $hash->{TYPE});
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

	if (@a < 2) {
		$msg =  '"set ' . $name . '" needs one or more parameter'

	} else {
		if(!defined($sets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %sets) {
				$arguments.= $arg . ($sets{$arg} ? (':' . $sets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;
		}
	}

	return $msg;
}

sub HM485_Get($@) {
	my ($hash, @a) = @_;

	my $name =$a[0];
	my $cmd = $a[1];
	my $msg = undef;

	my ($addr, $chanNr) = split(':', $hash->{DEF});

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
			HM485_getInfos($hash, $addr);
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
	my $hash = $defs{$name};
	my $msg = '';

	if ($attrName) {
		foreach my $attrRO (@attrListRO) {
			if ( $attrName eq $attrRO && AttrVal($name, $attrName, undef) ) {
#				$msg = 'Attribute ' . $attrName . ' is read only after definition.';
			}
		}
	
		if (!$msg) {
			if ( $attrName eq 'serialNr' && (!defined($val) || $val !~ m/^[A-Za-z0-9]{10}$/i) ) {
				$msg = 'Wrong serialNr (' . $val . ') defined. serialNr must be 10 characters (A-Z, a-z or 0-9).';
		
			} elsif ( $attrName eq 'firmware' && (!defined($val) || !looks_like_number($val)) ) {
				$msg = 'Firmware version must be a number.';
	
			} elsif ( $attrName eq 'hardwareType' ) {
				if ( !defined($val) || !looks_like_number($val) ) {
					$msg = 'HardwareType must be a number.';
				} else {
					configDevice($hash, $val);
					CommandAttr(undef, $name . ' model ' . HM485::Device::getModel($val));
					CommandAttr(undef, $name . ' modelName ' . HM485::Device::getModelName($val));
					
					# access the 4. sub param as reference
	#				$_[3] = $val . ' (' . HM485_getModelFromDefinition($val) . ')'; 
				}
			}
		}
	}
	
	return ($msg) ? $msg : undef;
}



################################################################################
#
################################################################################


=head2 getInitialDeviceInfos
	Title:		getInitialDeviceInfos
	Function:	Get first device properties after found at discovery
	Returns:	noting
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => string:	$address	string with hex device address
				-argument1 => string:	$senderAddr	string with hex sender address
=cut
sub getInitialDeviceInfos($$$) {
	my ($hash, $address, $senderAddr) = @_;

	# Todo: 0x98 change to real ctrl byte

	# get module type
	HM485::Communication::sendRawQueue(
		$hash, pack ('H*', $address), 0x98, pack ('H*', $senderAddr), chr(0x68)
	);

	#get firmware version
	HM485::Communication::sendRawQueue(
		$hash, pack ('H*', $address), 0x98, pack ('H*', $senderAddr), chr(0x76)
	);
	
	# get serial
	HM485::Communication::sendRawQueue(
		$hash, pack ('H*', $address), 0x98, pack ('H*', $senderAddr), chr(0x6E)
	);

	# EEProm Lesen
	HM485::Communication::sendRawQueue(
		$hash, pack ('H*', $address), 0x98, pack ('H*', $senderAddr), pack ('H*', '52000010')
	);

	# EEProm schreiben
#	HM485::Communication::sendRawQueue(
#		$hash, pack ('H*', $address), 0x7A, pack ('H*', $senderAddr), pack ('H*', '57000010FF1400000001FF03FF0AFF0AFFFFFFFF')
#	);

	# E(0x45) ???
#	HM485::Communication::sendRawQueue(
#		$hash, pack ('H*', $address), 0x7C, pack ('H*', $senderAddr), pack ('H*', '450000104')
#	);

	# 3 x EEProm Lesen (Je nach gerät vermutlich)
#	HM485::Communication::sendRawQueue(
#		$hash, pack ('H*', $address), 0x1E, pack ('H*', $senderAddr), pack ('H*', '52001010')
#	);
#	HM485::Communication::sendRawQueue(
#		$hash, pack ('H*', $address), 0x38, pack ('H*', $senderAddr), pack ('H*', '52003010')
#	);
#	HM485::Communication::sendRawQueue(
#		$hash, pack ('H*', $address), 0x5A, pack ('H*', $senderAddr), pack ('H*', '52036010')
#	);

}

=head2 configDevice
	Title:		configDevice
	Function:	Configure the single device on hardware type. Determinate allowed set and get attributes 
	Returns:	noting
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => string:	$address	string with hex device address
				-argument1 => string:	$senderAddr	string with hex sender address
=cut
sub configDevice($$) {
	my ($hash, $hwType) = @_;

	main::Log3 ($hash, 1, 'CONFIG');
}


1;
