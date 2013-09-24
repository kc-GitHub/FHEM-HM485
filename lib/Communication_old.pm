=head1
	Communication.pm

=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 2012 - 2013
	$Id$

=head1 DESCRIPTION
	Communication contans the communication layer for HS485 Protocol for Hmomematic

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
=cut

package FHEM::HM485::Communication;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw(usleep);

use constant {
	FRAME_START_SHORT		=> 0xFE,
	FRAME_START_LONG		=> 0xFD,
	ESCAPE_CHAR				=> 0xFC,

	MAX_SEND_RETRY			=> 3,
	SEND_RETRY_TIMEOUT		=> 100,		# 100ms	
	DISCOVERY_TRIES			=> 3,
	DISCOVERY_TIMEOUT		=> 25,		# 15ms

	STATE_IDLE				=> 0x00,
	STATE_TRANSMITTING		=> 0x01,
	STATE_SEND_ACK			=> 0x02,
	STATE_WAIT_ACK			=> 0x03,
	STATE_ACKNOWLEDGED		=> 0x04,
	STATE_CHANNEL_BUSY		=> 0x05,
	STATE_DISCOVERY			=> 0x06,
	STATE_DISCOVERY_WAIT	=> 0x07,
	
	CMD_SEND				=> 0x00,
	CMD_DISCOVERY			=> 0x01,
	CMD_RESPONSE			=> 0x80,
	CMD_ERROR				=> 0x81,
	CMD_EVENT				=> 0x82,
	CMD_DISCOVERY_RESULT	=> 0x83,
	CMD_DISCOVERY_END		=> 0x84,

	MIN_BUSY_TIME_MS		=> 5,
	WORST_CASE_BUSY_TIME_MS	=> 100		# 100ms
};

###############################################################################
# Define prototypes
###############################################################################

sub sendRawQueue($$$$$);		# ==> most always DONE
sub sendQueueNextItem(@);		# ==> most always DONE
sub sendFrame($$$$$;$);			# ==> DONE
sub bufferFrameByte($$;$);		# ==> DONE
sub setGpio ($$);				# ==> DONE
sub sendQueueFinishItem($);		# ==> DONE
sub sendQueueCheckItems($);		# ==> DONE

sub readFrame($$);				# ==> DONE
sub parseFrame($);
sub sendAck($$$$);				# ==> DONE
sub killSendingChild($);		# ==> most always DONE

sub cmdDiscovery($);			# ==> DONE
sub startDiscovery($);			# ==> DONE
sub readDiscoveryResult($);		# ==> DONE
sub endDiscovery($);			# ==> DONE



###############################################################################
# Sending frame related functions
###############################################################################

=head2 sendRawQueue
	Title:		sendRawQueue
	Function:	Send out raw HM-Wired frame
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => string:	$targetAddr	8 hex chars
				-argument1 => int:		$ctrl		ctrl byte
				-argument1 => string:	$senderAddr	8 hex chars
				-argument1 => string:	$data		n hex chars
=cut
sub sendRawQueue($$$$$) {
	my ($hash, $targetAddr, $ctrl, $senderAddr, $data) = @_;
		
	# Todo: for check frame must acked?
#	my $queueId = sprintf('%05d', scalar(keys (%{$hash->{sendQueue}})) );

	my @queueList = (sort keys %{$hash->{sendQueue}});
#	print Dumper(@queueList);
	my $queueId = pop (@queueList);
	$queueId = (defined ($queueId)) ? sprintf('%05d', ($queueId + 1)) : '00000';
	
#	main::Log(1, '$queueId: ' . $queueId);
	
	$hash->{sendQueue}{$queueId}{TARGET}	= $targetAddr;
	$hash->{sendQueue}{$queueId}{CTRL}		= $ctrl;
	$hash->{sendQueue}{$queueId}{SENDER}	= $senderAddr;
	$hash->{sendQueue}{$queueId}{DATA}		= $data;
	$hash->{sendQueue}{$queueId}{QUEUE_ID}	= $queueId;

	if (uc( unpack ('H*', $targetAddr)) eq 'FFFFFFFF') {
		$hash->{sendQueue}{$queueId}{STATE}	= STATE_IDLE;
	} else {
		$hash->{sendQueue}{$queueId}{STATE}	= STATE_WAIT_ACK;
	}
	
	if (!$hash->{queueRunning}) {
#main::Log(1, 'startqueue');	
		
		$hash->{queueRunning} = 1;
		sendQueueCheckItems($hash);
	}
}

