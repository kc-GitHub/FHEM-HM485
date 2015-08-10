#
#
#
package HM485::PeeringManager;

use strict;
use warnings;
use POSIX qw(ceil floor);
use lib::HM485::Util;
use lib::HM485::Constants;

use Data::Dumper;


#get next free peerID from Device
sub getFreePeerId ($$) {
	my ($devhash,$peerType) = @_;
	
	$peerType = $peerType ? $peerType : 'sensor';
	
	my $linkParams = getLinkParams($devhash);
	my $retVal;
	
	if (ref($linkParams->{$peerType}) eq 'HASH') {
		for (my $peerId = 0 ; $peerId < $linkParams->{$peerType}{count}; $peerId ++) {
			
			my $adrStart = $linkParams->{$peerType}{address_start}
					+ ($peerId * $linkParams->{$peerType}{address_step}
			);
		
			if (ref($linkParams->{$peerType}{parameter}) eq 'HASH') {
				if (ref($linkParams->{$peerType}{parameter}{channel}) eq 'HASH') {
					my $chHash = HM485::ConfigurationManager::writeConfigParameter($devhash,
						$linkParams->{$peerType}{parameter}{channel},
						$adrStart,
						$linkParams->{$peerType}{address_step}
						);
					
					if (($chHash->{value}) >= 255) {
						$retVal = $peerId;
						last;
					}
				} 
			}
		}	
	}
	
	return $retVal;
}

sub getPeerId ($$$$) {
	my ($hash, $hmwid, $channel, $isAct) = @_;
	
	my $retVal;
	my $ch 			= int($channel) -1;
	my $peertype 	= $isAct ? 'actuator' : 'sensor';
	my $linkParams 	= getLinkParams($hash);
		
	if (ref($linkParams->{$peertype}) eq 'HASH') {
		for (my $peerId = 0 ; $peerId < $linkParams->{$peertype}{count}; $peerId ++) {
			
			my $adrStart = $linkParams->{$peertype}{address_start} + 
				($peerId * $linkParams->{$peertype}{address_step}
			);
		
			if (ref($linkParams->{$peertype}{parameter}) eq 'HASH') {
				if (ref($linkParams->{$peertype}{parameter}{channel}) eq 'HASH') {
					my $chHash = HM485::ConfigurationManager::writeConfigParameter($hash,
						$linkParams->{$peertype}{parameter}{channel},
						$adrStart,
						$linkParams->{$peertype}{address_step}
						);
					
					if (($chHash->{value} < 255) && ($chHash->{value} == $ch)) {
						my $peering = $isAct ? 'actuator' : 'sensor';
						my $adrHash = HM485::ConfigurationManager::writeConfigParameter($hash,
							$linkParams->{$peertype}{parameter}{$peering},
							$adrStart,
							$linkParams->{$peertype}{address_step}
							);
							
						if ($adrHash->{value} eq $hmwid) {
							$retVal = $peerId;
						}					
					}
				} 
			}
		}	
	}
	
	return $retVal;
}	


sub getPeerableChannels($) {
	my ($hash) = @_;
		
	my @peered;
	my @peerable;
	my $retVal;
	my $devHash    		= $main::modules{HM485}{defptr}{substr($hash->{DEF},0,8)};
	my $devPeerLinks 	= getLinksFromDevice($devHash);
	
	if ($devPeerLinks->{sensors}{0}{sensor} &&
		$devPeerLinks->{sensors}{0}{sensor} eq 'none') {
		return undef;
	}
	
	foreach my $hmwId (sort keys %{$main::modules{HM485}{defptr}}) {
		
		if (length($hmwId) > 8) { next; } # only channel 0
		
		my $devHash    	= $main::modules{HM485}{defptr}{$hmwId};
		my $peerLinks 	= getLinksFromDevice($devHash);
		
		if ($peerLinks->{sensors}{0}{sensor} && $peerLinks->{sensors}{0}{sensor} eq 'none') {
			next;
		}
		
		if (!$peerLinks) { last; }
		
		my $peerChannels = getLinkParams($devHash);
		
		if (exists($peerChannels->{sensor}{channels})) {
			my @channels = split(' ',$peerChannels->{sensor}{channels});
		
			foreach my $num (@channels) {
				
				my $alreadyPeered = 0;
			
				if ($num eq substr($hash->{DEF}, 9, 2) && substr($hash->{DEF}, 0, 8) eq $hmwId) {
					#actor not sensor
					return undef;
				}
			
				foreach my $actId (keys %{$peerLinks->{sensors}}) {
					
					if (defined ($peerLinks->{sensors}{$actId}{channel}) &&
					    $peerLinks->{sensors}{$actId}{channel} eq $num &&
						$peerLinks->{sensors}{$actId}{sensor} eq $hash->{DEF}) {
						$alreadyPeered = 1;
					}
				}
						
				if ($alreadyPeered) {
					#push @peered, $hmwId.'_'.$num;
					push @peered, getDevNameByHmwId($hmwId.'_'.$num);
					next;
				} else {
					#push @peerable, $hmwId.'_'.$num;
					push @peerable, getDevNameByHmwId($hmwId.'_'.$num);
				}
				
			}
		}					
	}
	
	$retVal->{peerable} = join(",",@peerable);
	$retVal->{peered} = join(",",@peered);
	$hash->{PeerList} = $retVal->{peered};
	
	return $retVal;
}

