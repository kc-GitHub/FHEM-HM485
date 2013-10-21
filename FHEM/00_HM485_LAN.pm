=head1
	00_HM485_LAN.pm

=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013
	$Id$

=head1 DESCRIPTION
	00_HM485_LAN is the interface for communicate with HomeMatic Wired (HM485) devices
	over USB / UART / RS232 -> RS485 Converter

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
=cut
 
package main;

use strict;
use warnings;

use Data::Dumper;    # for debugging only

use Cwd qw(abs_path);
use FindBin;
use lib abs_path("$FindBin::Bin");

use lib::HM485::Constants;
use lib::HM485::Device;
use lib::HM485::Util;

use vars qw {%data %attr %defs %selectlist %modules}; #supress errors in Eclipse EPIC IDE

# Function prototypes
sub HM485_LAN_Initialize($);
sub HM485_LAN_Define($$);
sub HM485_LAN_Ready($);
sub HM485_LAN_Undef($$);
sub HM485_LAN_Shutdown($);
sub HM485_LAN_Read($);
sub HM485_LAN_Write($$;$);
sub HM485_LAN_Set($@);
sub HM485_LAN_Attr(@);

# Helper functions
sub HM485_LAN_Init($);
sub HM485_LAN_InitInterface($$);
sub HM485_LAN_parseIncommingCommand($$);
sub HM485_LAN_Connect($);
sub HM485_LAN_RemoveValuesFromAttrList($@);
sub HM485_LAN_openDev($;$);
sub HM485_LAN_checkAndCreateHM485d($);
sub HM485_LAN_HM485dGetPid($$);
sub HM485_LAN_DispatchNack($$);

use constant {
	SERIALNUMBER_DEF   => 'SGW0123456',
	KEEPALIFE_TIMER    => 'keepAlife:',
	KEEPALIFECK_TIMER  => 'keepAlifeCk:',
	KEEPALIFE_TIMEOUT  => 20, # CCU2 send keepalife each 20 seconds, Todo: check if we need to modify the timeout via attribute
	KEEPALIFE_MAXRETRY => 3,
};

=head2
	Implements Initialize function
	
	@param	hash	hash of device addressed
=cut
sub HM485_LAN_Initialize($) {
	my ($hash) = @_;
	my $dev  = $hash->{DEF};
	my $name = $hash->{NAME};
	
	my $initResult = HM485::Device::init();

	if ($initResult) {
		HM485::Util::logger($name, 1, $initResult);
	} else {

		require $attr{global}{modpath} . '/FHEM/DevIo.pm';

		$hash->{DefFn}      = 'HM485_LAN_Define';
		$hash->{ReadyFn}    = 'HM485_LAN_Ready';
		$hash->{UndefFn}    = 'HM485_LAN_Undef';
		$hash->{ShutdownFn} = 'HM485_LAN_Shutdown';
		$hash->{ReadFn}     = 'HM485_LAN_Read';
		$hash->{WriteFn}    = 'HM485_LAN_Write';
		$hash->{SetFn}      = 'HM485_LAN_Set';
		$hash->{AttrFn}     = "HM485_LAN_Attr";
	
		$hash->{AttrList}   = 'hmwId do_not_notify:0,1 HM485d_bind:0,1 ' .
		                     'HM485d_startTimeout HM485d_device ' . 
		                     'HM485d_serialNumber HM485d_logfile ' .
		                     'HM485d_detatch:0,1 HM485d_logVerbose:0,1,2,3,4,5 ' . 
		                     'HM485d_gpioTxenInit HM485d_gpioTxenCmd0 ' . 
		                     'HM485d_gpioTxenCmd1';
		
		my %mc = ('1:HM485' => '^.*');
		$hash->{Clients}    = ':HM485:';
		$hash->{MatchList}  = \%mc;
	}
}

=head2
	Implements DefFn function
	
	@param	hash    hash of device addressed
	@param	string  definition string
	
	@return string | undef
=cut
sub HM485_LAN_Define($$) {
	my ($hash, $def) = @_;
	my @a = split('[ \t][ \t]*', $def);

	my $ret = undef;
	my $name = $a[0];

	my $msg = '';
	if( (@a < 3)) {
		$msg = 'wrong syntax: define <name> HM485 {none | hostname:port}';
	}

	# create default hmwId on define, modify is possible e.g. via "attr <name> hmwId 00000002"
	$ret = CommandAttr(undef, $name . ' hmwId 00000001');

	if (!$ret) {
		$hash->{DEF} = $a[2];

		if($hash->{DEF} eq 'none') {
			HM485::Util::logger($name, 1, 'HM485 device is none, commands will be echoed only');
		} else {
			# Make shure HM485_LAN_Connect starts after HM485_LAN_Define is ready 
			InternalTimer(gettimeofday(), 'HM485_LAN_ConnectOrStartHM485d', $hash, 0);
		}
				
	} else {
		HM485::Util::logger($name, 1, $ret);
	}

	$hash->{msgCounter} = 0;
	$hash->{STATE} = '';

	$data{FWEXT}{test}{SCRIPT} = 'hm485.js?' . gettimeofday()
		. '"><script type="text/javascript" charset="UTF-8';

	return $ret;
}