=head2 sendQueueNextItem
	Title:		sendQueueNextItem
	Function:	Sendout the next queued HM485 message.
				Try send up to n times (n=MAX_SEND_RETRY)
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
=cut
sub sendQueueNextItem(@) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	# TODOs:	line watching: if line free to send?
	my $queueId = (sort keys %{$hash->{sendQueue}})[0];
		
	# Todo check wait for 10ms
	usleep(10000);
#main::Log(1, 'nextqueue');	
	my $ackState = 0;
	my $sendRetry = 1;
	for ($sendRetry = 1; $sendRetry <= (MAX_SEND_RETRY + 1); $sendRetry++){
		if ($sendRetry <= MAX_SEND_RETRY) {
			sendFrame(
				$hash,
				$hash->{sendQueue}{$queueId}{TARGET},
				$hash->{sendQueue}{$queueId}{CTRL},
				$hash->{sendQueue}{$queueId}{SENDER},
				$hash->{sendQueue}{$queueId}{DATA},
				$queueId . ':' . $sendRetry
			);
			
			# we wait only for ack if STATE = STATE_WAIT_ACK
			if ($hash->{sendQueue}{$queueId}{STATE}	== STATE_WAIT_ACK) {
				# wait, so the receiving process can read ack and terminate this child
				usleep(SEND_RETRY_TIMEOUT * 1000);
			} else {
				$ackState = STATE_IDLE;
				last;
			}
		}
	}
	
	my $retVal = $name . '|' . $queueId;
	if ($sendRetry > MAX_SEND_RETRY) {
		$retVal .= '|1';
	}

	return $retVal;
}

=head2 sendFrame
	Title:		sendFrame
	Function:	Collect Send out a HM485 frame
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => string:	$targetAddr	string of 4 bytes
				-argument1 => int:		$ctrl		ctrl byte
				-argument1 => string:	$senderAddr	string of 4 bytes
				-argument1 => string:	$data		string of n bytes
				-argument1 => int:		$sendId
				-argument1 => int:		$sendCount (optional)
=cut
sub sendFrame($$$$$;$) {
	my ($hash, $targetAddr, $ctrl, $senderAddr, $data, $sendCount) = @_;

	my $dataSend		= undef;
	my $name			= $hash->{NAME};

	my %logData;
	my $sendByte		= undef;

	my $crc16Register	= 0xFFFF;

	my $start	= FRAME_START_LONG;

	bufferFrameByte($hash, $start, 1);											# startbyte
	$logData{start} = $start;
	$crc16Register = FHEM::HM485::Util::crc16Shift(
		$start , $crc16Register
	);

	for (my $i = 0; $i < length($targetAddr); $i++) {							# target address
		$sendByte = ord(substr($targetAddr, $i, 1));
		$logData{target}.= bufferFrameByte($hash, $sendByte, 0);
		$crc16Register = FHEM::HM485::Util::crc16Shift(
			$sendByte , $crc16Register
		);
	}

	bufferFrameByte($hash, $ctrl, 0);											# controll byte
	$logData{cb} = $ctrl;
	$crc16Register = FHEM::HM485::Util::crc16Shift(
		$ctrl , $crc16Register
	);

	if (!FHEM::HM485::Util::ctrlIsDiscovery($ctrl) &&
		 FHEM::HM485::Util::ctrlHasSender($ctrl)) {								# check if message has sender

		for (my $i = 0; $i < length($senderAddr); $i++) 	{					# sender address
			$sendByte = ord(substr($senderAddr, $i, 1));
			$logData{sender}.= bufferFrameByte($hash, $sendByte, 0);
			$crc16Register = FHEM::HM485::Util::crc16Shift(
				$sendByte , $crc16Register
			);
		}
	}

	$data = defined($data) ? $data : '';
	
	# TODO: Check max dataLength (FB=251)
	my $dataLenght = length($data) + 2;
	bufferFrameByte($hash, $dataLenght, 0);										# data length
	$logData{dataLen} = $dataLenght;
	$crc16Register = FHEM::HM485::Util::crc16Shift(
		$dataLenght , $crc16Register
	);

	for (my $i = 0; $i < $dataLenght-2; $i++) {									# data
		$sendByte = ord(substr($data, $i, 1));
		$logData{data}.= bufferFrameByte($hash, $sendByte, 0);
		$crc16Register = FHEM::HM485::Util::crc16Shift(
			$sendByte , $crc16Register
		);
	}
	
	$crc16Register = FHEM::HM485::Util::crc16Shift(0 , $crc16Register);
	$crc16Register = FHEM::HM485::Util::crc16Shift(0 , $crc16Register);

	$logData{data}.=bufferFrameByte($hash, (($crc16Register >> 8) & 0xFF), 0);	# first byte of crc
	$logData{data}.=bufferFrameByte($hash, ($crc16Register & 0xFF), 0 );		# second byte of crc
	$logData{crc16Register} = $crc16Register;

	if (defined($hash->{FRAME_SEND_BUFFER})) {
		# set gpio pin for RS485 TX enable if necesarry
		setGpio($hash, 1);

		# send out buffer to IO device
		main::DevIo_SimpleWrite($hash, $hash->{FRAME_SEND_BUFFER}, 0);
		
		# reset gpio pin for RS485 TX enable if necesarry
		setGpio($hash, 0);
		
	}
	$hash->{FRAME_SEND_BUFFER} = '';
	
	$sendCount = (defined($sendCount)) ? '(' . $sendCount . ')' : '';
	FHEM::HM485::Util::logger(3, $name, 'TX' . $sendCount . ':', \%logData);
}

