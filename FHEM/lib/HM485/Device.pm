package HM485::Devicefile;
# Version 0.5.141

use constant false => 0;
use constant true => 1;

package HM485::Device;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use POSIX qw(ceil floor);


use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin");
use lib::HM485::Constants;
use lib::HM485::Util;

#use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

# prototypes
sub parseForEepromData($;$$);

my %deviceDefinitions;
my %models = ();

=head2
	Initialize all devices
	Load available device files
=cut
sub init () {
	my $retVal      = '';
	my $devicesPath = $main::attr{global}{modpath} . HM485::DEVICE_PATH;

	if (opendir(DH, $devicesPath)) {
		HM485::Util::logger(HM485::LOGTAG_HM485, 3, 'HM485: Loading available device files');
		HM485::Util::logger(HM485::LOGTAG_HM485, 3, '=====================================');
		foreach my $m (sort readdir(DH)) {
			next if($m !~ m/(.*)\.pm$/);
			
			my $deviceFile = $devicesPath . $m;
			if(-r $deviceFile) {
				HM485::Util::logger(HM485::LOGTAG_HM485, 3, 'Loading device file: ' .  $deviceFile);
				my $includeResult = do $deviceFile;
	
				if($includeResult) {
					foreach my $dev (keys %HM485::Devicefile::definition) {
						$deviceDefinitions{$dev} = $HM485::Devicefile::definition{$dev};
					}
				} else {
					HM485::Util::logger(
						HM485::LOGTAG_HM485, 3,
						'HM485: Error in device file: ' . $deviceFile . ' deactivated:' . "\n $@"
					);
				}
				%HM485::Devicefile::definition = ();

			} else {
				HM485::Util::logger(
					HM485::LOGTAG_HM485, 1,
					'HM485: Error loading device file: ' .  $deviceFile
				);
			}
		}
		closedir(DH);
	
		if (scalar(keys %deviceDefinitions) < 1 ) {
			return 'HM485: Warning, no device definitions loaded!';
		}
		initModels();
	} else {
		$retVal = 'HM485: ERROR! Can\'t read devicePath: ' . $devicesPath . $!;
	}
		
	return $retVal;
}

=head2
	Initialize all loaded models
=cut
sub initModels() {

	foreach my $deviceKey (keys %deviceDefinitions) {					
		if ($deviceDefinitions{$deviceKey}{'supported_types'}) {		
			foreach my $modelKey (keys (%{$deviceDefinitions{$deviceKey}{'supported_types'}})) {
				if ($deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'parameter'}{'0'}{'const_value'}) {
					$models{$modelKey}{'model'} = $modelKey;
					$models{$modelKey}{'name'} = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'name'};
					$models{$modelKey}{'type'} = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'parameter'}{'0'}{'const_value'};
					
					my $minFW = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'parameter'}{'2'}{'const_value'};
					$minFW = $minFW ? $minFW : 0;
					$models{$modelKey}{'versionDeviceKey'}{$minFW} = $deviceKey;
				}
				# PFE BEGIN
				# Handling of the "generic" device
                # This is probably not perfect, but should work
				  elsif($deviceKey eq 'HMW_GENERIC') {
                    $models{$modelKey}{'model'} = $modelKey;
                    $models{$modelKey}{'name'} = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'name'};
					$models{$modelKey}{'type'} = 0;
					$models{$modelKey}{'versionDeviceKey'}{0} = $deviceKey;  
				}
				# PFE END
			}
		}
	}
#	my $t = getModelName(getModelFromType(91));
}

=head2
	Get device key depends on firmware version
=cut
sub getDeviceKeyFromHash($) {
	my ($hash) = @_;

	my $retVal = '';
	if ($hash->{'MODEL'}) {
		my $model    = $hash->{'MODEL'};
		my $fw  = $hash->{'FW_VERSION'} ? $hash->{'FW_VERSION'} : 0;
		my $fw1 = $fw ? int($fw) : 0;
		my $fw2 = ($fw * 100) - int($fw) * 100;

		my $fwVersion = hex(
			sprintf ('%02X%02X', ($fw1 ? $fw1 : 0), ($fw2 ? $fw2 : 0))
		);

		foreach my $version (keys (%{$models{$model}{'versionDeviceKey'}})) {
			if ($version <= $fwVersion) {
				$retVal = $models{$model}{'versionDeviceKey'}{$version};
			} else {
				last;
			}
		}
	}
	
	return $retVal;
}


=head2
	Get the model from numeric hardware type
	
	@param	int      the numeric hardware type
	@return	string   the model
=cut
sub getModelFromType($) {
	my ($hwType) = @_;

	foreach my $model (keys (%models)) {
		if (exists($models{$model}{'type'}) && $models{$model}{'type'} == $hwType) {
			return $model;
		}
	}

	HM485::Util::logger( 'HM485::Device::getModelFromType',1, 'Unknown device type '.$hwType.'. Setting model to Generic' );
	
	return 'HMW_Generic';
}

=head2 getModelName
	Get the model name from model type
	
	@param	string   the model type e.g. HMW_IO_12_Sw7_DR
	@return	string   the model name
=cut
sub getModelName($) {
	my ($hwType) = @_;
	my $retVal = 'unknown';

	if (defined($models{$hwType}{'name'})) {
		$retVal = $models{$hwType}{'name'};
	}
	
	return $retVal;
}

=head2 getModelList
	Get a list of models from $models hash

	@return	string   list of models
=cut
sub getModelList() {
	my @modelList;
	foreach my $type (keys %models) {
		if ($models{$type}{'model'}) {
			push (@modelList, $models{$type}{'model'});
		}
	}

	return join(',', @modelList);
}



sub getBehaviour($) {
	my ($hash) = @_;
	
	my $chConfig = undef;
	my $chType;
	my $extension = undef;
	
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	
	if (defined($chNr) && $chNr > 0) {
		my $deviceKey = getDeviceKeyFromHash($hash);
		
		if ($deviceKey) {
			$chType = HM485::Device::getChannelType($deviceKey, $chNr); #key
			
			my $channelConfig  = getValueFromDefinitions(
				$deviceKey . '/channels/' . $chType
			);
			
			if ( $channelConfig->{'special_parameter'}{'behaviour'} && 
				 $channelConfig->{'special_parameter'}{'behaviour'}{'physical'}{'address'}{'index'}) {
					$chConfig = HM485::ConfigurationManager::getConfigFromDevice($hash, $chNr);
				if ($channelConfig->{'link_roles'}{'source'}{'name'}) {
					$extension = $channelConfig->{'link_roles'}{'source'}{'name'};
				} else {
					foreach my $option (keys @{$chConfig->{'behaviour'}{'possibleValues'}}) {
						if (exists ($chConfig->{'behaviour'}{'possibleValues'}[$option]{'default'})) {
							#$extension = $option;
							$extension = $chConfig->{'behaviour'}{'possibleValues'}[$option]{'id'};
						}
					}
				}
			}
		}
	}

	return ($chConfig, $chType, $extension);
}

