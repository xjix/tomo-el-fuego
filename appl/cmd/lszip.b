implement Lszip;

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
# <https://source.heropunch.luxe/System/9/inferno-zipfs>
# <https://github.com/mjl-/zipfs>

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
include "bufio.m";
include "zip.m";
	zip: Zip;
	Fhdr, CDFhdr, Endofcdir: import zip;

Lszip: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

dflag: int;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	zip = load Zip Zip->PATH;
	zip->init();

	arg->init(args);
	arg->setusage(arg->progname()+" [-d] file");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	zip->dflag = dflag++;
		* =>	arg->usage();
		}
	args = arg->argv();
	if(len args != 1)
		arg->usage();

	fd := sys->open(hd args, Sys->OREAD);
	if(fd == nil)
		fail(sprint("open: %r"));

	(nil, fhdrs, err) := zip->open(fd);
	if(err != nil)
		fail("parsing zip: "+err);

	for(i := 0; i < len fhdrs; i++)
		sys->print("%q\n", fhdrs[i].filename);
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}
