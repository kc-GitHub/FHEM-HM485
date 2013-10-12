function FW_HM485setConfig(name, form) {
	var setName = 'val.HM485.config.set';
	
	var elSet = document.getElementsByName(setName + name)[0];

	var configAttr = document.getElementsByClassName('arg.HM485.config');
	for(var i = 0; i < configAttr.length; i++) { 
		console.log(configAttr[i].getAttribute('name'));
	}
	
	
	
	elSet.setAttribute('name', setName + name);

	console.log(name, elSet, configAttr);
	
	return false;
}
