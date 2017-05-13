

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
	return undef unless(ref($linkParams->{$peerType}) eq 'HASH');
	return undef unless(ref($linkParams->{$peerType}{parameter}) eq 'ARRAY');
	my $channelHash = HM485::Util::getArrayEntryWithId($linkParams->{$peerType}{parameter}, "channel");
	return undef unless $channelHash;
	for (my $peerId = 0 ; $peerId < $linkParams->{$peerType}{count}; $peerId ++) {
		my $adrStart = $linkParams->{$peerType}{address_start}
				+ ($peerId * $linkParams->{$peerType}{address_step});
		my $chHash = HM485::ConfigurationManager::writeConfigParameter($devhash,
						$channelHash, $adrStart, $linkParams->{$peerType}{address_step});
		return $peerId if($chHash->{value} >= 255);			
	}	
	return undef;
}

sub getPeerId ($$$$) {
	my ($hash, $hmwid, $channel, $isAct) = @_;
	
	my $ch 			= int($channel) -1;
	my $peertype 	= $isAct ? 'actuator' : 'sensor';
	my $linkParams 	= getLinkParams($hash);
		
	return undef unless(ref($linkParams->{$peertype}) eq 'HASH');
	for (my $peerId = 0 ; $peerId < $linkParams->{$peertype}{count}; $peerId ++) {		
		my $adrStart = $linkParams->{$peertype}{address_start} + 
			($peerId * $linkParams->{$peertype}{address_step});
		next unless(ref($linkParams->{$peertype}{parameter}) eq 'ARRAY');
		my $channelHash = HM485::Util::getArrayEntryWithId($linkParams->{$peertype}{parameter}, "channel");
		next unless($channelHash);
		my $chHash = HM485::ConfigurationManager::writeConfigParameter($hash,
						$channelHash, $adrStart, $linkParams->{$peertype}{address_step});
		next unless(($chHash->{value} < 255) && ($chHash->{value} == $ch));
        my $peeringHash = HM485::Util::getArrayEntryWithId($linkParams->{$peertype}{parameter}, $peertype);			
		my $adrHash = HM485::ConfigurationManager::writeConfigParameter($hash,
							$peeringHash, $adrStart, $linkParams->{$peertype}{address_step});
		return $peerId if ($adrHash->{value} eq $hmwid);
	}
	return undef;
}	

# Determine peer role for channel hash
# This is buffered in internal peerRole
# Result can be "sensor", "actuator" or "none"
sub getPeerRole($){
    my ($channelHash) = @_;
	# buffered?
	return $channelHash->{peerRole} if(defined($channelHash->{peerRole}));
	# channel?
	return undef unless(defined($channelHash->{devHash}));
	# not buffered, determine
	my $linkParams = getLinkParams($channelHash->{devHash});
	if (exists($linkParams->{sensor}{channels})) {
	    my @channels = split(' ',$linkParams->{sensor}{channels});
		foreach my $num (@channels) {
		    next if($num != $channelHash->{chanNo});
		    $channelHash->{peerRole} = "actuator";
			return "actuator"; 
		}
	};	
	if (exists($linkParams->{actuator}{channels})) {
	    my @channels = split(' ',$linkParams->{actuator}{channels});
		foreach my $num (@channels) {
		    next if($num != $channelHash->{chanNo});
		    $channelHash->{peerRole} = "sensor";
			return "sensor"; 
		}
	};	
    $channelHash->{peerRole} = "none";
    return "none";
}


sub getPeeredChannelsUnbuffered($) {
	my ($channelHash) = @_;
    my $peerRole = getPeerRole($channelHash);
	# can this channel have peerings at all?
    return [] if($peerRole eq "none");
    my $devHash = $channelHash->{devHash};
	my $devLinks = getLinksFromDevice($devHash);
	my @result;
	# we need to check both roles, even though only one can be correct
	# otherwise, broken peerings through behaviour changes cannot be deleted
	foreach my $actsen ("actuator","sensor") {
	    foreach my $peerId (keys %{$devLinks->{$actsen."s"}}) {
	        # correct channel?
		    next unless($devLinks->{$actsen."s"}{$peerId}{channel} eq $channelHash->{chanNo});			
		    push(@result, getDevNameByHmwId($devLinks->{$actsen."s"}{$peerId}{$actsen}));			
	    };
	};
	my @sortedResult = sort(@result);
    return \@sortedResult;	
};


sub getPeeredChannels($) {
	my ($channelHash) = @_;
	# only for channels
    my $devHash = $channelHash->{devHash};
	return [] unless(defined($devHash));
    my $result = $devHash->{cache}{$channelHash->{chanNo}}{peeredChannels};
	if(!defined($result)) {
		return [] unless($devHash->{READINGS}{configStatus}{VAL} eq 'OK');
	    $result = getPeeredChannelsUnbuffered($channelHash);
		$devHash->{cache}{$channelHash->{chanNo}}{peeredChannels} = $result;
	};
	return $result;
};


