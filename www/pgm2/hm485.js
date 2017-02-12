function FW_HM485ConfigSaveClicked(name) {
	var submitBtn = $("#submit.HM485.config");
	if (!submitBtn) return;
    if(submitBtn.attr('disabled')) return;	
	var configValue = '';
	$( ".argHM485config" ).each(function() {
		configValue += $(this).attr('name') + ' ' + $(this).val() + ' ';
    });
	var cmd = '/fhem?XHR=1&cmd=set ' + name + ' config ' + configValue;
    FW_cmd(cmd);		
	FW_HM485CloseConfigDialog();
}


function FW_HM485PeersettingsSaveClicked(name) {
	var submitBtn = $("#submit.HM485.config");
	if (submitBtn && !submitBtn.attr('disabled')) {	
		var configValue = '';
		$( ".argHM485settings" ).each(function() {
			configValue += $(this).attr('name') + ' ' + $(this).val() + ' ';
        });
		var cmd = '/fhem?XHR=1&cmd=set ' + name + ' settings ' + configValue;
        FW_cmd(cmd);		
	}
}


function FW_HM485PeerConfigSaveClicked(name) {
	var submitBtn = $("#submit.HM485.config");
	if (!submitBtn) return;
    if(submitBtn.attr('disabled')) return;	
	var configValue = '';
	var sensorName = '';
	var sensorAddress = '';
	var isSensor = false;
	$( ".argHM485config" ).each(function() {
		switch($(this).attr('name')){
			case 'actuator':
			    // this means there are no settings
				FW_errmsg("Sensors don't have peer settings. Configure from actuator channel.",5000);
				isSensor = true;
				return false;
            case 'sensor':
			    // just save for error message
				sensorAddress = $(this).val();
				break;
			case 'sensorname':
                sensorName = $(this).val();
                break;
            case 'channel':
                // ignore
                break;				
            case 'hmid':
		        configValue += 'actuator ' + $(this).val() + ' ';
			default:
		        configValue += $(this).attr('name') + ' ' + $(this).val() + ' ';
		};
    });
	if(isSensor) return;
	if(sensorName == ''){
	    FW_errmsg("Sensor is not defined in FHEM: " + sensorAddress,5000);
		return;
	};	
	var cmd = '/fhem?XHR=1&cmd=set ' + sensorName + ' settings ' + configValue;
    FW_cmd(cmd);		
	FW_HM485CloseConfigDialog();
}


function FW_HM485OpenConfigDialog() {
	var configArea = $("#configArea");
	// XMLHTTP request to get config options with current values
	FW_cmd('/fhem?XHR=1&cmd=get ' + configArea.attr('data-name') + ' config ', FW_HM485OCDCallback);
};	


function FW_HM485OpenPeerList() {
	var configArea = $("#configArea");
	// XMLHTTP request to get config options with current values
	FW_cmd('/fhem?XHR=1&cmd=get ' + configArea.attr('data-name') + ' peerlist ', FW_HM485PeerlistCallback);
};	


function FW_HM485OpenPeerConfigDialog(actSen,peerId) {
	var configArea = $("#configArea");
	// XMLHTTP request to get config options with current values
	FW_cmd('/fhem?XHR=1&cmd=get ' + configArea.attr('data-name') + ' peerconfig ' 
	                              + actSen.slice(0,-1) + ' ' + peerId, FW_HM485PeerConfigCallback);
};	