sub getDevNameByHmwId($) {
	my ($hmwId) = @_;
	
	my $hash = $main::modules{HM485}{defptr}{$hmwId};
	my $retVal = 'unknown';
	
	if (ref($hash) eq 'HASH') {
		$retVal = $hash->{NAME};
	}
	
	return $retVal;
}

sub getHmwIdByDevName ($) {
	my ($name) = @_;
	
	my $retVal = undef;
	
	foreach my $def (keys %{$main::modules{HM485}{defptr}}) {
		
		if ($main::modules{HM485}{defptr}{$def}{NAME} eq $name) {
	
			$retVal = $main::modules{HM485}{defptr}{$def}{DEF};
			last;
		}
	}
	
	return $retVal;
}

sub getLinkParams($) {
	my ($devHash) = @_;
	
	return if (length ($devHash->{DEF}) > 8);
	
	my $linkParams = $devHash->{cache}{linkParams};
	
	if (!$linkParams) {
		my $channels = getChannelsFromDevice($devHash);
		
		if ($channels) {
			foreach my $subType (sort keys %{$channels}) {
				my $chStart   = $channels->{$subType}{chStart};
				my $chCount   = $channels->{$subType}{chCount};
			
				for(my $ch = $chStart; $ch < ($chStart + $chCount); $ch++) {
					
					$ch			 	= sprintf("%02d",$ch);
					my $name   		= $devHash->{NAME};
					my $deviceKey 	= HM485::Device::getDeviceKeyFromHash($devHash);
					my $chHash 		= $main::modules{HM485}{defptr}{$devHash->{DEF}.'_'.$ch};
					my ($behaviour,$bool,$role) = HM485::Device::getChannelBehaviour($chHash);
					
					if ($role && $role eq 'switch') { 
						$behaviour = $role .'_ch';
					}
				
					my $valuePrafix = $bool ? '/subconfig/paramset/hmw_'. $behaviour. 
						'_link/' : '/paramset/link/';
						
					my $params   = HM485::Device::getValueFromDefinitions(
						$deviceKey . '/channels/' . $subType . $valuePrafix
					);
				
					if ($params->{peer_param}) {
						my $peertype = $params->{peer_param};
						if (ref($linkParams->{$peertype}) eq 'HASH') {
							$linkParams->{$peertype}{channels} .= ' '.$ch;
							next;
						} else {
							$linkParams->{$peertype} = $params;
							$linkParams->{$peertype}{channels} = $ch;  
						}
					}
				}		
			}
		}  else {
			$linkParams->{actuator}{channels} = '00';
			$linkParams->{sensor}{channels} = '00';
		}
		
		$devHash->{cache}{linkParams} = $linkParams;
	}
	
	return $linkParams;
}

sub getChannelsFromDevice($) {
	my ($hash) = @_;
	
	my $retVal;
	my $deviceKey = HM485::Device::getDeviceKeyFromHash($hash);
	my $subTypes  = HM485::Device::getValueFromDefinitions($deviceKey . '/channels');
	
	if (ref($subTypes) eq 'HASH') {
		foreach my $subType (sort keys %{$subTypes}) {

			if ($subType ne 'maintenance') {
				if ( defined($subTypes->{$subType}{count}) && $subTypes->{$subType}{count} > 0) {
						
					$retVal->{$subType}{chStart} = $subTypes->{$subType}{'index'};
					$retVal->{$subType}{chCount} = $subTypes->{$subType}{count};
				}
			}
		}
	}
	
	return $retVal;
}

