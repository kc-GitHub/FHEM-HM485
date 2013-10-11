package HM485::Device;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

use constant {
	DEVICE_PATH		=> '/FHEM/lib/HM485/Devices/',
};

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
	my @chArray = ();
	foreach my $subType (keys %{$channels}) {
		push (@chArray, sprintf ('%02d' , $channels->{$subType}{id}) . '_' . $subType);
	}

	foreach my $chSubType (sort @chArray) {
		my ($ch, $subType) = split('_', $chSubType);
		if ($chNo < int($ch)) {
			last;
		} else {
			$retVal = $subType;
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
	my $frameData   = getFrameInfos($modelGroup, $data, 1, '>');
	my $retVal      = translateValue($modelGroup, $frameData);

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
				my $params = convertDataToValue($data, $frames->{$frame}{params});
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

sub convertDataToValue($$) {
	my ($data, $params) = @_;
	$data = pack('H*', $data);

	my $dataValid = 1;
	my %retVal;
	if ($params) {
		foreach my $param (keys %{$params}) {
			$param = lc($param);
			my $index = ($params->{$param}{'index'} - 9);
			my $size = ($params->{$param}{size});
			my $value;

			if (isInt($index) && $size >=1) {
				$value = ord(substr($data, $index, $size));
			} else {
				my $bitsIndex = ($index - int($index)) * 10;
				my $bitsSize  = ($size - int($size)) * 10;
				$value = ord(substr($data, int($index), 1));
				$value = subBit($value, $bitsIndex, $bitsSize);
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

sub translateValue($$) {
	my ($modelGroup, $frameData) = @_;

	if ($frameData->{ch}) {
		foreach my $valId (keys %{$frameData->{params}}) {
			my $valueMap = getChannelValueMap($modelGroup, $frameData, $valId);

			if ($valueMap) {
				if ($valueMap->{conversion}{type} eq 'boolean_integer') {
					if ($valueMap->{conversion}{threshold}) {
						if ($frameData->{params}{$valId}{val} > $valueMap->{conversion}{threshold}) {
							$frameData->{params}{$valId}{val} = 1;
						} else {
							$frameData->{params}{$valId}{val} = 0;
						}
					} else {
						if ($frameData->{params}{$valId}{val}) {
							$frameData->{params}{$valId}{val} = 1
						} else {
							$frameData->{params}{$valId}{val} = 0
						}
					}
				}

				my $valName = $valueMap->{name};
				if (defined($valueMap->{control})) {

					if ($valueMap->{control} eq 'switch.state') {
						if ($frameData->{params}{$valId}{val} == 1) {
							$frameData->{value}{$valName} = 'on';
						} else {
							$frameData->{value}{$valName} = 'off';
						}

					} elsif (index($valueMap->{control}, 'button.') > -1) {
						$frameData->{value}{'state'} = $valName . ' ' . $frameData->{params}{counter}{val};

					} else {
						$frameData->{value}{$valName} = $frameData->{params}{$valId}{val};
					}

				} else {
					$frameData->{value}{$valName} = $frameData->{params}{$valId}{val};
				}
			}
		}
	}

	return $frameData;
}

sub getChannelValueMap($$$) {
	my ($modelGroup, $frameData, $valId) = @_;
	
	my $channel = $frameData->{ch};
	my $subType = getSubtypeFromChannelNo($modelGroup, $channel);
	my $values  = getValueFromDefinitions(
		$modelGroup . '/channels/' . $subType . '/params/values/'
	);

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