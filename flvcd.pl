#!/bin/perl
use strict;
use warnings;
use http;
my ($f, $i, $d, $c, $w) = ("", 0, 0, 0, 0);
while_opt: while ($i < @ARGV) {
	for ($ARGV[$i]) {
		/^-f(.*)$/ && do {
			$f = $1 ? $1 : $ARGV[++$i];
			$i++, next while_opt;
		};
		/^-c$/ && do {
			$c = 1, $i++, next while_opt;
		};
		/^-w$/ && do {
			$w = 1, $i++, next while_opt;
		};
		/^-d$/ && do {
			$d = 1, $i++, next while_opt;
		}
	}
	$_ = http::uri_escape($ARGV[$i++]);
	$_ .= "&format=$f";
	$_ = "www.flvcd.com/parse.php?kw=" . $_;
	my @ans = `wget "$_" -O - | iconv -f gbk -t utf8`;
	my $i = 0;
	my ($name, $cnt);
	while ($i <= $#ans) {
		$name = $1 if ($ans[$i] =~ /^\s+(.*?)\s+<strong>/);
		if ($ans[$i] =~ /自动切割的<font color=red>(\d+)/) {
			$cnt = $1;
			for (0..$cnt-1) {
				next if $c && -e "$_.flv";
				$ans[$i + $_] =~ /href="(.*)" target=/;
				if ($w) {
					qx(mplayer "$1" >&2);
					next;
				}
				qx|wget -U Xeslaro --no-dns-cache --connect-timeout=10 -t 0 -O $_.flv "$1"|;
				while ($?) {
					sleep 300;
					qx|wget -U Xeslaro --no-dns-cache --connect-timeout=10 -t 0 -O $_.flv "$1"|;
				}
			}
			last;
		} elsif ($ans[$i] =~ /\s+<a href="(.*?)".*复制地址/) {
			$cnt = 1;
			qx(mplayer "$1" >&2) if $w;
			qx|wget -U Xeslaro --no-dns-cache --connect-timeout=10 -t 0 -O 0.flv "$1"| unless $w;
			last;
		}
		$i++;
	}
	$c=0, $cnt--;
	unless ($w) {
		qx|mencoder -ovc copy -oac lavc -lavcopts acodec=ac3 -of lavf -lavfopts format=matroska -o "$name".mkv {0..$cnt}.flv|;
		qx|rm {0..$cnt}.flv| if ($d);
	}
}