sub getLinksFromDevice($) {
	my ($devHash) = @_;
	
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($devHash);
	
	if ($chNr ne '0') { return; }
		
	my $peers = $devHash->{cache}{peers};
	
	if (!$peers) {
	
		my $linkParams = getLinkParams($devHash);
		#todo split into sub getParamValue
		if (ref($linkParams->{actuator}{parameter}) eq 'HASH' && $linkParams->{actuator}{count}) {
			
			for (my $peerId=0 ; $peerId < $linkParams->{actuator}{count}; $peerId++) {
		
				my $adrStart = $linkParams->{actuator}{address_start} +
					($peerId * $linkParams->{actuator}{address_step});
				
				if (ref($linkParams->{actuator}{parameter}) eq 'HASH' && 
					ref($linkParams->{actuator}{parameter}{channel}) eq 'HASH') {
					
					my $chHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
						$linkParams->{actuator}{parameter}{channel},
						$adrStart,
						$linkParams->{actuator}{address_step}
					);
					if ($chHash->{value} < '255') {
						my $addrHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
							$linkParams->{actuator}{parameter}{actuator},
							$adrStart,
							$linkParams->{actuator}{address_step}
						);
						if ($addrHash->{value}) {
							$peers->{actuators}{$peerId}{actuator} = $addrHash->{value};
							$peers->{actuators}{$peerId}{channel} = sprintf("%02d",$chHash->{value} + 1);
							my $peerHash = $main::modules{HM485}{defptr}{$peers->{actuators}{$peerId}{actuator}};
							if (!$peerHash) { $peerHash->{NAME} = 'unknown'};
							$devHash->{'peer_act_'.$peerId} = 'channel_'.$peers->{actuators}{$peerId}{channel}.
								' → '. $peerHash->{NAME};  #$peers->{'actuators'}{$peerId}{'actuator'};
						}	
					} else {
					    # remove empty peering
					    delete($devHash->{'peer_act_'.$peerId});
					} 
				}
			
			}
		} 
		
		if (ref($linkParams->{sensor}{parameter}) eq 'HASH' && $linkParams->{sensor}{count}) {
			
			for (my $peerId=0 ; $peerId < $linkParams->{sensor}{count}; $peerId++) {
				
				my $adrStart = $linkParams->{sensor}{address_start} + 
					($peerId * $linkParams->{sensor}{address_step});
				
				if (ref($linkParams->{sensor}{parameter}) eq 'HASH' && 
					ref($linkParams->{sensor}{parameter}{sensor}) eq 'HASH') {
					
					my $chHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
						$linkParams->{sensor}{parameter}{channel},
						$adrStart,
						$linkParams->{sensor}{address_step}
					);
					
					if ($chHash->{value} && $chHash->{value} ne '255') {
						my $addrHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
							$linkParams->{sensor}{parameter}{sensor},
							$adrStart,
							$linkParams->{sensor}{address_step}
						);
						if ($addrHash->{value}) {
							$peers->{sensors}{$peerId}{sensor} = $addrHash->{value};
							$peers->{sensors}{$peerId}{channel} = sprintf("%02d",$chHash->{value} + 1);
							
							my $peerHash = $main::modules{HM485}{defptr}{$peers->{sensors}{$peerId}{sensor}};
							if (!$peerHash) { $peerHash->{NAME} = 'unknown'};
							$devHash->{'peer_sen_'.$peerId} = 'channel_'.$peers->{sensors}{$peerId}{channel}.
								' ← '. $peerHash->{NAME}; #$peers->{'sensors'}{$peerId}{'sensor'};
						}	
					} else {
					    # remove empty peering
					    delete($devHash->{'peer_sen_'.$peerId});
					}	
				}
			}
		}
		
		if ($peers) {
			$devHash->{cache}{peers} = $peers;
		} elsif ($linkParams->{sensor}{count} || $linkParams->{actuator}{count}) {
			$devHash->{cache}{peers}{sensors}{0}{sensor}{channel} = 255;
		} else {
			#dummy for caching if device has no peering implemented
			$devHash->{cache}{peers}{sensors}{0}{sensor} = 'none';
		}
	}

	return $peers;
}

