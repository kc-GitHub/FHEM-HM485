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

package HM485_Protocol;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw(gettimeofday);
use bytes;

use constant {
	FRAME_START_SHORT       => 0xFE,
	FRAME_START_LONG        => 0xFD,
	ESCAPE_CHAR             => 0xFC,

	MAX_SEND_RETRY          => 3,
	SEND_RETRY_TIMEOUT      => 200,  # die CCU macht nach 200ms eine Neusendung? 	
	DISCOVERY_TRIES         => 3,
	DISCOVERY_TIMEOUT       => 20,   # 15ms
#	DISCOVERY_TIMEOUT       => 50,

	STATE_IDLE              => 0x00,
	STATE_WAIT_ACK          => 0x03,
	STATE_WAIT_RESPONSE     => 0x04,
	STATE_ACKNOWLEDGED      => 0x05,
	STATE_DISCOVERY         => 0x06,
	STATE_DISCOVERY_WAIT    => 0x07,
	
	### Commands from client
	CMD_SEND                => 0x53,
	CMD_DISCOVERY           => 0x44,

	### Commands to client
	CMD_ALIVE               => 0x61,
	CMD_EVENT               => 0x65,
	CMD_DISCOVERY_RESULT    => 0x64,
	CMD_DISCOVERY_END       => 0x63,
	CMD_RESPONSE            => 0x72,

	LOGTAG                  => 'HM485d'
};

my @validRequestTypes = ('K', 'R', 'S', 'h', 'n', 'p', 'r', 's', 'v', 'x', 'Ë');

my %sendQueue;
my %discoveryData;
my %addressLastMsgMap;

my $queueRunning = 0;

my $currentQueueId = 0;

my $FRAME_SEND_BUFFER;
my %RD = ();
my $stateTx = STATE_IDLE;

my $gpioTxenCmd0 = '';
my $gpioTxenCmd1 = '';
my $hmwId;
my $checkResendQueueItemsTimeout;
my $globalQueueId = 0;

###############################################################################
# Define prototypes
###############################################################################

sub new($);

sub sendRawQueue($$$$;$);
sub sendQueueNextItem();
sub sendFrame($$$$;$);
sub bufferFrameByte($$;$);
sub sendQueueCheckItems();

sub readFrame($$);
sub parseFrame();
sub sendAck($$$$);

sub cmdDiscovery($$$);
sub discoveryStart($);
sub readDiscoveryResult();
sub discoveryEnd($);

###############################################################################

=head2 NAME
	Title:		new
	Function:	The class constructor
	Returns:	HM485_Protocol
	Args:		named arguments:
				-argument1 => string:	$className  The class name
				-argument1 => string:	$hmwId      4 byte hex number
=cut
sub new($) {
	my ($className, $myHmwId) = @_;
	$hmwId = defined($myHmwId) ? $myHmwId : '00000001';
	
	return bless {
		sendQueue     => \%sendQueue,
		discoveryData => \%discoveryData,
	}, $className;
}

sub setStateIdle() {
	$stateTx = STATE_IDLE;
}

sub setStateDiscovery() {
	$stateTx = STATE_DISCOVERY;
}

sub setStateDiscoveryWait() {
	$stateTx = STATE_DISCOVERY_WAIT;
}

###############################################################################
# Sending frame related functions
###############################################################################

=head2 NAME
	Title:		sendRawQueue
	Function:	Queue a HMW message and start queue if it not running
	Returns:	nothing
	Args:		named arguments:
				-argument1 => string:	$targetAddr	8 hex chars
				-argument1 => int:		$ctrl		ctrl byte
				-argument1 => string:	$senderAddr	8 hex chars
				-argument1 => string:	$data		n hex chars
