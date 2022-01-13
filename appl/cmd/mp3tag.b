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
