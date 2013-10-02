package HM485::Devices;

our %definition = (
	'HMW-Sen-SC-12'	=> {
		'version'		=> 7,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_Sen_SC_12_DR'	=> {
				'name'	=> 'rs485 shutter contact 12-channel (din rails)',
				'type'		=> 25,
			},
			'HMW_SEN_SC_12_FM'	=> {
				'name'	=> 'rs485 shutter contact 12-channel (flush-mount)',
				'type'		=> 26,
			},
		},
		'params' => {
			'master'	=> {
				'central_address'	=> {										# parameter id
					'hidden'		=> 1,										# should not vidible in ui ???
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
				'central_address'	=> {
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
				'type'		=> 0x73,											# s
				'dir'		=> '<',												# prefered communication direction < means to-device, we need them??? 
				'ch_field'	=> 10,												# position in frame ??? we need them???
			},
			'info_level'	=> {
				'type'		=> 0x69,											# i
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
			'maintenance'	=> {												
				'id'		=> 0,
				'ui-flags'	=> 'internal',										# flages for ui rendering ???
				'class'		=> 'maintenance',
				'count'	=> 1,													# count of channels of this type it the device
				'params'	=> {
					'master'	=> {
					},
					'values'	=> {
						'unreach'	=> {										# this parameter is set when device is not reachable
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
						'sticky_unreach'	=> {								# this parameter is set when device is not reachable again
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
						'config_pending'	=> {								# not used this time with fhem
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
			'sensor'	=> {
				'id'	=> 1,
				'count'	=> 12,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 0 
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x07,
						'address_step'	=> 2,
						'input_locked'	=> {
							'logical'		=> {
								'type'		=> 'boolean',						# logical type (the availabe states) boolean -> on/off
								'default'	=> 0,								# the default state after power on the device ???
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'size'		=> 0.1,								# 1 bit
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
					'values'	=> {
						'sensor'	=> {
							'operations'	=> 'read,event',					# which type of actions supports the channel ??? 
							'ctrl'			=> 'door_sensor.state',				# ui related ???
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'get'		=> {								# getter (fhem get) ???
									'request'	=> 'level_get',					# request a level_get frame on get
									'response'	=> 'info_level'					# expect info_level frame on get
								},
								'event'		=> {								# event (fhem notify) ???
									'frame'					=> 'info_level',		# trigger event on info_level frame
									'auth_violate_policy'	=>	'reject',		#???
								},
							},
						},
						'install_test'	=> {
							'operations'	=> 'event',							# which type of actions supports the channel ??? 
							'ui_flags'		=> 'internal',
							'logical'		=> {
								'type'		=> 'action',						# ???
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'value_id'	=> 'test_counter',					# ???
								'event'		=> {								# event (fhem notify) ???
									'frame'					=> 'info_level'		# trigger event on info_level frame
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