package HM485::Devicefile;

our %definition = (
	'HMW_Sen_SC_12'	=> {
		'version'		=> 7,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_Sen_SC_12_DR'	=> {
				'name'	=> 'RS485 shutter contact 12-channel (DIN rails)',
				'type'		=> 25,
			},
			'HMW_SEN_SC_12_FM'	=> {
				'name'	=> 'RS485 shutter contact 12-channel (flush-mount)',
				'type'		=> 26,
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
						'address_id'	=> 0x0002
					}
				}
			},
			'master'	=> {
				'direct_link_deactivate'	=> {
					'hidden'		=> 1,
					'enforce'		=> 1,
					'logical'		=> {
						'type'		=> 'boolean',
					},
					'physical'		=> {
						'type'		=> 'int',
						'size'		=> 0.1,
						'interface'	=> 'eeprom',
						'address_id'	=> 0x0006
					}
				}
			}
		},
		'frames'	=> {
			'level_get'	=> {
				'type'		=> 0x53,
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
			'sensor'	=> {
				'id'	=> 1,
				'count'	=> 12,
				'physical_id_offset'	=> -1, 
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x07,
						'address_step'	=> 2,
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
					},
					'values'	=> {
						'sensor'	=> {
							'operations'	=> 'read,event', 
							'control'		=> 'door_sensor.state',
							'logical'		=> {
								'type'		=> 'boolean',
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
									'frame'					=> 'info_level',
									'auth_violate_policy'	=> 'reject'			# what is this
								}
							},
						}
					},
					'install_test' => {
						'operations'=> 'event',
						'ui_flags'	=> 'internal',
						'logical'	=> {
							'type'	=> 'action',
						},
						'physical'	=> {
							'type'		=> 'int',
							'interface'	=> 'command',
							'value_id'	=> 'test_counter',
							'event'	=> {
								'frame'	=> 'info_level',
							}
						},
					}
				}
			},
		}
	}
);

1;