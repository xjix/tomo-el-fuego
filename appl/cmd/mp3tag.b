# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.

# <https://source.heropunch.luxe/System/9/inferno-attrfs>
# <https://github.com/mjl-/attrfs>

implement Mp3tag0;

include "sys.m";
include "draw.m";
include "arg.m";
include "mp3tags.m";

sys: Sys;
mp3tags: Mp3tags;

sprint, fprint, fildes, print: import sys;
Mp3tag, genre: import mp3tags;

Mp3tag0: module
{
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	mp3tags = load Mp3tags Mp3tags->PATH;

	arg->init(args);
	arg->setusage(arg->progname()+" file");
	while((c := arg->opt()) != 0)
		case c {
		* =>	print("lala\n"); arg->usage();
		}
	args = arg->argv();
	if(len args != 1)
		arg->usage();

	(tag, err) := Mp3tag.read(hd args);
	if(err != nil)
		fail(err);
	print("%s\n", tag.title);
	print("%s\n", tag.artist);
	print("%s\n", tag.album);
	print("%s\n", tag.year);
	print("%s\n", tag.comment);
	print("%d\n", tag.track);
	print("%s\n", genre(tag.genre));
}

fail(s: string)
{
	fprint(fildes(2), "%s\n", s);
	raise "fail:"+s;
}
