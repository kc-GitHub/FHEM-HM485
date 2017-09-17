package HM485::Devicefile;

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
# use lib::HM485::XmlConverter;   # TODO: remove 

# prototypes
sub parseForEepromData($;$$);

my %deviceDefinitions;
my %models = ();

# are device Files ok?
our $deviceFilesOutdated = 0;

sub convertXmls() {
	my $xmlsPath = $main::attr{global}{modpath} . HM485::DEVICE_PATH."xml/";
	my $devicesPath = $main::attr{global}{modpath} . HM485::DEVICE_PATH;
	return "HM485: ERROR: Can\'t read xmlPath: " . $xmlsPath unless (opendir(DH, $xmlsPath));
	HM485::Util::Log3(undef, 3, 'HM485: Converting device files');
	HM485::Util::Log3(undef, 3, '==============================');
	
	# get modification time of XmlConverter.pm
	my $converterTime = (stat($main::attr{global}{modpath}."/FHEM/lib/HM485/XmlConverter.pm"))[9];
    my $converterLoaded = 0;
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.xml$/);
		# check if we need to convert
		# pm file exists? if not, always convert
		my $outputFile = $devicesPath . substr($m,0,-3) . 'pm';
        if( -e $outputFile ){ 
		    # get modification time for xml file
            my $xmlTime = (stat($xmlsPath.$m))[9];
			# get modification time for pm file
			my $pmTime = (stat($outputFile))[9];
			# check
			if($pmTime > $converterTime && $pmTime > $xmlTime) {
                HM485::Util::Log3(undef,3, $m." up to date");
			    next;
			};
		};
        HM485::Util::Log3(undef,3, 'Converting '.$m);
		if(!$converterLoaded) {
		    eval {
			    require lib::HM485::XmlConverter;
				HM485::XmlConverter->import();
			};
			# error ?
			if($@) {
			    HM485::Util::Log3(undef,0, 'Device definition files could not be updated');
                HM485::Util::Log3(undef,0, 'Could not load XML converter, probably perl module XML::Simple is missing');
                HM485::Util::Log3(undef,0, $@);
			    $deviceFilesOutdated = $@;
				return;
			};
			$converterLoaded = 1;
		};
		HM485::XmlConverter::convertFile($xmlsPath.$m, $devicesPath);
    };
};


=head2
	Initialize all devices
	Load available device files
=cut
sub init () {

    convertXmls();

	return "Device definition files could not be updated" if($deviceFilesOutdated);
	
	my $devicesPath = $main::attr{global}{modpath} . HM485::DEVICE_PATH;

	return 'HM485: ERROR! Can\'t read devicePath: ' . $devicesPath . $!
	           unless(opendir(DH, $devicesPath));
	HM485::Util::Log3(undef, 3, 'Loading available device files');
	HM485::Util::Log3(undef, 3, '==============================');
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.pm$/);
		my $deviceFile = $devicesPath . $m;
		if(-r $deviceFile) {
			HM485::Util::Log3(undef, 3, 'Loading device file: ' .  $deviceFile);
			my $includeResult = do $deviceFile;
			if($includeResult) {
				foreach my $dev (keys %HM485::Devicefile::definition) {
					$deviceDefinitions{$dev} = $HM485::Devicefile::definition{$dev};
				}
			} else {
				HM485::Util::Log3(undef, 1,	'Error in device file: ' . $deviceFile . ' deactivated:' . "\n $@");
			}
			%HM485::Devicefile::definition = ();
		} else {
			HM485::Util::Log3(undef, 1, 'Error loading device file: ' .  $deviceFile);
		}
	}
	closedir(DH);
	
	if (scalar(keys %deviceDefinitions) < 1 ) {
		return 'Warning, no device definitions loaded!';
	}

	return '';
}


