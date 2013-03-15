#!/usr/bin/perl -w
use strict;
use feature "switch";
my ($f, $o, $d, $i);
$i = 0;
while ($i < @ARGV) {
	given ($ARGV[$i]) {
		when (/^-f$/) {
			$f = $ARGV[++$i];
		}
		when (/^-o$/) {
			$o = $ARGV[++$i];
		}
		when (/^-d$/) {
			$d = $ARGV[++$i];
		}
	}
	$i++;
}
for (`ffmpeg -i "$f" 2>&1`) {
	if (/Duration: (\d+):(\d+):(\d+)/) {
		my $td = $1*3600 + $2*60 + $3;
		for (0..$td/$d) {
			my $ss = $_ * $d;
			qx|ffmpeg -ss $ss -i "$f" -f image2 -frames:v 1 $_.jpg|;
		}
		my $cnt = int($td/$d);
		qx|convert {0..$cnt}.jpg -append $o|;
		last;
	}
}
