package HM485::Devicefile;
our %definition = (
  'HMW_IO_12_FM' => {
    'version' =>     7,
    'eep_size' =>     1024,
    'supported_types' =>     {
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
    'paramset' =>     {
      "enforce" => {
                     "CENTRAL_ADDRESS" => {
                                            "value" => 1
                                          },
                     "DIRECT_LINK_DEACTIVATE" => {
                                                   "value" => true
                                                 }
                   },
      "id" => "HMW-IO-12-FM_dev_master",
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
                    },
      "TOGGLE_INSTALL_TEST" => {
                                 "channel_field" => 10,
                                 "direction" => "to_device",
                                 "parameter" => {
                                                  "index" => 11.0,
                                                  "param" => "TOGGLE_FLAG",
                                                  "size" => 1.0,
                                                  "type" => "integer"
                                                },
                                 "type" => 0x78
                               }
    },
    'channels' =>     {
      "INPUT_OUTPUT" => {
                          "count" => 12,
                          "index" => 1,
                          "link_roles" => {
                                            "source" => {
                                                          "name" => "SWITCH"
                                                        }
                                          },
                          "paramset" => {
                                          "link" => {
                                                      "address_start" => 0x349,
                                                      "address_step" => 6,
                                                      "channel_param" => "CHANNEL",
                                                      "count" => 30,
                                                      "parameter" => {
                                                                       "ACTUATOR" => {
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
                                                                       "CHANNEL" => {
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
                                                      "peer_param" => "ACTUATOR",
                                                      "type" => "LINK"
                                                    },
                                          "master" => {
                                                        "address_start" => 9,
                                                        "address_step" => 2,
                                                        "parameter" => {
                                                                         "BEHAVIOUR" => {
                                                                                          "logical" => {
                                                                                                         "option" => {
                                                                                                                       "INPUT" => {
                                                                                                                                    "default" => true
                                                                                                                                  },
                                                                                                                       "OUTPUT" => {}
                                                                                                                     },
                                                                                                         "type" => "option"
                                                                                                       },
                                                                                          "physical" => {
                                                                                                          "interface" => "internal",
                                                                                                          "type" => "integer",
                                                                                                          "value_id" => "BEHAVIOUR"
                                                                                                        },
                                                                                          "ui_flags" => "transform"
                                                                                        },
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
                                                                         "INSTALL_TEST" => {
                                                                                             "logical" => {
                                                                                                            "type" => "action"
                                                                                                          },
                                                                                             "operations" => "event",
                                                                                             "physical" => {
                                                                                                             "event" => {
                                                                                                                          1 => {
                                                                                                                                 "frame" => "KEY_EVENT_SHORT"
                                                                                                                               },
                                                                                                                          2 => {
                                                                                                                                 "frame" => "KEY_EVENT_LONG"
                                                                                                                               }
                                                                                                                        },
                                                                                                             "interface" => "command",
                                                                                                             "type" => "integer",
                                                                                                             "value_id" => "TEST_COUNTER"
                                                                                                           },
                                                                                             "ui_flags" => "internal"
                                                                                           },
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
                                                                                           "operations" => "event,write",
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
                                                                                            "operations" => "event,write",
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
                          "physical_index_offset" => -1,
                          "special_parameter" => {
                                                   "id" => "BEHAVIOUR",
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
                                                                           "name" => "SWITCH"
                                                                         }
                                                           },
                                           "paramset" => {
                                                           "hmw_io_ch_master" => {
                                                                                   "address_start" => 33,
                                                                                   "address_step" => 2,
                                                                                   "parameter" => {
                                                                                                    "BEHAVIOUR" => {
                                                                                                                     "logical" => {
                                                                                                                                    "option" => {
                                                                                                                                                  "INPUT" => {
                                                                                                                                                               "default" => true
                                                                                                                                                             },
                                                                                                                                                  "OUTPUT" => {}
                                                                                                                                                },
                                                                                                                                    "type" => "option"
                                                                                                                                  },
                                                                                                                     "physical" => {
                                                                                                                                     "interface" => "internal",
                                                                                                                                     "type" => "integer",
                                                                                                                                     "value_id" => "BEHAVIOUR"
                                                                                                                                   },
                                                                                                                     "ui_flags" => "transform"
                                                                                                                   },
                                                                                                    "LOGGING" => {
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
                                                                                                                 }
                                                                                                  },
                                                                                   "type" => "MASTER"
                                                                                 },
                                                           "hmw_switch_ch_link" => {
                                                                                     "address_start" => 0x39,
                                                                                     "address_step" => 28,
                                                                                     "channel_param" => "CHANNEL",
                                                                                     "count" => 28,
                                                                                     "parameter" => {
                                                                                                      "CHANNEL" => {
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
                                                                                                      "LONG_ACTION_TYPE" => {
                                                                                                                              "logical" => {
                                                                                                                                             "option" => {
                                                                                                                                                           "ACTIVE" => {
                                                                                                                                                                         "default" => true
                                                                                                                                                                       },
                                                                                                                                                           "INACTIVE" => {}
                                                                                                                                                         },
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
                                                                                                      "LONG_JT_OFF" => {
                                                                                                                         "logical" => {
                                                                                                                                        "option" => {
                                                                                                                                                      "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                      "OFF" => {},
                                                                                                                                                      "OFFDELAY" => {},
                                                                                                                                                      "ON" => {},
                                                                                                                                                      "ONDELAY" => {
                                                                                                                                                                     "default" => true
                                                                                                                                                                   }
                                                                                                                                                    },
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
                                                                                                      "LONG_JT_OFFDELAY" => {
                                                                                                                              "logical" => {
                                                                                                                                             "option" => {
                                                                                                                                                           "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                           "OFF" => {
                                                                                                                                                                      "default" => true
                                                                                                                                                                    },
                                                                                                                                                           "OFFDELAY" => {},
                                                                                                                                                           "ON" => {},
                                                                                                                                                           "ONDELAY" => {}
                                                                                                                                                         },
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
                                                                                                      "LONG_JT_ON" => {
                                                                                                                        "logical" => {
                                                                                                                                       "option" => {
                                                                                                                                                     "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                     "OFF" => {},
                                                                                                                                                     "OFFDELAY" => {
                                                                                                                                                                     "default" => true
                                                                                                                                                                   },
                                                                                                                                                     "ON" => {},
                                                                                                                                                     "ONDELAY" => {}
                                                                                                                                                   },
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
                                                                                                      "LONG_JT_ONDELAY" => {
                                                                                                                             "logical" => {
                                                                                                                                            "option" => {
                                                                                                                                                          "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                          "OFF" => {},
                                                                                                                                                          "OFFDELAY" => {},
                                                                                                                                                          "ON" => {
                                                                                                                                                                    "default" => true
                                                                                                                                                                  },
                                                                                                                                                          "ONDELAY" => {}
                                                                                                                                                        },
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
                                                                                                      "LONG_MULTIEXECUTE" => {
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
                                                                                                      "LONG_OFFDELAY_TIME" => {
                                                                                                                                "conversion" => {
                                                                                                                                                  1 => {
                                                                                                                                                         "factors" => "0.1,1,60,1000",
                                                                                                                                                         "type" => "float_configtime",
                                                                                                                                                         "value_size" => 1.6
                                                                                                                                                       },
                                                                                                                                                  2 => {
                                                                                                                                                         "type" => "integer_integer_map",
                                                                                                                                                         "value_map" => {
                                                                                                                                                                          "device_value" => 0xc000,
                                                                                                                                                                          "mask" => 0xc000,
                                                                                                                                                                          "parameter_value" => 0xffff
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
                                                                                                      "LONG_OFF_TIME" => {
                                                                                                                           "conversion" => {
                                                                                                                                             1 => {
                                                                                                                                                    "factors" => "0.1,1,60,1000",
                                                                                                                                                    "type" => "float_configtime",
                                                                                                                                                    "value_size" => 1.6
                                                                                                                                                  },
                                                                                                                                             2 => {
                                                                                                                                                    "type" => "integer_integer_map",
                                                                                                                                                    "value_map" => {
                                                                                                                                                                     "device_value" => 0xc000,
                                                                                                                                                                     "mask" => 0xc000,
                                                                                                                                                                     "parameter_value" => 0xffff
                                                                                                                                                                   }
                                                                                                                                                  }
                                                                                                                                           },
                                                                                                                           "logical" => {
                                                                                                                                          "default" => 16383000,
                                                                                                                                          "max" => 982980.0,
                                                                                                                                          "min" => 0.0,
                                                                                                                                          "special_value" => {
                                                                                                                                                               "id" => "NOT_USED",
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
                                                                                                      "LONG_OFF_TIME_MODE" => {
                                                                                                                                "logical" => {
                                                                                                                                               "option" => {
                                                                                                                                                             "ABSOLUTE" => {
                                                                                                                                                                             "default" => true
                                                                                                                                                                           },
                                                                                                                                                             "MINIMAL" => {}
                                                                                                                                                           },
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
                                                                                                      "LONG_ONDELAY_TIME" => {
                                                                                                                               "conversion" => {
                                                                                                                                                 1 => {
                                                                                                                                                        "factors" => "0.1,1,60,1000",
                                                                                                                                                        "type" => "float_configtime",
                                                                                                                                                        "value_size" => 1.6
                                                                                                                                                      },
                                                                                                                                                 2 => {
                                                                                                                                                        "type" => "integer_integer_map",
                                                                                                                                                        "value_map" => {
                                                                                                                                                                         "device_value" => 0xc000,
                                                                                                                                                                         "mask" => 0xc000,
                                                                                                                                                                         "parameter_value" => 0xffff
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
                                                                                                      "LONG_ON_TIME" => {
                                                                                                                          "conversion" => {
                                                                                                                                            1 => {
                                                                                                                                                   "factors" => "0.1,1,60,1000",
                                                                                                                                                   "type" => "float_configtime",
                                                                                                                                                   "value_size" => 1.6
                                                                                                                                                 },
                                                                                                                                            2 => {
                                                                                                                                                   "type" => "integer_integer_map",
                                                                                                                                                   "value_map" => {
                                                                                                                                                                    "device_value" => 0xc000,
                                                                                                                                                                    "mask" => 0xc000,
                                                                                                                                                                    "parameter_value" => 0xffff
                                                                                                                                                                  }
                                                                                                                                                 }
                                                                                                                                          },
                                                                                                                          "logical" => {
                                                                                                                                         "default" => 16383000,
                                                                                                                                         "max" => 982980.0,
                                                                                                                                         "min" => 0.0,
                                                                                                                                         "special_value" => {
                                                                                                                                                              "id" => "NOT_USED",
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
                                                                                                      "LONG_ON_TIME_MODE" => {
                                                                                                                               "logical" => {
                                                                                                                                              "option" => {
                                                                                                                                                            "ABSOLUTE" => {
                                                                                                                                                                            "default" => true
                                                                                                                                                                          },
                                                                                                                                                            "MINIMAL" => {}
                                                                                                                                                          },
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
                                                                                                      "LONG_TOGGLE_USE" => {
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
                                                                                                                                            "option" => {
                                                                                                                                                          "DIRECT" => {},
                                                                                                                                                          "DONT_USE" => {
                                                                                                                                                                          "default" => true
                                                                                                                                                                        },
                                                                                                                                                          "INVERTED" => {}
                                                                                                                                                        },
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
                                                                                                      "SENSOR" => {
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
                                                                                                      "SHORT_ACTION_TYPE" => {
                                                                                                                               "logical" => {
                                                                                                                                              "option" => {
                                                                                                                                                            "ACTIVE" => {
                                                                                                                                                                          "default" => true
                                                                                                                                                                        },
                                                                                                                                                            "INACTIVE" => {}
                                                                                                                                                          },
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
                                                                                                      "SHORT_JT_OFF" => {
                                                                                                                          "logical" => {
                                                                                                                                         "option" => {
                                                                                                                                                       "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                       "OFF" => {},
                                                                                                                                                       "OFFDELAY" => {},
                                                                                                                                                       "ON" => {},
                                                                                                                                                       "ONDELAY" => {
                                                                                                                                                                      "default" => true
                                                                                                                                                                    }
                                                                                                                                                     },
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
                                                                                                      "SHORT_JT_OFFDELAY" => {
                                                                                                                               "logical" => {
                                                                                                                                              "option" => {
                                                                                                                                                            "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                            "OFF" => {
                                                                                                                                                                       "default" => true
                                                                                                                                                                     },
                                                                                                                                                            "OFFDELAY" => {},
                                                                                                                                                            "ON" => {},
                                                                                                                                                            "ONDELAY" => {}
                                                                                                                                                          },
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
                                                                                                      "SHORT_JT_ON" => {
                                                                                                                         "logical" => {
                                                                                                                                        "option" => {
                                                                                                                                                      "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                      "OFF" => {},
                                                                                                                                                      "OFFDELAY" => {
                                                                                                                                                                      "default" => true
                                                                                                                                                                    },
                                                                                                                                                      "ON" => {},
                                                                                                                                                      "ONDELAY" => {}
                                                                                                                                                    },
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
                                                                                                      "SHORT_JT_ONDELAY" => {
                                                                                                                              "logical" => {
                                                                                                                                             "option" => {
                                                                                                                                                           "NO_JUMP_IGNORE_COMMAND" => {},
                                                                                                                                                           "OFF" => {},
                                                                                                                                                           "OFFDELAY" => {},
                                                                                                                                                           "ON" => {
                                                                                                                                                                     "default" => true
                                                                                                                                                                   },
                                                                                                                                                           "ONDELAY" => {}
                                                                                                                                                         },
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
                                                                                                      "SHORT_OFFDELAY_TIME" => {
                                                                                                                                 "conversion" => {
                                                                                                                                                   1 => {
                                                                                                                                                          "factors" => "0.1,1,60,1000",
                                                                                                                                                          "type" => "float_configtime",
                                                                                                                                                          "value_size" => 1.6
                                                                                                                                                        },
                                                                                                                                                   2 => {
                                                                                                                                                          "type" => "integer_integer_map",
                                                                                                                                                          "value_map" => {
                                                                                                                                                                           "device_value" => 0xc000,
                                                                                                                                                                           "mask" => 0xc000,
                                                                                                                                                                           "parameter_value" => 0xffff
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
                                                                                                      "SHORT_OFF_TIME" => {
                                                                                                                            "conversion" => {
                                                                                                                                              1 => {
                                                                                                                                                     "factors" => "0.1,1,60,1000",
                                                                                                                                                     "type" => "float_configtime",
                                                                                                                                                     "value_size" => 1.6
                                                                                                                                                   },
                                                                                                                                              2 => {
                                                                                                                                                     "type" => "integer_integer_map",
                                                                                                                                                     "value_map" => {
                                                                                                                                                                      "device_value" => 0xc000,
                                                                                                                                                                      "mask" => 0xc000,
                                                                                                                                                                      "parameter_value" => 0xffff
                                                                                                                                                                    }
                                                                                                                                                   }
                                                                                                                                            },
                                                                                                                            "logical" => {
                                                                                                                                           "default" => 16383000,
                                                                                                                                           "max" => 982980.0,
                                                                                                                                           "min" => 0.0,
                                                                                                                                           "special_value" => {
                                                                                                                                                                "id" => "NOT_USED",
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
                                                                                                      "SHORT_OFF_TIME_MODE" => {
                                                                                                                                 "logical" => {
                                                                                                                                                "option" => {
                                                                                                                                                              "ABSOLUTE" => {
                                                                                                                                                                              "default" => true
                                                                                                                                                                            },
                                                                                                                                                              "MINIMAL" => {}
                                                                                                                                                            },
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
                                                                                                      "SHORT_ONDELAY_TIME" => {
                                                                                                                                "conversion" => {
                                                                                                                                                  1 => {
                                                                                                                                                         "factors" => "0.1,1,60,1000",
                                                                                                                                                         "type" => "float_configtime",
                                                                                                                                                         "value_size" => 1.6
                                                                                                                                                       },
                                                                                                                                                  2 => {
                                                                                                                                                         "type" => "integer_integer_map",
                                                                                                                                                         "value_map" => {
                                                                                                                                                                          "device_value" => 0xc000,
                                                                                                                                                                          "mask" => 0xc000,
                                                                                                                                                                          "parameter_value" => 0xffff
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
                                                                                                      "SHORT_ON_TIME" => {
                                                                                                                           "conversion" => {
                                                                                                                                             1 => {
                                                                                                                                                    "factors" => "0.1,1,60,1000",
                                                                                                                                                    "type" => "float_configtime",
                                                                                                                                                    "value_size" => 1.6
                                                                                                                                                  },
                                                                                                                                             2 => {
                                                                                                                                                    "type" => "integer_integer_map",
                                                                                                                                                    "value_map" => {
                                                                                                                                                                     "device_value" => 0xc000,
                                                                                                                                                                     "mask" => 0xc000,
                                                                                                                                                                     "parameter_value" => 0xffff
                                                                                                                                                                   }
                                                                                                                                                  }
                                                                                                                                           },
                                                                                                                           "logical" => {
                                                                                                                                          "default" => 16383000,
                                                                                                                                          "max" => 982980.0,
                                                                                                                                          "min" => 0.0,
                                                                                                                                          "special_value" => {
                                                                                                                                                               "id" => "NOT_USED",
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
                                                                                                      "SHORT_ON_TIME_MODE" => {
                                                                                                                                "logical" => {
                                                                                                                                               "option" => {
                                                                                                                                                             "ABSOLUTE" => {
                                                                                                                                                                             "default" => true
                                                                                                                                                                           },
                                                                                                                                                             "MINIMAL" => {}
                                                                                                                                                           },
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
                                                                                                      "SHORT_TOGGLE_USE" => {
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
                                                                                                                                             "option" => {
                                                                                                                                                           "DIRECT" => {},
                                                                                                                                                           "DONT_USE" => {
                                                                                                                                                                           "default" => true
                                                                                                                                                                         },
                                                                                                                                                           "INVERTED" => {}
                                                                                                                                                         },
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
                                                                                                      "UI_HINT" => {
                                                                                                                     "logical" => {
                                                                                                                                    "default" => "",
                                                                                                                                    "type" => "string",
                                                                                                                                    "use_default_on_failure" => true
                                                                                                                                  },
                                                                                                                     "physical" => {
                                                                                                                                     "id" => "UI_HINT",
                                                                                                                                     "interface" => "store",
                                                                                                                                     "save_on_change" => true,
                                                                                                                                     "type" => "string"
                                                                                                                                   }
                                                                                                                   }
                                                                                                    },
                                                                                     "peer_param" => "SENSOR",
                                                                                     "type" => "LINK"
                                                                                   },
                                                           "hmw_switch_ch_values" => {
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
                                                                                                        "INSTALL_TEST" => {
                                                                                                                            "conversion" => {
                                                                                                                                              "type" => "toggle",
                                                                                                                                              "value" => "STATE"
                                                                                                                                            },
                                                                                                                            "logical" => {
                                                                                                                                           "type" => "action"
                                                                                                                                         },
                                                                                                                            "operations" => "write",
                                                                                                                            "physical" => {
                                                                                                                                            "interface" => "command",
                                                                                                                                            "no_init" => true,
                                                                                                                                            "set" => {
                                                                                                                                                       "request" => "TOGGLE_INSTALL_TEST"
                                                                                                                                                     },
                                                                                                                                            "type" => "integer",
                                                                                                                                            "value_id" => "TOGGLE_FLAG"
                                                                                                                                          },
                                                                                                                            "ui_flags" => "internal"
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
                                                         }
                                         }
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
                       }
    },
  }
);	