sub getBehaviourCommand($) {
	my ($hash) = @_;
	my $retVal = undef;
	
	my ($chConfig, $chType, $extension) = getBehaviour($hash);
	


	if ($chConfig->{'behaviour'}{'value'} && $chConfig->{'behaviour'}{'value'} eq '1') {	
		my $deviceKey = getDeviceKeyFromHash($hash);
		#i only found switch as link_role
		if ($extension eq 'switch') {
			$extension = $extension .'_ch';
		}
		
		my $search  = getValueFromDefinitions(
						$deviceKey . '/channels/' . $chType .'/subconfig/paramset/'
					  );
		if (ref($search) eq 'HASH') {
			#leider kann getValueFromDefinitions nicht tiefer suchen
			foreach my $valueHash (keys %{$search}) {
				my $item = $search->{$valueHash};
				foreach my $found (keys %{$item}) {
					if ($found eq 'type' && $search->{$valueHash}{$found} eq 'values') {
						$retVal = $search->{$valueHash}{'parameter'};
					}
				}
			}
		}
	}
	
	return $retVal;
}


=head2 getChannelBehaviour
	Get the behavior of a chanel from eeprom, if the channel support this

	@param	hash

	@return	array   array of behavior values
=cut
sub getChannelBehaviour($) {
	my ($hash) = @_;
	my $retVal = undef;
	my $bool = 0; #false
	
	my ($chConfig, $chType, $extension) = getBehaviour($hash);

	if (ref ($chConfig) eq 'HASH') {
		$bool = $chConfig->{'behaviour'}{'value'};
		$retVal = HM485::ConfigurationManager::convertValueToOption( $chConfig->{behaviour}{possibleValues}, $bool);
	}
	
	return ($retVal, $bool, $extension);
}




### we should rework below this ###


=head2 getHwTypeList
	Title		: getHwTypeList
	Usage		: my $modelHwList = getHwTypeList();
	Function	: Get a list of model harwaretypes from $models hash
	Returns 	: string
	Args 		: nothing
=cut
sub getHwTypeList() {
	return join(',', sort keys %models);
}

=head2 getValueFromDefinitions
	Get values from definition hash by given path.
	The path is seperated by "/". E.g.: 'HMW_IO12_SW7_DR/channels/KEY'
	
	Spechial path segment can be "key:value". So we can select a hash contains a
	key and match the value. E.g. 'HMW_IO12_SW7_DR/channels/KEY/paramset/type:MASTER'
	
	@param	string	$path
	
	@return	mixed
=cut
sub getValueFromDefinitions($) {
	my ($path) = @_;
	my $retVal = undef;
	my @pathParts = split('/', $path);
	my %definitionPart = %deviceDefinitions;

	my $found = 1;
	foreach my $part (@pathParts) {
		my ($subkey, $compare) = split(':', $part);
		if (defined($subkey) && defined($compare)) {
			$part = HM485::Util::getHashKeyBySubkey({%definitionPart}, $subkey, $compare);
		}

		if (defined($part)) {
			if (ref($definitionPart{$part}) eq 'HASH') {
				%definitionPart = %{$definitionPart{$part}};
				
			} else {
				if ($definitionPart{$part}) {
					$retVal = $definitionPart{$part};
				} else {
					$retVal = undef;
					$found = 0;			
				}
				last;
			}
		} else {
			$found = 0;
			last;
		}
	}
	
	if (!defined($retVal) && $found) {
		$retVal = {%definitionPart};
	}

	return $retVal
}

=head2 getChannelType
	Get a type of a given channel number
	
	@param	string   the device key
	@param	int      the channel number
	
	@return	string   the channel type
=cut
sub getChannelType($$) {
	my ($deviceKey, $chNo) = @_;
	$chNo = int($chNo);
	
	my $retVal = undef;

	my $channels = getValueFromDefinitions($deviceKey . '/channels/');
	my @chArray  = getChannelsByModelgroup($deviceKey);

	foreach my $channel (@chArray) {
		my $chStart = int($channels->{$channel}{'index'});
		my $chCount = int($channels->{$channel}{'count'});
		if (($chNo == 0 && $chStart == 0) || ($chNo >= $chStart && $chNo < ($chStart + $chCount) && $chStart > 0)) {

			$retVal = $channel;
			last;
		}
	}
	
	return $retVal;
}

=head2
	Parse incomming frame data and split to several values
	
	@param	hash	the hash of the IO device
	@param	string	message to parse
=cut
sub parseFrameData($$$) {
	my ($hash, $data, $actionType) = @_;	# hash, 690E03FF, response

	my $behaviour 			= undef;
	my $deviceKey			= HM485::Device::getDeviceKeyFromHash($hash);
	my $channel           	= sprintf("%02d",hex (substr($data, 2, 2)) +1);
	my $hmwId              	= $hash->{'DEF'};
	my $chHash             	= $main::modules{'HM485'}{'defptr'}{$hmwId . '_' . $channel};
	($behaviour, undef) 	= getChannelBehaviour($chHash);
	my $frameData       	= getFrameInfos($deviceKey, $data, 1, $behaviour, 'from_device');
	my $retVal          	= convertFrameDataToValue($hash, $deviceKey, $frameData);

	return $retVal;
}

=head2
	Get all infos of current frame data
	
	@param	string	the deviceKey
	@param	string	the frame data to parse
	@param	boolean	optinal value identify the frame as event 
	@param	string	optional frame direction (from or to device)