=head2 bufferFrameByte
	Title:		bufferFrameByte
	Function:	Bufer a frame byte to for later sending
				Bevore buffering check byte for spechial chars. Spechial chars was escaped bevore buffering
	Returns:	string
	Args:		named arguments:
				-argument1 => hash:	$hash			hash of device
				-argument1 => int:	$byte			byte to buffer
				-argument1 => int:	$noEscapeCheck	set to 1 to suppress escape check for sending byte
=cut
sub bufferFrameByte($$;$) {
	my ($hash, $byte, $noEscapeCheck) = @_;
	my $byteLog = '';

	$hash->{FRAME_SEND_BUFFER} = '' if (!defined($hash->{FRAME_SEND_BUFFER}));
	
	$noEscapeCheck = defined($noEscapeCheck) ? $noEscapeCheck : 0;
	if (!$noEscapeCheck) {
		if ($byte == FRAME_START_LONG || $byte == FRAME_START_SHORT || $byte == ESCAPE_CHAR) {
			$hash->{FRAME_SEND_BUFFER}.= chr(ESCAPE_CHAR);
			$byteLog = chr(ESCAPE_CHAR);
			$byte = $byte & 0x7F;
		}
	}
	
	$hash->{FRAME_SEND_BUFFER}.= chr($byte);
	$byteLog.= chr($byte);

	return $byteLog;
}

=head2 setGpio
	Title:		setGpio
	Function:	Set or reset specific gpio line for enable the transmitter in RS485 tranceiver.
				Set or reset executes only if attr "gpioTxenCmd_0" and "gpioTxenCmd_1" are defined.
				If you use a USB-RS485 converter or a Network-RS485 converter no set or reset are required. 
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:	$hash			hash of device
				-argument1 => int:	$value			1: execute set comand, 0: execute reset comand
=cut
sub setGpio ($$) {
	my ($hash, $value) = @_;
	my $name = $hash->{NAME};

	my $gpioTxenCmd_0 = main::AttrVal($name, 'gpioTxenCmd_0', '');
	my $gpioTxenCmd_1 = main::AttrVal($name, 'gpioTxenCmd_1', '');

	if ($gpioTxenCmd_0 ne '' && $gpioTxenCmd_0 ne '') {
		my $cmd = ($value == 1) ? $gpioTxenCmd_1 : $gpioTxenCmd_0;

		FHEM::HM485::Util::parseCommand($cmd);
	}
}

=head2 sendQueueFinishItem
	Title:		sendQueueFinishItem
	Function:	Process if forcked process returns from child. Check send queue for continuose sending
	Returns:	nothing
	Args:		named arguments:
				-argument1 => string:	$params		return string from child process
=cut
sub sendQueueFinishItem($) {
	my $param = shift;
	my ($name, $queueId, $wait) = split("\\|", $param);
#	my ($name, $queueId, $wait) = split("\\|", shift);
	my $hash = $main::defs{$name};

	if (!defined($wait) && !$wait) {
#main::Log(1, 'NextItem');		
		if (exists($hash->{sendQueue}{$queueId})) {
			# prozess next queue item only if current exists
			delete ($hash->{sendQueue}{$queueId});
			sendQueueCheckItems($hash);
		}
	} else {
#main::Log(1, 'timerqueue ' . $$);	
		
		# start internal timer fot trigger next item if sendrytry > MAX_SEND_RETRY
		
		# TODO: Inernal timer not worked at this time, sould be fixed
		#InternalTimer(gettimeofday()+1, "FHEM::HM485::Communication::sendQueueFinishItem", $name . '|' . $queueId, 0);

		# workaround
		usleep(100 * 1000);
		sendQueueFinishItem($name . '|' . $queueId);
	}
}

