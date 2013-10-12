package HM485::FhemWebHelper;

use strict;
use warnings;
use Data::Dumper;

use vars qw($FW_ss);      # is smallscreen, needed by 97_GROUP/95_VIEW
use vars qw(%FW_hiddenroom); # hash of hidden rooms, used by weblink
use vars qw {%defs};

sub showConfig($$$) {
	my ($hash, $configHash, $peerHash) = @_;
	my $name = $hash->{NAME};

	my $content = '';
	if(ref($configHash) eq 'HASH') {
		$content.= makeConfigTable($hash, $configHash);
	}

	if(ref($peerHash) eq 'HASH') {
#		$content.= makePeeringsTable($hash, $peerHash);
	}
	
	return $content;
}

sub makeConfigTable($$) {
	my ($hash, $configHash) = @_;

	my $name = $hash->{NAME};
	
#	print Dumper($configHash);
	
	my $content = '';
	my $rowCount = 1;
	foreach my $cKey (sort keys %{$configHash}) {
		my $rowContent.= wrapTd($cKey . ':');
		
		my $value = '';
		if ($configHash->{$cKey}{type} eq 'option') {
			$value = configSelect($cKey, $configHash->{$cKey}{posibleValues}, $configHash->{$cKey}{value})

		} elsif ($configHash->{$cKey}{type} eq 'boolean') {
			$value = configSelect(
				$cKey, 'no,yes', ($configHash->{$cKey}{value} ? 'yes' : 'no')
			);

		} else {
			$value = configInput($cKey, $configHash->{$cKey}{value}, $configHash->{$cKey}{min}, $configHash->{$cKey}{max})
		}
		
		my $unit = $configHash->{$cKey}{unit} ? $configHash->{$cKey}{unit} : '';
		$value = wrapDiv($value . ' ' .  $unit, '', 'dval');
		
		$rowContent.= wrapTd($value);
	
		my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
		$content.= wrapTr($rowContent, $rowClass);
		$rowCount++;
	}

	my $rowClass = ($rowCount & 1) ? 'odd' : 'even';
	$content.= wrapTr(
		wrapTd() . wrapTd('<input type="submit" value="Save Config" class="attr">'),
		$rowClass
	);
	
	my $title = 'Configuration';
	my $className = lc($title);
	$className =~ s/[^A-Za-z]/_/g;

	$content = wrapTable($content, 'block wide');
	$content = wrapDiv($content, $title, 'makeTable wide');

	$content = wrapForm($content, $name);
	return $content;
}

sub configInput($$;$$) {
	my ($name, $value, $min, $max) = @_;

	my $content = '';	
#	my $content = '<input type="text" onchange="alert()" size="5" value="' . 
#	               $value . '" id="' . $name . '" class="attr">';

	return $content;
}

sub configSelect($$$) {
	my ($name, $posibleValues, $value) = @_;
	
	my $content = '<select id="arg.HM485.config' . $name . '" name="' . $name . '" class="arg.HM485.config">';
	my $options = '';
	foreach my $oKey (split(',', $posibleValues)) {
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
	$content = ($content) ? $content : '';

	$content = '<td' . $class . '>' . $content . '</td>';
	return $content;
}

sub wrapForm($$) {
	my ($content, $name) = @_;
	
	$content = '<form method="post" onSubmit="return FW_HM485setConfig(\'' . $name . '\', this)" action="/fhem">' .
		'<input type="hidden" name="detail" value="' . $name . '">' .
		'<input type="hidden" name="dev.set' . $name . '" value="' . $name . '">' .
		'<input type="hidden" name="cmd.set' . $name . '" value="set">' .
		'<input type="hidden" name="arg.set' . $name . '" value="config">' .
		'<input type="hidden" name="val.HM485.config.set' . $name . '" value="logging on">' .
		$content . '</form>';
		
	return $content;
}

1;
