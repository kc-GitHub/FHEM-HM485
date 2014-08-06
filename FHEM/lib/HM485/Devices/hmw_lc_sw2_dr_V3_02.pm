package HM485::Devicefile;
our %definition = (
  'HMW_LC_SW2_DR_V3_02' => {
    'version' =>     7,
    'eep_size' =>     1024,
    'supported_types' =>     {
      "HMW_LC_Sw2_DR" => {
                           "name" => "RS485 switch actuator 2-channel (DIN rails)",
                           "parameter" => {
                                            0 => {
                                                   "const_value" => 17,
                                                   "size" => 1
                                                 },
                                            1 => {
                                                   "const_value" => 0,
                                                   "size" => 1
                                                 },
                                            2 => {
                                                   "const_value" => 0x0302,
                                                   "size" => 2
                                                 }
                                          },
                           "priority" => 2
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
      "id" => "HMW-LC-Sw2-DR_dev_master",
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
                                                   },
                       "LOGGING_TIME" => {
                                           "conversion" => {
                                                             "factor" => 10,
                                                             "offset" => 0.0,
                                                             "type" => "float_integer_scale"
                                                           },
                                           "logical" => {
                                                          "default" => 2.0,
                                                          "max" => 25.5,
                                                          "min" => 0.0,
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
      "type" => "MASTER"
    },
    'frames' =>     {
      "INFO_LEVEL" => {
                        "channel_field" => 10,
                        "direction" => "from_device",
                        "event" => true,
                        "parameter" => {
                                         "11.0" => {
                                                     "param" => "STATE",
                                                     "size" => 1.0,
                                                     "type" => "integer"
                                                   },
                                         "12.4" => {
                                                     "param" => "STATE_FLAGS",
                                                     "size" => 0.3,
                                                     "type" => "integer"
                                                   }
                                       },
                        "type" => 0x69
                      },
      "KEY_EVENT_LONG" => {
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
                                                         "param" => "COUNTER",
                                                         "size" => 0.6,
                                                         "type" => "integer"
                                                       }
                                           },
                            "type" => 0x4B
                          },
      "KEY_EVENT_SHORT" => {
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
                                                          "param" => "COUNTER",
                                                          "size" => 0.6,
                                                          "type" => "integer"
                                                        }
                                            },
                             "type" => 0x4B
                           },
      "KEY_SIM_LONG" => {
                          "channel_field" => 10,
                          "direction" => "from_device",
                          "parameter" => {
                                           "12.0" => {
                                                       "const_value" => 1,
                                                       "size" => 0.1,
                                                       "type" => "integer"
                                                     },
                                           "12.2" => {
                                                       "param" => "SIM_COUNTER",
                                                       "size" => 0.6,
                                                       "type" => "integer"
                                                     }
                                         },
                          "receiver_channel_field" => 11,
                          "type" => 0x4B
                        },
      "KEY_SIM_SHORT" => {
                           "channel_field" => 10,
                           "direction" => "from_device",
                           "parameter" => {
                                            "12.0" => {
                                                        "const_value" => 0,
                                                        "size" => 0.1,
                                                        "type" => "integer"
                                                      },
                                            "12.2" => {
                                                        "param" => "SIM_COUNTER",
                                                        "size" => 0.6,
                                                        "type" => "integer"
                                                      }
                                          },
                           "receiver_channel_field" => 11,
                           "type" => 0x4B
                         },
      "LEVEL_GET" => {
                       "channel_field" => 10,
                       "direction" => "to_device",
                       "type" => 0x53
                     },
      "LEVEL_SET" => {
                       "channel_field" => 10,
                       "direction" => "to_device",
                       "parameter" => {
                                        "index" => 11.0,
                                        "param" => "STATE",
                                        "size" => 1.0,
                                        "type" => "integer"
                                      },
                       "type" => 0x78
                     },
      "SET_LOCK" => {
                      "channel_field" => 11,
                      "direction" => "to_device",
                      "parameter" => {
                                       "index" => 12.0,
                                       "param" => "INHIBIT",
                                       "size" => 1.0,
                                       "type" => "integer"
                                     },
                      "type" => 0x6C
                    }
    },
    'channels' =>     {
      "KEY" => {
                 "count" => 2,
                 "index" => 1,
                 "link_roles" => {
                                   "source" => {
                                                 "name" => "SWITCH"
                                               }
                                 },
                 "paramset" => {
                                 "link" => {
                                             "address_start" => 0x357,
                                             "address_step" => 6,
                                             "channel_offset" => 0,
                                             "count" => 28,
                                             "peer_address_offset" => 1,
                                             "peer_address_size" => 4.0,
                                             "peer_channel_offset" => 5,
                                             "peer_channel_size" => 1.0,
                                             "type" => "LINK"
                                           },
                                 "master" => {
                                               "address_start" => 0x07,
                                               "address_step" => 2,
                                               "parameter" => {
                                                                "INPUT_LOCKED" => {
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
                                                                "INPUT_TYPE" => {
                                                                                  "logical" => {
                                                                                                 "option" => {
                                                                                                               "PUSHBUTTON" => {
                                                                                                                                 "default" => true
                                                                                                                               },
                                                                                                               "SWITCH" => {}
                                                                                                             },
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
                                                                "LONG_PRESS_TIME" => {
                                                                                       "conversion" => {
                                                                                                         1 => {
                                                                                                                "factor" => 10,
                                                                                                                "type" => "float_integer_scale"
                                                                                                              },
                                                                                                         2 => {
                                                                                                                "type" => "integer_integer_map",
                                                                                                                "value_map" => {
                                                                                                                                 "device_value" => 0xff,
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
                                               "type" => "MASTER"
                                             },
                                 "values" => {
                                               "parameter" => {
                                                                "PRESS_LONG" => {
                                                                                  "control" => "BUTTON.LONG",
                                                                                  "conversion" => {
                                                                                                    "counter_size" => 6,
                                                                                                    "sim_counter" => "SIM_COUNTER",
                                                                                                    "type" => "action_key_counter"
                                                                                                  },
                                                                                  "logical" => {
                                                                                                 "type" => "action"
                                                                                               },
                                                                                  "loopback" => true,
                                                                                  "operations" => "event,read,write",
                                                                                  "physical" => {
                                                                                                  "event" => {
                                                                                                               "frame" => "KEY_EVENT_LONG"
                                                                                                             },
                                                                                                  "interface" => "command",
                                                                                                  "set" => {
                                                                                                             "request" => "KEY_SIM_LONG"
                                                                                                           },
                                                                                                  "type" => "integer",
                                                                                                  "value_id" => "COUNTER"
                                                                                                }
                                                                                },
                                                                "PRESS_SHORT" => {
                                                                                   "control" => "BUTTON.SHORT",
                                                                                   "conversion" => {
                                                                                                     "counter_size" => 6,
                                                                                                     "sim_counter" => "SIM_COUNTER",
                                                                                                     "type" => "action_key_counter"
                                                                                                   },
                                                                                   "logical" => {
                                                                                                  "type" => "action"
                                                                                                },
                                                                                   "loopback" => true,
                                                                                   "operations" => "event,read,write",
                                                                                   "physical" => {
                                                                                                   "event" => {
                                                                                                                "frame" => "KEY_EVENT_SHORT"
                                                                                                              },
                                                                                                   "interface" => "command",
                                                                                                   "set" => {
                                                                                                              "request" => "KEY_SIM_SHORT"
                                                                                                            },
                                                                                                   "type" => "integer",
                                                                                                   "value_id" => "COUNTER"
                                                                                                 }
                                                                                 }
                                                              },
                                               "type" => "VALUES"
                                             }
                               },
                 "physical_index_offset" => -1
               },
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
      "SWITCH" => {
                    "count" => 2,
                    "index" => 3,
                    "link_roles" => {
                                      "target" => {
                                                    "name" => "SWITCH"
                                                  }
                                    },
                    "paramset" => {
                                    "link" => {
                                                "address_start" => 0x0F,
                                                "address_step" => 28,
                                                "channel_offset" => 5,
                                                "count" => 30,
                                                "peer_address_offset" => 0,
                                                "peer_address_size" => 4.0,
                                                "peer_channel_offset" => 4,
                                                "peer_channel_size" => 1.0,
                                                "type" => "LINK"
                                              },
                                    "master" => {
                                                  "address_start" => 0x0B,
                                                  "address_step" => 2,
                                                  "parameter" => {
                                                                   "id" => "LOGGING",
                                                                   "logical" => {
                                                                                  "option" => {
                                                                                                "OFF" => {},
                                                                                                "ON" => {
                                                                                                          "default" => true
                                                                                                        }
                                                                                              },
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
                                                                 },
                                                  "type" => "MASTER"
                                                },
                                    "values" => {
                                                  "parameter" => {
                                                                   "INHIBIT" => {
                                                                                  "control" => "NONE",
                                                                                  "logical" => {
                                                                                                 "default" => false,
                                                                                                 "type" => "boolean"
                                                                                               },
                                                                                  "loopback" => true,
                                                                                  "operations" => "read,write,event",
                                                                                  "physical" => {
                                                                                                  "interface" => "command",
                                                                                                  "set" => {
                                                                                                             "request" => "SET_LOCK"
                                                                                                           },
                                                                                                  "type" => "integer",
                                                                                                  "value_id" => "INHIBIT"
                                                                                                }
                                                                                },
                                                                   "STATE" => {
                                                                                "control" => "SWITCH.STATE",
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
                                                                                                             "frame" => "INFO_LEVEL"
                                                                                                           },
                                                                                                "get" => {
                                                                                                           "request" => "LEVEL_GET",
                                                                                                           "response" => "INFO_LEVEL"
                                                                                                         },
                                                                                                "interface" => "command",
                                                                                                "set" => {
                                                                                                           "request" => "LEVEL_SET"
                                                                                                         },
                                                                                                "type" => "integer",
                                                                                                "value_id" => "STATE"
                                                                                              }
                                                                              },
                                                                   "WORKING" => {
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
                                                                                                                      "frame" => "INFO_LEVEL"
                                                                                                                    },
                                                                                                               2 => {
                                                                                                                      "frame" => "ACK_STATUS"
                                                                                                                    }
                                                                                                             },
                                                                                                  "get" => {
                                                                                                             "request" => "LEVEL_GET",
                                                                                                             "response" => "INFO_LEVEL"
                                                                                                           },
                                                                                                  "interface" => "command",
                                                                                                  "type" => "integer",
                                                                                                  "value_id" => "STATE_FLAGS"
                                                                                                },
                                                                                  "ui_flags" => "internal"
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