=head2 sendQueueCheckItems
	Title:		sendQueueCheckItems
	Function:	Check the sendqueue for sending items and send them.
	Returns:	int
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
=cut
sub sendQueueCheckItems($) {
	my ($hash) = @_;

	my $maxTimeout = 2;
	if (scalar(keys (%{$hash->{sendQueue}})) > 0) {
		
#main::Log(1, 'addqueue');
		# get next queued item and store to LAST_SEND
		my $queueId = (sort keys %{$hash->{sendQueue}})[0];
		$hash->{LAST_SEND}{TARGET}	= $hash->{sendQueue}{$queueId}{TARGET};
		$hash->{LAST_SEND}{CTRL}	= $hash->{sendQueue}{$queueId}{CTRL};
		$hash->{LAST_SEND}{SENDER}	= $hash->{sendQueue}{$queueId}{SENDER};
		$hash->{LAST_SEND}{DATA}	= $hash->{sendQueue}{$queueId}{DATA};
		$hash->{LAST_SEND}{STATE}	= $hash->{sendQueue}{$queueId}{STATE};
		$hash->{LAST_SEND}{SEND_ID}	= $queueId;

		# Forck child process. Here we can resend not acked frames
		my $blockingHash = blockingCall(
			'FHEM::HM485::Communication::sendQueueNextItem', $hash ,
			'FHEM::HM485::Communication::sendQueueFinishItem', $maxTimeout 
		);
		$hash->{LAST_SEND}{PID} = defined ($blockingHash->{pid}) ? $blockingHash->{pid} : undef;;
	} else {
#main::Log(1, 'endqueue');	
		
		$hash->{queueRunning} = 0;
	}
}



###############################################################################
# Receiving frame related functions
###############################################################################

=head2 readFrame
	Title:		readFrame
	Function:	Read each byte from buffer and build the communication frame
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => string:	$buffer		the buffer
=cut
sub readFrame($$) {
	my ($hash, $buffer) = @_;
	my $name = $hash->{NAME};
	
	for (my $i = 0; $i < length($buffer); $i++) {
		my $rxByte = ord( substr($buffer, $i, 1) );

		# $hash->{RD} holds read data for each device
		if ($rxByte == ESCAPE_CHAR && !$hash->{RD}{esc}) {
			$hash->{RD}{esc} = 1;
		} else {

			if ($rxByte == FRAME_START_LONG || $rxByte == FRAME_START_SHORT) {
				# start byte recieved
				$hash->{RD}{start} = $rxByte;
				$hash->{RD}{esc} = 0;
				$hash->{RD}{dataPntr} = 0;
				$hash->{RD}{adrPntr} = 0;

				$hash->{RD}{adrLen} = 0;
				$hash->{RD}{adrLenLng} = 0;
				$hash->{RD}{dataLen} = 0;
				$hash->{RD}{data} = undef;
				$hash->{RD}{target} = undef;
				$hash->{RD}{sender} = undef;

				$hash->{RD}{crc16Register} = 0xFFFF;
				$hash->{RD}{crc16Register} = FHEM::HM485::Util::crc16Shift(
					$rxByte, $hash->{RD}{crc16Register}
				);

				if ($rxByte == FRAME_START_LONG) {
					# start byte long (0xFD)
					$hash->{RD}{adrLen} = 4;
					$hash->{RD}{adrLenLng} = 9;

				} elsif ($rxByte == FRAME_START_SHORT) {
					# start byte short (0xFE)
					$hash->{RD}{adrLen} = 1;
					$hash->{RD}{adrLenLng} = 2;
				}

			} elsif ($hash->{RD}{start}) {
				# frame start
				if ($hash->{RD}{esc}) {
					$rxByte = $rxByte | 0x80;
					$hash->{RD}{esc} = 0;
				}

				$hash->{RD}{crc16Register} = FHEM::HM485::Util::crc16Shift(
					$rxByte, $hash->{RD}{crc16Register}
				);

				if ($hash->{RD}{adrPntr} < $hash->{RD}{adrLen}) {
					# recieve target address
					$hash->{RD}{adrPntr}++;
					$hash->{RD}{target} .= chr($rxByte);

				} elsif ($hash->{RD}{adrPntr} == $hash->{RD}{adrLen}) {
					# recieve controll byte
					$hash->{RD}{adrPntr}++;
					$hash->{RD}{cb} = $rxByte;
					
					if ( FHEM::HM485::Util::ctrlIsDiscovery($hash->{RD}{cb}) ) {
						# Skip sender address if discovery frame
						$hash->{RD}{adrPntr} += 4;
					}

				} elsif (FHEM::HM485::Util::ctrlHasSender($hash->{RD}{cb}) &&
						 $hash->{RD}{adrPntr} < $hash->{RD}{adrLenLng} ) {

					# recieve sender address
					$hash->{RD}{adrPntr}++;
					$hash->{RD}{sender} .= chr($rxByte);

				} elsif ($hash->{RD}{adrPntr} != 0xFF) {
					# recieve frame length
					$hash->{RD}{adrPntr} = 0xFF;
					$hash->{RD}{dataLen} = $rxByte;
					
				} else {
					# receive data
					$hash->{RD}{dataPntr}++;
					$hash->{RD}{data} .= chr($rxByte);

					if ($hash->{RD}{dataPntr} == $hash->{RD}{dataLen}) {
						# data complete recieved

						if ($hash->{RD}{crc16Register} == 0) {
							# checksumme ok
							$hash->{$name . '_MSGCNT'}++;
							$hash->{$name . '_TIME'} = main::TimeNow();

							if (!FHEM::HM485::Util::ctrlIsDiscovery($hash->{RD}{cb})) {
								parseFrame($hash);
							} else {
								FHEM::HM485::Util::logger(3, $name, 'RX:', $hash->{RD});
								
								# Receiving external discovery frame
								# Nothing to do yet
							}
						} else {
							FHEM::HM485::Util::logger(3, $name, 'RX: data -> crc error');
						}
					}
				}
			}
		}
	}
}