sub getPeerSettingsFromDevice($$) {
	my ($arg, $sensor) = @_;
	
	my $hmwid 		= getHmwIdByDevName($arg);
	my $hash		= $main::modules{HM485}{defptr}{substr($hmwid, 0, 8)};
	my $linkParams	= getLinkParams($hash);
	my $peerId		= getPeerId($hash, $sensor, substr($hmwid, 9, 2), 0);
	my $retVal;
	
	if (defined ($peerId) && ref($linkParams->{sensor}) eq 'HASH') {
		
		my $adrStart = $linkParams->{sensor}{address_start} +
		    ($peerId * $linkParams->{sensor}{address_step}
		);

		foreach my $setting (keys %{$linkParams->{sensor}{parameter}}) {
						
			if ($setting eq 'channel' || $setting eq 'sensor') {
				next;
			}
						
			my $settingHash = HM485::ConfigurationManager::writeConfigParameter($hash,
				$linkParams->{sensor}{parameter}{$setting},
				$adrStart,
				$linkParams->{sensor}{address_step}
			);

			$retVal->{$setting} = $settingHash;
		}
		
		#insert the actuator address into the peering hash hmmmm!
		#todo better way ?
		$retVal->{actuator}{value}	= $hash->{DEF};
		$retVal->{actuator}{type}	= 'address';
		$retVal->{actuator}{unit}	= '';
		$retVal->{peerId}{value}	= $peerId;
		$retVal->{peerId}{type}		= 'address';
		$retVal->{peerId}{unit}		= '';
	}
	
	return $retVal;
}

#convert a confighash to a addresshash
sub configDataToAddressData($$$$) {
	my ($devHash, $configData, $adressStart, $adressStep) = @_;
	#create a new hash with address keys, so i can sort it by address.
	
	my $adrConfig;
	
	foreach my $sort (keys %{$configData}) {
		my ($adrId, $size, $littleEndian, $readSize) = HM485::Device::getPhysicalAddress(
			$devHash, $configData->{$sort}{config}, $adressStart, $adressStep
		);
		
		$adrConfig->{$adrId}{value}  	= $configData->{$sort}{value};
		$adrConfig->{$adrId}{config} 	= $configData->{$sort}{config};
		$adrConfig->{$adrId}{size}   	= $size;
		$adrConfig->{$adrId}{readSize}	= $readSize;
		$adrConfig->{$adrId}{'le'}     	= $littleEndian;
		$adrConfig->{$adrId}{id}     	= $sort;
		
		if (defined $configData->{$sort}{chan}) {
			$adrConfig->{$adrId}{chan} = $configData->{$sort}{chan};
		}
		
		if (ref($configData->{$sort}{config}{logical}) eq 'HASH' &&
				$configData->{$sort}{config}{logical}{type} eq 'option')
		{
			$adrConfig->{$adrId}{text} = HM485::ConfigurationManager::convertOptionToValue(
				$configData->{$sort}{config}{logical}{option},
				$configData->{$sort}{value}
			);
		}
		
		if (ref($configData->{$sort}{config}{conversion}) eq 'HASH') {
			$adrConfig->{$adrId}{value} = HM485::Device::dataConversion(
				$configData->{$sort}{value}, 
				$configData->{$sort}{config}{conversion},
				'to_device'
			);
		}	
	}
	
	return $adrConfig;
}

