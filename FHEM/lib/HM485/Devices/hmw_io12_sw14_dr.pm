package HM485::Devicefile;
our %definition = (
	'HMW_IO12_SW14_DR' => {
		'version' => 	12,
		'eep_size' => 	1024,
		'supported_types' => 	{
			"HMW_IO_12_Sw14_DR" => {
				"name" => "RS485 I/O module 12-channel in and switch actuator 14-channel (DIN rails)",
				"parameter" => {
					"0" => {
						"const_value" => 28,
						"size" => 1
					},
					"1" => {
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
					"id" => "central_address",
					"value" => 1
				}
			},
			"id" => "hmw-io-12-sw14-dr_dev_master",
			"parameter" => {
				"central_address" => {
					"hidden" => true,
					"id" => "central_address",
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
				}
			},
			"type" => "master"
		},
		'frames' => 	{
			"info_frequency" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"event" => true,
				"parameter" => {
					"index" => 11.0,
					"param" => "state",
					"size" => 3.0,
					"type" => "integer"
				},
				"type" => 0x69
			},
			"info_level" => {
				"channel_field" => 10,
				"direction" => "from_device",
				"event" => true,
				"parameter" => {
					"index" => 11.0,
					"param" => "state",
					"size" => 2.0,
					"type" => "integer"
				},
				"type" => 0x69
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
					"size" => 2.0,
					"type" => "integer"
				},
				"type" => 0x73
			}
		},
		'channels' => 	{
			"digital_analog_input" => {
				"count" => 6,
				"index" => 21,
				"paramset" => {
					"link" => {},
					"master" => {
						"parameter" => {
							"behaviour" => {
								"logical" => {
									"option" => {
										"analog_input" => {},
										"digital_input" => {
											"default" => true
										}
									},
									"type" => "option"
								},
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "behaviour"
								},
								"ui_flags" => "transform"
							},
							"calibration" => {
								"conversion" => {
									"1" => {
										"offset" => 127,
										"type" => "integer_integer_scale"
									},
									"2" => {
										"type" => "integer_integer_map",
										"value_map" => {
											"device_value" => 0xFF,
											"from_device" => true,
											"parameter_value" => 127,
											"to_device" => false
										}
									}
								},
								"logical" => {
									"max" => 127,
									"min" => -127,
									"type" => "integer"
								},
								"physical" => {
									"address" => {
										"index" => 10,
										"step" => 1
									},
									"interface" => "eeprom",
									"size" => 1,
									"type" => "integer"
								}
							}
						},
						"type" => "master"
					},
					"values" => {
						"parameter" => {
							"value" => {
								"conversion" => {
									"factor" => 1,
									"type" => "float_integer_scale"
								},
								"id" => "value",
								"logical" => {
									"max" => 1000,
									"min" => 0,
									"type" => "float"
								},
								"operations" => "read,event",
								"physical" => {
									"event" => {
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
				"physical_index_offset" => -1,
				"special_parameter" => {
					"behaviour" => {
						"id" => "behaviour",
						"logical" => {
							"type" => "integer"
						},
						"physical" => {
							"address" => {
								"index" => 8.0,
								"step" => 0.1
							},
							"interface" => "eeprom",
							"size" => 0.1,
							"type" => "integer"
						}
					}
				},
				"subconfig" => {
					"paramset" => {
						"hmw_digital_input_values" => {
							"parameter" => {
								"state" => {
									"conversion" => {
										"false" => 0,
										"threshold" => 1,
										"true" => 1023,
										"type" => "boolean_integer"
									},
									"id" => "state",
									"logical" => {
										"default" => false,
										"type" => "boolean"
									},
									"operations" => "read,event",
									"physical" => {
										"event" => {
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
						},
						"hmw_io_ch_master" => {
							"parameter" => {
								"behaviour" => {
									"id" => "behaviour",
									"logical" => {
										"option" => {
											"analog_input" => {},
											"digital_input" => {
												"default" => true
											}
										},
										"type" => "option"
									},
									"physical" => {
										"interface" => "internal",
										"type" => "integer",
										"value_id" => "behaviour"
									},
									"ui_flags" => "transform"
								}
							},
							"type" => "master"
						}
					}
				}
			},
			"digital_analog_output" => {
				"count" => 8,
				"index" => 7,
				"paramset" => {
					"link" => {},
					"master" => {
						"parameter" => {
							"behaviour" => {
								"logical" => {
									"option" => {
										"analog_output" => {},
										"digital_output" => {
											"default" => true
										}
									},
									"type" => "option"
								},
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "behaviour"
								},
								"ui_flags" => "transform"
							},
							"pulsetime" => {
								"conversion" => {
									"1" => {
										"factor" => 100,
										"offset" => 0.0,
										"type" => "float_integer_scale"
									},
									"2" => {
										"type" => "integer_integer_map",
										"value_map" => {
											"device_value" => 0xFFFF,
											"from_device" => true,
											"parameter_value" => 0,
											"to_device" => false
										}
									}
								},
								"logical" => {
									"max" => 600.0,
									"min" => 0.0,
									"type" => "float",
									"unit" => "s"
								},
								"physical" => {
									"address" => {
										"index" => 16,
										"step" => 2
									},
									"interface" => "eeprom",
									"size" => 2,
									"type" => "integer"
								}
							}
						},
						"type" => "master"
					},
					"values" => {
						"parameter" => {
							"frequency" => {
								"control" => "digital_analog_output.frequency",
								"conversion" => {
									"type" => "float_integer_scale"
								},
								"id" => "frequency",
								"logical" => {
									"max" => 50000.0,
									"min" => 0.0,
									"type" => "float",
									"unit" => "mhz"
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
							}
						},
						"type" => "values"
					}
				},
				"physical_index_offset" => -1,
				"special_parameter" => {
					"behaviour" => {
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
					}
				},
				"subconfig" => {
					"paramset" => {
						"hmw_digital_output_values" => {
							"parameter" => {
								"state" => {
									"control" => "switch.state",
									"conversion" => {
										"false" => 0,
										"threshold" => 1,
										"true" => 1023,
										"type" => "boolean_integer"
									},
									"id" => "state",
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
								}
							},
							"type" => "values"
						},
						"hmw_io_ch_master" => {
							"parameter" => {
								"behaviour" => {
									"id" => "behaviour",
									"logical" => {
										"option" => {
											"analog_output" => {},
											"digital_output" => {
												"default" => true
											}
										},
										"type" => "option"
									},
									"physical" => {
										"interface" => "internal",
										"type" => "integer",
										"value_id" => "behaviour"
									},
									"ui_flags" => "transform"
								}
							},
							"type" => "master"
						}
					}
				}
			},
			"digital_input" => {
				"count" => 6,
				"index" => 15,
				"paramset" => {
					"link" => {},
					"master" => {
						"parameter" => {
							"behaviour" => {
								"id" => "behaviour",
								"logical" => {
									"option" => {
										"digital_input" => {
											"default" => true
										},
										"frequency_input" => {}
									},
									"type" => "option"
								},
								"physical" => {
									"interface" => "internal",
									"type" => "integer",
									"value_id" => "behaviour"
								},
								"ui_flags" => "transform"
							}
						},
						"type" => "master"
					},
					"values" => {
						"parameter" => {
							"frequency" => {
								"conversion" => {
									"factor" => 1.0,
									"type" => "float_integer_scale"
								},
								"id" => "frequency",
								"logical" => {
									"max" => 350000,
									"min" => 0,
									"type" => "float",
									"unit" => "mhz"
								},
								"operations" => "read,event",
								"physical" => {
									"event" => {
										"frame" => "info_frequency"
									},
									"get" => {
										"request" => "level_get",
										"response" => "info_frequency"
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
				"physical_index_offset" => -1,
				"special_parameter" => {
					"behaviour" => {
						"id" => "behaviour",
						"logical" => {
							"type" => "integer"
						},
						"physical" => {
							"address" => {
								"index" => 9.0,
								"step" => 0.1
							},
							"interface" => "eeprom",
							"size" => 0.1,
							"type" => "integer"
						}
					}
				},
				"subconfig" => {
					"paramset" => {
						"hmw_digital_input_values" => {
							"parameter" => {
								"state" => {
									"conversion" => {
										"false" => 0,
										"threshold" => 1,
										"true" => 1023,
										"type" => "boolean_integer"
									},
									"id" => "state",
									"logical" => {
										"default" => false,
										"type" => "boolean"
									},
									"operations" => "read,event",
									"physical" => {
										"event" => {
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
						},
						"hmw_io_ch_master" => {
							"parameter" => {
								"behaviour" => {
									"id" => "behaviour",
									"logical" => {
										"option" => {
											"digital_input" => {
												"default" => true
											},
											"frequency_input" => {}
										},
										"type" => "option"
									},
									"physical" => {
										"interface" => "internal",
										"type" => "integer",
										"value_id" => "behaviour"
									},
									"ui_flags" => "transform"
								}
							},
							"type" => "master"
						}
					}
				}
			},
			"digital_output" => {
				"count" => 6,
				"index" => 1,
				"paramset" => {
					"link" => {},
					"master" => {
						"type" => "master"
					},
					"values" => {
						"parameter" => {
							"state" => {
								"control" => "switch.state",
								"conversion" => {
									"false" => 0,
									"threshold" => 1,
									"true" => 1023,
									"type" => "boolean_integer"
								},
								"id" => "state",
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
							}
						},
						"type" => "values"
					}
				},
				"physical_index_offset" => -1
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
