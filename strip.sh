#!/bin/bash
while (($#>1)); do
	case $1 in
		strip_bin)
			find ${!#}/{bin,sbin,lib,libexec} | while read i; do
				if [[ ! -h "$i" && -f "$i" && -x "$i" ]]; then
					if [[ ! -w "$i" ]]; then
						chmod u+w "$i"
					fi
					strip "$i"
				fi
			done
			;;
		gzip_man)			
			find ${!#}/share/{man,info} | while read i; do
				if [[ ! -h "$i" && -f "$i" && ! "$i" =~ .*".gz" ]]; then
					gzip -f "$i"
				elif [[ -h "$i" ]]; then
					c=$(ls -l "$i")
					if [[ "$c" =~ "-> "(.*) ]]; then
						c=${BASH_REMATCH[1]}
						if [[ ! "$c" =~ gz$ ]]; then
							ln -sf "$c.gz" "$i"
						fi
					fi
					if [[ ! "$i" =~ gz$ ]]; then
						mv "$i" "$i.gz"
					fi
				fi
			done
			;;
		rm_a)
			find ${!#}/lib -name '*.a' | while read i; do
				if [[ -f "${i/%a/so}" ]]; then
					rm "$i"
				fi
			done
			;;
		strip_a)
			find ${!#}/lib -name '*.a' | while read i; do
				if [[ ! -w "$i" ]]; then
					chmod u+w "$i"
				fi
				strip --strip-unneeded "$i"
			done
			;;
	esac
	shift
done
