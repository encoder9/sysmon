#!/usr/bin/perl
#
# System Monitor - Created by Bradley J. Gibby :)
# Version 1.0 - 2014-08-05 - Gizmo :(
#

use JSON;
use LWP::UserAgent;

my $portalBaseURL = 'http://localhost/sysmon/'
my $outputData = 0;
my %payload = ();

print "System Monitor - Created by Bradley J. Gibby :)\n" if ($outputData);

# System Uptime
processUptime();

# Top
processTop();

# Netstat
processNetstat();

# DF
processDF();

# MISC
processMISC();

# W
processW();

my $js = JSON->new();
$js->allow_blessed(1);
$js->convert_blessed(1);
my $jsonString = $js->utf8->encode(\%payload);



exit(0);

sub processUptime {
	print "Processing Uptime\n" if ($outputData);
	
	my %uptime = ();
	my $rawUptime = `uptime`;
	
	$rawUptime =~ /^\s*(.*?)\sup/;
	$uptime{systemTime} = $1;
	
	$rawUptime =~ /up\s(.*?)user/;
	my $utime = $1;
	$utime =~ s/^\s+//;
	my @utb = split(/, /, $utime);
	pop(@utb);
	
	$uptime{systemUpTime} = join(', ', @utb);
	
	$rawUptime =~ /(\d+) user/;
	$uptime{userCount} = $1;
	
	$rawUptime =~ /load average: (.*?), (.*?), (.*?)$/;
	$uptime{la1} = $1;
	$uptime{la5} = $2;
	$uptime{la15} = $3;
	
	$payload{uptime} = \%uptime;
}

sub processTop {
	print "Processing Top\n" if ($outputData);
	
	my @top = ();
	my $rawTop = `top -n 1 -b`;
	
	my @topLines = split(/\n/, $rawTop);
	
	shift(@topLines);
	
	my $taskSummary = shift(@topLines);
	my $cpuSummary = shift(@topLines);
	my $memSummary = shift(@topLines);
	my $swapSummary = shift(@topLines);
	
	shift(@topLines);
	shift(@topLines);
	pop(@topLines);
	
	foreach my $item (@topLines) {
		# print $item . "\n";
		$item =~ s/\s{1,}/ /g;
		my @tb = split(/\s/, $item);
		
		my $pid = $tb[1];
		my $user = $tb[2];
		my $priority = $tb[3];
		my $nice = $tb[4];
		my $virt = $tb[5];
		my $res = $tb[6];
		my $she = $tb[7];
		my $s = $tb[8];
		my $cpu = $tb[9];
		my $mem = $tb[10];
		my $time = $tb[11];
		my $proc = $tb[12];
		
		if ($cpu > 5 || $mem > 5) {
			push(@top, {
				pid => $pid, 
				user => $user, 
				pri => $priority, 
				nice => $nice, 
				virt => $virt, 
				res => $res, 
				she => $she, 
				s => $s, 
				cpu => $cpu, 
				mem => $mem, 
				time => $time, 
				proc => $proc
			});
		}
	}
	
	$payload{top} = \@top;
}

sub processNetstat {
	print "Processing Netstat\n" if ($outputData);
	
	my @netstat = ();
	my $rawNetstat = `netstat -tulpan`;
	
	my @lines = split(/\n/, $rawNetstat);
	
	shift(@lines);
	shift(@lines);
	
	foreach my $item (@lines) {
		my @bits = split(/\s/, $item);
		
		my $proto = substr($item, 0, 5);
		my $recv = substr($item, 7, 5);
		my $send = substr($item, 14, 5);
		my $localIP = substr($item, 20, 23);
		my $remoteIP = substr($item, 44, 23);
		my $state = substr($item, 68, 11);
		my $proc = substr($item, 80, length($item));
		
		$proto =~ s/\s//g;
		$recv =~ s/\s//g;
		$send =~ s/\s//g;
		$localIP =~ s/\s//g;
		$remoteIP =~ s/\s//g;
		$state =~ s/\s//g;
		$proc =~ s/\s//g;
		
		push(@netstat, {
			proto => $proto, 
			recv => $recv, 
			send => $send, 
			lip => $localIP, 
			rip => $remoteIP, 
			state => $state, 
			proc => $proc
		});
	}
	
	$payload{netstat} = \@netstat;
}

sub processDF {
	print "Processing DF\n" if ($outputData);
	
	my @df = ();
	my $rawDF = `df`;
	
	my @lines = split(/\n/, $rawDF);
	
	shift(@lines);
	
	foreach my $item (@lines) {
		$item =~ s/\s{1,}/ /g;
		
		my @bits = split(/\s/, $item);
		
		my $filesystem = $bits[0];
		my $size = $bits[1];
		my $used = $bits[2];
		my $available = $bits[3];
		my $per = $bits[4];
		my $mount = $bits[5];
		
		push(@df, {
			fs => $filesystem, 
			size => $size, 
			used => $used, 
			av => $available, 
			per => $per, 
			mount => $mount
		});
	}
	
	$payload{df} = \@df;
}

sub processMISC {
	print "Processing MISC\n" if ($outputData);
	
	$payload{host} = `hostname`;
	$payload{date} = `date`;
}

sub processW {
	print "Processing W\n" if ($outputData);
	
	my @users = ();
	my $rawW = `w`;
	
	my @lines = split(/\n/, $rawW);
	
	shift(@lines);
	shift(@lines);
	
	foreach my $item (@lines) {
		$item =~ s/\s{1,}/ /g;
		$item =~ /^(.*?)\s(.*?)\s(.*?)\s(.*?)\s(.*?)\s(.*?)\s(.*?)\s(.*?)$/;
		
		my $user = $1;
		my $tty = $2;
		my $from = $3;
		my $login = $4;
		my $idle = $5;
		my $jcpu = $6;
		my $pcpu = $7;
		my $proc = $8;
		
		push(@users, {
			user => $user, 
			tty => $tty, 
			from => $from, 
			login => $login, 
			idle => $idle, 
			jcpu => $jcpu, 
			pcpu => $pcpu, 
			proc => $proc
		});
	}
	
	$payload{w} = \@users;
}
