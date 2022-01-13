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

implement Mp3tags;

include "sys.m";
include "draw.m";
include "string.m";
include "mp3tags.m";

sys: Sys;
str: String;
mp3tags: Mp3tags;

sprint: import sys;

Titleoff:	con 3;
Artistoff:	con Titleoff+30;
Albumoff:	con Artistoff+30;
Yearoff:	con Albumoff+30;
Commentoff:	con Yearoff+4;
Trackoff:	con Commentoff+28;
Genreoff:	con Trackoff+2;

genres := array[] of {
	"Blues",
	"Classic Rock",
	"Country",
	"Dance",
	"Disco",
	"Funk",
	"Grunge",
	"Hip-Hop",
	"Jazz",
	"Metal",
	"New Age",
	"Oldies",
	"Other",
	"Pop",
	"R&B",
	"Rap",
	"Reggae",
	"Rock",
	"Techno",
	"Industrial",
	"Alternative",
	"Ska",
	"Death Metal",
	"Pranks",
	"Soundtrack",
	"Euro-Techno",
	"Ambient",
	"Trip-Hop",
	"Vocal",
	"Jazz+Funk",
	"Fusion",
	"Trance",
	"Classical",
	"Instrumental",
	"Acid",
	"House",
	"Game",
	"Sound Clip",
	"Gospel",
	"Noise",
	"AlternRock",
	"Bass",
	"Soul",
	"Punk",
	"Space",
	"Meditative",
	"Instrumental Pop",
	"Instrumental Rock",
	"Ethnic",
	"Gothic",
	"Darkwave",
	"Techno-Industrial",
	"Electronic",
	"Pop-Folk",
	"Eurodance",
	"Dream",
	"Southern Rock",
	"Comedy",
	"Cult",
	"Gangsta",
	"Top 40",
	"Christian Rap",
	"Pop/Funk",
	"Jungle",
	"Native American",
	"Cabaret",
	"New Wave",
	"Psychadelic",
	"Rave",
	"Showtunes",
	"Trailer",
	"Lo-Fi",
	"Tribal",
	"Acid Punk",
	"Acid Jazz",
	"Polka",
	"Retro",
	"Musical",
	"Rock & Roll",
	"Hard Rock",

	"Folk",
	"Folk-Rock",
	"National Folk",
	"Swing",
	"Fast Fusion",
	"Bebob",
	"Latin",
	"Revival",
	"Celtic",
	"Bluegrass",
	"Avantgarde",
	"Gothic Rock",
	"Progressive Rock",
	"Psychedelic Rock",
	"Symphonic Rock",
	"Slow Rock",
	"Big Band",
	"Chorus",
	"Easy Listening",
	"Acoustic",
	"Humour",
	"Speech",
	"Chanson",
	"Opera",
	"Chamber Music",
	"Sonata",
	"Symphony",
	"Booty Bass",
	"Primus",
	"Porn Groove",
	"Satire",
	"Slow Jam",
	"Club",
	"Tango",
	"Samba",
	"Folklore",
	"Ballad",
	"Power Ballad",
	"Rhythmic Soul",
	"Freestyle",
	"Duet",
	"Punk Rock",
	"Drum Solo",
	"A capella",
	"Euro-House",
	"Dance Hall",
};

genre(id: int): string
{
	if(id >= 0 && id < len genres)
		return genres[id];
	return nil;
}

Mp3tag.unpack(d: array of byte): (ref Mp3tag, string)
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	if(len d != 128)
		return (nil, "data not 128 bytes");

	tag := string d[:3];
	if(tag != "TAG")
		return (nil, "no tag");
	title := string d[Titleoff:Artistoff];
	artist := string d[Artistoff:Albumoff];
	album := string d[Albumoff:Yearoff];
	year := string d[Yearoff:Commentoff];
	comment := string d[Commentoff:Trackoff];
	track := int d[Trackoff]<<8 | int d[Trackoff+1];
	genre := int d[Genreoff];
	return (ref Mp3tag(S(title), S(artist), S(album), S(year), S(comment), track, genre), nil);
}

S(s: string): string
{
	if(str == nil)
		str = load String String->PATH;
	while(s != nil && str->in(s[len s-1], " \t\n\r"))
		s = s[:len s-1];
	return s;
}

Mp3tag.read(file: string): (ref Mp3tag, string)
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	fd := sys->open(file, Sys->OREAD);
	if(fd == nil)
		return (nil, sprint("open: %r"));
	sys->seek(fd, big -128, Sys->SEEKEND);
	n := sys->read(fd, d := array[128] of byte, len d);
	if(n < 0)
		return (nil, sprint("reading tag: %r"));
	if(n != len d)
		return (nil, "short read on tag");
	return Mp3tag.unpack(d);
}
