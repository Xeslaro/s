#!/usr/bin/perl -w
use strict;
for (@ARGV) {
	while (s|:|%3A|) {};
	while (s|/|%2F|) {};
	$_ .= "&flag=one&format=super";
	$_ = "www.flvcd.com/parse.php?kw=" . $_;
	my @ans = `wget "$_" -O - | iconv -f gbk -t utf8`;
	my $i = 0;
	my ($name, $cnt);
	while ($i <= $#ans) {
		$name = $1 if ($ans[$i] =~ /^\s+(.*)\s+<strong>（请用右键"目标另存为"或硕鼠来快速下载.）<\/strong>/);
		if ($ans[$i] =~ /由优酷网自动切割的<font color=red>(\d+)/) {
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
