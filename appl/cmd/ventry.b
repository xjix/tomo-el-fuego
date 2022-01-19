# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.

# <https://source.heropunch.luxe/System/9/inferno-ventisrv>
# <https://github.com/mjl-/ventisrv>

implement Ventry;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "dial.m";
	dial: Dial;
include "venti.m";
	venti: Venti;
	Score, Session, Entry, Entrysize, Datatype, Dirtype: import venti;
include "vac.m";
	vac: Vac;
	Vacfile: import vac;

Ventry: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

addr := "$venti";
dflag := 0;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	dial = load Dial Dial->PATH;
	venti = load Venti Venti->PATH;
	venti->init();
	vac = load Vac Vac->PATH;
	vac->init();

	index := 0;
	arg->init(args);
	arg->setusage(arg->progname() + " [-d] [-a addr] [-i index] score");
	while((c := arg->opt()) != 0)
		case c {
		'a' =>	addr = arg->earg();
		'd' =>	dflag++;
		'i' =>	index = int arg->earg();
		* =>	arg->usage();
		}
	args = arg->argv();
	if(len args != 1)
		arg->usage();

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

	ed := session.read(score, Dirtype, venti->Maxlumpsize);
	if(ed == nil)
		fail(sprint("reading entry: %r"));
	o := (index+1)*Entrysize;
	if(o > len ed)
		fail(sprint("only %d entries present", len ed/Entrysize));
	e := Entry.unpack(ed[o-Entrysize:o]);
	if(e == nil)
		fail(sprint("parsing entry: %r"));
	say("entry unpacked");

	bio := bufio->fopen(sys->fildes(1), bufio->OWRITE);
	if(bio == nil)
		fail(sprint("fopen stdout: %r"));

	f := Vacfile.new(session, e);
	buf := array[e.dsize] of byte;
	for(;;) {
		n := f.read(buf, len buf);
		if(n < 0)
			fail(sprint("reading: %r"));
		if(n == 0)
			break;
		say(sprint("have %d", n));
		if(bio.write(buf, n) != n)
			fail(sprint("writing: %r"));
	}
	if(bio.flush() < 0)
		fail(sprint("closing: %r"));
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