sub convertPeeringsToEepromData($$) {
	my ($devHash, $configData) = @_;

	my $adressStart = 0;
	my $adressStep  = 0;
	my $adressOffset = 0;
	
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($devHash);
	
	if ($chNr != 0) {
		$devHash = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
	}
	
	my $devLinkParams = getLinkParams($devHash);
	my $linkParams;
		
	if (ref ($configData->{sensor}) eq 'HASH') {
	    $linkParams =  $devLinkParams->{sensor};
	} elsif (ref ($configData->{actuator}) eq 'HASH') { 
	    $linkParams =  $devLinkParams->{actuator};
	} else {
		print Dumper ("OJE");
	}
		
	$adressStart = $linkParams->{address_start} ? $linkParams->{address_start} : 0;
	$adressStep  = $linkParams->{address_step}  ? $linkParams->{address_step} : 1;
	$adressOffset = $adressStart + ($configData->{channel}{peerId} + 1) * $adressStep;
	
	my $adrStart = $linkParams->{address_start} +
		 ($configData->{channel}{peerId} * $linkParams->{address_step}
	);
		
	my $log = sprintf("0x%X",$adrStart);
	
	HM485::Util::logger ( HM485::LOGTAG_HM485, 5,
		'convertPeeringsToEepromData peerId: ' .$configData->{'channel'}{'peerId'}.
		' start: ' . $log . ' step: ' .$adressStep . ' offset: ' .$adressOffset
	);
	
	my $addressData = {};
	my $sortedConfig = configDataToAddressData($devHash, $configData, $adrStart, $adressStep);
	
	if (ref ($sortedConfig) eq 'HASH') {
	
		foreach my $config (sort keys %{$sortedConfig}) {
				
			my $adrKey   = int($config);
			my $value    = $sortedConfig->{$config}{'value'};
			my $size     = $sortedConfig->{$config}{'size'};
			my $readSize = $sortedConfig->{$config}{'readSize'};
			
			if (HM485::Device::isInt($sortedConfig->{$config}{'size'})) {
				$addressData->{$adrKey}{'value'} = $value;
				$addressData->{$adrKey}{'text'} = $sortedConfig->{$config}{'id'} . '=' . $sortedConfig->{$config}{'value'};
				$addressData->{$adrKey}{'size'} = $size;
				$addressData->{$adrKey}{'le'} = $sortedConfig->{$config}{'le'};
			
			} else {
				my $bit = ($config * 10) - ($adrKey * 10);
				#print Dumper ("bit: $bit size:$size readsize: $readSize $sortedConfig->{$config}{'id'}
				# text: $sortedConfig->{$config}{'text'} value: $sortedConfig->{$config}{'value'}");
			
				if (!defined($addressData->{$adrKey}{'value'})) {
					my $eepromValue = HM485::Device::getValueFromEepromData (
						$devHash, $sortedConfig->{$config}{'config'}, $adrStart, $adressStep, 1
					);
				
					$addressData->{$adrKey}{'value'} = $eepromValue;
					$addressData->{$adrKey}{'text'}  = '';
					$addressData->{$adrKey}{'size'}  = $readSize;
					$addressData->{$adrKey}{'le'} = $sortedConfig->{$config}{'le'};
				}
			
 
				$addressData->{$adrKey}{'_adrId'} = $config;
				$addressData->{$adrKey}{'_value_old'} = $addressData->{$adrKey}{'value'};
				$addressData->{$adrKey}{'_value'} = $value;
				
				$value = HM485::Device::updateBits($addressData->{$adrKey}{'value'},$value,$size,$config);
			
				if ($sortedConfig->{$config}{'text'}) {
					$addressData->{$adrKey}{'text'}  .= $sortedConfig->{$config}{'id'} . '=' . $sortedConfig->{$config}{'text'} .' ';
				} else {
					$addressData->{$adrKey}{'text'} .= $sortedConfig->{$config}{'id'} . '=' . $sortedConfig->{$config}{'value'} .' ';
				}
				$addressData->{$adrKey}{'_bit'} = $bit;
				$addressData->{$adrKey}{'_size'} = $size;
			}

			$addressData->{$adrKey}{'value'} = $value;
		
		}
	}
	
	return $addressData;
}

sub valueToSettings($$) {
	my ($paramHash, $value) = @_;
	
	my $retVal  = $value;

	if (exists $paramHash->{'logical'}{'unit'} && 
				$paramHash->{'logical'}{'unit'} eq '100%') {
				$retVal = $value / 100;
			}
	
	#Todo Log 5 print Dumper ("ValueToControl Ret",$retVal);
	return $retVal;
}

sub updateBits ($$$$) {
	my ($eepromValue, $value, $size, $index) = @_;
	#We handle everything as bits, also numbers are more bits
	
	my $bitIndex = ($index * 10) - (int($index) *10);
	my $bitSize  = $size * 10;
	my $retVal   = $eepromValue;
	
	#get the bit
	$value = $value << $bitIndex;
	for (my $i = 0; $i < $bitSize; $i++) {
		
		my $mask = 1 << $i + $bitIndex;
		my $bit  = $value & $mask;
		
		if ($bit) { #bit 1
			$retVal = $retVal | $mask;
		} else {    #bit 0
			my $bitMask = ~(1 << $i + $bitIndex);
			$retVal = $retVal & $bitMask;
		}
	}
	
	return $retVal;
}

