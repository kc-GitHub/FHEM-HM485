package HM485::ConfigurationManager;

# Version 0.5.137 für neues Config

use strict;
use warnings;
use POSIX qw(ceil);

use Data::Dumper;
use lib::HM485::Util;

sub getConfigFromDevice($$) {
	my ($hash, $chNr) = @_;

	my $retVal = {};
	my ($hmwId1, $chNr1) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash        = $main::modules{HM485}{defptr}{substr($hmwId1,0,8)};
	my $deviceKey      = HM485::Device::getDeviceKeyFromHash($devHash);
	
	my $configHash = getConfigSettings($hash);	# Felder von HMW_LC_BL1_DR/paramset/
												# HMW_LC_BL1_DR/channels/KEY/paramset/master/
	
	if (ref($configHash) eq 'HASH') {

		my $adressStart = $configHash->{address_start} ? $configHash->{address_start} : 0;	# = 0
		my $adressStep  = $configHash->{address_step}  ? $configHash->{address_step}  : 1;	# = 1
				
		$configHash = $configHash->{parameter};			# HMW_LC_BL1_DR/channels/KEY/paramset/master/parameter/
		$configHash = getConfigSetting( $configHash);  	# Hash's mit dem Attribut hidden werden geloescht 
					   
		foreach my $config (keys %{$configHash}) {	# 'BEHAVIOUR'		# CALIBRATION
			my $dataConfig = $configHash->{$config};
			# HM485::Util::HM485_Log( 'ConfigurationsManager:getConfigFromDevice config = ' . $config);
			if (ref($dataConfig) eq 'HASH') {
				my $type  = $dataConfig->{logical}{type} ? $dataConfig->{logical}{type} : undef;			# option
				my $unit  = $dataConfig->{logical}{unit} ? $dataConfig->{logical}{unit} : '';				# ''
				my $min   = defined($dataConfig->{logical}{min})  ? $dataConfig->{logical}{min}  : undef;
				my $max   = defined($dataConfig->{logical}{max})  ? $dataConfig->{logical}{max}  : undef;

				$retVal->{$config}{type}  = $type;
				$retVal->{$config}{unit}  = $unit;
	
				if ( $type && $type ne 'option') {
					if ($type ne 'boolean') {
						$retVal->{$config}{min} = $min;
						$retVal->{$config}{max} = $max;
					}
				} else {
					my $oConfig = $dataConfig->{logical}{option};
					my $opt = ''; 
					$opt = join( ",", optionHashToArray($oConfig));
					$retVal->{$config}{posibleValues} = $opt;
					# HM485::Util::logger( 'ConfigurationManager:getConfigFromDevice', 3,' posibleValues = ' . $opt);
				}
				
				my $addrStep = $adressStep;
				if ( $dataConfig->{'physical'}{'address'}{'step'}) {
					$addrStep = $dataConfig->{'physical'}{'address'}{'step'};
				} 
	
				$retVal->{$config}{value} = HM485::Device::getValueFromEepromData(
					$hash, $dataConfig, $adressStart, $addrStep
				);		
			}
		}
	}
	if (keys $retVal) {
		$hash->{'.configManager'} = 1;
	}
	return $retVal;
}

sub optionHashToArray($) {
	my ($optionHash) = @_;

	# my $OptionRef = %HM485::Device::optionRefs->{$deviceKey};
	my $opt = ''; 
	my @retval = ();
	my $count = 0;
	if ( ref( $optionHash) eq 'HASH') {
		foreach my $oC ( keys %{$optionHash}) {
			if ( defined( $optionHash->{$oC}{default})) {
				my $default = $optionHash->{$oC}{default};
				$retval[ $default] = $oC;
				if ( $count == $default) {
					$count++;
				}
			} else {
				$retval[ $count] = $oC;
				$count++;
				if ( defined( $retval[ $count])) {
					$count++;
				}
			}
		}
	}
		
		
#			if ( defined( %{$OptionRef}->{$oC})) {
#				$retval[$OptionRef->{$oC}] = $oC;
#			} else {
#				if ( $opt eq '') {
#					$opt = $oC;
#				} else {
#					$opt .= ',' . $oC;
#				}
#			}
#		}
#	}
#	if ( $opt eq '') {
#		#return map( s/ //g, @retval );
#		return @retval;
#	} else {
#		return map {s/ //g; $_; } split(',', $opt);
#	}
	return @retval;
}

sub convertOptionToValue($$) {
	my ($optionList, $option) = @_;

	my $retVal = 0;
	my @optionValues = split( ',', $optionList);
	my $i = 0;
	foreach my $optionValue (@optionValues) {
		if ($optionValue eq $option) {
			$retVal = $i;
			last;
		}
		$i++;
	}
	
	return $retVal;
}