=head2 parseFrame
	Title:		parseFrame
	Function:	Parse a HM-Wired frame and dispatch the message
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:	$hash	hash of device
=cut
sub parseFrame($) {
	my ($hash) = @_;
	my $name				= $hash->{NAME};
	my $ackNum				= FHEM::HM485::Util::ctrlAckNum($hash->{RD}{cb});
	my $responseId			= -1;
	my $frameFromOtherCCU	= 0;
	
	if($hash->{RD}{start} == FRAME_START_LONG) {
		if ( ord(substr($hash->{RD}{sender},0,1)) == 0 &&
			 ord(substr($hash->{RD}{sender},1,1)) == 0 &&
			 ord(substr($hash->{RD}{sender},2,1)) == 0) {
			 	
			# This is an frame. from an other central unit (CCU)
			$frameFromOtherCCU = 1;
		}
		
		if ( defined($hash->{LAST_SEND}) ) {
			if (defined($hash->{LAST_SEND}{STATE}) &&
				$hash->{LAST_SEND}{STATE} == STATE_WAIT_ACK &&
				defined($hash->{LAST_SEND}{TARGET}) &&
				$hash->{LAST_SEND}{TARGET} eq $hash->{RD}{sender} &&
				defined($hash->{LAST_SEND}{CTRL}) &&
				FHEM::HM485::Util::ctrlTxNum($hash->{LAST_SEND}{CTRL}) == $ackNum) {
				
				# This ist the ACK - Frame of last sent frame
				$responseId = $hash->{LAST_SEND}{SEND_ID};
				$hash->{LAST_SEND}{STATE} = STATE_ACKNOWLEDGED;
			}
		}
	} else {
		if ( defined($hash->{LAST_SEND}) ) {
			if (defined($hash->{LAST_SEND}{STATE}) &&
				$hash->{LAST_SEND}{STATE} == STATE_WAIT_ACK &&
				defined($hash->{LAST_SEND}{CTRL}) &&
				!FHEM::HM485::Util::ctrlHasSender($hash->{LAST_SEND}{CTRL}) &&
				FHEM::HM485::Util::ctrlTxNum($hash->{LAST_SEND}{CTRL}) == $ackNum) {
				
				# This ist the ACK - Frame of last sent frame
				$hash->{LAST_SEND}{STATE} = STATE_ACKNOWLEDGED;
			}
		}
	}

	if ( defined($hash->{LAST_SEND}{STATE}) && $hash->{LAST_SEND}{STATE} == STATE_ACKNOWLEDGED ) {
		# Terminate child sendFrame Process
		killSendingChild($hash->{LAST_SEND}{PID});
	} else {
		#todo: NACK
	}
	
	my $response	= undef;
	my $txtResponse = '';
	my $sentCmd = '';
	if (defined($hash->{LAST_SEND}{DATA})) {
		$sentCmd =	uc(sprintf('%x', ord(substr($hash->{LAST_SEND}{DATA}, 0 ,1)) ));
	}

	my $event		= undef;
	if ($responseId > -1) {
		if ( !FHEM::HM485::Util::ctrlIsAck($hash->{RD}{cb}) ) {
			$txtResponse = ' Response';
		}
		$response = uc(substr(unpack ('H*', $hash->{RD}{data}), 0, -4));
	} else {
		$event = uc(substr(unpack ('H*', $hash->{RD}{data}), 0, -4));
	}

	FHEM::HM485::Util::logger(3, $name, 'RX:' . $txtResponse, $hash->{RD});

	# If I-Frame, Message should dispatch
	if ( FHEM::HM485::Util::ctrlIsIframe($hash->{RD}{cb}) ) {

		# Format for sending RAW messages to clients (TTTTTTTT CC SSSSSSSS D....)
		$hash->{RAWMSG} =	uc(unpack ('H*', $hash->{RD}{target})) . ' ' .
							uc(sprintf('%02X', $hash->{RD}{cb})) . ' ' .
							uc( unpack ('H*', $hash->{RD}{sender}) ) . ' ' .
							substr( uc( unpack ('H*', $hash->{RD}{data})), 0 , -4);
	
		my %addvals = ();
		$hash->{addvals}{SENT_CMD}	= $sentCmd;
		$hash->{addvals}{RESPONSE}	= $response;
		$hash->{addvals}{EVENT}		= $event;
#			'RAWMSG'		=> $hash->{RAWMSG},
	
		# Dont dispatch frames from other CCU
		if (!$frameFromOtherCCU) {
			
			# dispatch first time if $targetAddr unknown so autocreate can create the device
			
			if (FHEM::HM485::Util::checkForAutocreate() &&
				!FHEM::HM485::Util::searchValueInDefs('DEF', uc(unpack ('H*', $hash->{RD}{sender}))) ) {

				main::Log(1, '--- DISPATCH0 (Autocreate) ---');

				main::Dispatch($hash, $hash->{RAWMSG}, \%addvals);
				$hash->{addvals}{NEW} = 1;
			}
	
			main::Dispatch($hash, $hash->{RAWMSG}, \%addvals);
			main::Log(1, '--- DISPATCH1 ---');
			$hash->{addvals}{NEW} = 0;
		}
	
		# TODO: maybe we want ack messages from all sender adress
		# if ( FHEM::HM485::Util::ctrlIsIframe($hash->{RD}{cb}) && $hash->{RD}{target} eq $hash->{LAST_SEND}{SENDER} ) {
		if ($hash->{RD}{target} eq pack('H*', main::AttrVal($name, 'hmwId', '')) ) {
	
			# Todo wait 10ms
			usleep(10000);
			
			# IFRAME received, send ACK
			sendAck(
				$hash, $hash->{RD}{target}, $hash->{RD}{sender}, FHEM::HM485::Util::ctrlTxNum($hash->{RD}{cb})
			);
		}

		if (defined($hash->{LAST_SEND}{SEND_ID})) {
			# Complete the sendqueue
			sendQueueFinishItem($name . '|' . $hash->{LAST_SEND}{SEND_ID})
		}
	}
}

