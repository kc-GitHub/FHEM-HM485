#!/usr/bin/perl

use Data::Dumper;

sub dataConversion($$;$);
	
$convertConfig = {
	'float_integer_scale'	=> {
		'factor'	=> 10,
	},
	'integer_integer_map'	=> {
		'01'	=> {
			'device_value'		=> 0xFF,
			'parameter_value'	=> 10,
			'from_device'		=> 1,
			'to_device'			=> 0,
		}
	}
};

my $dir = 'to_device';

my $value = 10;
#$dir = 'from_device';
print dataConversion($value, $convertConfig, $dir) . "\n";

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

#	'integer_integer_map'	=> {
#		'01'	=> {
#			'device_value'		=> 0xFF,
#			'parameter_value'	=> 10,
#			'from_device'		=> 1,
#			'to_device'			=> 0,
#		}
#	}

exit(0);

1;
