package HM485::Devicefile;
our %definition = (
  'HMW_IO12_SW14_DR' => {
    'version' =>     12,
    'eep_size' =>     1024,
    'supported_types' =>     {
      "HMW_IO_12_Sw14_DR" => {
                               "name" => "RS485 I/O module 12-channel in and switch actuator 14-channel (DIN rails)",
                               "parameter" => {
                                                0 => {
                                                       "const_value" => 28,
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
                     "id" => "CENTRAL_ADDRESS",
                     "value" => 1
                   },
      "id" => "HMW-IO-12-Sw14-DR_dev_master",
      "parameter" => {
                       "hidden" => true,
                       "id" => "CENTRAL_ADDRESS",
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
      "type" => "MASTER"
    },
    'frames' =>     {
      "INFO_FREQUENCY" => {
                            "channel_field" => 10,
                            "direction" => "from_device",
                            "event" => true,
                            "parameter" => {
                                             "index" => 11.0,
                                             "param" => "STATE",
                                             "size" => 3.0,
                                             "type" => "integer"
                                           },
                            "type" => 0x69
                          },
      "INFO_LEVEL" => {
                        "channel_field" => 10,
                        "direction" => "from_device",
                        "event" => true,
                        "parameter" => {
                                         "index" => 11.0,
                                         "param" => "STATE",
                                         "size" => 2.0,
                                         "type" => "integer"
                                       },
                        "type" => 0x69
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
                                        "size" => 2.0,
                                        "type" => "integer"
                                      },
                       "type" => 0x73
                     }
    },
    'channels' =>     {
      "DIGITAL_ANALOG_INPUT" => {
                                  "count" => 6,
                                  "index" => 21,
                                  "paramset" => {
                                                  "link" => {},
                                                  "master" => {
                                                                "parameter" => {
                                                                                 "BEHAVIOUR" => {
                                                                                                  "logical" => {
                                                                                                                 "option" => {
                                                                                                                               "ANALOG_INPUT" => {},
                                                                                                                               "DIGITAL_INPUT" => {
                                                                                                                                                    "default" => true
                                                                                                                                                  }
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
                                                                                 "CALIBRATION" => {
                                                                                                    "conversion" => {
                                                                                                                      1 => {
                                                                                                                             "offset" => 127,
                                                                                                                             "type" => "integer_integer_scale"
                                                                                                                           },
                                                                                                                      2 => {
                                                                                                                             "type" => "integer_integer_map",
                                                                                                                             "value_map" => {
                                                                                                                                              "device_value" => 0xff,
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
                                                                "type" => "MASTER"
                                                              },
                                                  "values" => {
                                                                "parameter" => {
                                                                                 "conversion" => {
                                                                                                   "factor" => 1,
                                                                                                   "type" => "float_integer_scale"
                                                                                                 },
                                                                                 "id" => "VALUE",
                                                                                 "logical" => {
                                                                                                "max" => 1000,
                                                                                                "min" => 0,
                                                                                                "type" => "float"
                                                                                              },
                                                                                 "operations" => "read,event",
                                                                                 "physical" => {
                                                                                                 "event" => {
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
                                                                                          "index" => 8.0,
                                                                                          "step" => 0.1
                                                                                        },
                                                                           "interface" => "eeprom",
                                                                           "size" => 0.1,
                                                                           "type" => "integer"
                                                                         }
                                                         },
                                  "subconfig" => {
                                                   "paramset" => {
                                                                   "hmw_digital_input_values" => {
                                                                                                   "parameter" => {
                                                                                                                    "conversion" => {
                                                                                                                                      "false" => 0,
                                                                                                                                      "threshold" => 1,
                                                                                                                                      "true" => 1023,
                                                                                                                                      "type" => "boolean_integer"
                                                                                                                                    },
                                                                                                                    "id" => "STATE",
                                                                                                                    "logical" => {
                                                                                                                                   "default" => false,
                                                                                                                                   "type" => "boolean"
                                                                                                                                 },
                                                                                                                    "operations" => "read,event",
                                                                                                                    "physical" => {
                                                                                                                                    "event" => {
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
                                                                                                                  },
                                                                                                   "type" => "VALUES"
                                                                                                 },
                                                                   "hmw_io_ch_master" => {
                                                                                           "parameter" => {
                                                                                                            "id" => "BEHAVIOUR",
                                                                                                            "logical" => {
                                                                                                                           "option" => {
                                                                                                                                         "ANALOG_INPUT" => {},
                                                                                                                                         "DIGITAL_INPUT" => {
                                                                                                                                                              "default" => true
                                                                                                                                                            }
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
                                                                                           "type" => "MASTER"
                                                                                         }
                                                                 }
                                                 }
                                },
      "DIGITAL_ANALOG_OUTPUT" => {
                                   "count" => 8,
                                   "index" => 7,
                                   "paramset" => {
                                                   "link" => {},
                                                   "master" => {
                                                                 "parameter" => {
                                                                                  "BEHAVIOUR" => {
                                                                                                   "logical" => {
                                                                                                                  "option" => {
                                                                                                                                "ANALOG_OUTPUT" => {},
                                                                                                                                "DIGITAL_OUTPUT" => {
                                                                                                                                                      "default" => true
                                                                                                                                                    }
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
                                                                                  "PULSETIME" => {
                                                                                                   "conversion" => {
                                                                                                                     1 => {
                                                                                                                            "factor" => 100,
                                                                                                                            "offset" => 0.0,
                                                                                                                            "type" => "float_integer_scale"
                                                                                                                          },
                                                                                                                     2 => {
                                                                                                                            "type" => "integer_integer_map",
                                                                                                                            "value_map" => {
                                                                                                                                             "device_value" => 0xffff,
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
                                                                 "type" => "MASTER"
                                                               },
                                                   "values" => {
                                                                 "parameter" => {
                                                                                  "control" => "DIGITAL_ANALOG_OUTPUT.FREQUENCY",
                                                                                  "conversion" => {
                                                                                                    "type" => "float_integer_scale"
                                                                                                  },
                                                                                  "id" => "FREQUENCY",
                                                                                  "logical" => {
                                                                                                 "max" => 50000.0,
                                                                                                 "min" => 0.0,
                                                                                                 "type" => "float",
                                                                                                 "unit" => "mHz"
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
                                                    "paramset" => {
                                                                    "hmw_digital_output_values" => {
                                                                                                     "parameter" => {
                                                                                                                      "control" => "SWITCH.STATE",
                                                                                                                      "conversion" => {
                                                                                                                                        "false" => 0,
                                                                                                                                        "threshold" => 1,
                                                                                                                                        "true" => 1023,
                                                                                                                                        "type" => "boolean_integer"
                                                                                                                                      },
                                                                                                                      "id" => "STATE",
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
                                                                                                     "type" => "VALUES"
                                                                                                   },
                                                                    "hmw_io_ch_master" => {
                                                                                            "parameter" => {
                                                                                                             "id" => "BEHAVIOUR",
                                                                                                             "logical" => {
                                                                                                                            "option" => {
                                                                                                                                          "ANALOG_OUTPUT" => {},
                                                                                                                                          "DIGITAL_OUTPUT" => {
                                                                                                                                                                "default" => true
                                                                                                                                                              }
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
                                                                                            "type" => "MASTER"
                                                                                          }
                                                                  }
                                                  }
                                 },
      "DIGITAL_INPUT" => {
                           "count" => 6,
                           "index" => 15,
                           "paramset" => {
                                           "link" => {},
                                           "master" => {
                                                         "parameter" => {
                                                                          "id" => "BEHAVIOUR",
                                                                          "logical" => {
                                                                                         "option" => {
                                                                                                       "DIGITAL_INPUT" => {
                                                                                                                            "default" => true
                                                                                                                          },
                                                                                                       "FREQUENCY_INPUT" => {}
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
                                                         "type" => "MASTER"
                                                       },
                                           "values" => {
                                                         "parameter" => {
                                                                          "conversion" => {
                                                                                            "factor" => 1.0,
                                                                                            "type" => "float_integer_scale"
                                                                                          },
                                                                          "id" => "FREQUENCY",
                                                                          "logical" => {
                                                                                         "max" => 350000,
                                                                                         "min" => 0,
                                                                                         "type" => "float",
                                                                                         "unit" => "mHz"
                                                                                       },
                                                                          "operations" => "read,event",
                                                                          "physical" => {
                                                                                          "event" => {
                                                                                                       "frame" => "INFO_FREQUENCY"
                                                                                                     },
                                                                                          "get" => {
                                                                                                     "request" => "LEVEL_GET",
                                                                                                     "response" => "INFO_FREQUENCY"
                                                                                                   },
                                                                                          "interface" => "command",
                                                                                          "type" => "integer",
                                                                                          "value_id" => "STATE"
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
                                                                                   "index" => 9.0,
                                                                                   "step" => 0.1
                                                                                 },
                                                                    "interface" => "eeprom",
                                                                    "size" => 0.1,
                                                                    "type" => "integer"
                                                                  }
                                                  },
                           "subconfig" => {
                                            "paramset" => {
                                                            "hmw_digital_input_values" => {
                                                                                            "parameter" => {
                                                                                                             "conversion" => {
                                                                                                                               "false" => 0,
                                                                                                                               "threshold" => 1,
                                                                                                                               "true" => 1023,
                                                                                                                               "type" => "boolean_integer"
                                                                                                                             },
                                                                                                             "id" => "STATE",
                                                                                                             "logical" => {
                                                                                                                            "default" => false,
                                                                                                                            "type" => "boolean"
                                                                                                                          },
                                                                                                             "operations" => "read,event",
                                                                                                             "physical" => {
                                                                                                                             "event" => {
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
                                                                                                           },
                                                                                            "type" => "VALUES"
                                                                                          },
                                                            "hmw_io_ch_master" => {
                                                                                    "parameter" => {
                                                                                                     "id" => "BEHAVIOUR",
                                                                                                     "logical" => {
                                                                                                                    "option" => {
                                                                                                                                  "DIGITAL_INPUT" => {
                                                                                                                                                       "default" => true
                                                                                                                                                     },
                                                                                                                                  "FREQUENCY_INPUT" => {}
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
                                                                                    "type" => "MASTER"
                                                                                  }
                                                          }
                                          }
                         },
      "DIGITAL_OUTPUT" => {
                            "count" => 6,
                            "index" => 1,
                            "paramset" => {
                                            "link" => {},
                                            "master" => {
                                                          "type" => "MASTER"
                                                        },
                                            "values" => {
                                                          "parameter" => {
                                                                           "control" => "SWITCH.STATE",
                                                                           "conversion" => {
                                                                                             "false" => 0,
                                                                                             "threshold" => 1,
                                                                                             "true" => 1023,
                                                                                             "type" => "boolean_integer"
                                                                                           },
                                                                           "id" => "STATE",
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
                       }
    },
  }
);	