=cut
sub getFrameInfos($$;$$$) {
	my ($deviceKey, $data, $event, $behaviour, $dir) = @_;
					
	my $frameType = hex(substr($data, 0,2));  #e.g. 69 or 4B 
	my @retVals;
	
	my $frames = getValueFromDefinitions($deviceKey . '/frames/');
	if(!$frames){ return {}; }; #Device has no Frames, give up 
	
	foreach my $frame (keys %{$frames}) {
		if ($frames->{$frame}{'parameter'}{'index'}) {
			# Rewrite the new configuration to the old one
			# TODO: Is this still needed? Maybe for "old" Homebrew devices 
			my $replace = convertFrameIndexToHash ($frames->{$frame}{'parameter'});
			delete ($frames->{$frame}{'parameter'});
			$frames->{$frame}{'parameter'} = $replace;
		}
		# TODO: This behaviour handling looks a bit hard-coded
		#       Can we read this from the XML?
		if ($behaviour) {
			if ($frame eq 'info_frequency') {
			    if (($behaviour eq 'analog_output') ||
			    	($behaviour eq 'analog_input') || 
			    	($behaviour eq 'digital_input') || 
			    	($behaviour eq 'digital_output')) {
					next;
				}
			} elsif ($frame eq 'info_level') {
				if ($behaviour eq 'frequency_input') {
					next;
				}
			}	
		} else {
			if ($frame eq 'info_frequency') { next; }
		}
	
		my $fType  = $frames->{$frame}{'type'};
		my $fEvent = $frames->{$frame}{'event'} ? $frames->{$frame}{'event'} : 0;
		my $fDir   = $frames->{$frame}{'direction'} ? $frames->{$frame}{'direction'} : 0;
		
		# Frame Type, event and direction are matching?
		if (!($frameType == $fType &&
		   (!defined($event) || $event == $fEvent) &&
		   (!defined($dir) || $dir eq $fDir) )) {
		   next; # no, go on
		}
		my $chField = ($frames->{$frame}{'channel_field'} - 9) * 2;
		my $parameter = translateFrameDataToValue($data, $frames->{$frame}{'parameter'});
		# The above line checks e.g. const_value and might return nothing
		if (!defined($parameter)) { next; }; 
		# Ok, we have found something
		# Daten umstrukturieren
		foreach my $pindex (keys %{$parameter}) {
			my $replace = $parameter->{$pindex}{'param'};
			if (defined($replace)) {
				$parameter->{$replace} = delete $parameter->{$pindex};
				delete $parameter->{$replace}{'param'};	
			}
		}
			
		# collect all the frames we are finding	
		@retVals[scalar @retVals] = {
			ch     => sprintf ('%02d' , hex(substr($data, $chField, 2)) + 1),
			params => $parameter,
			type   => $fType,
			event  => $frames->{$frame}{'event'} ? $frames->{$frame}{'event'} : 0,
			id     => $frame
		};
	}
	if(scalar @retVals > 1) {
		# We found multiple Frames which fit in theory
		# Check for Channel definitions
		foreach my $retVal (@retVals) {
			# in theory, the channel can be different as the channel field 
			# is in the frame definition
			my $chTyp	= getChannelType( $deviceKey, $retVal->{ch});
			my $values = getValueFromDefinitions($deviceKey . '/channels/' . $chTyp . '/paramset/values/parameter/');
			if(!$values){ next; }  # no Frames for this channel?
			foreach my $value (keys %{$values}) {
				if ( defined( $values->{$value}{'physical'}{'get'}{'response'})
					&& $values->{$value}{'physical'}{'get'}{'response'} eq $retVal->{id} ) {
					# found a match, return it
					return $retVal;
				}
			}
		}
	}
	# if we come here, then we have either not return value at all
	if(scalar @retVals == 0) { return {}; } 
	# or there are multiple, but none matching the channel definition
	# or there is anyway exactly one. In both last cases, we just return 
	# the first entry
	return $retVals[0];
}

sub convertFrameIndexToHash($) {
	my ($configSettings) = @_;
	
	my $ConvertHash; # = {};
	my $index = sprintf("%.1f",$configSettings->{'index'});
	
	if ($index) {
		$ConvertHash->{$index} = $configSettings;
		delete $ConvertHash->{$index}{'index'};
	}
	
	return $ConvertHash;
}

sub getValueFromEepromData($$$$;$) {
	my ($hash, $configHash, $adressStart, $adressStep, $wholeByte) = @_;
	
	$wholeByte = $wholeByte ? 1 : 0;
	my $hex = 0;
	my $retVal = '';
	
	my ($adrId, $size, $littleEndian, $readSize) = getPhysicalAddress($hash, $configHash, $adressStart, $adressStep);
	my $tSize = ceil($size);
	
	if (defined($adrId)) {
		my $default;

		if ($readSize) {
			#we send hex data to getValueFromHexData if read_size is set
			$tSize = $readSize;
			$hex = 1;
		}
		
		my $data = HM485::Device::getRawEEpromData(
			$hash, int($adrId), $tSize, $hex, $littleEndian
		);
		
		my $eepromValue = 0;
		
		my $adrStart = (($adrId * 10) - (int($adrId) * 10)) / 10;
		$adrStart    = ($adrStart < 1 && !$wholeByte) ? $adrStart: 0;
		$size        = ($size < 1 && $wholeByte) ? 1 : $size;
		$size		 = ($readSize && $wholeByte) ? $readSize : $size;
		
		$eepromValue = getValueFromHexData($data, $adrStart, $size, $hex);
		
		if ($wholeByte == 0) {
			$retVal = dataConversion($eepromValue, $configHash->{'conversion'}, 'from_device');
			$default = $configHash->{'logical'}{'default'};
		} else { #dataConversion bei mehreren gesetzten bits ist wohl sinnlos kommt null raus
				 #auch ein default Value bringt teilweise nur Unsinn in solchen Fällen Richtig ???
			$retVal = $eepromValue;
		}
		
		if (defined($default)) {
			if ($size == 1) {
				$retVal = ($eepromValue != 0xFF) ? $retVal : $default;
			} elsif ($size == 2) {
				$retVal = ($eepromValue != 0xFFFF) ? $retVal : $default;
			} elsif ($size == 4) {
				$retVal = ($eepromValue != 0xFFFFFFFF) ? $retVal : $default; 
			}
		}
	}
	
	return $retVal;
}


sub getPhysicalAddress($$$$) {
	my ($hash, $configHash, $addressStart, $addressStep) = @_;
		
	my $adrId          = 0;
	my $size           = 0;
	my $littleEndian   = 0;
	my $readSize	   = 0;
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $deviceKey      = HM485::Device::getDeviceKeyFromHash($hash);
	my $chType         = HM485::Device::getChannelType($deviceKey, $chNr);
	my $chConfig       = getValueFromDefinitions(
		$deviceKey . '/channels/' . $chType .'/'
	);
	
	my $chId;
	if (defined $hash->{'.helper'}{'peerNr'}) {
		$chId = int($hash->{'.helper'}{'peerNr'});
	} else {
		$chId = int($chNr) - $chConfig->{'index'};
	}
	
	# we must check if special params exists.
	# Then address_id and step retrieve from special params
	# also the new Configuration has the address step here
	
	if (ref($configHash->{'physical'}) eq 'HASH' && exists $configHash->{'physical'}{'interface'}) {
		if ($configHash->{'physical'}{'interface'} eq 'internal') {
			my $spConfig  = HM485::Device::getValueFromDefinitions(
			    # $configHash->{'physical'}{'value_id'} ist z.B. "behaviour"
				$deviceKey . '/channels/' . $chType .'/special_parameter/'.$configHash->{'physical'}{'value_id'}
			);
			
			if ($spConfig) {
				$addressStep  = $spConfig->{'physical'}{'address'}{'step'} ?
								$spConfig->{'physical'}{'address'}{'step'}  : 0;
				$size         = $spConfig->{'physical'}{'size'} ?
								$spConfig->{'physical'}{'size'} : 1;
				$adrId        = $spConfig->{'physical'}{'address'}{'index'} ?
								$spConfig->{'physical'}{'address'}{'index'} : 0;
				#over 8 bits maybe somtimes i have a better idea
				#it's only relevant for behaviours over 8 channels (io-12-fm for example)
				$adrId        = $adrId + ($chId * $addressStep);
				#set bit over 8 
				if ($size == 0.1 && $chId >= 8) {
					$adrId        = (($adrId *10) + 2) / 10;	
				}
			}			
		} else { ##eeprom
			if (exists $configHash->{'physical'}{'address'}{'index'}){

				$size         = $configHash->{'physical'}{'size'} ?
								$configHash->{'physical'}{'size'} : 1;
				$readSize	  = $configHash->{'physical'}{'read_size'} ?
								$configHash->{'physical'}{'read_size'} : 0;
				$addressStep  = $configHash->{'physical'}{'address'}{'step'} ?
								$configHash->{'physical'}{'address'}{'step'} : $addressStep;
				$adrId        = $configHash->{'physical'}{'address'}{'index'} ?
								$configHash->{'physical'}{'address'}{'index'} : 0;
				$adrId        = $adrId + $addressStart + ($chId * $addressStep);
				$littleEndian = ($configHash->{'physical'}{'endian'} &&
								 $configHash->{'physical'}{'endian'} eq 'little') ? 1 : 0;
				
			}
		}
	} elsif (ref($configHash->{'physical'}) eq 'ARRAY') {
		#hardcoded size for peering address
		$size         = $configHash->{'physical'}[0]{'size'};
		$size         = $size + $configHash->{'physical'}[1]{'size'};
		$adrId        = $configHash->{'physical'}[0]{'address'}{'index'};
		$adrId        = $adrId + $addressStart + ($chId * $addressStep);
	}

	return ($adrId, $size, $littleEndian, $readSize);
}


