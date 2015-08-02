package HM485::ConfigurationManager;

use strict;
use warnings;
use POSIX qw(ceil);

use Data::Dumper;
use lib::HM485::Util;

sub getConfigFromDevice($$) {
	my ($hash, $chNr) = @_;
	
	#Todo Log 5
	#print Dumper("getConfigFromDevice Channel: $chNr");
	
	my $retVal = {};
	my $configHash = getConfigSettings($hash);
	#print Dumper("getConfigFromDevice Channel: $chNr",$configHash);

	if (ref($configHash) eq 'HASH') {
		
		if (ref($configHash->{'parameter'}) eq 'HASH') {
			if ($configHash->{'parameter'}{'id'}) {
				#wenns eine id gibt sollte es keinen extra hash mit dem namen geben
				my $id = $configHash->{'parameter'}{'id'};
				$retVal->{$id} = writeConfigParameter($hash,
					$configHash->{'parameter'},
					$configHash->{'address_start'},
					$configHash->{'address_step'}
				);
			# mehrere Config Parameter
			} else {
				foreach my $config (keys %{$configHash->{'parameter'}}) {
					if (ref($configHash->{'parameter'}{$config}) eq 'HASH') {
						$retVal->{$config} = writeConfigParameter($hash,
							$configHash->{'parameter'}{$config},
							$configHash->{'address_start'},
							$configHash->{'address_step'}
						);
					}
				}	
			}
		}
	}
	
	if (keys %{$retVal}) {
		$hash->{'.configManager'} = 1;
	}
	
	#print Dumper ("getConfigFromDevice", $retVal);
	return $retVal;
}

sub writeConfigParameter($$;$$) {
	
	my ($hash, $parameterHash, $addressStart, $addressStep) = @_ ;
	
	my $retVal = {};
	my $type   = $parameterHash->{'logical'}{'type'} ? $parameterHash->{'logical'}{'type'} : undef;
	my $unit   = $parameterHash->{'logical'}{'unit'} ? $parameterHash->{'logical'}{'unit'} : '';
	my $min    = defined($parameterHash->{'logical'}{'min'})  ? $parameterHash->{'logical'}{'min'}  : undef;
	my $max    = defined($parameterHash->{'logical'}{'max'})  ? $parameterHash->{'logical'}{'max'}  : undef;

	$retVal->{'type'}  = $type;
	$retVal->{'unit'}  = $unit;
	
	if ($type && $type ne 'option') {
		#todo da gibts da noch mehr ?
		if ($type ne 'boolean') {
			$retVal->{'min'} = $min;
			$retVal->{'max'} = $max;
		}
	} else {
		$retVal->{'possibleValues'} = $parameterHash->{'logical'}{'option'};
	}
	
	my $addrStart = $addressStart ? $addressStart : 0;
	#address_steps gibts mehrere Varianten
	my $addrStep = $addressStep ? $addressStep : 0;
	#physical can be a ARRAY
	if (ref $parameterHash->{'physical'} eq 'HASH') {
		if($parameterHash->{'physical'}{'address'}{'step'}) {
			$addrStep = $parameterHash->{'physical'}{'address'}{'step'};
		}

		###debug Dadurch wird allerdings getPhysicalAddress 2 mal hintereinander aufgerufen !
		#my ($addrId, $size, $endian) = HM485::Device::getPhysicalAddress(
		#				$hash, $parameterHash, $addrStart, $addrStep);
		#
		#$retVal->{'address_start'} = $addrStart;
		#$retVal->{'address_step'} = $addrStep;
		#$retVal->{'address_index'} = $addrId;
		#$retVal->{'size'} = $size;
		#$retVal->{'endian'} = $endian;
		####
		$retVal->{'value'} = HM485::Device::getValueFromEepromData (
			$hash, $parameterHash, $addrStart, $addrStep
		);
	} elsif (ref $parameterHash->{'physical'} eq 'ARRAY') {
		my $peerHash;
		
		foreach my $phyHash (@{$parameterHash->{'physical'}}) {
			$peerHash->{'physical'} = $phyHash;
      		
      		if ($phyHash->{'size'} eq '4') {
      			my $address = HM485::Device::getValueFromEepromData (
				$hash, $peerHash, $addressStart, $addressStep
				);
				$retVal->{'value'} = sprintf("%08X",$address);
		
      		}
      	
      		if ($phyHash->{'size'} eq '1') {
      			my $channel = HM485::Device::getValueFromEepromData (
					$hash, $peerHash, $addressStart, $addressStep
				);
				$retVal->{'value'} .= sprintf("_%02i",$channel +1);
				#print Dumper ("writeConfigParameter channel:$channel <> $retVal->{'value'}");
      		}
      	}		
		
	}

	return $retVal;
}