sub convertValueToOption($$) {
	my ($optionList, $value) = @_;
	
	my $opt = '';
	my @optionValues = split( ',', $optionList);
	my $cc = 0;
	foreach my $oKey (@optionValues) {
		if ( $oKey eq $value || $cc eq $value) {
			$opt = $oKey;
			last;
		}
		$cc++;
	}
	return $opt;
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
			if ($chNr > 0) {	# 13
				my $subtype = HM485::Device::getChannelType($deviceKey, $chNr);
				$configSettings = HM485::Device::getValueFromDefinitions( $deviceKey . '/channels/' . $subtype .'/paramset/master/');

			} else {
				$configSettings = HM485::Device::getValueFromDefinitions( $deviceKey . '/paramset/');
			}

			$configSettings = getConfigSetting($configSettings);  # Hash's mit dem Attribut hidden werden geloescht 
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

	my $adressStart = 0;
	my $adressStep  = 0;
	my $masterConfig = {};

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	
	my $adressOffset = 0;
	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
	# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData deviceKey = ' . $deviceKey . ' chNr = ' . $chNr);
	if ($chNr > 0) {
		my $subType = HM485::Device::getChannelType($deviceKey, $chNr);
		$masterConfig = HM485::Device::getValueFromDefinitions(
			$deviceKey . '/channels/' . $subType . '/paramset/master/'
		);
		$adressStart = $masterConfig->{address_start} ? $masterConfig->{address_start} : 0;
		$adressStep  = $masterConfig->{address_step}  ? $masterConfig->{address_step}  : 1;
		$adressOffset = $adressStart + ($chNr - 1) * $adressStep;
	} else {
		#im channel 0 gibt es nur address index kein address_start oder address_step
		$masterConfig = HM485::Device::getValueFromDefinitions( $deviceKey . '/paramset/');
	}
	
	# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData deviceKey = ' . $deviceKey . ' adressStart = ' . $adressStart . ' adressStep = ' . $adressStep . ' adressOffset = ' . $adressOffset);
	
	
	my $addressData = {};
	my $oldValue = 0;
	my $zaehler = 0;
	my $eepromValue = 0;
	my $invert = 0;
	foreach my $config (keys %{$configData}) {
		my $configHash = $configData->{$config}{config};	#hash von BEHAVIOUR
		
		my ($adrId, $size, $littleEndian) = HM485::Device::getPhysicalAdress(	
			$hash, $configHash, $adressStart, $adressStep
		);
		
		#HM485::Util::logger( 'ConfigurationsManager.convertSettingsToEepromData', 3, ' config = ' . $config . ' adrId = ' . $adrId . ' size = ' . $size . ' littleEndian = ' . $littleEndian);
		
		my $value = $configData->{$config}{value};
		my $BHvalue = $value;
		# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value . ' type = ' . $configData->{$config}{config}{logical}{type});
		if ($configData->{$config}{config}{logical}{type} eq 'option') {
			#$value = HM485::ConfigurationManager::convertOptionToValue(
			$value = convertOptionToValue(
				$configData->{$config}{config}{logical}{option}, $value
			);
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value . ' type = option');
		} else {
			$value = HM485::Device::dataConversion(
				$value, $configData->{$config}{config}{conversion}, 'to_device'
			);
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value . ' type <> option');
		}

		my $adrKey = int($adrId);
		if ( !defined( $addressData->{$adrKey})) {
			$zaehler = 0;
		}
		if (HM485::Device::isInt($size)) {
			$addressData->{$adrKey}{value} = $value;
			$addressData->{$adrKey}{text} = $config . '=' . $configData->{$config}{value};
			$addressData->{$adrKey}{size} = $size;
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value . ' ConfigText = ' . $addressData->{$adrKey}{text});
		} else {
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value . ' kein Integer');
			# -------------------------
			#if ( !defined( $addressData->{$adrKey})) {
			$eepromValue = HM485::Device::getValueFromEepromData ( $hash, $configHash, $adressStart, $adressStep, 1);
			$oldValue 	= $eepromValue;	# Wert beinhaltes das ganze Byte
			#HM485::Util::logger( 'ConfigurationsManager.convertSettingsToEepromData', 3, ' eepromValue = ' . $oldValue);
			if ( $configHash->{logical}{type} eq 'boolean') {
				$invert = $configHash->{conversion}{invert} ? 1 : 0;
				$oldValue = (($invert && $oldValue) || (!$invert && !$oldValue)) ? 0 : 1; 
				$oldValue = ( $oldValue >= 1) ? 1 : 0;
				#HM485::Util::logger( 'ConfigurationsManager.convertSettingsToEepromData', 3, ' oldValue invertiert = ' . $oldValue);
			} else {
				$invert = 0;
			}

			#---------------------
			if (!defined($addressData->{$adrKey}{value})) {
				$addressData->{$adrKey}{value} 	= $eepromValue; # alter Wert fuer ein Byte
				$addressData->{$adrKey}{text} = '';
				$addressData->{$adrKey}{size} = ceil($size);  # aufrunden auf naechsthoehere Zahl
				# wenn eepromValue = 0 dann sollte der vorherige Schaltzustand default sein, bei Doppeltbelegung des bytes
			}
			
			my $bit = ($adrId * 10) - ($adrKey * 10);
			$addressData->{$adrKey}{_adrId} = $adrId;
			$addressData->{$adrKey}{_value_old} = $addressData->{$adrKey}{value};
			$addressData->{$adrKey}{_value} = $value;
		
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData oldValue = ' . $oldValue);
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value . ' bit = ' . $bit);
			
			if ( defined( $value)) {
#				if ( $configData->{$config}{config}{logical}{type} eq 'boolean') {
#					$value = $value ^ $value;  # Bitweises XOR --> Negation
#				}
				my $bitMask = 1 << $bit;  # 1 um bit nach links schieben
				# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData bitMask = ' . $bitMask . ' value = ' . $value);
				# schauen ob sich der Wert gegenüber dem vorhergehenden Durchlauf überhaupt verändert hat
				#if ( $oldValue != $addressData->{$adrKey}{value}) {
				if ( $configData->{$config}{config}{logical}{type} eq 'option') {
					if ( $config eq 'behaviour') {
						if ( $value == 0) {
							# pruefen ob Channelbit gesetzt ist
							$value = $oldValue | $bitMask;  # Bitweises OR
							if ( $value == $oldValue) {  # Channelbit ist gesetzt
								# Channelbit zurücksetzen
								$value = $oldValue ^ $bitMask;  # Bitweises XOR
							} else {
								$value = $oldValue;
							}
						}
						if ( $value == 1) {
							# Channelbit setzen
							$value = $oldValue | $bitMask;  # Bitweises OR
							#if ( $value != $oldValue) {  # Channelbit ist nicht gesetzt
							#	# Channelbit setzen
							#	$value = $oldValue | $bitMask;  # Bitweises OR
							#}
						}
					} else {
						if ( $value == 0) {
							# pruefen ob bit gesetzt ist
							$value = $addressData->{$adrKey}{value} | $bitMask;  # Bitweises OR
							if ( $value == $addressData->{$adrKey}{value}) {  # bit ist gesetzt
								# bit zurücksetzen
								$value = $addressData->{$adrKey}{value} ^ $bitMask;  # Bitweises XOR
							} else {
								$value = $addressData->{$adrKey}{value};
							}
						} elsif ( $value == 1) {
							# bit setzten
							$value = $addressData->{$adrKey}{value} | $bitMask;  # Bitweises OR
						}
					}
				} elsif ( $configData->{$config}{config}{logical}{type} eq 'boolean') {
					if ( $value > 0) {
						if ( $value == $addressData->{$adrKey}{value}) {
							$value = $bitMask;
						} else {
							$value = $addressData->{$adrKey}{value} | $bitMask;  # Bitweises ODER
						}
					}
				} else {
					$value = $value | $bitMask;  # Bitweises ODER
				}
			} else {
				my $bitMask = unpack ('C', pack 'c', ~(1 << $bit));
				$value = $value & $bitMask;
			}
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value);
			
			$addressData->{$adrKey}{text} .= ' ' . $config . '=' . $configData->{$config}{value};
			
			# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData Configtext = ' . $addressData->{$adrKey}{text});
		}
		
		if ($littleEndian) {
			$value = sprintf ('%0' . ($size*2) . 'X' , $value);
			$value = reverse( pack('H*', $value) );
			$value = hex(unpack('H*', $value));
		}
		
		# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value);
		$zaehler++;
		$addressData->{$adrKey}{value} = $value;	# neuen Wert für naechsten Durchlauf der Schleife ( naechstes bit vom gleichen byte) merken
#		$addressData->{$adrKey}{value} = $littleEndian ? reverse($addressData->{$adrKey}{value}) : $addressData->{$adrKey}{value};
	}
	
#	print Dumper($addressData);
	return $addressData;
}

sub configToSateFormat ($) {
	my ($validatedConfig) = @_;
	
	my $retVal = {};
	
	if ($validatedConfig->{'behaviour'}) {
		#Todo nach defaultWert suchen
		if ($validatedConfig->{'behaviour'}{'value'} == 1) {
			$retVal->{'stateFormat'} = "state";
			$retVal->{'webCmd'} = "on:off";
		} else {
			$retVal->{'stateFormat'} = "frequency";
			$retVal->{'webCmd'} = "frequency";
		}
	}
	
	return $retVal;
}

1;