sub translateFrameDataToValue($$) {
	my ($data, $params) = @_;		# 690EC800, frames/info_level/parameter
	$data = pack('H*', $data);
	my $dataValid = 1;
	my %retVal;
		
	if ($params) {
		foreach my $param (keys %{$params}) {	# params = info_level/parameter
			my $index = $param - 9;
			my $size  = ($params->{$param}{size});
			my $value = getValueFromHexData($data, $index, $size);
			my $constValue = $params->{$param}{const_value};
			# HM485::Util::logger( 'Device:translateFrameDataToValue', 3, ' value = ' . $value . ' constValue = ' . $constValue);
			if ( !defined($constValue) || $constValue eq $value) {
				$retVal{$param}{val} = $value;
				if (defined $constValue) {
					$retVal{$param}{param} = 'const_value';
				} else {
					$retVal{$param}{param} = $params->{$param}{param};
				}
			} else {
				$dataValid = 0;
				last
			}
		}
	}
	
	return $dataValid ? \%retVal : undef;
}

sub getValueFromHexData($;$$$) {
	my ($data, $start, $size, $hex) = @_;

	$start = $start ? $start : 0;
	$size  = $size ? $size : 1;
	
	# the following needs to be done with split as floating point 
	# calculations are not precise (it was done by multiplying the decimals with 10)
	my (undef, $bitsId) = split('\.',$start);
	# usually, addresses and sizes should always be denoted like 12.0, but you never know
	$bitsId = $bitsId ? $bitsId : 0;
	my (undef, $bitsSize) = split('\.',$size);
	$bitsSize = $bitsSize ? $bitsSize : 0;
	
	my $retVal;
	
	if ($hex) {
		if (isInt($start) && $size >=1) {
			$retVal = hex($data);
		} else {
			#jumptables return as hexdata #todo also other values as hex data
			my $mask = 2**$bitsSize - 1;
		
			$retVal = hex($data) >> $bitsId;
			$retVal = $retVal & $mask;
		}
			
	} elsif (isInt($start) && $size >=1) {
		$retVal = hex(unpack ('H*', substr($data, $start, $size)));

	} else {
		$retVal = ord(substr($data, int($start), 1));
		$retVal = subBit($retVal, $bitsId, $bitsSize);
	}

	return $retVal;
}


sub convertFrameDataToValue($$$) {
	my ($hash, $deviceKey, $frameData) = @_;
					
	if (!($frameData->{ch})) { return $frameData; }

	foreach my $valId (keys %{$frameData->{params}}) {
		# HM485::Util::HM485_Log( 'Device:convertFrameDataToValue valId = ' . $valId);
		my $valueMap = getChannelValueMap($hash, $deviceKey, $frameData, $valId);
		if(!(scalar @$valueMap)) {
			# frames zu denen keine valueMap existiert loeschen
			delete $frameData->{params}{$valId};
			next;
		}
		foreach my $valueMapEntry (@$valueMap) { 
			HM485::Util::logger( 'Device:convertFrameDataToValue', 5, 'deviceKey = ' . $deviceKey . ' valId = ' . $valId . ' value1 = ' . $frameData->{params}{$valId}{val});
		
			$frameData->{params}{$valId}{val} = dataConversion(
				$frameData->{params}{$valId}{val},					
				$valueMapEntry->{conversion},
				'from_device'
			);
			HM485::Util::logger( 'Device:convertFrameDataToValue', 5, 'value2 = ' . $frameData->{params}{$valId}{val});
			$frameData->{value}{$valueMapEntry->{name}} = valueToControl(
				$valueMapEntry,
				$frameData->{params}{$valId}{val},
			);
		}
	}

	return $frameData;
}

=head2
	Map values to control specific values

	@param	hash    hash of parameter config
	@param	number    the data value
	
	@return string    converted value
=cut
sub valueToControl($$) {
	my ($paramHash, $value) = @_;
	# Transformieren des Modulwertebereichs in den FHEM Wertebereich
	my $retVal = $value;  # default

	my $control = undef;
	if ( defined( $paramHash->{control}) && $paramHash->{control}) {
		$control = $paramHash->{control};
	}
	my $valName = $paramHash->{name};
	HM485::Util::logger( 'Device:valueToControl', 5, 'valName = ' . $valName . ' = ' . $value);
	if ($control) {
		if ( $control eq 'switch.state') {
			my $threshold = $paramHash->{conversion}{threshold};
			$threshold = $threshold ? int($threshold) : 1;
			$retVal = ($value >= $threshold) ? 'on' : 'off';

		} elsif ($control eq 'door_sensor.state') {
			$retVal = ($value == 0) ? 'closed' : 'open';
		} elsif ($control eq 'dimmer.level' || $control eq 'blind.level' || $control eq 'valve.level') {
			if ( exists $paramHash->{'logical'}{'unit'} && $paramHash->{'logical'}{'unit'} eq '100%') {
				$retVal = $value * 100;
			}
		}
		#digital_analog_input - digital_input has no control
		#the same for direction, working
	} elsif (exists $paramHash->{'logical'}{'type'} && $paramHash->{'logical'}{'type'} eq 'boolean') {
		my $threshold = $paramHash->{conversion}{threshold};	# digital_input + digital_input_values
		$threshold = $threshold ? int($threshold) : 1;
		$retVal = ($value >= $threshold) ? 'on' : 'off';
	} elsif (exists $paramHash->{'logical'}{'type'} && $paramHash->{'logical'}{'type'} eq 'option') {
		# not checking index arrays simply seems to create entries in the array
		my $options = $paramHash->{logical}{option}; 
		if(exists($options->[$value])) {
			$retVal = $options->[$value]{id};
		}else{
		# if $value is out of bounds, find the default option
			HM485::Util::logger( 'Device:valueToControl', 3, 'options = ');
			print(Dumper($options));
			foreach my $option (@$options) {
				print(Dumper($option));
				if(defined($option->{default}) && $option->{default}) {
					return $option->{id};
				}
			}
		}
	
	}
	
	return $retVal;
}

