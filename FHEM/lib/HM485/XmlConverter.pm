package HM485::XmlConverter;

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename;
use Getopt::Long;
use XML::Simple;
use FindBin;
use lib abs_path("$FindBin::Bin");
use Data::Dumper;
use POSIX;

use lib::HM485::Util;

my $indentStyle = 2;

sub convertFiles($$);
sub dumperSortkey($);
sub printDump($$$);
sub reMap($;$);
sub checkId($;$$$);


sub convertFile($$) {
	my ($inputFile, $outputPath) = @_;
	my $outputFile = $outputPath . substr(basename($inputFile),0,-4) . '.pm';
	$outputFile=~ s/\/\//\//g;
	
	HM485::Util::Log3(undef,4, $inputFile . ' -> ' . $outputFile);
	
	my $xml = XMLin("$inputFile", KeyAttr => {});
	# print Dumper($xml);
	$xml = reMap($xml);
	$xml->{'frames'} = $xml->{'frames'}->{'frame'};
	$xml->{'channels'} = $xml->{'channels'}->{'channel'};
	
	$xml->{'channels'} = fixChannelPeerAdresses($xml->{'channels'});
	
	checkId( $xml);
	
	my $defKey = uc(substr(basename($inputFile),0,-4));
	$defKey =~ s/-/_/g;

	$Data::Dumper::Terse = 1;
	$Data::Dumper::Indent = $indentStyle;
	$Data::Dumper::Quotekeys = 0;
	$Data::Dumper::Useqq = 1;

	my $tab = "\t";
	if ($indentStyle != 0) {
		$Data::Dumper::Quotekeys = 1;
		$Data::Dumper::Pad = $tab;
	}
	
	$Data::Dumper::Sortkeys = \&dumperSortkey;

	my $content = 'package HM485::Devicefile;' . "\n";
	my $lf = ($indentStyle != 0) ? "\n" : '';

	$content.= 'our %definition = (' . ($lf ? $lf . $tab : '') . '\'' . $defKey . '\' => {' . $lf;

	$content.= lc(printDump('version', $xml->{'version'}, 2));
	$content.= lc(printDump('eep_size', $xml->{'eep_size'}, 2));
	$content.= printDump('supported_types', $xml->{'supported_types'}, 2);
	$content.= lc(printDump('paramset', $xml->{'paramset'}, 2));
	$content.= lc(printDump('frames', $xml->{'frames'}, 2));
	$content.= lc(printDump('channels', $xml->{'channels'}, 2));
	$content.=  $tab . '}' . $lf. ');	' . $lf;
	
	$content =~ s/(\s*=>\s*)(0x[0-9])([a-z])(.*)/$1.$2.uc($3).$4/ge;	# hex Kleinbuchstaben in hex Großbuchstaben
	$content =~ s/(\s*=>\s*)(0x)([a-z]{1,4})(.*)/$1.$2.uc($3).$4/ge;	# hex Kleinbuchstaben in hex Großbuchstaben
	
	open(FH, ">$outputFile") or die('Error opening "' . $outputFile . '"');
	print FH $content;

	close(FH);
}

sub dumperSortkey($) {
	my ($hash) = @_;
	return [(sort keys %$hash)];
}

sub printDump($$$) {
	my ($key, $value, $tiefe) = @_;

	my $retVal = '';
	if ($value) {
		$retVal = Dumper($value);
		
		chop ($retVal);
		my $tab = "\t";
		$retVal = '\'' . $key . '\' => ' . $retVal . ',';
		if ($indentStyle != 0) {
			my @ar = split( "\n", $retVal);
			$retVal = '';
			foreach (@ar){
				$_ =~ s/^\s+//; # Leerzeichen am Anfang entfernen
				my $c = substr( $_, -1);
				if ( $c eq '{' && substr( $_, -2) ne '{}' && substr( $_, -3) ne '{},') {
					$retVal .= $tab x $tiefe . $_ . "\n";
					$tiefe++;
				} elsif ( ( $c eq '}' || substr( $_, -2) eq '},') && substr( $_, -2) ne '{}' && substr( $_, -3) ne '{},') {
					$tiefe--;
					$retVal .= $tab x $tiefe . $_ . "\n";
				} else {
					$retVal .= $tab x $tiefe . $_ . "\n";
				}
			}
		}
		# convert strings in values  
		$retVal =~ s/(\s*=>\s*)(")(0x[0-9a-fA-F]*)(")(.*)/$1$3$5/g;						# string to hex
		$retVal =~ s/(\s*=>\s*)(")([0-9]*\.[0-9]*)(")(.*)/$1$3$5/g;						# string to float
		$retVal =~ s/(\s*=>\s*)("#)([a-zA-Z])(")(.*)/$1.sprintf('0x%02X',ord($3)).$5/ge;	# char to hex
		$retVal =~ s/(\s*=>\s*)(")(true|false)(")(.*)/$1$3$5/g;							# true / false to 1/0
		$retVal =~ s/(\s*=>\s*)("\+)([0-9]*\.{0,1}[0-9]*)(")(.*)/$1$3$5/g;					# +1 -> 1
	
	}

	return $retVal; 
}

