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



sub brokenPeers ($$) {
	my ($hash, $chList) = @_;
	
	my @list = @{$chList};
	my $retVal = undef;
	
	my $devHash = $main::modules{HM485}{defptr}{substr($hash->{DEF}, 0, 8)};
	my $channel = substr($hash->{DEF}, 9, 2);
	my $devchannels = $devHash->{cache}{peered_act};
	my @chArray = ();
	
	#first we create a array of peers with the aprobiate channel,
	#then compare two arrays
	
	foreach my $peerId (keys %{$devchannels}) {
		if ($channel eq $devchannels->{$peerId}{channel}) {
			my $name = getDevNameByHmwId($devchannels->{$peerId}{name});
			push @chArray, $name;
		}
	}
	
	my (@intersection, @difference) = ();
    
    my %count = ();
    my $element;
    
    foreach $element (@chArray, @list) { 
    	$count{$element}++;
    }
    foreach $element (keys %count) {
            push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
    }

    if (@difference && $devHash->{CONFIG_STATUS} eq 'OK') {
    	$retVal = \@difference;
    }

    return $retVal;
}

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

sub actuatorPeerList($$) {
	my ($hash,$peerLinks) = @_;
	
	my @peerlist;
	my $retVal;
	
	foreach my $peerId (keys %{$peerLinks->{sensors}}) {
		if ($peerLinks->{sensors}{$peerId}{channel} && 
			$peerLinks->{sensors}{$peerId}{channel} eq substr($hash->{DEF}, 9, 2)) {
			my $name = $peerLinks->{sensors}{$peerId}{sensor};
			push @peerlist, getDevNameByHmwId($name);
		}
	}
	
	$hash->{PeerList} = join(' ', @peerlist);
	$retVal = join(',', @peerlist);
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
					$retVal->{actpeered} = actuatorPeerList($hash,$peerLinks);
					return $retVal;
				}
			
				foreach my $actId (keys %{$peerLinks->{sensors}}) {
					
					if (defined ($peerLinks->{sensors}{$actId}{channel}) &&
					    $peerLinks->{sensors}{$actId}{channel} eq $num &&
						$peerLinks->{sensors}{$actId}{sensor} eq $hash->{DEF}) {
						$alreadyPeered = 1;
					}
				}
						
				if ($alreadyPeered) {
					push @peered, getDevNameByHmwId($hmwId.'_'.$num);
					next;
				} else {
					push @peerable, getDevNameByHmwId($hmwId.'_'.$num);
				}
				
			}
		}					
	}
	
	if (@peered) {
		$hash->{PeerList} = join(" ",@peered);
	} else {
		delete $hash->{PeerList};
	}
	
	$retVal->{peerable} = join(",",@peerable);
	
	# peered could be empty but broken could be set
	# we concatenate broken and peered, so we can also
	# delete broken peers
	my $broken = brokenPeers($hash, \@peered);
	if ($broken) {
		push @peered, @{$broken};
		$hash->{BrokenPeers} = join(" ",@{$broken});
	} else {
		delete $hash->{BrokenPeers};
	}
	$retVal->{peered} = join(",",@peered);
	
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
	
	my $hash = $main::defs{$name};
	if($hash && $hash->{TYPE} eq 'HM485') {
		return $hash->{DEF};
	}
	return undef;
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
					if (defined($chHash->{value}) && $chHash->{value} < '255') {
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
								' → '. $peerHash->{NAME};
							$devHash->{cache}{peered_act}{$peerId}{name} = $peers->{actuators}{$peerId}{actuator};
							$devHash->{cache}{peered_act}{$peerId}{channel} = $peers->{actuators}{$peerId}{channel};
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
					
					if (defined($chHash->{value}) && $chHash->{value} ne '255') {
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
								' ← '. $peerHash->{NAME};
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
	
	HM485::Util::logger ( HM485::LOGTAG_HM485, 3,
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


sub loadDefaultPeerSettings($) {
	my ($configTypeHash) = @_;
	my $retVal;
	
	if (ref($configTypeHash->{logical}) eq 'HASH' && 
		    $configTypeHash->{physical}{interface} eq 'eeprom') {
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

sub sendUnpeer($$;$) {
	my ($senHmwId,$actHmwId,$fromAct) = @_;
	
	my $msg = '';
	my @sort = ('actuator', 'sensor');
	
	if ($fromAct) {
		#unpeer from actuator, turn around
		@sort = ('sensor', 'actuator');
		my $tmp = $senHmwId;
		$senHmwId = $actHmwId;
		$actHmwId = $tmp;
	}
	
	
	foreach my $senAct (@sort) {
			
		my ($isAct, $hmwId, $phmwId);
			
		if ($senAct eq 'sensor') {
			$hmwId  = $senHmwId;
			$phmwId = $actHmwId;
			$isAct  = 0;
		} else { #actuator
			$hmwId  = $actHmwId;
			$phmwId = $senHmwId;
			$isAct  = 1;
		}
		
		my $ch 		 = (int(substr($phmwId,9,2)));
		my $devHash  = $main::modules{'HM485'}{'defptr'}{substr($hmwId,0,8)};
		my $pdevHash = $main::modules{'HM485'}{'defptr'}{substr($phmwId,0,8)};
		my $params   = HM485::PeeringManager::getLinkParams($pdevHash);
		my $peerId   = HM485::PeeringManager::getPeerId($pdevHash,$hmwId,$ch,$isAct);
		
		if (defined $peerId) {
			#write FF into address and channel
			my $config;
			
			$config->{$senAct}{'value'}    = 'FFFFFFFFFF';
			$config->{$senAct}{'config'}   = $params->{$senAct}{'parameter'}{$senAct};
			$config->{$senAct}{'chan'}     = $ch;
			$config->{'channel'}{'value'}  = hex('FF');
			$config->{'channel'}{'config'} = $params->{$senAct}{'parameter'}{'channel'};
			$config->{'channel'}{'peerId'} = $peerId;
			
			my $settings = HM485::PeeringManager::convertPeeringsToEepromData(
				$pdevHash, $config
			);
			
			foreach my $adr (sort keys %$settings) {
		
				my $size  = $settings->{$adr}{'size'} ? $settings->{$adr}{'size'} : 1;
				my $value = $settings->{$adr}{'value'};
					
				if ($settings->{$adr}{'le'}) {
					if ($size >= 1) {
						$value = sprintf ('%0' . ($size*2) . 'X' , $value);
						$value = reverse( pack('H*', $value) );
						$value = hex(unpack('H*', $value));
					}
				}
				
				$size     = sprintf ('%02X' , $size);
				
				if (index($settings->{$adr}{'text'}, $senAct) > -1) {						
					$value = sprintf ('%s', $value);
				} else {
					$value = sprintf ('%0' . ($size * 2) . 'X', $value);
				}
				
				HM485::Util::logger ( $pdevHash->{NAME}.'_'.substr($phmwId,9,2), 3,
					HM485::LOGTAG_HM485.': Set unpeer for ' . $phmwId . ': ' .
					$settings->{$adr}{'text'}
				);
			
				$adr = sprintf ('%04X' , $adr);
				HM485::Device::internalUpdateEEpromData($pdevHash,$adr . $size . $value);
				main::HM485_SendCommand($pdevHash, $phmwId, '57' . $adr . $size . $value);
			}
		} else {
			if ($senAct eq 'actuator' && $fromAct == 0) {
				$msg = "$hmwId. no Eeprom data found, Please wait until eeprom reading is finished";
			} else {
				# delete a brocken peer";
				main::HM485_SendCommand($pdevHash, $phmwId, '43');
			}
		}
		if (!$msg) {
			main::HM485_SendCommand($pdevHash, $phmwId, '43');
		}
	}
	
	return $msg;
}

sub loadPeerSettingsfromFile($) {
	my ($device) = @_;
	
	#todo get the Settings from a file
	my $settings;
	
	if ($device eq 'switch' || $device eq 'input_output') {
		#$settings->{'short_action_type'} = 1;		#6.0
		#$settings->{'short_toggle_use'} = 0;		#6.4
		#$settings->{'short_off_time_mode'} = 1;		#6.6
		#...
	}
	
	elsif ($device eq 'dimmer') {
		
		#$settings->{'short_on_time_mode'} = 0;			#6.7
		#$settings->{'short_off_time_mode'} = 0;			#6.6
		#$settings->{'short_ondelay_mode'} = 0;			#6.5
		#...
	}
	
	elsif ($device eq 'blind') {
		
		#$settings->{'short_on_time_mode'} = 1;
		#$settings->{'short_off_time_mode'} = 1;
		#$settings->{'short_driving_mode'} = 3;
		#....
		
	}
	
	return $settings;
}

1;