sub getDeviceKeyAndModel($$) {
	my ($rawDevType, $rawFwVersion) = @_;

	# search for matching device descriptions
    my $bestPriority = -1;  # priority of the generic device is 0
	my @retVal;
	foreach my $deviceKey (keys %deviceDefinitions) {	
	    # ignore the "central" device
		next if($deviceKey eq "HMW_CENTRAL");
        foreach my $modelKey (keys %{$deviceDefinitions{$deviceKey}{supported_types}}) {
			my $model = $deviceDefinitions{$deviceKey}{supported_types}{$modelKey};
			# this should have parameter 
			next unless(defined($model->{parameter}));
			# there might be some bad HBW-XMLs out there... make sure they have higher prio 
			# then the generic device
			my $priority = defined($model->{priority}) ? $model->{priority} : 1;
			# if we already have something, which is as good, go on
			next if($priority <= $bestPriority);
			# check device type, but only if present
			if(defined($model->{parameter}{"0"}) and defined($model->{parameter}{"0"}{const_value})) {
			    next unless($model->{parameter}{"0"}{const_value} == $rawDevType);
			};
			# check fw version, if present
			if(defined($model->{parameter}{"2"}) and defined($model->{parameter}{"2"}{const_value})) {
			    my $op = defined($model->{parameter}{"2"}{cond_op}) ? $model->{parameter}{2}{cond_op} : "EQ";
				if($op eq "EQ") {
				    next unless($model->{parameter}{"2"}{const_value} == $rawFwVersion);
                }elsif($op eq "NE") {
				    next unless($model->{parameter}{"2"}{const_value} != $rawFwVersion);
                }elsif($op eq "GT") {
				    next unless($model->{parameter}{"2"}{const_value} < $rawFwVersion);
                }elsif($op eq "GE") {
				    next unless($model->{parameter}{"2"}{const_value} <= $rawFwVersion);
                }elsif($op eq "LT") {
				    next unless($model->{parameter}{"2"}{const_value} > $rawFwVersion);
                }elsif($op eq "LE") {
				    next unless($model->{parameter}{"2"}{const_value} >= $rawFwVersion);
                }else{
				    # weird
					next;
				};				
			};
			# if we came that far, we have found a match
			@retVal = ($deviceKey,$modelKey);
			$bestPriority = $priority;
		};
	};		
	return @retVal;	
}


=head2
	Get device key depending on firmware version
	Device Key is in principle the name of the device file
=cut
sub getDeviceKeyFromHash($) {
	my ($hash) = @_;

	# $DB::single = 1;
	
	# channel?
	if(defined($hash->{devHash})) {
		$hash = $hash->{devHash};
	}
	# do we have it as a reading?
	return $hash->{READINGS}{"D-deviceKey"}{VAL} if(defined($hash->{READINGS}{"D-deviceKey"}));

	# do we have device type and firmware version?
	return '' unless(defined($hash->{RawDeviceType}) and defined($hash->{RawFwVersion}));
	# now search for matching device descriptions
	my ($devicekey,undef) = getDeviceKeyAndModel($hash->{RawDeviceType},$hash->{RawFwVersion});
	main::HM485_ReadingUpdate($hash,"D-deviceKey",$devicekey) if($devicekey);
	return $devicekey;	
}


=head2 isBehaviour
	Looks if channels behaviour is activ
	@param	hash      hash of device addressed
	
	@return	boolean   behaviour enabled/disabled
=cut

