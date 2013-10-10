package HM485::FhemWebHelper;

use strict;
use warnings;
use Data::Dumper;

use vars qw($FW_ss);      # is smallscreen, needed by 97_GROUP/95_VIEW
use vars qw(%FW_hiddenroom); # hash of hidden rooms, used by weblink
use vars qw {%defs};

sub showConfig($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	my $content = '';
	my $configs = $hash->{CONFIGS};
	if(ref($configs) eq 'HASH') {
		$content.= makeConfigTable($hash, $configs);
	}

	my $peerings = $hash->{PEERINGS};
	if(ref($configs) eq 'HASH') {
#		$content.= makePeeringsTable($hash, $peerings);
	}
	
	return $content;
}

sub makeConfigTable($$) {
	my ($hash, $configs) = @_;

	my $name = $hash->{NAME};
	
	my $content = '';
	my $rowCount = 1;
	foreach my $cKey (sort keys %{$configs}) {
		my $rowContent.= wrapTd($cKey . ':');
		
		my $value = '';
		if ($configs->{$cKey}{type} eq 'option') {
			$value = configSelect($cKey, $configs->{$cKey}{posibleValues}, $configs->{$cKey}{value})
		} else {
			$value = configInput($cKey, $configs->{$cKey}{value}, $configs->{$cKey}{min}, $configs->{$cKey}{max})
		}
		
		my $unit = $configs->{$cKey}{unit} ? $configs->{$cKey}{unit} : '';
		$value = wrapDiv($value . ' ' .  $unit, '', 'dval');
		
		$rowContent.= wrapTd($value);
	
		my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
		$content.= wrapTr($rowContent, $rowClass);
		$rowCount++;
	}

	my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
	$content.= wrapTr(
		wrapTd() . wrapTd('<input type="submit" name="" value="Save Config" class="attr">'),
		$rowClass
	);
	
	my $title = 'Configuration';
	my $className = lc($title);
	$className =~ s/[^A-Za-z]/_/g;

	$content = wrapTable($content, 'block wide');
	$content = wrapDiv($content, $title, 'makeTable wide');

	return $content;
}

sub configInput($$;$$) {
	my ($name, $value, $min, $max) = @_;
	
	my $content = '<input type="text" onchange="alert()" size="5" value="' . 
	               $value . '" id="' . $name . '" name="' . $name . '" class="attr">';

	return $content;
}

sub configSelect($$$) {
	my ($name, $posibleValues, $value) = @_;
	
	my $content = '<select onchange="alert()" id="' . $name . '" name="' . $name . '" class="set">';
	my $options = '';
	foreach my $oKey (split(':', $posibleValues)) {
		$options.= '<option value="' . $oKey . '">' . $oKey . '</option>';
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

	$content = '<td' . $class . '>' . $content . '</td>';
	return $content;
}

1;