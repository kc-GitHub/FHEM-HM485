package HM485::devices;

our %definition = (
	'HMW-IO-12-Sw14'	=>{
		'version'		=> 12,													# ???
		'eeprom-size'	=> 1024,												# eprom size of the device
		'models'	=> {														# hash with all different models of the device
			'HMW-Sen-SC-12-DR'	=> {											# the model id
				'name'	=> 'RS485 I/O module 12-channel in and switch actuator 14-channel (DIN rails)',	# the name
				'priority'	=> 2,												# ???
				'type'		=> 28,												# the model type (1 byte)
			},
		},
		'params' => {															# the device params
			'HMW-IO-12-Sw14-DR_dev_master'	=> {
				'type'				=> 'master',
				'CENTRAL_ADDRESS'	=> {										# parameter id
					'hidden'		=> TRUE,									# should not vidible in UI ???
					'enforce'		=> 0x00000001,								# sould always set to this value ???
					'logical'		=> {
						'type'			=> 'int',								# parameter value type
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 4,										# 4 bytes
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> 0x0002,									# location of central adress in device
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
				'event'		=> TRUE,											# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {											# aditional frame parameter (state)
						'type'	=> 'int',										# value type
						'index'	=> 11.0,										# position in frame ???
						'size'	=> 2											# value length
					},
				},
			},
			'info_frequency'	=> {
				'type'		=> 'i',
				'dir'		=> '>',
				'event'		=> TRUE,
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'		=> 'int',
						'index'		=> 11.0,
						'size'		=> 3,
					},
				},
			},
			'level_set'	=> {
				'type'		=> 's',
				'dir'		=> '<',
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {
						'type'		=> 'int',
						'index'		=> 11.0,
						'size'		=> 2,
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
				'type'	=> 'DIGITAL_OUTPUT',										# Channel Type (simple on / off switch)
				'count'	=> 6,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 0 
				'params'	=> {
					'hmw_io_ch_master'	=> {									# why the master channel?
						'type'	=> 'MASTER',
					},
					'hmw_digital_output_values'	=> {
						'type'	=> 'VALUES',
						'STATE'	=> {
							'operations'	=> 'read,write,event',				# which type of actions supports the channel ??? 
							'ctrl'			=> 'SWITCH.STATE',					# ui related ???
							'logical'		=> {
								'type'		=> 'boolean',						# logical type (the availabe states) boolean -> on/off
								'default'	=> FALSE,								# the default state after power on the device ???
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'set'		=> {								# setter (FHEM SET) ???
									'request'	=> 'LEVEL_SET'					# request a LEVEL_SET frame on set
								},
								'get'		=> {								# getter (FHEM GET) ???
									'request'	=> 'LEVEL_GET',					# request a LEVEL_GET frame on get
									'response'	=> 'INFO_LEVEL'					# expect INFO_LEVEL frame on get
								},
								'event'		=> {								# event (FHEM NOTIFY) ???
									'frame'	=> 'INFO_LEVEL'						# trigger event on INFO_LEVEL frame
								}
							},
							'conversion'	=> {
								'type'		=> 'boolean-int',					# conversion type @see logical / physical types 
								'threshold'	=> 1,								# conversion schwellwert???
								'false'		=> 0,								# value for false
								'true'		=> 1023								# value for true
							}
						}
					},
				}
			},
			7	=> {
				'type'	=> 'DIGITAL_ANALOG_OUTPUT',								# Channel Type (frequency otput)
				'count'	=> 8,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 6
				'spechial_param'	=> {										# ???
					'BEHAVIOUR'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'		=> {									# physical parameters
							'type'		=> 'int',								# the locical type mapped to this physical type
							'size'		=> 0.1,									# size: one bit
							'interface'	=> 'eeprom',							# param stored in eeprom
							'address'	=> {
								'index'	=> 7.0,									# address starts on byte 7
								'step'	=> 0.1									# next channel increments 1 bin 
							},
						},
					},
				}, 
				'params'	=> {
					'hmw_io_ch_master'	=> {
						'type'	=> 'MASTER',
						'BEHAVIOUR'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> {
									'ANALOG_OUTPUT' 	=> {},
									'DIGITAL_OUTPUT'	=> {
										'default'	=> TRUE,
									},
								},
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
						'PULSETIME'	=> {
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
									'index'	=> 16,
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
									'from_device'		=> TRUE,				# ???
									'to_device'			=> FALSE,				# ???
								}
							}
						},
					},
					'hmw_analog_output_values'	=> {
						'type'	=> 'VALUES',
						'FREQUENCY' => {
							'operations'	=> 'read,write,event',				# which type of actions supports the channel ??? 
							'ctrl'			=> 'DIGITAL_ANALOG_OUTPUT.FREQUENCY', # ui related ???
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0.0,
								'max'		=> 50000.0,
								'unit'		=> 'mHz',
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'set'		=> {								# setter (FHEM SET) ???
									'request'	=> 'LEVEL_SET'					# request a LEVEL_SET frame on set
								},
								'get'		=> {								# getter (FHEM GET) ???
									'request'	=> 'LEVEL_GET',					# request a LEVEL_GET frame on get
									'response'	=> 'INFO_LEVEL'					# expect INFO_LEVEL frame on get
								},
								'event'		=> {								# event (FHEM NOTIFY) ???
									'frame'	=> 'INFO_LEVEL'						# trigger event on INFO_LEVEL frame
								}
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale', 
							},
						},
					},
				},
				'subconfig-params'	=> {										# Was steht hier drinn ???
				},
			},
			15	=> {
				'type'	=> 'DIGITAL_INPUT',										# Channel Type (digital input)
				'count'	=> 6,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 6
				'spechial_param'	=> {										# ???
					'BEHAVIOUR'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'		=> {									# physical parameters
							'type'		=> 'int',								# the locical type mapped to this physical type
							'size'		=> 0.1,									# size: one bit
							'interface'	=> 'eeprom',							# param stored in eeprom
							'address'	=> {
								'index'	=> 9.0,									# address starts on byte 7
								'step'	=> 0.1									# next channel increments 1 bin 
							},
						},
					},
				}, 
				'params'	=> {
					'hmw_io_ch_master'	=> {
						'type'	=> 'MASTER',
						'BEHAVIOUR'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> {
									'FREQUENCY_INPUT' 	=> {},
									'DIGITAL_INPUT'	=> {
										'default'	=> TRUE,
									},
								},
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
					},
					'hmw_analog_input_values'	=> {
						'type'	=> 'VALUES',
						'FREQUENCY' => {
							'operations'	=> 'read,event',					# which type of actions supports the channel ??? 
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0.0,
								'max'		=> 350000,
								'unit'		=> 'mHz',
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'get'		=> {								# getter (FHEM GET) ???
									'request'	=> 'LEVEL_GET',					# request a LEVEL_GET frame on get
									'response'	=> 'INFO_FREQUENCY'				# expect INFO_FREQUENCY frame on get
								},
								'event'		=> {								# event (FHEM NOTIFY) ???
									'frame'	=> 'INFO_FREQUENCY'					# trigger event on INFO_FREQUENCY frame
								}
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale', 
								'factor'	=> 1.0, 
							},
						},
					},
				},
				'subconfig-params'	=> {										# Was steht hier drinn ???
				},
			},
			21	=> {
				'type'	=> 'DIGITAL_ANALOG_INPUT',								# Channel Type (frequency input)
				'count'	=> 6,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from INDEX + physical_index_offset => 6
				'spechial_param'	=> {										# ???
					'BEHAVIOUR'	=> {
						'logical'		=> {
							'type'		=> 'int',
						},
						'physical'		=> {									# physical parameters
							'type'		=> 'int',								# the locical type mapped to this physical type
							'size'		=> 0.1,									# size: one bit
							'interface'	=> 'eeprom',							# param stored in eeprom
							'address'	=> {
								'index'	=> 8.0,									# address starts on byte 7
								'step'	=> 0.1									# next channel increments 1 bin 
							},
						},
					},
				}, 
				'params'	=> {
					'hmw_io_ch_master'	=> {
						'type'	=> 'MASTER',
						'BEHAVIOUR'	=> {
							'ui-flags'	=> 'transform', 
							'logical'		=> {
								'type'		=> 'option',
								'options'	=> {
									'ANALOG_INPUT' 	=> {},
									'DIGITAL_INPUT'	=> {
										'default'	=> TRUE,
									},
								},
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
						'CALIBRATION'	=> {
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
									'index'	=> 10,								# address starts on byte 7
									'step'	=> 1								# next channel increments 1 bin 
								},
							},
							'conversion'	=> {
								'type'		=> 'integer_integer_scale',
								'offset'	=> 127,
							},
						},
					},
					'hmw_analog_input_values'	=> {
						'type'	=> 'VALUES',
						'VALUE' => {
							'operations'	=> 'read,event',					# which type of actions supports the channel ??? 
							'logical'		=> {
								'type'		=> 'float',
								'min'		=> 0,
								'max'		=> 1000,
							},
							'physical'		=> {								# physical parameters
								'type'		=> 'int',							# the locical type mapped to this physical type
								'interface'	=> 'command',						# ???
								'get'		=> {								# getter (FHEM GET) ???
									'request'	=> 'LEVEL_GET',					# request a LEVEL_GET frame on get
									'response'	=> 'INFO_LEVEL'					# expect INFO_LEVEL frame on get
								},
								'event'		=> {								# event (FHEM NOTIFY) ???
									'frame'	=> 'INFO_LEVEL'						# trigger event on INFO_LEVEL frame
								},
							},
							'conversion'	=> {
								'type'		=> 'float_integer_scale', 
								'factor'	=> 1, 
							},
						},
					},
				},
				'subconfig-params'	=> {										# Was steht hier drinn ???
				},
			},
		},
	},
);

1;