function FW_HM485CloseConfigDialog() {
	var configArea = $("#configArea");
	var html = "";
	if(configArea.attr('data-hasconfig') == "yes") {
	    html += "<div class=\"makeTable wide\"><input type=\"button\" value=\"";
	    if(configArea.attr('data-ischannel') == "yes") {
		    html += "Channel";
        }else{
            html += "Device";
		};
        html += " Configuration\" class=\"attr\" onClick = \"FW_HM485OpenConfigDialog(\'" + configArea.attr('data-name') + "\')\">";
	};
	if(configArea.attr('data-peered') == "yes") {
		html += "<input type=\"button\" value=\"Peering Configuration\" class=\"attr\" onClick = \"FW_HM485OpenPeerList(\'" + configArea.attr('data-name') + "\')\">"
	};
    html += "</div>"
	configArea.html(html);
};	

	
function FW_HM485OCDCallback(configJson) {	

    var config = JSON.parse(configJson);
	// error message?
	if(config[".message"]) {
		FW_errmsg(config[".message"].value,5000);
		return;
	};	

	var configArea = $("#configArea");	
    var htmlObj = { even : false,
	                html : "<div class=\"makeTable wide\">Device Configuration<br><table class=\"block wide\"><tbody>" 
				  };
	FW_HM485MakeConfigTable(config, htmlObj)
	htmlObj.html += "<tr class=";
	if(htmlObj.even){
	    htmlObj.html += "\"even\"";	 
    }else{
		htmlObj.html += "\"odd\"";
    };			
    htmlObj.html += "><td colspan=\"2\"><input type=\"button\" id=\"submit.HM485.config\" value=\"Write to Device\" class=\"attr\" onClick = \"FW_HM485ConfigSaveClicked('" + configArea.attr('data-name') + "')\">" +
	"<input type=\"button\" id=\"cancel.HM485.config\" value=\"Cancel\" class=\"attr\" onClick = \"FW_HM485CloseConfigDialog()\"></td></tr></tbody></table></div><br>";
	
	configArea.html(htmlObj.html);
	/* configArea.html("<div class=\"makeTable wide\">Configuration<br><table class=\"block wide\"><tbody><tr class=\"odd\"><td>logging_time:</td><td><div class=\"dval\"><input type=\"text\" size=\"6\" name=\"logging_time\" value=\"2.00\" class=\"argHM485config\" style=\"text-align:right;\" /> s</div></td></tr><tr class=\"even\"><td></td><td><input type=\"button\" id=\"submit.HM485.config\" value=\"Write to Device\" class=\"attr\" onClick = \"FW_HM485ConfigSaveClicked('HMW_LC_Sw2_DR_KEQ1056682')\"></td></tr></tbody></table></div><br>"); */
};	


function FW_HM485MakeConfigTable(config, htmlObj) {	
    
	// loop through the config options
	for(var cName in config){
	    // hidden options are needed for later reference when saving
		if(parseInt(config[cName].hidden)){
	        htmlObj.html += "<tr><td><input type=\"hidden\" name=\"" + cName + 
			                "\" value=\"" + config[cName].value + 
							"\" class=\"argHM485config\" style=\"text-align:right;\" /></td></tr>";
		    continue;
		};
		// start of the table row
		htmlObj.html += "<tr class=";
		if(htmlObj.even){
		    htmlObj.html += "\"even\"";	 
        }else{
			htmlObj.html += "\"odd\"";
        };			
		// name of the config option
		htmlObj.html += "><td>" + cName + "</td><td><div class=\"dval\">";
        // now it depends on the type
        switch(config[cName].type){
            case 'option':
			// <select name="input_type" class="argHM485config" ><option value="0">switch</option><option value="1" selected="selected">pushbutton</option></select>
			    htmlObj.html += "<select name=\"" + cName + "\" class=\"argHM485config\">";
				for(var i = 0; i < config[cName].possibleValues.length; i++) {
					htmlObj.html += "<option value=\"" + i.toString() + "\"";
					if(i == parseInt(config[cName].value)) {
						htmlObj.html += " selected=\"selected\"";
					};	
					htmlObj.html += ">" + config[cName].possibleValues[i] + "</option>";
				};	
				htmlObj.html += "</select>";
				break;
			case 'boolean':
			// <select ncSame="input_locked" class="argHM485config" ><option value="0" selected="selected">no</option><option value="1">yes</option></select>
			    htmlObj.html += "<select name=\"" + cName + "\" class=\"argHM485config\">";
				if(parseInt(config[cName].value)) {
                    htmlObj.html += "<option value=\"0\">no</option><option value=\"1\" selected=\"selected\">yes</option>"; 
                }else{
                    htmlObj.html += "<option value=\"0\" selected=\"selected\">no</option><option value=\"1\">yes</option>"; 
                };
				htmlObj.html += "</select>";
                break;				
			case 'float':
			case 'integer':	
			// <input type="text" size="3" name="long_press_time" value="2.00" class="argHM485config" style="text-align:right;" />
			    var cSize = 3;
				if(config[cName].hasOwnProperty("max")){ 
				    cSize = config[cName].max.length +1;
				};
                if(config[cName].type == "float") {
                    cSize++;
                };
                htmlObj.html += "<input type=\"text\" size=\"" + cSize.toString() + "\" name=\"" + cName + "\" " + 
				        "value=\"" + config[cName].value + "\" class=\"argHM485config\" "+
						"style=\"text-align:right;\" />";		
                break;
            default:
                htmlObj.html += config[cName].value;
        };
        if(config[cName].hasOwnProperty("unit")){
            htmlObj.html += " " + config[cName].unit;
        };		
		htmlObj.html += "</div></td></tr>";
		htmlObj.even = !htmlObj.even;
	};	
};	



