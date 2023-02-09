#!/bin/sh

upload_name=`echo $QUERY_STRING | sed -E 's,n=(.+),\1,'`

case $REQUEST_METHOD in
	POST)
		## only y specifically?
		##&& `echo $FOSSIL_CAPABILITIES | grep y >/dev/null`; then
		## the above errors for some reason, but works in repl
		if [ -n $CONTENT_LENGTH ]; then
			## map repos to their ci directory
			repo_slug=`echo $FOSSIL_URI | sed -E -e 's,^/,,' -e 's,/,_,g'`
			upload_target="/srv/dist/_ci/$repo_slug/$upload_name"
			if [ -d `dirname $upload_target` ]; then
				## read Content-Length bytes from STDIN
				head -c $CONTENT_LENGTH /dev/stdin > $upload_target
				cd `dirname $upload_target`
				## store content id
				content_id=`shasum -a 512 $upload_name`
				echo $content_id > $upload_target.sha512
				# hmmm
				#ln -sf $upload_target tomo-Linux-386-.zip
				## all set!
				echo Status: 200 OK
				echo Content-Type: application/json
				echo
				echo "{\"l\": $CONTENT_LENGTH, \"id\": \"$content_id\"}"
				exit 0
			else
				echo Status: 400 Bad Request
				echo Content-Type: application/json
				echo
				echo "{\"n\": \"$upload_target\", \"m\": \"$FOSSIL_URI not setup\"}"
				exit 0
			fi
		else
			echo Status: 400 Bad Request
			echo Content-Type: application/json
			echo
			echo "{\"n\": \"$upload_name\", \"m\": \"nothing to upload or missing y cap - $FOSSIL_CAPABILITIES\"}"
			exit 0
		fi;;
	*)
		echo Status: 200 OK
		echo Content-Type: application/json
		echo
		echo "{\"n\": \"$upload_name\"}"
		exit 0;;
esac

# vi: ts=2