=head2
	Implements ReadyFn function.

	@param	hash    hash of device addressed
	@return mixed   return value of the HM485_LAN_Init function
=cut
sub HM485_LAN_Ready($) {
	my ($hash) = @_;

	return HM485_LAN_openDev($hash, 1);
}

=head2
	Implements UndefFn function.

	Todo: maybe we must implement kill term for HM485d

	@param	hash    hash of device addressed
	@param	string  name of device

	@return undef
=cut
sub HM485_LAN_Undef($$) {
	my ($hash, $name) = @_;

	DevIo_CloseDev($hash);
	
	if (!AttrVal($name, 'HM485d_detatch', 0)) {
		HM485_LAN_HM485dStop($hash);
	}

	return undef;
}

=head2
	Implements Shutdown function.

	@param	hash    hash of device addressed
=cut
sub HM485_LAN_Shutdown($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	if (!AttrVal($name, 'HM485d_detatch', 0)) {
		HM485_LAN_HM485dStop($hash);
	}
}

=head2
	Implements ReadFn function.
	called from the global loop, when the select for hash->{FD} reports data

	@param	hash    hash of device addressed
=cut
sub HM485_LAN_Read($) {
	my ($hash) = @_;

	my $name   = $hash->{NAME};
	my $buffer = DevIo_SimpleRead($hash);

	if ($buffer) {
		# Remove timer to avoid duplicates
		RemoveInternalTimer(KEEPALIFECK_TIMER . $name);
		RemoveInternalTimer(KEEPALIFE_TIMER   . $name);
		
		if ($buffer eq 'Connection refused. Only on Client allowed') {
			$hash->{ERROR} = $buffer;
	
		} else {
			my $msgStart = substr($buffer,0,1);
			if ($msgStart eq 'H') {
				HM485_LAN_InitInterface($hash, $buffer);
	
			} elsif ($msgStart eq chr(HM485::FRAME_START_LONG)) {
	
				my @messages = split(chr(HM485::FRAME_START_LONG), $buffer);
				foreach my $message (@messages) {
					if ($message) {
						$message = chr(HM485::FRAME_START_LONG) . $message;
			
						$message = HM485::Util::unescapeMessage($message);
	
						### Debug ###
	#					my $m = $message;
	#					my $l = uc( unpack ('H*', $m) );
	##					$m =~ s/^.*CRLF//g;
	#					Log3 ('', 1, $l . ' (RX: ' . $m . ')' . "\n");
	
						HM485_LAN_parseIncommingCommand($hash, $message);
					}
				}
			}
	
			InternalTimer(
				gettimeofday() + KEEPALIFE_TIMEOUT, 'HM485_LAN_KeepAlife', KEEPALIFE_TIMER . $name, 1
			);
		}
	}
}

=head2
	Initialize the Interface

	@param	hash      hash of device addressed
=cut
sub HM485_LAN_InitInterface($$) {
	my ($hash, $message) = @_;	

	my $name = $hash->{NAME};
	$message =~ s/\r\n/,/g;
	
	my (undef, $protokolVersion, $interfaceType, $version, $serialNumber, $msgCounter) = split(',', $message);

	$hash->{InterfaceType}   = $interfaceType;
	$hash->{ProtokolVersion} = $protokolVersion;
	$hash->{Version}         = $version;
	$hash->{SerialNumber}    = $serialNumber;
	$hash->{msgCounter}      = hex(substr($msgCounter,1));

	HM485::Util::logger($name, 3, 'Lan Device Information');
	HM485::Util::logger($name, 3, 'Protocol-Version: ' . $hash->{ProtokolVersion});
	HM485::Util::logger($name, 3, 'Interface-Type: '   . $interfaceType);
	HM485::Util::logger($name, 3, 'Firmware-Version: ' . $version);
	HM485::Util::logger($name, 3, 'Serial-Number: '    . $serialNumber);

	# initialize keepalife flags
	$hash->{keepalife}{ok}    = 1;
	$hash->{keepalife}{retry} = 0;

	# Send the Initialize sequence	
	HM485_LAN_Write($hash, HM485::CMD_INITIALIZE);				
}

=head2
	Implements WriteFn function.

	This function acts as the IOWrite function for the client module

	@param	hash      hash of device addressed
	@param	integer   the command @see lib/Constants.pm
	@param	hashref   aditional parameter
	
	@return integer   the message id of the sended message
