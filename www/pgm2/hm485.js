function FW_HM485setConfigSubmit(name, form) {
	var retVal = false;

	var submitBtn = document.getElementsByName('submit.HM485.config')[0];
	if (submitBtn && !submitBtn.getAttribute('disabled')) {

		var setName = 'val.HM485.config.set';
		
		var configValue = '';
		var configAttr = document.getElementsByClassName('arg.HM485.config');
		for(var i = 0; i < configAttr.length; i++) { 
			var attr = configAttr[i].getAttribute('name');
			var val = configAttr[i].value;
			configValue = configValue + attr + ' ' + val + ' ';
		}
		
		var elSet = document.getElementsByName(setName + name)[0];
		elSet.value = configValue
		elSet.setAttribute('name', 'val.set' + name);

		retVal = true;
	}
	
	var submitBtn = document.getElementsByName('submit.HM485.settings')[0];
	if (submitBtn && !submitBtn.getAttribute('disabled')) {
		
		var setName = 'val.HM485.settings.set';
		
		var configValue = '';
		var configAttr = document.getElementsByClassName('arg.HM485.settings');
		for(var i = 0; i < configAttr.length; i++) { 
			var attr = configAttr[i].getAttribute('name');
			var val = configAttr[i].value;
			configValue = configValue + attr + ' ' + val + ' ';
		}
		
		var elSet = document.getElementsByName(setName + name)[0];
		elSet.value = configValue
		elSet.setAttribute('name', 'val.set' + name);
		
		retVal = true;
	
	}
	
	return retVal;
}

function FW_HM485setChange(el) {
	var submitBtn = document.getElementsByName('submit.HM485.config')[0];
	if(submitBtn) {
	    submitBtn.removeAttribute('disabled');
	};	
	var submitBtn = document.getElementsByName('submit.HM485.settings')[0];
	if(submitBtn) {	
	    submitBtn.removeAttribute('disabled');
	};	
}