=cut
sub sendRawQueue($$$$;$) {
	my ($self, $targetAddr, $ctrl, $senderAddr, $data, $msgId) = @_;

	# Todo: for check frame must acked?

	my $queueId = $self->getQueueId();
	my $cmd = substr($data, 0,1);

	$self->{sendQueue}{$queueId}{TARGET}     = $targetAddr;
	$self->{sendQueue}{$queueId}{CTRL}       = $ctrl;
	$self->{sendQueue}{$queueId}{SENDER}     = $senderAddr;
	$self->{sendQueue}{$queueId}{DATA}       = $data;
	$self->{sendQueue}{$queueId}{MSG_ID}     = $msgId;
	$self->{sendQueue}{$queueId}{SEND_COUNT} = 0;

	# Messages to broadcast, messages with z or Z command must not acked
	if ( (uc( unpack ('H*', $targetAddr)) eq 'FFFFFFFF') || $cmd eq 'z' || $cmd eq 'Z') {
		$self->{sendQueue}{$queueId}{STATE}	= STATE_IDLE;
		
	} else {
		if (grep $_ eq $cmd, @validRequestTypes) {
			$self->{sendQueue}{$queueId}{STATE}	= STATE_WAIT_RESPONSE;
		} else {
			$self->{sendQueue}{$queueId}{STATE}	= STATE_WAIT_ACK;
		}
	}

	if (!$queueRunning) {
		$queueRunning = 1;
		$self->sendQueueNextItem();
	}
}

sub getQueueId() {
	my ($self) = @_;
	$globalQueueId++;
	return sprintf('%08X', $globalQueueId);
	
#	return int(gettimeofday()*1000) % 0xFFFFFFFF;
}

=head2 sendQueueNextItem
	Title:		sendQueueNextItem
	Function:	Sendout the next queued HM485 message.
				Try send up to n times (n=MAX_SEND_RETRY)
	Returns:	nothing
	Args:		named arguments:
				nothing
=cut
sub sendQueueNextItem() {
	my ($self) = @_;

	# TODOs:	line watching: if line free to send?
	delete ($self->{sendQueue}{0});

	my $queueCount = scalar(keys (%{$self->{sendQueue}}));
	if ($queueCount > 0) {
		$currentQueueId = (sort keys %{$self->{sendQueue}})[0];
		
#		$self->{sendQueue}{$currentQueueId}{SEND_ID} = $currentQueueId;
		$self->{sendQueue}{$currentQueueId}{SEND_COUNT}++;

		$self->sendFrame(
			$self->{sendQueue}{$currentQueueId}{TARGET},
			$self->{sendQueue}{$currentQueueId}{CTRL},
			$self->{sendQueue}{$currentQueueId}{SENDER},
			$self->{sendQueue}{$currentQueueId}{DATA},
			$self->{sendQueue}{$currentQueueId}{MSG_ID} . ':' . $self->{sendQueue}{$currentQueueId}{SEND_COUNT}
		);
	
		if ($self->{sendQueue}{$currentQueueId}{STATE} == STATE_WAIT_ACK || 
			$self->{sendQueue}{$currentQueueId}{STATE} == STATE_WAIT_RESPONSE) {
				
			# check if the item must resend after 100ms resend this queue item after 100 ms
			$checkResendQueueItemsTimeout = main::setTimeout(
				SEND_RETRY_TIMEOUT, 'checkResendQueueItems'
			);
		} else {
			$queueRunning = 0;
			$self->deleteCurrentItemFromQueue();			
		}	
	} else {
		$queueRunning = 0;
	}
}

=head2 NAME
	Title:		sendFrame
	Function:	Collect Send out a HM485 frame
	Returns:	nothing
	Args:		named arguments:
				-argument1 => string:	$targetAddr	string of 4 bytes
				-argument1 => int:		$ctrl		ctrl byte
				-argument1 => string:	$senderAddr	string of 4 bytes
				-argument1 => string:	$data		string of n bytes
				-argument1 => int:		$sendId
				-argument1 => int:		$sendCount (optional)
