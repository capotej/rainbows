#!/bin/sh
. ./test-lib.sh

t_plan 10 "rack.input client_max_body_size bigger"

t_begin "setup and startup" && {
	rtmpfiles curl_out curl_err cmbs_config
	rainbows_setup $model
	sed -e 's/client_max_body_size.*/client_max_body_size 10485760/' \
	  < $unicorn_config > $cmbs_config
	rainbows -D sha1-random-size.ru -c $cmbs_config
	rainbows_wait_start
}

t_begin "stops a regular request" && {
	rm -f $ok
	dd if=/dev/zero bs=102485761 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	test -e $ok
}

t_begin "stops a large chunked request" && {
	rm -f $ok
	dd if=/dev/zero bs=102485761 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	test -e $ok
}

t_begin "small size sha1 chunked ok" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "small size sha1 content-length ok" && {
	blob_sha1=b376885ac8452b6cbf9ced81b1080bfd570d9b91
	rm -f $ok
	dd if=/dev/zero bs=256 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "right size sha1 chunked ok" && {
	blob_sha1=8c206a1a87599f532ce68675536f0b1546900d7a
	rm -f $ok
	dd if=/dev/zero bs=10485760 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "right size sha1 content-length ok" && {
	blob_sha1=8c206a1a87599f532ce68675536f0b1546900d7a
	rm -f $ok
	dd if=/dev/zero bs=10485760 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "default size sha1 chunked ok" && {
	blob_sha1=3b71f43ff30f4b15b5cd85dd9e95ebc7e84eb5a3
	rm -f $ok
	dd if=/dev/zero bs=1048576 count=1 | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "default size sha1 content-length ok" && {
	blob_sha1=3b71f43ff30f4b15b5cd85dd9e95ebc7e84eb5a3
	rm -f $ok
	dd if=/dev/zero bs=1048576 count=1 of=$tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test "$(cat $curl_out)" = $blob_sha1
}

t_begin "shutdown" && {
	kill $rainbows_pid
}

t_done
