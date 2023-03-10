# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
implement Readnetstr;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "netstr.m";
	netstr: Netstr;

Readnetstr: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	netstr = load Netstr Netstr->PATH;

	if(args != nil)
		args = tl args;
	if(args != nil && hd args == "--")
		args = tl args;

	if(len(args) != 0)
		fail("usage: readnetstr");

	(s, err) := netstr->readstr(sys->fildes(0));
	if(err != nil)
		fail("reading netstring: "+err);
	sys->print("%s", s);
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}
