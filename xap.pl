#!/usr/bin/perl -w
use strict;
use http;
use feature "switch";
my (%cookie, %child);
my ($i, $cff) = (0, 0);
my ($base, $user, $pass);
while ($i < @ARGV) {
	if ($ARGV[$i] =~ /^-c$/) {
		$cff = 1;
		http::cookie_read(\%cookie, $ARGV[++$i]);
	} elsif ($ARGV[$i] =~ /^-b$/) {
		$base = `cat $ARGV[++$i]`;
	} elsif ($ARGV[$i] eq "-u") {
		$user = $ARGV[++$i];
	} elsif ($ARGV[$i] eq "-p") {
		$pass = $ARGV[++$i];
	}
	$i++;
}
if ($cff && !wap_baidu_cookie_check($base, \%cookie)) {
	print "cookie check failed, re-enter user & password, separate by space:\n";
	chomp($_ = <>);
	/([^ ]+) ([^ ]+)/;
	$user=$1, $pass=$2, $cff=0;
}
$base = http::wap_baidu_login($user, $pass, \%cookie) unless ($cff);
while (print("<xap>"), $_=<STDIN>) {
	chomp;
	given($_) {
		when (/^a (\d+) (\d+)$/) {
			my $uri = $base."flr?pid=$1&kz=$2";
			my $pid = fork();
			unless ($pid) {
				while (1) {
					http::wap_baidu_submit($uri, \%cookie, "up");
					sleep 600 + int(rand(3000)) + 1;
				}
			}
			$child{$pid} = $1." ".$2;
		}
		when (/^d (\d+)$/) {
			kill 15, $1;
			wait;
			delete $child{$1};
		}
		when (/^p$/) {
			print "$_ $child{$_}\n" for (keys %child);
		}
		when (/^s$/) {
			kill 19, $_ for (keys %child);
		}
		when (/^c$/) {
			kill 18, $_ for (keys %child);
		}
	}
}
for (keys %child) {
	kill 15, $_;
	wait;
}
unless ($cff) {
	http::cookie_dump(\%cookie, "$user.cookie");
	`echo -n '$base' > $user.base`;
}
