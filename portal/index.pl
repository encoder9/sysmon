#!/usr/bin/perl

print "Content-type: text/html\n\n";

use CGI;
use DBI;
use JSON;
use Data::Dumper;

my $config = {};
my $c = CGI->new();
my $command = $c->param('c');

if ($command eq '') {
	loadSite();
} else {
	
}

exit(0);

sub loadSite {
	# Load Config.json
	local $/;
	open(CONFIG, 'config.json');
	my $data = <CONFIG>;
	close(CONFIG);
	
	my $js = JSON->new();
	$js->allow_blessed(1);
	$js->convert_blessed(1);
	$config = $js->utf8->decode($data);
	
	if ($config->{database}->{dsn} eq '') {
		loadInstall();
	} else {
		
	}
}

sub loadInstall {
	print mergeData(loadTemplate('templates/install.html'), {
		foo => 'bar'
	});
}

sub loadTemplate {
	my $fileName = shift;
	my $data;
	
	open(FILE, $fileName) || warn "Can not open file: " . $fileName;
	
	while(<FILE>) {
		$data .= $_;
	}
	
	close(FILE);
	
	return $data;
}

sub mergeData {
	my (
		$template, 
		$data
	) = @_;
	
	$template =~ s/_%(\w*)%_/$$data{$1}/g;
	
	return $template;
}
