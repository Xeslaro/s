#!/usr/bin/perl -w
use strict;
use http;
my ($f, $i) = ("", 0);
while ($i < @ARGV) {
	if ($ARGV[$i] eq "-f") {
		$f = $ARGV[$i+1];
		$i += 2;
		next;
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
				$ans[$i + $_] =~ /href="(.*)" target=/;
				qx|wget -U Xeslaro --no-dns-cache --connect-timeout=10 -t 0 -O $_.flv "$1"|;
			}
			last;
		}
		$i++;
	}
	$cnt--;
	qx|mencoder -ovc copy -oac lavc -lavcopts acodec=ac3 -of lavf -lavfopts format=matroska -o "$name".mkv {0..$cnt}.flv|;
}