=head2 sendAck
	Title:		sendAck
	Function:	Send ACK to HM-Wired device
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:		$hash		hash of device
				-argument1 => string:	$senderAddr	8 hex chars
				-argument1 => string:	$targetAddr	8 hex chars
				-argument1 => int:		$txCounter
=cut
sub sendAck($$$$) {
	my ($hash, $senderAddr, $targetAddr, $txCounter) = @_;
	my $ctrl = ($txCounter << 5) | 0x19;

	sendFrame($hash, $targetAddr, $ctrl, $senderAddr, '');
}

sub killSendingChild ($) {
	my $pid = shift;

	if( defined($pid) && ($^O !~ m/Win/) ) {
		if($pid && kill(9, $pid)) {
			main::Log (1, "Terminated sending process $pid")
		}
	}
}



###############################################################################
# Discovery-Scan related functions
###############################################################################

=head2 cmdDiscovery
	Title:		cmdDiscovery
	Function:	Start a discovery scan within a new process
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:	$hash		hash of device
				-argument2 => int:	$timeout	seconds after child process terminates
=cut
sub cmdDiscovery ($) {
	my ($hash, $timeout) = @_;
	my $name = $hash->{NAME};
	my $retVal = 'Discovery mode started.';

	# Check if Sendqueue running and wait
	if ($hash->{queueRunning}) {
		$retVal = 'Send queue is already running. Pleas start discovery later again.';
		FHEM::HM485::Util::logger(3, $name, $retVal);

	} else {

		# TODO: txState handling
		$hash->{TX_STATE} = STATE_IDLE;
		if ($hash->{TX_STATE} == STATE_IDLE) {
			$hash->{TX_STATE} = STATE_DISCOVERY;

			BlockingCall(
				'FHEM::HM485::Communication::startDiscovery', $hash,
				'FHEM::HM485::Communication::endDiscovery', $timeout
			);
			# we delete hash from selectlist, so the child can read answer byself
			# while discovery is running. The hash was restored in endDiscovery
			delete($main::selectlist{$hash->{NAME} . '.' . $hash->{DEF}});
		}
	}
	
	return $name . ': ' . $retVal;
}

