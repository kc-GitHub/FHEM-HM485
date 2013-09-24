package HM485::devices;

our %definition = (
	'HMW-Sen-SC-12'	=> {
		'version'		=> 7,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW-Sen-SC-12-DR'	=> {
				'name'	=> 'RS485 shutter contact 12-channel (DIN rails)',
				'priority'	=> 2,												# ???
				'type'		=> 25,												# Device type
			},
			'HMW-Sen-SC-12-FM'	=> {
				'name'	=> 'RS485 shutter contact 12-channel (flush-mount)',
				'priority'	=> 2,												# ???
				'type'		=> 26,												# Device type
			},
		},
		'params' => {
			'HMW-Sen-SC-12_dev_master'	=> {
				'type'				=> 'master',
				'CENTRAL_ADDRESS'	=> {										# parameter id
					'hidden'		=> TRUE,									# should not vidible in UI ???
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
				'DIRECT_LINK_DEACTIVATE'	=> {								# no direct link available
					'hidden'		=> TRUE,									# should not vidible in UI ???
					'enforce'		=> TRUE,									# sould always set to this value ???
					'logical'		=> {
						'type'		=> 'boolean',								# parameter value type
						'default'	=> FALSE,
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 0.1,										# 1 bit
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> 0x0006,									# location of central adress in device
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
				'event'		=> TRUE,												# frame should triger event???
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
			0	=> {												
				'type'		=> 'MAINTENANCE',									# Channel Type
				'ui-flags'	=> 'internal',										# flages for UI rendering ???
				'class'		=> 'maintenance',
				'count'	=> 1,													# count of channels of this type it the device
				'params'	=> {
					'maint_ch_master'	=> {									# paramset id
						'type'	=> 'master',
					},
					'maint_ch_values'	=> {									# paramset id
						'type'	=> 'values',
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
			1	=> {
				'type'	=> 'SENSOR',											# Channel Type (simple on / off switch)
				'count'	=> 12,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 0 
				'params'	=> {
					'hmw_sensor_ch_master'	=> {								# why the master channel?
						'type'			=> 'MASTER',
						'address_start'	=> 0x07,
						'address_step'	=> 2,
						'INPUT_LOCKED'	=> {
							'logical'		=> {
								'type'		=> 'boolean',						# logical type (the availabe states) boolean -> on/off
								'default'	=> FALSE,							# the default state after power on the device ???
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
								'invert'	=> TRUE,
							}
						}
					},
					'hmw_sensor_ch_values'	=> {
						'type'	=> 'VALUES',
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