# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
implement Torrentverify;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "arg.m";
include "keyring.m";
	kr: Keyring;
include "styx.m";
include "bitarray.m";
	bitarray: Bitarray;
	Bits: import bitarray;
include "bittorrent.m";
	bt: Bittorrent;
	Bee, Msg, Torrent, Torrentx: import bt;
include "rand.m";
include "util0.m";
	util: Util0;
	killgrp, pid, warn, hex: import util;

Torrentverify: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};


dflag: int;
nofix: int;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	arg := load Arg Arg->PATH;
	kr = load Keyring Keyring->PATH;
	bitarray = load Bitarray Bitarray->PATH;
	bt = load Bittorrent Bittorrent->PATH;
	bt->init();
	util = load Util0 Util0->PATH;
	util->init();

	sys->pctl(Sys->NEWPGRP, nil);

	arg->init(args);
	arg->setusage(arg->progname()+" [-dn] torrentfile");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	bt->dflag = dflag++;
		'n' =>	nofix = 1;
		* =>	arg->usage();
		}

	args = arg->argv();
	if(len args != 1)
		arg->usage();

	f := hd args;
	(t, terr) := Torrent.open(f);
	if(terr != nil)
		fail(terr);

	(tx, nil, oerr) := Torrentx.open(t, f, nofix, 1);
	if(oerr != nil)
		fail(oerr);
	if(tx == nil)
		fail("files from the torrent do not exist");

	spawn bt->reader(tx, rc := chan[2] of (array of byte, string));
	digest := array[kr->SHA1dlen] of byte;
	n := 0;
	for(i := 0; i < t.piececount; i++) {
		(buf, err) := <-rc;
		if(err != nil)
			fail(err);
		kr->sha1(buf, len buf, digest, nil);
		if(hex(digest) == hex(t.hashes[i])) {
			sys->print("1");
			n++;
		} else
			sys->print("0");
	}
	sys->print("\n");
	sys->print("progress:  %d/%d pieces\n", n, t.piececount);
}

say(s: string)
{
	if(dflag)
		warn(s);
}

fail(s: string)
{
	warn(s);
	killgrp(pid());
	raise "fail:"+s;
}
