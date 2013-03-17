package http;
sub cookie_dump {
	my ($cookie, $f) = @_;
	my $fh;
	open($fh, ">", $f);
	print $fh "$_=$cookie->{$_}\n" for (keys %$cookie);
	close($fh);
}
sub cookie_read {
	my ($cookie, $f) = @_;
	my $fh;
	open($fh, "<", $f);
	while (<$fh>) {
		chomp;
		/^(.*)=(.*)$/;
		$cookie->{$1} = $2;
	}
	close($fh);
}
sub update_cookie {
	my $h = shift;
	for (@_) {
		$h->{$1} = $2 if (/^Set-Cookie: (\w+)=([^;\r\n]+)/);
	}
}
sub get_cookie {
	my $h = shift;
	my $ans = "";
	for (keys %{$h}) {
		$ans .= " $_=$h->{$_};";
	}
	$ans =~ s/;$//;
	return $ans;
}
sub uri_escape {
	my $s = shift;
	my $ans = "";
	for (0..length($s)-1) {
		my $char = substr($s, $_, 1);
		$char = sprintf("%%%.2X", ord($char)) if ($char =~ /[^A-Za-z0-9-_.~]/);
		$ans .= $char;
	}
	return $ans;
}
sub http_get {
	my ($uri, $host, $port, $cookie) = @_;
	my $request =
	    "GET $uri HTTP/1.1\r\n".
	    "Host: $host\r\n".
	    "Connection: close\r\n".
	    "User-Agent: Xeslaro\r\n";
	$request .= "Cookie:" . get_cookie($cookie) . "\r\n" if ($cookie);
	$request .= "\r\n";
	return `echo -n '$request' | ncat $host $port`;
}
sub http_post {
	my ($uri, $host, $port, $post, $cookie) = @_;
	my $post_len = length($post);
	my $request =
	    "POST $uri HTTP/1.1\r\n".
	    "Host: $host\r\n".
	    "Connection: close\r\n".
	    "User-Agent: Xeslaro\r\n".
	    "Content-Length: $post_len\r\n".
	    "Content-Type: application/x-www-form-urlencoded\r\n";
	$request .= "Cookie:" . get_cookie($cookie) . "\r\n" if ($cookie);
	$request .= "\r\n" . $post;
	return `echo -n '$request' | ncat $host $port`;
}
sub wap_baidu_login {
	my ($user, $pass, $cookie) = @_;
	for (`wget wap.baidu.com -O -`) {
		if (/.*<a href="(.*)">贴吧<\/a>/) {
			for (`wget "$1" -O -`) {
				if (/.*<a href="(.*)">登录/) {
					my ($f, $post) = (0, "");
					for (`wget "$1" -O -`) {
						$f = 1 if (m|<form action="http://wappass.baidu.com/passport/" method="post">|);
						if ($f && m|<input |) {
							my ($name, $value);
							/name="(.*?)"/;$name = $1;
							/value="(.*?)"/;$value = $1;
							$value = $user if ($name =~ /^login_username$/);
							$value = $pass if ($name =~ /^login_loginpass$/);
							$value = "%E7%99%BB%E5%BD%95" if ($name =~ /^aaa$/);
							$post .= $name."=".$value."&";
						}
						last if ($f && m|</form>|);
					}
					$post =~ s|&$||;
					my @ans = http_post("/passport", "wappass.baidu.com", "80", $post, 0);
					update_cookie($cookie, @ans);
					for (@ans) {
						if (m|<meta http-equiv="refresh".*url=http://wap.baidu.com(.*)"/>|) {
							@ans = http_get("/$1", "wap.baidu.com", 80, $cookie);
							update_cookie($cookie, @ans);
							for (@ans) {
								if (m|.*<a href="http://wapp.baidu.com(.*)">贴吧|) {
									@ans = http_get($1, "wapp.baidu.com", 80, $cookie);
									update_cookie($cookie, @ans);
									for (@ans) {
										return $1 if (/.*<a href="(.*)m\?kz=\d+/);
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
sub wap_baidu_cookie_check {
	my ($base, $cookie) = @_;
	my $uri = $base . "m?kw=placebo";
	my $ans = http_get($uri, "wapp.baidu.com", 80, $cookie);
	return ($ans =~ /我的i贴吧/) ? 1 : 0;
}
sub wap_baidu_submit {
	my ($uri, $cookie, $co) = @_;
	my $post;
	my @ans = http_get($uri, "wapp.baidu.com", 80, $cookie);
	update_cookie($cookie, @ans);
	$post = "";
	for (@ans) {
		$uri = $1 if (/<form action="(.*)" method="post">/);
		/<input type="text" name="co"/g;
		while (m|<input.*?name="(.*?)".*?value="(.*?)"/>|g) {
			last if ($1 =~ /insert_smile/);
			$post .= "&" . uri_escape($1) . "=" . uri_escape($2);
		}
	}
	$post = "co=" . uri_escape($co) . $post;
	@ans = http_post("/$uri", "wapp.baidu.com", 80, $post, $cookie);
	update_cookie($cookie, @ans);
}
sub chrome_cookie_extract {
	my ($cookie, @c) = @_;
	chomp for (@c);
	my $i = 0;
	while ($i < @c) {
		unless ($i % 6) {
			$cookie->{$c[$i]} = $c[$i+1];
			$i++;
		}
		$i++;
	}
}
528;
