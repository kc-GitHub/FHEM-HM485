package HM485::ConfigurationManager;

use strict;
use warnings;
use Data::Dumper;


sub getConfigFromDevice($) {
	my ($hash) = @_;
	my $name   = $hash->{NAME};

	my $retVal = {};
	my $configHash = getConfigSettings($hash);
	if (ref($configHash) eq 'HASH') {
#		print Dumper($configHash);
		foreach my $config (keys %{$configHash}) {

			my $dataConfig = $configHash->{$config};
			if (ref($dataConfig) eq 'HASH') {
				my $type = $dataConfig->{logical}{type} ? $dataConfig->{logical}{type} : undef;
				
				my $unit = $dataConfig->{logical}{unit} ? $dataConfig->{logical}{unit} : '';
				my $min  = $dataConfig->{logical}{min} ? $dataConfig->{logical}{min} : undef;
				my $max  = $dataConfig->{logical}{max} ? $dataConfig->{logical}{max} : undef;
	
				$retVal->{$config}{type}  = $type;
				$retVal->{$config}{unit}  = $unit;
				$retVal->{$config}{value} = getConfigValueFromEeprom($hash, $dataConfig);
			
				if ($type ne 'option') {
					$retVal->{$config}{min} = $min;
					$retVal->{$config}{min} = $max;
				} else {
					$retVal->{$config}{posibleValues} = $dataConfig->{logical}{options}
				}
			}
		}
	}

	return $retVal;
}

sub optionsToArray($) {
	my ($optionList) = @_;

	return map {s/ //g; $_; } split(',', $optionList);
}

sub convertOptionToValue($$) {
	my ($optionList, $option) = @_;

	my $retVal = 0;
	my @optionValues = optionsToArray($optionList);
	my $i = 0;
#	print Dumper(@optionValues);
	foreach my $optionValue (@optionValues) {
		if ($optionValue eq $option) {
			$retVal = $i;
			last;
		}
		$i++;
	}
	
	return $retVal;
}

sub getConfigValueFromEeprom() {
	my ($hash, $dataConfig) = @_;

	my $retVal = '';
	if ($dataConfig->{physical}{address_id}) {
		my $size = $dataConfig->{physical}{size} ? $dataConfig->{physical}{size} : 1;
		my $data = HM485::Device::getRawEEpromData($hash, $dataConfig->{physical}{address_id}, $size);
		
		my $value = hex(unpack ('H*', substr($data, 0, $size)));

		$retVal = HM485::Device::dataConversion($value, $dataConfig->{conversion}, 'from_device');
		my $default = $dataConfig->{logical}{'default'};
		if ($default) {
			if ($size == 1) {
				$retVal = ($value != 0xFF) ? $retVal : $default;

			} elsif ($size == 2) {
				$retVal = ($value != 0xFFFF) ? $retVal : $default;

			} elsif ($size == 4) {
				$retVal = ($value != 0xFFFFFFFF) ? $retVal : $default;
			}
		}

	}
	
	return $retVal;
}

sub getConfigSettings($) {
	my ($hash) = @_;

	my $configSettings = $hash->{cache}{configSettings};
#	print Dumper($configSettings);
#	if (!$configSettings) {
		my $name   = $hash->{NAME};
		my $model  = $hash->{MODEL};
		my $hmwId  = $hash->{DEF};
		my $addr   = substr($hmwId,0,8);
		my $chNr   = (length($hmwId) > 8) ? substr($hmwId, 9, 2) : undef;
		
		if ($model) {
			my $modelGroup  = HM485::Device::getModelGroup($model);
			if (defined($chNr)) {
				my $subtype = HM485::Device::getSubtypeFromChannelNo($modelGroup, $chNr);
				$configSettings = HM485::Device::getValueFromDefinitions(
					$modelGroup . '/channels/' . $subtype .'/params/master/'
				);
			} else {
				$configSettings = HM485::Device::getValueFromDefinitions($modelGroup . '/params/master/');
			}

			$configSettings = getConfigSetting($configSettings);
		}
#		$hash->{cache}{configSettings} = $configSettings;
#	}

	return $configSettings;
}

sub getConfigSetting($) {
	my ($configHash) = @_;

	if (ref($configHash) eq 'HASH') {
		foreach my $config (keys %{$configHash}) {

			if (ref($configHash->{$config}) eq 'HASH' && $configHash->{$config}{hidden}) {
				delete($configHash->{$config});
			}
		}	
	}

	return $configHash;
}

sub convertSettingsToEepromData($$) {
	my ($hash, $configData) = @_;
	print Dumper($configData);
	die;	

	my $chNr = HM485::Device::getChannelNrFromDevice($hash);
	my $adressOffset = 0;
	if ($chNr > 0) {
		my $modelGroup  = HM485::Device::getModelGroup($hash->{MODEL});
		my $subType = HM485::Device::getSubtypeFromChannelNo($modelGroup, $chNr);
		my $masterConfig = HM485::Device::getValueFromDefinitions(
			$modelGroup . '/channels/' . $subType . '/params/master'
		);
		my $adressStart = $masterConfig->{address_start};
		my $adressStep  = $masterConfig->{address_step};
		$adressOffset = $adressStart + ($chNr - 1) * $adressStep;
	}
	
	my $addressData = {};
	foreach my $config (keys %{$configData}) {
#		print Dumper($configData);
		my $addressId = $configData->{$config}{config}{physical}{address_id};
		my $address = $adressOffset + int($addressId);

		my $value = $configData->{$config}{value};
		if ($configData->{$config}{config}{logical}{type} eq 'option') {
			$value = HM485::ConfigurationManager::convertOptionToValue(
				$configData->{$config}{config}{logical}{options}, $value
			);
		} else {
			$value = HM485::Device::dataConversion(
				$value, $configData->{$config}{config}{conversion}, 'to_device'
			);
		}

		my $size = $configData->{$config}{config}{physical}{size};
		if (HM485::Device::isInt($size)) {
			$addressData->{$address}{value} = $value;
			$addressData->{$address}{text} = $config . '=' . $configData->{$config}{value}
		} else {
			if (!defined($addressData->{$address}{value})) {
				$addressData->{$address}{value} = 0;
				$addressData->{$address}{text} = '';
			}
			my $bitVal = $value << ($addressId * 10);
			$addressData->{$address}{value} = $addressData->{$address}{value} | $bitVal;
			$addressData->{$address}{text}.= ' ' . $config . '=' . $configData->{$config}{value}
		}
	}
	
	return $addressData;
}

1;