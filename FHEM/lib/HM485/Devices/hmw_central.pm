package HM485::Devicefile;
our %definition = (
	'HMW_CENTRAL' => {
		'version' => 	3,
		'supported_types' => 	{
			"type" => {
				"Virtual Remote Control 50 Keys" => {
					"id" => "HMW-RCV-50"
				}
			}
		},
		'paramset' => 	{
			"id" => "hmw_central_dev_master",
			"type" => "master"
		},
		'frames' => 	{
			"key_event_long" => {
				"channel_field" => 10,
				"direction" => "to_device",
				"parameter" => {
					"12.0" => {
						"const_value" => 1,
						"size" => 0.1,
						"type" => "integer"
					},
					"12.2" => {
						"param" => "switch_counter",
						"size" => 0.6,
						"type" => "integer"
					}
				},
				"receiver_channel_field" => 11,
				"type" => 0x4B
			},
			"key_event_short" => {
				"channel_field" => 10,
				"direction" => "to_device",
				"parameter" => {
					"12.0" => {
						"const_value" => 0,
						"size" => 0.1,
						"type" => "integer"
					},
					"12.2" => {
						"param" => "switch_counter",
						"size" => 0.6,
						"type" => "integer"
					}
				},
				"receiver_channel_field" => 11,
				"type" => 0x4B
			}
		},
		'channels' => 	{
			"listener" => {
				"class" => "central",
				"count" => 1,
				"hidden" => true,
				"index" => 63,
				"link_roles" => {
					"target" => {
						"name" => "switch"
					}
				},
				"paramset" => {
					"link" => {
						"type" => "link"
					},
					"master" => {
						"type" => "master"
					}
				}
			},
			"maintenance" => {
				"class" => "maintenance",
				"count" => 1,
				"index" => 0,
				"paramset" => {
					"hmw_central_maint_ch_master" => {
						"type" => "master"
					},
					"hmw_central_maint_ch_values" => {
						"type" => "values"
					}
				},
				"ui_flags" => "internal"
			},
			"virtual_key" => {
				"class" => "central",
				"count" => 50,
				"index" => 1,
				"link_roles" => {
					"source" => {
						"name" => "switch"
					}
				},
				"paramset" => {
					"link" => {
						"type" => "link"
					},
					"master" => {
						"type" => "master"
					},
					"values" => {
						"parameter" => {
							"press_long" => {
								"control" => "button.long",
								"logical" => {
									"type" => "action"
								},
								"loopback" => true,
								"operations" => "write,event",
								"physical" => {
									"counter" => "switch_counter",
									"interface" => "central_command",
									"set" => {
										"request" => "key_event_long"
									},
									"type" => "integer"
								}
							},
							"press_short" => {
								"control" => "button.short",
								"logical" => {
									"type" => "action"
								},
								"loopback" => true,
								"operations" => "write,event",
								"physical" => {
									"counter" => "switch_counter",
									"interface" => "central_command",
									"set" => {
										"request" => "key_event_short"
									},
									"type" => "integer"
								}
							}
						},
						"type" => "values"
					}
				}
			}
		},
	}
);	