sub onOffToState($$) {
	my ($stateHash, $cmd) = @_;

	my $state = undef;
	my $conversionHash = $stateHash->{conversion};
	my $logicalHash	   = $stateHash->{logical};
	#Todo es gaebe auch: long_[on,off]_level short_[on,off]_level, wäre dann aus dem eeprom zu holen
	
	if ( $cmd eq 'on') {
		if ( $logicalHash->{'type'} eq 'boolean') {
			$state = $conversionHash->{true};
		} elsif ( $logicalHash->{'type'} eq 'float' || $logicalHash->{'type'} eq 'int') {
			$state = $conversionHash->{'factor'} * $logicalHash->{'max'};
		}
		#$state = 1;
	} elsif ( $cmd eq 'off') {
		if ( $logicalHash->{'type'} eq 'boolean') {
			$state = $conversionHash->{false};
		} elsif ( $logicalHash->{'type'} eq 'float' || $logicalHash->{'type'} eq 'int') {
			$state = $conversionHash->{'factor'} * $logicalHash->{'min'};
		}
	} elsif ($cmd eq 'toggle') {
		if ($stateHash->{'control'} eq 'switch.state') {
			$state = 0xFF;
		}
	}

	return $state;
}

sub valueToState($$) {
	my ($valueHash, $value) = @_;
	# Transformieren des FHEM- Wertebereichs in den Modulwertebereich
	my $state = undef;
	
	if ( defined( $value)) {
	
		if ( exists $valueHash->{'logical'}{'unit'} && $valueHash->{'logical'}{'unit'} eq '100%') {
			# Da wir in FHEM einen State von 0 - 100 anzeigen lassen,
			# muss der an das Modul gesendete Wert in den Bereich von 0 - 1 
			# transferiert werden
			$value = $value / 100;
		}
		my $factor = $valueHash->{conversion}{factor} ? $valueHash->{conversion}{factor} : 1;
	
		$state = int($value * $factor);
	}

	return $state;
}


sub simCounter($$$) {
	my ($stateHash, $cmd, $lastCounter) = @_;
	
	my $ret;
	my $countersize = $stateHash->{'conversion'}{'counter_size'} ? int($stateHash->{'conversion'}{'counter_size'}) : 1;
	my $oldcounter = $lastCounter ? $lastCounter : 1;

	
	if ($oldcounter >= 2 ** $countersize -1) {
		$ret = '0';
	} else {
		$ret = $oldcounter + 1 ; 
	}

	return $ret;


}

sub buildFrame($$$;$) {
	my ($hash, $frameType, $frameData, $peer) = @_;



	my $retVal;

	if (ref($frameData) eq 'HASH') {
		my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
		my $devHash        = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
		my $deviceKey      = HM485::Device::getDeviceKeyFromHash($devHash);

		my $frameHash = HM485::Device::getValueFromDefinitions(
			$deviceKey . '/frames/' . $frameType .'/'
		);
		
		if (ref($frameHash->{'parameter'}) eq 'HASH') {
			
			if ($peer) {
				#send a keysym (CB)
				$retVal  = sprintf('%02X%02X%02X', '203', $chNr-1 ,substr($peer,9,2) - 1 );
				$retVal .= translateValueToFrameData ($frameHash->{'parameter'},$frameData);
				$retVal .= substr($hmwId,0,8);
			} else {
				$retVal  = sprintf('%02X%02X', $frameHash->{'type'}, $chNr-1);
				$retVal .= translateValueToFrameData ($frameHash->{'parameter'},$frameData);
			}
		}
	}

	return $retVal;
}


sub translateValueToFrameData ($$) {
	my ($frameParam, $frameData) = @_;
	
	my $retVal;
	my $key     = (keys %{$frameData})[0];
	my $valueId = $frameData->{$key}{'physical'}{'value_id'};
	
	# HM485::Util::logger('translateValueToFrameData', 3, 'frameParam: ');
	# print(Dumper($frameParam));
	
	if ($valueId && $key) {
		if ($frameParam->{'size'}) {
			my $paramLen = $frameParam->{'size'};
			$retVal.= sprintf('%0' . $paramLen * 2 . 'X', $frameData->{$key}{'value'});
		} else {
			my $value = undef;
			
			foreach my $index (keys %{$frameParam}) {
				
				my $shift    = $index *10 - floor($index) * 10;
				my $paramLen = $frameParam->{$index}{'size'} ? $frameParam->{$index}{'size'} : 1;
				
				# fixed value?
				if (defined ($frameParam->{$index}{'const_value'})) {
					$frameData->{$key}{'value'} = $frameParam->{$index}{'const_value'};
				}
				
				if ($paramLen >= 1) {
					$retVal.= sprintf('%0' . $paramLen * 2 . 'X', $frameData->{$key}{'value'});
				} else {
					# bitschupsen
					my $val = $frameData->{$key}{'value'} << $shift;
					$value += $val;
				}
			}
			
			if (defined $value) {
				$retVal .= sprintf('%02X', $value);
			}
		}
	}
	
	return $retVal;
}

=head2
	Convert values specifyed in config files

	@param	number    the value to convert
	@param	hast      convertConfig hash
	@param	string    the converting direction
	
	@return string    converted value
=cut
sub dataConversion($$;$) {
	my ($value, $convertConfig, $dir) = @_;   # 0, channels/paramset/master/INPUT_LOCKED/conversion, to_device
	
	my $retVal = $value;
	if (ref($convertConfig) eq 'HASH') {
	
		my $valHash->{'value'} = $value;
		$dir     = ($dir && $dir eq 'to_device') ? 'to_device' : 'from_device';
		my $type = $convertConfig->{'type'};
		
		if ($type) {
			$valHash = dataConvertValue( $valHash, $convertConfig, $dir);
		} else {
			# try in reverse order
			my $countKeys = keys %{$convertConfig};
			for (my $i = $countKeys; $i >= 1; $i--) {
				$type = $convertConfig->{$i}{'type'};
				if ($type) {
					my $tmpConvertConfig = $convertConfig->{$i};
				
					$valHash = dataConvertValue( $valHash, $tmpConvertConfig, $dir);	
				}
			}
		}
		$retVal = $valHash->{'value'};
	}
	HM485::Util::logger('HM485:Device:dataConversion', 5, 'retVal = ' . $retVal);
	return $retVal;
}

