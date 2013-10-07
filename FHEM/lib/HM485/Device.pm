package HM485::Device;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use POSIX qw(ceil);

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

use constant {
	DEVICE_PATH		=> '/FHEM/lib/HM485/Devices/',
};

# prototypes
sub parseForEepromData($;$$);

my %deviceDefinitions;
my %models = ();

sub init () {
	my $devicesPath = $main::attr{global}{modpath} . DEVICE_PATH;
	opendir(DH, $devicesPath) || return 'HM485: ERROR! Can\'t read devicePath: ' . $devicesPath . $!;

	main::Log (3, 'HM485: Loading available device files');
	main::Log (3, '=====================================');
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.pm$/);
		
		my $deviceFile = $devicesPath . $m;
		if(-r $deviceFile) {
#			main::Log (GetLogLevel($name,5), 'HM485: Loading device file: ' .  $deviceFile);
			main::Log (1, 'HM485: Loading device file: ' .  $deviceFile);

			my $ret=do $deviceFile;

			if($ret) {
				foreach my $dev (keys %HM485::Devices::definition) {
					$deviceDefinitions{$dev} = $HM485::Devices::definition{$dev};
				}
			} else {
				main::Log (1, 'HM485: Error in device file: ' . $deviceFile . ' deactivated:' . "\n $@");
			}

			%HM485::Devices::definition = ();
		} else {
			main::Log (1, 'HM485: Error loading device file: ' .  $deviceFile);
		}
	}
	closedir(DH);

	if (scalar(keys %deviceDefinitions) < 1 ) {
		return 'HM485: Warning, no device definitions loaded!';
	}

	initModels();
	
	return undef;
}

=head2 initModels
	Title		: initModels
	Usage		: initModels();
	Function	: Get modellist.
	              Returns a hash of hardwareType => modelName combination
	Returns 	: nothing
	Args 		: nothing
