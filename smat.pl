#!/bin/perl
=name
Steamcommunity Market Auto Trader
=cut
use strict;
use warnings;
use Socket;
my ($remote_ip_addr, $remote_host) = ("63.228.223.103", "steamcommunity.com");
my ($i, $buying_acc, $search_acc, $debug, $iprice_file, $sessionid, $wallet_balance, $log, $rest_time);
my ($socket_http_get, $fork_process, $fh, $buying_acc_cookie, $search_acc_cookie);
my @cookie_from_file;
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
	not $_ =~ /^#/ and $cnt_of_iitem++ for (@iprice_content);
	print $log "cnt_of_iitem is $cnt_of_iitem.\n" if $debug;
	use integer;
	my ($item_per_process, $remainder) = ($cnt_of_iitem / $fork_process, $cnt_of_iitem % $fork_process);
	no integer;
	my $cnt_current_item = 0;
	for (@iprice_content) {
		next if /^#/;
		chomp;
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
sub proc_unusual_courier {
	my %usual_color = ("61, 104, 196" => "indigo", "130, 50, 207" => "violet", "74, 183, 141" => "teal", "255, 255, 255" => "trivial",
			   "183, 207, 51" => "light_green", "208, 119, 51" => "orange", "130, 50, 237" => "purple", "81, 179, 80" => "green", "0, 151, 206" => "blue", "207, 171, 49" => "gold", "208, 61, 51" => "red");
	my %effect_abbreviation_to_full = ("ef" => "Ethereal Flame", "dt" => "Directide Corruption", "sf" => "Sunfire",
					   "ff" => "Frostivus Frost", "lotus" => "Trail of the Lotus Blossom",
					   "re" => "Resonant Energy");
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
				if (/BuyMarketListing\('listing', '(.*?)'/) { $description_cnt++, $listing_id = $1; print $log "current listing id $listing_id\n" if ($debug); next; }
				if (/market_listing_price_with_fee/) {
					next unless $html[$i++] =~ /(\d+\.\d+)/; $total = $1*100;
					last loop if ($total > $max_price || $total > $wallet_balance);
				}
				if (/market_listing_price_without_fee/) {
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
						} elsif ($debug) {
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
		unless (defined $item_name and $name eq $item_name) {
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
				} elsif ($debug) {
					print "status is $status.\n";
				}
			}
		}
	}
}
sub new_socket_and_connect_to {
	my ($ip_addr_ascii, $port) = @_;
	my $ip_addr_numeric = inet_aton($ip_addr_ascii) || die "invalid ip address\n";
	my $ip_and_port = pack_sockaddr_in($port, $ip_addr_numeric);
	my $proto = getprotobyname("tcp");
	socket(my $socket, PF_INET, SOCK_STREAM, $proto) or die "open socket failed: $!\n";
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
		my ($status, $ans) = http_extract_response($$socket_ref);
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
		my ($status, $ans) = http_extract_response($socket);
		close($socket);
		$status =~ /sock.*error/ and $socket = new_socket_and_connect_to($remote_ip_addr, 80) or return ($status, $ans);
	}
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
		for (keys %item_iprice) {
			my ($referer, $iprice, $name) = ($_, $item_iprice{$_}, referer_to_name($_));
			print $log "referer name is $name\n" if ($debug);
			if ($iprice =~ /func=proc_unusual_courier/) {
				proc_unusual_courier($referer, $iprice, $name);
			} else {
				proc_usual_item($referer, $iprice, $name);
			}
		}
		my $new_sec = time();
		print $log "group $group: seconds for this round is ", $new_sec - $old_sec, ".\n" if ($debug);
		$old_sec = $new_sec;
		open($fh, "<", "w") or die $!;
		chomp($wallet_balance = <$fh>);
		close($fh) or die $!;
	}
}