sub dataConvertValue ($$$) {
	my ($valHash, $convertConfig, $dir) = @_;
	
	my $value   = $valHash->{'value'};
	my $mask    = $valHash->{'mask'} ? $valHash->{'mask'} : 0;
	my $retVal  = $value;
	my $retHash = {};
	my $type    = $convertConfig->{'type'};
	
	
	if (ref($convertConfig->{'value_map'}) eq 'HASH' && $convertConfig->{'type'}) {
		if (ref($convertConfig->{'value_map'}) eq 'HASH') {
			if ($convertConfig->{'type'} eq 'integer_integer_map') {
				my $valParam  = $convertConfig->{'value_map'}{'parameter_value'} ? 
								$convertConfig->{'value_map'}{'parameter_value'} : 0;
				my $valDevice = $convertConfig->{'value_map'}{'device_value'} ?
								$convertConfig->{'value_map'}{'device_value'} : 0;
				my $valMask	  = $convertConfig->{'value_map'}{'mask'} ?
								$convertConfig->{'value_map'}{'mask'} : 0;
				if ($valMask) {
						$retHash->{'mask'} = $value & $valDevice;
					}
						
				if ($dir eq 'to_device' && $convertConfig->{'value_map'}{'to_device'}) {
					$retVal = ($value == $valParam) ? $valDevice : $retVal;
					
				} elsif ($dir eq 'from_device' && $convertConfig->{'value_map'}{'from_device'}) {
					$retVal = ($value == $valDevice) ? $valParam : $retVal;
				}
				
			} elsif ($convertConfig->{'type'} eq 'option_integer') {
				my $valParam = 0;
				my $valDevice = 0;
				
				foreach my $key (keys %{$convertConfig->{'value_map'}}) {
					
					$valParam  = $convertConfig->{'value_map'}{$key}{'parameter_value'};	
					$valDevice = $convertConfig->{'value_map'}{$key}{'device_value'};
					
					if ($dir eq 'to_device' && $convertConfig->{'value_map'}{$key}{'to_device'}) {
						if ($value == $valParam) {
							$retVal = $valDevice;
							last;
						}
					} elsif ($dir eq 'from_device' && $convertConfig->{'value_map'}{$key}{'from_device'}) {
						if ($value == $valDevice) {
							$retVal = $valParam;
							last;
						}
					}
				}
			}
		}
	}

	if ($type eq 'float_integer_scale' || $type eq 'integer_integer_scale') {
		my $factor = $convertConfig->{'factor'} ? $convertConfig->{'factor'} : 1;
		my $offset = $convertConfig->{'offset'} ? $convertConfig->{'offset'} : 0;
		$factor = ($type eq 'float_integer_scale') ? $factor : 1;
		
		if ($dir eq 'to_device') {
			$retVal = $retVal + $offset;
			$retVal = int($retVal * $factor); 
		} else {
			$retVal = $retVal / $factor;
			$retVal = sprintf("%.2f", $retVal - $offset);
		}
	
	} elsif ($type eq 'boolean_integer') {
		my $threshold = $convertConfig->{'threshold'} ? $convertConfig->{'threshold'} : 1;
		my $invert    = $convertConfig->{'invert'} ? 1 : 0;			
		my $false     = $convertConfig->{'false'} ? $convertConfig->{'false'} : 0;
		my $true      = $convertConfig->{'true'} ? $convertConfig->{'true'} : 1;
	
		if ($dir eq 'from_device') {
			$retVal = ($value >= $threshold) ? 1 : 0;
			$retVal = (($invert && $retVal) || (!$invert && !$retVal)) ? 0 : 1; 
		} else {
			$retVal = (($invert && $value) || (!$invert && !$retVal)) ? 0 : 1;
			$retVal = ($retVal >= $threshold) ? $true : $false;
		}

	} elsif ($type eq 'float_configtime') {
		my $valSize = $convertConfig->{'value_size'} ?
					  $convertConfig->{'value_size'} : 0;
		# i only need the first 2 bits
		my $factor  = $mask >> ($valSize * 10 - 2);
		my @factors = split (',',$convertConfig->{'factors'});
		
		if ($dir eq 'to_device') {
			#Todo 
			if ($factor == 3) {
				#special_value
				$retVal = $value;
			} else {
				$retVal = int ($value / $factors[$factor]);
			}
			
		} elsif ($dir eq 'from_device') {
			$retVal = ($value - $mask) * $factors[$factor];
			#special_value
			if ($retVal == 0 && $factor == 3) { $retVal = $value; }
		}
	}
	
	$retHash->{'value'} = $retVal;
	return $retHash;
}


