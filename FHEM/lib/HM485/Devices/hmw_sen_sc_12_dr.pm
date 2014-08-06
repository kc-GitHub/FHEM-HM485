package HM485::Devicefile;
our %definition = (
  'HMW_SEN_SC_12_DR' => {
    'version' =>     7,
    'eep_size' =>     1024,
    'supported_types' =>     {
      "type" => {
                  "RS485 shutter contact 12-channel (DIN rails)" => {
                                                                      "id" => "HMW-Sen-SC-12-DR",
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
                  "RS485 shutter contact 12-channel (flush-mount)" => {
                                                                        "id" => "HMW-Sen-SC-12-FM",
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
                }
    },
    'paramset' =>     {
      "enforce" => {
                     "CENTRAL_ADDRESS" => {
                                            "value" => 1
                                          },
                     "DIRECT_LINK_DEACTIVATE" => {
                                                   "value" => true
                                                 }
                   },
      "id" => "HMW-Sen-SC-12-DR_dev_master",
      "parameter" => {
                       "CENTRAL_ADDRESS" => {
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
                       "DIRECT_LINK_DEACTIVATE" => {
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
      "type" => "MASTER"
    },
    'frames' =>     {
      "INFO_LEVEL" => {
                        "channel_field" => 10,
                        "direction" => "from_device",
                        "event" => true,
                        "parameter" => {
                                         "index" => 11.0,
                                         "param" => "STATE",
                                         "size" => 1.0,
                                         "type" => "integer"
                                       },
                        "type" => 0x69
                      },
      "LEVEL_GET" => {
                       "channel_field" => 10,
                       "direction" => "to_device",
                       "type" => 0x53
                     }
    },
    'channels' =>     {
      "MAINTENANCE" => {
                         "class" => "maintenance",
                         "count" => 1,
                         "index" => 0,
                         "paramset" => {
                                         "maint_ch_master" => {
                                                                "type" => "MASTER"
                                                              },
                                         "maint_ch_values" => {
                                                                "parameter" => {
                                                                                 "CONFIG_PENDING" => {
                                                                                                       "logical" => {
                                                                                                                      "type" => "boolean"
                                                                                                                    },
                                                                                                       "operations" => "read,event",
                                                                                                       "physical" => {
                                                                                                                       "interface" => "internal",
                                                                                                                       "type" => "integer",
                                                                                                                       "value_id" => "CONFIG_PENDING"
                                                                                                                     },
                                                                                                       "ui_flags" => "service"
                                                                                                     },
                                                                                 "STICKY_UNREACH" => {
                                                                                                       "logical" => {
                                                                                                                      "type" => "boolean"
                                                                                                                    },
                                                                                                       "operations" => "read,write,event",
                                                                                                       "physical" => {
                                                                                                                       "interface" => "internal",
                                                                                                                       "type" => "integer",
                                                                                                                       "value_id" => "STICKY_UNREACH"
                                                                                                                     },
                                                                                                       "ui_flags" => "service"
                                                                                                     },
                                                                                 "UNREACH" => {
                                                                                                "logical" => {
                                                                                                               "type" => "boolean"
                                                                                                             },
                                                                                                "operations" => "read,event",
                                                                                                "physical" => {
                                                                                                                "interface" => "internal",
                                                                                                                "type" => "integer",
                                                                                                                "value_id" => "UNREACH"
                                                                                                              },
                                                                                                "ui_flags" => "service"
                                                                                              }
                                                                               },
                                                                "type" => "VALUES"
                                                              }
                                       },
                         "ui_flags" => "internal"
                       },
      "SENSOR" => {
                    "count" => 12,
                    "index" => 1,
                    "paramset" => {
                                    "link" => {},
                                    "master" => {
                                                  "address_start" => 0x07,
                                                  "address_step" => 2,
                                                  "parameter" => {
                                                                   "conversion" => {
                                                                                     "invert" => true,
                                                                                     "type" => "boolean_integer"
                                                                                   },
                                                                   "id" => "INPUT_LOCKED",
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
                                                  "type" => "MASTER"
                                                },
                                    "values" => {
                                                  "parameter" => {
                                                                   "INSTALL_TEST" => {
                                                                                       "logical" => {
                                                                                                      "type" => "action"
                                                                                                    },
                                                                                       "operations" => "event",
                                                                                       "physical" => {
                                                                                                       "event" => {
                                                                                                                    "frame" => "INFO_LEVEL"
                                                                                                                  },
                                                                                                       "interface" => "command",
                                                                                                       "type" => "integer",
                                                                                                       "value_id" => "TEST_COUNTER"
                                                                                                     },
                                                                                       "ui_flags" => "internal"
                                                                                     },
                                                                   "SENSOR" => {
                                                                                 "control" => "DOOR_SENSOR.STATE",
                                                                                 "logical" => {
                                                                                                "type" => "boolean"
                                                                                              },
                                                                                 "operations" => "read,event",
                                                                                 "physical" => {
                                                                                                 "event" => {
                                                                                                              "auth_violate_policy" => "reject",
                                                                                                              "frame" => "INFO_LEVEL"
                                                                                                            },
                                                                                                 "get" => {
                                                                                                            "request" => "LEVEL_GET",
                                                                                                            "response" => "INFO_LEVEL"
                                                                                                          },
                                                                                                 "interface" => "command",
                                                                                                 "type" => "integer",
                                                                                                 "value_id" => "STATE"
                                                                                               }
                                                                               }
                                                                 },
                                                  "type" => "VALUES"
                                                }
                                  },
                    "physical_index_offset" => -1
                  }
    },
  }
);	
