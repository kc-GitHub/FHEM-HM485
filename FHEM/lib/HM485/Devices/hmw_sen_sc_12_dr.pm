package HM485::Devicefile;
our %definition = (
	'HMW_SEN_SC_12_DR' => {
		'version' => 	7,
		'eep_size' => 	1024,
		'supported_types' => 	{
			"HMW_Sen_SC_12_DR" => {
				"name" => "RS485 shutter contact 12-channel (DIN rails)",
				"parameter" => {
					0 => {
						"const_value" => 25,
						"size" => 1
					},
					1 => {
						"const_value" => 0,
						"size" => 1
					}
				},
				"priority" => 2
			},
			"HMW_Sen_SC_12_FM" => {
				"name" => "RS485 shutter contact 12-channel (flush-mount)",
				"parameter" => {
					0 => {
						"const_value" => 26,
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
			"id" => "hmw-sen-sc-12-dr_dev_master",
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
					"index" => 11.0,
					"param" => "state",
					"size" => 1.0,
					"type" => "integer"
				},
				"type" => 0x69
			},
			"level_get" => {
				"channel_field" => 10,
				"direction" => "to_device",
				"type" => 0x53
			}
		},
		'channels' => 	{
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
			},
			"sensor" => {
				"count" => 12,
				"index" => 1,
				"paramset" => {
					"link" => {},
					"master" => {
						"address_start" => 0x07,
						"address_step" => 2,
						"parameter" => {
							"input_locked" => {
								"conversion" => {
									"invert" => true,
									"type" => "boolean_integer"
								},
								"id" => "input_locked",
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
										"frame" => "info_level"
									},
									"interface" => "command",
									"type" => "integer",
									"value_id" => "test_counter"
								},
								"ui_flags" => "internal"
							},
							"sensor" => {
								"control" => "door_sensor.state",
								"logical" => {
									"type" => "boolean"
								},
								"operations" => "read,event",
								"physical" => {
									"event" => {
										"auth_violate_policy" => "reject",
										"frame" => "info_level"
									},
									"get" => {
										"request" => "level_get",
										"response" => "info_level"
									},
									"interface" => "command",
									"type" => "integer",
									"value_id" => "state"
								}
							}
						},
						"type" => "values"
					}
				},
				"physical_index_offset" => -1
			}
		},
	}
);	