sub optionsToList($) {
	my ($optionList) = @_;
	#Todo schöner programmieren ist a bissl umständlich geschrieben
	#der Name ist eigenlich auch falsch ist kein Array sondern 
	#ein string Komma separiert
	
	if (ref $optionList eq 'ARRAY') {
		
		my @map;
		
		foreach my $key (keys @{$optionList}) {
    		push (@map, $optionList->[$key]{'id'}.':'.$key);
		}

		return join(",",@map);
	} 
	
	elsif (ref $optionList eq 'HASH') {
		print Dumper ("optionsToList HASH !!!!!");
		my @map;
		my $default;
		my $nodefault;

		foreach my $oKey (keys %{$optionList}) {
			#das geht bestimmt schöner! zuerst default suchen und danach nochmal alles wieder durchsuchen?
			if (defined( $optionList->{$oKey}{default})) {
				$default = $optionList->{$oKey}{default};
				if ($default eq '1') {
					$nodefault = 0;
				} else {
					$nodefault = 1;
				}
			}
		}
		foreach my $oKey (keys %{$optionList}) {
			if (defined( $optionList->{$oKey}{default})) {
				push (@map, $oKey.':'.$default);
			} else {
				push (@map, $oKey.':'.$nodefault);
			}
		}
		return join(",",@map);
	} else {
		my $dbg = map {s/ //g; $_; } split(',', $optionList);
		
		return map {s/ //g; $_; } split(',', $optionList);
	}
}


sub convertOptionToValue($$) {
	my ($optionList, $option) = @_;

	my $retVal = 0;
	my $optionValues = optionsToList($optionList);
	
    my @Values = map {s/ //g; $_; } split(',', $optionValues);

	foreach my $val (@Values) {
		my ($item,$num) = split(':',$val);	
		if ($option eq $item) {
			$retVal = $num;
			last;
		}				
	}
	
	return $retVal;
}

sub convertValueToOption($$) {

	my ($optionList, $value) = @_;
	
	my $opt = '';
	my $optionValues = optionsToList($optionList);
    my @Values = map {s/ //g; $_; } split(',', $optionValues);

	foreach my $val (@Values) {
		my ($item,$num) = split(':',$val);	
		if ($value eq $num) {
			$opt = $item;
			last;
		}				
	}
	return $opt;
}


sub getConfigSettings($) {
	my ($hash) = @_;

	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($hash);
	my $devHash = $main::modules{'HM485'}{'defptr'}{substr($hmwId,0,8)};
	my $configSettings = {};

	# Todo: Caching for Config
#	my $configSettings = $devHash->{'cache'}{'configSettings'};

#	if (!$configSettings) {
		my $name   = $devHash->{'NAME'};
		my $deviceKey = HM485::Device::getDeviceKeyFromHash($devHash);

		if ($deviceKey && defined($chNr)) {
		    my $chType  = HM485::Device::getChannelType($deviceKey, $chNr);

			if ($chNr == 0 && $chType eq 'maintenance') {
				#channel 0 has a different path and has no address_start and address_step
				$configSettings = HM485::Device::getValueFromDefinitions(
				 	$deviceKey . '/paramset'
				);
			} else {
				$configSettings = HM485::Device::getValueFromDefinitions(
				 	$deviceKey . '/channels/' . $chType .'/paramset/master'
				);
			}

			# "fold" parameters according to id (?)
			# TODO: funktioniert das? (honk fragen?)
			if (ref($configSettings) eq 'HASH') {
				if (exists $configSettings->{'parameter'}{'id'}) {
					#write id->parameter
					my $id = $configSettings->{'parameter'}{'id'};
					$configSettings->{'parameter'}{$id} = delete $configSettings->{'parameter'};


				}
				# delete hidden configs (Hashes mit dem Attribut hidden werden geloescht )
				# TODO: Warum macht honk das nicht?
				$configSettings = removeHiddenConfig($configSettings);
			}
		}
	return $configSettings;
}

sub removeHiddenConfig($);  # wegen Rekursion

sub removeHiddenConfig($) {
	my ($configHash) = @_;

	if (ref($configHash) eq 'HASH') {
		foreach my $config (keys %{$configHash}) {
			if (ref($configHash->{$config}) eq 'HASH' && $configHash->{$config}{hidden}) {
				delete($configHash->{$config});
			}
		}	
	}
	
	# remove hidden parameters as well from "parameter"
	if(defined($configHash->{'parameter'}) && ref($configHash->{'parameter'}) eq 'HASH') {
	  $configHash->{'parameter'} = removeHiddenConfig($configHash->{'parameter'});
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
	if ($chNr > 0) {
		my $chType = HM485::Device::getChannelType($deviceKey, $chNr);
		$masterConfig = HM485::Device::getValueFromDefinitions(
			$deviceKey . '/channels/' . $chType . '/paramset/master/'
		);
		$adressStart = $masterConfig->{'address_start'} ? $masterConfig->{'address_start'} : 0;
		$adressStep  = $masterConfig->{'address_step'}  ? $masterConfig->{'address_step'}  : 1;
		$adressOffset = $adressStart + ($chNr - 1) * $adressStep;
	} else {
	    # TODO: Warum ist das nicht so bei honk?
		#im channel 0 gibt es nur address index kein address_start oder address_step
		$masterConfig = HM485::Device::getValueFromDefinitions( $deviceKey . '/paramset/');
	}
	
	
	my $addressData = {};
	my $oldValue = 0;
	my $zaehler = 0;
	my $eepromValue = 0;
	my $invert = 0;
	print(Dumper($configData));
	foreach my $config (keys %{$configData}) {
		my $configHash = $configData->{$config}{'config'};	#hash von BEHAVIOUR
		
		my ($adrId, $size, $littleEndian) = HM485::Device::getPhysicalAdress(	
			$hash, $configHash, $adressStart, $adressStep
		);
		my $value = $configData->{$config}{'value'};
		if ($configData->{$config}{'config'}{'logical'}{'type'} && 
		    $configData->{$config}{'config'}{'logical'}{'type'} eq 'option') {
			#$value = convertOptionToValue(
			#	$configData->{$config}{'config'}{'logical'}{'option'}, $value
			#);
		} else {
			$value = HM485::Device::dataConversion(
				$value, $configData->{$config}{'config'}{'conversion'}, 'to_device'
			);
		}

		my $adrKey = int($adrId);
		if ( !defined( $addressData->{$adrKey})) {
			$zaehler = 0;
		}
		if (HM485::Device::isInt($size)) {
			$addressData->{$adrKey}{'value'} = $value;
			$addressData->{$adrKey}{'text'} = $config . '=' . $configData->{$config}{'value'};
			$addressData->{$adrKey}{'size'} = $size;
		} else {
			#if ( !defined( $addressData->{$adrKey})) {
			$eepromValue = HM485::Device::getValueFromEepromData ( $hash, $configHash, $adressStart, $adressStep, 1);
			$oldValue 	= $eepromValue;	# Wert beinhaltes das ganze Byte
			if ( $configHash->{logical}{type} eq 'boolean') {
				$invert = $configHash->{conversion}{invert} ? 1 : 0;
				$oldValue = (($invert && $oldValue) || (!$invert && !$oldValue)) ? 0 : 1; 
				$oldValue = ( $oldValue >= 1) ? 1 : 0;
			} else {
				$invert = 0;
			}

			if (!defined($addressData->{$adrKey}{'value'})) {
				$addressData->{$adrKey}{'value'} 	= $eepromValue; # alter Wert fuer ein Byte
				$addressData->{$adrKey}{'text'} = '';
				$addressData->{$adrKey}{'size'} = ceil($size);  # aufrunden auf naechsthoehere Zahl
				# wenn eepromValue = 0 dann sollte der vorherige Schaltzustand default sein, bei Doppeltbelegung des bytes
			}
			
			my $bit = ($adrId * 10) - ($adrKey * 10);
			$addressData->{$adrKey}{'_adrId'} = $adrId;
			$addressData->{$adrKey}{'_value_old'} = $addressData->{$adrKey}{'value'};
			$addressData->{$adrKey}{'_value'} = $value;
		
	
			if ( defined( $value)) {
				my $bitMask = 1 << $bit;  # 1 um bit nach links schieben
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
			
			$addressData->{$adrKey}{'text'} .= ' ' . $config . '=' . $configData->{$config}{'value'};
			
		}
		
		if ($littleEndian) {
			$value = sprintf ('%0' . ($size*2) . 'X' , $value);
			$value = reverse( pack('H*', $value) );
			$value = hex(unpack('H*', $value));
		}
		
		# HM485::Util::HM485_Log( 'ConfigurationsManager.convertSettingsToEepromData value = ' . $value);
		$zaehler++;
		$addressData->{$adrKey}{'value'} = $value;	# neuen Wert für naechsten Durchlauf der Schleife ( naechstes bit vom gleichen byte) merken
	}
	
	return $addressData;
}

1;