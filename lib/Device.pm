package HM485::Device;

use strict;
use warnings;
use Data::Dumper;

use vars qw {%attr %defs %modules}; #supress errors in Eclipse EPIC

use constant {
	DEVICE_PATH		=> '/FHEM/HM485/devices/',
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
	
#	print Dumper(%models);
	
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
					my $type = $deviceDefinitions{$modelGroupKey}{'models'}{$modelKey}{'type'};
					$models{$type}{'MODELKEY'} = $modelGroupKey;
					$models{$type}{'MODEL'} = $modelKey;
					$models{$type}{'NAME'} = $deviceDefinitions{$modelGroupKey}{'models'}{$modelKey}{'name'};
				}
			}
		}
	}
}

=head2 getModel
	Title		: getModel
	Usage		: my $model = getModel();
	Function	: Get the model from $models hash
	Returns 	: string
	Args 		: nothing
=cut
sub getModel($) {
	my ($hwType) = @_;
	
	my $retVal = $hwType;
	if (defined($models{$hwType}{'MODEL'})) {
		$retVal = $models{$hwType}{'MODEL'};
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
	return $models{$hwType}{'NAME'} if defined($models{$hwType}{'NAME'});
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
	return $models{$hwType}{'MODELKEY'} if defined($models{$hwType}{'MODELKEY'});
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
		push (@modelList, $models{$type}{'MODEL'});
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












################################################################################
### We ned this anymore?
################################################################################

# ???
sub parseDefinitions($){
	foreach my $dev (keys %{$modules{HM485}{defptr}}) {
		my $name = $modules{HM485}{defptr}{$dev}{NAME};
		my $adr = $modules{HM485}{defptr}{$dev}{DEF};
		my $model = $attr{$name}{model};
		
		if (defined($model)) {
			my $modelGroup = HM485_getModelFromDefinition($model);

			my %hash = %{$modules{HM485}{defptr}{$dev}};
			$hash{hmwTYPE} = getValueFromDefinitions($modelGroup . '/models/' . $model . '/type');
			$hash{hmwTYPE_NAME} = $model;
			$hash{hmwDESCR} = getValueFromDefinitions($modelGroup . '/models/' . $model . '/name');
			$hash{hmwAddress} = $adr;
			$hash{hmwSerial} = $attr{$name}{serialNr};
			$hash{hmwHardwareVer} = $attr{$name}{hardware};
			$hash{hmwFirmwareVer} = $attr{$name}{firmware};
			%{$modules{HM485}{defptr}{$dev}} = %hash;
		}
	}
}

# ???
sub getValueFromDefinitions ($) {
	my ($path) = @_;
	my $retVal = undef;
	my @pathParts = split('/', $path);
	
	my %definitionPart = %deviceDefinitions;
	foreach my $part (@pathParts) {
		if (ref($definitionPart{$part}) eq 'HASH') {
			%definitionPart = %{$definitionPart{$part}};
		} else {
			$retVal = $definitionPart{$part};
			last;
		}
	}
	
	if (!defined($retVal)) {
		$retVal = {%definitionPart};
	}
	
	return $retVal
}


=head2 HM485_getModelFromDefinition
	Title		: HM485_getModelFromDefinition
	Usage		: my $var = HM485_getModelFromDefinition($model);
	Function	: returns model hash (name, priorty, type) from device definitions with given model group
	Returns 	: string
	Args 		: named arguments:
				: -argument1 => string:	$model
=cut
sub HM485_getModelFromDefinition ($) {
	my ($model) = @_;

	if (defined ($model)) {
		foreach my $modelGroupKey (keys %deviceDefinitions) {
			if ( defined($deviceDefinitions{$modelGroupKey}{'models'}) ) {
				foreach my $modelKey (keys (%{$deviceDefinitions{$modelGroupKey}{'models'}})) {
					if ($modelKey eq $model) {
						return $modelGroupKey;
					}
				}
			}
		}
	}
	
	return '';
}




1;