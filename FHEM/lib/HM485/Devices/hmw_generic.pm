package HM485::Devicefile;
our %definition = (
	'HMW_GENERIC' => {
		'version' => 	2,
		'supported_types' => 	{
			"HMW_Generic" => {
				"name" => "RS485 generic",
				"parameter" => {},
				"priority" => 0
			}
		},
		'paramset' => 	{
			"id" => "hmw-generic_dev_master",
			"type" => "master"
		},
		'channels' => 	{},
	}
);	
