package HM485::Devicefile;

our %definition = (
	'HMW_RCV'	=>{
		'version'		=> 3,
		'models'	=> {
			'HMW_RCV_50'	=> {
				'name'	=> 'Virtual Remote Control 50 Keys',
				'type'	=> 0,
			},
		},
		'params' => {
			'master'	=> {},
		},
		'frames'	=> {
			'key_event_short'	=> {
				'type'			=> 0x4B,
				'dir'			=> 'from_device',
				'event'			=> 1,
				'ch_field'		=> 10,
				'rec_ch_field'	=> 11,
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
				'type'			=> 0x4B,
				'dir'			=> 'from_device',
				'event'			=> 1,
				'ch_field'		=> 10,
				'rec_ch_field'	=> 11,
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
			'toggle_install_test'	=> {
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
		'channels'	=> {
			'maintenance' => {
				'id'		=> 0,
				'ui-flags'	=> 'internal',
				'class'		=> 'maintenance',
				'count'	=> 1,
				'params'	=> {
					'master'	=> {},
					'values'	=> {},
				}
			},
			'virtual_key' => {
				'id'	=> 1,
				'count'	=> 50,
				'physical_id_offset'	=> -1,
				'link_roles'	=> {
					'source'	=> 'switch',
				},
				'params'	=> {
					'master'	=> {},
					'link'		=> {},
					'values' 	=> {
						'press_short'	=> {
							'operations'	=> 'event,write', 
							'control'		=> 'button.short',
							'loopback'		=> 1,
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'counter',
								'set'		=> {
									'request'	=> 'key_event_short',
								},
							},
						},
						'press_long'	=> {
							'operations'	=> 'event,write', 
							'control'		=> 'button.long',
							'loopback'		=> 1,
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'counter',
								'set'		=> {
									'request'	=> 'key_event_long',
								}
							}
						}
					}
				}
			}
		}
	}
);

1;