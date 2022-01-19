# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.

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
