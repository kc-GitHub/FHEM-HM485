package HM485::ConfigurationManager;

use strict;
use warnings;
use POSIX qw(ceil);

use Data::Dumper;

sub getConfigFromDevice($$) {
	my ($hash, $chNr) = @_;

	my $retVal = {};
	my $configHash = getConfigSettings($hash);

	if (ref($configHash) eq 'HASH') {

		my $adressStart = $configHash->{address_start} ? $configHash->{address_start} : 0;

		foreach my $config (keys %{$configHash}) {
			my $dataConfig = $configHash->{$config};
			if (ref($dataConfig) eq 'HASH') {
				my $type  = $dataConfig->{logical}{type} ? $dataConfig->{logical}{type} : undef;
				my $unit  = $dataConfig->{logical}{unit} ? $dataConfig->{logical}{unit} : '';
				my $min   = defined($dataConfig->{logical}{min})  ? $dataConfig->{logical}{min}  : undef;
				my $max   = defined($dataConfig->{logical}{max})  ? $dataConfig->{logical}{max}  : undef;

				$retVal->{$config}{type}  = $type;
				$retVal->{$config}{unit}  = $unit;

				$retVal->{$config}{value} = HM485::Device::getValueFromEepromData (
					$hash, $dataConfig, $adressStart
				);

				### debug	
				my $adressStep = $configHash->{address_step} ? $configHash->{address_step} : 1;
				my ($adrId, $size) = HM485::Device::getPhysical(
					$hash, $dataConfig, $adressStart, $adressStep
				);

				$retVal->{$config}{physical} = $dataConfig->{physical};
				$retVal->{$config}{physical}{'.adrId'} = $adrId;
				$retVal->{$config}{physical}{'.size'} = $size;
				$retVal->{$config}{physical}{'.address_start'} = $adressStart;
				$retVal->{$config}{physical}{'.address_step'} = $adressStep;
				###
				
				if ($type ne 'option') {
					$retVal->{$config}{min} = $min;
					$retVal->{$config}{max} = $max;
				} else {
					$retVal->{$config}{posibleValues} = $dataConfig->{logical}{options}
				}
			}
		}
	}
#print Dumper($retVal);
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

sub getConfigSettings($) {
	my ($hash) = @_;

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
	my $configSettings = {};

#	my $configSettings = $devHash->{cache}{configSettings};
#	print Dumper($configSettings);
#	if (!$configSettings) {
		my $name   = $devHash->{NAME};
		
		my $deviceKey = HM485::Device::getDeviceKeyFromHash($devHash);
#		print Dumper($deviceKey, $chNr);
		if ($deviceKey) {
			if ($chNr) {
				my $subtype = HM485::Device::getChannelType($deviceKey, $chNr);
				$configSettings = HM485::Device::getValueFromDefinitions(
					$deviceKey . '/channels/' . $subtype .'/params/master/'
				);
#				print Dumper("$deviceKey . '/channels/' . $subtype .'/params/master/'");
			} else {
				$configSettings = HM485::Device::getValueFromDefinitions(
					$deviceKey . '/params/master/'
				);
			}

			$configSettings = getConfigSetting($configSettings);
		}
#		$devHash->{cache}{configSettings} = $configSettings;
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
#	print Dumper($configData);
#	die;	

	my $adressStart = 0;
	my $adressStep  = 0;

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	
	my $adressOffset = 0;
	if ($chNr > 0) {
		my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
		my $subType = HM485::Device::getChannelType($deviceKey, $chNr);
		my $masterConfig = HM485::Device::getValueFromDefinitions(
			$deviceKey . '/channels/' . $subType . '/params/master'
		);

		$adressStart = $masterConfig->{address_start} ? $masterConfig->{address_start} : 0;
		$adressStep  = $masterConfig->{address_step}  ? $masterConfig->{address_step}  : 1;
		
		$adressOffset = $adressStart + ($chNr - 1) * $adressStep;
	}
	
	my $addressData = {};
	foreach my $config (keys %{$configData}) {
		my $configHash     = $configData->{$config}{config};
		my ($adrId, $size) = HM485::Device::getPhysical(
			$hash, $configHash, $adressStart, $adressStep
		);
		
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
		
		my $adrKey = int($adrId);
		if (HM485::Device::isInt($size)) {
			$addressData->{$adrKey}{value} = $value;
			$addressData->{$adrKey}{text} = $config . '=' . $configData->{$config}{value}
		} else {
			if (!defined($addressData->{$adrKey}{value})) {
				my $eepromValue = HM485::Device::getValueFromEepromData (
					$hash, $configData->{$config}{config}, $adrKey, 1
				);
				$addressData->{$adrKey}{value} = $eepromValue;
				$addressData->{$adrKey}{text} = '';
			}

			my $bit = ($adrId * 10) - ($adrKey * 10);
#			print Dumper($bit, $bitVal, $addressData->{$adrKey}{value}, '___');
#			$addressData->{$adrKey}{_bitVal} = $bitVal;
			$addressData->{$adrKey}{_adrId} = $adrId;
			$addressData->{$adrKey}{_value_old} = $addressData->{$adrKey}{value};
			$addressData->{$adrKey}{_value} = $value;

			if ($value) {
				my $bitMask = 1 << $bit;
				$addressData->{$adrKey}{value} = $addressData->{$adrKey}{value} | $bitMask;
			} else {
				my $bitMask = unpack ('C', pack 'c', ~(1 << $bit));
				$addressData->{$adrKey}{value} = $addressData->{$adrKey}{value} & $bitMask;
			}

			$addressData->{$adrKey}{text} .= ' ' . $config . '=' . $configData->{$config}{value}
		}
	}
	
#	print Dumper($addressData);

	return $addressData;
}

1;