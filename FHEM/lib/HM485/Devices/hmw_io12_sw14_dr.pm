package HM485::Devicefile;

our %definition = (
	'HMW-IO-12-SW14'	=>{
		'version'		=> 12,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_IO_12_Sw14_DR'	=> {
				'name'	=> 'RS485 I/O module 12-channel in and switch actuator 14-channel (DIN rails)',
				'type'	=> 28,
			},
		},
		'params' => {
			'master'	=> {
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
						'address'	=> {
							'id'	=> 0x0002
						}
					}
				}
			}
		},
		'frames'	=> {
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
					'state'		=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 2
					}
				}
			},
			'info_frequency'	=> {
				'type'		=> 0x69,
				'dir'		=> 'from_device',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 3
					},
				}
			},
			'level_set'	=> {
				'type'		=> 0x73,
				'dir'		=> 'to_device',
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'	=> 'int',
						'id'	=> 11.0,
						'size'	=> 2
					}
				}
			}
		},
		'channels'	=> {
			'maintenance'	=> {
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
			'digitaloutput'	=> {
				'id'	=> 1,
				'count'	=> 6,
				'physical_id_offset'	=> -1, 
				'params'	=> {
					'master'	=> {},
					'values'	=> {
						'state'	=> {
							'operations'	=> 'read,write,event', 
							'control'		=> 'switch.state',
							'logical'		=> {
								'type'		=> 'boolean',
								'default'	=> 0,
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'set'		=> {
									'request'	=> 'level_set'
								},
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								}
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,
								'false'		=> 0,
								'true'		=> 1023
							}
						}
					}
				}
			},
			'digital_analog_output'	=> {
				'id'	=> 7,
				'count'	=> 8,
				'physical_id_offset'	=> -1,
				'spechial_param'	=> {
					'behaviour'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'			=> {
							'type'			=> 'int',
							'size'			=> 0.1,
							'interface'		=> 'eeprom',
							'address_id'	=> 7.0,
							'address_step'	=> 0.1 
						}
					}
				}, 
				'params'	=> {
					'master'	=> {
						'behaviour'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> 'analog_output, digital_output',
								'default'	=> 'digital_output'
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
								'value_id'	=> 'behaviour'
							},
						},
						'pulsetime'	=> {
							'logical'	=> {
								'type'	=> 'float',
								'min'	=> 0.0,
								'max'	=> 600.0,
								'unit'	=> 's'
							},
							'physical'		=> {
								'type'		=> 'int',
								'size'		=> 2,
								'interface'	=> 'eeprom',
								'address_id'	=> 16,
								'address_step'	=> 2 
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 100,
								'offset'	=> 0.0,
								'value_map'	=>	{
									'type'	=> 'integer_integer_map',
									'01'	=> {
										'device_value'		=> 0xFFFF,
										'parameter_value'	=> 0,
										'from_device'		=> 1,
										'to_device'			=> 0
									}
								}
							}
						}
					},
					'values'	=> {
						'frequency' => {
							'operations'	=> 'read,write,event', 
							'control'		=> 'digital_analog_output.frequency',
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0.0,
								'max'		=> 50000.0,
								'unit'		=> 'mHz',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'set'		=> {
									'request'	=> 'level_set'
								},
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								}
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
							}
						}
					}
				},
				'subconfig'	=> {												# ???
					'master'	=> {
						'behaviour'	=> {
							'ui_flags'	=> 'transform',
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> 'analog_output, digital_output',
								'default'	=> 'digital_output',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
								'value_id'	=> 'behaviour',
							}
						}
					},
					'values'	=> {
						'state'	=> {
							'operations'	=> 'read,write,event',
							'control'		=> 'switch.state',
							'logical'		=> {
								'type'		=> 'boolean',
								'default'	=> 0,
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'set'		=> {
									'request'	=> 'level_set'
								},
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								}
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,
								'false'		=> 0,
								'true'		=> 1023
							}
						}
					}
				}
			},
			'digital_input'	=> {
				'id'	=> 15,
				'count'	=> 6,
				'physical_id_offset'	=> -1,
				'spechial_param'	=> {
					'behaviour'	=> {
						'logical'	=> {
							'type'	=> 'int',
						},
						'physical'			=> {
							'type'			=> 'int',
							'size'			=> 0.1,
							'interface'		=> 'eeprom',
							'address_id'	=> 9.0,
							'address_step'	=> 0.1 
						}
					}
				}, 
				'params'	=> {
					'master'	=> {
						'behaviour'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> 'frequency_input, digital_input',
								'default'	=> 'digital_input',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
								'value_id'	=> 'behaviour'
							}
						}
					},
					'values'	=> {
						'frequency'	=> {
							'operations'	=> 'read,event',
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0,
								'max'		=> 350000,
								'unit'		=> 'mHz',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								}
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 1
							}
						}
					}
				},
				'subconfig'	=> {												# ???
					'master'	=> {
						'behaviour'	=> {
							'ui_flags'	=> 'transform',
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> 'frequency_input, digital_input',
								'default'	=> 'digital_input',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
								'value_id'	=> 'behaviour',
							}
						}
					},
					'values'	=> {
						'state'	=> {
							'operations'	=> 'read,event',
							'logical'		=> {
								'type'		=> 'boolean',
								'default'	=> 0,
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								}
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,
								'false'		=> 0,
								'true'		=> 1023
							}
						}
					}
				}
			},
			'digital_analog_input'	=> {
				'id'	=> 21,
				'count'	=> 6,
				'physical_id_offset'	=> -1,
				'spechial_param'	=> {
					'behaviour'	=> {
						'logical'	=> {
							'type'	=> 'int',
						},
						'physical'	=> {
							'type'			=> 'int',
							'size'			=> 0.1,
							'interface'		=> 'eeprom',
							'address_id'	=> 8.0,
							'address_step'	=> 0.1 
						}
					}
				},
				'params'	=> {
					'master'	=> {
						'behaviour'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> 'analog_input, digital_input',
								'default'	=> 'digital_input'
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
								'value_id'	=> 'behaviour'
							},
						},
						'calibration'	=> {
							'logical'		=> {
								'type'		=> 'int',
								'min'		=> -127,
								'max'		=> 127,
							},
							'physical'	=> {
								'type'			=> 'int',
								'size'			=> 1,
								'interface'		=> 'eeprom',
								'address_id'	=> 10,
								'address_step'	=> 1 
							},
							'conversion'	=> {
								'type'		=> 'integer_integer_scale',
								'offset'	=> 127,
								'value_map'	=> {
									'type'	=> 'integer_integer_map',
									'01'	=> {
										'device_value'		=> 0xFF,
										'parameter_value'	=> 127,
										'from_device'		=> 1,
										'to_device'			=> 0
									}
								}
							}
						}
					},
					'values'	=> {
						'value' => {
							'operations'	=> 'read,event', 
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0,
								'max'		=> 1000,
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								},
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',
								'factor'	=> 1
							}
						}
					}
				},
				'subconfig'	=> {												# ???
					'master'	=> {
						'behaviour'	=> {
							'ui_flags'	=> 'transform',
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> 'analog_input, digital_input',
								'default'	=> 'digital_input',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
								'value_id'	=> 'behaviour',
							}
						}
					},
					'values'	=> {
						'state'	=> {
							'operations'	=> 'read,event',
							'logical'		=> {
								'type'		=> 'boolean',
								'default'	=> 0,
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'get'		=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level'
								},
								'event'		=> {
									'frame'	=> 'info_level'
								}
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,
								'false'		=> 0,
								'true'		=> 1023
							}
						}
					}
				}
			}
		}
	}
);

1;