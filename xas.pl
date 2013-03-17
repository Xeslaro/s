#!/usr/bin/perl -w
use strict;
use http;
use feature "switch";
my @p;
my ($i, $v) = (0, 0);
my (%cookie, $base, $user, $pass, $d);
sub pp {
	if (-f "$user.cookie" && -f "$user.base") {
		$base = `cat $user.base`;
		http::cookie_read(\%cookie, "$user.cookie");
	}
	if (!%cookie || !http::wap_baidu_cookie_check($base, \%cookie)) {
		unless ($pass) {
			print "cookie check for account $user failed, re-enter your password:";
			chomp($pass = <>);
		}
		%cookie = ();
		$base = http::wap_baidu_login($user, $pass, \%cookie);
		`echo -n '$base' > $user.base`;
		http::cookie_dump(\%cookie, "$user.cookie");
	}
	push @p, [$base, {}, $d];	
	%{$p[$#p][1]} = %cookie;
	%cookie = (), $pass="";
}
while ($i < @ARGV) {
	given($ARGV[$i]) {
		when (/^-v$/) {
			$v = 1;
		}
		when (/^-u$/) {
			$user = $ARGV[++$i];
		}
		when (/^-p$/) {
			$pass = $ARGV[++$i];
		}
		when (/^-d$/) {
			$d = $ARGV[++$i];
			pp();
		}
		when (/^-c$/) {
			my @cfg = `cat $ARGV[++$i]`;
			for (@cfg) {
				chomp;
				/^([^ ]+) ([^ ]+) (.*)$/;
				$user=$1, $pass=$2, $d=$3;
				pp();
			}
		}
	}
	$i++;
}
for (@p) {
	my ($base, $cookie, $d) = @{$_};
	for (split / /, $d) {
		my $uri = $base . "m?kw=" . http::uri_escape($_);
		my @ans = http::http_get($uri, "wapp.baidu.com", 80, $cookie);
		http::update_cookie($cookie, @ans);
		for (@ans) {
			if (/.*<a href="(.*)">签到/) {
				$uri = $1;
				while ($uri =~ s/&amp;/&/) {}
				@ans = http::http_get($uri, "wapp.baidu.com", 80, $cookie);
				http::update_cookie($cookie, @ans);
				last;
			}
		}
	}
}
