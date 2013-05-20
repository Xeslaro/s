#!/bin/bash
while (($#>1)); do
	case $1 in
		strip_bin)
			find ${!#}/{bin,sbin,lib,libexec} | while read i; do
				if [[ ! -h "$i" && -f "$i" && -x "$i" ]] && file "$i" | grep 'ELF.*not stripped' >/dev/null; then
					[[ ! -w "$i" ]] && chmod u+w "$i"
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
						[[ ! "$c" =~ gz$ ]] && ln -sf "$c.gz" "$i"
					fi
					[[ ! "$i" =~ gz$ ]] && mv "$i" "$i.gz"
				fi
			done
			;;
		rm_a)
			find ${!#}/lib -name '*.a' | while read i; do
				[[ -f "${i/%a/so}" ]] && rm "$i"
			done
			;;
		strip_a)
			find ${!#}/lib -name '*.a' | while read i; do
				[[ ! -w "$i" ]] && chmod u+w "$i"
				strip --strip-unneeded "$i"
			done
			;;
	esac
	shift
done
