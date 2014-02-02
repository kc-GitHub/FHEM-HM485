package HM485::Devicefile;

our %definition = (
	'HMW_LC_Bl1_0302'	=> {
		'version'		=> 7,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_LC_Bl1_DR'	=> {
				'name'	=> 'RS485 blind actuator 1-channel (DIN rails)',
				'type'		=> 21,
			},
		},
		'params' => {
			'master'	=> {
				'logging_time'	=> {
					'logical'		=> {
						'type'		=> 'float',
						'min'		=> 0.0,
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
						'factor'	=> 10,
						'offset'	=> 0.0
					}
				},
				'central_address'	=> {
					'hidden'		=> 1,
					'enforce'		=> 0x00000001,
					'logical'		=> {
						'type'		=> 'int',
					},
					'physical'	=> {
						'type'			=> 'int',
						'size'			=> 4,
						'interface'		=> 'eeprom',
						'address_id'	=> 0x0002
					}
				},
				'direct_link_deactivate'	=> {
					'hidden'		=> 1,
					'enforce'		=> 1,
					'logical'		=> {
						'type'		=> 'boolean',
						'default'	=> 0,
					},
					'physical'	=> {
						'type'			=> 'int',
						'size'			=> 0.1,
						'interface'		=> 'eeprom',
						'address_id'	=> 0x0006
					}
				},
			},
		},
		'frames'	=> {
			'level_set'	=> {
				'type'		=> 0x78,
				'dir'		=> 'to_device',
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 1 
					},
				},
			},
			'level_get'	=> {
				'type'		=> 0x73,
				'dir'		=> 'to_device', 
				'ch_field'	=> 10,
			},
			'info_level'	=> {
				'type'		=> 0x69,
				'dir'		=> 'from_device',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 1
					},
					'state_flags'	=> { 
						'type'	=> 'int',
						'id'	=> 12.4,
						'size'	=> 0.3
					},
				},
			},
			'stop'	=> {
				'type'		=> 0x78,
				'dir'		=> 'to_device',
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {
						'type'			=> 'int',
						'id'			=> 11.0,
						'size'			=> 1,
						'const_value'	=> 201
					},
				},
			},
			'key_event_short'	=> {
				'type'		=> 0x4B,
				'dir'		=> 'from_device',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {
						'type'			=> 'int',
						'id'			=> 12.0,
						'size'			=> 0.1,
						'const_value'	=> 0
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
						'const_value'	=> 1
					},
					'counter'	=> {
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
				'type'		=> 0x6C,
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
		},
		'channels'	=> {
			'maintenance' => {
				'id'		=> 0,
				'ui-flags'	=> 'internal',
				'class'		=> 'maintenance',
				'count'	=> 1,
				'params'	=> {
					'master'	=> {},
					'values'	=> {
						'unreach'	=> {
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
						'sticky_unreach'	=> {
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
						'config_pending'	=> {
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
			'key'	=> {
				'id'	=> 1,
				'count'	=> 2,
				'physical_id_offset'	=> -1,
				'link_roles'	=> {
					'source'	=> 'switch',
				},
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x07,
						'address_step'	=> 2,
						'input_type'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'switch, pushbutton',
								'default'	=> 'pushbutton',
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 0.1,
								'interface'		=> 'eeprom',
								'address_id'	=> 0.0
							}
						},
						'input_locked'	=> {
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
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'invert'	=> 1
							}
						},
						'long_press_time'	=> {
							'logical'	=> {
								'type'		=> 'float',
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
								'type'		=> 'float_integer_scale',
								'factor'	=> 10,
								'value_map'	=> {
									'type'	=> 'integer_integer_map',
									'01'	=> {
										'device_value'		=> 0xFF,
										'parameter_value'	=> 10,
										'from_device'		=> 1,
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
						'address_start'	=> 0x356,
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
							'operations'	=> 'event,read,write', 
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
							'operations'	=> 'event,read,write', 
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
					}
				}
			},
			'blind' => {
				'id'	=> 3,
				'count'	=> 1,
				'physical_id_offset'	=> -1,
				'link_roles'	=> {
					'target'	=> 'switch',
				},
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x0B,
						'address_step'	=> 7,
						'logging'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'off,on',
								'default'	=> 'on',
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 0.1,
								'interface'		=> 'eeprom',
								'address_id'	=> 0
							}
						},
						'change_over_delay'	=> {
							'logical'	=> {
								'type'		=> 'float',
								'min' 		=> 0.0,
								'max'	 	=> 25.5,
								'default'	=> 0.5,
								'unit'		=> 's',
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 10,
								'ofset'		=> 0.0,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 1,
								'interface'		=> 'eeprom',
								'address_id'	=> 1
							}
						},
						'reference_run_counter'	=> {
							'logical'	=> {
								'type'		=> 'integer',
								'min' 		=> 0,
								'max'	 	=> 100,
								'default'	=> 0,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 1,
								'interface'		=> 'eeprom',
								'address_id'	=> 2
							}
						},
						'reference_running_time_bottom_top'	=> {
							'logical'	=> {
								'type'		=> 'float',
								'min' 		=> 0.1,
								'max'	 	=> 6000,
								'default'	=> 50,
								'unit'		=> 's',
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 10,
								'ofset'		=> 0.0,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 2,
								'interface'		=> 'eeprom',
								'endian'		=> 'little',
								'address_id'	=> 3
							}
						},
						'reference_running_time_top_bottom'	=> {
							'logical'	=> {
								'type'		=> 'float',
								'min' 		=> 0.1,
								'max'	 	=> 6000,
								'default'	=> 50,
								'unit'		=> 's',
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 10,
								'ofset'		=> 0.0,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 2,
								'interface'		=> 'eeprom',
								'endian'		=> 'little',
								'address_id'	=> 5
							}
						}
					},
					'link'	=> {
						'peer_param'	=> 'sensor',
						'channel_param'	=> 'channel',
						'count'			=> 22,
						'address_start'	=> 0x12,
						'address_step'	=> 38,
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
									'default'	=> 255,
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
							'short_driving_mode'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'drive_via_next_end_position, drive_via_upper_end_position, drive_via_lower_end_position, drive_directly',
									'default'	=> 'drive_directly',
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 0.2,
									'interface'		=>	'eeprom',
									'address_id'	=>	6.4
								},
							},
							'short_toggle_use'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'use, dont_use',
									'default'	=> 'dont_use',
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	6.3
								},
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
							'short_off_level'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 1,
									'default'	=> 0.0,
									'unit'		=> '100%',
								},
								'conversion'	=> {
									'type'		=> 'float_integer_scale',
									'factor'	=> 200,
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	8
								},
							},
							'short_on_level'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 1,
									'default'	=> 0.0,
									'unit'		=> '100%',
								},
								'conversion'	=> {
									'type'		=> 'float_integer_scale',
									'factor'	=> 200,
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	9
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
									'address_id'	=>	10
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
									'address_id'	=>	12
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
									'address_id'	=>	14
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
									'address_id'	=>	16
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
							'short_max_time_first_dir'	=> {
								'logical'	=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 25.4,
									'default'	=> 25.5,
									'unit'		=> 's',
									'special_value'	=> {
										'not_used'	=> 25.5,
									}
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	18
								},
								'conversion'	=> {
									'type'		=> 'float_integer_scale',
									'factors'	=> '10',
									'offset'	=> 0.0,
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
							'short_jt_ondelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'refon',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	19
								}
							},
							'short_jt_ondelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'on',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	19.4
								}
							},
							'short_jt_rampon'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'on',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	19.0
								}
							},
							'short_jt_on'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'offdelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	20.4
								}
							},
							'short_jt_offdelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'refoff',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	21.0
								}
							},
							'short_jt_refoff'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'off',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	21.4
								}
							},
							'short_jt_rampoff'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'off',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	22.0
								}
							},
							'short_jt_off'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'ondelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=>	'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	22.4
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
									'address_id'	=>	7.7
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
									'address_id'	=>	7.6
								}
							},
							'long_driving_mode'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'drive_via_next_end_position, drive_via_upper_end_position, drive_via_lower_end_position, drive_directly',
									'default'	=> 'drive_directly',
								},
								'physical'		=> {
									'type'			=> 'int',
									'size'			=> 0.2,
									'interface'		=>	'eeprom',
									'address_id'	=> 7.4
								},
							},
							'long_toggle_use'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options' 	=> 'use, dont_use',
									'default'	=> 'dont_use',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.1,
									'interface'		=>	'eeprom',
									'address_id'	=>	7.3
								},
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
									'address_id'	=>	7.2
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
									'address_id'	=>	7.0
								}
							},
							'long_off_level'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 1.0,
									'default'	=> 0.0,
									'unit'		=> '100%',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	23
								},
								'conversion'	=> {
									'type'			=> 'float_integer_scale',
									'factor'		=> 200,
								}
							},
							'long_on_level'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 1.0,
									'default'	=> 1.0,
									'unit'		=> '100%',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	24
								},
								'conversion'	=> {
									'type'			=> 'float_integer_scale',
									'factor'		=> 200,
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
									'address_id'	=>	25
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
									'address_id'	=>	27
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
									'address_id'	=>	29
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
									'address_id'	=>	31
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
							'long_max_time_first_dir'	=> {
								'logical'		=> {
									'type'		=> 'float',
									'min' 		=> 0.0,
									'max'		=> 25.4,
									'default'	=> 0.5,
									'unit'		=> 's',
									'special_value'	=> {
										'not_used'	=> 25.5,
									}
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 1,
									'interface'		=>	'eeprom',
									'address_id'	=>	33
								},
								'conversion'	=> {
									'type'		=> 'float_configtime',
									'factor'	=> 10,
									'ofset'		=> 0.0,
								}
							},
							'long_jt_ondelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'refon',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	34.0
								}
							},
							'long_jt_refon'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'on',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	34.4
								}
							},
							'long_jt_rampon'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'on',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	35.0
								}
							},
							'long_jt_on'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'offdelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	35.4
								}
							},
							'long_jt_offdelay'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'refoff',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	36.0
								}
							},
							'long_jt_refoff'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'off',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	36.4
								}
							},
							'long_jt_rampoff'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'off',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	37.0
								}
							},
							'long_jt_off'	=> {
								'logical'		=> {
									'type'		=> 'option',
									'options'	=> 'ondelay, refon, rampon, on, offdelay, refoff, rampoff, off, no_jump_ignore_command',
									'default'	=> 'ondelay',
								},
								'physical'	=> {
									'type'			=> 'int',
									'size'			=> 0.4,
									'interface'		=> 'eeprom',
									'read_size'		=>	1,
									'address_id'	=>	37.4
								}
							}
						}
					},
					'values' => {
						'level'	=> {
							'operations'=> 'read,write,event',
							'control'	=> 'blind.level',
							'logical'	=> {
								'type'		=> 'int',
								'default'	=> 0,
								'min'		=> 0,
								'max'		=> 100,
								'unit'		=> '100%',
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'level',
								'set'	=> {
									'request'	=> 'level_set',
								},
								'get'	=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level',
								},
								'event'	=> {
									'frame'	=> 'info_level',
								},
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 2,
								'false'		=> 0,
								'true'		=> 200
							},
							'value_map'	=> {
								'type'	=> 'integer_integer_map',
								'01'	=> {
									'device_value'		=> 0x04,
									'parameter_value'	=> 1,
									'mask'				=> 0x04,
								},
								'02'	=> {
									'device_value'		=> 0x00,
									'parameter_value'	=> 0,
								},
								'03'	=> {
									'device_value'		=> 0x01,
									'parameter_value'	=> 1,
								},
								'04'	=> {
									'device_value'		=> 0x02,
									'parameter_value'	=> 1,
								},
								'05'	=> {
									'device_value'		=> 0x03,
									'parameter_value'	=> 0,
								}
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
						'direction'	=> {
							'operations'=> 'read,event',
							'ui_flags'	=> 'internal',
							'logical'	=> {
								'type'		=> 'option',
								'options' 	=> 'none, up, down, undefined',
								'default'	=> 'none',
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
							'value_map'	=> {
								'type'	=> 'option_integer',
								'01'	=> {
									'device_value'		=> 0x00,
									'parameter_value'	=> 0,
								},
								'02'	=> {
									'device_value'		=> 0x01,
									'parameter_value'	=> 1,
								},
								'03'	=> {
									'device_value'		=> 0x02,
									'parameter_value'	=> 2,
								},
								'04'	=> {
									'device_value'		=> 0x03,
									'parameter_value'	=> 3,
								}
							}
						},
						'stop'	=> {
							'operations'=> 'write',
							'control'	=> 'blind.stop',
							'logical'	=> {
								'type'		=> 'action',
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'dummy',
								'set'	=> {
									'request'	=> 'stop',
								},
							},
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
					}
				}
			}
		}
	}
);

1;