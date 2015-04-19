package HM485::Devicefile;
# Version 0.5.135

use constant false => 0;
use constant true => 1;

package HM485::Device;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use POSIX qw(ceil);


use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin");
use lib::HM485::Constants;
use lib::HM485::Util;

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

# prototypes
sub parseForEepromData($;$$);

my %deviceDefinitions;
my %models = ();
our %optionRefs;

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

	foreach my $deviceKey (keys %deviceDefinitions) {					# HMW_SEN_SC_12_DR
		if ($deviceDefinitions{$deviceKey}{'supported_types'}) {		# HMW_SEN_SC_12_DR und HMW_SEN_SC_12_FM
			foreach my $modelKey (keys (%{$deviceDefinitions{$deviceKey}{'supported_types'}})) {
				if ($deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'parameter'}{'0'}{'const_value'}) {
					$models{$modelKey}{'model'} = $modelKey;
					$models{$modelKey}{'name'} = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'name'};
					$models{$modelKey}{'type'} = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'parameter'}{'0'}{'const_value'};
					# HM485::Util::HM485_Log( 'Device::initModels modelKey = ' . $modelKey . ' type = ' . $models{$modelKey}{'type'});
					
					my $minFW = $deviceDefinitions{$deviceKey}{'supported_types'}{$modelKey}{'parameter'}{'2'}{'const_value'};
					$minFW = $minFW ? $minFW : 0;
					$models{$modelKey}{'versionDeviceKey'}{$minFW} = $deviceKey;
				}
			}
		}
	}
	my $optionRefFile = $main::attr{global}{modpath} . '/FHEM/lib/HM485/optionref.pm';
	if(-r $optionRefFile) {
		HM485::Util::logger(HM485::LOGTAG_HM485, 3, 'Loading Option-Referenz file: ' .  $optionRefFile);
		my $includeResult = do $optionRefFile;
		if($includeResult) {
			foreach my $dev (keys %HM485::Devicefile::optionRef) {
				$optionRefs{$dev} = $HM485::Devicefile::optionRef{$dev};
			}
		} else {
			HM485::Util::logger(
				HM485::LOGTAG_HM485, 3,
				'HM485: Error in optionRef file: ' . $optionRefFile
			);
		}
		%HM485::Devicefile::optionRef = ();
	} else {
		HM485::Util::logger(
			HM485::LOGTAG_HM485, 1,
			'HM485: Error loading optionRef file: ' .  $optionRefFile
		);
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
	my $retVal = undef;

	foreach my $model (keys (%models)) {
		# HM485::Util::HM485_Log( 'Device:getModelFromType hwType = ' . $hwType . ' model = ' . $model);
		if (exists($models{$model}{'type'}) && $models{$model}{'type'} == $hwType) {
			$retVal = $model;
			last;
		}
	}

	return $retVal;
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

=head2 getChannelBehaviour
	Get the behavior of a chanel from eeprom, if the channel support this

	@param	hash

	@return	array   array of behavior values
=cut
sub getChannelBehaviour($) {
	my ($hash) = @_;
	my $retVal = undef;
	
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	if ( $chNr > 0) {
		my $deviceKey = getDeviceKeyFromHash($hash);
		if ($deviceKey) {
			my $chType         = HM485::Device::getChannelType($deviceKey, $chNr); # digital_analog_input
			my $channelConfig  = getValueFromDefinitions(
				$deviceKey . '/channels/' . $chType
			);
			
			if ( $channelConfig->{'special_parameter'}{'behaviour'}) {
			   
			#if ($channelConfig->{'special_parameter'}{'id'} &&
			#   ($channelConfig->{'special_parameter'}{'id'} eq 'behaviour') &&
			#   $channelConfig->{'special_parameter'}{'physical'}{'address'}{'index'}) {

				my $chConfig = HM485::ConfigurationManager::getConfigFromDevice( $hash, $chNr);										
				
				my @posibleValuesArray = split(',', $chConfig->{behaviour}{posibleValues});
				
				# Trim all items in the array
				@posibleValuesArray = grep(s/^\s*(.*)\s*$/$1/, @posibleValuesArray);

				# den aktuell eingestellten Channeltyp finden
				my $value = $chConfig->{behaviour}{value};
				# HM485::Util::HM485_Log( 'Device:getChannelBehaviour: value = ' . $value);
				$retVal = $posibleValuesArray[$value];
			}
		}
	}
	
	return $retVal;
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

	# if (defined($retVal)) {
	#	HM485::Util::logger( 'Device:getValueFromDefinitions', 3, 'retVal = ' . $retVal);
	# }
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

	my $evTyp		= substr( $data, 0, 2);
	my $event 		= undef;
	if ( $evTyp eq '4B' || $evTyp eq '69') {
		$event = 1;
	}
	my $deviceKey	= HM485::Device::getDeviceKeyFromHash($hash);
	my $chtyp = '';
	my $channelBehaviour = undef;
	if ( uc( $deviceKey) eq 'HMW_IO12_SW14_DR') {
		my $chNr		= sprintf ('%02d' , hex( substr( $data, 2, 2)) + 1);
		$chtyp	 		= getChannelType( $deviceKey, $chNr);
		$event 			= 1;
		my $hmwId 		= $hash->{DEF};
		my $chHash 		= $main::modules{HM485}{defptr}{$hmwId . '_' . $chNr};
		$channelBehaviour = HM485::Device::getChannelBehaviour( $chHash);
		#HM485::Util::HM485_Log( 'Device:parseFrameData channelBehaviour = ' . $channelBehaviour . ' hmwId = ' . $hmwId . ' chtyp = ' . $chtyp);
		if ( defined( $channelBehaviour) && $channelBehaviour && ( $chtyp eq 'digital_analog_output' || $chtyp eq 'digital_analog_input')) {
			$event = 3;
		}
		if ( defined( $channelBehaviour) && $channelBehaviour eq 'digital_input' && $chtyp eq 'digital_input') {
			$event = 3;
		}
		if ( $chtyp eq 'digital_output') {
			$event = 3;
		}
	}
	my $frameData = getFrameInfos($deviceKey, $data, $event, 'from_device');
					
#	print Dumper($frameData);
	my $retVal    = convertFrameDataToValue($hash, $deviceKey, $frameData);
	
	return $retVal;
}

=head2
	Get all infos of current frame data
	
	@param	string	the deviceKey
	@param	string	the frame data to parse
	@param	boolean	optinal value identify the frame as event 
	@param	string	optional frame direction (from or to device)
=cut
sub getFrameInfos($$;$$) {
	my ($deviceKey, $data, $event, $dir) = @_;
	
	my $frameType = hex( substr( $data, 0, 2));	# 69
	my %retVal;
	my $framt = '';
	if ( $event && $event == 3) {
		$framt = 'INFO_frequency';
		$event = 1;
	}
	#HM485::Util::HM485_Log( 'Device:getFrameInfos: event = ' . $event . ' data = ' . $data);
	
	my $frames = getValueFromDefinitions($deviceKey . '/frames/');
	if ($frames) {
		foreach my $frame (keys %{$frames}) {
			if ( $framt ne $frame) {
				my $fType  = $frames->{$frame}{type};
				my $fEvent = $frames->{$frame}{event} ? $frames->{$frame}{event} : 0;
				my $fDir   = $frames->{$frame}{direction} ? $frames->{$frame}{direction} : 0;
			
				#HM485::Util::HM485_Log( 'Device:getFrameInfos: frame = ' . $frame . ' fEvent = ' . $fEvent . ' event = ' . $event);
				if ($frameType == $fType &&
					(!defined($event) || $event == $fEvent) &&
					(!defined($event) || $dir eq $fDir) ) {

					my $chField = ($frames->{$frame}{channel_field} - 9) * 2;
					my $params = translateFrameDataToValue($data, $frame, $frames->{$frame}{parameter});
					# HM485::Util::HM485_Log( 'Device:getFrameInfos: chField = ' . $chField . ' deviceKey = ' . $deviceKey . ' frameType = ' . $frameType . ' frame = ' . $frame);
					if (defined($params)) {
						#foreach my $par (keys %{$params}) {
						#	HM485::Util::HM485_Log( 'Device:getFrameInfos: par = ' . $par);
						#	if ( ref( $params->{$par}) eq 'HASH') {
						#		my $pa   = $params->{$par};
						#		foreach my $p (keys %{$pa}) {
						#			HM485::Util::HM485_Log( 'Device:getFrameInfos: p = ' . $p . ' value = ' . $pa->{val});
						#		}
						#	}
						#}
					
						%retVal = (
							ch     => sprintf ('%02d' , hex(substr($data, $chField, 2)) + 1),
							params => $params, 	# $params->{STATE}{val} = $value
							type   => $fType,	# 69
							event  => $fEvent,
							id     => $frame	# INFO_LEVEL
						);
						last;
					}
				} 
			}
		}
	}
	
	return \%retVal;
}

sub getValueFromEepromData($$$$;$) {
	my ($hash, $configHash, $adressStart, $adressStep, $wholeByte) = @_;

	$wholeByte = $wholeByte ? 1 : 0;

	# my $adressStep = $configHash->{address_step} ? $configHash->{address_step}  : 1;						# = 1
	my ($adrId, $size, $littleEndian) = getPhysicalAdress($hash, $configHash, $adressStart, $adressStep);
	# HM485::Util::HM485_Log( 'Device:getValueFromEepromData adressStep = ' . $adressStep . ' adrId = ' . $adrId . ' size = ' . $size);

	my $retVal = '';
	if (defined($adrId)) {
		my $data = HM485::Device::getRawEEpromData(
			$hash, int($adrId), ceil($size), 0, $littleEndian
		);
		
		my $eepromValue = 0;
		my $default = undef;
		my $adrStart = (($adrId * 10) - (int($adrId) * 10)) / 10;
		$adrStart    = ($adrStart < 1 && !$wholeByte) ? $adrStart: 0;
		$size        = ($size < 1 && $wholeByte) ? 1 : $size;
		
		# HM485::Util::HM485_Log( 'Device:getValueFromEepromData: adrStart = ' . $adrStart . ' size = ' . $size);
		$eepromValue = getValueFromHexData($data, $adrStart, $size);
		# HM485::Util::logger( 'Device:getValueFromEepromData', 3, ' eepromValue = ' . $eepromValue);

		# $retVal = dataConversion($eepromValue, $configHash->{conversion}, 'from_device');
		if ($wholeByte == 0) {
			$retVal = dataConversion($eepromValue, $configHash->{'conversion'}, 'from_device');
			$default = $configHash->{'logical'}{'default'};
		} else { 
			#dataConversion bei mehreren gesetzten bits ist wohl sinnlos kommt null raus
			#auch ein default Value bringt teilweise nur Unsinn in solchen Faellen richtig ???
			$retVal = $eepromValue;
		}
		# HM485::Util::logger( 'Device:getValueFromEepromData', 3,' retVal = ' . $retVal);
		if ( $retVal eq '') {
			my $wert = $configHash->{logical}{'type'};
			if ( defined($wert) && $wert eq 'option') {
				my $wertHash = $configHash->{logical}{'option'};
				foreach my $w (keys %{$wertHash}) {
					my $df = $wertHash->{$w}{'default'};
					if ( defined($df) && ($df eq 'true')) {
						$wert = $w;
						last;
					}
				}
			}
			HM485::Util::logger( 'Device:getValueFromEepromData', 3, 'Option default = ' . $wert);
		}
		# my $default = $configHash->{logical}{'default'};
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

sub getPhysicalAdress($$$$) { 		# 8.0 0.1
	my ($hash, $configHash, $adressStart, $adressStep) = @_;	# configHash = deviceKey/channels/channelType/paramset/master/parameter/LOGGING/
	
	my $adrId = 0;
	my $size  = 0;

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

	# HM485::Util::logger('Device:getPhysicalAdress', 3, 'hmwId = ' . $hmwId . ' chNr = ' . $chNr  . ' adressStart = ' . $adressStart  . ' adressStep = ' . $adressStep);
		
#	if ( $chNr == 0) {
#		return ($adrId, $size, 0);
#	}
	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
	my $chType    = HM485::Device::getChannelType($deviceKey, $chNr);
	# HM485::Util::logger('Device:getPhysicalAdress', 3, 'deviceKey = ' . $deviceKey . ' chType = ' . $chType);
	my $chConfig  = getValueFromDefinitions( $deviceKey . '/channels/' . $chType . '/');
	my $chId = $chNr - $chConfig->{index};
	my $chCount = $chConfig->{count};
	# HM485::Util::logger('Device:getPhysicalAdress', 3, 'chId = ' . $chId);
		
	# we must check if spechial params exists.
	# Then adress_id and step retreve from spechial params 
	my $valId = $configHash->{physical}{value_id} ? $configHash->{physical}{value_id} : undef;	# behaviour	
	
	if ($valId) {
		# HM485::Util::HM485_Log('Device:getPhysicalAdress: valId = ' . $valId);
		my $spConfig = $chConfig->{special_parameter};
		if ( $spConfig->{id} eq $valId) {
			$adressStep  = $spConfig->{physical}{address}{step} ? 	$spConfig->{physical}{address}{step}  : 0;
			$size        = $spConfig->{physical}{size} ? 			$spConfig->{physical}{size} : 1;
			$adrId       = $spConfig->{physical}{address}{index} ? 	$spConfig->{physical}{address}{index} : 0;
			if ( $chCount < 9) {
				$adrId   = $adrId + ($chId * $adressStep * ceil($size));
			} else {
				# HM485::Util::HM485_Log( 'Device:getPhysicalAdress: chId = ' . $chId);
				if ( $chId < 8) {
					$adrId   = $adrId + ($chId * $adressStep * ceil($size));
				} else {
					$adrId   = $adrId + 1;
					$adrId   = $adrId + ( ( $chId - 8) * $adressStep * ceil($size));
				}
			}
		}
		# HM485::Util::HM485_Log( 'Device:getPhysicalAdress: deviceKey = ' . $deviceKey . ' chNr = ' . $chNr . ' adrId = ' . $adrId);
	} else {
		$size       = $configHash->{physical}{size} ? $configHash->{physical}{size} : 1;
		$adrId      = $configHash->{physical}{address}{index} ? $configHash->{physical}{address}{index} : 0;
		# $adrId      = $adrId + $adressStart + ($chId * $adressStep * ceil($size));
		$adrId      = $adrId + $adressStart + ( $chId * $adressStep);
	}
	
	my $littleEndian = ($configHash->{physical}{endian} && $configHash->{physical}{endian} eq 'little') ? 1 : 0;

	# HM485::Util::HM485_Log( 'Device:getPhysicalAdress- return adrId = ' . $adrId . ' size = ' . $size);
	return ($adrId, $size, $littleEndian);
}

sub translateFrameDataToValue($$$) {
	my ($data, $frameName, $params) = @_;		# 690E03FF, INFO_LEVEL, frames/INFO_LEVEL/parameter
	$data = pack('H*', $data);

	my $index = 0;
	my $par	  = undef;
	my $dataValid = 1;
	my %retVal;
	my $size	= 1;
	if ($params) {
		foreach my $param (keys %{$params}) {	# params = INFO_LEVEL/parameter
#			$param = lc($param);
			# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: param = ' . $param);	# 12.0
			if ( ref( $params->{$param}) eq 'HASH') {
				$par   = $params->{$param};	# 12.0
				$index = $param - 9;
				$size  = ($params->{$param}{size});
				# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: index1 = ' . $index . ' size1 = ' . $size);
				
				my $value = getValueFromHexData($data, $index, $size);

				my $constValue = $params->{$param}{const_value};
				
				# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: constValue = ' . $constValue . ' value = ' . $value);
				if ( !defined($constValue) || $constValue eq $value) {
					if ( defined( $par) && $par && defined( $par->{param})) {
						my $p = $par->{param};
						if ( defined( $p) && $p) {
							$retVal{ $p}{val} = $value;
							# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: p = ' . $p . ' value = ' . $value);
						}
					} else {
						$retVal{$param}{val} = $value;
						# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: param = ' . $param . ' value = ' . $value);
					}
				} else {
					$dataValid = 0;
					# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: keine gueltigen Daten');
					last;
				}
			} else {
				# $index 	= ($params->{$param}{index} - 9); ######################
				$index 	= ($params->{index} - 9);		# 11.0-9=2
				$size  	= ($params->{size});			# 3
				# HM485::Util::HM485_Log( 'Device:translateFrameDataToValue: index2 = ' . $index . ' size2 = ' . $size);
				my $value 	= getValueFromHexData($data, $index, $size);	# 690E03FF, 2, 3
				if ( defined( $params->{param})) {
					$retVal{$params->{param}}{val} = $value;	# $retval->{STATE}{val} = $value
				} else {
					$retVal{$frameName}{val} = $value;			# $retval->{INFO_LEVEL}{val} = $value
				}
				last;
			}
			# my $size  	= ($params->{$param}{size});
			
		}
	}
	
	return $dataValid ? \%retVal : undef;
}

sub getValueFromHexData($;$$) {
	my ($data, $start, $size) = @_;		# 690E03FF, 2, 3
#print Dumper(unpack ('H*',$data), $start, $size);

	$start = $start ? $start : 0;	# 0
	$size  = $size ? $size : 1;		# 1

	my $retVal = undef;

	if (isInt($start) && $size >=1) {
		$retVal = hex(unpack ('H*', substr($data, $start, $size)));	# 3, 0, 1
	} else {
		my $bitsId = ($start - int($start)) * 10;		# 0
		my $bitsSize  = ($size - int($size)) * 10;		# 1
		$retVal = ord(substr($data, int($start), 1));
		$retVal = subBit($retVal, $bitsId, $bitsSize);
		# HM485::Util::logger('Device:getValueFromHexData', 3, 'data = ' . $data . ' start = ' . $start . ' size = ' . $size);
		# HM485::Util::logger('Device:getValueFromHexData', 3, 'bitsId = ' . $bitsId . ' bitsSize = ' . $bitsSize . ' retVal = ' . $retVal);
	}

	return $retVal;
}

sub convertFrameDataToValue($$$) {
	my ($hash, $deviceKey, $frameData) = @_;
					
	if ($frameData->{ch}) {
		# HM485::Util::HM485_Log( 'Device:convertFrameDataToValue frameData->{ch} = ' . $frameData->{ch} . ' deviceKey = ' . $deviceKey);
		foreach my $valId (keys %{$frameData->{params}}) {
			# HM485::Util::HM485_Log( 'Device:convertFrameDataToValue valId = ' . $valId);
			my $valueMap = getChannelValueMap($hash, $deviceKey, $frameData, $valId);
			HM485::Util::HM485_Log( 'Device:convertFrameDataToValue deviceKey = ' . $deviceKey . ' valId = ' . $valId . ' value = ' . $frameData->{params}{$valId}{val});
			if ($valueMap) {
				$frameData->{params}{$valId}{val} = dataConversion(
					$frameData->{params}{$valId}{val},					
					$valueMap->{conversion},
					'from_device'
				);
				if ( $valueMap->{cal} && $valueMap->{cal} > -128 && $valueMap->{cal} < 128) {
					$frameData->{params}{$valId}{val} = $frameData->{params}{$valId}{val} + $valueMap->{cal};
					if ( $frameData->{params}{$valId}{val} < 0) {
						$frameData->{params}{$valId}{val} = 0;
					}
				}
				HM485::Util::HM485_Log( 'Device:convertFrameDataToValue End value = ' . $frameData->{params}{$valId}{val});
				# $frameData->{value}{$valueMap->{name}} = valueToControl(	# $frameData->{value}{STATE} = on
				$frameData->{value}{$valueMap->{name}} = valueToControl(
					$valueMap,
					$frameData->{params}{$valId}{val},
				);
			} else {
				# frames zu denen keine valueMap existiert loeschen
				delete $frameData->{params}{$valId};
			}
		}
		#foreach my $par (keys %{$frameData->{params}}) {
		#	HM485::Util::HM485_Log( 'Device:convertFrameDataToValue param = ' . $par);
		#	if ( ref( $frameData->{params}{$par}) eq 'HASH') {
		#		my $pa   = $frameData->{params}{$par};
		#		foreach my $p (keys %{$pa}) {
		#			HM485::Util::HM485_Log( 'Device:convertFrameDataToValue p = ' . $p . ' value = ' . $pa->{val});
		#		}
		#	} else {
		#		HM485::Util::HM485_Log( 'Device:convertFrameDataToValue wert = ' . $frameData->{params}{$par});
		#	}
		#}
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
	my $retVal = $value;

	my $control = undef;
	if ( defined( $paramHash->{control}) && $paramHash->{control}) {
		$control = $paramHash->{control};
	}
	my $valName = $paramHash->{name};
	HM485::Util::HM485_Log( 'Device:valueToControl: valName = ' . $valName . ' = ' . $value);
	if ($control) {
		if ( $control eq 'switch.state') {
			my $threshold = $paramHash->{conversion}{threshold};
			$threshold = $threshold ? int($threshold) : 1;
			$retVal = ($value > $threshold) ? 'on' : 'off';

		} elsif ($control eq 'dimmer.level' || $control eq 'blind.level') {
			if ( exists $paramHash->{'logical'}{'unit'} && $paramHash->{'logical'}{'unit'} eq '100%') {
				$value = $value * 100;
			}
			$retVal = $value;

		} elsif (index($control, 'button.') > -1) {
			$retVal = $valName . ' ' . $value;
			# HM485::Util::HM485_Log( 'Device:valueToControl: retVal = ' . $retVal);

		} elsif ($control eq 'door_sensor.state') {	# hmw_sen_sc_12_dr
			if ( isNumber($value)) {
				if ( $value == 0) {
					$retVal = 'off';
				} else {
					$retVal = 'on';
				}
			}
		} else {
			$retVal = $value;
		}

	} else {
		$retVal = $value;
	}
	
	return $retVal;
}

sub onOffToState($$) {
	my ($stateHash, $cmd) = @_;

	my $state = undef;
	my $conversionHash = $stateHash->{conversion};
	my $logicalHash	   = $stateHash->{logical};
	
	if ( lc( $cmd) eq 'on' && defined($conversionHash->{true})) {
		$state = $conversionHash->{true};
	} elsif ( lc( $cmd) eq 'off' && defined($conversionHash->{false})) {
		$state = $conversionHash->{false};
	}
	if ( !$state) {
		if ( lc( $cmd) eq 'on' && defined($conversionHash->{factor}) && defined($logicalHash->{max})) {
			$state = $conversionHash->{factor} * $logicalHash->{max};
		} elsif ( lc( $cmd) eq 'off' && defined($conversionHash->{factor}) && defined($logicalHash->{min})) {
			$state = $conversionHash->{factor} * $logicalHash->{min};
		}
	}
	return $state;
}

sub valueToState($$$$) {
	my ($chType, $valueHash, $valueKey, $value) = @_;
	# Transformieren des FHEM- Wertebereichs in den Modulwertebereich
	my $state = undef;
	
	if ( defined( $value)) {
	
		if ( exists $valueHash->{'logical'}{'unit'} && $valueHash->{'logical'}{'unit'} eq '100%') {
			# Da wir in FHEM einen State von 0 - 100 anzeigen lassen,
			# muß der an das Modul gesendete Wert in den Bereich von 0 - 1 
			# transferiert werden
			$value = $value / 100;
		}
		my $factor = $valueHash->{conversion}{factor} ? $valueHash->{conversion}{factor} : 1;
	
		$state = int($value * $factor);
	}

	return $state;
}

sub buildFrame($$$$) {
	my ($hash, $frameType, $valueKey, $frameData) = @_;	# hash, level_set, level, HMW_IO12_SW7_DR/channels/SWITCH/paramset/values/parameter/STATE/physical
	my $retVal = '';

	if (ref($frameData) eq 'HASH') {
		my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
		my $devHash        = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
		my $deviceKey      = HM485::Device::getDeviceKeyFromHash($devHash);

		my $frameHash = HM485::Device::getValueFromDefinitions(
			$deviceKey . '/frames/' . $frameType . '/'
		);

		$retVal = sprintf('%02X%02X', $frameHash->{type}, $chNr-1);	# 78cc
		
		foreach my $key (keys %{$frameData}) {
			my $valueId = $frameData->{$key}{physical}{value_id};	# inhibit
			
			if ($valueId && $valueId eq $valueKey && defined( $frameData->{$key}{value})) {
				my $paramLen = $frameHash->{parameter}{size} ? int($frameHash->{parameter}{size}) : 1;
				$retVal.= sprintf('%0' . $paramLen * 2 . 'X', $frameData->{$key}{value});
			} elsif ( $valueId && $valueId eq 'dummy' && $frameHash->{parameter}{const_value}) {
				# stop
				my $paramLen = $frameHash->{parameter}{size} ? int($frameHash->{parameter}{size}) : 1;
				$retVal.= sprintf('%0' . $paramLen * 2 . 'X', $frameHash->{parameter}{const_value});
			} elsif ($valueId && $valueId eq $valueKey && !defined( $frameData->{$key}{value})) {
				# inhibit ( lock), toggle_install_test
				#my $paramLen = $frameHash->{parameter}{size} ? int($frameHash->{parameter}{size}) : 1;
				#$retVal.= sprintf('%0' . $paramLen * 2 . 'X', $frameHash->{parameter}{const_value});
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
				
#	print Dumper($convertConfig);
	my $retVal = $value;
	# HM485::Util::logger('Device:dataConversion', 3, 'retVal = ' . $retVal . ' convertConfig = ' . $convertConfig);
	if (ref($convertConfig) eq 'HASH') {
		$dir = ($dir && $dir eq 'to_device') ? 'to_device' : 'from_device';
		
		my $type = $convertConfig->{type};	# boolean_integer
		
		# ------------
		if ( !defined( $type) && $convertConfig->{1}) {
			# HM485::Util::HM485_Log('Device:dataConversion: conversion/1/ ist definiert');
			$convertConfig = $convertConfig->{1};
			$type = $convertConfig->{type};
		}
		# -----------
		
		# HM485::Util::logger('Device:dataConversion', 3, 'dir = ' . $dir . ' type = ' . $type);
		
		if (ref($convertConfig->{value_map}) eq 'HASH' && $convertConfig->{value_map}{type}) {
			foreach my $key (keys %{$convertConfig->{value_map}}) {
				my $valueMap = $convertConfig->{value_map}{$key};
				if (ref($valueMap) eq 'HASH') {

					if ($convertConfig->{value_map}{type} eq 'integer_integer_map') {
						my $valParam  = $valueMap->{parameter_value} ? $valueMap->{parameter_value} : 0;
						my $valDevice = $valueMap->{device_value} ? $valueMap->{device_value} : 0;
	
						if ($dir eq 'to_device' && $valueMap->{to_device}) {
							$retVal = ($value == $valParam) ? $valDevice : $retVal;
						} elsif ($dir eq 'from_device' && $valueMap->{from_device}) {
							$retVal = ($value == $valDevice) ? $valParam : $retVal;
						}
					}
				}
			}
		}

#		if ( !defined( $type)) {
#			foreach my $key ( keys %{$convertConfig}) {
#				my $valueMap = $convertConfig->{$key};
#				if ( ref($valueMap) eq 'HASH') {
#
#					if ($convertConfig->{$key}{type} eq 'integer_integer_map') {
#						my $valParam  = $valueMap->{value_map}{parameter_value} ? $valueMap->{value_map}{parameter_value} : 0;
#						my $valDevice = $valueMap->{value_map}{device_value} ? $valueMap->{value_map}{device_value} : 0;
#	
#						if ($dir eq 'to_device' && $valueMap->{value_map}{to_device}) {
#							$retVal = ($value == $valParam) ? $valDevice : $retVal;
#						} elsif ($dir eq 'from_device' && $valueMap->{value_map}{from_device}) {
#							$retVal = ($value == $valDevice) ? $valParam : $retVal;
#						}
#						return $retVal;
#					} else {
#						$type = $convertConfig->{type};
#					}
#				}
#			}
#		}


		if ($type eq 'float_integer_scale' || $type eq 'integer_integer_scale') {
			my $factor = $convertConfig->{factor} ? $convertConfig->{factor} : 1;
			my $offset = $convertConfig->{offset} ? $convertConfig->{offset} : 0;
			$factor = ($type eq 'float_integer_scale') ? $factor : 1;
#my $t = $retVal;
			if ($dir eq 'to_device') {
				$retVal = $retVal + $offset;
				$retVal = int($retVal * $factor); 
			} else {
#				$retVal = $retVal / $factor;
				$retVal = sprintf("%.2f", $retVal / $factor);
				$retVal = $retVal - $offset;
			}
#print Dumper($retVal, $factor, $t);

		} elsif ($type eq 'boolean_integer') {
			my $threshold = $convertConfig->{threshold} ? $convertConfig->{threshold} : 1;
			my $invert    = $convertConfig->{invert} ? 1 : 0;
			my $false     = $convertConfig->{false} ? $convertConfig->{false} : 0;
			my $true      = $convertConfig->{true} ? $convertConfig->{true} : 1;

			if ($dir eq 'to_device') {
				$retVal = ($retVal >= $threshold) ? 1 : 0;
				$retVal = (($invert && $retVal) || (!$invert && !$retVal)) ? 0 : 1; 
			} else {
				$retVal = (($invert && $retVal) || (!$invert && !$retVal)) ? 0 : 1; 
				$retVal = ($retVal >= $threshold) ? $true : $false;
			}

		# Todo float_configtime from 
		#} elsif ($config eq 'float_configtime') {
		#	$valueMap = 'IntInt';

		#} elsif ($config eq 'option_integer') {
		#	$valueMap = 'value';

		}
	} else {
		# HM485::Util::HM485_Log('Device:dataConversion: kein conversions- Hash vorhanden');
	}
	
	return $retVal;
}

sub getChannelValueMap($$$$) {
	my ($hash, $deviceKey, $frameData, $valId) = @_;
	
	my $channel = $frameData->{ch};
	my $chType = getChannelType($deviceKey, $channel);

	my $hmwId = $hash->{DEF}; 
	my $chHash = $main::modules{HM485}{defptr}{$hmwId . '_' . $channel};

	my $values;
	my $channelBehaviour = HM485::Device::getChannelBehaviour($chHash);
	
	# HM485::Util::HM485_Log( 'Device:getChannelValueMap: deviceKey = ' . $deviceKey . ' frameData->{id} = ' . $frameData->{id} . ' valId = ' . $valId . ' chType = ' . $chType); 

	my $valuePrafix = '';
	if ( defined( $channelBehaviour) && $channelBehaviour) {
		# HM485::Util::HM485_Log( 'Device:getChannelValueMap: channelBehaviour = ' . $channelBehaviour);
		$valuePrafix = $channelBehaviour;
	}
	
	#################################################
	$values  = getValueFromDefinitions(
		$deviceKey . '/channels/' . $chType . '/paramset/values/parameter/'
	);
	
	my $retVal = undef;
	if ( defined( $values)) {
		#----------------------------------------------
		if ( uc( $deviceKey) eq 'HMW_IO12_SW14_DR') {
			if ( $valuePrafix eq 'analog_input' && $chType eq 'digital_analog_input') {
				# digital_analog_input.analog_input
				$values = $values->{value};
				if ( defined( $values->{physical}{value_id}) && 
					( $values->{physical}{value_id} eq $valId) # || $values->{physical}{value_id} eq "STATE")
					# STATE eq STATE
					) {
					if ( defined($values->{physical}{event}{frame}) && $values->{physical}{event}{frame} eq $frameData->{id}) {
						$retVal = $values;
						# $retVal->{name} = $valId;
						$retVal->{name} = $values->{id};
						HM485::Util::HM485_Log( 'Device:getChannelValueMap1 valueName = ' . $retVal->{name});
						# Calibration beruecksichtigen bei analog_input
						my $calibHash  = HM485::ConfigurationManager::getConfigFromDevice( $chHash, $channel);
						$retVal->{cal} = $calibHash->{calibration}{value};
						$retVal->{min} = $calibHash->{calibration}{min};
						$retVal->{max} = $calibHash->{calibration}{max};
						HM485::Util::HM485_Log( 'Device:getChannelValueMap1 retVal->{cal} = ' . $retVal->{cal});
						
					}
				}	
			}
									
			if ( $valuePrafix eq 'digital_input' && $chType eq 'digital_analog_input') {
				# digital_analog_input.digital_input
				$values  = getValueFromDefinitions( $deviceKey . '/channels/' . $chType . '/subconfig/paramset/');
				if ( defined( $values)) {
					foreach my $value (keys %{$values}) {	# hmw_digital_output_values
						if ( $values->{$value}{type} eq "values"){
							my $p = $values->{$value}{parameter};
							foreach my $k (keys %{$p}) {	# state
								my $Key = $k;
								my $h	=  $p->{$k};
								if ( defined( $h->{physical}{value_id}) && $h->{physical}{value_id} eq $valId) {
									if ( defined( $h->{physical}{event}{frame}) && $h->{physical}{event}{frame} eq $frameData->{id}) {		
										# INFO_LEVEL eq INFO_LEVEL ?
										$retVal = $h;
										$retVal->{name} = $Key;
										HM485::Util::HM485_Log( 'Device:getChannelValueMap2 valueName = ' . $retVal->{name});
									}
								}
							}
							last;
						}
					}
				}
			}
			
			if ( $valuePrafix eq 'frequency' && $chType eq 'digital_analog_output') {
				# digital_analog_output.frequency
				$values = $values->{frequency};
				if ( defined( $values->{physical}{value_id}) && 
					( $values->{physical}{value_id} eq $valId) # || $values->{physical}{value_id} eq "STATE")
					# STATE eq STATE
					) {
					if ( defined($values->{physical}{event}{frame}) && $values->{physical}{event}{frame} eq $frameData->{id}) {
						$retVal = $values;
						# $retVal->{name} = $valId;
						$retVal->{name} = $values->{id};
						HM485::Util::HM485_Log( 'Device:getChannelValueMap3 valueName = ' . $retVal->{name});
						# pulsetime beruecksichtigen bei analog_input
						my $calibHash  = HM485::ConfigurationManager::getConfigFromDevice( $chHash, $channel);
						$retVal->{pul} = $calibHash->{pulsetime}{value};
						$retVal->{min} = $calibHash->{pulsetime}{min};
						$retVal->{max} = $calibHash->{pulsetime}{max};
						HM485::Util::HM485_Log( 'Device:getChannelValueMap3 retVal->{pul} = ' . $retVal->{pul});
						
					}
				}
			}
			
			if ( $valuePrafix eq 'digital_output' && $chType eq 'digital_analog_output') {
				# digital_analog_output.digital_output
				$values  = getValueFromDefinitions( $deviceKey . '/channels/' . $chType . '/subconfig/paramset/');
				if ( defined( $values)) {
					foreach my $value (keys %{$values}) {	# hmw_digital_output_values
						if ( $values->{$value}{type} eq "values"){
							my $p = $values->{$value}{parameter};
							my $Key = $p->{state}{id};		# state
							my $v	= $p->{state};
							if ( defined( $v->{physical}{value_id}) && $v->{physical}{value_id} eq $valId) {
								if ( defined( $v->{physical}{event}{frame}) && $v->{physical}{event}{frame} eq $frameData->{id}) {		
									# INFO_LEVEL eq INFO_LEVEL ?
									$retVal = $v;
									$retVal->{name} = $v->{id};
									HM485::Util::HM485_Log( 'Device:getChannelValueMap4 value = ' . $retVal->{name});
									last;
								}
							} 
						}
					}
				}
			}
			
			if ( $valuePrafix eq 'digital_input' && $chType eq 'digital_input') {
				# digital_input
				$values  = getValueFromDefinitions( $deviceKey . '/channels/' . $chType . '/subconfig/paramset/');
				if ( defined( $values)) {
					foreach my $value (keys %{$values}) {	# hmw_digital_input_values
						if ( $values->{$value}{type} eq "values"){
							my $p = $values->{$value}{parameter};
							my $Key = $p->{state}{id};		# state
							my $v	= $p->{state};
							# if ( defined( $v->{physical}{value_id}) && $v->{physical}{value_id} eq $valId) {
								if ( defined( $v->{physical}{event}{frame}) && $v->{physical}{event}{frame} eq $frameData->{id}) {		
									# INFO_LEVEL eq INFO_LEVEL ?
									$retVal = $v;
									$retVal->{name} = $v->{id};
									HM485::Util::HM485_Log( 'Device:getChannelValueMap5: value = ' . $retVal->{name});
									last;
								}
							# } 
						}
					}
				}
			}
			
			if ( $valuePrafix eq 'frequency_input' && $chType eq 'digital_input') {
				foreach my $value (keys %{$values}) {
					# frequency
					if ( defined( $values->{$value}{physical}{value_id}) && 
					   ( $values->{physical}{value_id} eq $valId || $values->{physical}{value_id} eq "state")) {
						# STATE eq INFO_LEVEL
						if ( defined($values->{$value}{physical}{event}{frame}) && $values->{$value}{physical}{event}{frame} eq $frameData->{id}) {		
							# INFO_frequency eq INFO_frequency ?
							$retVal = $values->{$value};
							$retVal->{name} = $value;
							HM485::Util::HM485_Log( 'Device:getChannelValueMap6 value = ' . $retVal->{name});
							last;
						}
					}
				}
			}
			
			if ( $chType eq 'digital_output'){	
				# digital_output
				my $v	= $values->{state};
				my $Key = $v->{id};
				if ( defined( $v->{physical}{value_id}) && $v->{physical}{value_id} eq $valId) {
					# STATE eq STATE
					if ( defined($v->{physical}{event}{frame}) && $v->{physical}{event}{frame} eq $frameData->{id}) {
						# INFO_LEVEL eq INFO_LEVEL
						$retVal = $v;
						$retVal->{name} = $v->{id};
						HM485::Util::HM485_Log( 'Device:getChannelValueMap7: valueName = ' . $retVal->{name});
					}	
				}
			}
			
		} elsif ( uc( $deviceKey) eq 'HMW_IO_12_FM') {
			# HM485::Util::HM485_Log( 'Device:getChannelValueMap6: valuePrafix = ' . $valuePrafix); # OUTPUT
			if ( $valuePrafix eq 'output'){
				$values  = HM485::Device::getValueFromDefinitions( $deviceKey . '/channels/' . $chType . '/subconfig/paramset/');
				if ( defined( $values)) {
					foreach my $val (keys %{$values}) {	# hmw_switch_ch_values
						if ( $values->{$val}{type} eq "values"){
							my $valueHash = $values->{$val}{parameter}{state};
							# HM485::Util::HM485_Log( 'Device:getChannelValueMap6: frameTyp = ' . $valueHash->{physical}{event}{frame} . ' frameData->{id} = ' . $frameData->{id});
							if ( defined( $valueHash->{physical}{event}{frame}) && $valueHash->{physical}{event}{frame} eq $frameData->{id}) {	
								$retVal = $valueHash;
								$retVal->{name} = $valueHash->{physical}{value_id};
								HM485::Util::HM485_Log( 'Device:getChannelValueMap8: value = ' . $retVal->{name});
								last;
							}
						
						}
					}
				}
			} else {
				if ( defined( $values)) {
					foreach my $val (keys %{$values}) {	# PRESS_SHORT
						my $valueHash = $values->{$val};
						if ( defined( $valueHash->{physical}{value_id}) && $valueHash->{physical}{value_id} eq $valId) {
							if ( defined( $valueHash->{physical}{event}{frame}) && $valueHash->{physical}{event}{frame} eq $frameData->{id}){
								$retVal = $valueHash;
								$retVal->{name} = $val;
								HM485::Util::HM485_Log( 'Device:getChannelValueMap9: value = ' . $retVal->{name});
								last;
							}
						}
					}
				}
			}
		} else {
			#----------------------------------------------
			foreach my $value (keys %{$values}) {
				if ( defined( $values->{$value}{physical}{value_id}) && $values->{$value}{physical}{value_id} eq $valId) {
					if ( defined($values->{$value}{physical}{event}{frame}) && $values->{$value}{physical}{event}{frame} eq $frameData->{id}) {
						$retVal = $values->{$value};
						$retVal->{name} = $value;
						# HM485::Util::HM485_Log( 'Device:getChannelValueMap10: valueName = ' . $value . ' Wert = ' . $values->{$value});
						last;
					}
				} 
			}
		}
	}
	
	return $retVal;
}

sub getEmptyEEpromMap($) {
	my ($hash) = @_;

	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
	my $eepromAddrs = parseForEepromData( getValueFromDefinitions( $deviceKey));  # Device- Informationen einlesen und aus diesen die EEpromadressen extrahieren
	
	# HM485::Util::HM485_Log( 'Device:getEmptyEEpromMap: leere EEpromMap fuer ' . $deviceKey);
	
	my $eepromMap = {};
	my $blockLen = 16;
	my $blockCount = 0;
	my $addrMax = 1024;
	my $adrCount = 0;
	my $hexBlock;
											# 64
	for ($blockCount = 0; $blockCount < ($addrMax / $blockLen); $blockCount++) {
		my $blockStart = $blockCount * $blockLen;  # 16
		foreach my $adrStart (keys %{$eepromAddrs}) {
			# HM485::Util::logger('Device:getEmptyEEpromMap', 3, 'adrStart = ' . $adrStart . '->' . $eepromAddrs->{$adrStart});
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

		#if (length($retVal) / 2 >= $len) {
		#	last;
		#}
		if (length($retVal) / 2 >= $start - $blockStart * $blockLen + $len) {
			last;
		}
	}

	my $start2 = ( ( ($start/$blockLen) - $blockStart ) * $blockLen );	# 8
	
	$retVal = pack('H*', substr( $retVal, ( $start2 * 2), ( $len * 2) ) );
	$retVal = $littleEndian ? reverse($retVal) : $retVal;
	$retVal = $hex ? unpack('H*', $retVal) : $retVal;
	
#print Dumper("+++++++ \n", unpack ('H*',$retVal), $start, $len, "\n -------");		
	
	# HM485::Util::HM485_Log( 'Device:getRawEEpromData retVal = ' . $retVal . ' start = ' . $start . ' len = ' . $len);
	return $retVal;
}

sub setRawEEpromData($$$$) {
	my ($hash, $start, $len, $data) = @_;

	$data = substr($data, 0, ($len*2));
	$len = length($data);
	my $blockLen = 16;
	my $addrMax = 1024;
	my $blockStart = 0;
	my $blockCount = 0;
	
	if (hex($start) > 0) {
		$blockStart = int((hex($start) * 2) / ($blockLen*2));
	}

	for ($blockCount = $blockStart; $blockCount < (ceil($addrMax / $blockLen)); $blockCount++) {

		my $blockId = sprintf ('.eeprom_%04X' , ($blockCount * $blockLen));
		my $blockData = $hash->{READINGS}{$blockId}{VAL};
		if (!$blockData) {
			# no blockdata defined yet
			$blockData = 'FF' x $blockLen;
		}

		my $dataStart = (hex($start) * 2) - ($blockCount * ($blockLen * 2));
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
		
		$hash->{READINGS}{$blockId}{VAL} = $newBlockData;

		$len = length($data);
		if ($len == 0) {
			last;
		}
	}
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

	} else {
		if ( $paramHash->{physical}{address} && $paramHash->{physical}{address}{index}) {
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









sub internalUpdateEEpromData($$) {
	my ($devHash, $requestData) = @_;

	my $start = substr($requestData, 0,4);
	my $len   = substr($requestData, 4,2);
	my $data  = substr($requestData, 6);

	setRawEEpromData($devHash, $start, $len, $data);
}

sub parseModuleType($) {
	my ($data) = @_;
	
	# HM485::Util::HM485_Log( 'Device:parseModuleType data = ' . $data);
	my $modelNr = hex(substr($data,0,2));
	# HM485::Util::HM485_Log( 'Device:parseModuleType modelNr = ' . $modelNr);
	my $retVal  = getModelFromType($modelNr);
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

	my $name   = $hash->{NAME};
	my $model  = $hash->{MODEL};
	my $onOff  = 'on:noArg off:noArg toggle:noArg on-for-timer:textField ';
	my $keys   = 'press_short:noArg press_long:noArg ';

	my $retVal = undef;
	# HM485::Util::HM485_Log( 'Device:getAllowedSets name = ' . $name . ' model = ' . $model);
	if ( defined( $model) && $model) {
		
		my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

		# HM485::Util::HM485_Log( 'Device:getAllowedSets: chNr = ' . $chNr);
		
		if ( $chNr > 0) {
			my $channelBehaviour = getChannelBehaviour($hash);
			if ($channelBehaviour) {
				$hash->{behaviour} = $channelBehaviour;
				# HM485::Util::HM485_Log( 'Device:getAllowedSets channelBehaviour = ' . $channelBehaviour);	# analog_input  ==> Spannung 0..10V
				if ($channelBehaviour eq 'output' || $channelBehaviour eq 'digital_output') {
					$retVal = $onOff;

				} elsif ($channelBehaviour eq 'analog_output') {
					$retVal = 'frequency:textField';

#				} elsif ($channelBehaviour eq 'INPUT' || $channelBehaviour eq 'digital_input') {
#					$retVal = $keys;

				} elsif ($channelBehaviour eq 'frequency_input') {
					$retVal = 'frequency:slider,0,1,100 frequency2:textField';
				}
				# analog_input  ==> Spannung 0..10V
				# kein zusätzliches Set erforderlich --> nur Messeingang
			} else {
				my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
				my $chType    = getChannelType($deviceKey, $chNr);

				# HM485::Util::HM485_Log( 'Device:getAllowedSets: deviceKey = ' . $deviceKey . ' chType = ' . $chType);
				
				if ($chType eq 'key') {
					$retVal = $keys;
		
				} elsif ($chType eq 'switch' || $chType eq 'digital_output') {
					$retVal = $onOff;
	
				} elsif ($chType eq 'dimmer' || $chType eq 'blind') {
					$retVal = $onOff . getDeviceSets( $deviceKey, $chType);
				}
			}
		}
		# HM485::Util::HM485_Log( 'Device:getAllowedSets retVal = ' . $retVal);
	} else {
		# HM485::Util::HM485_Log( 'Device:getAllowedSets kein model definiert');
	}

	return $retVal;
}

sub getDeviceSets($$) {
	my ($deviceKey, $chType ) = @_;

	my $retVal = '';
	my $values  = getValueFromDefinitions( $deviceKey . '/channels/' . $chType . '/paramset/values/parameter/');
	foreach my $val (keys %{$values}) {
		my $valueHash = $values->{$val};
		if ( defined( $valueHash->{operations})) {
			my $op = $valueHash->{operations};
			# HM485::Util::logger( 'Device:getDeviceSets', 3, 'val = ' . $val . ' operations = ' . $op . ' index = ' . index( $op, 'write'));
			if ( index( $op, 'write') > -1) {
				if ( $val eq 'level') {
					$retVal .= $val . ':slider,0,1,100 ';
				} else {
					$retVal .= $val . ':noArg ';
				}
			}
		}
	}
	return $retVal;
}

1;