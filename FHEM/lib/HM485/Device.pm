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

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

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
sub initModels () {
	foreach my $modelGroupKey (keys %deviceDefinitions) {

		if ($deviceDefinitions{$modelGroupKey}{models}) {
			foreach my $modelKey (keys (%{$deviceDefinitions{$modelGroupKey}{models}})) {
				if ($deviceDefinitions{$modelGroupKey}{models}{$modelKey}{type}) {
					$models{$modelKey}{modelkey} = $modelGroupKey;
					$models{$modelKey}{model} = $modelKey;
					$models{$modelKey}{name} = $deviceDefinitions{$modelGroupKey}{models}{$modelKey}{name};
					$models{$modelKey}{type} = $deviceDefinitions{$modelGroupKey}{models}{$modelKey}{type};
				}
			}
		}
	}
}




### we should rework below this ###

=head2
	Get the model from numeric hardware type
	
	@param	int      the numeric hardware type
	@return	string   the model
=cut
sub getModelFromType($) {
	my ($hwType) = @_;

	my $retVal = undef;
	foreach my $model (keys (%models)) {
		if (exists($models{$model}{type}) && $models{$model}{type} == $hwType) {
			$retVal = $model;
			last;
		}
	}

	return $retVal;
}

=head2 getModelName
	Title		: getModelName
	Usage		: my $modelName = getModelName();
	Function	: Get the model name from $models hash
	Returns 	: string
	Args 		: nothing
=cut
sub getModelName($) {
	my ($hwType) = @_;
	
	my $retVal = $hwType;
	if (defined($models{$hwType}{'name'})) {
		$retVal = $models{$hwType}{'name'};
	}
	
	return $retVal;
}

=head2 getModelGroup
	Title		: getModelGroup
	Usage		: my $modelGroup = getModelGroup();
	Function	: Get the model group from $models hash
	Returns 	: string
	Args 		: nothing
=cut
sub getModelGroup($) {
	my ($hwType) = @_;

	my $retVal = $hwType;
	if (defined($models{$hwType}{modelkey})) {
		$retVal = $models{$hwType}{modelkey};
	}
	
	return $retVal; 
}

=head2 getModelList
	Title		: getModelList
	Usage		: my $modelList = getModelList();
	Function	: Get a list of models from $models hash
	Returns 	: string
	Args 		: nothing
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

sub getValueFromDefinitions ($) {
	my ($path) = @_;
	my $retVal = undef;
	my @pathParts = split('/', $path);
	
	my %definitionPart = %deviceDefinitions;
	my $found = 1;
	foreach my $part (@pathParts) {
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
	}
	
	if (!defined($retVal) && $found) {
		$retVal = {%definitionPart};
	}

	return $retVal
}

