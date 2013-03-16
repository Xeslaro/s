#!/usr/bin/perl -w
use strict;
sub p_sub_xml {
	my ($file_name, $id, $lang, $tmp_dir) = @_;
	my %font = (
		eng => "Lucida Console",
		chi => "SimSun");
	my $c = '
<subpictures format="NTSC">
<stream>
<textsub filename= characterset="UTF-8"
fontsize="28.0" font= fill-color="yellow"
outline-color="purple" outline-thickness="3.0"
shadow-offset="0, 0" shadow-color="black"
horizontal-alignment="center" vertical-alignment="bottom"
left-margin="60" right-margin="60"
top-margin="20" bottom-margin="30"
/>
</stream>
</subpictures>';
	$c =~ s/filename=/filename="$file_name"/;
	$c =~ s/font=/font="$font{$lang}"/;
	open(my $ouf, ">", "$tmp_dir/sub$id.xml");
	print $ouf $c;
	close $ouf;
}
sub add_sub {
	my ($cur_gs, $sub_cnt, $tmp_dir) = @_;
	my $cmd = "spumux -m dvd -s 0 -P \"$tmp_dir/sub0.xml\" <\"$cur_gs\"";
	$cmd .= "|spumux -m dvd -s $_ -P \"$tmp_dir/sub$_.xml\"" foreach (1..$sub_cnt - 1);
	$cmd .= " >\"$tmp_dir/tmp_for_sub\"";
	qx/$cmd/;
	qx|mv "$tmp_dir/tmp_for_sub" "$cur_gs"|;
}
my ($i, $tmp_dir, $ouf) = (0, "/mnt/d/dvd", "/mnt/d/dvd.iso");
my $lang;
my $sub_cnt=0;
my @file_name = ();
my @orig_file_name = ();
while ($i < @ARGV) {
	$_ = $ARGV[$i++];
	$tmp_dir = $ARGV[$i++], next if (/^-t$/);
	$ouf = $ARGV[$i++], next if (/^-o$/);
	$lang = "eng", next if (/^-e$/);
	if (/^-a/) {
		$lang = "chi";
		add_sub($file_name[$#file_name], $sub_cnt, $tmp_dir), $sub_cnt = 0 if ($sub_cnt);
		my ($mp1, $done) = (0, 0);
		$mp1 = 1 if (/1/);
		$done = 1 if (/d/);
		$_ = $ARGV[$i++];
		push @orig_file_name, $_;
		if ($done) {
			push @file_name, $_;
			next;
		}
		/([^\/]*)\.\w+$/;
		if ($mp1) {
			qx|ffmpeg -i "$_" -target ntsc-dvd -s 352x240 -c:v mpeg1video "$tmp_dir/$1.mp1" 1>&2|;
			push @file_name, "$tmp_dir/$1.mp1";
		} else {
			qx|ffmpeg -i "$_" -target ntsc-dvd "$tmp_dir/$1.mp2" 1>&2|;
			push @file_name, "$tmp_dir/$1.mp2";
		}
		next;
	}
	p_sub_xml($_, $sub_cnt++, $lang, $tmp_dir), next if (/\.(srt|ass)$/);
	if (/\.sub$/) {
		my $sub_name = $_;
		foreach (`ffmpeg -i "$_" 2>&1`) {
			if (/Stream\s+#0:(\d+).*Subtitle:\s+dvd_subtitle/) {
				qx|spuunmux -o "$tmp_dir/sub$sub_cnt" -F NTSC -s $1 "$sub_name"|;
				$sub_cnt++;
			}
		}
	}
	if (/^-m$/) {
		my $cur_file = $orig_file_name[$#orig_file_name];
		foreach (`ffmpeg -i "$cur_file" 2>&1`) {
			if (/Stream\s+#0:(\d+)\((\w+)\):\s+Subtitle/) {
				qx|rm "$tmp_dir/sub$sub_cnt.srt"| if -e "$tmp_dir/sub$sub_cnt.srt";
				qx|mkvextract tracks "$cur_file" $1:"$tmp_dir/sub$sub_cnt.srt"|;
				p_sub_xml("$tmp_dir/sub$sub_cnt.srt", $sub_cnt++, $2, $tmp_dir);
			}
		}
	}
}
add_sub($file_name[$#file_name], $sub_cnt, $tmp_dir), $sub_cnt = 0 if ($sub_cnt);
open(my $xml, ">", "$tmp_dir/mkdvd.xml");
print $xml '<dvdauthor dest="'."$tmp_dir".'/dvd"><vmgm><menus><video format="NTSC"></video></menus></vmgm><titleset><titles><video format="NTSC"></video>';
foreach (0..$#file_name) {
	my $next = $_ + 2;
	$next = 1 if ($_ == $#file_name);
	print $xml '<pgc><vob file="'."$file_name[$_]".'"></vob><post>jump title '."$next".';</post></pgc>';
}
print $xml '</titles></titleset></dvdauthor>';
close $xml;
qx|dvdauthor -x "$tmp_dir/mkdvd.xml" 1>&2|;
qx|rm "$_"| foreach (@file_name);
qx|mkisofs -dvd-video -o $ouf "$tmp_dir/dvd"|;
qx|rm -r "$tmp_dir/dvd"|;
