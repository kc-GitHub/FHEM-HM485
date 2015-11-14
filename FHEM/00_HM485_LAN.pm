=head1
	00_HM485_LAN.pm Version 13.11.2015

=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013
	Refined by Thorsten Pferdekaemper
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
sub HM485_LAN_openDev($;$);
sub HM485_LAN_checkAndCreateHM485d($);
sub HM485_LAN_HM485dGetPid($$);
sub HM485_LAN_DispatchNack($$);

use constant {
	SERIALNUMBER_DEF   => 'SGW0123456',
	KEEPALIVE_TIMER    => 'keepAlive:',
	KEEPALIVECK_TIMER  => 'keepAliveCk:',
	KEEPALIVE_TIMEOUT  => 20, # CCU2 send keepalive each 20 seconds, Todo: check if we need to modify the timeout via attribute
	KEEPALIVE_MAXRETRY => 3,
	DISCOVERY_TIMEOUT  => 10,
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
		HM485::Util::Log3($hash, 1, $initResult);
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
		                     'HM485d_detach:0,1 HM485d_logVerbose:0,1,2,3,4,5 ' . 
		                     'HM485d_gpioTxenInit HM485d_gpioTxenCmd0 ' . 
		                     'HM485d_gpioTxenCmd1 '.
							 'autoReadConfig:atstartup,always';
		
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
			HM485::Util::Log3($hash, 1, 'HM485 device is none, commands will be echoed only');
		} else {
			# Make sure HM485_LAN_Connect starts after HM485_LAN_Define is ready 
			InternalTimer(gettimeofday(), 'HM485_LAN_ConnectOrStartHM485d', $hash, 0);
		}
				
	} else {
		HM485::Util::Log3($hash, 1, $ret);
	}

	$hash->{msgCounter} = 0;
	# $hash->{STATE} = '';

	$data{FWEXT}{test}{SCRIPT} = 'hm485.js?' . gettimeofday();

	return $ret;
}
=head2
	Implements ReadyFn function.

	@param	hash    hash of device addressed
	@return mixed   return value of the HM485_LAN_Init function
