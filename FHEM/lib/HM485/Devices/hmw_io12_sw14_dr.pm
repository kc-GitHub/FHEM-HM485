package HM485::Devices;

our %definition = (
	'HMW-IO-12-SW14'	=>{
		'version'		=> 12,													# ???
		'eeprom-size'	=> 1024,												# eprom size of the device
		'models'	=> {
			'HMW_IO_12_Sw14_DR'	=> {
				'name'	=> 'RS485 I/O module 12-channel in and switch actuator 14-channel (DIN rails)',
				'type'	=> 28,
			},
		},
		'params' => {															# the device params
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
							'id'	=> 0x0002,
						},
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
						'id'	=> 11.0,										# position in frame ???
						'size'	=> 2											# value length
					},
				},
			},
			'info_frequency'	=> {
				'type'		=>0x69,												# i
				'dir'		=> '>',
				'event'		=> 1,
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'		=> 'int',
						'id'		=> 11.0,
						'size'		=> 3,
					},
				},
			},
			'level_set'	=> {
				'type'		=> 0x73,											# s
				'dir'		=> '<',
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'		=> 'int',
						'id'		=> 11.0,
						'size'		=> 2,
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
					'master'	=> {									# paramset id
					},
					'values'	=> {									# paramset id
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
			'digitaloutput'	=> {
				'id'	=> 1,
				'count'	=> 6,													# count of channels of this type it the device
				'physical_id_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 0 
				'params'	=> {
					'master'	=> {											# why the master channel?
					},
					'values'	=> {
						'state'	=> {
							'operations'	=> 'read,write,event',				# which type of actions supports the channel ??? 
							'control'		=> 'switch.state',					# ui related ???
							'logical'		=> {
								'type'		=> 'boolean',						# logical type (the availabe states) boolean -> on/off
								'default'	=> 0,								# the default state after power on the device ???
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'value_id'	=> 'state',
								'set'		=> {								# setter (fhem set) ???
									'request'	=> 'level_set'					# request a level_set frame on set
								},
								'get'		=> {								# getter (fhem get) ???
									'request'	=> 'level_get',					# request a level_get frame on get
									'response'	=> 'info_level'					# expect info_level frame on get
								},
								'event'		=> {								# event (fhem notify) ???
									'frame'	=> 'info_level'						# trigger event on info_level frame
								}
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',				# conversion type @see logical / physical types 
								'threshold'	=> 1,								# conversion schwellwert???
								'false'		=> 0,								# value for false
								'true'		=> 1023								# value for true
							}
						}
					},
				}
			},
			'digital_analog_output'	=> {
				'id'	=> 7,
				'count'	=> 8,													# count of channels of this type it the device
				'physical_id_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 6
				'spechial_param'	=> {										# ???
					'behaviour'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'		=> {									# physical parameters
							'type'		=> 'int',								# the locical type mapped to this physical type
							'size'		=> 0.1,									# size: one bit
							'interface'	=> 'eeprom',							# param stored in eeprom
							'address'	=> {
								'id'	=> 7.0,									# address starts on byte 7
								'step'	=> 0.1									# next channel increments 1 bin 
							},
						},
					},
				}, 
				'params'	=> {
					'master'	=> {
						'behaviour'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> {
									'analog_output' 	=> {},
									'digital_output'	=> {
										'default'	=> 1,
									},
								},
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
						'pulsetime'	=> {
							'logical'	=> {
								'type'	=> 'float',
								'min'	=> 0.0,
								'max'	=> 600.0,
								'unit'	=> 's',
							},
							'physical'		=> {
								'type'		=> 'int',
								'size'		=> 2,
								'interface'	=> 'eeprom',
								'address'	=> {
									'id'	=> 16,
									'step'	=> 2
								},
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale',			# conversion type 
								'factor'	=> 100,								# conversion factor
								'offset'	=> 0.0,								# ???
							},
							'conversion'	=> {
								'type'			=> 'integer_integer_map',		# ??? 
								'value_map'		=> {
									'device_value'		=> 0xffff,				# ???
									'parameter_value'	=> 0,					# ???
									'from_device'		=> 1,					# ???
									'to_device'			=> 0,					# ???
								}
							}
						},
					},
					'values'	=> {
						'frequency' => {
							'operations'	=> 'read,write,event',				# which type of actions supports the channel ??? 
							'control'		=> 'digital_analog_output.frequency', # ui related ???
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0.0,
								'max'		=> 50000.0,
								'unit'		=> 'mhz',
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'value_id'	=> 'state',
								'set'		=> {								# setter (fhem set) ???
									'request'	=> 'level_set'					# request a level_set frame on set
								},
								'get'		=> {								# getter (fhem get) ???
									'request'	=> 'level_get',					# request a level_get frame on get
									'response'	=> 'info_level'					# expect info_level frame on get
								},
								'event'		=> {								# event (fhem notify) ???
									'frame'	=> 'info_level'						# trigger event on info_level frame
								}
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale', 
							},
						},
					},
				},
				'subconfig-params'	=> {										# was steht hier drinn ???
				},
			},
			'digital_input'	=> {
				'id'	=> 15,
				'count'	=> 6,													# count of channels of this type it the device
				'physical_id_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 6
				'spechial_param'	=> {										# ???
					'behaviour'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'		=> {									# physical parameters
							'type'		=> 'int',								# the locical type mapped to this physical type
							'size'		=> 0.1,									# size: one bit
							'interface'	=> 'eeprom',							# param stored in eeprom
							'address'	=> {
								'id'	=> 9.0,									# address starts on byte 7
								'step'	=> 0.1									# next channel increments 1 bin 
							},
						},
					},
				}, 
				'params'	=> {
					'master'	=> {
						'behaviour'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> {
									'frequency_input' 	=> {},
									'digital_input'	=> {
										'default'	=> 1,
									},
								},
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
					},
					'values'	=> {
						'frequency' => {
							'operations'	=> 'read,event',					# which type of actions supports the channel ??? 
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0.0,
								'max'		=> 350000,
								'unit'		=> 'mhz',
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'value_id'	=> 'state',
								'get'		=> {								# getter (fhem get) ???
									'request'	=> 'level_get',					# request a level_get frame on get
									'response'	=> 'info_frequency'				# expect info_frequency frame on get
								},
								'event'		=> {								# event (fhem notify) ???
									'frame'	=> 'info_frequency'					# trigger event on info_frequency frame
								}
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale', 
								'factor'	=> 1.0, 
							},
						},
					},
				},
				'subconfig-params'	=> {										# was steht hier drinn ???
				},
			},
			'digital_analog_input'	=> {
				'id'	=> 21,
				'count'	=> 6,													# count of channels of this type it the device
				'physical_id_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 6
				'spechial_param'	=> {										# ???
					'behaviour'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'		=> {									# physical parameters
							'type'		=> 'int',								# the locical type mapped to this physical type
							'size'		=> 0.1,									# size: one bit
							'interface'	=> 'eeprom',							# param stored in eeprom
							'address'	=> {
								'id'	=> 8.0,									# address starts on byte 7
								'step'	=> 0.1									# next channel increments 1 bin 
							},
						},
					},
				}, 
				'params'	=> {
					'master'	=> {
						'behaviour'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> {
									'analog_input' 	=> {},
									'digital_input'	=> {
										'default'	=> 1,
									},
								},
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
						'calibration'	=> {
							'logical'		=> {
								'type'		=> 'int',
								'min'		=> -127,
								'max'		=> 127,
							},
							'physical'		=> {
								'type'		=> 'int',
								'size'		=> 1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'id'	=> 10,								# address starts on byte 7
									'step'	=> 1								# next channel increments 1 bin 
								},
							},
							'conversion'	=> {
								'type'		=> 'integer_integer_scale',
								'offset'	=> 127,
							},
						},
					},
					'values'	=> {
						'value' => {
							'operations'	=> 'read,event',					# which type of actions supports the channel ??? 
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0,
								'max'		=> 1000,
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'value_id'	=> 'state',
								'get'		=> {								# getter (fhem get) ???
									'request'	=> 'level_get',					# request a level_get frame on get
									'response'	=> 'info_level'					# expect info_level frame on get
								},
								'event'		=> {								# event (fhem notify) ???
									'frame'	=> 'info_level'						# trigger event on info_level frame
								},
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale', 
								'factor'	=> 1, 
							},
						},
					},
				},
				'subconfig-params'	=> {										# was steht hier drinn ???
				},
			},
		},
	},
);

1;