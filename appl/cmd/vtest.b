# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org/>
# <https://source.heropunch.luxe/System/9/inferno-ventisrv>
# <https://github.com/mjl-/ventisrv>

implement Vtest;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
include "dial.m";
	dial: Dial;
include "venti.m";
	venti: Venti;
	Vmsg, Score, Session, Datatype: import venti;

Vtest: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

addr := "$venti";
dflag := 0;
dtype := Datatype;
n := 1;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	venti = load Venti Venti->PATH;
	venti->init();

	arg->init(args);
	arg->setusage(arg->progname() + " [-d] [-a addr] [-n count] type score");
	while((c := arg->opt()) != 0)
		case c {
		'a' =>	addr = arg->earg();
		'd' =>	dflag++;
		'n' =>	n = int arg->earg();
		* =>	arg->usage();
		}
	args = arg->argv();
	if(len args != 2)
		arg->usage();

	dtype = int hd args;
	args = tl args;
	(ok, score) := Score.parse(hd args);
	if(ok != 0)
		fail("bad score: "+hd args);

	say("dialing");
	addr = dial->netmkaddr(addr, "net", "venti");
	cc := dial->dial(addr, nil);
	if(cc == nil)
		fail(sprint("dialing %s: %r", addr));
	fd := cc.dfd;
	say("have connection");

	session := Session.new(fd);
	if(session == nil)
		fail(sprint("handshake: %r"));
	say("have handshake");

	for(i := 0; i < n; i++) {
		vmsg := ref Vmsg.Tread(1, i % 256, score, dtype, Venti->Maxlumpsize);
		d := vmsg.pack();
		if(sys->write(fd, d, len d) != len d)
			fail(sprint("writing: %r"));
		say(sprint("> %d", tagof vmsg));
	}
	for(i = 0; i < n; i++) {
		(vmsg, err) := Vmsg.read(fd);
		if(err != nil)
			fail(sprint("reading: %r"));
		say(sprint("< %d", tagof vmsg));
	}
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}

say(s: string)
{
	if(dflag)
		sys->fprint(sys->fildes(2), "%s\n", s);
}
