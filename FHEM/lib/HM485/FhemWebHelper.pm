package HM485::FhemWebHelper;

use strict;
use warnings;
use Data::Dumper;

use vars qw($FW_ss);      # is smallscreen, needed by 97_GROUP/95_VIEW
use vars qw(%FW_hiddenroom); # hash of hidden rooms, used by weblink


sub showConfig($$$) {
	my ($hash, $configHash, $linkHash) = @_;

	# if the config is not synched, then we only display the config
	# but it cannot be changed
	my $devHash = (defined($hash->{devHash}) ? $hash->{devHash} : $hash);
	my $configReady = ($devHash->{READINGS}{configStatus}{VAL} eq 'OK');
	
	my $content = '';
	if(ref($configHash) eq 'HASH') {
		$content.= makeConfigTable($hash, $configHash, $configReady);
		if(ref($linkHash) eq 'HASH') {
			$content.= makePeeringsTable($hash, $linkHash, $configReady);
		}
	}


	return $content;
}


sub makePeeringsTable($$$) {
	my ($hash, $configHash, $configReady) = @_;

	my $name = $hash->{NAME};
	my $content = '';
	my $rowCount = 1;
	
	my $title = 'Settings';
	my $className = lc($title);
	$className =~ s/[^A-Za-z]/_/g;
	
	
	#foreach my $cKey (sort { if (index($a, 'long') > -1) { return 1; } elsif (index($b, 'long') > -1) { return -1; } else { return $a cmp $b; } } keys %{$configHash}) {
	foreach my $cKey (reverse sort keys %{$configHash}) {
		
		my $config = $configHash->{$cKey};
		my $rowContent = '';
		
		if ($cKey ne 'actuator' || $cKey ne 'peerId' || $cKey eq 'ui_hint') {
			$rowContent.= wrapTd($cKey . ':');
		}		
		
		my $value = '';
		
		if ($config->{'type'} eq 'option') {
			my $possibleValusList = HM485::ConfigurationManager::optionsToList($config->{'possibleValues'});
			$value = configSelect(
				$cKey, $possibleValusList, $config->{'value'}, $className, $configReady
			);
			
		} elsif ($config->{'type'} eq 'boolean') {
			$value = configSelect(
				$cKey, 'no:0,yes:1', $config->{'value'}, $className, $configReady
			);
		} else {
			my $cSize = $config->{'max'} ? length ($config->{'max'}) : 3;
			
			if ($config->{'type'} eq 'float') {
				$cSize = $cSize + 2;
				#print Dumper ("malsehen:", $config);
				$config->{'value'} = sprintf('%.2f',$config->{'value'});
			} elsif ($config->{'type'} eq 'integer') {
				$config->{'value'} = sprintf('%d',$config->{'value'});
				$cSize = $cSize + 1;
			} elsif ($config->{'type'} eq 'address') {
				$cSize = 10;
			}
			
			if ($config->{'unit'} eq '100%') {
				$config->{'unit'} = '%';
				$config->{'value'} = sprintf('%d',$config->{'value'} * 100);
			}

			if ($cKey eq 'actuator' || $cKey eq 'peerId' || $cKey eq 'ui_hint') {
				$value = configHidden(
					$cKey, $config->{'value'}, $cSize ,$className
				);
				$content.= $value;
				next;
			} else {
				$value = configInput(
					$cKey, $config->{'value'}, $cSize ,$className, $configReady
				);
			}
			
		
		}
		
		my $unit = $config->{'unit'} ? $config->{'unit'} : '';
		
		$value = wrapDiv($value . ' ' .  $unit, '', 'dval');
		
		$rowContent.= wrapTd($value);
	
		my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
		$content.= wrapTr($rowContent, $rowClass);
		$rowCount++;
	
	}
	if (keys %{$configHash}) {
		my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
		$content.= wrapTr(
			wrapTd() . wrapTd('<input type="submit" name ="submit.HM485.'.$className.'" d_isabled="disabled" value="Save Settings" class="attr"'.($configReady ? '' : 'disabled').' >'),
			$rowClass

		);
	}

	$content = wrapTable($content, 'block wide');
	$content = wrapDiv($content, $title, 'makeTable wide');

	$content = wrapForm($content, $name, $className);
	return $content;
}


