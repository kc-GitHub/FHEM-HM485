package HM485::devices;

our %definition = (
	'HMW-IO12-SW7'	=> {
		'version'		=> 11,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_IO_12_Sw7_DR'	=> {
				'name'	=> 'RS485 I/O module 12-channel in and switch actuator 7-channel (DIN rails)',
				'type'		=> 18,
			},
		},
		'params' => {
			'master'	=> {
				'LOGGING_TIME'	=> {											# parameter id
					'logical'		=> {										# time after state changes reeported by device via message
						'type'		=> 'float',									# parameter value type
						'min'		=> 0.5,
						'max'		=> 25.5,
						'default'	=> 2.0,
						'unit'		=> 's',
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 1.0,										# 1 byte
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> 0x0001,									# location of central adress in device
					},
					'conversion'	=> {
						'type'		=> 'float_integer_scale', 					# wert wird beim speichern mit <factor> mutipliziert, beim lesen dividiert
						'factor'	=> 10,										# conversion factor
						'offset'	=> 0.0,										# ???
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
				'DIRECT_LINK_DEACTIVATE'	=> {								# no direct link available
					'hidden'		=> 1,										# should not vidible in UI ???
					'enforce'		=> 1,										# sould always set to this value ???
					'logical'		=> {
						'type'		=> 'boolean',								# parameter value type
						'default'	=> 0,
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
		'frames'	=> {
			'level_set'	=> {
				'type'		=> 'x',
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
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
					'state_flags'	=> {										# aditional frame parameter (state flags)
						'type'	=> 'int',										# value type
						'index'	=> 12.4,										# position in frame ???
						'size'	=> 0.3											# value length
					},
				},
			},
			'key_event_short'	=> {
				'type'		=> 'K',
				'dir'		=> '>',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 0									# Parameter set always tu this value,short (0) long keypress (1)
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_event_long'	=> {
				'type'		=> 'K',
				'dir'		=> '>',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 1									# Parameter set always tu this value,short (0) long keypress (1)
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_sim_short'	=> {
				'type'			=> 'K',
				'dir'			=> '>',											# prefered communication direction > means from-device, we need them???
				'ch_field'		=> 10,											# ???
				'rec_ch_field'	=> 11,											# ???
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 0									# Parameter set always tu this value,short (0) long keypress (1)
					},
					'sim_counter'	=> {										# aditional frame parameter (sim_counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_sim_long'	=> {
				'type'			=> 'K',
				'dir'			=> '>',											# prefered communication direction > means from-device, we need them???
				'ch_field'		=> 10,											# ???
				'rec_ch_field'	=> 11,											# ???
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 1									# Parameter set always tu this value,short (0) long keypress (1)
					},
					'sim_counter'	=> {										# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'set_lock'	=> {
				'type'		=> 'l',
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
				'ch_field'	=> 10,												# ???
				'params'	=> {
					'inhibit'	=> {											# aditional frame parameter (inhibit)
						'type'	=> 'int',										# value type
						'index'	=> 12.0,										# position in frame ???
						'size'	=> 1,											# value length
					},
				},
			},
			'toggle_install_test'	=> {
				'type'		=> 'x',
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
				'ch_field'	=> 10,												# ???
				'params'	=> {
					'toggle_flag'	=> {										# aditional frame parameter (toggle_flag)
						'type'	=> 'int',										# value type
						'index'	=> 11.0,										# position in frame ???
						'size'	=> 1,											# value length
					},
				},
			},
		},
		'channels'	=> {
			'Maintenance' => {
				'id'		=> 0,
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
			'Key'	=> {
				'id'	=> 1,
				'count'	=> 12,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 0
				'link_roles'	=> {
					'source'	=> 'SWITCH',
				},
				'params'	=> {
					'Master'	=> {
						'address_start'	=> 0x07,
						'address_step'	=> 2,
						'INPUT_TYPE'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'Switch, Pushbutton',
								'default'	=> 'Pushbutton',
							},
							'physical'	=> {
								'type'	=> 'int',
								'size'	=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.0
								},
							},
						},
						'INPUT_LOCKED'	=> {
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'size'		=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.1
								},
							},
							'conversion'	=> {
								'type'	=> 'boolean_integer',
								'invert'	=> 1
							},
						},
						'LONG_PRESS_TIME'	=> {
							'logical'	=> {
								'type'		=> 'float',
								'min'		=> 0.4,
								'max'		=> 5,
								'default'	=> 1.0,
								'unit'		=> 's',
							},
							'physical'	=> {
								'type'		=> 'int',
								'size'		=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 1
								},
							},
							'conversion'	=> {
								'type'	=> 'float_integer_scale',
								'factor'	=> 10
							},
							# ToDo: conversion integer_integer_map @see xml file
						},
					},
					'Link'	=> {
						'peer_param'	=> 'ACTUATOR',
						'channel_param'	=> 'CHANNEL',
						'count'			=> 27,
						'address_start'	=> 0x359,
						'address_start'	=> 0x359,
						'address_step'	=> 6,
						'CHANNEL'	=> {
							'operations'	=> 'none',							# which type of actions supports the channel ??? 
							'hidden'		=> 1,
							'logical'		=> {
								'type'		=> 'int',
								'min'		=> 0,
								'max'		=> 255,
								'default'	=> 255,
							},
							'physical'		=> {
								'type'		=> 'int',
								'size'		=> 1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0,
								},
							},
						},
						'ACTUATOR'	=> {
							'operations'	=> 'none',							# which type of actions supports the channel ??? 
							'hidden'		=> 1,
							'logical'		=> {
								'type'		=> 'address',
							},
							'physical'		=> {
								'array'		=> {
									'size'		=> 1,
									'interface'	=> 'eeprom',
									'address'	=> {
										'index'	=> 0,
									},
								},
								'integer'	=> {
									'size'		=> 1,
									'interface'	=> 'eeprom',
									'address'	=> {
										'index'	=> 5,
									},
								},
							},
						}
					},
					'Values'	=> {
						'Press_Short'	=> {
							'operations'	=> 'event,read,write', 
							'control'		=> 'BUTTON.SHORT',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'COUNTER',
								'event'		=> {
									'frame'	=> 'KEY_EVENT_SHORT',
								},
								'set'		=> {
									'request'	=> 'KEY_SIM_SHORT',
								},
							},
							'conversion'	=> {
								'type'			=> 'action_key_counter',
								'sim_counter'	=> 'SIM_COUNTER',
								'counter_size'	=> 6,
							},
						},
						'Press_Long'	=> {
							'operations'	=> 'event,read,write', 
							'control'		=> 'BUTTON.LONG',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'COUNTER',
								'event'		=> {
									'frame'	=> 'KEY_EVENT_LONG',
								},
								'set'		=> {
									'request'	=> 'KEY_SIM_LONG',
								},
							},
							'conversion'	=> {
								'type'			=> 'action_key_counter',
								'sim_counter'	=> 'SIM_COUNTER',
								'counter_size'	=> 6,
							},
						},
					},
				}
			},
			'Switch' => {
				'id'	=> 13,
				'count'	=> 7,
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 0
				'link_roles'	=> {
					'target'	=> 'SWITCH',
				},
				'params'	=> {
					'Master'	=> {
						'address_start'	=> 0x1F,
						'address_step'	=> 2,
						'LOGGING'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'On,Off',
								'default'	=> 'On',
							},
							'physical'	=> {
								'type'	=> 'int',
								'size'	=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.0
								},
							},
						},
					},
					'Link'	=> {
						'peer_param'	=> 'SENSOR',
						'channel_param'	=> 'CHANNEL',
						'count'			=> 29,
						'address_start'	=> 0x2D,
						'address_step'	=> 28,
						'LOGGING'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'On,Off',
								'default'	=> 'On',
							},
							'physical'	=> {
								'type'	=> 'int',
								'size'	=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.0
								},
							},
						},
					},
					'Values' => {
						'state'	=> {
							'operations'=> 'read,write,event',
							'control'	=> 'SWITCH.STATE',
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'set'	=> {
									'request'	=> 'LEVEL_SET',
								},
								'get'	=> {
									'request'	=> 'LEVEL_GET',
									'response'	=> 'INFO_LEVEL',
								},
								'event'	=> {
									'frame'	=> 'INFO_LEVEL',
								},
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,
								'false'		=> 0,
								'true'		=> 200,
							},
						},
						'Working' => {
							'operations'=> 'read,event',
							'ui_flags'	=> 'internal',
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'get'	=> {
									'request'	=> 'LEVEL_GET',
									'response'	=> 'INFO_LEVEL',
								},
								'event'	=> {
									'frame_1'	=> 'INFO_LEVEL',
									'frame_2'	=> 'ACK_STATUS',
								},
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
							},
						},
						'Inhibit' => {
							'operations'=> 'read,write,event',
							'control'	=> 'none',
							'loopback'	=> 1,
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'set'	=> {
									'request'	=> 'SET_LOCK',
								},
							},
						},
					},
				},
			},
		}
	}
);

1;