sub getChannelValueMap($$$$) {
	my ($hash, $deviceKey, $frameData, $valId) = @_;
		
	my $channel = $frameData->{'ch'};
	my $chType  = getChannelType($deviceKey, $channel);
	my $hmwId   = $hash->{'DEF'}; 
	my $chHash  = $main::modules{'HM485'}{'defptr'}{$hmwId . '_' . $channel};
	my $values;
	
	my ($behaviour, $bool, $extension) = HM485::Device::getChannelBehaviour($chHash);
	
	if ($extension && $extension eq 'switch') {
		$extension = $extension .'_ch';
	}
	
	my $valuePrafix = $bool ? '/subconfig/paramset/hmw_'. $extension. 
		'_values/parameter' : '/paramset/values/parameter/';
	
	$values = getValueFromDefinitions(
		$deviceKey . '/channels/' . $chType . $valuePrafix
	);
	
	my @retVal = ();
	if (defined($values)) {
		if (exists ($values->{'id'})) {
			# oh wie ich diese id's hasse :-(
			if ($values->{'physical'}{'value_id'} eq $valId) {
				if (!defined($values->{'physical'}{'event'}{'frame'}) ||
					$values->{'physical'}{'event'}{'frame'} eq $frameData->{'id'}) {
						
					my $id = $values->{'id'};
					$retVal[0] = $values;
					$retVal[0]{name} = $id;
					}
				}		
		} else {
			foreach my $value (keys %{$values}) {
				if ($values->{$value}{'physical'}{'value_id'} eq $valId) {
					if (!defined($values->{$value}{'physical'}{'event'}{'frame'}) ||
						$values->{$value}{'physical'}{'event'}{'frame'} eq $frameData->{'id'}) {

						$retVal[scalar @retVal] = $values->{$value};
						$retVal[$#retVal]{name} = $value;
					}
				}
			}
		}
	}
	#Todo Log5
	#print Dumper ("getChannelValueMap,$valId bevaviour:$behaviour bool:$bool extension:$extension chtype:$chType");
	
	return \@retVal;
}

sub getEmptyEEpromMap($) {
	my ($hash) = @_;

	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
	my $eepromAddrs = parseForEepromData( getValueFromDefinitions( $deviceKey));  # Device- Informationen einlesen und aus diesen die EEpromadressen extrahieren
	
	my $eepromMap = {};
	my $blockLen = 16;
	my $blockCount = 0;
	my $addrMax = 1024;
	my $adrCount = 0;
	my $hexBlock;
											# 64
	for ($blockCount = 0; $blockCount < ($addrMax / $blockLen); $blockCount++) {
		my $blockStart = $blockCount * $blockLen;  # 16
		foreach my $adrStart (sort keys %{$eepromAddrs}) {
			my $len = $adrStart + $eepromAddrs->{$adrStart};
			if (($adrStart >= $blockStart && $adrStart < ($blockStart + $blockLen)) || ($len >= $blockStart)) {

				my $blockId = sprintf ('%04X' , $blockStart);
				if (!$eepromMap->{$blockId}) {
					$eepromMap->{$blockId} = '##' x $blockLen;
				}
				if ($len <= ($blockStart + $blockLen)) {
					delete ($eepromAddrs->{$adrStart});				
				}
			} else {
				last;
			}
		}
	}

	return $eepromMap;
}

=head2
	Get EEprom data from hash->READINGS with specific start address and lenth

	@param	hash       hash	hash of device addressed
	@param	int        start address
	@param	int        count bytes to retreve
	@param	boolean    if 1 return as hext string
	
	@return string     value string
=cut
sub getRawEEpromData($;$$$$) {
	my ($hash, $start, $len, $hex, $littleEndian) = @_;
	
	my $hmwId   = $hash->{DEF};
	my $devHash = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
	# HM485::Util::HM485_Log( 'Device:getRawEEpromData hmwId = ' . $hmwId);
	
	my $blockLen = 16;
	my $addrMax = 1024;
	my $blockStart = 0;
	my $blockCount = 0;
	
	$start        = defined($start) ? $start : 0;		# 8
	$len          = defined($len) ? $len : $addrMax;	# 1
	$hex          = defined($hex) ? $hex : 0;
	$littleEndian = defined($littleEndian) ? $littleEndian : 0;

	if ($start > 0) {
		$blockStart = int($start/$blockLen);
	}

	my $retVal = '';
	for ($blockCount = $blockStart; $blockCount < (ceil($addrMax / $blockLen)); $blockCount++) {	# von 0 bis 64
		my $blockId = sprintf ('.eeprom_%04X' , ($blockCount * $blockLen));
		# HM485::Util::HM485_Log( 'Device:getRawEEpromData blockId = ' . $blockId);
		if ($devHash->{READINGS}{$blockId}{VAL}) {
			$retVal.= $devHash->{READINGS}{$blockId}{VAL};
			# HM485::Util::HM485_Log( 'Device:getRawEEpromData Reading = ' . $devHash->{READINGS}{$blockId}{VAL});
		} else {
			$retVal = 'FF' x $blockLen;
			# HM485::Util::HM485_Log( 'Device:getRawEEpromData Reading = nicht vorh.');
		}

		if (length($retVal) / 2 >= $start - $blockStart * $blockLen + $len) {
			last;
		}
	}

	my $start2 = ( ( ($start/$blockLen) - $blockStart ) * $blockLen );	# 8
	
	$retVal = pack('H*', substr( $retVal, ( $start2 * 2), ( $len * 2) ) );
	$retVal = $littleEndian ? reverse($retVal) : $retVal;
	$retVal = $hex ? unpack('H*', $retVal) : $retVal;
	
	return $retVal;
}

sub setRawEEpromData($$$$) {
	my ($hash, $start, $len, $data) = @_;

    # HM485::Util::logger('setRawEEpromData', 3, 'Start: '.$start.' Len: '.$len.' Data: '.$data);

	$len = hex($len) * 2;
	$data = substr($data, 0, $len);
	my $blockLen = 16;
	my $addrMax = 1024;
	my $blockStart = 0;
	my $blockCount = 0;
	
	$start = hex($start);
	
	if ($start > 0) {
		$blockStart = int($start / $blockLen);  # Die 2 kuerzt sich hier raus
	}
  
	for ($blockCount = $blockStart; $blockCount < (ceil($addrMax / $blockLen)); $blockCount++) {

		my $blockId = sprintf ('.eeprom_%04X' , ($blockCount * $blockLen));
		my $blockData = $hash->{READINGS}{$blockId}{VAL};
		if (!$blockData) {
			# no blockdata defined yet
			$blockData = 'FF' x $blockLen;
		}
		# HM485::Util::logger('setRawEEpromData', 3, $blockId.' Old Block Data: ' .  $blockData);

		my $dataStart = ($start * 2) - ($blockCount * ($blockLen * 2));
		my $dataLen = $len;

		if ($dataLen > (($blockLen * 2) - $dataStart)) {
			$dataLen = ($blockLen * 2) - $dataStart;
		}

		my $newBlockData = $blockData;

		if ($dataStart > 0) {
			$newBlockData = substr($newBlockData, 0, $dataStart);
		} else {
			$newBlockData = '';
		}

		$dataLen = ($len <= $dataLen) ? $len : $dataLen;
		$newBlockData.= substr($data, 0, $dataLen);

		if ($dataStart + $dataLen < ($blockLen * 2)) {
			$newBlockData.= substr(
				$blockData, ($dataStart + $dataLen), ($blockLen * 2) - $dataStart + $dataLen
			);
			$data = '';
		} else {
			$data = substr($data, $dataLen);
			$start = ($blockCount * $blockLen) + $blockLen;
		}
		# HM485::Util::logger('setRawEEpromData', 3, $blockId.'New Block Data: ' .  $newBlockData);
        main::setReadingsVal($hash, $blockId, $newBlockData, main::TimeNow());

		$len = length($data);
		if ($len == 0) {
			last;
		}
	}
    delete $hash->{'cache'};
}

=head2
	Walk thru device definition and found all eeprom related values
	
	Todo: Maybe we don't need the function. We should ask the device for used eeprom space
	
	@param	hash    the whole config for thie device
	@param	hash    holds the eeprom adresses with length
	@param	hash    spechial params passed while recursion for getEEpromData
	
	@return hash    $adrHash
=cut
sub parseForEepromData($;$$) {
	my ($configHash, $adrHash, $params) = @_;

	$adrHash = $adrHash ? $adrHash : {};
	$params  = $params ? $params : {};
	
	# first we must collect all values only, hahes was pushed to hash array
	my @hashArray = ();
	foreach my $param (keys %{$configHash}) {
		if (ref($configHash->{$param}) ne 'HASH') {
			if ($param eq 'count' || $param eq 'address_start' || $param eq 'address_step') {
				$params->{$param} = $configHash->{$param};		# params->{address_start} = 0x07
			}
		} else {
			push (@hashArray, $param);
		}
	}

	# now we parse the hashes
	foreach my $param (@hashArray) {
		my $p = $configHash->{$param};

		# Todo: Processing Array of hashes (type array) 

		if ((ref ($p->{physical}) eq 'HASH') && $p->{physical} && $p->{physical}{interface} && ($p->{physical}{interface} eq 'eeprom') ) {
			my $result = getEEpromData($p, $params);
			@{$adrHash}{keys %$result} = values %$result;

		} else {
			$adrHash = parseForEepromData($p, $adrHash, {%$params});
		}
	}

	return $adrHash;
}

=head2
	calculate the eeprom adress with length for a specific param hash
	
	@param	hash    the param hash
	@param	hash    spechial params passed while recursion for getEEpromData

	@return hash    eeprom addr -> length
=cut
sub getEEpromData($$) {
	my ($paramHash, $params) = @_;
	
	my $count = ($params->{count} && $params->{count} > 0) ? $params->{count} : 1; 
	my $retVal;
	
	if ($params->{address_start} && $params->{address_step}) {
		my $adrStart  = $params->{address_start} ? $params->{address_start} : 0; 
		my $adrStep   = $params->{address_step} ? $params->{address_step} : 1;
		
		$adrStart = sprintf ('%04d' , $adrStart);
		$retVal->{$adrStart} = $adrStep * $count;

	} elsif ($params->{'address'}{'step'}) {
		# alternate Configuration
		my $adrStart  = 0;
		my $adrStep   = $paramHash->{'address'}{'step'} ? $paramHash->{'address'}{'step'} : 1;
		
		$adrStart = sprintf ('%04d' , $adrStart);
		$retVal->{$adrStart} = $adrStep * $count;

	} else {
		if ($paramHash->{'physical'}{'address_id'}) {
			my $adrStart =  $paramHash->{'physical'}{'address_id'};
			$adrStart = sprintf ('%04d' , $adrStart);

			my $size = $paramHash->{'physical'}{'size'};
			$size = $size * $count;
			$size = isInt($paramHash->{'physical'}{'size'}) ? $size : ceil(($size / 0.8));
			
			$retVal->{$adrStart} = $size;
		} elsif ( $paramHash->{physical}{address}{index}) {
			my $adrStart = $paramHash->{physical}{address}{index};
			$adrStart = sprintf ('%04d' , $adrStart);

			my $size = $paramHash->{physical}{size};
			$size = $size * $count;
			$size = isInt($paramHash->{physical}{size}) ? $size : ceil(($size / 0.8));

			$retVal->{$adrStart} = $size;
		}
	}

	return $retVal;
}

sub getChannelsByModelgroup($) {
	my ($deviceKey) = @_;
	my $channels = getValueFromDefinitions($deviceKey . '/channels/');
	my @retVal = ();
	foreach my $channel (keys %{$channels}) {
		push (@retVal, $channel);
	}
	
	return @retVal;
}

sub isNumber($) {
	my ($value) = @_;
	
	my $retVal = (looks_like_number($value)) ? 1 : 0;
	
	return $retVal;
}

sub isInt($) {
	my ($value) = @_;
	
	$value = (looks_like_number($value)) ? $value : 0;
	my $retVal = ($value == int($value)) ? 1 : 0;
	
	return $retVal;
}

sub subBit ($$$) {
	my ($byte, $start, $len) = @_;

	return (($byte << (8 - $start - $len)) & 0xFF) >> (8 - $len);
}


sub updateBits ($$$$) {
	my ($eepromValue, $value, $size, $index) = @_;
	#We handle everything as bits, also numbers are more bits
	
	my $bitIndex = ($index * 10) - (int($index) *10);
	my $bitSize  = $size * 10;
	my $retVal   = $eepromValue;
	
	#get the bit
	$value = $value << $bitIndex;
	for (my $i = 0; $i < $bitSize; $i++) {
		
		my $mask = 1 << $i + $bitIndex;
		my $bit  = $value & $mask;
		
		if ($bit) { #bit 1
			$retVal = $retVal | $mask;
		} else {    #bit 0
			my $bitMask = ~(1 << $i + $bitIndex);
			$retVal = $retVal & $bitMask;
		}
	}
	#print Dumper ("updateBits $eepromValue, $value, $size, $index, $retVal");
	return $retVal;
}


sub internalUpdateEEpromData($$) {
	my ($devHash, $requestData) = @_;

	my $start = substr( $requestData, 0, 4);
	my $len   = substr( $requestData, 4, 2);
	my $data  = substr( $requestData, 6);

	setRawEEpromData($devHash, $start, $len, $data);
    delete $devHash->{'cache'};
}

sub parseModuleType($) {
	my ($data) = @_;
	
	# Todo sometimes there comes a big number don't now how to parse
	my $retVal;
	if (length ($data) > 4) {
		my $modelNr = hex(substr($data,4,2));
		print Dumper ("parseModuleType bigstring:$modelNr",$data);
		return undef;
	}	
	# HM485::Util::HM485_Log( 'Device:parseModuleType data = ' . $data);
	my $modelNr = hex(substr($data,0,2));
	if (!defined($modelNr)) { return undef };
	# HM485::Util::HM485_Log( 'Device:parseModuleType modelNr = ' . $modelNr);
	$retVal  = getModelFromType($modelNr);
	if ( $retVal) {
		$retVal =~ s/-/_/g;
	}
	
	return $retVal;
}

sub parseSerialNumber($) {
	my ($data) = @_;
	
	my $retVal = substr(pack('H*',$data), 0, 10);
	
	return $retVal;
}

sub parseFirmwareVersion($) {
	my ($data) = @_;
	my $retVal = undef;
	
	if (length($data) == 4) {
		$retVal = hex(substr($data,0,2));
		$retVal = $retVal + (hex(substr($data,2,2))/100);
	}

	return $retVal;
}

sub getAllowedSets($) {
	my ($hash) = @_;
	#Todo peerings abfragen für press_long press_short
	
	my $name   = $hash->{'NAME'};
	my $model  = $hash->{'MODEL'};
	
	my %cmdOverwrite = (
		'switch.state'	=> "on:noArg off:noArg"
	);
		
	my %cmdArgs = (
		'none'			=> "noArg",
   		'blind.level'	=> "slider,0,1,100 on:noArg off:noArg",
   		'blind.stop'	=> "noArg",
   		'dimmer.level' 	=> "slider,0,1,100 on:noArg off:noArg",
   		'valve.level' 	=> "slider,0,1,100 on:noArg off:noArg",
   		'button.long'	=> "noArg",
   		'button.short'	=> "noArg",
   		'digital_analog_output.frequency' => "slider,0,1,50000 frequency2:textField",
	);
	
	my @cmdlist;
	my $retVal = undef;

	if (defined($model) && $model) {
		
		my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

		if (defined($chNr)) {
			
			my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
			my $chType    = getChannelType($deviceKey, $chNr);
			
			if ($chType) {
				my $commands  = getValueFromDefinitions(
					$deviceKey . '/channels/' . $chType .'/paramset/values/parameter'
				);
				
				my $behaviour = getBehaviourCommand($hash);
				if ($behaviour) {
					$commands = $behaviour;
				}
				
				if (exists ($commands->{'id'})) {
					#only one command
					if ($commands->{'operations'}) {
						my @values = split(',', $commands->{'operations'});
  						foreach my $val (@values) {
    					
    						if ($val eq 'write' && 
    							$commands->{'physical'}{'interface'} eq 'command') {
								
								if ($commands->{'control'}) {
									my $ctrl = $commands->{'control'};
									
									if ($cmdOverwrite{$ctrl}) {
										push @cmdlist, $cmdOverwrite{$ctrl};
									}
							
									if($cmdArgs{$ctrl}) {
										push @cmdlist, "$commands->{'id'}:$cmdArgs{$ctrl}";	
									}
								} else {
									push @cmdlist, "$commands->{'id'}";
								}
							}
    					}
					}
				} else {
					foreach my $command (sort (keys %{$commands})) {
				
						if ($commands->{$command}{'operations'}) {
							my @values = split(',', $commands->{$command}{'operations'});
	  						foreach my $val (@values) {
	    					
    							if ($val eq 'write' && 
    								$commands->{$command}{'physical'}{'interface'} eq 'command') {
									
									if ($commands->{$command}{'control'}) {
										my $ctrl = $commands->{$command}{'control'};
										
										if ($cmdOverwrite{$ctrl}) {
											push @cmdlist, $cmdOverwrite{$ctrl};
										}
							
										if($cmdArgs{$ctrl}) {
											push @cmdlist, "$command:$cmdArgs{$ctrl}";	
										}
									} else {
										push @cmdlist, "$command";
									}
								}
	    					}
						}
					}
				}
			}
		}
	}
	
	$retVal = join(" ",@cmdlist);
	return $retVal;
}

1;