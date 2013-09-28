package HM485::devices;

our %definition = (
	'HMW-Sen-SC-12'	=> {
		'version'		=> 7,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_Sen_SC_12_DR'	=> {
				'name'	=> 'RS485 shutter contact 12-channel (DIN rails)',
				'type'		=> 25,
			},
			'HMW_Sen_SC_12_FM'	=> {
				'name'	=> 'RS485 shutter contact 12-channel (flush-mount)',
				'type'		=> 26,
			},
		},
		'params' => {
			'master'	=> {
				'CENTRAL_ADDRESS'	=> {										# parameter id
					'hidden'		=> 1,										# should not vidible in UI ???
					'enforce'		=> 0x00000001,								# sould always set to this value ???
					'logical'		=> {
						'type'		=> 'int',									# parameter value type
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 4,										# 4 bytes
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> 0x0002,									# location of central adress in device
					},
				},
				'CENTRAL_ADDRESS'	=> {
					'hidden'		=> 1,
					'enforce'		=> 0x00000001,
					'logical'		=> {
						'type'		=> 'int',
					},
					'physical'		=> {
						'type'		=> 'int',
						'size'		=> 4,
						'interface'	=> 'eeprom',
						'address'	=> 0x0002,
					},
				},
			},
		},
		'frames'	=> {														# supported frames ???
			'level_get'	=> {													# frame id
				'type'		=> 'S',												# frame type
				'dir'		=> '<',												# prefered communication direction < means to-device, we need them??? 
				'ch_field'	=> 10,												# position in frame ??? we need them???
			},
			'info_level'	=> {
				'type'		=> 'i',
				'dir'		=> '>',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {											# aditional frame parameter (state)
						'type'	=> 'int',										# value type
						'index'	=> 11.0,										# position in frame ???
						'size'	=> 1											# value length
					},
				},
			},
		},
		'channels'	=> {
			'Maintenance'	=> {												
				'id'		=> 0,
				'ui-flags'	=> 'internal',										# flages for UI rendering ???
				'class'		=> 'maintenance',
				'count'	=> 1,													# count of channels of this type it the device
				'params'	=> {
					'Master'	=> {
					},
					'Values'	=> {
						'UNREACH'	=> {										# this parameter is set when device is not reachable
							'operations'	=> 'read,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
						'STICKY_UNREACH'	=> {								# this parameter is set when device is not reachable again
							'operations'	=> 'read,write,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							}
						},
						'CONFIG_PENDING'	=> {								# not used this time with FHEM
							'operations'	=> 'read,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							}
						},
					},
				},
			},
			'Sensor'	=> {
				'id'	=> 1,
				'count'	=> 12,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 0 
				'params'	=> {
					'Master'	=> {
						'address_start'	=> 0x07,
						'address_step'	=> 2,
						'INPUT_LOCKED'	=> {
							'logical'		=> {
								'type'		=> 'boolean',						# logical type (the availabe states) boolean -> on/off
								'default'	=> 0,								# the default state after power on the device ???
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'size'		=> 0.1,								# 1 Bit
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> +0.1								# 1 bit each channel
								},
							},
							'conversion'	=> {
								'type'		=> 'boolean-int',					# conversion type @see logical / physical types 
								'invert'	=> 1,
							}
						}
					},
					'Values'	=> {
						'SENSOR'	=> {
							'operations'	=> 'read,event',					# which type of actions supports the channel ??? 
							'ctrl'			=> 'DOOR_SENSOR.STATE',				# ui related ???
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'get'		=> {								# getter (FHEM GET) ???
									'request'	=> 'LEVEL_GET',					# request a LEVEL_GET frame on get
									'response'	=> 'INFO_LEVEL'					# expect INFO_LEVEL frame on get
								},
								'event'		=> {								# event (FHEM NOTIFY) ???
									'frame'					=> 'INFO_LEVEL',		# trigger event on INFO_LEVEL frame
									'auth_violate_policy'	=>	'reject',		#???
								},
							},
						},
						'INSTALL_TEST'	=> {
							'operations'	=> 'event',							# which type of actions supports the channel ??? 
							'ui_flags'		=> 'internal',
							'logical'		=> {
								'type'		=> 'action',						# ???
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'value_id'	=> 'TEST_COUNTER',					# ???
								'event'		=> {								# event (FHEM NOTIFY) ???
									'frame'					=> 'INFO_LEVEL'		# trigger event on INFO_LEVEL frame
								},
							},
						}
					},
				}
			},
		}
	}
);

1;