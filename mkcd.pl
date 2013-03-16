#!/usr/bin/perl -w
use strict;
my ($i, $t, $a, $p, $g, $f) = (0, "Xeslaro", "Xeslaro", '^(.*)$', 2, 1);
my ($tmp_dir, $country) = ("./mkcd_tmp", "EN");
my @files;
my @titles;
open(my $ouf, ">", "mkcd.cfg");
while ($i < @ARGV) {
	$_ = $ARGV[$i++];
	$t = $ARGV[$i++], next if (/^-t$/);
	$a = $ARGV[$i++], next if (/^-a$/);
	$p = $ARGV[$i++], next if (/^-p$/);
	$g = $ARGV[$i++], next if (/^-g$/);
	$f = 1 - $f, next if (/^-f$/);
	$country = $ARGV[$i++], next if (/^-c$/);
	/([^\/]*)\.\w{2,4}$/;
	qx|mkdir $tmp_dir| unless -d $tmp_dir;
	qx|ffmpeg -i "$_" "$tmp_dir/$1.wav"|;
	push @files, "$tmp_dir/$1.wav";
	$1 =~ $p;
	push @titles, $1;
}
print $ouf "CD_DA\n";
print $ouf "CD_TEXT {\n";
print $ouf "LANGUAGE_MAP {\n";
print $ouf "0 : $country\n";
print $ouf "}\n";
print $ouf "LANGUAGE 0 {\n";
print $ouf "TITLE \"$t\"\n";
print $ouf "PERFORMER \"$a\"\n";
print $ouf "}\n";
print $ouf "}\n";
$i = 0;
foreach (@files) {
	print $ouf "TRACK AUDIO\n";
	print $ouf "CD_TEXT {\n";
	print $ouf "LANGUAGE 0 {\n";
	print $ouf "TITLE \"$titles[$i]\"\n";
	print $ouf "}\n";
	print $ouf "}\n";
	print $ouf "PREGAP 00:$g:00\n";
	print $ouf "FILE \"$_\" 0\n";
	$i++;
}
qx|cdrdao write --device /dev/sr1 -n mkcd.cfg && rm -r mkcd.cfg mkcd_tmp| if ($f);