sub reMap($;$) {
	my ($hash,$father) = @_;
	$father = "" if(!defined($father));
	
	foreach my $param (keys %{$hash}) {

		if (ref($hash->{$param}) eq 'HASH') {
			
			if ($param eq 'type' && $hash->{$param}->{'id'}) {
				my $idField = ($hash->{$param}->{'type'}) ? 'type' : 'id';
				my $id = $hash->{$param}->{$idField};
				delete ($hash->{$param}->{$idField});
				$id =~ s/-/_/g;
				$hash->{$id} = reMap($hash->{$param});
				delete ($hash->{$param});
			}elsif ($param eq 'special_parameter' && $hash->{special_parameter}{id}) {
			    # special_parameter => { id => behaviour ...  ->   special_parameter => { behaviour => { id ...
				my $id = $hash->{special_parameter}{id};
				$id =~ s/-/_/g;
                my $remapped = reMap($hash->{special_parameter});
				delete ($hash->{special_parameter});
				$hash->{special_parameter}{$id} = $remapped;
			} else {
				if (defined($hash->{$param}{'type'}) && ($hash->{$param}{'type'} eq 'option')) {

				} elsif (defined($hash->{$param}{'type'}) && ($hash->{$param}{'type'} eq 'array')) {

					$hash->{$param} = $hash->{$param}{$param};
				} else {
				    # special handling for paramset/../parameter and frames/../parameter
					$hash->{$param} = reMap($hash->{$param}, ($father eq "paramset" or $father eq "frames") ? $father : $param);
				};
				
			}
			if ( $param eq 'supported_types') {
				if(defined($hash->{$param}{'type'})) {
					$hash->{$param} = $hash->{$param}{'type'};
				}
				$hash->{$param} = reMap($hash->{$param});
			}
		    # make sure that paramset/parameter is always an array
            if($param eq "parameter" && $father eq "paramset") {
			    $hash->{$param} = [$hash->{$param}];
			};
			# make sure that frames/../parameter is always a hash
			if($param eq "parameter" && $father eq "frames") {
			    my $newHash;
			    my $index;
			    if (defined($hash->{$param}{index})) {
				    $index = $hash->{$param}{index};
				    delete ($hash->{$param}{index});
			    } else {
				    $index = "11.0";  # this is somehow the default
			    }
			    $newHash->{$index} = $hash->{$param};
			    $hash->{$param} = $newHash;
			};			
		} elsif (ref($hash->{$param}) eq 'ARRAY') {
		    # make sure that paramset/parameter is always an array
            if($param eq "parameter" && $father eq "paramset") {
			    for(my $i=0; $i < @{$hash->{$param}}; $i++){
                    $hash->{$param}[$i] = reMap($hash->{$param}[$i]);    				
		        };
		    }else{
			    my $newHash;
			    my $id;
			    foreach my $item (@{$hash->{$param}}){
				    my $idField = ($item->{'id'}) ? 'id' : 'index';
				    if ($item->{'type'} && $param eq 'channel') {
					    $idField = 'type';
				    }
				    if (defined($item->{$idField})) {
					    $id = $item->{$idField};
					    delete ($item->{$idField});
					    $id =~ s/-/_/g;
				    } else {
					    $id ++;
				    }
				    $newHash->{$id} = $item;
			    }	
     		    # special handling for paramset/../parameter and frames/../parameter
			    $hash->{$param} = reMap($newHash, ($father eq "paramset" or $father eq "frames") ? $father : $param);
			};
		}
		
	}

	return $hash;
}

sub fixChannelPeerAdresses($) {
	my ($hash) = @_;

	foreach my $param (keys %{$hash}) {
		# convert long keys into short. E.g. hmw_input_ch_link -> link
		if ($param ne 'MAINTENANCE') {
			foreach my $param2 (keys %{$hash->{$param}{'paramset'}}) {
				my @paramArray = split('_', $param2);
				my $newParam2 = pop (@paramArray);

				$hash->{$param}{'paramset'}{$newParam2} = $hash->{$param}{'paramset'}{$param2};
				delete ($hash->{$param}{'paramset'}{$param2});
			}			
		}
	}
	
	return $hash;
}

sub checkId($;$$$){
	my ( $hash, $halt, $value, $noConvert) = @_;
	if ( ref( $hash) eq 'HASH') {
		my $newHash = {};
		foreach my $k1 (keys %{$hash}) {
		    next if($k1 eq "special_parameter");
			if ( $k1 eq 'conversion' || $k1 eq 'logical' || $k1 eq 'physical') {
				$noConvert = 1;
			}
			if ( $k1 eq 'id' && $value && !$noConvert && !defined( $hash->{parameter})) {
				$newHash = {};
				$newHash->{$hash->{$k1}} = $halt;
				my $oldHash = $newHash->{$hash->{$k1}}->{$value};
				$newHash->{$hash->{$k1}} = $newHash->{$hash->{$k1}}->{$value};
			
				$halt->{$value} = $newHash;
				last;
			}
			my $h2 = $hash->{$k1};
			if ( ref( $h2) eq 'HASH') {
				foreach my $k2 (keys %{$h2}) {
					if ( $k2 eq 'conversion' || $k2 eq 'logical' || $k2 eq 'physical') {
						$noConvert = 1;
					}
					if ( $k2 eq 'id' && !$noConvert && !defined( $h2->{parameter})) {
						$newHash = {};
						$newHash->{$h2->{$k2}} = reMap($hash->{$k1});
						$hash->{$k1} = reMap($newHash);
					} else {
						my $h3 = $h2->{$k2};
						checkId( $h3, $h2, $k2, $noConvert);
						if ( $k1 ne 'conversion' && $k1 ne 'logical' && $k1 ne 'physical' && $k2 ne 'conversion' && $k2 ne 'logical' && $k2 ne 'physical') {
							if (( $value && $value ne 'conversion' && $value ne 'logical' && $value ne 'physical') || !$value) {
								$noConvert = 0;
							}
						}
					}
				}
			}
			
		}
		$noConvert = 0;
	}
}

1;