=cut
sub HM485_LAN_Write($$;$) {
	my ($hash, $cmd, $params) = @_;
	my $name = $hash->{NAME};
	my $msgId = $hash->{msgCounter} ? $hash->{msgCounter} : 1;

	if ($cmd == HM485::CMD_SEND || $cmd == HM485::CMD_DISCOVERY ||
		$cmd == HM485::CMD_KEEPALIFE || HM485::CMD_INITIALIZE) {
			
		my $sendData = '';
		my $sendDataLog = '';
		if ($cmd == HM485::CMD_SEND) {

			# ctrl check for sending
			my $ctrl = $params->{ctrl};
			if (!$ctrl) {
				$ctrl = $hash->{ctrl}{$params->{target}};
				if (!$ctrl) {
					$ctrl = '98';
				} else {
					$ctrl = hex($ctrl);
					my $txNum = HM485::Util::ctrlTxNum($ctrl);
					$txNum = ($txNum < 3) ? $txNum + 1 : 0;
					# Set new txNum and reset sync bit (& 0x7F)
					$ctrl = HM485::Util::setCtrlTxNum($ctrl & 0x7F, $txNum);
					$ctrl = sprintf('%02X', $ctrl);					
				}
			}
			$hash->{ctrl}{$params->{target}} = $ctrl;
			# todo:
			# reset ctrl byte if sync sent from device
			# respect nack 

			my $source = (exists($params->{source})) ? $params->{source} : AttrVal($name, 'hmwId', '00000001');
			my $target = $params->{target};
			my $data = $params->{data};

			$hash->{Last_Sent_RAW_CMD} = sprintf (
				'%s %s %s %s', $target, $ctrl, $source, $data
			);

			# Debug
			my %RD = (
				target  => pack('H*', $target),
				cb      => hex($ctrl),
				sender  => pack('H*', $source),
				datalen => length($data) + 2,
				data    => pack('H*', $data . 'FFFF'),
			);

			$sendDataLog = HM485::Util::logger($name, 3, 'TX: (' . $msgId . ')', \%RD, 1);
			$sendData = pack('H*',
				sprintf(
					'%02X%02X%s%s%s%s%s', $msgId, $cmd, 'C8', $target, $ctrl, $source, $data
				)
			);

		} elsif ($cmd == HM485::CMD_DISCOVERY) {
			$sendData = pack('H*',sprintf('%02X%02X00FF', $msgId, $cmd));

		} elsif ($cmd == HM485::CMD_KEEPALIFE) {
			$sendData = pack('H*',sprintf('%02X%02X', $msgId, $cmd));
			HM485::Util::logger($name, 3, 'keepalife msgNo: ' . $msgId);

		} elsif ($cmd == HM485::CMD_INITIALIZE) {
			my $txtMsgId = unpack('H4', sprintf('%02X', $msgId));
			$sendData = pack('H*',sprintf('%02X%s%s', $cmd, $txtMsgId, '2C303030300D0A'));
			HM485::Util::logger ($name, 3, 'Initialize the interface');
		}

		if ($sendData) {
			if ($cmd == HM485::CMD_INITIALIZE) {
				$sendData = chr(HM485::FRAME_START_LONG) . $sendData;
			} else {
				$sendData = chr(HM485::FRAME_START_LONG) . chr(length($sendData)) . $sendData;
				$sendData = HM485::Util::escapeMessage($sendData);
			}

			if ($cmd == HM485::CMD_SEND || $cmd == HM485::CMD_DISCOVERY) {
				my $target = $params->{target};
				HM485_LAN_SendQueue($hash, $msgId, $sendData, $target, $sendDataLog);				
			} else {
				DevIo_SimpleWrite($hash, $sendData, 0);
			}
		} 
	}

	$hash->{msgCounter} = ($hash->{msgCounter} >= 0xFF) ? 1 : ($hash->{msgCounter} + 1);

	return $msgId;
}

####################################################################
sub HM485_LAN_SendQueue($$$$$) {
	my ($hash, $msgId, $sendData, $hmwId, $sendDataLog) = @_;

	$hash->{queueId}++;
	my $queueId = sprintf('%08X', $hash->{queueId});

	$hash->{sendQueue}{$queueId}{data}    = $sendData;
	$hash->{sendQueue}{$queueId}{msgId}   = $msgId;
	$hash->{sendQueue}{$queueId}{hmwId}   = $hmwId;
	$hash->{sendQueue}{$queueId}{dataLog} = $sendDataLog;

	if (!$hash->{queueRunning}) {
		$hash->{queueRunning} = 1;
		HM485_LAN_SendQueueNextItem($hash);
	}
}

sub HM485_LAN_SendQueueNextItem($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	delete ($hash->{sendQueue}{0});

	my $queueCount = scalar(keys (%{$hash->{sendQueue}}));
	if ($queueCount > 0) {
		my $currentQueueId = (sort keys %{$hash->{sendQueue}})[0];
		$hash->{currentQueueId} = $currentQueueId;

		my $sendData = $hash->{sendQueue}{$currentQueueId}{data};
		
		DevIo_SimpleWrite($hash, $sendData, 0);
		if ($hash->{sendQueue}{$currentQueueId}{dataLog}) {
			Log3 ($hash, 3, $hash->{sendQueue}{$currentQueueId}{dataLog});
		}
		
		my $checkResendQueueItemsDelay = 1;

		my $hmwId = $hash->{sendQueue}{$currentQueueId}{hmwId};
		if ($hmwId) {
			# For messages to broadcast, with z or Z command we don't wait for ack.
			if ($hmwId eq 'FFFFFFFF' || $sendData eq '5A' || $sendData eq '7A') {
				HM485_LAN_DeleteCurrentItemFromQueue($hash, $currentQueueId);
				$checkResendQueueItemsDelay = 0.1
			}
		}
		
		InternalTimer(
			gettimeofday() + $checkResendQueueItemsDelay,
			'HM485_LAN_CheckResendQueueItems',
			$name . ':queueTimer:' . $currentQueueId, 0
		);
	} else {
		$hash->{queueRunning} = 0;
	}
}