sub loadDefaultPeerSettingsneu($) {
	my ($configTypeHash) = @_;
	my $retVal;
	
	if (ref($configTypeHash->{logical}) eq 'HASH' && $configTypeHash->{physical}{interface} eq 'eeprom') {
		if (defined $configTypeHash->{logical}{default}) {
			$retVal = $configTypeHash->{logical}{default};
		} elsif (defined $configTypeHash->{logical}{option}) {
			for(my $index = 0; $index <= $#{$configTypeHash->{logical}{option}}; $index++){
     			if ($configTypeHash->{logical}{option}[$index]{default}) {
     				$retVal = $index;
     				last;
     			}
			}			
		}
	}
	
	return $retVal;
}

sub loadDefaultPeerSettings($) {
	my ($device) = @_;
	
	#todo get the defaults direct from xml
	my $settings;
	
	if ($device eq 'switch' || $device eq 'input_output') {
		$settings->{'short_action_type'} = 1;		#6.0
													#6.2 gibts ned
		$settings->{'short_toggle_use'} = 0;		#6.4
		$settings->{'short_off_time_mode'} = 1;		#6.6
		$settings->{'short_on_time_mode'} = 1;		#6.7
	
		$settings->{'long_action_type'} = 1;		#7.0
		$settings->{'long_multiexecute'} = 1;		#7.2   30.4
		$settings->{'long_toggle_use'} = 0;			#7.4
		$settings->{'long_off_time_mode'} = 1;		#7.6
		$settings->{'long_on_time_mode'} = 1;		#7.7  
	
		$settings->{'short_ondelay_time'} = 0;		#8     12
		$settings->{'short_on_time'} = 49152;		#10    16
		$settings->{'short_offdelay_time'} = 0;		#12    18
		$settings->{'short_off_time'} = 49152;		#14    22
	
		$settings->{'short_jt_ondelay'} = 1;		#16.0  27
		$settings->{'short_jt_on'} = 2;				#16.3  
		$settings->{'short_jt_offdelay'} = 3;		#16.6
		$settings->{'short_jt_off'} = 0;			#16.9
	
		$settings->{'long_ondelay_time'} = 0;		#18    36
		$settings->{'long_on_time'} = 49152;		#20    40
		$settings->{'long_offdelay_time'} = 0;		#22		42
		$settings->{'long_off_time'} = 49152;		#24		46
	
		$settings->{'long_jt_ondelay'} = 1;			#26.0	51	
		$settings->{'long_jt_on'} = 2;				#26.3
		$settings->{'long_jt_offdelay'} = 3;		#26.6
		$settings->{'long_jt_off'} = 0;				#26.9   53.4
	}
	
	elsif ($device eq 'dimmer') {
		
		$settings->{'short_on_time_mode'} = 0;			#6.7
		$settings->{'short_off_time_mode'} = 0;			#6.6
		$settings->{'short_ondelay_mode'} = 0;			#6.5
		$settings->{'short_action_type'} = 1;			#6.0
		$settings->{'short_off_level'} = 0; 			#7
		$settings->{'short_on_min_level'} = 0.1;		#8
		$settings->{'short_on_level'} = 1;				#9
		$settings->{'short_ramp_start_step'} = 0.05;	#10
		$settings->{'short_offdelay_step'} = 0.05; 		#11
		$settings->{'short_ondelay_time'} = 0;			#12
		$settings->{'short_rampon_time'} = 0.5;			#14
		$settings->{'short_on_time'} = 49152;			#16
		$settings->{'short_offdelay_time'} = 0;			#18
		$settings->{'short_rampoff_time'} = 0.5;		#20
		$settings->{'short_off_time'} = 49152;			#22
		$settings->{'short_dim_min_level'} = 0; 		#24
		$settings->{'short_dim_max_level'} = 1;			#25
		$settings->{'short_dim_step'} = 0.05;			#26
		$settings->{'short_jt_ondelay'} = 1;			#27
		$settings->{'short_jt_rampon'} = 2; 			#27.4
		$settings->{'short_jt_on'} = 3;					#28
		$settings->{'short_jt_offdelay'} = 4;			#28.4
		$settings->{'short_jt_rampoff'} = 5;			#29
		$settings->{'short_jt_off'} = 0;				#29.4
		$settings->{'long_on_time_mode'} = 0;			#30.7
		$settings->{'long_off_time_mode'} = 0;			#30.6
		$settings->{'long_ondelay_mode'} = 0;			#30.5
		$settings->{'long_multiexecute'} = 1;			#30.4
		$settings->{'long_action_type'} = 6;			#30
		$settings->{'long_off_level'} = 0;				#31
		$settings->{'long_on_min_level'} = 0.1; 		#32
		$settings->{'long_on_level'} = 1; 				#33
		$settings->{'long_ramp_start_step'} = 0.05;		#34
		$settings->{'long_offdelay_step'} = 0.05;		#35
		$settings->{'long_ondelay_time'} = 0;			#36
		$settings->{'long_rampon_time'} = 0.5;  		#38
		$settings->{'long_on_time'} = 49152;			#40
		$settings->{'long_offdelay_time'} = 0;			#42
		$settings->{'long_rampoff_time'} = 0.5; 		#44
		$settings->{'long_off_time'} = 49152;			#46
		$settings->{'long_dim_min_level'} = 0; 			#48
		$settings->{'long_dim_max_level'} = 1;  		#49
		$settings->{'long_dim_step'} = 0.05;			#50
		$settings->{'long_jt_ondelay'} = 1;				#51
		$settings->{'long_jt_rampon'} = 2; 				#51.4
		$settings->{'long_jt_on'} = 3;					#52
		$settings->{'long_jt_offdelay'} = 4;			#52.4
		$settings->{'long_jt_rampoff'} = 5;				#53
		$settings->{'long_jt_off'} = 0;					#53.4
	}
	
	elsif ($device eq 'blind') {
		
		$settings->{'short_on_time_mode'} = 1;
		$settings->{'short_off_time_mode'} = 1;
		$settings->{'short_driving_mode'} = 3;
		$settings->{'short_toggle_use'} = 1;
		$settings->{'short_action_type'} = 1;
		$settings->{'short_off_level'} = 0;
		$settings->{'short_on_level'} = 1;
		$settings->{'short_ondelay_time'} = 0;
		$settings->{'short_offdelay_time'} = 0;
		$settings->{'short_on_time'} = 49152;
		$settings->{'short_off_time'} = 49152;
		$settings->{'short_max_time_first_dir'} = 25.5;
		$settings->{'short_jt_ondelay'} = 1;
		$settings->{'short_jt_refon'} = 3;
		$settings->{'short_jt_rampon'} = 3;
		$settings->{'short_jt_on'} = 4;
		$settings->{'short_jt_offdelay'} = 5;
		$settings->{'short_jt_refoff'} = 7;
		$settings->{'short_jt_rampoff'} = 7;
		$settings->{'short_jt_off'} = 0;
		
		$settings->{'long_on_time_mode'} = 1;
		$settings->{'long_off_time_mode'} = 1;
		$settings->{'long_driving_mode'} = 3;
		$settings->{'long_toggle_use'} = 1;
		$settings->{'long_multiexecute'} = 1;
		$settings->{'long_action_type'} = 1;
		$settings->{'long_off_level'} = 0;
		$settings->{'long_on_level'} = 1;
		$settings->{'long_ondelay_time'} = 0;
		$settings->{'long_offdelay_time'} = 0;
		$settings->{'long_on_time'} = 49152;
		$settings->{'long_off_time'} = 49152;
		$settings->{'long_max_time_first_dir'} = 0.5;
		$settings->{'long_jt_ondelay'} = 1;
		$settings->{'long_jt_refon'} = 3;
		$settings->{'long_jt_rampon'} = 3;
		$settings->{'long_jt_on'} = 4;
		$settings->{'long_jt_offdelay'} = 5;
		$settings->{'long_jt_refoff'} = 7;
		$settings->{'long_jt_rampoff'} = 7;
		$settings->{'long_jt_off'} = 0;
	}
	
	return $settings;
}

1;