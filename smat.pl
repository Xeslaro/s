#!/bin/perl
#Steamcommunity Market Auto Trader
use strict;
use warnings;
my ($i, $buying_acc, $search_acc, $debug, $iprice_file, $sessionid, $wallet_ballance, $log, $rest_time);
open($log, ">", "smat.log") or die "open log file failed.";
$debug = 0;
$rest_time = 5;
$i = 0;
while ($i < @ARGV) {
	$_ = $ARGV[$i++];
	/^-d$/ && do { $debug = 1; next; };
	/^-b$/ && do { $buying_acc = $ARGV[$i++]; next; };
	/^-b(.*)$/ && do { $buying_acc = $1; next; };
	/^-s$/ && do { $search_acc = $ARGV[$i++]; next; };
	/^-s(.*)$/ && do { $search_acc = $1; next; };
	/^-p$/ && do { $iprice_file = $ARGV[$i++]; next; };
	/^-p(.*)$/ && do { $iprice_file = $1; next; };
	/^-w$/ && do { $wallet_ballance = $ARGV[$i++]; next; };
	/^-w(.*)$/ && do { $wallet_ballance = $1; next; };
	/^-r$/ && do { $rest_time = $ARGV[$i++]; next; };
	/^-r(.*)$/ && do { $rest_time = $1; next; };
}
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
	/(.*)=(.*)/;
	print $log "setting price for $1 to $2\n" if ($debug);
	$item_iprice{$1} = $2;
}
my @cpid;
for (keys %item_iprice) {
	if (my $pid = fork()) {
		push @cpid, $pid;
		next;
	}
	my ($referer, $iprice) = ($_, $item_iprice{$_});
	while (1) {
		my ($listing_id, $total, $subtotal);
		my $json = qx(wget -U chrome --header="Referer: $referer" --header="Cookie: $search_acc_cookie" -O - "$referer/render/?query=&start=0&count=5" 2>/dev/null);
		$json =~ /results_html":"(.*?)[^\\]"/;
		my @html = split /\\n/, $1;
		print $log "going to scanning price for $referer\n" if ($debug);
		$i = 0;
		while ($i < @html) {
			$_ = $html[$i++];
			/BuyMarketListing\('listing', '(.*?)'/ && do { $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; };
			/market_listing_price_with_fee/ && do {
				next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
				print $log "current item price $total\n" if ($debug);
				last if ($total > $iprice || $total > $wallet_ballance);
			};
			/market_listing_price_without_fee/ && do {
				next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
				my $fee = $total - $subtotal;
				print "$referer\ngoing to buy this item for $total, fee $fee, subtotal $subtotal\n";
				my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
				print "post data is $post_data\n";
				my $post_result = qx(wget -U chrome --header="Referer: $referer" --header="Cookie: $buying_acc_cookie" --post-data="$post_data" -O - "http://steamcommunity.com/market/buylisting/$listing_id" 2>/dev/null);
				unless ($?) {
					$wallet_ballance -= $total;
					print "$post_result\nwallet_ballance:$wallet_ballance\n";
				}
			};
		}
		sleep $rest_time;
	}
}
<STDIN>;
kill 15, @cpid;
0 while (wait() != -1);
