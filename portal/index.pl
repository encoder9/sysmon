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
my $js = JSON->new();
$js->allow_blessed(1);
$js->convert_blessed(1);

if ($command eq '') {
	loadSite();
} else {
	if ($command eq 'saveConfig') {
		saveConfig();
	} elsif ($command eq 'updateHostData') {
		updateHostData();
	} elsif ($command eq 'getData') {
		getData();
	}
}

exit(0);

sub loadSite {
	$config = loadConfig();
	
	if ($config->{database}->{dsn} eq '') {
		loadInstall();
	} else {
		renderData();
	}
}

sub loadConfig {
	local $/;
	open(CONFIG, 'config.json');
	my $data = <CONFIG>;
	close(CONFIG);
	
	return $js->utf8->decode($data);
}

sub saveConfigToFile {
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
	setupDatabase();
	
	print mergeData(loadTemplate('templates/configSaved.html'), {});
}

sub connectToDatabase {
	$config = loadConfig();
	
	$db = DBI->connect($config->{database}->{dsn} . ';host=' . $config->{database}->{host}, $config->{database}->{uid}, $config->{database}->{pwd}, {
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
		$db->do('CREATE TABLE IF NOT EXISTS sysmon_hosts (hostID serial not null, hostname varchar(255) not null, systemDate varchar(100) not null, lastUpdated datetime not null, uptime varchar(25) not null, userCount int not null, loadAvg1 varchar(10) not null, loadAvg5 varchar(10) not null, loadAvg15 varchar(10) not null);');
		$db->do('CREATE TABLE IF NOT EXISTS sysmon_top (hostID bigint unsigned not null, pid varchar(10) not null, user varchar(25) not null, pri varchar(3) not null, nice varchar(3) not null, virt varchar(10) not null, res varchar(10) not null, shr varchar(10) not null, s varchar(1) not null, cpu varchar(5) not null, mem varchar(5) not null, ptime varchar(10) not null, proc varchar(100) not null);');
		$db->do('CREATE TABLE IF NOT EXISTS sysmon_netstat (hostID bigint unsigned not null, proto varchar(5) not null, recv varchar(5) not null, send varchar(5) not null, lip varchar(25) not null, rip varchar(25) not null, st varchar(25) not null, proc varchar(100) not null);');
		$db->do('CREATE TABLE IF NOT EXISTS sysmon_df (hostID bigint unsigned not null, fs varchar(25) not null, sz varchar(25) not null, used varchar(25) not null, av varchar(25) not null, per varchar(5) not null, mount varchar(100) not null);');
		$db->do('CREATE TABLE IF NOT EXISTS sysmon_w (hostID bigint unsigned not null, user varchar(25) not null, tty varchar(10) not null, fr varchar(50) not null, login varchar(10) not null, idle varchar(10) not null, jcpu varchar(10) not null, pcpu varchar(10) not null, proc varchar(100) not null);');
		disconnectFromDatabase();
	}
}

sub renderData {
	print mergeData(loadTemplate('templates/site.html'), {
		
	});
}

sub updateHostData {
	my $p = $c->param('p');
	my $payload = $js->utf8->decode($p);
	
	connectToDatabase();
	
	if ($db) {
		my $sth = $db->prepare('SELECT hostID FROM sysmon_hosts WHERE hostname = ?;');
		$sth->execute($payload->{host});
		my $hashRef = $sth->fetchrow_hashref;
		$sth->finish;
		
		my $hostID = $hashRef->{hostID};
		
		if (defined($hostID)) {
			$sth = $db->prepare('UPDATE sysmon_hosts SET hostname = ?, systemDate = ?, lastUpdated = now(), uptime = ?, userCount = ?, loadAvg1 = ?, loadAvg5 = ?, loadAvg15 = ? WHERE hostID = ?;');
			$sth->execute(
				$payload->{host}, 
				$payload->{date}, 
				$payload->{uptime}->{systemUpTime}, 
				$payload->{uptime}->{userCount}, 
				$payload->{uptime}->{la1}, 
				$payload->{uptime}->{la5}, 
				$payload->{uptime}->{la15}, 
				$hostID
			);
			
			$sth->finish;
		} else {
			$sth = $db->prepare('INSERT INTO sysmon_hosts (hostID, hostname, systemDate, lastUpdated, uptime, userCount, loadAvg1, loadAvg5, loadAvg15) VALUES (null, ?, ?, now(), ?, ?, ?, ?, ?);');
			$sth->execute(
				$payload->{host}, 
				$payload->{date}, 
				$payload->{uptime}->{systemUpTime}, 
				$payload->{uptime}->{userCount}, 
				$payload->{uptime}->{la1}, 
				$payload->{uptime}->{la5}, 
				$payload->{uptime}->{la15}
			);
			
			$hostID = $sth->{mysql_insertid};
			$sth->finish;
		}
		
		$db->do('DELETE FROM sysmon_top WHERE hostID = ' . $hostID . ';');
		$db->do('DELETE FROM sysmon_netstat WHERE hostID = ' . $hostID . ';');
		$db->do('DELETE FROM sysmon_df WHERE hostID = ' . $hostID . ';');
		$db->do('DELETE FROM sysmon_w WHERE hostID = ' . $hostID . ';');
		
		foreach my $item (@{$payload->{top}}) {
			$sth = $db->prepare('INSERT INTO sysmon_top (hostID, pid, user, pri, nice, virt, res, shr, s, cpu, mem, ptime, proc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);');
			$sth->execute(
				$hostID, 
				$item->{pid}, 
				$item->{user}, 
				$item->{pri}, 
				$item->{nice}, 
				$item->{virt}, 
				$item->{res}, 
				$item->{shr}, 
				$item->{s}, 
				$item->{cpu}, 
				$item->{mem}, 
				$item->{time}, 
				$item->{proc}
			);
			$sth->finish;
		}
		
		foreach my $item (@{$payload->{netstat}}) {
			$sth = $db->prepare('INSERT INTO sysmon_netstat (hostID, proto, recv, send, lip, rip, st, proc) VALUES (?, ?, ?, ?, ?, ?, ?, ?);');
			$sth->execute(
				$hostID, 
				$item->{proto}, 
				$item->{recv}, 
				$item->{send}, 
				$item->{lip}, 
				$item->{rip}, 
				$item->{state}, 
				$item->{proc}
			);
			$sth->finish;
		}
		
		foreach my $item (@{$payload->{df}}) {
			$sth = $db->prepare('INSERT INTO sysmon_df (hostID, fs, sz, used, av, per, mount) VALUES (?, ?, ?, ?, ?, ?, ?);');
			$sth->execute(
				$hostID, 
				$item->{fs}, 
				$item->{size}, 
				$item->{used}, 
				$item->{av}, 
				$item->{per}, 
				$item->{mount}
			);
			$sth->finish;
		}
		
		foreach my $item (@{$payload->{w}}) {
			$sth = $db->prepare('INSERT INTO sysmon_w (hostID, user, tty, fr, login, idle, jcpu, pcpu, proc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);');
			$sth->execute(
				$hostID, 
				$item->{user}, 
				$item->{tty}, 
				$item->{from}, 
				$item->{login}, 
				$item->{idle}, 
				$item->{jcpu}, 
				$item->{pcpu}, 
				$item->{proc}
			);
			$sth->finish;
		}
	}
	
	print "Thank you\n";
}

sub getData {
	my $what = $c->param('w');
	my $sd = $c->param('sd');
	my $ed = $c->param('ed');
	
	$sd =~ s/\-//g;
	$sd =~ s/\://g;
	$sd =~ s/\s//g;
	
	$ed =~ s/\-//g;
	$ed =~ s/\://g;
	$ed =~ s/\s//g;
	
	my $basePath = '../daemon/dataFiles/';
	my @data = ();
	open(FH, $basePath . $what . '.log');
	
	while(<FH>) {
		chomp();
		my @bitz = split(/:/);
		
		if ($bitz[0] >= $sd && $bitz[0] <= $ed) {
			print $_ . "\n";
		}
	}
	
	close(FH);
}