=cut
sub initModels () {
	foreach my $modelGroupKey (keys %deviceDefinitions) {

		if ( defined($deviceDefinitions{$modelGroupKey}{models}) ) {
			foreach my $modelKey (keys (%{$deviceDefinitions{$modelGroupKey}{models}})) {
				if (defined ($deviceDefinitions{$modelGroupKey}{models}{$modelKey}{type}) ) {
					$models{$modelKey}{modelkey} = $modelGroupKey;
					$models{$modelKey}{model} = $modelKey;
					$models{$modelKey}{name} = $deviceDefinitions{$modelGroupKey}{models}{$modelKey}{name};
					$models{$modelKey}{type} = $deviceDefinitions{$modelGroupKey}{models}{$modelKey}{type};
				}
			}
		}
	}
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
sub parseFrameData($$$$) {
	my ($model, $data, $type, $action) = @_;

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
		foreach my $frame (keys $frames) {
			my $fType  = $frames->{$frame}{type};
			my $fEvent = $frames->{$frame}{event} ? $frames->{$frame}{event} : 0;
			my $fDir   = $frames->{$frame}{dir} ? $frames->{$frame}{dir} : 0;
			
			if ($frameType == $fType &&
			   (!defined($event) || $event == $fEvent) &&
			   (!defined($event) || $dir eq $fDir) ) {

				my $chField = ($frames->{$frame}{ch_field} - 9) * 2;
				my $params = translateDataToValue($data, $frames->{$frame}{params});
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

sub translateDataToValue($$) {
	my ($data, $params) = @_;
	$data = pack('H*', $data);

	my $dataValid = 1;
	my %retVal;
	if ($params) {
		foreach my $param (keys $params) {
			$param = lc($param);
			my $id = ($params->{$param}{id} - 9);
			my $size = ($params->{$param}{size});
			my $value;
			if (isInt($id) && $size >=1) {
				$value = hex(unpack ('H*', substr($data, $id, $size)));
			} else {
				my $bitsId = ($id - int($id)) * 10;
				my $bitsSize  = ($size - int($size)) * 10;
				$value = ord(substr($data, int($id), 1));
				$value = subBit($value, $bitsId, $bitsSize);
			}

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

sub convertFrameDataToValue($$) {
	my ($modelGroup, $frameData) = @_;

	if ($frameData->{ch}) {
		foreach my $valId (keys $frameData->{params}) {
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
	
	my $retVal = $value;

	if (ref($convertConfig) eq 'HASH') {
		# < = data to value, > = value to data
		$dir = ($dir && $dir eq 'to_device') ? 'to_device' : 'from_device';

		my $valueMap = '';
		foreach my $config (keys %{$convertConfig}) {
			
			my $configHash = $convertConfig->{$config};
			if ($config eq 'float_integer_scale' || $config eq 'integer_integer_scale') {

				my $factor = $configHash->{factor} ? $configHash->{factor} : 1;
				my $offset = $configHash->{offset} ? $configHash->{offset} : 0;
				$factor = ($config eq 'float_integer_scale') ? $factor : 1;

				if ($dir eq 'to_device') {
					$retVal = $retVal + $offset;
					$retVal = int($retVal * $factor); 
				} else {
					$retVal = $retVal / $factor;
					$retVal = $retVal - $offset;
				}

			} elsif ($config eq 'boolean_integer') {
				my $threshold = $configHash->{threshold} ? $configHash->{threshold} : 1;
				my $invert    = $configHash->{invert} ? 1 : 0;
				my $false     = $configHash->{false} ? $configHash->{false} : 0;
				my $true      = $configHash->{true} ? $configHash->{true} : 1;

				if ($dir eq 'to_device') {
					$retVal = ($retVal >= $threshold) ? 1 : 0;
					$retVal = (($invert && $retVal) || (!$invert && !$retVal)) ? 0 : 1; 
				} else {
					$retVal = (($invert && $retVal) || (!$invert && !$retVal)) ? 0 : 1; 
					$retVal = ($retVal >= $threshold) ? $true : $false;
				}

			} elsif ($config eq 'integer_integer_map') {
				$valueMap = 'integer_integer_map';

			# Todo float_configtime from 
			#} elsif ($config eq 'float_configtime') {
			#	$valueMap = 'IntInt';

			#} elsif ($config eq 'option_integer') {
			#	$valueMap = 'value';

			}
		}
		
		if ($valueMap) {

			foreach my $key (keys %{$convertConfig->{$valueMap}}) {
				my $mapHash = $convertConfig->{$valueMap}{$key};

				if ($valueMap eq 'integer_integer_map') {
					my $valParam  = $mapHash->{parameter_value} ? $mapHash->{parameter_value} : 0;
					my $valDevice = $mapHash->{device_value} ? $mapHash->{device_value} : 0;


					if ($dir eq 'to_device' && $mapHash->{to_device}) {
						$retVal = ($value == $valParam) ? $valDevice : $retVal;
					} elsif ($dir eq 'from_device' && $mapHash->{from_device}) {
						$retVal = ($value == $valDevice) ? $valParam : $retVal;
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
		foreach my $value (keys $values) {
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
		foreach my $adrStart (sort keys $eepromAddrs) {
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
		if ($hash->{READINGS}{$blockId}{VAL}) {
			$retVal.= $hash->{READINGS}{$blockId}{VAL};
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


sub getConfigSettings($) {
	my ($hash) = @_;

	my $configSettings = $hash->{cache}{configSettings};
	if (!$configSettings) {
		my $name   = $hash->{NAME};
		my $hmwId  = $hash->{DEF};
		my $addr   = substr($hmwId,0,8);
		my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
		
		my $model = main::AttrVal($name, 'model', undef);
		if ($model) {
			my $modelGroup  = getModelGroup($model);
			if (defined($chNr)) {
				my $subtype = getSubtypeFromChannelNo($modelGroup, $chNr);
				$configSettings = getValueFromDefinitions($modelGroup . '/channels/' . $subtype .'/params/master/');
#		print Dumper ("--------------------------------- $hmwId");
#		print Dumper("getValueFromDefinitions($modelGroup . '/channels/' . $subtype .'/params/master/')");
#		print Dumper ($configSettings);
#		print Dumper ("---------------------------------");
			} else {
				$configSettings = getValueFromDefinitions($modelGroup . '/params/master/');
			}

#			print Dumper($configSettings);
			$configSettings = getConfigSetting($configSettings);
		}
		$hash->{cache}{configSettings} = $configSettings;
	}

	return $configSettings;
}

sub getConfigSetting($) {
	my ($configHash) = @_;

	if (ref($configHash) eq 'HASH') {
		foreach my $config (keys $configHash) {

			if (ref($configHash->{$config}) eq 'HASH') {
				if ($configHash->{$config}{hidden}) {
					delete($configHash->{$config});
				}
			}

		}	
	}

	return $configHash;
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
	foreach my $param (keys $configHash) {
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
		if ($paramHash->{physical}{address}{id}) {
			my $adrStart =  $paramHash->{physical}{address}{id};
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
	foreach my $channel (keys $channels) {
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

1;