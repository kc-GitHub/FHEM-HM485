package HM485::Devicefile;

our %definition = (
	'HMW-LC-Bl1'	=> {
		'version'		=> 13,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_LC_Bl1_DR'	=> {
				'name'	=> 'rs485 blind actuator 1-channel (din rails)',
				'type'		=> 21,
			},
		},
		'params' => {
			'master'	=> {
				'logging_time'	=> {											# parameter id
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
						'address'	=> {
							'id'	=> 0x0001,
						},
					},
					'conversion'	=> {
						'type'		=> 'float_integer_scale', 					# wert wird beim speichern mit <factor> mutipliziert, beim lesen dividiert
						'factor'	=> 10,										# conversion factor
						'offset'	=> 0.0,										# ???
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
						'address'	=> {
							'id'	=> 0x0002,
						},
					},
				},
				'direct_link_deactivate'	=> {								# no direct link available
					'hidden'		=> 1,										# should not vidible in ui ???
					'enforce'		=> 1,										# sould always set to this value ???
					'logical'		=> {
						'type'		=> 'boolean',								# parameter value type
						'default'	=> 0,
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 0.1,										# 1 bit
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> {
							'id'	=> 0x0006,
						},
					},
				},
			},
		},
		'frames'	=> {														# supported frames ???
			'level_set'	=> {
				'type'		=> 0x78,											# x
				'dir'		=> 'to_device',
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {											# aditional frame parameter (level)
						'type'	=> 'int',										# value type
						'id'	=> 11.0,										# position in frame ???
						'size'	=> 1											# value length
					},
				},
			},
			'level_get'	=> {													# frame id
				'type'		=> 0x73,											# s
				'dir'		=> 'to_device', 
				'ch_field'	=> 10,												# position in frame ??? we need them???
			},
			'info_level'	=> {
				'type'		=> 0x69,											# i
				'dir'		=> 'from_device',
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {											# aditional frame parameter (level)
						'type'	=> 'int',										# value type
						'id'	=> 11.0,										# position in frame ???
						'size'	=> 1											# value length
					},
					'state_flags'	=> {										# aditional frame parameter (state flags)
						'type'	=> 'int',										# value type
						'id'	=> 12.4,										# position in frame ???
						'size'	=> 0.3											# value length
					},
				},
			},
			'stop'	=> {
				'type'		=> 0x78,											# x
				'dir'		=> 'to_device',
				'ch_field'	=> 10,
				'params'	=> {
					201	=> {
						'type'			=> 'int',
						'id'			=> 11.0,
						'size'			=> 1,
					},
				},
			},
			'key_event_short'	=> {
				'type'		=> 0x4B,											# K
				'dir'		=> 'from_device',
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'id'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 0									# parameter set always tu this value,short (0) long keypress (1)
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'id'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_event_long'	=> {
				'type'		=> 0x4B,											# K
				'dir'		=> 'from_device',
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'id'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 1									# parameter set always tu this value,short (0) long keypress (1)
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'id'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_sim_short'	=> {
				'type'			=> 0x4B,										# K
				'dir'			=> 'from_device',
				'ch_field'		=> 10,											# ???
				'rec_ch_field'	=> 11,											# ???
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'id'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 0									# parameter set always tu this value,short (0) long keypress (1)
					},
					'sim_counter'	=> {										# aditional frame parameter (sim_counter)
						'type'	=> 'int',										# value type
						'id'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_sim_long'	=> {
				'type'			=> 0x4B,										# K
				'dir'			=> 'from_device',
				'ch_field'		=> 10,											# ???
				'rec_ch_field'	=> 11,											# ???
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'id'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 1									# parameter set always tu this value,short (0) long keypress (1)
					},
					'sim_counter'	=> {										# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'id'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'set_lock'	=> {
				'type'		=> 0x6C,											# l
				'dir'		=> 'to_device',
				'ch_field'	=> 11,												# ???
				'params'	=> {
					'inhibit'	=> {											# aditional frame parameter (inhibit)
						'type'	=> 'int',										# value type
						'id'	=> 12.0,										# position in frame ???
						'size'	=> 1,											# value length
					},
				},
			},
			'toggle_install_test'	=> {
				'type'		=> 0x78,											# x
				'dir'		=> 'to_device',
				'ch_field'	=> 10,												# ???
				'params'	=> {
					'toggle_flag'	=> {										# aditional frame parameter (toggle_flag)
						'type'	=> 'int',										# value type
						'id'	=> 11.0,										# position in frame ???
						'size'	=> 1,											# value length
					},
				},
			},
		},
		'channels'	=> {
			'maintenance' => {
				'id'	=> 0,
				'count'	=> 1,
			},
			'key' => {
				'id'	=> 1,
				'physical_id_offset' => -1,
				'count'	=> 2,
			},
			'blind' => {
				'id'	=> 3,
				'physical_id_offset' => -1,
				'count'	=> 1,
			},
		}
	}
);

1;