# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
implement Testcgi;

include "sys.m";
	sys: Sys;
	print: import sys;
include "draw.m";
include "cgi.m";
	cgi: Cgi;
	Fields: import cgi;

Testcgi: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	cgi = load Cgi Cgi->PATH;
	if(cgi == nil)
		nomod(Cgi->PATH);
	cgi->init();

	if(len args != 2) {
		sys->fprint(sys->fildes(2), "usage: testcgi querystring\n");
		raise "fail:usage";
	}
	args = tl args;

	print("=== unpack\n");
	qs := hd args;
	f := cgi->unpack(qs);
	for(p := f.all(); p != nil; p = tl p) {
		(k, v, nil) := hd p;
		print("have %s=%s\n", k, v);
	}

	print("get: %s=%s\n", "wordfile", f.get("wordfile"));
	print("getdefault(oink): %s=%s\n", "blah", f.getdefault("blah", "oink"));
	print("getlist: %s -> len %d\n", "blah", len f.getlist("blah"));
		
	l: list of (string, string);
	for(fl := f.l; fl != nil; fl = tl fl)
		l = ((hd fl).t0, (hd fl).t1)::l;
	qs2 := cgi->pack(l);
	print("qs=%q qs2=%q\n", qs, qs2);

	print("=== unpackenv\n");
	f = cgi->unpackenv();
	if(f == nil)
		return;
	for(p = f.all(); p != nil; p = tl p) {
		(k, v, nil) := hd p;
		print("%s = %s\n", k, v);
	}
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