sub isBehaviour($) {
	my ($hash) = @_;
	
	my ($hmwId, $chNr)	= HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $deviceKey 		= getDeviceKeyFromHash($hash);
	my $chType 			= getChannelType($deviceKey, $chNr);
	my $config			= getValueFromDefinitions(
		$deviceKey . '/channels/' .	$chType . '/paramset/master'
	);
	my $retVal;

	foreach my $param (@{$config->{parameter}}) {
        next unless($param->{id} eq "behaviour");	
		$retVal = HM485::ConfigurationManager::writeConfigParameter($hash,
			$param, $config->{address_start}, $config->{address_step}
		);
		last;
	}

	return $retVal->{value}
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
				if ($channelConfig->{link_roles}{source}{name}) {
					$extension = $channelConfig->{link_roles}{source}{name};
				} else {
				    my $behaviour = HM485::Util::getArrayEntryWithId($chConfig, "behaviour");
                    if($behaviour) {
					    foreach my $option (@{$behaviour->{possibleValues}}) {
						    next unless($option->{default});
							$extension = $option->{id};
							last;
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

	my $behaviour = HM485::Util::getArrayEntryWithId($chConfig,"behaviour");
    return undef unless($behaviour && defined($behaviour->{value}) && $behaviour->{value} eq "1"); 	
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

	if (ref ($chConfig) eq 'ARRAY') {
	    my $behaviour = HM485::Util::getArrayEntryWithId($chConfig, "behaviour");
		if($behaviour) {
		    $bool = $behaviour->{value};
		    $retVal = HM485::ConfigurationManager::convertValueToOption( $behaviour->{possibleValues}, $bool);
		};
	}
	
	return ($retVal, $bool, $extension);
}




### we should rework below this ###


# =head2 getHwTypeList
	# Title		: getHwTypeList
	# Usage		: my $modelHwList = getHwTypeList();
	# Function	: Get a list of model harwaretypes from $models hash
	# Returns 	: string
	# Args 		: nothing
# =cut
# sub getHwTypeList() {
	# return join(',', sort keys %models);
# }

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
	if($chHash) {
	    # i.e. not for generic devices or for bugs...
	    ($behaviour, undef) 	= getChannelBehaviour($chHash);
	};
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
			foreach my $value (@$values) {
				if ( defined( $value->{'physical'}{'get'})
					&& $value->{'physical'}{'get'}{'response'} eq $retVal->{id} ) {
					# found a match, return it
					return $retVal;
				}
				if ( defined( $value->{'physical'}{'event'})
					&& $value->{'physical'}{'event'}{'frame'} eq $retVal->{id} ) {
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
		# care for special value
		if(defined($configHash->{logical}{special_value}) &&
                $retVal == $configHash->{logical}{special_value}{value}) {
            $retVal = $configHash->{logical}{special_value}{id};
        };        		
		
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
	
	my $chId  = int($chNr) - $chConfig->{'index'};
	
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
		my $valueMap = getChannelValueMap($hash, $deviceKey, $frameData, $valId);
		if(!(scalar @$valueMap)) {
			# frames zu denen keine valueMap existiert loeschen
			delete $frameData->{params}{$valId};
			next;
		}
		foreach my $valueMapEntry (@$valueMap) { 
			HM485::Util::Log3( $hash, 5, 'Device:convertFrameDataToValue: deviceKey = ' . $deviceKey . ' valId = ' . $valId . ' value1 = ' . $frameData->{params}{$valId}{val});
		
			$frameData->{params}{$valId}{val} = dataConversion(
				$frameData->{params}{$valId}{val},					
				$valueMapEntry->{conversion},
				'from_device'
			);
			HM485::Util::Log3($hash, 5, 'Device:convertFrameDataToValue: value2 = ' . $frameData->{params}{$valId}{val});
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
	HM485::Util::Log3(undef, 5,  'Device:valueToControl: valName = ' . $valName . ' = ' . $value);
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
			HM485::Util::Log3(undef, 4, 'Device:valueToControl: options = '.Dumper($options));
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
	
	if ( $cmd eq 'on' || $cmd eq 'up') {
		if ( $logicalHash->{'type'} eq 'boolean') {
			$state = $conversionHash->{true};
		} elsif ( $logicalHash->{'type'} eq 'float' || $logicalHash->{'type'} eq 'int') {
			$state = $conversionHash->{'factor'} * $logicalHash->{'max'};
		}
		#$state = 1;
	} elsif ( $cmd eq 'off' || $cmd eq 'down') {
		if ( $logicalHash->{'type'} eq 'boolean') {
			$state = $conversionHash->{false};
		} elsif ( $logicalHash->{'type'} eq 'float' || $logicalHash->{'type'} eq 'int') {
			$state = $conversionHash->{'factor'} * $logicalHash->{'min'};
		}
	}

	return $state;
}

sub valueToState($$) {
	my ($valueHash, $value) = @_;
	# Transformieren des FHEM- Wertebereichs in den Modulwertebereich
	# TODO: Eigentlich ist es nicht so toll, dass es das zweimal gibt: 
	#       einmal fuer EEPROM-Kram und nochmal fuer set-Befehle
	
	return undef unless(defined($value));
	
	if ( exists $valueHash->{logical}{type} && $valueHash->{logical}{type} eq 'boolean') {
	    if( !$value || $value eq '0' || $value eq 'off' || $value eq 'no') {
		    $value = 0;
		}else{
            $value = 1;
        };			
    }
	
	if ( exists $valueHash->{'logical'}{'unit'} && $valueHash->{'logical'}{'unit'} eq '100%') {
		# Da wir in FHEM einen State von 0 - 100 anzeigen lassen,
		# muss der an das Modul gesendete Wert in den Bereich von 0 - 1 
		# transferiert werden
		$value = $value / 100;
	}
	my $factor = $valueHash->{conversion}{factor} ? $valueHash->{conversion}{factor} : 1;

	return int($value * $factor);
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
	return undef unless(ref($frameData) eq 'HASH');
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash        = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
	my $deviceKey      = HM485::Device::getDeviceKeyFromHash($devHash);
	my $frameHash = HM485::Device::getValueFromDefinitions($deviceKey . '/frames/' . $frameType .'/');
	return undef unless(ref($frameHash->{'parameter'}) eq 'HASH');
	if ($peer) {
		#send a keysym (CB)
		$retVal  = sprintf('%02X%02X%02X', '203', $chNr-1 ,substr($peer,9,2) - 1 );
		$retVal .= translateValueToFrameData ($frameHash->{'parameter'},$frameData);
		$retVal .= substr($hmwId,0,8);
	} else {
		$retVal  = sprintf('%02X', $frameHash->{'type'});
		# The channel field is sometimes "later" (only for inhibit?)
		if(defined($frameHash->{channel_field})) {
		    for (my $i = $frameHash->{channel_field}; $i > 10; $i--) {
			    $retVal .= '00';
		    }
		}
		$retVal .= sprintf('%02X', $chNr-1);
		$retVal .= translateValueToFrameData ($frameHash->{'parameter'},$frameData);
	}
	return $retVal;
}


sub translateValueToFrameData ($$) {
	my ($frameParam, $frameData) = @_;
	
	my $retVal;
	my $key     = (keys %{$frameData})[0];
	my $valueId = $frameData->{$key}{'physical'}{'value_id'};
	
	if ($valueId && $key) {
		my $value = undef;
		foreach my $index (sort keys %{$frameParam}) {
			my $paramLen = $frameParam->{$index}{'size'} ? $frameParam->{$index}{'size'} : 1;
			my $singleVal;
			# fixed value?
			if (defined ($frameParam->{$index}{'const_value'})) {
				$singleVal = $frameParam->{$index}{'const_value'};
			} else {
				$singleVal = $frameData->{$key}{'value'};
			}
			if ($paramLen >= 1) {
				$retVal.= sprintf('%0' . $paramLen * 2 . 'X', $singleVal);
			} else {
				# bitschupsen
				# the following needs to be done with split as floating point 
				# calculations are not precise (it was done by multiplying the decimals with 10)
				my (undef, $shift) = split('\.',$index);
				$shift = $shift ? $shift : 0;
				$value += ($singleVal << $shift);
			}
		}
		if (defined $value) {
			$retVal .= sprintf('%02X', $value);
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
	HM485::Util::Log3(undef, 5, 'HM485:Device:dataConversion: retVal = ' . $retVal);
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
		my $valSize = $convertConfig->{'value_size'};
		my @factors = split (',',$convertConfig->{'factors'});
		if ($dir eq 'to_device') {
		    # We need to find the smallest factor, so that value/factor fits in the field
			my $maxDevValue = (1 << ($valSize * 10 - 2)) - 1;  # normally 16383
			my $i = 0;
			for(;$i < @factors; $i++) {
			    $retVal = int($value / $factors[$i]);
				last if($retVal <= $maxDevValue);
			};
			# if this did NOT work, then $i is now too large
			# return largest possible value
			if($i >= @factors) {
			    $i = @factors -1;
				$retVal = $maxDevValue;
			};
			$retVal += $i << ($valSize * 10 - 2);
		} elsif ($dir eq 'from_device') {
		    # i only need the first 2 bits
		    my $factor  = $mask >> ($valSize * 10 - 2);
		    $retVal = ($value - $mask) * $factors[$factor];
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
		foreach my $value (@{$values}) {
			if ($value->{'physical'}{'value_id'} eq $valId) {
				if (!defined($value->{'physical'}{'event'}{'frame'}) ||
					$value->{'physical'}{'event'}{'frame'} eq $frameData->{'id'}) {
						$retVal[scalar @retVal] = $value;
						$retVal[$#retVal]{name} = $value->{id};
				}
			}
		}
	}
	
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
	# HM485::Util::Log3($hash, 5, 'Device:getRawEEpromData hmwId = ' . $hmwId);
	
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

		if ($devHash->{READINGS}{$blockId}{VAL}) {
			$retVal.= $devHash->{READINGS}{$blockId}{VAL};
		} else {
			$retVal = 'FF' x $blockLen;
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

    HM485::Util::Log3($hash, 5, 'setRawEEpromData: Start: '.$start.' Len: '.$len.' Data: '.$data);

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

        main::setReadingsVal($hash, $blockId, $newBlockData, main::TimeNow());

		$len = length($data);
		if ($len == 0) {
			last;
		}
	}
    delete $hash->{cache};
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
		if (ref($configHash->{$param}) ne 'HASH' && ref($configHash->{$param}) ne 'ARRAY') {
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

		if(ref($p) eq "ARRAY" && $param eq "parameter"){
		    foreach my $entry (@{$p}){
			    my $result = getEEpromData($entry, $params);
			    @{$adrHash}{keys %$result} = values %$result;
			};			
		} elsif ((ref ($p->{physical}) eq 'HASH') && $p->{physical} && $p->{physical}{interface} && ($p->{physical}{interface} eq 'eeprom') ) {
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

sub parseModuleType($$) {
	my ($data,$rawFwVersion) = @_;
	
	# Todo sometimes there comes a big number don't now how to parse
	if (length ($data) > 4) {
		my $modelNr = hex(substr($data,4,2));
		print Dumper ("parseModuleType bigstring:$modelNr",$data);
		return undef;
	}	
	my $modelNr = hex(substr($data,0,2));
	if (!defined($modelNr)) { return undef };
	my (undef, $model)  = getDeviceKeyAndModel($modelNr,$rawFwVersion);
	if ( $model) {
		$model =~ s/-/_/g;
	}
	return $model;
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

sub getAllowedSetsUnbuffered($) {
	my ($hash) = @_;
	
	my %cmdOverwrite = (
		'switch.state'	=> "on:noArg off:noArg toggle:noArg"
	);
		
	my %cmdArgs = (
   		'blind.level'	=> "slider,0,1,100 on:noArg off:noArg up:noArg down:noArg",
   		'blind.stop'	=> "noArg",
   		'dimmer.level' 	=> "slider,0,1,100 on:noArg off:noArg",
   		'valve.level' 	=> "slider,0,1,100 on:noArg off:noArg",
   		'button.long'	=> "noArg",
   		'button.short'	=> "noArg",
   		'digital_analog_output.frequency' => "slider,0,1,50000",
	);

    my $commands = getBehaviourCommand($hash);
	if(!$commands){
	    my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
        return '' unless($deviceKey);
	    my $chType    = getChannelType($deviceKey, $hash->{chanNo});
	    return '' unless($chType);		
	    $commands  = getValueFromDefinitions($deviceKey . '/channels/' . $chType .'/paramset/values/parameter');
	};
	
    my @cmdlist;		
	foreach my $command (@{$commands}) {
		next unless($command->{operations});
		my @values = split(',', $command->{'operations'});
		foreach my $val (@values) {
			next unless($val eq 'write' && $command->{'physical'}{'interface'} eq 'command');
			if ($command->{'control'}) {
				my $ctrl = $command->{'control'};
				if ($cmdOverwrite{$ctrl}) {
					push @cmdlist, $cmdOverwrite{$ctrl};
				}elsif($cmdArgs{$ctrl}) {
					push @cmdlist, $command->{id}.":".$cmdArgs{$ctrl};	
				}elsif($ctrl eq "none") {
				    # TODO: as well for other data types, maybe even for other controls
				    if($command->{logical}{type} and $command->{logical}{type} eq "boolean") {
					    push @cmdlist, $command->{id}.":on,off";
					}else{
   					    push @cmdlist, $command->{id}.":noArg";
					};
				}
			} else {
				push @cmdlist, $command->{id};
			}
		}
	}
	return join(" ",@cmdlist);
}


sub getAllowedSets($) {
	my ($hash) = @_;
	# only for channels
	return '' unless(defined($hash->{devHash}));
	# buffer 
	my $result = $hash->{devHash}{cache}{$hash->{chanNo}}{allowedSets};
	if(!defined($result)) {
	    # not in buffer
	    $result = getAllowedSetsUnbuffered($hash);
	    $hash->{devHash}{cache}{$hash->{chanNo}}{allowedSets} = $result;
	};
	return $result;
};

1;
