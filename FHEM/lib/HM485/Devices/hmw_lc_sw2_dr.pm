package HM485::Devicefile;

our %definition = (
	'HMW-LC-SW2-DR'	=> {
		'version'		=> 12,													# internal version number
		'eeprom-size'	=> 1024,												# the eprom size of the device
		'models'	=> {
			'HMW_LC_Sw2_DR'	=> {
				'name'			=> 'RS485 switch actuator 2-channel (DIN rails)',
				'type'			=> 17,
				'minFW_version'	=> 0x0303										# The device file only valid for devices with firmware 3.3 or greater
			},
		},
		'params' => {
			'master'	=> {
				'logging_time'	=> {											# time after state changes reported by device via message
					'logical'		=> {
						'type'		=> 'float',
						'min'		=> 0.1,
						'max'		=> 25.5,
						'default'	=> 2.0,
						'unit'		=> 's',
					},
					'physical'	=> {
						'type'			=> 'int',
						'size'			=> 1.0,
						'interface'		=> 'eeprom',
						'address_id'	=> 0x0001
					},
					'conversion'	=> {
						'type'		=> 'float_integer_scale',
						'factor'	=> 10,										# conversion factor
						'offset'	=> 0.0
					}
				},
				'central_address'	=> {										# all devices knowing the adress of their central.
					'hidden'		=> 1,										# the parameter should not visible by the user?
					'enforce'		=> 0x00000001,								# the central address is fixed in all devices. so the central must have 0x00000001
					'logical'		=> {
						'type'		=> 'int',
					},
					'physical'	=> {
						'type'			=> 'int',
						'size'			=> 4,									# the length of the data in eeprom
						'interface'		=> 'eeprom',							# This parameter ist stored in the device eeprom
						'address_id'	=> 0x0002								# start adress in device eeprom where this parameter resist
					}
				},
				'direct_link_deactivate'	=> {								# deactivate direct linking ???
					'hidden'		=> 1,
					'enforce'		=> 1,										# sould always set to this value ???
					'logical'		=> {
						'type'		=> 'boolean',
						'default'	=> 0,
					},
					'physical'	=> {
						'type'			=> 'int',
						'size'			=> 0.1,									# sizes such 0.x means there are only used x bits in the byte value
						'interface'		=> 'eeprom',
						'address_id'	=> 0x0006
					}
				},
			},
		},
		'frames'	=> {														# all supported frames
			'level_set'	=> {													# parameter id, must match to chanel/parameter/physical/value_id
				'type'		=> 0x78,											# x - frame
				'dir'		=> 'to_device',										# the frame is received by the device
				'event'		=> 1,												# frame maps only if received by event???, should triger event???
				'ch_field'	=> 10,												# the position of the command byte in whole frame. Count starts at index 0 behind the start char
				'params'	=> {
					'state'		=> {											# aditional frame parameter (state)
						'type'	=> 'int',										# value type
						'id'	=> 11.0,										# position in frame (at byte pos. 11)
						'size'	=> 1											# the length of the parameter data 
					},
				},
			},
			'level_get'	=> {
				'type'		=> 0x73,											# s - frame
				'dir'		=> 'to_device', 
				'ch_field'	=> 10,
			},
			'info_level'	=> {
				'type'		=> 0x69,											# i - frame
				'dir'		=> 'from_device',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 1
					},
					'state_flags'	=> {										# a second parameter data in the frame 
						'type'	=> 'int',
						'id'	=> 12.4,										# this parameter starts at bit 4 in byte 12
						'size'	=> 0.3											# the length ot this parameter is 3 bits
					},
				},
			},
			'key_event_short'	=> {
				'type'		=> 0x4B,											# K - frame
				'dir'		=> 'from_device',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {
						'type'			=> 'int',
						'id'			=> 12.0,
						'size'			=> 0.1,
						'const_value'	=> 0									# this frame is mapped to event only if this parameter is equal 0
					},
					'counter'	=> {
						'type'	=> 'int',
						'id'	=> 12.2,
						'size'	=> 0.6
					}
				}
			},
			'key_event_long'	=> {
				'type'		=> 0x4B,
				'dir'		=> 'from_device',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {
						'type'			=> 'int',
						'id'			=> 12.0,
						'size'			=> 0.1,
						'const_value'	=> 1									# this frame is mapped to event only if this parameter is equal 1
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',
						'id'	=> 12.2,
						'size'	=> 0.6
					}
				}
			},
			'key_sim_short'	=> {
				'type'			=> 0x4B,										# Key-Sim frames are 0xCB? A 0x4B with set 8 bit?
				'dir'			=> 'from_device',
				'ch_field'		=> 10,
				'rec_ch_field'	=> 11, 
				'params'	=> {
					'key'	=> {
						'type'			=> 'int',
						'id'			=> 12.0,
						'size'			=> 0.1,
						'const_value'	=> 0
					},
					'sim_counter'	=> {
						'type'	=> 'int',
						'id'	=> 12.2,
						'size'	=> 0.6
					},
				},
			},
			'key_sim_long'	=> {
				'type'			=> 0x4B,
				'dir'			=> 'from_device',
				'ch_field'		=> 10,
				'rec_ch_field'	=> 11,
				'params'	=> {
					'key'	=> {
						'type'			=> 'int',
						'id'			=> 12.0,
						'size'			=> 0.1,
						'const_value'	=> 1
					},
					'sim_counter'	=> {
						'type'	=> 'int',
						'id'	=> 12.2,
						'size'	=> 0.6
					}
				}
			},
			'set_lock'	=> {
				'type'		=> 0x6C,											# l - frame
				'dir'		=> 'to_device',
				'ch_field'	=> 11,
				'params'	=> {
					'inhibit'	=> {
						'type'	=> 'int',
						'id'	=> 12.0,
						'size'	=> 1.0
					}
				}
			},
			'toggle_install_test'	=> {										# no details at this time
				'type'		=> 0x78,
				'dir'		=> 'to_device',
				'ch_field'	=> 10,
				'params'	=> {
					'toggle_flag'	=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 1.0
					}
				}
			}
		},
		'channels'	=> {														# all supported channels
			'maintenance' => {													# the maintenance channel contains all device specific settings
				'id'		=> 0,												# the start uid of this channel in all channel collection
				'ui-flags'	=> 'internal',										# this chennel is not visible in the ui?
				'class'		=> 'maintenance',									# ???
				'count'	=> 1,													# count of channels of this type it the device
				'params'	=> {												# all channel parameter
					'master'	=> {},											# ??? we need them?
					'values'	=> {											# we need the master channel values???
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
						'config_pending'	=> {								# is set, if the device waiting for configuration data
							'operations'	=> 'read,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							}
						}
					}
				}
			},
			'key'	=> {														# channel for all keys
				'id'	=> 1,													# start id of this channel collection
				'count'	=> 2,													# count of channels of this type
				'physical_id_offset'	=> -1,									# = id + physical_id_offset, we need them?
				'link_roles'	=> {											# the roles of this channel in peering
					'source'	=> 'switch',									# this is a source of type switch
				},
				'params'	=> {
					'master'	=> {											# the master parameter channel contains all channel specific settings
						'address_start'	=> 0x07,								# adress start of channel params in eeprom
						'address_step'	=> 2,									# each data for channel contains 2 bytes (length)
						'input_type'	=> {									# type of the input
							'logical'	=> {
								'type'	=> 'option',							# this parameter is a select box with options
								'options' 	=> 'switch, pushbutton',			# available options in this order
								'default'	=> 'pushbutton',					# the default
							},
							'physical'	=> {
								'type'			=> 'int',						# parameter is a integer
								'size'			=> 0.1,							# parameter length ist 1 bit
								'interface'		=> 'eeprom',					# stored in eeprom
								'address_id'	=> 0.0							# parameter adress starts at: address_id + address_start + address_step * (id + physical_id_offset)
							}
						},
						'input_locked'	=> {									# is the input locked?
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 0.1,
								'interface'		=> 'eeprom',
								'address_id'	=> 0.1
							},
							'conversion'	=> {								# conversion config
								'type'		=> 'boolean_integer',
								'invert'	=> 1
							}
						},
						'long_press_time'	=> {								# time after the input recognise a long button press
							'logical'	=> {
								'type'		=> 'float',							# this parameter is a float
								'min'		=> 0.4,
								'max'		=> 5,
								'default'	=> 1.0,
								'unit'		=> 's',
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 1.0,
								'interface'		=> 'eeprom',
								'address_id'	=> 1.0
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',			# conversion config
								'factor'	=> 10,								# before saving values to eeprom we multiply the parameter with factor
								'value_map'	=> {
									'type'	=> 'integer_integer_map',			# parameter mapping configuration
									'01'	=> {
										'device_value'		=> 0xFF,			# if device value equal 0xFF
										'parameter_value'	=> 10,				# this mapped to parameter value 10
										'from_device'		=> 1,				# only data comes from device
										'to_device'			=> 0,
									}
								}
							}
						}
					},
					'link'	=> {
						'peer_param'	=> 'actuator',
						'channel_param'	=> 'channel',
						'count'			=> 28,
						'address_start'	=> 0x357,
						'address_step'	=> 6,
						'channel'	=> {
							'operations'	=> 'none', 
							'hidden'		=> 1,
							'logical'		=> {
								'type'		=> 'int',
								'min'		=> 0,
								'max'		=> 255,
								'default'	=> 255,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 1,
								'interface'		=> 'eeprom',
								'address_id'	=> 0
							}
						},
						'actuator'	=> {
							'operations'	=> 'none', 
							'hidden'		=> 1,
							'logical'		=> {
								'type'		=> 'address',
							},
							'physical'		=> {
								'type'		=> 'array',
								'01'		=> {
									'type'		=>	'int',
									'size'		=>	4,
									'interface'	=>	'eeprom',
									'address_id'	=> 1
								},
								'02'	=> {
									'type'		=>	'int',
									'size'		=>	1,
									'interface'	=>	'eeprom',
									'address_id'	=> 5
								}
							}
						}
					},
					'values'	=> {
						'press_short'	=> {
							'operations'	=> 'event,write', 
							'control'		=> 'button.short',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'counter',
								'event'		=> {
									'frame'	=> 'key_event_short',
								},
								'set'		=> {
									'request'	=> 'key_sim_short',
								},
							},
							'conversion'	=> {
								'type'			=> 'action_key_counter',
								'sim_counter'	=> 'sim_counter',
								'counter_size'	=> 6
							}
						},
						'press_long'	=> {
							'operations'	=> 'event,write', 
							'control'		=> 'button.long',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'counter',
								'event'		=> {
									'frame'	=> 'key_event_long',
								},
								'set'		=> {
									'request'	=> 'key_sim_long',
								}
							},
							'conversion'	=> {
								'type'			=> 'action_key_counter',
								'sim_counter'	=> 'sim_counter',
								'counter_size'	=> 6
							}
						},
						'install_test'	=> {
							'operations'	=> 'event', 
							'ui_flags'		=> 'internal',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'test_counter',
								'event'		=> {
									'frame'	=> 'key_event_short, key_event_long',
								}
							}
						}
					}
				}
			},
			'switch' => {
				'id'	=> 3,
				'count'	=> 2,
				'physical_id_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 0
				'link_roles'	=> {
					'target'	=> 'switch',
				},
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x0B,
						'address_step'	=> 2,
						'logging'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'on,off',
								'default'	=> 'on',
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 0.1,
								'interface'		=> 'eeprom',
								'address_id'	=> 0
							}
						}
					},
					'link'	=> {
						'peer_param'	=> 'sensor',
						'channel_param'	=> 'channel',
						'count'			=> 30,
						'address_start'	=> 0x0F,
						'address_step'	=> 28,
						'params'	=> {
							'ui_hint'	=> {
								'logical'		=> {
									'type'						=> 'string',
									'default'					=> '',
									'use_default_on_failure' 	=> 1,
								},
								'physical'		=> {
									'type'				=> 'string',
									'interface'			=> 'store',
									'save_on_change'	=> 1,
								}
							},
							'sensor'	=> {
								'operations'	=> 'none',
								'hidden'		=> 1,
								'logical'		=> {
									'type'		=> 'address',
								},
								'physical'		=> {
									'type'		=> 'array',
									'01'		=> {
										'type'			=>	'int',
										'size'			=>	4,
										'interface'		=>	'eeprom',
										'address_id'	=>	0
									},
									'02'	=> {
										'type'			=>	'int',
										'size'			=>	1,
										'interface'		=>	'eeprom',
										'address_id'	=>	4
									}
								}
							},
							'channel'	=> {
								'operations'	=> 'none',
								'hidden'		=> 1,
								'logical'		=> {
									'type'		=> 'int',
									'min'		=> 0,
									'max'		=> 255,
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	5
								}
							},
							'short_on_time_mode'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'minimal, absolute',
									'default'	=> 'absolute',
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	6.7
								}
							},
							'short_off_time_mode'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'minimal, absolute',
									'default'	=> 'absolute',
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	6.6
								}
							},
							'short_toggle_use'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'dont_use, direct, inverted',
									'default'	=> 'dont_use',
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 0.2,
									'interface'		=>	'eeprom',
									'address_id'	=>	6.4
								},
								'conversion'	=> {
									'type'		=> 'option_integer',
									'value_map'	=> {
										'01'	=> {
											'device_value'		=> 0x03,
											'parameter_value'	=> 0,
											'from_device'		=> 1,
											'to_device'			=> 1,
										},
										'02'	=> {
											'device_value'		=> 0x02,
											'parameter_value'	=> 1,
											'from_device'		=> 1,
											'to_device'			=> 1,
										},
										'03'	=> {
											'device_value'		=> 0x00,
											'parameter_value'	=> 2,
											'from_device'		=> 1,
											'to_device'			=> 1,
										}
									}
								}
							},
							'short_action_type'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'inactive, active',
									'default'	=> 'active',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	6.0
								},
							},
							'short_ondelay_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 0.0,
									'unit'		=> 's',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	7
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'short_on_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 16383000,
									'unit'		=> 's',
									'special_value'	=> {
										'not_used'	=> 16383000,
									}
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	9
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'short_offdelay_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 0,
									'unit'		=> 's',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	11
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'short_off_time'	=> {
								'logical'	=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 16383000,
									'unit'		=> 's',
									'special_value'	=> {
										'not_used'	=> 16383000,
									}
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	13
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'short_jt_ondelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'on',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'read_size'		=>	2,
									'address_id'	=>	15.0
								}
							},
							'short_jt_on'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'offdelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'read_size'		=>	2,
									'address_id'	=>	15.3
								}
							},
							'short_jt_offdelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'off',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'read_size'		=>	2,
									'address_id'	=>	15.6
								}
							},
							'short_jt_off'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'ondelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'read_size'		=>	2,
									'address_id'	=>	15.9
								}
							},
							'long_on_time_mode'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'minimal, absolute',
									'default'	=> 'absolute',
								},
								'physical'			=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	17.7
								}
							},
							'long_off_time_mode'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'minimal, absolute',
									'default'	=> 'absolute',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	17.6
								}
							},
							'long_toggle_use'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'dont_use, direct, inverted',
									'default'	=> 'dont_use',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.2,
									'interface'		=>	'eeprom',
									'address_id'	=>	17.4
								},
								'conversion'	=> {
									'type'	=> 'option_integer',
									'value_map'	=> {
										'01'	=> {
											'device_value'		=> 0x03,
											'parameter_value'	=> 0,
											'from_device'		=> 1,
											'to_device'			=> 1,
										},
										'02'	=> {
											'device_value'		=> 0x02,
											'parameter_value'	=> 1,
											'from_device'		=> 1,
											'to_device'			=> 1,
										},
										'03'	=> {
											'device_value'		=> 0x00,
											'parameter_value'	=> 2,
											'from_device'		=> 1,
											'to_device'			=> 1,
										}
									}
								}
							},
							'long_multiexecute'	=> {
								'logical'		=> {
									'type'		=> 'boolean',
									'default'	=> 1,
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	17.2
								}
							},
							'long_action_type'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'inactive, active',
									'default'	=> 'active',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	17.0
								}
							},
							'long_ondelay_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 0.0,
									'unit'		=> 's',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	18
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'long_on_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 16383000,
									'unit'		=> 's',
									'special_value'	=> {
										'not_used'	=> 16383000,
									}
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	20
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'long_offdelay_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 0.0,
									'unit'		=> 's',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	22
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'long_off_time'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 982980.0,
									'default'	=> 16383000,
									'unit'		=> 's',
									'special_value'	=> {
										'not_used'	=> 16383000,
									}
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 2,
									'interface'		=>	'eeprom',
									'endian'		=>	'little',
									'address_id'	=>	24
								},
								'conversion'	=> {
									'type'			=> 'float_configtime',
									'factors'		=> '0.1,1,60,1000',
									'value_size'	=> 1.6,
									'value_map'		=> {
										'type'	=> 'integer_integer_map',
										'01'	=> {
											'device_value'		=> 0xC000,
											'parameter_value'	=> 0xFFFF,
											'mask'				=> 0xC000,
										},
									}
								}
							},
							'long_jt_ondelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'on',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=> 'eeprom',
									'endian'		=> 'little',
									'read_size'		=>	2,
									'address_id'	=>	26.0
								}
							},
							'long_jt_on'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'offdelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=> 'eeprom',
									'endian'		=> 'little',
									'read_size'		=>	2,
									'address_id'	=>	26.3
								}
							},
							'long_jt_offdelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'off',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=> 'eeprom',
									'endian'		=> 'little',
									'read_size'		=>	2,
									'address_id'	=>	26.6
								}
							},
							'long_jt_off'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, on, offdelay, off, no_jump_ignore_command',
									'default'	=> 'ondelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.3,
									'interface'		=> 'eeprom',
									'endian'		=> 'little',
									'read_size'		=>	2,
									'address_id'	=>	26.9
								}
							}
						}
					},
					'values' => {												# all supported values (channel <-> value mapping)
						'state'	=> {											# the state value
							'operations'=> 'read,write,event',					# ??? we need this???
							'control'	=> 'switch.state',						# this value is displayed as switch state in ui
							'logical'	=> {
								'type'	=> 'boolean',							# this is a boolean value
								'default'	=> 0,								# default = 0
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',						# we need this?
								'value_id'	=> 'state',							# this value id mapped to frame
								'set'	=> {
									'request'	=> 'level_set',					# mapped only at set request (level_set) ???
								},
								'get'	=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level',
								},
								'event'	=> {
									'frame'	=> 'info_level',
								},
							},
							'conversion'	=> {								# conversion config
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,								# values > treshold evaluated to true
								'false'		=> 0,								# 0 is false
								'true'		=> 200								# 200 is true
							}
						},
						'working' => {
							'operations'=> 'read,event',
							'ui_flags'	=> 'internal',
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state_flags',
								'get'	=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level',
								},
								'event'	=> {
									'frame'	=> 'info_level, ack_status',
								},
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
							}
						},
						'inhibit' => {
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
								'value_id'	=> 'inhibit',
								'set'	=> {
									'request'	=> 'set_lock',
								}
							}
						},
						'install_test' => {
							'operations'=> 'write',
							'ui_flags'	=> 'internal',
							'loopback'	=> 1,
							'logical'	=> {
								'type'	=> 'action',
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'toggle_flag',
								'no_init'	=> 'true',
								'set'	=> {
									'request'	=> 'toggle_install_test',
								}
							},
							'conversion'	=> {
								'type'		=> 'toggle',
								'value'	=> 'state'
							}
						}
					}
				}
			}
		}
	}
);

1;