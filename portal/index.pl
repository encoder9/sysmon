#!/usr/bin/perl

print "Content-type: text/html\n\n";

use CGI;
use DBI;
use JSON;
use Data::Dumper;

my $config = {};
my $c = CGI->new();
my $db = undef;
my $command = $c->param('c');

if ($command eq '') {
	loadSite();
} else {
	if ($command eq 'saveConfig') {
		saveConfig();
	}
}

exit(0);

sub loadSite {
	$config = loadConfig();
	
	if ($config->{database}->{dsn} eq '') {
		loadInstall();
	} else {
		
	}
}

sub loadConfig {
	local $/;
	open(CONFIG, 'config.json');
	my $data = <CONFIG>;
	close(CONFIG);
	
	my $js = JSON->new();
	$js->allow_blessed(1);
	$js->convert_blessed(1);
	return $js->utf8->decode($data);
}

sub saveConfigToFile {
	my $js = JSON->new();
	$js->allow_blessed(1);
	$js->convert_blessed(1);
	my $configString = $js->utf8->encode($config);
	
	open(CONFIG, '>config.json');
	print CONFIG $configString . "\n";
	close(CONFIG);
}

sub loadInstall {
	print mergeData(loadTemplate('templates/install.html'), {});
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

sub saveConfig {
	my $dsn = $c->param('dsn');
	my $uid = $c->param('uid');
	my $pwd = $c->param('pwd');
	my $host = $c->param('host');
	
	$config = loadConfig();
	
	$config->{database}->{dsn} = $dsn;
	$config->{database}->{uid} = $uid;
	$config->{database}->{pwd} = $pwd;
	$config->{database}->{host} = $host;
	
	saveConfigToFile();
	my $ret = setupDatabase();
	
	if ($ret == 1) {
		print mergeData(loadTemplate('templates/configSaved.html'), {
			success => 'block', 
			failed => 'none'
		});
	} elsif ($ret == -1) {
		print mergeData(loadTemplate('templates/configSaved.html'), {
			success => 'none', 
			failed => 'block'
		});
	}
}

sub connectToDatabase {
	$db = DBI->connect($config->{database}->{dsn} . '; host=' . $config->{database}->{host}, $config->{database}->{uid}, $config->{database}->{pwd}, {
		RaiseError => 0, 
		PrintError => 1, 
		HandleError => \&dbConnectErrorHandler
	}) or dbConnectErrorHandler(DBI->errstr);
}

sub dbConnectErrorHandler {
	my $message = shift;
	print $message;
	exit(0);
}

sub disconnectFromDatabase {
	$db->disconnect if ($db);
}

sub setupDatabase {
	connectToDatabase();
	
	if ($db) {
		
		
		disconnectFromDatabase();
		return 1;
	} else {
		return -1;
	}
}
