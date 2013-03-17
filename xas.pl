#!/usr/bin/perl -w
use strict;
use http;
use feature "switch";
my @p;
my ($i, $v) = (0, 0);
my (%cookie, $base, $user, $pass);
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
			$base = http::wap_baidu_login($user, $pass, \%cookie);
			`echo -n '$base' > $user.base`;
			http::cookie_dump(\%cookie, "$user.cookie");
		}
		when (/^-d$/) {
			if (!%cookie && -f "$user.cookie" && -f "$user.base") {
				$base = `cat $user.base`;
				http::cookie_read(\%cookie, "$user.cookie");
			}
			unless (http::wap_baidu_cookie_check($base, \%cookie)) {
				print "cookie check for account $user failed, re-enter your password:";
				chomp($pass = <>);
				%cookie = ();
				$base = http::wap_baidu_login($user, $pass, \%cookie);
				`echo -n '$base' > $user.base`;
				http::cookie_dump(\%cookie, "$user.cookie");
			}
			my $d = $ARGV[++$i];
			push @p, [$base, {}, $d];
			%{$p[$#p][1]} = %cookie;
			%cookie = ();
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
