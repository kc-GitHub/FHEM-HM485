package HM485::Devicefile;
our %definition = (
	'HMW_IO_12_FM' => {
		'version' => 	7,
		'eep_size' => 	1024,
		'supported_types' => 	{
			"HMW_IO_12_FM" => {
				"name" => "RS485 I/O module 12-channel (flush-mount)",
				"parameter" => {
					0 => {
						"const_value" => 27,
						"size" => 1
					},
					1 => {
						"const_value" => 0,
						"size" => 1
					}
				},
				"priority" => 2
			}
		},
		'paramset' => 	{
			"enforce" => {
				"central_address" => {
					"value" => 1
				},
				"direct_link_deactivate" => {
					"value" => true
				}
			},
			"id" => "hmw-io-12-fm_dev_master",
			"parameter" => {
				"central_address" => {
					"hidden" => true,
					"logical" => {
						"type" => "integer"
					},
					"physical" => {
						"address" => {
							"index" => 0x0002
						},
						"interface" => "eeprom",
						"size" => 4,
						"type" => "integer"
					}
				},
				"direct_link_deactivate" => {
					"hidden" => true,
					"logical" => {
						"default" => false,
						"type" => "boolean"
					},
					"physical" => {
						"address" => {
							"index" => 0x0006
						},
						"interface" => "eeprom",
						"size" => 0.1,
						"type" => "integer"
					}
				},
				"logging_time" => {
					"conversion" => {
						"factor" => 10,
						"offset" => 0.0,
						"type" => "float_integer_scale"
					},
					"logical" => {
						"default" => 2.0,
						"max" => 25.5,
						"min" => 0.1,
						"type" => "float",
						"unit" => "s"
					},
					"physical" => {
						"address" => {
							"index" => 0x0001
						},
						"interface" => "eeprom",
						"size" => 1.0,
						"type" => "integer"
					}
				}
			},
			"type" => "master"
		},
		'frames' => 	{
			"info_level" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"event" => true,
				"parameter" => {
					"11.0" => {
						"param" => "state",
						"size" => 1.0,
						"type" => "integer"
					},
					"12.4" => {
						"param" => "state_flags",
						"size" => 0.3,
						"type" => "integer"
					}
				},
				"type" => 0x69
			},
			"key_event_long" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"event" => true,
				"parameter" => {
					"12.0" => {
						"const_value" => 1,
						"size" => 0.1,
						"type" => "integer"
					},
					"12.2" => {
						"param" => "counter",
						"size" => 0.6,
						"type" => "integer"
					}
				},
				"type" => 0x4B
			},
			"key_event_short" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"event" => true,
				"parameter" => {
					"12.0" => {
						"const_value" => 0,
						"size" => 0.1,
						"type" => "integer"
					},
					"12.2" => {
						"param" => "counter",
						"size" => 0.6,
						"type" => "integer"
					}
				},
				"type" => 0x4B
			},
			"key_sim_long" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"parameter" => {
					"12.0" => {
						"const_value" => 1,
						"size" => 0.1,
						"type" => "integer"
					},
					"12.2" => {
						"param" => "sim_counter",
						"size" => 0.6,
						"type" => "integer"
					}
				},
				"receiver_channel_field" => 11,
				"type" => 0x4B
			},
			"key_sim_short" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"parameter" => {
					"12.0" => {
						"const_value" => 0,
						"size" => 0.1,
						"type" => "integer"
					},
					"12.2" => {
						"param" => "sim_counter",
						"size" => 0.6,
						"type" => "integer"
					}
				},
				"receiver_channel_field" => 11,
				"type" => 0x4B
			},
			"level_get" => {
				"channel_field" => 10,
				"direction" => "to_device",
				"type" => 0x53
			},
			"level_set" => {
				"channel_field" => 10,
				"direction" => "to_device",
				"parameter" => {
					"index" => 11.0,
					"param" => "state",
					"size" => 1.0,
					"type" => "integer"
				},
				"type" => 0x78
			},
			"set_lock" => {
				"channel_field" => 11,
				"direction" => "to_device",
				"parameter" => {
					"index" => 12.0,
					"param" => "inhibit",
					"size" => 1.0,
					"type" => "integer"
				},
				"type" => 0x6C
			},
			"toggle_install_test" => {
				"channel_field" => 10,
				"direction" => "to_device",
				"parameter" => {
					"index" => 11.0,
					"param" => "toggle_flag",
					"size" => 1.0,
					"type" => "integer"
				},
				"type" => 0x78
			}
		},
		'channels' => 	{
			"input_output" => {
				"count" => 12,
				"index" => 1,
				"link_roles" => {
					"source" => {
						"name" => "switch"
					}
				},
				"paramset" => {
					"link" => {
						"address_start" => 0x349,
						"address_step" => 6,
						"channel_param" => "channel",
						"count" => 30,
						"parameter" => {
							"actuator" => {
								"hidden" => true,
								"logical" => {
									"type" => "address"
								},
								"operations" => "none",
								"physical" => [
								{
									"address" => {
										"index" => 1
									},
									"interface" => "eeprom",
									"size" => 4.0,
									"type" => "integer"
								},
								{
									"address" => {
										"index" => 5
									},
									"interface" => "eeprom",
									"size" => 1.0,
									"type" => "integer"
								}
								]
							},
							"channel" => {
								"hidden" => true,
								"logical" => {
									"default" => 255,
									"max" => 255,
									"min" => 0,
									"type" => "integer"
								},
								"operations" => "none",
								"physical" => {
									"address" => {
										"index" => 0
									},
									"interface" => "eeprom",
									"size" => 1.0,
									"type" => "integer"
								}
							}
						},
						"peer_param" => "actuator",
						"type" => "link"
					},
					"master" => {
						"address_start" => 9,
						"address_step" => 2,
						"parameter" => {
							"behaviour" => {
								"logical" => {
									"option" => [
									{
										"default" => true,
										"id" => "input"
									},
									{
										"id" => "output"
									}
									],
									"type" => "option"
								},
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "behaviour"
								},
								"ui_flags" => "transform"
							},
							"input_locked" => {
								"conversion" => {
									"invert" => true,
									"type" => "boolean_integer"
								},
								"logical" => {
									"default" => false,
									"type" => "boolean"
								},
								"physical" => {
									"address" => {
										"index" => 0.1
									},
									"interface" => "eeprom",
									"size" => 0.1,
									"type" => "integer"
								}
							},
							"input_type" => {
								"logical" => {
									"option" => [
									{
										"id" => "switch"
									},
									{
										"default" => true,
										"id" => "pushbutton"
									}
									],
									"type" => "option"
								},
								"physical" => {
									"address" => {
										"index" => 0.0
									},
									"interface" => "eeprom",
									"size" => 0.1,
									"type" => "integer"
								}
							},
							"long_press_time" => {
								"conversion" => {
									1 => {
										"factor" => 10,
										"type" => "float_integer_scale"
									},
									2 => {
										"type" => "integer_integer_map",
										"value_map" => {
											"device_value" => 0xFF,
											"from_device" => true,
											"parameter_value" => 10,
											"to_device" => false
										}
									}
								},
								"logical" => {
									"default" => 1.0,
									"max" => 5.0,
									"min" => 0.4,
									"type" => "float",
									"unit" => "s"
								},
								"physical" => {
									"address" => {
										"index" => 1.0
									},
									"interface" => "eeprom",
									"size" => 1.0,
									"type" => "integer"
								}
							}
						},
						"type" => "master"
					},
					"values" => {
						"parameter" => {
							"install_test" => {
								"logical" => {
									"type" => "action"
								},
								"operations" => "event",
								"physical" => {
									"event" => {
										1 => {
											"frame" => "key_event_short"
										},
										2 => {
											"frame" => "key_event_long"
										}
									},
									"interface" => "command",
									"type" => "integer",
									"value_id" => "test_counter"
								},
								"ui_flags" => "internal"
							},
							"press_long" => {
								"control" => "button.long",
								"conversion" => {
									"counter_size" => 6,
									"sim_counter" => "sim_counter",
									"type" => "action_key_counter"
								},
								"logical" => {
									"type" => "action"
								},
								"loopback" => true,
								"operations" => "event,write",
								"physical" => {
									"event" => {
										"frame" => "key_event_long"
									},
									"interface" => "command",
									"set" => {
										"request" => "key_sim_long"
									},
									"type" => "integer",
									"value_id" => "counter"
								}
							},
							"press_short" => {
								"control" => "button.short",
								"conversion" => {
									"counter_size" => 6,
									"sim_counter" => "sim_counter",
									"type" => "action_key_counter"
								},
								"logical" => {
									"type" => "action"
								},
								"loopback" => true,
								"operations" => "event,write",
								"physical" => {
									"event" => {
										"frame" => "key_event_short"
									},
									"interface" => "command",
									"set" => {
										"request" => "key_sim_short"
									},
									"type" => "integer",
									"value_id" => "counter"
								}
							}
						},
						"type" => "values"
					}
				},
				"physical_index_offset" => -1,
				"special_parameter" => {
					"id" => "behaviour",
					"logical" => {
						"type" => "integer"
					},
					"physical" => {
						"address" => {
							"index" => 7.0,
							"step" => 0.1
						},
						"interface" => "eeprom",
						"size" => 0.1,
						"type" => "integer"
					}
				},
				"subconfig" => {
					"link_roles" => {
						"target" => {
							"name" => "switch"
						}
					},
					"paramset" => {
						"hmw_io_ch_master" => {
							"address_start" => 33,
							"address_step" => 2,
							"parameter" => {
								"behaviour" => {
									"logical" => {
										"option" => [
										{
											"default" => true,
											"id" => "input"
										},
										{
											"id" => "output"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"interface" => "internal",
										"type" => "integer",
										"value_id" => "behaviour"
									},
									"ui_flags" => "transform"
								},
								"logging" => {
									"logical" => {
										"option" => [
										{
											"id" => "off"
										},
										{
											"default" => true,
											"id" => "on"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 0
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								}
							},
							"type" => "master"
						},
						"hmw_switch_ch_link" => {
							"address_start" => 0x39,
							"address_step" => 28,
							"channel_param" => "channel",
							"count" => 28,
							"parameter" => {
								"channel" => {
									"hidden" => true,
									"logical" => {
										"default" => 255,
										"max" => 255,
										"min" => 0,
										"type" => "integer"
									},
									"operations" => "none",
									"physical" => {
										"address" => {
											"index" => 5
										},
										"interface" => "eeprom",
										"size" => 1.0,
										"type" => "integer"
									}
								},
								"long_action_type" => {
									"logical" => {
										"option" => [
										{
											"id" => "inactive"
										},
										{
											"default" => true,
											"id" => "active"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 17.0
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"long_jt_off" => {
									"logical" => {
										"option" => [
										{
											"default" => true,
											"id" => "ondelay"
										},
										{
											"id" => "on"
										},
										{
											"id" => "offdelay"
										},
										{
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 26.9
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"long_jt_offdelay" => {
									"logical" => {
										"option" => [
										{
											"id" => "ondelay"
										},
										{
											"id" => "on"
										},
										{
											"id" => "offdelay"
										},
										{
											"default" => true,
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 26.6
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"long_jt_on" => {
									"logical" => {
										"option" => [
										{
											"id" => "ondelay"
										},
										{
											"id" => "on"
										},
										{
											"default" => true,
											"id" => "offdelay"
										},
										{
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 26.3
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"long_jt_ondelay" => {
									"logical" => {
										"option" => [
										{
											"id" => "ondelay"
										},
										{
											"default" => true,
											"id" => "on"
										},
										{
											"id" => "offdelay"
										},
										{
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 26.0
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"long_multiexecute" => {
									"logical" => {
										"default" => true,
										"type" => "boolean"
									},
									"physical" => {
										"address" => {
											"index" => 17.2
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"long_offdelay_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 0.0,
										"max" => 982980.0,
										"min" => 0.0,
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 22
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"long_off_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 16383000,
										"max" => 982980.0,
										"min" => 0.0,
										"special_value" => {
											"id" => "not_used",
											"value" => 16383000
										},
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 24
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"long_off_time_mode" => {
									"logical" => {
										"option" => [
										{
											"id" => "minimal"
										},
										{
											"default" => true,
											"id" => "absolute"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 17.6
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"long_ondelay_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 0.0,
										"max" => 982980.0,
										"min" => 0.0,
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 18
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"long_on_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 16383000,
										"max" => 982980.0,
										"min" => 0.0,
										"special_value" => {
											"id" => "not_used",
											"value" => 16383000
										},
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 20
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"long_on_time_mode" => {
									"logical" => {
										"option" => [
										{
											"id" => "minimal"
										},
										{
											"default" => true,
											"id" => "absolute"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 17.7
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"long_toggle_use" => {
									"conversion" => {
										"type" => "option_integer",
										"value_map" => {
											1 => {
												"device_value" => 0x03,
												"from_device" => true,
												"parameter_value" => 0,
												"to_device" => true
											},
											2 => {
												"device_value" => 0x02,
												"from_device" => true,
												"parameter_value" => 1,
												"to_device" => true
											},
											3 => {
												"device_value" => 0x00,
												"from_device" => true,
												"parameter_value" => 2,
												"to_device" => true
											}
										}
									},
									"logical" => {
										"option" => [
										{
											"default" => true,
											"id" => "dont_use"
										},
										{
											"id" => "direct"
										},
										{
											"id" => "inverted"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 17.4
										},
										"interface" => "eeprom",
										"size" => 0.2,
										"type" => "integer"
									}
								},
								"sensor" => {
									"hidden" => true,
									"logical" => {
										"type" => "address"
									},
									"operations" => "none",
									"physical" => [
									{
										"address" => {
											"index" => 0
										},
										"interface" => "eeprom",
										"size" => 4.0,
										"type" => "integer"
									},
									{
										"address" => {
											"index" => 4
										},
										"interface" => "eeprom",
										"size" => 1.0,
										"type" => "integer"
									}
									]
								},
								"short_action_type" => {
									"logical" => {
										"option" => [
										{
											"id" => "inactive"
										},
										{
											"default" => true,
											"id" => "active"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 6.0
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"short_jt_off" => {
									"logical" => {
										"option" => [
										{
											"default" => true,
											"id" => "ondelay"
										},
										{
											"id" => "on"
										},
										{
											"id" => "offdelay"
										},
										{
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 15.9
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"short_jt_offdelay" => {
									"logical" => {
										"option" => [
										{
											"id" => "ondelay"
										},
										{
											"id" => "on"
										},
										{
											"id" => "offdelay"
										},
										{
											"default" => true,
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 15.6
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"short_jt_on" => {
									"logical" => {
										"option" => [
										{
											"id" => "ondelay"
										},
										{
											"id" => "on"
										},
										{
											"default" => true,
											"id" => "offdelay"
										},
										{
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 15.3
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"short_jt_ondelay" => {
									"logical" => {
										"option" => [
										{
											"id" => "ondelay"
										},
										{
											"default" => true,
											"id" => "on"
										},
										{
											"id" => "offdelay"
										},
										{
											"id" => "off"
										},
										{
											"id" => "no_jump_ignore_command"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 15.0
										},
										"endian" => "little",
										"interface" => "eeprom",
										"read_size" => 2,
										"size" => 0.3,
										"type" => "integer"
									}
								},
								"short_offdelay_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 0.0,
										"max" => 982980.0,
										"min" => 0.0,
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 11
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"short_off_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 16383000,
										"max" => 982980.0,
										"min" => 0.0,
										"special_value" => {
											"id" => "not_used",
											"value" => 16383000
										},
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 13
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"short_off_time_mode" => {
									"logical" => {
										"option" => [
										{
											"id" => "minimal"
										},
										{
											"default" => true,
											"id" => "absolute"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 6.6
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"short_ondelay_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 0.0,
										"max" => 982980.0,
										"min" => 0.0,
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 7
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"short_on_time" => {
									"conversion" => {
										1 => {
											"factors" => "0.1,1,60,1000",
											"type" => "float_configtime",
											"value_size" => 1.6
										},
										2 => {
											"type" => "integer_integer_map",
											"value_map" => {
												"device_value" => 0xC000,
												"mask" => 0xC000,
												"parameter_value" => 0xFFFF
											}
										}
									},
									"logical" => {
										"default" => 16383000,
										"max" => 982980.0,
										"min" => 0.0,
										"special_value" => {
											"id" => "not_used",
											"value" => 16383000
										},
										"type" => "float",
										"unit" => "s"
									},
									"physical" => {
										"address" => {
											"index" => 9
										},
										"endian" => "little",
										"interface" => "eeprom",
										"size" => 2.0,
										"type" => "integer"
									}
								},
								"short_on_time_mode" => {
									"logical" => {
										"option" => [
										{
											"id" => "minimal"
										},
										{
											"default" => true,
											"id" => "absolute"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 6.7
										},
										"interface" => "eeprom",
										"size" => 0.1,
										"type" => "integer"
									}
								},
								"short_toggle_use" => {
									"conversion" => {
										"type" => "option_integer",
										"value_map" => {
											1 => {
												"device_value" => 0x03,
												"from_device" => true,
												"parameter_value" => 0,
												"to_device" => true
											},
											2 => {
												"device_value" => 0x02,
												"from_device" => true,
												"parameter_value" => 1,
												"to_device" => true
											},
											3 => {
												"device_value" => 0x00,
												"from_device" => true,
												"parameter_value" => 2,
												"to_device" => true
											}
										}
									},
									"logical" => {
										"option" => [
										{
											"default" => true,
											"id" => "dont_use"
										},
										{
											"id" => "direct"
										},
										{
											"id" => "inverted"
										}
										],
										"type" => "option"
									},
									"physical" => {
										"address" => {
											"index" => 6.4
										},
										"interface" => "eeprom",
										"size" => 0.2,
										"type" => "integer"
									}
								},
								"ui_hint" => {
									"logical" => {
										"default" => "",
										"type" => "string",
										"use_default_on_failure" => true
									},
									"physical" => {
										"id" => "ui_hint",
										"interface" => "store",
										"save_on_change" => true,
										"type" => "string"
									}
								}
							},
							"peer_param" => "sensor",
							"type" => "link"
						},
						"hmw_switch_ch_values" => {
							"parameter" => {
								"inhibit" => {
									"control" => "none",
									"logical" => {
										"default" => false,
										"type" => "boolean"
									},
									"loopback" => true,
									"operations" => "read,write,event",
									"physical" => {
										"interface" => "command",
										"set" => {
											"request" => "set_lock"
										},
										"type" => "integer",
										"value_id" => "inhibit"
									}
								},
								"install_test" => {
									"conversion" => {
										"type" => "toggle",
										"value" => "state"
									},
									"logical" => {
										"type" => "action"
									},
									"operations" => "write",
									"physical" => {
										"interface" => "command",
										"no_init" => true,
										"set" => {
											"request" => "toggle_install_test"
										},
										"type" => "integer",
										"value_id" => "toggle_flag"
									},
									"ui_flags" => "internal"
								},
								"state" => {
									"control" => "switch.state",
									"conversion" => {
										"false" => 0,
										"threshold" => 1,
										"true" => 200,
										"type" => "boolean_integer"
									},
									"logical" => {
										"default" => false,
										"type" => "boolean"
									},
									"operations" => "read,write,event",
									"physical" => {
										"event" => {
											"frame" => "info_level"
										},
										"get" => {
											"request" => "level_get",
											"response" => "info_level"
										},
										"interface" => "command",
										"set" => {
											"request" => "level_set"
										},
										"type" => "integer",
										"value_id" => "state"
									}
								},
								"working" => {
									"conversion" => {
										"type" => "boolean_integer"
									},
									"logical" => {
										"default" => false,
										"type" => "boolean"
									},
									"operations" => "read,event",
									"physical" => {
										"event" => {
											1 => {
												"frame" => "info_level"
											},
											2 => {
												"frame" => "ack_status"
											}
										},
										"get" => {
											"request" => "level_get",
											"response" => "info_level"
										},
										"interface" => "command",
										"type" => "integer",
										"value_id" => "state_flags"
									},
									"ui_flags" => "internal"
								}
							},
							"type" => "values"
						}
					}
				}
			},
			"maintenance" => {
				"class" => "maintenance",
				"count" => 1,
				"index" => 0,
				"paramset" => {
					"maint_ch_master" => {
						"type" => "master"
					},
					"maint_ch_values" => {
						"parameter" => {
							"config_pending" => {
								"logical" => {
									"type" => "boolean"
								},
								"operations" => "read,event",
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "config_pending"
								},
								"ui_flags" => "service"
							},
							"sticky_unreach" => {
								"logical" => {
									"type" => "boolean"
								},
								"operations" => "read,write,event",
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "sticky_unreach"
								},
								"ui_flags" => "service"
							},
							"unreach" => {
								"logical" => {
									"type" => "boolean"
								},
								"operations" => "read,event",
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "unreach"
								},
								"ui_flags" => "service"
							}
						},
						"type" => "values"
					}
				},
				"ui_flags" => "internal"
			}
		},
	}
);	
