#!/bin/perl
#Steamcommunity Market Auto Trader
use strict;
use warnings;
my ($i, $buying_acc, $search_acc, $debug, $iprice_file, $sessionid, $wallet_balance, $log, $rest_time);
$debug = 0;
$rest_time = 5;
$i = 0;
while ($i < @ARGV) {
	$_ = $ARGV[$i++];
	/^-d$/ && do { $debug = $ARGV[$i++]; next };
	/^-d(.*)$/ && do { $debug = $1; next };
	/^-b$/ && do { $buying_acc = $ARGV[$i++]; next };
	/^-b(.*)$/ && do { $buying_acc = $1; next };
	/^-s$/ && do { $search_acc = $ARGV[$i++]; next };
	/^-s(.*)$/ && do { $search_acc = $1; next };
	/^-p$/ && do { $iprice_file = $ARGV[$i++]; next };
	/^-p(.*)$/ && do { $iprice_file = $1; next };
	/^-w$/ && do { $wallet_balance = $ARGV[$i++]; next };
	/^-w(.*)$/ && do { $wallet_balance = $1; next };
	/^-r$/ && do { $rest_time = $ARGV[$i++]; next };
	/^-r(.*)$/ && do { $rest_time = $1; next };
}
qx(echo $wallet_balance >w);
open($log, ">", "smat.log") or die "open log file failed." if ($debug);
my ($buying_acc_cookie, $search_acc_cookie);
my @cookie_from_file = qx(cat $buying_acc.cookie);
for (@cookie_from_file) {
	chomp;
	/(.*)=(.*)/;
	$sessionid = $2 if ($1 eq "sessionid");
}
$buying_acc_cookie = join ";", @cookie_from_file;
print $log "buying_acc_cookie=$buying_acc_cookie\n" if ($debug);
@cookie_from_file = qx(cat $search_acc.cookie);
chomp for (@cookie_from_file);
$search_acc_cookie = join ";", @cookie_from_file;
print $log "search_acc_cookie=$search_acc_cookie\n" if ($debug);
my %item_iprice;
for (qx(cat $iprice_file)) {
	chomp;
	/(.*?)=(.*)/;
	next if ($1 =~ /^#/);
	print $log "setting price for $1 to $2\n" if ($debug);
	$item_iprice{$1} = $2;
}
sub referer_to_name {
	(my $referer) = @_;
	(my $ans) = ($referer =~ m|.*/(.*)|);
	$ans =~ s/%([A-F0-9]{2})/chr hex $1/ge;
	return $ans;
}
sub find_item_name {
	my ($k, $html) = @_;
	while ($k < @$html) {
		$_ = $html->[$k];
		return $1 if (/market_listing_item_name[^_].*>(.*)</);
		$k++;
	}
	return "";
}
sub proc_unusual_courier {
	my @usual_color = ("61, 104, 196", "130, 50, 207", "74, 183, 141", "255, 255, 255",
			   "183, 207, 51", "208, 119, 51", "130, 50, 237", "81, 179, 80", "0, 151, 206", "207, 171, 49", "208, 61, 51");
	my %effect_abbreviation_to_full = ("ef" => "Ethereal Flame", "dt" => "Directide Corruption", "sf" => "Sunfire",
					   "ff" => "Frostivus Frost", "lotus" => "Trail of the Lotus Blossom",
					   "re" => "Resonant Energy");
	my ($referer, $option, $name) = @_;
	my %iprice;
	my $max_price;
	$rest_time = 15;
	for (split /,/, $option) {
		/(.*)=(.*)/;
		($1 eq "func") && next;
		($1 eq "rest_time") && ($rest_time = $2, next);
		$iprice{$1} = $2;
	}
	$max_price = 0;
	$max_price = ($_ > $max_price) ? $_ : $max_price for (values %iprice);
	while (1) {
		my @html = qx(wget -U chrome --header="Cookie: $search_acc_cookie" -O - "$referer" 2>/dev/null);
		print $log "going to scanning for $referer\n" if ($debug);
		my $cnt;
		/searchResults_total">(.*?)</ && do {$cnt = $1; last} for (@html);
		next unless (defined $cnt);
		$cnt =~ s/,//g;
		print $log "total item count is $cnt\n" if $debug;
		loop: for (0..$cnt/10) {
			use integer;
			my $start = $_ * 10;
			my $count = ($_ == $cnt/10) ? $cnt%10 : 10;
			no integer;
			print $log "going to search for start=$start count=$count\n" if ($debug);
			last unless ($count);
			my $json = qx(wget -U chrome --header="Referer: $referer" --header="Cookie: $search_acc_cookie" -O - "$referer/render/?query=&start=$start&count=$count" 2>/dev/null);
			$debug && print($log "warning, json response failed, retrying\n"), redo unless $json =~ /^{"success":true/;
			$json =~ /results_html":"(.*?)[^\\]"/;
			$debug && print($log "json response not valid, retrying\n"), redo unless defined $1;
			@html = split /\\n/, $1;
			(my $item_name) = ($json =~ /market_name":"(.*?)"/);
			$debug && print($log "referer name: $name\nitem: $item_name\ndon't match\n"), redo unless (defined $item_name && $name eq $item_name);
			my @descriptions = $json =~ /descriptions":\[(.*?)\]/g;
			my ($total, $subtotal, $description_cnt, $listing_id);
			$description_cnt = -1;
			$i = 0;
			while ($i < @html) {
				$_ = $html[$i++];
				/BuyMarketListing\('listing', '(.*?)'/ && do { $description_cnt++, $listing_id = $1; print $log "currenct listing id $listing_id\n" if ($debug); next; };
				/market_listing_price_with_fee/ && do {
					next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
					last loop if ($total > $max_price || $total > $wallet_balance);
				};
				/market_listing_price_without_fee/ && do {
					next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
					my $fee = $total - $subtotal;
					my $type = "";
					next loop unless defined $descriptions[$description_cnt];
					while ($descriptions[$description_cnt] =~ /value":"(.*?)"/g) {
						print $log "current description value is $1\n" if ($debug > 1);
						$_ = $1;
						/Effect: (.*)/ && do {
							print $log "effect is $1\n" if ($debug > 1);
							for (keys %effect_abbreviation_to_full) {
								$type = $_ if ($1 eq $effect_abbreviation_to_full{$_});
							}
						};
						/Color: .*?(\d+, \d+, \d+)/ && do {
							print $log "color is $1\n" if ($debug > 1);
							next unless (defined $iprice{"legacy"});
							my $legacy_flag = 1;
							($1 eq $_) && ($legacy_flag = 0, last) for (@usual_color);
							$type = "legacy" if ($legacy_flag);
						};
					}
					print $log "this item is of type $type & price $total\n" if ($debug && $type);
					if ($type && defined $iprice{$type}) {
						next if ($total > $iprice{$type});
						my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
						my $post_result = qx(wget -U chrome --header="Referer: $referer" --header="Cookie: $buying_acc_cookie" --post-data="$post_data" -O - "http://steamcommunity.com/market/buylisting/$listing_id" 2>/dev/null);
						unless ($?) {
							print "type: $type referer: $referer\n";
							print "condition met, going to buy this item for $total\n";
							print "post_data is $post_data\n";
							($wallet_balance) = $post_result =~ /wallet_balance":(\d+)/;
							qx(echo $wallet_balance >w);
							print "$post_result\nwallet_balance:$wallet_balance\n";
						}
					}
				}
			}
		}
		chomp($wallet_balance = qx(cat w));
		sleep $rest_time;
	}
}
my @cpid;
for (keys %item_iprice) {
	if (my $pid = fork()) {
		push @cpid, $pid;
		next;
	}
	my ($referer, $iprice, $name) = ($_, $item_iprice{$_}, referer_to_name($_));
	print $log "referer name is $name\n" if ($debug);
	proc_unusual_courier($referer, $iprice, $name) if ($iprice =~ /func=proc_unusual_courier/);
	while (1) {
		my ($listing_id, $total, $subtotal);
		my $json = qx(wget -U chrome --header="Referer: $referer" --header="Cookie: $search_acc_cookie" -O - "$referer/render/?query=&start=0&count=5" 2>/dev/null);
		$debug && print($log "warning, json response failed, retrying\n"), redo unless $json =~ /^{"success":true/;
		$json =~ /results_html":"(.*?)[^\\]"/;
		$debug && print($log "json response not valid, retrying\n"), redo unless defined $1;
		my @html = split /\\n/, $1;
		(my $item_name) = ($json =~ /market_name":"(.*?)"/);
		$debug && print($log "referer name: $name\nitem: $item_name\ndon't match\n"), redo unless (defined $item_name && $name eq $item_name);
		print $log "going to scanning price for $referer\n" if ($debug);
		$i = 0;
		while ($i < @html) {
			$_ = $html[$i++];
			/BuyMarketListing\('listing', '(.*?)'/ && do { $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; };
			/market_listing_price_with_fee/ && do {
				next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
				print $log "current item price $total\n" if ($debug);
				last if ($total > $iprice || $total > $wallet_balance);
			};
			/market_listing_price_without_fee/ && do {
				next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
				my $fee = $total - $subtotal;
				my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
				my $post_result = qx(wget -U chrome --header="Referer: $referer" --header="Cookie: $buying_acc_cookie" --post-data="$post_data" -O - "http://steamcommunity.com/market/buylisting/$listing_id" 2>/dev/null);
				unless ($?) {
					print "$referer\ngoing to buy this item for $total, fee $fee, subtotal $subtotal\n";
					print "post data is $post_data\n";
					($wallet_balance) = $post_result =~ /wallet_balance":(\d+)/;
					qx(echo $wallet_balance >w);
					print "$post_result\nwallet_balance:$wallet_balance\n";
				}
			}
		}
		chomp($wallet_balance = qx(cat w));
		sleep $rest_time;
	}
}
<STDIN>;
kill 15, @cpid;
0 while (wait() != -1);