sub makeConfigTable($$$) {
	my ($hash, $configHash, $configReady) = @_;

	my $name = $hash->{'NAME'};
	my $content = '';
	my $rowCount = 1;
	
	my $title = 'Configuration';
	my $className = 'config';
	
	# print(Dumper($configHash));
	foreach my $cKey (sort keys %{$configHash}) {
		my $config = $configHash->{$cKey};
		
		# we don't show hidden parameters
		if($config->{hidden}) { next; };
		
		my $rowContent.= wrapTd($cKey . ':');
		
		my $value = '';
		if ($config->{'type'} eq 'option') {
			my $possibleValuesList = HM485::ConfigurationManager::optionsToList($config->{'possibleValues'});
			$value = configSelect(
				$cKey, $possibleValuesList, $config->{'value'}, $className, $configReady	
			);
			
		} elsif ($config->{'type'} eq 'boolean') {
			$value = configSelect($cKey, 'no:0,yes:1', $config->{'value'} ,$className, $configReady	);
		} else {
			my $cSize = $config->{'max'} ? length ($config->{'max'}) : 3;
			
			if ($config->{'type'} eq 'float') {
				$cSize = $cSize + 2;
				$config->{'value'} = sprintf('%.2f',$config->{'value'});
			} elsif ($config->{'type'} eq 'integer') {
				$config->{'value'} = sprintf('%d',$config->{'value'});
				$cSize = $cSize + 1;
				if ($cKey eq 'central_address') {
					$config->{'value'} = sprintf('%08d',$config->{'value'});
					$cSize = $cSize + 1;
				}
			}

			$value = configInput(
				$cKey, $config->{'value'}, $cSize, $className, $configReady	
			);
		}
		
		my $unit = $config->{'unit'} ? $config->{'unit'} : '';
		$value = wrapDiv($value . ' ' .  $unit, '', 'dval');
		
		$rowContent.= wrapTd($value);
	
		my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
		$content.= wrapTr($rowContent, $rowClass);
		$rowCount++;
	}

	if (keys %{$configHash}) {
		my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
		$content.= wrapTr(
			wrapTd() . wrapTd('<input type="submit" name ="submit.HM485.'.$className.
			                  '" value="Save Config" class="attr"'.($configReady ? '' : 'disabled').' >'),
			$rowClass
		);
	}

	$content = wrapTable($content, 'block wide');
	$content = wrapDiv($content, $title, 'makeTable wide');

	$content = wrapForm($content, $name, $className);
	return $content;
}


sub configInput($$;$$$) {
	my ($name, $value, $size, $className, $configReady) = @_;
	#print Dumper ("configInput $size");
	
	my $cSize = ($size ? $size : '3');
	my $content = '<input onchange="FW_HM485setChange(this)" type="text" size="'.$cSize.'" name="' . $name . '" value="' . 
	               $value . '" class="arg.HM485.'.$className.'" style="text-align:right;"'.($configReady ? '' : 'disabled').' />';

	return $content;
}

sub configHidden($$;$$) {
	my ($name, $value, $size, $className) = @_;
	#print Dumper ("configInput $size");
	
	my $cSize = ($size ? $size : '3');
	my $content = '<input onchange="FW_HM485setChange(this)" type="hidden" size="'.$cSize.'" name="' . $name . '" value="' . 
	               $value . '" class="arg.HM485.'.$className.'" style="text-align:right;" />';

	return $content;
}

=head2
	Generate a select list of $posibleValues
	$posibleValues splits at : for name value pais if exists
	
	@param	string	name of the select list
	@param	string	posible items (comma seperated)
	@param	string	the value for specific item sould selected
=cut
sub configSelect($$$$$) {
	my ($name, $possibleValues, $value, $className, $configReady) = @_;
	
	my $content = '<select onchange="FW_HM485setChange(this)" name="' . $name . 
	               '" class="arg.HM485.'.$className.'"'.($configReady ? '' : 'disabled').' >';
	my $options = '';
	my @possibleValuesArray = split(',', $possibleValues);

	# Trim all items in the array
	#@posibleValuesArray = grep(s/^\s*(.*)\s*$/$1/, @posibleValuesArray);
	
	foreach my $oKey (@possibleValuesArray) {
		my ($optionName, $optionValue) = split(':', $oKey);
		my $selected = '';
		
		if ($value eq $optionValue) {
			$selected = ' selected="selected"';
		}

		$options.= '<option value="' . $optionValue . '"' . $selected . '>' . $optionName . '</option>';
	}
	
	$content.= $options . '</select>';

	return $content;
}


sub wrapDiv($;$$) {
	my ($content, $title, $class) = @_;
	$content = ($content) ? $content : '';
	$title   = ($title) ? $title . '<br>' : '';
	$class   = ($class) ? ' class="' . $class . '"' : '';
	
	if ($content) {
		$content = '<div' . $class . '>' . $title . $content . '</div>';
	}
	return $content;
}

sub wrapTable($;$) {
	my ($content, $class) = @_;

	$content = ($content) ? $content : '';
	$class   = ($class) ? ' class="' . $class . '"' : '';

	if ($content) {
		$content = '<table' . $class . '><tbody>' . $content . '</tbody></table>';
	}
	return $content;
}

sub wrapTr($;$) {
	my ($content, $class) = @_;

	$content = ($content) ? $content : '';
	$class   = ($class) ? ' class="' . $class . '"' : '';

	if ($content) {
		$content = '<tr' . $class . '>' . $content . '</tr>';
	}
	return $content;
}

sub wrapTd($;$) {
	my ($content, $class) = @_;

	$class   = ($class) ? ' class="' . $class . '"' : '';
	$content = ($content) ? $content : '';

	$content = '<td' . $class . '>' . $content . '</td>';
	return $content;
}

sub wrapForm($$$) {
	my ($content, $name, $className) = @_;
	
	$content = '<form method="post" informId="sel_'.$name.'" onSubmit="return FW_HM485setConfigSubmit(\'' . $name . '\', this)" action="/fhem">' .
		'<input type="hidden" name="detail" value="' . $name . '">' .
		'<input type="hidden" name="dev.set' . $name . '" value="' . $name . '">' .
		'<input type="hidden" name="cmd.set' . $name . '" value="set">' .
		'<input type="hidden" name="arg.set' . $name . '" value="'.$className.'">' .
		'<input type="hidden" name="val.HM485.'.$className.'.set' . $name . '" value="logging on">' .
		$content . '</form>';
		
	return $content;
}


1;