sub getSubtypeFromChannelNo($$) {
	my ($modelGroup, $chNo) = @_;
	$chNo = int($chNo);
	
	my $retVal = undef;

	my $channels = getValueFromDefinitions($modelGroup . '/channels/');
	my @chArray  = getChannelsByModelgroup($modelGroup);
	foreach my $channel (@chArray) {
		my $chStart = int($channels->{$channel}{id});
		my $chCount = int($channels->{$channel}{count});
		if (($chNo == 0 && $chStart == 0) ||
		    ($chNo >= $chStart && $chNo <= ($chStart + $chCount) && $chStart > 0)) {

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
	my ($model, $data, $actionType) = @_;

	my $modelGroup  = getModelGroup($model);
	my $frameData   = getFrameInfos($modelGroup, $data, 1, 'from_device');
	my $retVal      = convertFrameDataToValue($modelGroup, $frameData);

	return $retVal;
}

=head2
	Get all infos of current frame data
	
	@param	string	the $modelGroup
	@param	string	the frame data to parse
	@param	boolean	optinal value identify the frame as event 
	@param	string	optional frame direction (from or to device)
=cut
sub getFrameInfos($$;$$) {
	my ($modelGroup, $data, $event, $dir) = @_;
	
	my $frameType = hex(substr($data, 0,2));
	my %retVal;

	my $frames = getValueFromDefinitions($modelGroup . '/frames/');
	if ($frames) {
		foreach my $frame (keys %{$frames}) {
			my $fType  = $frames->{$frame}{type};
			my $fEvent = $frames->{$frame}{event} ? $frames->{$frame}{event} : 0;
			my $fDir   = $frames->{$frame}{dir} ? $frames->{$frame}{dir} : 0;
			
			if ($frameType == $fType &&
			   (!defined($event) || $event == $fEvent) &&
			   (!defined($event) || $dir eq $fDir) ) {

				my $chField = ($frames->{$frame}{ch_field} - 9) * 2;
				my $params = translateFrameDataToValue($data, $frames->{$frame}{params});
				if (defined($params)) {
					%retVal = (
						ch     => sprintf ('%02d' , hex(substr($data, $chField, 2)) + 1),
						params => $params,
						type   => $fType,
						event  => $frames->{$frame}{event} ? $frames->{$frame}{event} : 0,
						id     => $frame
					);
					last;
				}
			}
		}
	}
	
	return \%retVal;
}

sub getValueFromEepromData($$$) {
	my ($hash, $dataConfig, $adressStart) = @_;
#print Dumper($dataConfig);
#print Dumper($adressStart);
	my $retVal = '';
	if (defined($dataConfig->{physical}{address_id})) {
		my $size       = $dataConfig->{physical}{size} ? $dataConfig->{physical}{size} : 1;
		my $address_id = $dataConfig->{physical}{address_id} + $adressStart;
		my $data = HM485::Device::getRawEEpromData($hash, int($address_id), ceil($size));
		my $eepromValue = 0;

		$address_id = $address_id - int($address_id);
		$eepromValue = getValueFromHexData($data, $address_id, $size);

		$retVal = dataConversion($eepromValue, $dataConfig->{conversion}, 'from_device');
		my $default = $dataConfig->{logical}{'default'};
		if ($default) {
			if ($size == 1) {
				$retVal = ($eepromValue != 0xFF) ? $retVal : $default;

			} elsif ($size == 2) {
				$retVal = ($eepromValue != 0xFFFF) ? $retVal : $default;

			} elsif ($size == 4) {
				$retVal = ($eepromValue != 0xFFFFFFFF) ? $retVal : $default;
			}
		}

	}
#print Dumper($retVal);

	return $retVal;
}

sub translateFrameDataToValue($$) {
	my ($data, $params) = @_;
	$data = pack('H*', $data);

	my $dataValid = 1;
	my %retVal;
	if ($params) {
		foreach my $param (keys %{$params}) {
			$param = lc($param);

			my $id    = ($params->{$param}{id} - 9);
			my $size  = ($params->{$param}{size});
			my $value = getValueFromHexData($data, $id, $size);
#print Dumper(unpack ('H*',$data));
#print Dumper($value);

			my $constValue = $params->{$param}{const_value};
			if (!defined($constValue) || $constValue eq $value) {
				$retVal{$param}{val} = $value;
			} else {
				$dataValid = 0;
				last
			}
		}
	}
	
	return $dataValid ? \%retVal : undef;
}

sub getValueFromHexData($;$$) {
	my ($data, $start, $size) = @_;

	$start = $start ? $start : 0;
	$size  = $size ? $size : 1;

	my $retVal;

	if (isInt($start) && $size >=1) {
		$retVal = hex(unpack ('H*', substr($data, $start, $size)));
	} else {
		my $bitsId = ($start - int($start)) * 10;
		my $bitsSize  = ($size - int($size)) * 10;
		$retVal = ord(substr($data, int($start), 1));
		$retVal = subBit($retVal, $bitsId, $bitsSize);
	}

	return $retVal;
}

sub convertFrameDataToValue($$) {
	my ($modelGroup, $frameData) = @_;

	if ($frameData->{ch}) {
		foreach my $valId (keys %{$frameData->{params}}) {
			my $valueMap = getChannelValueMap($modelGroup, $frameData, $valId);

			if ($valueMap) {
				$frameData->{params}{$valId}{val} = dataConversion(
					$frameData->{params}{$valId}{val},
					$valueMap->{conversion},
					'from_device'
				);

				$frameData->{value}{$valueMap->{name}} = valueToControl(
					$valueMap->{control},
					$frameData->{params}{$valId}{val},
					$valueMap->{name}
				);
			}
		}
	}

	return $frameData;
}

=head2
	Map values to control specific values

	@param	string    control name
	@param	number    the data value
	@param	string    the value name
	
	@return string    converted value
=cut
sub valueToControl($$$) {
	my ($control, $value, $valName) = @_;
	my $retVal = $value;
	
	if ($control) {
		if ($control eq 'switch.state') {
			if ($value == 0xC8) {	# 200 (dez)
				$retVal = 'on';
			} else {
				$retVal = 'off';
			}

		} elsif ($control eq 'dimmer.level') {
			$retVal = $value * 100;

		} elsif (index($control, 'button.') > -1) {
			$retVal = $valName . ' ' . $value;

		} else {
			$retVal = $value;
		}

	} else {
		$retVal = $value;
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
	my ($value, $convertConfig, $dir) = @_;
	
#	print Dumper($convertConfig);
	my $retVal = $value;
	if (ref($convertConfig) eq 'HASH') {
		$dir = ($dir && $dir eq 'to_device') ? 'to_device' : 'from_device';

		my $type = $convertConfig->{type};

		if ($type eq 'float_integer_scale' || $type eq 'integer_integer_scale') {
			my $factor = $convertConfig->{factor} ? $convertConfig->{factor} : 1;
			my $offset = $convertConfig->{offset} ? $convertConfig->{offset} : 0;
			$factor = ($type eq 'float_integer_scale') ? $factor : 1;

			if ($dir eq 'to_device') {
				$retVal = $retVal + $offset;
				$retVal = int($retVal * $factor); 
			} else {
				$retVal = $retVal / $factor;
				$retVal = $retVal - $offset;
			}

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

		if (ref($convertConfig->{value_map}) eq 'HASH' && $convertConfig->{value_map}{type}) {
			$type = $convertConfig->{value_map}{type};

			foreach my $key (keys %{$convertConfig->{value_map}}) {
				my $valueMap = $convertConfig->{value_map}{$key};
				if (ref($valueMap) eq 'HASH') {

					if ($type eq 'integer_integer_map') {
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
	}
	
	return $retVal;
}

sub getChannelValueMap($$$) {
	my ($modelGroup, $frameData, $valId) = @_;
	
	my $channel = $frameData->{ch};
	my $subType = getSubtypeFromChannelNo($modelGroup, $channel);
	my $values  = getValueFromDefinitions(
		$modelGroup . '/channels/' . $subType . '/params/values/'
	);
#print Dumper($values);
	my $retVal;
	if (defined($values)) {
		foreach my $value (keys %{$values}) {
			if ($values->{$value}{physical}{value_id} eq $valId) {
				if (!defined($values->{$value}{physical}{event}{frame}) ||
					$values->{$value}{physical}{event}{frame} eq $frameData->{id}
				) {
					$retVal = $values->{$value};
					$retVal->{name} = $value;
					last;
				}
			}
		}
	}
	
	return $retVal;
}

sub getEmptyEEpromMap ($) {
	my ($model) = @_;

	my $modelGroup  = getModelGroup($model);
	my $eepromAddrs = parseForEepromData(getValueFromDefinitions($modelGroup));

	my $eepromMap = {};
	my $blockLen = 16;
	my $blockCount = 0;
	my $addrMax = 1024;
	my $adrCount = 0;
	my $hexBlock;

	for ($blockCount = 0; $blockCount < ($addrMax / $blockLen); $blockCount++) {
		my $blockStart = $blockCount * $blockLen;
		foreach my $adrStart (sort keys %{$eepromAddrs}) {
			my $len = $adrStart + $eepromAddrs->{$adrStart};
			if (($adrStart >= $blockStart && $adrStart < ($blockStart + $blockLen)) ||
			    ($len >= $blockStart)
			   ) {

				my $blockId = sprintf ('%04X' , $blockStart);
				if (!$eepromMap->{$blockId}) {
					$eepromMap->{$blockId} = 'FF' x $blockLen;
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
sub getRawEEpromData($;$$$) {
	my ($hash, $start, $len, $hex) = @_;

	my $hmwId   = $hash->{DEF};
	my $devHash = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};

	my $blockLen = 16;
	my $addrMax = 1024;
	my $blockStart = 0;
	my $blockCount = 0;
	
	$start = defined($start) ? $start : 0;
	$len   = defined($len) ? $len : $addrMax;
	$hex   = defined($hex) ? $hex : 0;

	if ($start > 0) {
		$blockStart = int($start/$blockLen);
	}
	
	my $retVal = '';
	for ($blockCount = $blockStart; $blockCount < (ceil($addrMax / $blockLen)); $blockCount++) {
		my $blockId = sprintf ('.eeprom_%04X' , ($blockCount * $blockLen));
		if ($devHash->{READINGS}{$blockId}{VAL}) {
			$retVal.= $devHash->{READINGS}{$blockId}{VAL};
		} else {
			$retVal = 'FF' x $blockLen;
		}

		if (length($retVal) / 2 >= $len) {
			last;
		}
	}

	my $start2 = ( ( ($start/$blockLen) - $blockStart ) * $blockLen );
	$retVal = substr($retVal, ($start2 * 2), ($len * 2) );
	
	if (!$hex) {
		$retVal = pack('H*', $retVal);
	}
	
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
	
	if ($start > 0) {
		$blockStart = int(($start*2) / ($blockLen*2));
	}
	
	for ($blockCount = $blockStart; $blockCount < (ceil($addrMax / $blockLen)); $blockCount++) {

		my $blockId = sprintf ('.eeprom_%04X' , ($blockCount * $blockLen));
		my $blockData = $hash->{READINGS}{$blockId}{VAL};
		if (!$blockData) {
			# no blockdata defined yet
			$blockData = 'FF' x $blockLen;
		}

		my $dataStart = ($start*2) - ($blockCount * ($blockLen * 2));
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
	
	@param	hash    the whole config for thie device
	@param	hash    holds the the eeprom adresses with length
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
				$params->{$param} = $configHash->{$param};
			}
		} else {
			push (@hashArray, $param);
		}
	}

	# now we parse the hashes
	foreach my $param (@hashArray) {
		my $p = $configHash->{$param};
		if ($p->{physical} && $p->{physical}{interface} && $p->{physical}{interface} eq 'eeprom') {
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
		if ($paramHash->{physical}{address_id}) {
			my $adrStart =  $paramHash->{physical}{address_id};
			$adrStart = sprintf ('%04d' , $adrStart);

			my $size = $paramHash->{physical}{size};
			$size = $size * $count;
			$size = isInt($paramHash->{physical}{size}) ? $size : ceil(($size / 0.8));

			$retVal->{$adrStart} = $size;
		}
	}

	return $retVal;
}

sub getChannelsByModelgroup ($) {
	my ($modelGroup) = @_;
	my $channels = getValueFromDefinitions($modelGroup . '/channels/');
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

sub getChannelNrFromDevice($) {
	my ($hash) = @_;

 	my $hmwId = $hash->{DEF};
	my $chNr  = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : 0;

	return $chNr;
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
	
	my $modelNr = hex(substr($data,0,2));
	my $retVal   = getModelFromType($modelNr);
	$retVal =~ s/-/_/g;
	
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

	my $name  = $hash->{NAME};
	my $model = $hash->{MODEL};

	my $retVal = undef;
	if (defined($model) && $model) {
		
		my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);

		if (defined($chNr)) {
			my $modelGroup = getModelGroup($model);
			my $subType    = getSubtypeFromChannelNo($modelGroup, $chNr);

			if ($subType eq 'key') {
#				$retVal = 'press_short:press_long';
	
			} elsif ($subType eq 'switch' || $subType eq 'digitaloutput') {
				$retVal = 'on off';

			} elsif ($subType eq 'dimmer') {
				$retVal = 'on off level:slider,0,1,100 ';
			}
		}
	}

	return $retVal;
}


1;