=cut
sub HM485_LAN_Ready($) {
	my ($hash) = @_;

	HM485::Util::Log3($hash, 5, 'HM485_LAN_Ready called');
	
	if ( ! $hash->{STATE} eq "disconnected" ) {
		return undef;  # nothing to do in this case
	};
	# It seems we are disconnected (not closed intentionally)
	# If we handle the Daemon ourselves, then check whether it is still running
	# and try to restart, if not
	my $name = $hash->{NAME};
	my $HM485dBind   = AttrVal($name, 'HM485d_bind', 0);
	my $HM485dDevice = AttrVal($name, 'HM485d_device', undef);
	if ($HM485dBind && $HM485dDevice) {
		my $pid = HM485_LAN_HM485dGetPid($hash, $hash->{HM485d_CommandLine});
		if(!($pid && kill(0, $pid))) {
			# seems it is not really running, try to start it
			HM485_LAN_HM485dStart($hash);
			return undef;  # in this case, an immediate openDev does not make sense
		}		
	};	
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
	
	if (!AttrVal($name, 'HM485d_detach', 0)) {
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

	if (!AttrVal($name, 'HM485d_detach', 0)) {
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
		RemoveInternalTimer(KEEPALIVECK_TIMER . $name);
		RemoveInternalTimer(KEEPALIVE_TIMER   . $name);
		
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
						HM485_LAN_parseIncommingCommand($hash, $message);
					}
				}
			}
	
			InternalTimer(
				gettimeofday() + KEEPALIVE_TIMEOUT, 'HM485_LAN_KeepAlive', KEEPALIVE_TIMER . $name, 1
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

	HM485::Util::Log3($hash, 3, 'Lan Device Information');
	HM485::Util::Log3($hash, 3, 'Protocol-Version: ' . $hash->{ProtokolVersion});
	HM485::Util::Log3($hash, 3, 'Interface-Type: '   . $interfaceType);
	HM485::Util::Log3($hash, 3, 'Firmware-Version: ' . $version);
	HM485::Util::Log3($hash, 3, 'Serial-Number: '    . $serialNumber);

	# initialize keepalive flags
	$hash->{keepalive}{ok}    = 1;
	$hash->{keepalive}{retry} = 0;

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

	HM485::Util::Log3($hash, 5, 'HM485_LAN_Write TX: ' . $msgId );
	
	if ($cmd == HM485::CMD_SEND || $cmd == HM485::CMD_DISCOVERY ||
		$cmd == HM485::CMD_KEEPALIVE || HM485::CMD_INITIALIZE) {
			
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

			$sendDataLog = HM485::Util::logger($name, 4, 'TX: (' . $msgId . ')', \%RD, 1);
			$sendData = pack('H*',
				sprintf(
					'%02X%02X%s%s%s%s%s', $msgId, $cmd, 'C8', $target, $ctrl, $source, $data
				)
			);

		} elsif ($cmd == HM485::CMD_DISCOVERY) {
			$sendData = pack('H*',sprintf('%02X%02X00FF', $msgId, $cmd));

		} elsif ($cmd == HM485::CMD_KEEPALIVE) {
			$sendData = pack('H*',sprintf('%02X%02X', $msgId, $cmd));

		} elsif ($cmd == HM485::CMD_INITIALIZE) {
			my $txtMsgId = unpack('H4', sprintf('%02X', $msgId));
			$sendData = pack('H*',sprintf('%02X%s%s', $cmd, $txtMsgId, '2C303030300D0A'));
			HM485::Util::Log3($hash, 3, 'Initialize the interface');
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
        HM485::Util::Log3($hash,  5, 'HM485_LAN_SendQueueNextItem: QID: '.$currentQueueId );
		$hash->{currentQueueId} = $currentQueueId;

		my $sendData = $hash->{sendQueue}{$currentQueueId}{data};
		
		DevIo_SimpleWrite($hash, $sendData, 0);
		if ($hash->{sendQueue}{$currentQueueId}{dataLog}) {
			HM485::Util::Log3($hash, 4, $hash->{sendQueue}{$currentQueueId}{dataLog});
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
 	    HM485::Util::Log3($hash, 5, 'HM485_LAN_CheckResendQueueItems: QID: '.$currentQueueId );
		if (exists($hash->{sendQueue}{$currentQueueId})) {
		    HM485::Util::Log3($hash, 5, 'HM485_LAN_CheckResendQueueItems: DispatchNack' );
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

	@param	undef
	@param	string  name of device
	@param	string  attr name
	@param	string  attr value

	@return undef | string    if attr value was wrong
=cut
sub HM485_LAN_Attr (@) {
	my (undef, $name, $attr, $val) =  @_;
	my $hash = $defs{$name};

	if ($attr eq 'hmwId') {
		my $hexVal = (defined($val)) ? hex($val) : 0;
		if (!defined($val) || $val !~ m/^[A-F0-9]{8}$/i || $hexVal > 255 || $hexVal < 1) {
			return 'Wrong hmwId defined. hmwId must be 8 digit hex address within 00000001 and 000000FF';
		};
		foreach my $d (keys %defs) {
			next if($d eq $name);
			if($defs{$d}{TYPE} eq 'HM485_LAN') {
				if(AttrVal($d, 'hmwId', '00000001') eq $val) {
						return 'hmwId ' . $val . ' is already used, use a different one.';
				}
			}
		}
		$hash->{hmwId} = $val;
	}
	return undef;
}

=head2
	Start the discovery command

	@param	hash    hash of device addressed
=cut
sub HM485_LAN_discoveryStart($) {
	my ($hash) =  @_;

	$hash->{discoveryRunning} = 1;

	# Start timer for cancel discovery if discovery fails
	HM485_LAN_setDiscoveryCancelTimer($hash);

	HM485_LAN_setBroadcastSleepMode($hash, 1);
	InternalTimer(gettimeofday(), 'HM485_LAN_doDiscovery', $hash, 0);
}

sub HM485_LAN_setDiscoveryCancelTimer($) {
	my ($hash) =  @_;
	my $name = $hash->{NAME};

	RemoveInternalTimer('discoveryCheckRunning:' . $name);
	InternalTimer(
		gettimeofday() + DISCOVERY_TIMEOUT ,
		'HM485_LAN_cancelDiscovery',
		'discoveryCheckRunning:' . $name,
		1
	);
}

sub HM485_LAN_cancelDiscovery($) {
	my($param) = @_;

	my(undef,$name) = split(':', $param);
	my $hash = $defs{$name};

	RemoveInternalTimer('discoveryCheckRunning:' . $name);
	HM485::Util::Log3($hash, 2, 'Discovery - canceled. No results found within ' . DISCOVERY_TIMEOUT . ' seconds!');
	HM485_LAN_setBroadcastSleepMode($hash, 0);
	$hash->{discoveryRunning} = 0;	
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
	my ($hash) =  @_;
	my $name = $hash->{NAME};

	RemoveInternalTimer('discoveryCheckRunning:' . $name);
	HM485_LAN_setBroadcastSleepMode($hash, 0);

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
				HM485::Util::Log3($hash, 4, $l . ' (RX: ' . $m . ')');
	 			HM485::Util::Log3($hash, 4, 'Dispatch: ' . $discoverdAddress);
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

	HM485::Util::Log3($hash, 3, 'connected to device ' . $dev);
	# $hash->{STATE} = 'open';
	
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
	
	HM485::Util::Log3($hash, 5, 'HM485_LAN_parseIncommingCommand: MsgId: '.$msgId.' Cmd: '.$msgCmd);
	
	if ($msgCmd == HM485::CMD_DISCOVERY_END) {
		my $foundDevices = hex($msgData);
		HM485::Util::Log3($hash, 4, 'Do action after discovery Found Devices: ' . $foundDevices);
		InternalTimer(gettimeofday() + 0, 'HM485_LAN_discoveryEnd', $hash, 0);

	} elsif ($msgCmd == HM485::CMD_DISCOVERY_RESULT) {
		HM485_LAN_setDiscoveryCancelTimer($hash);
		
		HM485::Util::Log3($hash, 3, 'Discovery - found device: ' . $msgData);
		$hash->{discoveryFound}{$msgData} = 1;

	} elsif ($msgCmd == HM485::CMD_ALIVE) {
		my $aliveStatus = substr($msgData, 0, 2);
		HM485::Util::Log3($hash, 5, 'HM485_LAN_parseIncommingCommand: Alive: (' . $msgId . ') ' . $msgData.' AliveStatus: '.$aliveStatus);
		if ($aliveStatus == '00') {
			# we got a response from keepalive
			$hash->{keepalive}{ok}    = 1;
			$hash->{keepalive}{retry} = 0;
		} else {
			HM485_LAN_DispatchNack($hash, $currentQueueId);
		}

	} elsif ($msgCmd == HM485::CMD_RESPONSE) {
		$canDispatch = 1;
		$hash->{Last_Sent_RAW_CMD_State} = 'ACK';
		HM485::Util::Log3($hash, 5, 'HM485_LAN_parseIncommingCommand: Response: (' . $msgId . ') ' . substr($msgData, 2));

	} elsif ($msgCmd == HM485::CMD_EVENT) {
		$canDispatch = 1;

		# Debug
		my %RD = (
			target  => pack('H*', substr($msgData, 0,8)),
			cb      => hex(substr($msgData, 8,2)),
			sender  => pack('H*', substr($msgData, 10,8)),
			datalen => $msgLen,
			data    => pack('H*', substr($msgData, 18)),
		);
		HM485::Util::Log3($hash, 4, 'Event:'. \%RD);
	}		

	if ($canDispatch && length($message) > 3) {
		Dispatch($hash, $message, '');
	}

	# we should not confuse events with answers
	# the server knows what is what...
	# for Nacks, the queue has already been removed
	# if ($currentQueueId) {
	if ($currentQueueId && defined($hash->{sendQueue}{$currentQueueId}{msgId}) 
	       && $hash->{sendQueue}{$currentQueueId}{msgId} == $msgId
		   && $msgCmd != HM485::CMD_ALIVE) {  # probably not needed, but no harm either
	    HM485::Util::Log3($hash, 5, 'HM485_LAN_parseIncommingCommand: Removing Queue '.$currentQueueId);
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
		HM485_LAN_openDev($hash);		
	} else {
		HM485_LAN_checkAndCreateHM485d($hash);
	}
}

=head2
	Keepalive check of the interface  
	
	@param	string    name of keepalive timer
=cut
sub HM485_LAN_KeepAlive($) {
	my($param) = @_;

	my(undef,$name) = split(':',$param);
	my $hash = $defs{$name};

	my $msgCounter = $hash->{msgCounter};
	
	$hash->{keepalive}{ok} = 1;

	if ($hash->{FD}) {
		HM485_LAN_Write($hash, HM485::CMD_KEEPALIVE);

		# Remove timer to avoid duplicates
		RemoveInternalTimer(KEEPALIVE_TIMER . $name);

		# Timeout where foreign device must response keepalive commands
		my $responseTime = AttrVal($name, 'respTime', 1);

		# start timer to check keepalive response
		InternalTimer(
			gettimeofday() + $responseTime, 'HM485_LAN_KeepAliveCheck', KEEPALIVECK_TIMER . $name, 1
		);

		# start timeout for next keepalive check
		InternalTimer(
			gettimeofday() + KEEPALIVE_TIMEOUT ,'HM485_LAN_KeepAlive', KEEPALIVE_TIMER . $name, 1
		);
	}
}

=head2
	Check keepalive response.
	If keepalive response is missing, retry keepalive up to KEEPALIVE_MAXRETRY count. 
	
	@param	string    name of keepalive timer
=cut
sub HM485_LAN_KeepAliveCheck($) {
	my($param) = @_;

	my(undef,$name) = split(':', $param);
	my $hash = $defs{$name};

	if (!$hash->{keepalive}{ok}) {
		# we got no keepalive answer 
		if ($hash->{keepalive}{retry} >= KEEPALIVE_MAXRETRY) {
			# keepalive retry count reached. Disonnect.
			DevIo_Disconnected($hash);
		} else {
			$hash->{keepalive}{retry} ++;

			# Remove timer to avoid duplicates
			RemoveInternalTimer(KEEPALIVE_TIMER . $name);

			# start timeout for repeated keepalive check
			HM485_LAN_KeepAlive(KEEPALIVE_TIMER . $name);
		}
	} else {
		$hash->{keepalive}{retry} = 0;
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

	HM485::Util::Log3($hash, 5, 'HM485_LAN_DispatchNack: Start');
	
	$hash->{Last_Sent_RAW_CMD_State} = 'NACK';

	if ($currentQueueId) {
		my $msgId = $hash->{sendQueue}{$currentQueueId}{msgId};
		if ($msgId) {
			my $hmwId = $hash->{sendQueue}{$currentQueueId}{hmwId};
			if ($hmwId) {
				if ($modules{HM485}{defptr}{$hmwId}) {
					# We use CMD_ALIVE and second byte for signalize NACK messages internaly
					# The last 4 bytes identify the HMW-ID which was not acked
					my $message = pack('H*',
						sprintf(
							'%02X%02X%02X%02X%02X%s',
							HM485::FRAME_START_LONG, 3, $msgId, HM485::CMD_ALIVE, 1, $hmwId
						)
					);
					HM485::Util::Log3($hash, 5, 'HM485_LAN_DispatchNack: Message: '.$message);
					Dispatch($hash, $message, '');
				} else {
					HM485::Util::Log3($hash, 3, 'NACK: (' . $msgId . ') ' . $hmwId);
				}
			}
		}
		HM485_LAN_DeleteCurrentItemFromQueue($hash, $currentQueueId);
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

	if ($hash->{STATE} ne 'opened') {
		# if we must reconnect, connection can reappear after 60 seconds 
		$retVal = DevIo_OpenDev($hash, $reconnect, 'HM485_LAN_Init');
	}

	return $retVal;
}
	
	
# update commandline internal
sub HM485_LAN_updateHM485dCommandLine($) {
	my ($hash) = @_;
	
	my $name = $hash->{NAME};
	my $HM485dBind   = AttrVal($name, 'HM485d_bind', 0);
	my $HM485dDevice = AttrVal($name, 'HM485d_device'   , undef);

	if (!$HM485dBind || !$HM485dDevice) {
		delete $hash->{HM485d_CommandLine};
		return;
	};	
	my (undef, $HM485dPort) = split(':', $hash->{DEF});
	my $HM485dSerialNumber = AttrVal($name, 'HM485d_serialNumber', SERIALNUMBER_DEF);
	my $HM485dDetach      = AttrVal($name, 'HM485d_detach',      undef);
	my $HM485dGpioTxenInit = AttrVal($name, 'HM485d_gpioTxenInit', undef);
	my $HM485dGpioTxenCmd0 = AttrVal($name, 'HM485d_gpioTxenCmd0', undef);
	my $HM485dGpioTxenCmd1 = AttrVal($name, 'HM485d_gpioTxenCmd1', undef);
	my $HM485dLogfile      = AttrVal($name, 'HM485d_logfile',      undef);
	my $HM485dLogVerbose   = AttrVal($name, 'HM485d_logVerbose',   undef);
	
	my $HM485dCommandLine = 'HM485d.pl';
	$HM485dCommandLine.= ($HM485dSerialNumber) ? ' --serialNumber ' . $HM485dSerialNumber : '';
	$HM485dCommandLine.= ($HM485dDevice)       ? ' --device '       . $HM485dDevice       : '';
	$HM485dCommandLine.= ($HM485dPort)         ? ' --localPort '    . $HM485dPort         : '';
	$HM485dCommandLine.= ($HM485dDetach)       ? ' --daemon '       . $HM485dDetach       : '';
	$HM485dCommandLine.= ($HM485dGpioTxenInit) ? ' --gpioTxenInit ' . $HM485dGpioTxenInit : '';
	$HM485dCommandLine.= ($HM485dGpioTxenCmd0) ? ' --gpioTxenCmd0 ' . $HM485dGpioTxenCmd0 : '';
	$HM485dCommandLine.= ($HM485dGpioTxenCmd1) ? ' --gpioTxenCmd1 ' . $HM485dGpioTxenCmd1 : '';
	$HM485dCommandLine.= ($HM485dLogfile)      ? ' --logfile '      . $HM485dLogfile      : '';
	$HM485dCommandLine.= ($HM485dLogVerbose)   ? ' --verbose '      . $HM485dLogVerbose   : '';
	
	$HM485dCommandLine = $attr{global}{modpath} . '/FHEM/lib/HM485/HM485d/' .$HM485dCommandLine;
	$hash->{HM485d_CommandLine} = $HM485dCommandLine;
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
	my $HM485dBind   = AttrVal($name, 'HM485d_bind', 0);
	my $HM485dDevice = AttrVal($name, 'HM485d_device'   , undef);

	if ($HM485dBind && $HM485dDevice) {
		HM485_LAN_HM485dStart($hash);	
	} elsif ($HM485dBind && !$HM485dDevice) {
		my $msg = 'HM485d not started. Attr "HM485d_device" for ' . $name . ' is not set!';
		HM485::Util::Log3($hash, 1, $msg);
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
	
	my $ps = 'ps axwwo pid,args | grep "' . $HM485dCommandLine . '" | grep -v grep';
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
		# Is there a process with the pid?
		if(!kill(0, $pid)) {
			return 'There is no HM485d process with PID ' . $pid . '.';	
		};	
		DevIo_CloseDev($hash);
		$hash->{STATE} = 'closed';
		if(!kill('TERM', $pid)) {
			return 'Can\'t terminate HM485d with PID ' . $pid . '.';
		};	
		$msg = 'HM485d with PID ' . $pid . ' was terminated.';
		$hash->{HM485d_STATE} = 'stopped';
		delete($hash->{HM485d_PID});
		HM485::Util::Log3($hash, 3, $msg);
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
	
	delete $hash->{HM485d_PID};
	
	HM485_LAN_updateHM485dCommandLine($hash);
	my $pid = HM485_LAN_HM485dGetPid($hash, $hash->{HM485d_CommandLine});
	# Is a process with this command line already running? If yes then use this.
	if($pid && kill(0, $pid)) {
		HM485::Util::Log3($hash, 1, 'HM485d already running with PID ' . $pid. '. We are using this process.');
		$hash->{HM485d_PID} = $pid;
		InternalTimer(gettimeofday() + 0.1, 'HM485_LAN_openDev', $hash, 0);		
		return 'HM485d already running. (Re)Connected to PID '.$pid;
	};		
	#...otherwise try to start HM485d
	system($hash->{HM485d_CommandLine} . '&');
	HM485::Util::Log3($hash, 3, 'Start HM485d with command line: ' . $hash->{HM485d_CommandLine});
	$pid = HM485_LAN_HM485dGetPid($hash, $hash->{HM485d_CommandLine});
	if(!$pid) {
		return 'HM485d could not be started';
	}
	$hash->{HM485d_PID} = $pid;
	HM485::Util::Log3($hash, 3, 'HM485d was started with PID: ' . $pid);
	$hash->{HM485d_STATE} = 'started';
	my $HM485dStartTimeout = int(AttrVal($hash->{NAME}, 'HM485d_startTimeout', '5'));
	if ($HM485dStartTimeout) {
		HM485::Util::Log3($hash, 3, 'Connect to HM485d delayed for ' . $HM485dStartTimeout . ' seconds');
		$hash->{HM485dStartTimeout} = $HM485dStartTimeout;
	}
	$HM485dStartTimeout = $HM485dStartTimeout + 0.1;
	InternalTimer(gettimeofday() + $HM485dStartTimeout, 'HM485_LAN_openDev', $hash, 0);		
	return 'HM485d started with PID '.$pid;
}


1;

=pod
=begin html

<a name="HM485_LAN"></a>
<h3>HM485_LAN</h3>
<ul>
	HM485_LAN is the interface for HomeMatic-Wired (HMW) devices<br>
	If you want to connect HMW devices to FHEM, at least one HM485_LAN is needed.
	The following hardware interfaces can be used with this module.
	<ul>
		<li>HomeMatic Wired RS485 LAN Gateway (HMW-LGW-O-DR-GS-EU)</li>
		<li>Ethernet to RS485 converter like <a href="http://forum.fhem.de/index.php/topic,14096.msg88557.html#msg88557">WIZ108SR</a>.</li>
		<li>RS232/USB to RS485 converter like DIGITUS DA-70157</li>
	</ul>
	For the HomeMatic Wired RS485 LAN Gateway, HM485_LAN communicates directly with the gateway.<br>
	For the Ethernet to RS485 or RS232/USB to RS485 converter, module HM485_LAN automatically starts a server process (HM485d.pl), which emulates the Gateway.<br>
    <br><br>
	<b>Minimum configuration examples</b>
	<ul>
		<li>HomeMatic Wired RS485 LAN Gateway<br>
			<code>
			define hm485 HM485_LAN 192.168.178.164:1000
			</code>
		</li>
		<li>Ethernet to RS485 converter<br>
			<code>
			define hm485 HM485_LAN localhost:2000
			attr hm485 HM485d_bind 1
			attr hm485 HM485d_device 192.168.178.165:5000
			</code>
		</li>
		<li>USB to RS485 converter<br>
			<code>
			define hm485 HM485_LAN localhost:2000
			attr hm485 HM485d_bind 1
			attr hm485 HM485d_device /dev/ttyUSB0
			</code>
		</li>
	</ul>
	
    <b>Define</b>
    <ul>
      <code>define &lt;name&gt; HM485_LAN &lt;hostname&gt;:&lt;port&gt;</code>
	  <br><br>
	  <ul>
	  <li>When using the HMW RS485 LAN Gateway, then hostname is the address of the gateway itself. As port, usually 1000 or 5000 is used. 
	  Example: <code>define hm485 HM485_LAN 192.168.178.164:5000</code>
	  </li> 
	  <li>When using anything else, then hostname is the address of the machine the HM485d process runs on. "port" is the port the HM485d process listens at. Usually, the HM485d process is controlled by FHEM and runs on the same machine as FHEM. This means that something like this usually makes sense: 
	  <code>define hm485 HM485_LAN localhost:2000</code>
	  </li>
	  </ul>
	</ul>
	
	<b>Set</b>
	<ul>
	<li><code>set &lt;name&gt; HM485d status|stop|start|restart</code>
	</li>
	<li><code>set &lt;name&gt; RAW &lt;target&gt; &lt;control&gt; &lt;central_address&gt; &lt;data&gt;</code>
	</li>
	<li><code>set &lt;name&gt; broadcastSleepMode off</code>
	</li>
	<li><code>set &lt;name&gt; discovery start</code>
	</li>
	</ul>

	<b>Readings</b>
	<ul>
	<li>state
	</li>
	</ul>
		
	<b>Attributes</b>
	<ul>
	<li>hmwId
			hmwId Hier muss die HMW-ID angegeben werden. Standardmäßig wird die 00000001 benutzt.
	</li>
	<li>autoReadConfig:atstartup,always</li>
	<li>do_not_notify:0,1
	## do_not_notify FileLog/notify/inform Benachrichtigung für das Gerät ist abgeschaltet.
	</li>
	<li>HM485d_bind:0,1<br>
		Set HM485d_bind to 1 to allow FHEM to handle HM485d. This means that you are then able to start, stop and restart the HM485d process. FHEM then also starts HM485d automatically and restarts it if it crashes. If you are using the HomeMatic Wired RS485 LAN Gateway, you should not set HM485d_bind. Otherwise, it most likely makes sense to set HM485d_bind to 1.  		
	</li>
	The following attributes only make sense when FHEM controls the HM485d process (HM485d_bind = 1). You can always set these attributes, but they are only used when FHEM starts the HM485d process.
	<li>HM485d_startTimeout<br>
		Especially on slow machines (e.g. Raspberry Pi 1), it takes a few seconds until the HM485d process accepts a connection. By default, FHEM waits 5 seconds after starting the HM485d before attempting to connect to it. You can change this time using attribute HM485d_startTimeout. In case FHEM is not able to connect at the first attempt, it usually takes about 60 seconds until the next try. I.e. if HM485d_startTimeout is too small, you might only see the device state as "opened" 60 seconds later. 
	</li>
	<li>HM485d_device<br>
		This is the device the HM485d process is supposed to connect to, i.e. either an ip address or the file name of a serial device, like USB. See above for examples.
		This attribute must be set when HM485d_bind is 1. Otherwise, FHEM cannot start the HN485d process.
	</li>
	<li>HM485d_serialNumber<br>
		This is the serial number which HM485d process uses as an identification with FHEM. It is mainly used to differentiate between multiple HM485d processes. This makes sense when you have more than one RS485 converters. Otherwise, you don't need to set it. (The default serial number is SGW0123456.)
	<li>HM485d_logfile<br>
		The HM485d process can write an own log file with &lt;HM485d_logfile&gt; as filename.
	</li> 
	<li>HM485d_detach:0,1
	 HM485d_detatch Wenn der hm485d mit FHEM zusammen gestartet wird (siehe HM485d_bind) so kann der Prozess hier von FHEM entkoppelt werden. Der Prozess wird dann auch nicht zusammen mit FHEM beendet.
	</li>
	<li>HM485d_logVerbose:0,1,2,3,4,5
	 HM485d_logVerbose Der Loglevel vom hm485d.
	</li>
	Die folgenden drei Attribute können verwendet werden, wenn der hm485d über einen einfachen UART ohne Flusskontrolle z.B. über den UART des Raspberry Pi, an einen RS485 Tranceiver angeschlossen wird. Dafür müssen ggf. GPIO-Pins zur Steuerung des RS485 Tranceivers (Senden/Empfangen) definiert werden: 
	<li>HM485d_gpioTxenInit
	 HM485d_gpioTxenInit Shell-Befehl zum initialisieren des benutzten GPIO-Pins für die Sendekontrolle
	</li>
	<li>HM485d_gpioTxenCmd0
	 HM485d_gpioTxenCmd0 Shell-Befehl um den Sende-GPIO-Pin zurück zu setzen
	</li>
	<li>HM485d_gpioTxenCmd1
	 HM485d_gpioTxenCmd1 Shell-Befehl um den Sende-GPIO-Pin zu setzen
	</li>
	</ul>
</ul>

=end html
=cut