=head2 startDiscovery
	Title:		startDiscovery
	Function:	Perform a discovery scan.
				This function sould start in a seperate process to avoid blocking of FHEM.
	Returns:	String of found adresses seperate with |
	Args:		named arguments:
				-argument1 => hash:	$hash	hash of device
=cut
sub startDiscovery ($) {
	my ($hash) = @_;
	
	my $name			= $hash->{NAME};
	my $address			= 0x00000000;
	my $validBits		= 1;
	my $count			= 0;
	my @foundAdresses	= ();

	# Discovery can start. Send Z command first twice
	my $senderAddr = pack ('H*', main::AttrVal($name, 'hmwId', '00000001'));
	sendFrame($hash, pack ('H*', 'FFFFFFFF'), 0x9A, $senderAddr, chr(0x7A));
	sendFrame($hash, pack ('H*', 'FFFFFFFF'), 0x9C, $senderAddr, chr(0x7A));

	# Wait 200ms before start
	usleep (200 * 1000);
	
	FHEM::HM485::Util::logger(3, $name, 'Discovery start.');

	while(1){
		my $txtAddress		= sprintf('%08X', $address);

		my $discoveryTries	= 0;
		for ($discoveryTries = 0; $discoveryTries < DISCOVERY_TRIES; $discoveryTries++){
			my $ctrl = (($validBits-1) << 3) | 0x03;
			sendFrame ($hash, pack ('H*', $txtAddress), $ctrl, undef, undef);

			if (readDiscoveryResult($hash)) {
				$validBits++;
				last;
			}
		}
		
		if($validBits == 33){
			# Check if device was new
#			if ( !FHEM::HM485::Util::searchValueInDefs('DEF', $txtAddress) ) {
				# found a valid address, push to the foundAdresses list
				push(@foundAdresses, $txtAddress);
#			}

			FHEM::HM485::Util::logger(3, $name, 'RX: Discovery result: ' . $txtAddress);
			
			# continue processing as if there was no answer received
			$validBits--;
			$discoveryTries = DISCOVERY_TRIES;

			# TODO: check if we can realy found only 256 devices
			$count++;
			if($count == 256) {
				FHEM::HM485::Util::logger(1, $name, 'HM485 Discovery: We found more than 255 Modules. Cancel with error.');
				return $hash->{NAME} . '|' . -1; 	
			}
		}
		
		if ($discoveryTries == DISCOVERY_TRIES) {
			if( (($address >> (32-$validBits)) & 0x01) == 0) {
				# least significant valid bit is 0, set it to 1
				$address |= (1) << (32 - $validBits);
			} else {
				# least significant valid bit is already 1
				# set invalid $address bits to 1, add 1 and set $validBits
				# to mask out the least significant 0-bits
				$address |= ( ($validBits==32) ? 0 : (0xFFFFFFFF>>$validBits) );

				if ($address == 0xFFFFFFFF) {
					# here we are done. Exit while.
					last;
				}

				$address++;
				$validBits = 32;
				while ($validBits && ((($address >> (32-$validBits)) & 0x01) == 0)) {
					$validBits--;
				}
			}
		}
	}

	return $hash->{NAME} . '|' . join(",", @foundAdresses);
}

