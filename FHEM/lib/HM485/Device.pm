package HM485::Device;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

use constant {
	DEVICE_PATH		=> '/FHEM/lib/HM485/devices/',
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
				foreach my $dev (keys %HM485::devices::definition) {
					$deviceDefinitions{$dev} = $HM485::devices::definition{$dev};
				}
			} else {
				main::Log (1, 'HM485: Error in device file: ' . $deviceFile . ' deactivated:' . "\n $@");
			}
		} else {
			main::Log (1, 'HM485: Error loading device file: ' .  $deviceFile);
		}
	}
	%HM485::devices::definition = ();
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

		if ( defined($deviceDefinitions{$modelGroupKey}{'models'}) ) {
			foreach my $modelKey (keys (%{$deviceDefinitions{$modelGroupKey}{'models'}})) {
				if (defined ($deviceDefinitions{$modelGroupKey}{'models'}{$modelKey}{'type'}) ) {
					$models{$modelKey}{MODELKEY} = $modelGroupKey;
					$models{$modelKey}{MODEL} = $modelKey;
					$models{$modelKey}{NAME} = $deviceDefinitions{$modelGroupKey}{'models'}{$modelKey}{'name'};
					$models{$modelKey}{TYPE} = $deviceDefinitions{$modelGroupKey}{'models'}{$modelKey}{'type'};
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
		if (exists($models{$model}{TYPE}) && $models{$model}{TYPE} == $hwType) {
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
	if (defined($models{$hwType}{'NAME'})) {
		$retVal = $models{$hwType}{'NAME'};
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
	if (defined($models{$hwType}{'MODELKEY'})) {
		$retVal = $models{$hwType}{'MODELKEY'};
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
		if ($models{$type}{'MODEL'}) {
			push (@modelList, $models{$type}{'MODEL'});
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
	foreach my $subType (keys $channels) {
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

sub parseFrameData($$;$) {
	my ($model, $data, $onlyEvent) = @_;
	$onlyEvent = (defined($onlyEvent) && $onlyEvent == 1) ? 1 : 0;

	my $frameType = hex(substr($data, 0,2));
	my $modelGroup = getModelGroup($model);
	my $frames = getValueFromDefinitions($modelGroup . '/frames/');

#print Dumper ($frames);

	my %retVal;
	if ($frames) {
		my $params;

		my $fType = getFrameType($modelGroup, $data, 1);

		foreach my $frame (keys $frames) {
			$frame = lc($frame);
			my $fType      = ord($frames->{$frame}{type});
			my $fDirection = $frames->{$frame}{dir};
			my $fEvent = exists($frames->{$frame}{event}) ? $frames->{$frame}{event} : 0;
#main::Log3('', 1, "modelGroup: $modelGroup, frameType: $frameType, $data ------------------------------------------");		

			# returned channel field starts in data part of the frame and based on hex strings (2 digits per byte)
			my $chField = ($frames->{$frame}{ch_field} - 9) * 2;
			$retVal{ch} = sprintf ('%02d' , hex(substr($data, $chField, 2)) + 1);

			if (($frameType == $fType) && ($onlyEvent == $fEvent)) {
				$params  = $frames->{$frame}{params};

				$retVal{id} = $frame;
				last;
			}
#main::Log3('', 1, "fType: $fType, fEvent: $fEvent, frameType: $frameType");
		}

#print Dumper(%retVal);

		if ($params) {
			$retVal{'values'} = convertDataToValue($data, $params);
			my $valueMapings = getValueFromDefinitions($modelGroup . '/channels/Switch/params/Values');
			$retVal{'values'} = mapValues($retVal{'values'}, $valueMapings);
		}
	}

	return \%retVal;
}

sub getFrameType($$;$) {
	my ($modelGroup, $data, $onlyEvent) = @_;
	
	$onlyEvent    = (defined($onlyEvent) && $onlyEvent == 1) ? 1 : 0;
	my $frameType = hex(substr($data, 0,2));
	

	my $frames = getValueFromDefinitions($modelGroup . '/frames/');
	if ($frames) {
		foreach my $frame (keys $frames) {
			my $fType  = ord($frames->{$frame}{type});
			my $fEvent = $frames->{$frame}{event} ? $frames->{$frame}{event} : 0;
			
			if (($frameType == $fType) && ($onlyEvent == $fEvent)) {
				my $params = $frames->{$frame}{params};
				my $t = convertDataToValue($data, $params);
main::Log3('', 1, "frame: $frame,  ------------------------------------------");
print Dumper($t);
			}
		}
	}
	
}

sub mapValues($$) {
	my ($values, $valueMapings) = @_;

	foreach my $valueMap (keys (%{$valueMapings})) {
		my $valueId = $valueMapings->{$valueMap}{physical}{value_id};
		if ($values->{$valueId}) {
			my $val = $values->{$valueId};
			delete ($values->{$valueId});
			$values->{$valueMap} = $val;
			$values->{$valueMap}{id}  = $valueId;
		}
	}
	
	return $values;
}

sub convertDataToValue($$) {
	my ($data, $params) = @_;
	$data = pack('H*', $data);

	my $dataValid = 1;
	my %retVal;
	if ($params) {
		foreach my $param (keys $params) {
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
#			print Dumper("defined($constValue) && $constValue eq $retVal{$param}{val}");
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

sub translsteValue($$$) {
	my ($valueHash, $modelGroup, $subType) = @_;

	if (exists($valueHash->{'values'})) {
		foreach my $valueKey (keys $valueHash->{'values'}) {
			my $valId = $valueHash->{'values'}{$valueKey}{id};
			my $valueMap = getValueFromDefinitions(
				$modelGroup . '/channels/' . $subType . '/params/Values/' . $valueKey . '/'
			);
			
			if ($valueMap) {
				# state conversion ($value -> conversion type)
				if ($valueMap->{conversion}{type} eq 'boolean_integer') {
					if ($valueMap->{conversion}{threshold}) {
						if ($valueHash->{'values'}{$valueKey}{val} > $valueMap->{conversion}{threshold}) {
							$valueHash->{'values'}{$valueKey}{val} = 1;
						} else {
							$valueHash->{'values'}{$valueKey}{val} = 0;
						}
					} else {
						if ($valueHash->{'values'}{$valueKey}{val}) {
							$valueHash->{'values'}{$valueKey}{val} =1
						} else {
							$valueHash->{'values'}{$valueKey}{val} =0
						}
					}
				}

				if (defined($valueMap->{control})) {

					if ($valueMap->{control} eq 'SWITCH.STATE') {
						# state conversion ($value -> ui controll)
						if ($valueHash->{'values'}{$valueKey}{val} == 1) {
							$valueHash->{'values'}{$valueKey}{val} = 'on';
						} else {
							$valueHash->{'values'}{$valueKey}{val} = 'off';
						}
					}
				}

			} else {
				delete ($valueHash->{'values'}{$valueKey}{val});
			}
		}
	}
	
	return $valueHash;
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