package HM485;

use strict;

our %commands = (
	'21' => 'Reset',										# (!) to device
	'41' => 'Announce',										# (A) from device
	'43' => 'Reread config',								# (C) to device
	'45' => '45 - unknown',									# (E) to device ???,
	'4B' => 'Key press',									# (K) to/from  device
	'52' => 'Read eeprom',									# (R) to device
	'53' => 'Level get',									# (S) to device
	'57' => 'Write eeprom',									# (W) to device
	'5A' => 'End discovery mode',							# (Z) to device
	'63' => 'HS485 Delete target address',					# (c) needed for HM485 anymore ???
	'65' => '65 - unknown (response for event 45?)',		# (e) ???
	'67' => 'Firmware update related',						# (g) to device
	'68' => 'Read Moduletype and hardware version',			# (h) to device
	'69' => 'Info level',									# (i) from device
	'6C' => 'Set lock',										# (l) to device
	'6E' => 'get serial number',							# (n) to device
	'70' => 'Firmware update related (get packet size)',	# (p) to device
	'71' => 'HS485 Add target address',						# (q) needed for HM485 anymore?
	'72' => 'Firmware update related (read firmware)',		# (r) to device
	'73' => 'Actor set',									# (s) to device
	'75' => 'Start module update',							# (u) to device
	'76' => 'Read firmware version',						# (v) to device
	'77' => 'Firmware update related (write firmware)',		# (w) to device
	'78' => 'Level set',									# (x) to device
	'7A' => 'Start discovery mode',							# (z) to device
	'CB' => 'Key press simmulation',						# (Ë) to device
);

our %responseAttrMap = (
	'68' => 'model',
	'6E' => 'serialNr',
	'76' => 'firmwareVersion',
);

#FRAME_START_SHORT{0xFE};

use constant {
#	FRAME_START_SHORT		=> 0xFE,
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
	
	MIN_BUSY_TIME_MS		=> 5,
	WORST_CASE_BUSY_TIME_MS	=> 100,		# 100ms

	### Commands to interface
	CMD_INITIALIZE       => 0x3E,
	CMD_DISCOVERY        => 0x44,
	CMD_KEEPALIVE        => 0x4B,
	CMD_SEND             => 0x53,

	### Commands from interface
	CMD_RESPONSE         => 0x72,
	CMD_ALIVE            => 0x61,
	CMD_EVENT            => 0x65,
	CMD_DISCOVERY_RESULT => 0x64,
	CMD_DISCOVERY_END    => 0x63,
};

1;