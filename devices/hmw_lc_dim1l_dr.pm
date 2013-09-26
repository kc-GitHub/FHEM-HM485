package HM485::devices;

our %definition = (
	'HMW-LC-Dim1L'	=> {
		'version'		=> 11,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_LC_Dim1L_DR'	=> {
				'name'	=> 'RS485 dimming actuator 1-channel leading edge (DIN rails)',
				'type'		=> 20,
			},
		},
		'params' => {
			'master'	=> {
				'type'				=> 'master',
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
					'hidden'		=> TRUE,
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
			'level_set'	=> {
				'type'		=> 'x',
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
				'event'		=> TRUE,											# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {											# aditional frame parameter (level)
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
				'event'		=> TRUE,											# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'level'		=> {											# aditional frame parameter (level)
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
				'event'		=> TRUE,											# frame should triger event???
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
				'event'		=> TRUE,											# frame should triger event???
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
				'ch_field'	=> 11,												# ???
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
				'id'	=> 0,
				'count'	=> 1,
			},
			'Key' => {
				'id'	=> 1,
				'physical_index_offset' => -1,
				'count'	=> 2,
			},
			'Dimmer' => {
				'id'	=> 3,
				'physical_index_offset' => -1,
				'count'	=> 1,
			},
		}
	}
);

1;