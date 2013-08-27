#!/bin/perl
=name
Steamcommunity Market Auto Trader
=cut
use strict;
use warnings;
my ($remote_ip_addr, $remote_host) = ("63.228.223.103", "steamcommunity.com");
my ($i, $buying_acc, $search_acc, $debug, $iprice_file, $sessionid, $wallet_balance, $log, $rest_time);
my ($socket_http_get, $fork_process, $fh, $buying_acc_cookie, $search_acc_cookie);
my @cookie_from_file;
my %cnt_of_item;
$debug = 0, $fork_process = 1;
$i = 0;
while ($i < @ARGV) {
	$_ = $ARGV[$i++];
	/^-d$/ and $debug = $ARGV[$i++], next;
	/^-d(.*)$/ and $debug = $1, next;
	/^-b$/ and $buying_acc = $ARGV[$i++], next;
	/^-b(.*)$/ and $buying_acc = $1, next;
	/^-s$/ and $search_acc = $ARGV[$i++], next;
	/^-s(.*)$/ and $search_acc = $1, next;
	/^-p$/ and $iprice_file = $ARGV[$i++], next;
	/^-p(.*)$/ and $iprice_file = $1, next;
	/^-w$/ and $wallet_balance = $ARGV[$i++], next;
	/^-w(.*)$/ and $wallet_balance = $1, next;
	/^-r$/ and $rest_time = $ARGV[$i++], next;
	/^-r(.*)$/ and $rest_time = $1, next;
	/^-f$/ and $fork_process = $ARGV[$i++], next;
	/^-f(.*)$/ and $fork_process = $1, next;
}
open($log, ">", "smat.log") or die "open log file failed." if ($debug);
{
	open($fh, ">", "w") or die $!;
	print $fh "$wallet_balance\n";
	close($fh) or die $!;
}
{
	open($fh, "<", "$buying_acc.cookie") or die $!;
	@cookie_from_file = <$fh>; close($fh) or die $!;
	for (@cookie_from_file) {
		chomp;
		/(.*)=(.*)/;
		$sessionid = $2 if ($1 eq "sessionid");
	}
	$buying_acc_cookie = join ";", @cookie_from_file;
	print $log "buying_acc_cookie=$buying_acc_cookie\n" if ($debug);
}
{
	open($fh, "<", "$search_acc.cookie") or die $!;
	@cookie_from_file = <$fh>; close($fh) or die $!;
	chomp for (@cookie_from_file);
	$search_acc_cookie = join ";", @cookie_from_file;
	print $log "search_acc_cookie=$search_acc_cookie\n" if $debug;
}
$SIG{PIPE} = sub {};
my %item_iprice;
my $group = 0;
my @child_pids;
{
	open($fh, "<", "$iprice_file") or die $!;
	my @iprice_content = <$fh>; close($fh) or die $!;
	my $cnt_of_iitem = 0;
	for (@iprice_content) {
		chomp;
		next if /^#/ or /^$/;
		if (/^func=proc_tournament_item/) {
			my $pid = fork();
			die $! unless defined $pid;
			$group++, push(@child_pids, $pid), next if ($pid);
			$item_iprice{"tournament"} = $_;
			main_loop();
		}
		$cnt_of_iitem++;
	}
	print $log "cnt_of_iitem is $cnt_of_iitem.\n" if $debug;
	use integer;
	my ($item_per_process, $remainder) = ($cnt_of_iitem / $fork_process, $cnt_of_iitem % $fork_process);
	no integer;
	my $cnt_current_item = 0;
	for (@iprice_content) {
		chomp;
		next if /^#/ or /^func=proc_tournament_item/ or /^$/;
		/(.*?)=(.*)/;
		$cnt_current_item++;
		print $log "setting price for $1 to $2, cnt_current_item is $cnt_current_item\n" if $debug;
		$item_iprice{$1} = $2;
		if ($cnt_current_item == $item_per_process + ($remainder != 0)) {
			$remainder-- if ($remainder);
			my $pid = fork();
			die $! unless defined $pid;
			if ($pid) {
				push @child_pids, $pid;
				$cnt_current_item = 0, %item_iprice = (), $group++;
			} else {
				main_loop();
			}
		}
	}
}
$SIG{CHLD} = sub {
	wait();
};
while (<STDIN>) {
	chomp;
	kill("SIGTERM", @child_pids), last if /^q$/;
	kill("SIGSTOP", @child_pids), next if /^s$/;
	kill("SIGCONT", @child_pids), next if /^c$/;
}
sub referer_to_name {
	(my $referer) = @_;
	(my $ans) = ($referer =~ m|.*/(.*)|);
	$ans =~ s/%([A-F0-9]{2})/chr hex $1/ge;
	return $ans;
}
sub proc_unusual_hat {
	my ($referer, $option, $name) = @_;
	my %effect_to_scaler = ("Harvest Moon" => 5, "Cloudy Moon" => 5, "It's A Secret To Everybody" => 5, "Burning Flames" => 5,
				"Roboactive" => 4, "Kill-a-Watt" => 4, "Misty Skull" => 4, "Anti-Freeze" => 4, "Scorching Flames" => 4,
				"Phosphorous" => 4, "Stormy 13th Hour" => 4, "Miami Nights" => 4, "Disco Beat Down" => 4, "Time Warp" => 4, "Overclocked" => 4,
				"Sunbeams" => 3, "Powersurge" => 3, "Flaming Lantern" => 3, "Knifestorm" => 3, "Circling Heart" => 3, "Stormy 13th Hour" => 3, "Sulphurous" => 3, "Electrostatic" => 3,
				"Green Energy" => 3, "Purple Energy" => 3, "Haunted Ghosts" => 3, "Aces High" => 3, "Blizzardy Storm" => 3, "Green Black Hole" => 3, "Cloud 9" => 3,
				"Cauldron Bubbles" => 2, "Eerie Orbiting Fire" => 2, "Vivid Plasma" => 2, "Stormy Storm" => 2,
				"Green Confetti" => 1, "Circling Peace Sign" => 1, "Searing Plasma" => 1, "Circling TF Logo" => 1,
				"Smoking" => 1, "Purple Confetti" => 1, "Orbiting Fire" => 1, "Orbiting Planets" => 1, "Steaming" => 1,
				"Bubbling" => 1, "Massed Files" => 1, "Nuts n' Bolts" => 1);
	my $base_price;
	for (split /,/, $option) {
		next if /func=proc_unusual_hat/;
		/^(\d+)$/ and $base_price = $1, next;
		/(.*)=(.*)/ and ($debug and print $log "setting scaler of $1 to $2.\n"), $effect_to_scaler{$1} = $2, next;
		print "invalid option $_.\n";
	}
	my $max_price = 0;
	$max_price = $max_price > $_ ? $max_price : $_ for (values %effect_to_scaler);
	$max_price *= $base_price;
	$debug and print $log "max_price for this is $max_price.\n";
	$referer =~ m|http://steamcommunity.com(.*)| or die "not able to obtain uri.\n";
	my $uri = $1;
	{
		my ($status, $html) = http_get($socket_http_get, "$uri/render/?query=&start=0&count=1", "Referer: $referer\r\n" . "Cookie: $search_acc_cookie\r\n");
		$debug and print $log "status for getting $uri/render/?query=&start=0&count=1 is $status.\n";
		my $cnt_of_this;
		$status eq "ok" and $html = gunzip($html) and $html =~ /^{"success":true/ and $html =~ /"total_count":(\d+)/ and $cnt_of_this = $1 or redo;
		$debug and print $log "total_count for this is $cnt_of_this.\n";
		my $start = 0;
		loop: while ($start < $cnt_of_this) {
			my $count = 50;
			$count = $cnt_of_this - $start if $cnt_of_this - $start < 50;
			my ($status, $json) = http_get($socket_http_get, "$uri/render/?query=&start=$start&count=$count", "Referer: $referer\r\n" . "Cookie: $search_acc_cookie\r\n");
			$debug and print $log "status for getting $uri/render/?query=&start=$start&count=$count is $status.\n";
			$status eq "ok" and $json = gunzip($json) and $json =~ /^{"success":true/ and $json =~ /"results_html":"(.*?)[^\\]"/ and my @html = split /\\n/, $1 and (my $item_name) = ($json =~ /market_name":"(.*?)"/) or redo;
			redo unless $name eq $item_name;
			my @descriptions = $json =~ /descriptions":\[(.*?)\]/g;
			my ($total, $subtotal, $description_cnt, $listing_id, $i);
			$description_cnt = -1, $i = 0;
			while ($i < @html) {
				$_ = $html[$i++];
				if (/BuyMarketListing\('listing', '(.*?)'/) { $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; }
				if (/market_listing_price_with_fee/) {
					next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
					last loop if ($total > $max_price || $total > $wallet_balance);
				}
				if (/market_listing_price_without_fee/) {
					$description_cnt++;
					next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
					my $fee = $total - $subtotal;
					last unless defined $descriptions[$description_cnt];
					my $scaler = 1;
					my $effect;
					while ($descriptions[$description_cnt] =~ /value":"(.*?)"/g) {
						$_ = $1;
						/Effect: (.*)/ and $effect = $1 and defined $effect_to_scaler{$1} and $effect_to_scaler{$1} > $scaler and $scaler = $effect_to_scaler{$1};
					}
					my $max_considered_price = $base_price * $scaler;
					$debug and print $log "effect is $effect, scaler is $scaler, max_considered_price is $max_considered_price.\n";
					next if $total > $max_considered_price;
					my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
					my ($status, $post_result) = http_post("/market/buylisting/$listing_id", "Referer: $referer\r\n" . "Cookie: $buying_acc_cookie\r\n", $post_data);
					print "condition met, going to buy $referer with effect $effect for $total.\n";
					print "post_data is $post_data.\n";
					if ($status eq "ok") {
						($wallet_balance) = $post_result =~ /wallet_balance":(\d+)/;
						print "$post_result\nwallet_balance:$wallet_balance\n";
						open($fh, ">", "w") or die $!;
						print $fh "$wallet_balance\n";
						close($fh) or die $!;
					} else {
						print "status is $status.\n";
					}
				}
			}
			$start += $count;
		}
	}
}
sub proc_unusual_courier {
	my %usual_color = ("61, 104, 196" => "indigo", "130, 50, 207" => "violet", "74, 183, 141" => "teal", "255, 255, 255" => "trivial",
			   "183, 207, 51" => "light_green", "208, 119, 51" => "orange", "130, 50, 237" => "purple", "81, 179, 80" => "green", "0, 151, 206" => "blue", "207, 171, 49" => "gold", "208, 61, 51" => "red");
	my %effect_abbreviation_to_full = ("ef" => "Ethereal Flame", "dt" => "Directide Corruption", "sf" => "Sunfire",
					   "ff" => "Frostivus Frost", "lotus" => "Trail of the Lotus Blossom",
					   "re" => "Resonant Energy", "lava" => "");
	my ($referer, $option, $name) = @_;
	my %iprice;
	my $max_price;
	for (split /,/, $option) {
		/(.*?)=(.*)/;
		next if $1 eq "func";
		$rest_time = $2, next if $1 eq "rest_time";
		my $effect = $1;
		$iprice{$effect} = {};
		/(.*)=(.*)/ and $iprice{$effect}{$1} = $2 or $iprice{$effect}{general} = $_ for (split /:/, $2);
	}
	$max_price = 0;
	for (values %iprice) {
		$max_price = ($_ > $max_price) ? $_ : $max_price for (values %$_);
	}
	$referer =~ m|http://.*?(/.*)|;
	my $uri_prefix = $1;
	print $log "uri prefix is $uri_prefix.\n" if $debug;
	{
		print $log "going to scanning for $referer\n" if ($debug);
		my ($status, $html) = http_get(\$socket_http_get, $uri_prefix, "Cookie: $search_acc_cookie\r\n");
		print $log "status is $status.\n" if $debug;
		redo unless $status eq "ok";
		$html = gunzip($html);
		my $cnt;
		$cnt = $1 if $html =~ /searchResults_total">(.*?)</;
		next unless (defined $cnt);
		$cnt =~ s/,//g;
		print $log "total item count is $cnt\n" if $debug;
		loop: for (0..$cnt/50) {
			use integer;
			next unless defined $_;
			my $start = $_ * 50;
			my $count = ($_ == $cnt/50) ? $cnt%50 : 50;
			no integer;
			last unless ($count);
			print $log "going to search for start=$start count=$count\n" if ($debug);
			my ($status, $json) = http_get(\$socket_http_get, $uri_prefix . "/render/?query=&start=$start&count=$count", "Referer: $referer\r\n" . "Cookie: $search_acc_cookie\r\n");
			print $log "status is $status.\n" if $debug;
			redo unless $status eq "ok";
			$json = gunzip($json);
			($debug and print $log "warning, json response failed, retrying\n"), redo unless $json =~ /^{"success":true/;
			$json =~ /total_count":(\d+)/;
			($debug and print $log "no listing for $referer now\n"), next unless defined $1 && $1 > 0;
			$json =~ /results_html":"(.*?)[^\\]"/;
			($debug and print $log "json response not valid, retrying\n"), redo unless defined $1;
			my @html = split /\\n/, $1;
			(my $item_name) = ($json =~ /market_name":"(.*?)"/);
			unless (defined $item_name and $name eq $item_name) {
				print($log "referer name: $name\nitem: $item_name\ndon't match\n") if (defined $item_name and $debug);
				redo;
			}
			my @descriptions = $json =~ /descriptions":\[(.*?)\]/g;
			my ($total, $subtotal, $description_cnt, $listing_id);
			$description_cnt = -1;
			$i = 0;
			while ($i < @html) {
				$_ = $html[$i++];
				if (/BuyMarketListing\('listing', '(.*?)'/) { $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; }
				if (/market_listing_price_with_fee/) {
					next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
					last loop if ($total > $max_price || $total > $wallet_balance);
				}
				if (/market_listing_price_without_fee/) {
					$description_cnt++;
					next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
					my $fee = $total - $subtotal;
					my ($effect, $color);
					next loop unless defined $descriptions[$description_cnt];
					while ($descriptions[$description_cnt] =~ /value":"(.*?)"/g) {
						print $log "current description value is $1\n" if ($debug > 1);
						$_ = $1;
						if (/Effect: (.*)/) {
							print $log "effect is $1\n" if ($debug > 1);
							for (keys %effect_abbreviation_to_full) {
								$effect = $_ if ($1 eq $effect_abbreviation_to_full{$_});
							}
						}
						if (/Color: .*?(\d+, \d+, \d+)/) {
							$color = defined $usual_color{$1} ? $usual_color{$1} : "legacy";
							print $log "color is $color\n" if ($debug > 1);
						}
					}
					print $log "this item is of name $name & effect $effect & color $color & price $total\n" if ($debug && $effect);
					my $legacy = $color eq "legacy" && defined $iprice{legacy}{general};
					my $specific_effect = defined $effect && defined $iprice{$effect}{general};
					my $specific_effect_color = defined $effect && defined $iprice{$effect}{$color};
					if ($legacy || $specific_effect || $specific_effect_color) {
						my $highest_considered_price = 0;
						$highest_considered_price = $iprice{legacy}{general} if ($legacy && $iprice{legacy}{general} > $highest_considered_price);
						$highest_considered_price = $iprice{$effect}{general} if ($specific_effect && $iprice{$effect}{general} > $highest_considered_price);
						$highest_considered_price = $iprice{$effect}{$color} if ($specific_effect_color && $iprice{$effect}{$color} > $highest_considered_price);
						print $log "highest_considered_price is $highest_considered_price\n" if ($debug);
						next if ($total > $highest_considered_price);
						my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
						my ($status, $post_result) = http_post("/market/buylisting/$listing_id", "Referer: $referer\r\n" . "Cookie: $buying_acc_cookie\r\n", $post_data);
						print "effect: ", defined $effect ? $effect : "legacy", " color: $color referer: $referer\n";
						print "condition met, going to buy this item for $total\n";
						print "post_data is $post_data\n";
						if ($status eq "ok") {
							($wallet_balance) = $post_result =~ /wallet_balance":(\d+)/;
							print "$post_result\nwallet_balance:$wallet_balance\n";
							open($fh, ">", "w") or die $!;
							print $fh "$wallet_balance\n";
							close($fh) or die $!;
						} else {
							print "status is $status.\n";
						}
					}
				}
			}
		}
	}
}
sub proc_usual_item {
	my ($referer, $iprice, $name) = @_;
	my $price_bak = $iprice;
	my $no_match = 0;
	defined $cnt_of_item{$referer} and not $cnt_of_item{$referer} and return;
	for (split /,/, $price_bak) {
		/^(\d+)$/ and $iprice = $1, next;
		if (/^cnt=(\d+)$/) {
			not defined $cnt_of_item{$referer} and $cnt_of_item{$referer} = $1, ($debug and print $log "setting cnt of $referer to $1.\n");
			next;
		}
		/^no_match$/ and $no_match = 1;
	}
	$referer =~ m|http://.*?(/.*)|;
	my $uri_prefix = $1;
	print $log "uri prefix is $uri_prefix.\n" if $debug;
	my ($listing_id, $total, $subtotal);
	{
		my ($status, $json) = http_get(\$socket_http_get, $uri_prefix . "/render/?query=&start=0&count=5", "Referer: $referer\r\n" . "Cookie: $search_acc_cookie\r\n");
		print $log "status is $status.\n" if $debug;
		redo unless $status eq "ok";
		$json = gunzip($json);
		($debug and print $log "warning, json response failed, retrying\n"), redo unless $json =~ /^{"success":true/;
		$json =~ /total_count":(\d+)/;
		($debug and print $log "no listing for $referer now\n"), next unless defined $1 && $1 > 0;
		$json =~ /results_html":"(.*?)[^\\]"/;
		($debug and print $log "json response not valid, retrying\n"), redo unless defined $1;
		my @html = split /\\n/, $1;
		(my $item_name) = ($json =~ /market_name":"(.*?)"/);
		unless ($no_match or defined $item_name and $name eq $item_name) {
			print($log "referer name: $name\nitem: $item_name\ndon't match\n") if (defined $item_name and $debug);
			redo;
		}
		print $log "going to scanning price for $referer\n" if ($debug);
		$i = 0;
		while ($i < @html) {
			$_ = $html[$i++];
			if (/BuyMarketListing\('listing', '(.*?)'/) { $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; }
			if (/market_listing_price_with_fee/) {
				next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
				print $log "current item price $total\n" if ($debug);
				last if ($total > $iprice || $total > $wallet_balance);
			}
			if (/market_listing_price_without_fee/) {
				next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
				my $fee = $total - $subtotal;
				my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
				my ($status, $post_result) = http_post("/market/buylisting/$listing_id", "Referer: $referer\r\n" . "Cookie: $buying_acc_cookie\r\n", $post_data);
				print "$referer\ngoing to buy this item for $total, fee $fee, subtotal $subtotal\n";
				print "post data is $post_data\n";
				if ($status eq "ok") {
					($wallet_balance) = $post_result =~ /wallet_balance":(\d+)/;
					print "$post_result\nwallet_balance:$wallet_balance\n";
					open($fh, ">", "w") or die $!;
					print $fh "$wallet_balance\n";
					close($fh) or die $!;
					defined $cnt_of_item{$referer} and $cnt_of_item{$referer}--, print("cnt remaining $cnt_of_item{$referer}.\n"), (not $cnt_of_item{$referer} and last);
				} elsif ($debug) {
					print "status is $status.\n";
				}
			}
		}
	}
}
sub new_socket_and_connect_to {
	my ($ip_addr_ascii, $port) = @_;
	$ip_addr_ascii =~ /(\d+).(\d+).(\d+).(\d+)/ or die "invalid ip address\n";
	my $ip_and_port = pack("CxnC4x8", 2, 80, $1, $2, $3, $4);
	socket(my $socket, 2, 1, 0) or die "open socket failed: $!\n";
	while (1) { connect($socket, $ip_and_port) and last or $debug and print $log "connect failed: $!, retrying\n" }
	print $log "new socket connected.\n" if $debug;
	return $socket;
}
sub gunzip {
	my ($content) = @_;
	my ($cr, $pw, $pr, $cw);
	pipe($cr, $pw) or die $!;
	pipe($pr, $cw) or die $!;
	my $ans = "";
	if (fork()) {
		close($cr) and close($cw) or die $!;
		print $pw $content;
		close($pw) or die $!;
		$ans .= $_ while (<$pr>);
		close($pr) or die $!;
		die "no child process or gzip failed\n" if wait() < 0 or $?;
		return $ans;
	} else {
		close($pr) and close($pw) or die $!;
		open(STDIN, "<&", $cr) or die $!;
		open(STDOUT, ">&", $cw) or die $!;
		exec "gzip", "-dc";
	}
}
sub http_get {
	my ($socket_ref, $uri, $additional_header) = @_;
	my $request = "GET $uri HTTP/1.1\r\n" . "Host: $remote_host\r\n" . "Accept-Encoding: gzip\r\n" .
	    "Connection: keep-alive\r\n" . "User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31\r\n" .
	    $additional_header . "\r\n";
	while (1) {
		send($$socket_ref, $request, 0);
		my ($status, $ans) = http_extract_response_with_timeout($$socket_ref);
		$status =~ /sock.*error/ and close($$socket_ref), $$socket_ref = new_socket_and_connect_to($remote_ip_addr, 80) or return ($status, $ans);
	}
}
sub http_post {
	my ($uri, $additional_header, $post_data) = @_;
	my $socket = new_socket_and_connect_to($remote_ip_addr, 80);
	my $content_length = length $post_data;
	my $request = "POST $uri HTTP/1.1\r\n" . "Host: $remote_host\r\n" .
	    "Connection: keep-alive\r\n" . "User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31\r\n" .
	    $additional_header . "Content-Type: application/x-www-form-urlencoded\r\n" .
	    "Content-Length: $content_length\r\n" . "\r\n" . $post_data;
	while (1) {
		send($socket, $request, 0);
		my ($status, $ans) = http_extract_response_with_timeout($socket);
		close($socket);
		$status =~ /sock.*error/ and $socket = new_socket_and_connect_to($remote_ip_addr, 80) or return ($status, $ans);
	}
}
sub http_extract_response_with_timeout {
	my ($status, $ans);
	eval {
		local $SIG{ALRM} = sub { die "timeout\n" };
		alarm 60;
		($status, $ans) = http_extract_response(@_);
		alarm 0
	};
	($debug and print $log "group $group timeout.\n"), return "sock_read_timeout_error" if $@;
	return ($status, $ans);
}
sub http_extract_response {
	my ($socket) = @_;
	my ($content_length);
	my ($chunked_encoding, $met_first_blank_line, $first_line, $ans) = (0, 0, 1, "");
	while (1) {
		my $line = <$socket>;
		not defined $line and return "sock_read_error";
		$line =~ s/\r?\n$//;
		$first_line and $first_line = 0, $line !~ m|^HTTP/1.1 200 OK$| and return "http_response_error";
		$content_length = $1, next if $line =~ /^Content-Length: (\d+)$/ and not $met_first_blank_line;
		$chunked_encoding = 1, next if $line =~ /^Transfer-Encoding: chunked$/ and not $met_first_blank_line;
		print $log "server connection header $line\n" if $debug and $line =~ /^Connection:/ and not $met_first_blank_line;
		print $log "server keep-alive header $line\n" if $debug and $line =~ /^Keep-Alive:/ and not $met_first_blank_line;
		if (not $met_first_blank_line and not $line) {
			read($socket, $ans, $content_length) == $content_length and return ("ok", $ans) or return "sock_read_error" if defined $content_length;
			$met_first_blank_line = 1;
			next;
		}
		if ($met_first_blank_line) {
			my $this_chunk;
			my $chunk_size = hex $line;
			read($socket, $this_chunk, $chunk_size) == $chunk_size and $ans .= $this_chunk or return "sock_read_error" if $chunk_size;
			$line = <$socket>;
			not defined $line and return "sock_read_error";
			$line =~ s/\r?\n$//;
			return "invalid_http_response" if $line;
			last unless $chunk_size;
		}
	}
	return ("ok", $ans);
}
sub main_loop {
	my $old_sec = time();
	$socket_http_get = new_socket_and_connect_to($remote_ip_addr, 80);
	while (1) {
		if (defined $item_iprice{"tournament"}) {
			proc_tournament_item($item_iprice{"tournament"});
		} else {
			for (keys %item_iprice) {
				my ($referer, $iprice, $name) = ($_, $item_iprice{$_}, referer_to_name($_));
				print $log "referer name is $name\n" if ($debug);
				if ($iprice =~ /func=proc_unusual_courier/) {
					proc_unusual_courier($referer, $iprice, $name);
				} elsif ($iprice =~ /func=proc_unusual_hat/) {
					proc_unusual_hat($referer, $iprice, $name);
				} else {
					proc_usual_item($referer, $iprice, $name);
				}
			}
		}
		my $new_sec = time();
		print $log "group $group: seconds for this round is ", $new_sec - $old_sec, ".\n" if ($debug);
		$old_sec = $new_sec;
		my $all_done = 1;
		(not defined $cnt_of_item{$_} or $cnt_of_item{$_}) and $all_done = 0, last for (keys %item_iprice);
		print("all work done, quitting.\n"), last if $all_done;
		open($fh, "<", "w") or die $!;
		chomp($wallet_balance = <$fh>);
		close($fh) or die $!;
	}
}
sub proc_tournament_item {
	my (%url_to_team_name, %url_to_tournament_name);
	my $price_conf = $_[0];
	my (%player, %team_of_player, %tournament, %event, %team, %quality, %event_name_full_to_brief, %player_to_profile_uri, %player_to_profile_name);
	%event_name_full_to_brief = ("Double Kill" => "dk", "First Blood" => "fb", "Aegis Denial" => "ad", "Triple Kill" => "tk", "Aegis Stolen" => "as", "ULTRA KILL" => "uk", "Victory" => "win",
				     "Courier Kill" => "ck", "Godlike" => "gl", "Allied Hero Denial" => "ahd", "RAMPAGE!" => "rampage");
	%url_to_team_name = ("http://cloud-2.steampowered.com/ugc/576738944225927378/441962CFDB10FA188D0AE854E85ED3425B6088FF/" => "alliance",
			     "http://cloud-2.steampowered.com/ugc/630787216938014761/1A5D6106352A721DBD2760C8F7FCBDA5C00935F8/" => "lgd.cn",
			     "http://cloud-2.steampowered.com/ugc/612760050488516720/DF0EE7F44746239DBA83B8F4537758ECBB51655E/" => "orange",
			     "http://cloud-2.steampowered.com/ugc/577870551233852518/EDF47BD55EDFF6269243E5E8D5B96CAF87696D87/" => "dk",
			     "http://cloud-2.steampowered.com/ugc/939254794963968818/367CD9CD40776AD11C9207049A0351E53C417A71/" => "ig",
			     "http://cloud-2.steampowered.com/ugc/612767741208345582/613BE7799811FC7174B52E4E96787A53961028AB/" => "zenith",
			     "http://cloud.steampowered.com/ugc/1118300602706069935/0326BF13EADA3B4BD0826D17A7FBBFB2E53493D6/" => "rs",
			     "http://cloud-2.steampowered.com/ugc/613896720944358650/05B38027BE5639B71A70B946673E6BFAFC7CC3B2/" => "tongfu",
			     "http://cloud-2.steampowered.com/ugc/920110421043409228/82E0398179759BD48DA9486A7F10CB1ECE55A713/" => "navi",
			     "http://cloud-2.steampowered.com/ugc/541804955981794502/4604E42A5D75D9BA2EF91C6C91E4B200241D2273/" => "ehome");
	%url_to_tournament_name = ("http://media.steampowered.com/apps/570/icons/econ/leagues/subscriptions_premierleague4_ingame.684a4f8668a957ef016844b5ff099f3091d55d68.png" => "tpls4",
				   "http://media.steampowered.com/apps/570/icons/econ/leagues/subscriptions_g-1_season5_ingame.8f43f5f7dac398ee1f135e789a31419e290428f6.png" => "g1",
				   "http://media.steampowered.com/apps/570/icons/econ/leagues/subscriptions_international_ingame.67992219b177deb3e7431b76a25b9cb7bcc05232.png" => "ti2",
				   "http://media.steampowered.com/apps/570/icons/econ/leagues/subscriptions_international_2013_ingame.bdcf612cab48cb613861a4b4e32930d69e29b169.png" => "ti3");
	%player_to_profile_uri = (s4 => "/profiles/76561198001497299", burning => "/profiles/76561198051158462", xb => "/profiles/76561198051963819", dendi => "/id/DendiQ/",
				  xboct => "/profiles/76561198049891200", zhou => "/profiles/76561198050403391", loda => "/profiles/76561198061761348",
				  hao => "/profiles/76561198048774243", mushi => "/profiles/76561198050137285", bulldog => "/profiles/76561198036748162",
				  akke => "/profiles/76561198001554683", mu => "/id/Piglara/", chuan => "/id/bestdotachuan", yyf => "/profiles/76561198050310737", 430 => "/profiles/76561198048850805");
	for (split /,/, $price_conf) {
		next if /func=proc_tournament_item/;
		/(.*?)=(.*)/;
		my $hash_name = $1;
		for (split /:/, $2) {
			/(.*?)=(.*)/;
			print $log "hash_name: $hash_name option: $1 value: $2\n" if $debug;
			$hash_name eq "tournament" and $tournament{$1} = $2, next;
			if ($hash_name eq "player") {
				my $player_name = $1;
				$2 =~ /(.*)=(.*)/;
				print $log "player name: $player_name team name: $1 price: $2\n" if $debug;
				$player{$player_name} = $2;
				$team_of_player{$player_name} = $1;
				{
					my ($status, $html) = http_get($socket_http_get, "$player_to_profile_uri{$player_name}", "Cookie: $search_acc_cookie\r\n");
					redo unless $status eq "ok";
					$html = gunzip($html);
					$html =~ m|<title>Steam Community :: (.*)</title>| and ($debug and print $log "player $player_name profile name setting to $1.\n"), $player_to_profile_name{$player_name} = $1 or redo;
				}
				next;
			}
			$hash_name eq "team" and $team{$1} = $2, next;
			$hash_name eq "event" and $event{$1} = $2, next;
			$hash_name eq "quality" and $quality{$1} = $2, next;
		}
	}
	my $max_considered_price = 0;
	my @sorted_list = sort { $b <=> $a } values %player;	$max_considered_price += (defined $sorted_list[0] ? $sorted_list[0] : 0) + (defined $sorted_list[1] ? $sorted_list[1] : 0);
	@sorted_list = sort {$b <=> $a} values %tournament;	$max_considered_price += defined $sorted_list[0] ? $sorted_list[0] : 0;
	@sorted_list = sort {$b <=> $a} values %event;		$max_considered_price += defined $sorted_list[0] ? $sorted_list[0] : 0;
	@sorted_list = sort {$b <=> $a} values %team;		$max_considered_price += (defined $sorted_list[0] ? $sorted_list[0] : 0) + (defined $sorted_list[1] ? $sorted_list[1] : 0);
	@sorted_list = sort {$b <=> $a} values %quality;	$max_considered_price += defined $sorted_list[0] ? $sorted_list[0] : 0;
	print $log "max_considered_price is $max_considered_price\n" if $debug;
	{
		my ($status, $html) = http_get($socket_http_get, "/market/search/render/?query=tournament&start=0&count=1", "Cookie: $search_acc_cookie\r\n" . "Referer: http://steamcommunity.com/market/search/render/?query=tournament\r\n");
		print $log "status for getting /market/search/render/?query=tournament&start=0&count=1 is $status\n" if $debug;
		redo unless $status eq "ok";
		$html = gunzip($html);
		($debug and print $log "getting info failed\n"), redo unless $html =~ /^{"success":true/;
		$html =~ /"total_count":(\d+)/;
		($debug and print $log "couldn't find total_count\n"), redo unless defined $1;
		print $log "total_count for whole tournament item is $1\n" if $debug;
		my $cnt_unique_items = $1;
		my $start = 0;
		while ($start < $cnt_unique_items) {
			my $count = 50;
			$count = $cnt_unique_items - $start if $cnt_unique_items - $start < 50;
			my ($status, $html) = http_get($socket_http_get, "/market/search/render/?query=tournament&start=$start&count=$count", "Cookie: $search_acc_cookie\r\n" . "Referer: http://steamcommunity.com/market/search/render/?query=tournament\r\n");
			print $log "status for getting /market/search/render/?query=tournament&start=$start&count=$count is $status\n" if $debug;
			redo unless $status eq "ok";
			$html = gunzip($html);
			($debug and print $log "getting info failed\n"), redo unless $html =~ /^{"success":true/;
			while ($html =~ /href=\\"(.*?)\\"/g) {
				my $url = $1;
				$url =~ s/\\//g;
				print $log "item url is $url\n" if $debug;
				next if $url =~ /filter=tournament/;
				next unless $url =~ /570/;
				$url =~ m|http://steamcommunity.com(.*)|;
				next unless defined $1;
				my $uri = $1;
				my $name = referer_to_name($url);
				print $log "item name is $name\n" if $debug;
				{
					my ($status, $html) = http_get($socket_http_get, "$uri/render/?query=&start=0&count=1", "Referer: $url\r\n" . "Cookie: $search_acc_cookie\r\n");
					print $log "status for getting $uri/render/?query=&start=0&count=1 is $status\n" if $debug;
					redo unless $status eq "ok";
					$html = gunzip($html);
					($debug and print $log "getting info failed\n"), redo unless $html =~ /^{"success":true/;
					$html =~ /"total_count":(\d+)/;
					($debug and print $log "couldn't find total_count\n"), redo unless defined $1;
					print $log "total_count for this specific item is $1\n" if $debug;
					my $cnt_specific_item = $1;
					my $start = 0;
					loop: while ($start < $cnt_specific_item) {
						my $count = 50;
						$count = $cnt_specific_item - $start if $cnt_specific_item - $start < 50;
						my ($status, $json) = http_get($socket_http_get, "$uri/render/?query=&start=$start&count=$count", "Referer: $url\r\n" . "Cookie: $search_acc_cookie\r\n");
						print $log "status for getting $uri/render/?query=&start=$start&count=$count is $status\n" if $debug;
						redo unless $status eq "ok";
						$json = gunzip($json);
						($debug and print $log "getting info failed\n"), redo unless $json =~ /^{"success":true/;
						($debug and print $log "counldn't find results_html\n"), redo unless $json =~ /"results_html":"(.*?)[^\\]"/;
						my @html = split /\\n/, $1;
						my @descriptions = $json =~ /"descriptions":\[(.*?)\]/g;
						my ($quality_description) = $json =~ /"descriptions":\[.*?\].*?"type":"(.*?)"/;
						($debug and print $log "strange error, quality_description not defined.\n"), last unless defined $quality_description;
						print $log "quality_description is $quality_description\n" if $debug;
						my $quality_bonus;
						$quality_description =~ /$_/ and $quality_bonus = $quality{$_}, last for (keys %quality);
						print $log "quality_bonus is " . (defined $quality_bonus ? $quality_bonus : "undefined") . "\n" if $debug;
						(my $item_name) = ($json =~ /market_name":"(.*?)"/);
						print $log "item_name for market is $item_name\n" if $debug;
						unless (defined $item_name and $name eq $item_name) {
							print($log "referer name: $name\nitem: $item_name\ndon't match\n") if (defined $item_name and $debug);
							redo;
						}
						my ($total, $subtotal, $description_cnt, $listing_id);
						$description_cnt = -1;
						$i = 0;
						while ($i < @html) {
							$_ = $html[$i++];
							if (/BuyMarketListing\('listing', '(.*?)'/) { $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; }
							if (/market_listing_price_with_fee/) {
								next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
								($debug and print $log "total $total too much, jumping out\n"), last loop if ($total > $max_considered_price || $total > $wallet_balance);
							}
							if (/market_listing_price_without_fee/) {
								$description_cnt++;
								next unless $html[$i++] =~ /(\d+\.\d+)/; $subtotal = $1*100;
								my $fee = $total - $subtotal;
								($debug and print $log "strange error, description not defined.\n"), last unless defined $descriptions[$description_cnt];
								my ($tournament_url, $team_a_url, $team_b_url, $event_name, $tournament_info);
								my ($tournament_name, $team_a_name, $team_b_name);
								while ($descriptions[$description_cnt] =~ /"value":"(.*?)(?<!\\)"/g) {
									$_ = $1;
									next unless /tournament_info/ and /Tournament Item Details/;
									$tournament_info = $_;
									$debug and print $log "can't extract tournament info, perhaps not a tournament item or program bug.\n", next unless m|src=\\"(.*?)\\".*?src=\\"(.*?)\\".*?<b> vs\. <\\/b>.*?src=\\"(.*?)\\".*?<b>(.*?)<\\/b>|;
									($tournament_url, $team_a_url, $team_b_url, $event_name) = ($1, $2, $3, $4);
									defined $_ and s/\\//g for ($tournament_url, $team_a_url, $team_b_url);
								}
								($debug and print $log "tournament info not extracted, this may indicate either that this item is not tournament or something is wrong in the program.\n"), next unless defined $tournament_url and defined $team_a_url and defined $team_b_url and defined $event_name;
								my $max_considered_price = 0;
								my ($a, $b);
								$max_considered_price += $b if defined ($a = $tournament_name = $url_to_tournament_name{$tournament_url}) and defined ($b = $tournament{$a});
								$max_considered_price += $b if defined ($a = $team_a_name = $url_to_team_name{$team_a_url}) and defined ($b = $team{$a});
								$max_considered_price += $b if defined ($a = $team_b_name = $url_to_team_name{$team_b_url}) and defined ($b = $team{$a});
								$max_considered_price += $b if defined ($a = $event_name_full_to_brief{$event_name}) and defined ($b = $event{$a});
								$max_considered_price += $quality_bonus if defined $quality_bonus;
								my $player_bonus_times = 0;
								defined $player_to_profile_name{$_} and $tournament_info =~ /\Q$player_to_profile_name{$_}\E/ and (defined $team_a_name and $team_a_name eq $team_of_player{$_} or defined $team_b_name and $team_b_name eq $team_of_player{$_}) and $max_considered_price += $player{$_}, $player_bonus_times++, ($debug and print $log "matched player $_\n") for (keys %player);
								$debug and print $log "matched tournament $tournament_name\n" if defined $tournament_name;
								$debug and print $log "matched team_a $team_a_name\n" if defined $team_a_name;
								$debug and print $log "matched team_b $team_b_name\n" if defined $team_b_name;
								$debug and print $log "event is $event_name\n";
								print $log "max_considered_price for this tournament item is $max_considered_price\n" if $debug;
								next if (not defined $team_a_name and not defined $team_b_name or $total > $max_considered_price);
								my $post_data = "sessionid=$sessionid&currency=1&subtotal=$subtotal&fee=$fee&total=$total";
								my ($status, $post_result) = http_post("/market/buylisting/$listing_id", "Referer: $url\r\n" . "Cookie: $buying_acc_cookie\r\n", $post_data);
								print "condition met, going to buy $url for total $total\n";
								if ($status eq "ok") {
									($wallet_balance) = $post_result =~ /wallet_balance":(\d+)/;
									print "$post_result\nwallet_balance:$wallet_balance\n";
									open($fh, ">", "w") or die $!;
									print $fh "$wallet_balance\n";
									close($fh) or die $!;
								} else {
									print "status is $status.\n";
								}
							}
						}
						$start += $count;
					}
				}
			}
			$start += $count; 
		}
	}
}