=cut
sub sendFrame($$$$;$) {
	my ($self, $targetAddr, $ctrl, $senderAddr, $data, $sendCount) = @_;
	my %logData;

	my $sendByte      = undef;
	my $crc16Register = 0xFFFF;
	my $start	= FRAME_START_LONG;

	$self->bufferFrameByte($start, 1);                                          # startbyte
	$logData{start} = $start;
	$crc16Register = $self->crc16Shift($start , $crc16Register);

	for (my $i = 0; $i < length($targetAddr); $i++) {                           # target address
		$sendByte = ord(substr($targetAddr, $i, 1));
		$logData{target}.= $self->bufferFrameByte($sendByte, 0);
		$crc16Register = $self->crc16Shift($sendByte , $crc16Register);
	}

	$self->bufferFrameByte($ctrl, 0);                                           # controll byte
	$logData{cb} = $ctrl;
	$crc16Register = $self->crc16Shift($ctrl , $crc16Register);

	if (!HM485::Util::ctrlIsDiscovery($ctrl) && HM485::Util::ctrlHasSender($ctrl)) { # check if message has sender
		for (my $i = 0; $i < length($senderAddr); $i++) {                       # sender address
			$sendByte = ord(substr($senderAddr, $i, 1));
			$logData{sender}.= $self->bufferFrameByte($sendByte, 0);
			$crc16Register = $self->crc16Shift($sendByte , $crc16Register);
		}
	}

	$data = defined($data) ? $data : '';
	
	# TODO: Check max dataLength (FB=251)
	my $dataLenght = length($data) + 2;
	$self->bufferFrameByte($dataLenght, 0);	                                    # data length
	$logData{dataLen} = $dataLenght;
	$crc16Register = $self->crc16Shift($dataLenght , $crc16Register);

	for (my $i = 0; $i < $dataLenght-2; $i++) {                                 # data
		$sendByte = ord(substr($data, $i, 1));
		$logData{data}.= $self->bufferFrameByte($sendByte, 0);
		$crc16Register = $self->crc16Shift($sendByte , $crc16Register);
	}
	
	$crc16Register = $self->crc16Shift(0 , $crc16Register);
	$crc16Register = $self->crc16Shift(0 , $crc16Register);

	$logData{data}.=$self->bufferFrameByte((($crc16Register >> 8) & 0xFF), 0);  # first byte of crc
	$logData{data}.=$self->bufferFrameByte(($crc16Register & 0xFF), 0 );        # second byte of crc
	$logData{crc16Register} = $crc16Register;

	if (defined($FRAME_SEND_BUFFER)) {
		# send out buffer to IO device
		main::interfaceWrite($FRAME_SEND_BUFFER);
	}

	$FRAME_SEND_BUFFER = '';
	
	$sendCount = (defined($sendCount)) ? '(' . $sendCount . ')' : '';
	HM485::Util::logger(LOGTAG, 3, 'Tx: ' . $sendCount, \%logData);
}

=head2 NAME
	Title:		bufferFrameByte
	Function:	Bufer a frame byte to for later sending
				Bevore buffering check byte for spechial chars. Spechial chars was escaped bevore buffering
	Returns:	string
	Args:		named arguments:
				-argument1 => int:	$byte			byte to buffer
				-argument1 => int:	$noEscapeCheck	set to 1 to suppress escape check for sending byte
=cut
sub bufferFrameByte($$;$) {
	my ($self, $byte, $noEscapeCheck) = @_;
	$noEscapeCheck = defined($noEscapeCheck) ? $noEscapeCheck : 0;

	my $byteLog = '';

	$FRAME_SEND_BUFFER = defined($FRAME_SEND_BUFFER) ? $FRAME_SEND_BUFFER : '';
	
	if (!$noEscapeCheck) {
		if ($byte == FRAME_START_LONG || $byte == FRAME_START_SHORT || $byte == ESCAPE_CHAR) {
			$FRAME_SEND_BUFFER.= chr(ESCAPE_CHAR);
			$byteLog = chr(ESCAPE_CHAR);
			$byte = $byte & 0x7F;
		}
	}
	
	$FRAME_SEND_BUFFER.= chr($byte);
	$byteLog.= chr($byte);

	return $byteLog;
}

=head2 NAME
	Title:		sendQueueCheckItems
	Function:	Check the sendqueue for sending items and send them.
	Returns:	int
	Args:		named arguments:
				nothing