sub getPeerableChannels($) {
	my ($channelHash) = @_;
    my $peerRole = getPeerRole($channelHash);
	# can this channel have peerings at all?
    return [] if($peerRole eq "none");
	return [] unless($channelHash->{devHash}{READINGS}{configStatus}{VAL} eq 'OK');
    my @peerable;
	my $otherRole = ($peerRole eq "sensor" ? "actuator" : "sensor");
	my $IODev = $channelHash->{devHash}{IODev};
    foreach my $otherChannel (values %{$main::modules{HM485}{defptr}}) {
	    # we are only interested in channels
        next unless(defined($otherChannel->{devHash}));
		# direct peering only via the same gateway
		next unless($otherChannel->{devHash}{IODev} == $IODev);
        next unless(getPeerRole($otherChannel) eq $otherRole);
        push @peerable, $otherChannel->{NAME};		
	};
	# remove what is already peered	
	my $alreadyPeered = getPeeredChannels($channelHash);
	my %in_alreadyPeered = map {$_ => 1} @{$alreadyPeered};
    my @notYetPeered  = grep {not $in_alreadyPeered{$_}} @peerable;
	my @sortedResult = sort(@notYetPeered);
    return \@sortedResult;	
}




sub getDevNameByHmwId($) {
	my ($hmwId) = @_;
	
	my $hash = $main::modules{HM485}{defptr}{$hmwId};
	my $retVal = 'unknown_'.$hmwId;
	
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
	# not found, might be "unknown_xxxxxxxx_nn(n)"
	my @parts = split("_",$name);
	# some plausibility check
	return undef unless(@parts == 3 && $parts[0] eq "unknown" && length($parts[1]) == 8 
	                      && length($parts[2]) > 1);
	return $parts[1]."_".$parts[2];					  
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
					# this might be called when not all channels are created yet
					next unless($chHash);
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
        # check if config reading is ready
		return $peers unless($devHash->{READINGS}{configStatus}{VAL} eq 'OK');
        # avoid double definition
        my $channelParam = undef;		
		my $linkParams = getLinkParams($devHash);
        # print Dumper($linkParams);

		#todo split into sub getParamValue
		if (ref($linkParams->{actuator}{parameter}) eq 'ARRAY' && $linkParams->{actuator}{count}) {
			
			for (my $peerId=0 ; $peerId < $linkParams->{actuator}{count}; $peerId++) {
		
				my $adrStart = $linkParams->{actuator}{address_start} +
					($peerId * $linkParams->{actuator}{address_step});
				$channelParam = HM485::Util::getArrayEntryWithId($linkParams->{actuator}{parameter}, "channel");
				next unless($channelParam);
				my $chHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
						$channelParam, $adrStart, $linkParams->{actuator}{address_step}
					);
				if (defined($chHash->{value}) && $chHash->{value} < '255') {
				    my $actuatorParam = HM485::Util::getArrayEntryWithId($linkParams->{actuator}{parameter}, "actuator");
				    next unless($actuatorParam);
				    my $addrHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
							             $actuatorParam, $adrStart, $linkParams->{actuator}{address_step}
						           );
					if ($addrHash->{value}) {
						$peers->{actuators}{$peerId}{actuator} = $addrHash->{value};
						$peers->{actuators}{$peerId}{channel} = sprintf("%02d",$chHash->{value} + 1);
						my $peerHash = $main::modules{HM485}{defptr}{$peers->{actuators}{$peerId}{actuator}};
						if (!$peerHash) {
						    $peerHash->{NAME} = 'unknown_'.$peers->{actuators}{$peerId}{actuator};
						};
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
		
		if (ref($linkParams->{sensor}{parameter}) eq 'ARRAY' && $linkParams->{sensor}{count}) {
			for (my $peerId=0 ; $peerId < $linkParams->{sensor}{count}; $peerId++) {
				my $adrStart = $linkParams->{sensor}{address_start} + 
					($peerId * $linkParams->{sensor}{address_step});			
				$channelParam = HM485::Util::getArrayEntryWithId($linkParams->{sensor}{parameter}, "channel");
				next unless($channelParam);
				my $chHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
						        $channelParam, $adrStart, $linkParams->{sensor}{address_step}
					         );
				if (defined($chHash->{value}) && $chHash->{value} ne '255') {
				    my $sensorParam = HM485::Util::getArrayEntryWithId($linkParams->{sensor}{parameter}, "sensor");
				    next unless($sensorParam);
					my $addrHash = HM485::ConfigurationManager::writeConfigParameter($devHash,
							         $sensorParam, $adrStart, $linkParams->{sensor}{address_step}
						           );
					if ($addrHash->{value}) {
						$peers->{sensors}{$peerId}{sensor} = $addrHash->{value};
						$peers->{sensors}{$peerId}{channel} = sprintf("%02d",$chHash->{value} + 1);
						my $peerHash = $main::modules{HM485}{defptr}{$peers->{sensors}{$peerId}{sensor}};
						if (!$peerHash) {
						    $peerHash->{NAME} = 'unknown_'.$peers->{sensors}{$peerId}{sensor};
						};
						if (!$peerHash) { $peerHash->{NAME} = 'unknown_'.$peers->{sensors}{$peerId}{sensor}};
						$devHash->{'peer_sen_'.$peerId} = 'channel_'.$peers->{sensors}{$peerId}{channel}.
								' ← '. $peerHash->{NAME};
					}	
				} else {
				    # remove empty peering
				    delete($devHash->{'peer_sen_'.$peerId});
				}	
			}
		}
		
		if ($peers) {
			$devHash->{cache}{peers} = $peers;
		} else {
			#dummy for caching if device has no peering implemented
			$devHash->{cache}{peers}{sensors} = {};
		}
        # print Dumper($peers);
	}
	return $peers;
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
		
		# care for special_value
		if (defined($configData->{$sort}{config}{logical}) &&
		        defined($configData->{$sort}{config}{logical}{special_value}) &&
			    $configData->{$sort}{value} eq $configData->{$sort}{config}{logical}{special_value}{id}) {
			$configData->{$sort}{value} = $configData->{$sort}{config}{logical}{special_value}{value};
		};		
		
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

sub convertPeeringsToEepromData($$$) {
	my ($devHash, $configData, $senact) = @_;

	my $adressStart = 0;
	my $adressStep  = 0;
	my $adressOffset = 0;
	
	my ($hmwId, $chNr) = HM485::Util::getHmwIdAndChNrFromHash($devHash);
	
	if ($chNr != 0) {
		$devHash = $main::modules{HM485}{defptr}{substr($hmwId,0,8)};
	}
	
	my $devLinkParams = getLinkParams($devHash);
	my $linkParams;
		
    $linkParams =  $devLinkParams->{$senact};
		
	$adressStart = $linkParams->{address_start} ? $linkParams->{address_start} : 0;
	$adressStep  = $linkParams->{address_step}  ? $linkParams->{address_step} : 1;
	$adressOffset = $adressStart + ($configData->{channel}{peerId} + 1) * $adressStep;
	
	my $adrStart = $linkParams->{address_start} +
		 ($configData->{channel}{peerId} * $linkParams->{address_step}
	);
		
	my $log = sprintf("0x%X",$adrStart);
	
	HM485::Util::Log3($devHash, 4,
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
				#print(Dumper($sortedConfig)) unless(defined($sortedConfig->{$config}{'id'}) && defined($sortedConfig->{$config}{'value'}));
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
	
	return $retVal;
}


sub loadDefaultPeerSettings($) {
	my ($configTypeHash) = @_;
	my $retVal;
	
    return undef unless(ref($configTypeHash->{logical}) eq 'HASH' && 
		                    $configTypeHash->{physical}{interface} eq 'eeprom');
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

	if(defined($configTypeHash->{logical}{special_value}) 
	        && $configTypeHash->{logical}{special_value}{value} eq $retVal) {
		$retVal = $configTypeHash->{logical}{special_value}{id};	
	};		
	return $retVal;
}


sub sendUnpeer($$;$) {
	my ($senHmwId,$actHmwId,$fromAct) = @_;
	
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
		
		my $pHash = $main::modules{HM485}{defptr}{$phmwId};
		# broken link -> only one side
		next unless($pHash);
		my $ch = $pHash->{chanNo};
		my $pdevHash = $pHash->{devHash};
		my $params   = HM485::PeeringManager::getLinkParams($pdevHash);
		my $peerId   = HM485::PeeringManager::getPeerId($pdevHash,$hmwId,$ch,$isAct);
		# if we do not find the peering, this can just be a broken link
		next unless(defined($peerId));
		#write FF into address and channel
		my $config;
		$config->{$senAct}{'value'}    = 'FFFFFFFFFF';
		$config->{$senAct}{'config'}   = HM485::Util::getArrayEntryWithId($params->{$senAct}{parameter}, $senAct);
		$config->{$senAct}{'chan'}     = $ch;
		$config->{'channel'}{'value'}  = hex('FF');
		$config->{'channel'}{'config'} = HM485::Util::getArrayEntryWithId($params->{$senAct}{parameter}, "channel");
		$config->{'channel'}{'peerId'} = $peerId;
		my $settings = HM485::PeeringManager::convertPeeringsToEepromData($pdevHash, $config, $senAct);
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
			HM485::Util::Log3($pdevHash, 4, 'Set unpeer for ' . $phmwId . ': '.$settings->{$adr}{'text'});
			$adr = sprintf ('%04X' , $adr);
			HM485::Device::internalUpdateEEpromData($pdevHash,$adr . $size . $value);
			main::HM485_SendCommand($pdevHash, $phmwId, '57' . $adr . $size . $value);
		}
		main::HM485_SendCommand($pdevHash, $phmwId, '43');
	}
	return '';
}

1;