function FW_HM485PeerlistCallback(configJson) {	

    var config = JSON.parse(configJson);
	// error message?
	if(config[".message"]) {
		FW_errmsg(config[".message"].value,5000);
		return;
	};	

	var configArea = $("#configArea");	
    var even = false;
	var html = "<div class=\"makeTable wide\">Peerings List<br><table class=\"block wide\"><tbody>";
	// loop through the peers options
    for(var actSen in config) {
		html += "<tr class=";
		if(even){
		    html += "\"even\"";	 
        }else{
			html += "\"odd\"";
        };			
		even = !even;
        html += "><td></td><td>";
		if(actSen == "actuators") {
			html += "Actuator";
		}else{
            html += "Sensor";
        };
        html += "</td><td></td></tr>";		
	for(var cName in config[actSen]){
		// start of the table row
		html += "<tr class=";
		if(even){
		    html += "\"even\"";	 
        }else{
			html += "\"odd\"";
        };			
		// number and name of the peer 
		// TODO: Button for config
		html += "><td>" + cName + "</td><td>" + config[actSen][cName] + "</td><td><input type=\"button\" id=\"peersettings.HM485.config\" value=\"Configure Peering\" class=\"attr\" onClick = \"FW_HM485OpenPeerConfigDialog('"+actSen+"','"+cName+"')\"></td></tr>";
		even = !even;
	};	
	};
	html += "<tr class=";
	if(even){
	    html += "\"even\"";	 
    }else{
		html += "\"odd\"";
    };			
    html += "><td colspan=\"3\"><input type=\"button\" id=\"cancel.HM485.config\" value=\"Cancel\" class=\"attr\" onClick = \"FW_HM485CloseConfigDialog()\"></td></tr></tbody></table></div><br>";
	
	configArea.html(html);
};	


function FW_HM485PeerConfigCallback(configJson) {	

    var config = JSON.parse(configJson);
	// error message?
	if(config[".message"]) {
		FW_errmsg(config[".message"].value,5000);
		return;
	};	

	var configArea = $("#configArea");		
    var htmlObj = { even : false,
	                html : "<div class=\"makeTable wide\">Peering Configuration<br><table class=\"block wide\"><tbody>" 
				  };
	FW_HM485MakeConfigTable(config, htmlObj)
	htmlObj.html += "<tr class=";
	if(htmlObj.even){
	    htmlObj.html += "\"even\"";	 
    }else{
		htmlObj.html += "\"odd\"";
    };			
    htmlObj.html += "><td colspan=\"2\"><input type=\"button\" id=\"submit.HM485.config\" value=\"Write to Device\" class=\"attr\" onClick = \"FW_HM485PeerConfigSaveClicked('" + configArea.attr('data-name') + "')\">" +
	"<input type=\"button\" id=\"cancel.HM485.config\" value=\"Cancel\" class=\"attr\" onClick = \"FW_HM485CloseConfigDialog()\"></td></tr></tbody></table></div><br>";
	
	configArea.html(htmlObj.html);
};	