=cut
sub sendQueueCheckItems() {
	my ($self) = @_;
	if (exists($self->{sendQueue}{$currentQueueId}{STATE})) {
		if ($self->{sendQueue}{$currentQueueId}{STATE} != STATE_ACKNOWLEDGED) {

			if ($self->{sendQueue}{$currentQueueId}{SEND_COUNT} >= MAX_SEND_RETRY) {
				### NACK ###
				$self->sendError($self->{sendQueue}{$currentQueueId}{MSG_ID}, 1);
				$self->deleteCurrentItemFromQueue();
			}

		} else {
			$self->deleteCurrentItemFromQueue();
		}
	}

	# prozess next queue item.
	$self->sendQueueNextItem();
}

sub deleteCurrentItemFromQueue() {
	my ($self) = @_;
	
	delete ($self->{sendQueue}{$currentQueueId});
	$currentQueueId = 0;
}

sub checkResendQueueItems($) {
	my ($self) = @_;
	$self->sendQueueCheckItems();
}

###############################################################################
# Receiving frame related functions
###############################################################################

=head2 readFrame
	Title:		readFrame
	Function:	Read each byte from buffer and build the communication frame
	Returns:	nothing
	Args:		named arguments:
				-argument1 => string:	$buffer		the buffer
=cut
sub readFrame($$) {
	my ($self, $buffer) = @_;
	
	for (my $i = 0; $i < length($buffer); $i++) {
		my $rxByte = ord( substr($buffer, $i, 1) );

		if ($rxByte == ESCAPE_CHAR && !$RD{esc}) {
			$RD{esc} = 1;
		} else {

			if ($rxByte == FRAME_START_LONG || $rxByte == FRAME_START_SHORT) {
				# start byte recieved
				$RD{start} = $rxByte;
				$RD{esc} = 0;
				$RD{dataPntr} = 0;
				$RD{adrPntr} = 0;

				$RD{adrLen} = 0;
				$RD{adrLenLng} = 0;
				$RD{dataLen} = 0;
				$RD{data} = undef;
				$RD{target} = undef;
				$RD{sender} = undef;

				$RD{crc16Register} = 0xFFFF;
				$RD{crc16Register} = $self->crc16Shift($rxByte, $RD{crc16Register});

				if ($rxByte == FRAME_START_LONG) {
					# start byte long (0xFD)
					$RD{adrLen} = 4;
					$RD{adrLenLng} = 9;

				} elsif ($rxByte == FRAME_START_SHORT) {
					# start byte short (0xFE)
					$RD{adrLen} = 1;
					$RD{adrLenLng} = 2;
				}

			} elsif ($RD{start}) {
				# frame start
				if ($RD{esc}) {
					$rxByte = $rxByte | 0x80;
					$RD{esc} = 0;
				}

				$RD{crc16Register} = $self->crc16Shift($rxByte, $RD{crc16Register});

				if ($RD{adrPntr} < $RD{adrLen}) {
					# recieve target address
					$RD{adrPntr}++;
					$RD{target} .= chr($rxByte);

				} elsif ($RD{adrPntr} == $RD{adrLen}) {
					# recieve controll byte
					$RD{adrPntr}++;
					$RD{cb} = $rxByte;
					
					if (HM485::Util::ctrlIsDiscovery($RD{cb}) ) {
						# Skip sender address if discovery frame
						$RD{adrPntr} += 4;
					}

				} elsif (HM485::Util::ctrlHasSender($RD{cb}) && $RD{adrPntr} < $RD{adrLenLng} ) {

					# recieve sender address
					$RD{adrPntr}++;
					$RD{sender} .= chr($rxByte);

				} elsif ($RD{adrPntr} != 0xFF) {
					# recieve frame length
					$RD{adrPntr} = 0xFF;
					$RD{dataLen} = $rxByte;
					
				} else {
					# receive data
					$RD{dataPntr}++;
					$RD{data} .= chr($rxByte);

					if ($RD{dataPntr} == $RD{dataLen}) {
						# data complete recieved

						if ($RD{crc16Register} == 0) {
							# checksumme ok
							if (!HM485::Util::ctrlIsDiscovery($RD{cb})) {
								$self->parseFrame();
							} else {
								HM485::Util::logger(LOGTAG, 3, 'Rx: ', \%RD);
								
								# Receiving external discovery frame
								# Nothing to do yet
							}
						} else {
							HM485::Util::logger(LOGTAG, 3, 'Rx: data -> crc error', \%RD);
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
=cut
sub parseFrame() {
	my ($self) = @_;

	my $frameFromOtherCentralUnit = 0;
	
	if (exists($addressLastMsgMap{$RD{sender}}) &&
	    $addressLastMsgMap{$RD{sender}}{cb} == $RD{cb} &&
	    $addressLastMsgMap{$RD{sender}}{data} eq $RD{data} &&
	    !HM485::Util::ctrlSynSet($RD{cb}) ) {
			
		HM485::Util::logger(LOGTAG, 3, 'Rx: dup frame: ', \%RD);
			
	} else {
		my $ackNum = HM485::Util::ctrlAckNum($RD{cb});
		my $responseId = -1;

		$addressLastMsgMap{$RD{sender}} = {
			cb   => $RD{cb},
			data => $RD{data}
		};
		
		if($RD{start} == FRAME_START_LONG) {
			if ( ord(substr($RD{sender},0,1)) == 0 &&
				 ord(substr($RD{sender},1,1)) == 0 &&
				 ord(substr($RD{sender},2,1)) == 0) {
				 	
				# This is an echo frame. from an other central unit (CCU)
				$frameFromOtherCentralUnit = 1;
			}

			if (exists($self->{sendQueue}{$currentQueueId}{STATE}) &&
				$self->{sendQueue}{$currentQueueId}{TARGET} eq $RD{sender} &&
				HM485::Util::ctrlTxNum($self->{sendQueue}{$currentQueueId}{CTRL}) == $ackNum) {

				if ($self->{sendQueue}{$currentQueueId}{STATE} == STATE_WAIT_ACK) {
					# This ist a ACK - Frame of last sent frame
					$self->{sendQueue}{$currentQueueId}{STATE} = STATE_ACKNOWLEDGED;

				} elsif ($self->{sendQueue}{$currentQueueId}{STATE} == STATE_WAIT_RESPONSE && 
					     substr($RD{data}, 0, -2) ) {

					# This ist a RESPONSE - Frame of last sent frame
					# We process response only if STATE_WAIT_RESPONSE and response data was given 
					$responseId = $self->{sendQueue}{$currentQueueId}{MSG_ID};
					$self->{sendQueue}{$currentQueueId}{STATE} = STATE_ACKNOWLEDGED;
				}
			}
		} else {
			if (exists($self->{sendQueue}{$currentQueueId}{STATE}) &&
				($self->{sendQueue}{$currentQueueId}{STATE} == STATE_WAIT_ACK || 
				 $self->{sendQueue}{$currentQueueId}{STATE} == STATE_WAIT_RESPONSE) &&
				!HM485::Util::ctrlHasSender($self->{sendQueue}{$currentQueueId}{CTRL}) &&
				HM485::Util::ctrlTxNum($self->{sendQueue}{$currentQueueId}{CTRL}) == $ackNum) {

				# This ist the ACK - Frame of last sent frame
				$self->{sendQueue}{$currentQueueId}{STATE} = STATE_ACKNOWLEDGED;
			}
		}
	
		### for logging
		my $txtResponse = '';
		if ($responseId > -1) {
			if ( !HM485::Util::ctrlIsAck($RD{cb}) ) {
				$txtResponse = 'Response: (' . $responseId . ')';
			}
			my $response = uc(substr(unpack ('H*', $RD{data}), 0, -4));
		} else {
			my $event = uc(substr(unpack ('H*', $RD{data}), 0, -4));
		}
	
		HM485::Util::logger(LOGTAG, 3, 'Rx: ' . $txtResponse, \%RD);
	
		# TODO: maybe we want ack messages from all sender adress
		if (HM485::Util::ctrlIsIframe($RD{cb}) && $RD{target} eq pack('H*', $hmwId) ) {
			# IFRAME received with receiver address eq this hmwId, we must ack it
			$self->sendAck($RD{target}, $RD{sender}, HM485::Util::ctrlTxNum($RD{cb}));
		}
	
		if ($responseId > -1 || ($self->{sendQueue}{$currentQueueId}{STATE} &&
		                         $self->{sendQueue}{$currentQueueId}{STATE} == STATE_ACKNOWLEDGED)) {
			my $responseData = substr($RD{data}, 0, -2);
			$self->sendResponse(
				$self->{sendQueue}{$currentQueueId}{MSG_ID}, 
				$RD{cb},
				$responseData
			);
	
			# Messages acknowleded, we can delet the resend timer
			if ($checkResendQueueItemsTimeout) {
				main::clearTimeout($checkResendQueueItemsTimeout);
				$checkResendQueueItemsTimeout = undef;
				
				# Check queue item
				$self->deleteCurrentItemFromQueue();
				$self->sendQueueCheckItems();
			}
		} else {

			# If I-Frame, Message should dispatch
			if ( HM485::Util::ctrlIsIframe($RD{cb}) ) {
	
				# Dont dispatch frames from other CCU
				if (!$frameFromOtherCentralUnit) {
	
					# Dispatch frame
					$self->sendEvent(
						$RD{target}, $RD{cb}, $RD{sender}, substr($RD{data}, 0, -2)
					);
				}
			
			}
	
		}
	}
}

=head2 NAME
	Title:		sendAck
	Function:	Send ACK to HM-Wired device
	Returns:	nothing
	Args:		named arguments:
				-argument1 => hash
=cut
sub sendAck($$$$) {
	my ($self, $senderAddr, $targetAddr, $txCounter) = @_;
	
	my $ctrl = ($txCounter << 5) | 0x19;
	$self->sendFrame($targetAddr, $ctrl, $senderAddr, '');
}

###############################################################################
# Discovery-Scan related functions
###############################################################################

=head2 cmdDiscovery
	Title:		cmdDiscovery
	Function:	Start a discovery scan within a new process
	Returns:	nothing
	Args:		named arguments:
				-argument2 => int:	$timeout	seconds after child process terminates
=cut
sub cmdDiscovery ($$$) {
	my ($self, $msgId, $timeout) = @_;
	
	my $retVal = 0;
	
	# Check if self->{sendQueue} running and wait
	if ($queueRunning) {
		main::Log3('', 3, 'Send queue is already running. Pleas start discovery later again.');

	} else {
		$retVal = 1;
		main::Log3('', 3, 'Discovery mode started.');

		# TODO: txState handling
		$self->setStateIdle();
		if ($stateTx == STATE_IDLE) {
			# Start Discovery after 100ms
			my %params = (self => $self, msgId => $msgId);
			main::setTimeout(100, 'HM485_Protocol::discoveryStart', \%params);
		}
	}
	
	return $retVal;
}

=head2 discoveryStart
	Title:		discoveryStart
	Function:	Perform a discovery scan.
				This function sould start in a seperate process to avoid blocking of FHEM.
	Returns:	String of found adresses seperate with |
	Args:		named arguments:
=cut
sub discoveryStart ($) {
	my ($hash) = @_;
	my $self = $hash->{self};
	my $msgId = $hash->{msgId};

	$self->setStateDiscovery();

	$self->{discoveryData} = {
		address        => 0x00000000,
		validBits      => 1,
		count          => 0,
		discoveryTries => 0,
		discoveryFound => 0,
		discoveryId =>    $msgId,
	};
		
	my %params = (self => $self, msgId => $msgId);
	main::setTimeout(500, 'HM485_Protocol::discoveryNextStep', \%params);
}

sub discoveryNextStep ($) {
	my ($hash) = @_;
	my $self = $hash->{self};
	my $msgId = $hash->{msgId};

	my $done = 0;
	my $txtAddress = sprintf('%08X', $self->{discoveryData}{address});

	if ($self->{discoveryData}{discoveryTries} < DISCOVERY_TRIES && !$self->{discoveryData}{discoveryFound}) {
		$self->{discoveryData}{discoveryTries}++;
		my $ctrl = (($self->{discoveryData}{validBits}-1) << 3) | 0x03;

		$self->setStateDiscoveryWait();
		$self->sendFrame (pack ('H*', $txtAddress), $ctrl, undef, undef);

	} elsif ($self->{discoveryData}{discoveryTries} < DISCOVERY_TRIES && $self->{discoveryData}{discoveryFound}) {
		$self->{discoveryData}{validBits}++;
	}
	
	if ($self->{discoveryData}{discoveryTries} == DISCOVERY_TRIES || $self->{discoveryData}{discoveryFound} ) {
		if($self->{discoveryData}{validBits} == 33){
			# we got an address!
			$self->sendDiscoveryResult($msgId, $self->{discoveryData}{address});
	
			# continue processing as if there was no answer received
			$self->{discoveryData}{validBits}--;
			$self->{discoveryData}{discoveryTries} = DISCOVERY_TRIES;
			$self->{discoveryData}{count}++;
		}		

		# TODO: check if we can realy found only 256 devices ?
		if($self->{discoveryData}{count} < 256) {
			if ($self->{discoveryData}{discoveryTries} == DISCOVERY_TRIES) {
	
				if( (($self->{discoveryData}{address} >> (32 - $self->{discoveryData}{validBits})) & 0x01) == 0) {
					# least significant valid bit is 0, set it to 1
					$self->{discoveryData}{address} |= (1) << (32 - $self->{discoveryData}{validBits});
				} else {
					# least significant valid bit is already 1
					# set invalid $self->{discoveryData}{address} bits to 1, add 1 and set $self->{discoveryData}{validBits}
					# to mask out the least significant 0-bits
					$self->{discoveryData}{address} |= ( ($self->{discoveryData}{validBits} == 32) ? 0 : (0xFFFFFFFF >> $self->{discoveryData}{validBits}) );

					if ($self->{discoveryData}{address} == 0xFFFFFFFF) {
						# here we are done.
						$done = 1;
					} else {
						$self->{discoveryData}{address}++;
						$self->{discoveryData}{validBits} = 32;
						while ($self->{discoveryData}{validBits} && ((($self->{discoveryData}{address} >> (32 - $self->{discoveryData}{validBits})) & 0x01) == 0)) {
							$self->{discoveryData}{validBits}--;
						}
					}
				}
			}
		} else {
			HM485::Util::logger(LOGTAG, 2, 'Discovery: We found more than 255 Modules. Cancel with error.');
			$done = 1;
		}

		$self->{discoveryData}{discoveryFound} = 0;
		$self->{discoveryData}{discoveryTries} = 0;
	}

	if (!$done) {
		my %params = (self => $self, msgId => $msgId);
		main::setTimeout(DISCOVERY_TIMEOUT, 'HM485_Protocol::discoveryNextStep', \%params);
	} else {
		$self->discoveryEnd($msgId, $self->{discoveryData}{count});
	}		
}

=head2 discoveryEnd
	Title:		discoveryEnd
	Function:	Called from Discovery-Scan child process.
	Returns:	noting
	Args:		named arguments:
				-argument1 => string:	params of child process
=cut
sub discoveryEnd ($) {
	my ($self, $msgId, $foundModuleCount) = @_;
	
	my $senderAddr = pack ('H*', $hmwId);

	$self->setStateIdle();

	$self->sendDiscoveryEnd($msgId, $foundModuleCount);
	HM485::Util::logger(LOGTAG, 3, 'Discovery: END');
}

sub discoveryFound() {
	my ($self, $buffer) = @_;
	
	$self->setStateDiscovery();
	
	$self->{discoveryData}{discoveryFound} = $buffer;
}

sub sendDiscoveryResult($$$) {
	my ($self, $msgId, $address) = @_;
	$address = pack('H*', sprintf('%08X', $address));
	$self->sendToClient($msgId, CMD_DISCOVERY_RESULT, $address);
}

sub sendDiscoveryEnd($$$) {
	my ($self, $msgId, $count) = @_;
	
	$self->sendToClient(
		$msgId, CMD_DISCOVERY_END, chr(0x00) . chr(0x00) . chr($count)
	);
}

### NACK
sub sendError($$$) {
	my ($self, $msgId, $error) = @_;
	
	$error = ord($error);
	$self->sendToClient($msgId, CMD_ALIVE, int($error));
}

sub sendResponse($$$) {
	my ($self, $msgId, $ctrl, $data) = @_;
	$self->sendToClient($msgId, CMD_RESPONSE, chr($ctrl) . $data);
}

sub sendEvent($$$$$) {
	my ($self, $target, $ctrl, $sender, $data) = @_;
	
	# todo: msg counter
	$self->sendToClient(0, CMD_EVENT, $target . chr($ctrl) . $sender . $data);
}

sub sendToClient($$$$) {
	my ($self, $msgId, $msgCmd, $msgData) = @_;
	main::clientWrite($msgId, $msgCmd, $msgData);
}

sub checkStateIdle() {
	my ($self) = @_;
	return ($stateTx == STATE_IDLE) ? 1 : 0
}

sub checkStateDiscovery() {
	my ($self) = @_;
	return ($stateTx == STATE_DISCOVERY) ? 1 : 0
}

sub checkStateDiscoveryWait() {
	my ($self) = @_;
	return ($stateTx == STATE_DISCOVERY_WAIT) ? 1 : 0
}

=head2 NAME
# Daten senden

# Startzeichen FD (hab noch kein FE gesehen)
# |  Länge der Nachricht inkl. MessageCounter
# |  |  MessageCounter, wird mit jedem KeepAlive oder anderer Message hochgezählt, Overflow bei 0xFF --> 0x01, startet nach Transparenzbefehl mit 01
# |  |  |  Befehl (S steht für Senden)
# |  |  |  |  ???
# |  |  |  |  |  ab hier kommen die Nutzdaten
# |  |  |  |  |  ---------------------------------------
# |  |  |  |  |  Zieladresse
# |  |  |  |  |  |           CTRL-Byte
# |  |  |  |  |  |           |  Absenderadresse
# |  |  |  |  |  |           |  |           Nutzdaten, könnte das der Jalousie-Aktor-Status sein?
# |  |  |  |  |  |           |  |           |
# -- -- -- -- ----------- -- -- ----------- -----------
# FD 0F 13 53 C8 00 00 59 ED 1A 00 00 00 01 78 0C 00
=cut
sub parseCommand ($$$) {
	my ($self, $message, $msgId) = @_;
	
	my $retVal = '';

	my $msgLen  = ord(substr($message, 1, 1));
	my $msgCmd  = ord(substr($message, 3, 1));

	if ($msgCmd == CMD_SEND) {                         # Command to bus devices
		my $msgData = uc( unpack ('H*', substr($message, 5)) );

		my $target = substr($msgData, 0, 8);
		my $ctrl = substr($msgData, 8, 2);
		my $source = substr($msgData, 10, 8);
		my $data = substr($msgData, 18);

		$self->sendRawQueue(
			pack('H*', $target),
			hex($ctrl),
			pack('H*', $source),
			pack('H*', $data),
			$msgId
		);

	} elsif ($msgCmd == CMD_DISCOVERY) {               # Command to Interface
		my $timeout = 30;
		my $result = $self->cmdDiscovery($msgId, $timeout);
	}
	
	return $retVal;
}
	
###############################################################################
# helper functions
###############################################################################
=head2 NAME
	Title:		crc16Shift
	Function:	Calculate crc16 checksum for each byte
	Returns:	int
	Args:		named arguments:
				-argument1 => int	$w
				-argument1 => int	$register
=cut
sub crc16Shift($$$) {
	my ($self, $w, $register) = @_;
	my $crc16Shift_status = 0;

	for (my $i = 0; $i < 8; $i++) {
		$crc16Shift_status = (($register & 0x8000) != 0) ? 1 : 0;

		$register = ($register << 1) & 0xFFFF;
		$register = ($register | 1) if ( ($w & 0x80) == 0x80);
		$register = ($register ^ 0x1002) if ($crc16Shift_status);
		$w = $w << 1;
	}

	return $register & 0xFFFF;;
}

1;