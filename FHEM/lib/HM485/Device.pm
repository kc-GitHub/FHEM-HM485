package HM485::Device;

use strict;
use warnings;
use Data::Dumper;

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

1;