sub HM485_LAN_CheckResendQueueItems($) {
	my ($param) = @_;

	my($name, $timerName, $currentQueueId) = split(':', $param);
	if ($timerName eq 'queueTimer') {
		my $hash = $defs{$name};
	
#		print Dumper($hash->{sendQueue}{$currentQueueId});
		if (exists($hash->{sendQueue}{$currentQueueId})) {
			HM485_LAN_DispatchNack($hash, $currentQueueId);
		}
	
		# prozess next queue item.
		HM485_LAN_SendQueueNextItem($hash);
	}
}

sub HM485_LAN_DeleteCurrentItemFromQueue($$) {
	my ($hash, $currentQueueId) = @_;

	delete ($hash->{sendQueue}{$currentQueueId});
	$hash->{currentQueueId} = 0;	
}

###################################################################

=head2
	Implements SetFn function.

	@param	hash    hash of device addressed
	@param	array   argument array
	
	@return    return error message on failure
=cut
sub HM485_LAN_Set($@) {
	my ($hash, @a) = @_;

	# All allowed set commands
	my %sets = (
		'RAW'                => '',
		'discovery'          => 'start',
		'broadcastSleepMode' => 'off',
	);

	my $name = $a[0];
	my $cmd  = $a[1];
	my $msg  = '';
	
	if (@a < 2) {
		$msg = '"set ' . $name . '" needs one or more parameter';
	
	} else {
		if (AttrVal($name, 'HM485d_bind', 0)) {
			$sets{HM485d} = 'status,stop,start,restart';
		}

		if(!defined($sets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %sets) {
				$arguments.= $arg . ($sets{$arg} ? (':' . $sets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;

		} elsif ($cmd && exists($hash->{discoveryRunning}) && $hash->{discoveryRunning} > 0) {
			$msg = 'Discovery is running. Pleas wait for finishing.';
			# Todo: timeout for aute exit discovery mode

		} elsif ($cmd eq 'RAW') {
			my $paramError = 0;
			if (@a == 6 || @a == 7) {
				if ($a[2] !~ m/^[A-F0-9]{8}$/i || $a[3] !~ m/^[A-F0-9]{2}$/i ||
				    $a[4] !~ m/^[A-F0-9]{8}$/i || $a[5] !~ m/^[A-F0-9]{1,251}$/i ) {
	
					$paramError = 1
				}
			} else {
				$paramError = 1;
			}
	
			if (!$paramError) {
				my %params = (
					target => $a[2],
					ctrl   => $a[3],
					source => $a[4],
					data   => $a[5]
				);
				HM485_LAN_Write($hash, HM485::CMD_SEND, \%params);
	
			} else {
				$msg = '"set HM485 raw" needs 5 parameter Sample: TTTTTTTT CC SSSSSSSS D...' . "\n" .
				       'Set sender address to 00000000 to use address from configuration.' . "\n\n" . 
				       '   T: 8 byte target address, C: Control byte, S: 8 byte sender address, D: data bytes' . "\n"
			}

		} elsif ($cmd eq 'discovery' && $a[2] eq 'start' ) {
			HM485_LAN_discoveryStart($hash);

		} elsif ($cmd eq 'broadcastSleepMode' && $a[2] eq 'off') {
			HM485_LAN_setBroadcastSleepMode($hash, 0)

		} elsif ($cmd eq 'HM485d') {
			if (grep $_ eq $a[2], split(',', $sets{HM485d}) ) {
				if ($a[2] eq 'status') {
					$hash->{HM485d_PID} = HM485_LAN_HM485dGetPid($hash, $hash->{HM485d_CommandLine});
					if ($hash->{HM485d_PID}) {
						$msg = 'HM485d is running with PID ' . $hash->{HM485d_PID};
					} else {
						$msg = 'no matching process of HM485d found!';
					}
					
									
				} elsif ($a[2] eq 'start') {
					$msg = HM485_LAN_HM485dStart($hash);

				} elsif ($a[2] eq 'stop') {
					$msg = HM485_LAN_HM485dStop($hash);

				} elsif ($a[2] eq 'restart') {
					$msg = HM485_LAN_HM485dStop($hash);
					$msg.= "\n" . HM485_LAN_HM485dStart($hash);
				}

			} else {
				$msg = 'Unknown argument ' . $a[2] . ' in "set ' . $name . ' HM485d" ';
				$msg.= 'choose one of: ' . join(', ', split(',', $sets{HM485d}));
			}
		}
	}	

	return $msg;
}

=head2
	Implements AttrFn function.
	Here we validate user values of some attr's

	Todo: Add some more attr's

	@param	undev
	@param	string  name of device
	@param	string  attr name
	@param	string  attr value

	@return undef | string    if attr value was wrong
=cut
sub HM485_LAN_Attr (@) {
	my (undef, $name, $attr, $val) =  @_;
	my $hash = $defs{$name};
	my $msg = '';

	if ($attr eq 'hmwId') {
		$hash->{hmwId} = $val;
		my $hexVal = (defined($val)) ? hex($val) : 0;
		if (!defined($val) || $val !~ m/^[A-F0-9]{8}$/i || $hexVal > 255 || $hexVal < 1) {
			$msg = 'Wrong hmwId defined. hmwId must be 8 digit hex address within 00000001 and 000000FF';
		} else {
			
			foreach my $d (keys %defs) {
				next if($d eq $name);
		
				if($defs{$d}{TYPE} eq 'HM485_LAN') {
					if(AttrVal($d, 'hmwId', '00000001') eq $val) {
						$msg = 'hmwId ' . $val . ' already used. Please use another one.';
					}
				}
			}
		}
		
	}

	return ($msg) ? $msg : undef;
}

=head2
	Start the discovery command

	@param	hash    hash of device addressed
=cut
sub HM485_LAN_discoveryStart($) {
	my ($hash) =  @_;

	$hash->{discoveryRunning} = 1;
	HM485_LAN_setBroadcastSleepMode($hash, 1);
	InternalTimer(gettimeofday() + 1, 'HM485_LAN_doDiscovery', $hash, 0);
}

=head2
	Send the discovery command to the interface

	@param	hash    hash of device addressed
=cut
sub HM485_LAN_doDiscovery($) {
	my ($hash) =  @_;
	HM485_LAN_Write($hash, HM485::CMD_DISCOVERY);
}

=head2
	Complete the discovery


	@param	hash    hash of device addressed
=cut
sub HM485_LAN_discoveryEnd($) {
	# Todo: We should set timer for discovery must have finish

	my ($hash) =  @_;
	my $name = $hash->{NAME};

	if (exists($hash->{discoveryFound})) {
		foreach my $discoverdAddress (keys %{$hash->{discoveryFound}}) {

			# we try to autocreate device only if not extist
			if (!$modules{HM485}{defptr}{$discoverdAddress}) {
				# build dummy message. With this message we can autocreate the device 
				my $message = pack('H*',
					sprintf(
						'FD0E00%02X%s%s%s%s', HM485::CMD_EVENT,
						$hash->{hmwId}, '98', $discoverdAddress, '690000'
					)
				);
		
				### Debug ###
				my $m = $message;
				my $l = uc( unpack ('H*', $m) );
				$m =~ s/^.*CRLF//g;
				HM485::Util::logger($name, 4, $l . ' (RX: ' . $m . ')');
		
	 			HM485::Util::logger($name, 4, 'Dispatch: ' . $discoverdAddress);
				Dispatch($hash, $message, '');
			}
		}
		delete ($hash->{discoveryFound});
	}

	$hash->{discoveryRunning} = 0;
}

=head2
	Set sleep command via broadcast to all bus devices
	
	Before discover can start, we must send sleep command to all bus devices.
	After discovery the sleep command must revert.

	@param	hash   hash of device addressed
	@param	int    1 => setSleepMode, 0 => resetSleepMode
=cut
sub HM485_LAN_setBroadcastSleepMode($$) {
	my ($hash, $value) =  @_;
	
	my %params = (
		target => 'FFFFFFFF',
		ctrl   => '98',
		source => $hash->{hmwId},
		data   => int($value) ? '7A' : '5A'
	);
	HM485_LAN_Write($hash, HM485::CMD_SEND, \%params);
	HM485_LAN_Write($hash, HM485::CMD_SEND, \%params);
}

=head2
	Implements DoInit function. Initialize the serial device

	@param	hash    hash of device addressed
	@return undef
=cut
sub HM485_LAN_Init($) {
	my ($hash) = @_;

	my $dev  = $hash->{DEF};
	my $name = $hash->{NAME};

	HM485::Util::logger($name, 3, 'connected to device ' . $dev);
	$hash->{STATE} = 'open';
	
	delete ($hash->{HM485dStartTimeout});

	return undef;
}

=head2
	Parse HM485 frame and dispatch to the client entyty

	@param	hash    hash of device addressed
	@param	string  the binary message to parse
=cut
sub HM485_LAN_parseIncommingCommand($$) {
	my ($hash, $message) = @_;
	
	my $name           = $hash->{NAME};
	my $msgLen         = ord(substr($message, 1, 1));
	my $msgId          = ord(substr($message, 2, 1));
	my $msgCmd         = ord(substr($message, 3, 1));
	my $msgData        = uc( unpack ('H*', substr($message, 4, $msgLen)));
	my $currentQueueId = $hash->{currentQueueId};
	my $canDispatch    = 0;
	
	if ($msgCmd == HM485::CMD_DISCOVERY_END) {
		my $foundDevices = hex($msgData);
		HM485::Util::logger($name, 4, 'Do action after discovery Found Devices: ' . $foundDevices);
		
		HM485_LAN_setBroadcastSleepMode($hash, 0);
		InternalTimer(gettimeofday() + 1, 'HM485_LAN_discoveryEnd', $hash, 0);

	} elsif ($msgCmd == HM485::CMD_DISCOVERY_RESULT) {
		HM485::Util::logger($name, 3, 'Discovery - found device: ' . $msgData);
		$hash->{discoveryFound}{$msgData} = 1;

	} elsif ($msgCmd == HM485::CMD_ALIFE) {
		my $alifeStatus = substr($msgData, 0, 2);
		HM485::Util::logger($name, 3, 'Alife: (' . $msgId . ') ' . uc(unpack ('H*', $msgData)));
		if ($alifeStatus == '00') {
			# we got a response from keepalife
			$hash->{keepalife}{ok}    = 1;
			$hash->{keepalife}{retry} = 0;
		} else {
			HM485_LAN_DispatchNack($hash, $currentQueueId);
		}

	} elsif ($msgCmd == HM485::CMD_RESPONSE) {
		$canDispatch = 1;
		$hash->{Last_Sent_RAW_CMD_State} = 'ACK';
		HM485::Util::logger($name, 3, 'ACK: (' . $msgId . ')');

		# Debug
		HM485::Util::logger($name, 3, 'Response: (' . $msgId . ') ' . substr($msgData, 2));

	} elsif ($msgCmd == HM485::CMD_EVENT) {
		$canDispatch = 1;

		# Debug
		my %RD = (
			target  => pack('H*',substr($msgData, 0,8)),
			cb      => hex(substr($msgData, 8,2)),
			sender  => pack('H*',substr($msgData, 10,8)),
			datalen => $msgLen,
			data    => pack('H*',substr($msgData, 18)),
		);
		HM485::Util::logger($name, 3, 'RX:', \%RD);
	}		

	if ($canDispatch && length($message) > 3) {
		Dispatch($hash, $message, '');
	}

	if ($currentQueueId) {
		RemoveInternalTimer($name . ':queueTimer:' . $currentQueueId);
		HM485_LAN_DeleteCurrentItemFromQueue($hash, $currentQueueId);
		HM485_LAN_CheckResendQueueItems($name . ':queueTimer:' . $currentQueueId);
	}
}

=head2
	Connect to the defined device or start HM485d
	
	@param	hash    hash of device addressed
=cut
sub HM485_LAN_ConnectOrStartHM485d($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $dev  = $hash->{DEF};

	if (!AttrVal($name, 'HM485d_bind',0)) {
		HM485_LAN_RemoveValuesFromAttrList(
			$hash,
			('HM485d_detatch', 'HM485d_device', 'HM485d_serialNumber',
			 'HM485d_logfile', 'HM485d_logVerbose:0,1,2,3,4,5', 'HM485d_startTimeout',
			 'HM485d_gpioTxenInit', 'HM485d_gpioTxenCmd0', 'HM485d_gpioTxenCmd1')
		);
		
		HM485_LAN_openDev($hash);
		
	} else {
		HM485_LAN_checkAndCreateHM485d($hash);
	}
}

=head2
	Keepalife check of the interface  
	
	@param	string    name of keepalife timer
=cut
sub HM485_LAN_KeepAlife($) {
	my($param) = @_;

	my(undef,$name) = split(':',$param);
	my $hash = $defs{$name};

	my $msgCounter = $hash->{msgCounter};
	
	$hash->{keepalife}{ok} = 1;

	if ($hash->{FD}) {
		HM485_LAN_Write($hash, HM485::CMD_KEEPALIFE);

		# Remove timer to avoid duplicates
		RemoveInternalTimer(KEEPALIFE_TIMER . $name);

		# Timeout where foreign device must response keepalife commands
		my $responseTime = AttrVal($name, 'respTime', 1);

		# start timer to check keepalife response
		InternalTimer(
			gettimeofday() + $responseTime, 'HM485_LAN_KeepAlifeCheck', KEEPALIFECK_TIMER . $name, 1
		);

		# start timeout for next keepalife check
		InternalTimer(
			gettimeofday() + KEEPALIFE_TIMEOUT ,'HM485_LAN_KeepAlife', KEEPALIFE_TIMER . $name, 1
		);
	}
}

=head2
	Check keepalife response.
	If keepalife response is missing, retry keepalife up to KEEPALIFE_MAXRETRY count. 
	
	@param	string    name of keepalife timer
=cut
sub HM485_LAN_KeepAlifeCheck($) {
	my($param) = @_;

	my(undef,$name) = split(':', $param);
	my $hash = $defs{$name};

	if (!$hash->{keepalife}{ok}) {
		# we got no keepalife answer 
		if ($hash->{keepalife}{retry} >= KEEPALIFE_MAXRETRY) {
			# keepalife retry count reached. Disonnect.
			DevIo_Disconnected($hash);
		} else {
			$hash->{keepalife}{retry} ++;

			# Remove timer to avoid duplicates
			RemoveInternalTimer(KEEPALIFE_TIMER . $name);

			# start timeout for repeated keepalife check
			HM485_LAN_KeepAlife(KEEPALIFE_TIMER . $name);
		}
	} else {
		$hash->{keepalife}{retry} = 0;
	}
}

=head2
	Notify the defice if we got a nack
	
	@param	hash    the hash of the device
	@param	string   the HMW id
	@param	string  the request type

=cut
sub HM485_LAN_DispatchNack($$) {
	my ($hash, $currentQueueId) = @_;	
	my $name = $hash->{NAME};

	$hash->{Last_Sent_RAW_CMD_State} = 'NACK';

	if ($currentQueueId) {
		my $msgId = $hash->{sendQueue}{$currentQueueId}{msgId};
		if ($msgId) {
			my $hmwId = $hash->{sendQueue}{$currentQueueId}{hmwId};
			if ($hmwId) {
				if ($modules{HM485}{defptr}{$hmwId}) {
					# We use CMD_ALIFE and second byte for signalize NACK messages internaly
					# The last 4 bytes identify the HMW-ID which was not acked
					my $message = pack('H*',
						sprintf(
							'%02X%02X%02X%02X%02X%s',
							HM485::FRAME_START_LONG, 3, $msgId, HM485::CMD_ALIFE, 1, $hmwId
						)
					);
					Dispatch($hash, $message, '');
				} else {
					HM485::Util::logger($name, 3, 'NACK: (' . $msgId . ') ' . $hmwId);
				}
			}
		}
		HM485_LAN_DeleteCurrentItemFromQueue($hash, $currentQueueId);
	}
}

=head2
	Remove values from $hash->{AttrList}
	
	@param	hash    hash of device addressed
	@param	array   array of values to remove
=cut
sub HM485_LAN_RemoveValuesFromAttrList($@) {
	my ($hash, @removeArray) = @_;
	my $name = $hash->{NAME};

	foreach my $item (@removeArray){
		$modules{$defs{$name}{TYPE}}{AttrList} =~ s/$item//;
		delete($attr{$name}{$item});
	}
}

=head2
	Open the device
	
	@param	hash    hash of device addressed
=cut
sub HM485_LAN_openDev($;$) {
	my ($hash, $reconnect) = @_;
	
	my $retVal = undef;
	$reconnect = defined($reconnect) ? $reconnect : 0;
	$hash->{DeviceName} = $hash->{DEF}; 

	if ($hash->{STATE} ne 'open') {
		# if we must reconnect, connection can reappered after 60 seconds 
		$retVal = DevIo_OpenDev($hash, $reconnect, 'HM485_LAN_Init');
	}

	return $retVal;
}
	
=head2
	Check if HM485d running.
	Start HM485d if no matchig pid exists
	
	Todo: Bulletproof Startr and restart
	      Maybe this can move to Servertools
	
	@param	hash    hash of device addressed
=cut
sub HM485_LAN_checkAndCreateHM485d($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $dev  = $hash->{DEF};

	my $HM485dBind   = AttrVal($name, 'HM485d_bind', 0);
	my $HM485dDevice = AttrVal($name, 'HM485d_device'   , undef);

	if ($HM485dBind && $HM485dDevice) {
		my (undef, $HM485dPort) = split(',', $hash->{DEF});
		
		my $HM485dSerialNumber = AttrVal($name, 'HM485d_serialNumber', SERIALNUMBER_DEF);
		my $HM485dDetatch      = AttrVal($name, 'HM485d_detatch',      undef);
		my $HM485dGpioTxenInit = AttrVal($name, 'HM485d_gpioTxenInit', undef);
		my $HM485dGpioTxenCmd0 = AttrVal($name, 'HM485d_gpioTxenCmd0', undef);
		my $HM485dGpioTxenCmd1 = AttrVal($name, 'HM485d_gpioTxenCmd1', undef);
		my $HM485dLogfile      = AttrVal($name, 'HM485d_logfile',      undef);
		my $HM485dLogVerbose   = AttrVal($name, 'HM485d_logVerbose',   undef);
	
		my $HM485dCommandLine = 'HM485d.pl';
		$HM485dCommandLine.= ($HM485dSerialNumber) ? ' --serialNumber ' . $HM485dSerialNumber : '';
		$HM485dCommandLine.= ($HM485dDevice)       ? ' --device '       . $HM485dDevice       : '';
		$HM485dCommandLine.= ($HM485dPort)         ? ' --localPort '    . $HM485dPort         : '';
		$HM485dCommandLine.= ($HM485dDetatch)      ? ' --daemon '       . $HM485dDetatch      : '';
		$HM485dCommandLine.= ($HM485dGpioTxenInit) ? ' --gpioTxenInit ' . $HM485dGpioTxenInit : '';
		$HM485dCommandLine.= ($HM485dGpioTxenCmd0) ? ' --gpioTxenCmd0 ' . $HM485dGpioTxenCmd0 : '';
		$HM485dCommandLine.= ($HM485dGpioTxenCmd1) ? ' --gpioTxenCmd1 ' . $HM485dGpioTxenCmd1 : '';
		$HM485dCommandLine.= ($HM485dLogfile)      ? ' --logfile '      . $HM485dLogfile      : '';
		$HM485dCommandLine.= ($HM485dLogVerbose)   ? ' --verbose '      . $HM485dLogVerbose   : '';
	
		$HM485dCommandLine = $attr{global}{modpath} . '/FHEM/lib/HM485/HM485d/' .
		                     $HM485dCommandLine;

		$hash->{HM485d_CommandLine} = $HM485dCommandLine;

		$hash->{HM485d_PID} = HM485_LAN_HM485dGetPid($hash, $HM485dCommandLine); 
		if ($hash->{HM485d_PID}) {
			HM485::Util::logger($name, 1,
				'HM485d already running with PID ' . $hash->{HM485d_PID}. '. We re use this process!'
			);

			InternalTimer(gettimeofday() + 0.1, 'HM485_LAN_openDev', $hash, 0);
			
		} else {
			# Start HM485d
			HM485_LAN_HM485dStart($hash);
		}

	} elsif ($HM485dBind && !$HM485dDevice) {
		my $msg = 'HM485d not started. Attr "HM485d_device" for ' . $name . ' is not set!';
		HM485::Util::logger($name, 1, $msg);
		$hash->{ERROR} = $msg;
	} else {

		DevIo_CloseDev($hash);
		HM485_LAN_openDev($hash);
	}
}

=head2
	Get the PID of a running HM485d depends on the commandline

	Todo: maybe the HM485d sould identifyed on its serial number only?	

	@param	hash      hash of device addressed
	@param	string    $HM485dCommandLine

	@return integer   PID of a running HM485d, else 0
=cut
sub HM485_LAN_HM485dGetPid($$) {
	my ($hash, $HM485dCommandLine) = @_;
	my $retVal = 0;
	
	my $ps = 'ps ao pid,args | grep "' . $HM485dCommandLine . '" | grep -v grep';
	my @result = `$ps`;
	foreach my $psResult (@result) {
		$psResult =~ s/[\n\r]//g;

		if ($psResult) {
			$psResult =~ /(^.*)\s.*perl.*/;
			$retVal = $1;
			last;
		}
	}
	
	return $retVal;
}

=head2
	Stop the HM485 process.

	@param	hash      hash of device addressed
	@return string
=cut
sub HM485_LAN_HM485dStop($) {
	my ($hash) = @_;
	
	my $name = $hash->{NAME};
	my $pid = $hash->{HM485d_PID} ? $hash->{HM485d_PID} : 0;

	my $msg;
	if ($pid > 0) {
		if(kill(0, $pid)) {
			DevIo_CloseDev($hash);
			$hash->{STATE} = 'closed';
	
			kill('TERM', $pid);
			if(!kill(0, $pid)) {
				$msg = 'HM485d with PID ' . $pid . ' was terminated sucessfully.';
				$hash->{HM485d_STATE} = 'stopped';
				delete($hash->{HM485d_PID});
			} else {
				$msg = 'Can\'t terminate HM485d with PID ' . $pid . '.';
			}
		} else {
			$msg = 'There ar no HM485d process with PID ' . $pid . '.';
			
		}
		
		HM485::Util::logger($name, 3, $msg);
	}
	
	return $msg;
}

=head2
	Stop the HM485 process.

	@param	hash      hash of device addressed
	@return string
=cut
sub HM485_LAN_HM485dStart($) {
	my ($hash) = @_;
	
	my $name = $hash->{NAME};
	my $msg;

	my $HM485dCommandLine = $hash->{HM485d_CommandLine};
	my $pid = HM485_LAN_HM485dGetPid($hash, $HM485dCommandLine);
	
	if(!$pid || ($pid && !kill(0, $pid))) {
		system($HM485dCommandLine . '&');
		$msg = 'Start HM485d with command line: ' . $HM485dCommandLine;
		$pid = HM485_LAN_HM485dGetPid($hash, $HM485dCommandLine);

		if ($pid) {
			$msg.= "\n" . 'HM485d was started with PID: ' . $pid;
			$hash->{HM485d_STATE} = 'started';
			$hash->{HM485d_PID} = HM485_LAN_HM485dGetPid($hash, $HM485dCommandLine);
			
			my $HM485dStartTimeout = int(AttrVal($name, 'HM485d_startTimeout', '2'));
			if ($HM485dStartTimeout) {
				HM485::Util::logger(
					$name, 3, 'Connect to HM485d delayed for ' . $HM485dStartTimeout . ' seconds'
				);
				$hash->{HM485dStartTimeout} = $HM485dStartTimeout;
			}

			$HM485dStartTimeout = $HM485dStartTimeout + 0.1;
			InternalTimer(gettimeofday() + $HM485dStartTimeout, 'HM485_LAN_openDev', $hash, 0);
			
		} else {
			$msg.= "\n" . 'HM485d Could nor start';
		}
	} else {
		$msg = 'HM485d with PID ' . $pid . ' already running.';		
	}
	
	foreach my $msgItem (split("\n", $msg)) {
		HM485::Util::logger($name, 3, $msgItem);
	}

	return $msg;
}


1;

=pod
=begin html

<a name="HM485_LAN"></a>
<h3>HM485_LAN</h3>
<ul>
	HM485_LAN FHEM module is the interface for controlling eQ-3 HomeMatic-Wired devices<br>
	The folowing hardware interfaces can used with this modul.
	<ul>
		<li>HomeMatic Wired RS485 LAN Gateway (HMW-LGW-O-DR-GS-EU)</li>
		<li>Ethernet to RS485 converter like WIZ108SR.<br>
			See http://forum.fhem.de/index.php?t=msg&th=14096&start=0&rid=42</li>
		<li>RS232/USB to RS485 converter like DIGITUS DA-70157</li>
	</ul>
	
	For HomeMatic Wired RS485 LAN Gateway, the module communicate with the interface.
	The HM485 protocol was built in the interface<br><br>
	
	For Ethernet to RS485 or RS232/USB to RS485 converter the module starts a 
	dedicated server process (HM485d.pl) The HM485d.pl is part of this module and
	assumes translation of the HM485 protokol to serial data.<br><br>
	<ul>
		<li>...</li>
		<li>...</li>
		<li>...</li>
	</ul>
</ul>

=end html
=cut