=head2 readDiscoveryResult
	Title:		readDiscoveryResult
	Function:	Read discovery result direct from DevIo
	Returns:	int
	Args:		named arguments:
				-argument1 => hash:	$hash		hash of device
=cut
sub readDiscoveryResult($) {
	my ($hash) = @_;
	
	my $rin = '';
	my $retVal = 0;

	vec($rin, $hash->{FD}, 1) = 1 if exists($hash->{FD});
	my $nfound = select($rin, undef, undef, (DISCOVERY_TIMEOUT / 1000));

	if ($nfound && exists($hash->{FD})) {
		my $buffer = main::DevIo_SimpleRead($hash);
		$retVal = ord(substr($buffer, 0, 1));
	}
	
	return $retVal;
}

=head2 endDiscovery
	Title:		endDiscovery
	Function:	Called from Discovery-Scan child process.
	Returns:	noting
	Args:		named arguments:
				-argument1 => string:	params of child process
=cut
sub endDiscovery ($) {
	my $params = shift;
	my $retVal = undef();

	my ($name, $adresses) = split("\\|", $params);
	my $hash = $main::defs{$name};

	my @foundAdresses = ();
	if (defined($adresses)) {
		@foundAdresses = split(",", $adresses);
	}

	# we must restore hash to selectlist if posible, so the parent can read again
	if (exists($hash->{FD})) {
		$main::selectlist{$hash->{NAME} . '.' . $hash->{DEF}} = $hash;
	}
	
	my $senderAddr = pack ('H*', main::AttrVal($hash->{NAME}, 'hmwId', '00000001'));

	# Discovery end. Send z command first twice
	sendFrame($hash, pack ('H*', 'FFFFFFFF'), 0x9E, $senderAddr, chr(0x5A));
	sendFrame($hash, pack ('H*', 'FFFFFFFF'), 0x98, $senderAddr, chr(0x5A));

	# count new devices (compare with existing)
	my $newDevices = 0;
	my @newAdresses = ();
	if (@foundAdresses > 0) {
		foreach my $address (@foundAdresses) {
			# TODO: check existing devices with same address
			push(@newAdresses, $address);
			$newDevices++;
		}
	}

	FHEM::HM485::Util::logger(
		3, $name,
		'Discovery End: ' . $newDevices. ' new device' . (($newDevices!=1) ? 's' : '') . ' found.'
	);

	if (@newAdresses > 0) {
		foreach my $address (@newAdresses) {
			main::DoTrigger($name, 'New Device (' . $address . ') found.');
			
			# Get modultype first after discovery
			sendRawQueue($hash, pack ('H*', $address), 0x98, $senderAddr, chr(0x68));
			$newDevices++;
		}
	}

	$hash->{TX_STATE} = STATE_IDLE;

	return $retVal;
}



###############################################################################
# Helper functions for Blocking
###############################################################################

=head2 blockingCall
	Title:		blockingCall
	Function:	Blocking wrapper for main::BlockingCall
	Returns:	hash
	Args:		named arguments:
				-argument1 => string:	$blockingFn
				-argument2 => hash:		$arg
				-argument3 => string:	$finishFn
				-argument4 => number:	$timeout
				-argument5 => string:	$abortFn
				-argument6 => mixed:	$abortArg
=cut
sub blockingCall($$;$$$$) {
	my ($blockingFn, $arg, $finishFn, $timeout, $abortFn, $abortArg) = @_;

	$arg->{blockingCallFn} = $blockingFn;

	my $retVal = main::BlockingCall(
		'FHEM::HM485::Communication::blockingWrapperFn', $arg ,
		$finishFn, $timeout, $abortFn, $abortArg 
	);
	
	delete $arg->{blockingCallFn};

	return $retVal
}

=head2 blockingWrapperFn
	Title:		blockingWrapperFn
	Function:	Wrapper for blockingCallFn. Here we must open a new serial device.
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash:		$arg
=cut
sub blockingWrapperFn($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $blockingFn = $hash->{blockingCallFn};

	delete $hash->{blockingCallFn};

	my $logLevel = $main::attr{global}{verbose};

	# disable logging for DevIo_OpenDev in blocking call 
	$main::attr{global}{verbose} = 0;

	# We must reopen the communication device
	main::DevIo_OpenDev($hash, 0, 'HM485_SERIAL_Init');

	# restore logging
	$main::attr{global}{verbose} = $logLevel;

	# Call blocking sub
	no strict "refs";
	my $ret = &{$blockingFn}($hash);
	use strict "refs";
}

1;