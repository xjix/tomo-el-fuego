# This is free and unencumbered software released into the public domain.
# see /lib/legal/UNLICENSE
implement Bittorrent;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
include "keyring.m";
	kr: Keyring;
include "security.m";
	random: Random;
include "rand.m";
	rand: Rand;
include "tables.m";
	tables: Tables;
	Strhash: import tables;
include "ip.m";
	ip: IP;
	IPaddr: import ip;
include "filter.m";
include "mhttp.m";
	http: Http;
	Url: import http;
include "bitarray.m";
	bitarray: Bitarray;
	Bits: import bitarray;
include "bittorrent.m";
include "util0.m";
	util: Util0;
	warn, rev, pid, kill, l2a, hex, index, strip, readfile, preadn, g32i, p32i, g16, suffix, prefix, join, hasstr: import util;
include "dial.m";
    dial: Dial;

dflag = 0;
version: con 0;
Peeridlen: con 20;

init()
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	random = load Random Random->PATH;
	rand = load Rand Rand->PATH;
	rand->init(sys->millisec()^sys->pctl(0, nil));
	kr = load Keyring Keyring->PATH;
	bufio = load Bufio Bufio->PATH;
	tables = load Tables Tables->PATH;
	ip = load IP IP->PATH;
	ip->init();
	http = load Http Http->PATH;
	http->init(bufio);
	bitarray = load Bitarray Bitarray->PATH;
	util = load Util0 Util0->PATH;
	util->init();
    dial = load Dial Dial->PATH;
}

Bee.find(bb: self ref Bee, s: string): ref Bee
{
	a := array of byte s;
	pick b := bb {
	Dict =>
		for(i := 0; i < len b.a; i++)
			if(len a == len b.a[i].t0.a && string b.a[i].t0.a == s)
				return b.a[i].t1;
	};
	return nil;
}

Bee.pack(b: self ref Bee): array of byte
{
	n := b.packedsize();
	a := array[n] of byte;
	m := beepack(b, a, 0);
	if(n != m)
		raise "internal error packing bee structure";
	return a;
}

Bee.packedsize(bb: self ref Bee): int
{
	pick b := bb {
	String =>
		n := len b.a;
		return (len string n)+1+n;
	Integer =>
		return 1+(len string b.i)+1;
	List =>
		n := 1;
		for(i := 0; i < len b.a; i++)
			n += b.a[i].packedsize();
		n += 1;
		return n;
	Dict =>
		n := 1;
		for(i := 0; i < len b.a; i++) {
			n += b.a[i].t0.packedsize();
			n += b.a[i].t1.packedsize();
		}
		n += 1;
		return n;
	}
}

beepack(bb: ref Bee, d: array of byte, i: int): int
{
	begin := i;
	pick b := bb {
	String =>
		na := array of byte string len b.a;
		d[i:] = na;
		i += len na;
		d[i] = byte ':';
		i++;
		d[i:] = b.a;
		i += len b.a;
	Integer =>
		a := array of byte string b.i;
		d[i] = byte 'i';
		i++;
		d[i:] = a;
		i += len a;
		d[i] = byte 'e';
		i++;
	List =>
		d[i] = byte 'l';
		i++;
		for(j := 0; j < len b.a; j++)
			i += beepack(b.a[j], d, i);
		d[i] = byte 'e';
		i++;
	Dict =>
		d[i] = byte 'd';
		i++;
		for(j := 0; j < len b.a; j++) {
			i += beepack(b.a[j].t0, d, i);
			i += beepack(b.a[j].t1, d, i);
		}
		d[i] = byte 'e';
		i++;
	}
	return i-begin;
}

Bee.unpack(d: array of byte): (ref Bee, string)
{
	(b, n, err) := beeunpack(d, 0);
	if(err != nil)
		return (nil, err+" (at offset "+string n+")");
	if(n != len d)
		return (nil, sprint("%d bytes left after parsing", len d-n));
	return (b, nil);
}

beeunpack(d: array of byte, o: int): (ref Bee, int, string)
{
	if(o >= len d)
		return (nil, o, "premature end");

	case int d[o] {
	'i' =>
		e := o+1;
		if(d[e] == byte '-')
			e++;
		while(e+1 < len d && d[e] >= byte '0' && d[e] <= byte '9')
			e++;
		if(e == len d)
			return (nil, o, "bad integer, missing end");
		if(d[e] != byte 'e')
			return (nil, o, "bad integer, bad end");
		s := string d[o+1:e];
		if(s == "-0" || s == "" || len s > 1 && s[0] == '0')
			return (nil, o, "bad integer, bad value");
		return (ref Bee.Integer(big s), e+1, nil);
	
	'l' =>
		a := array[0] of ref Bee;
		e := o+1;
		for(;;) {
			if(e >= len d)
				return (nil, o, "bad list, missing end");
			if(d[e] == byte 'e') {
				e++;
				break;
			}
			(b, ne, err) := beeunpack(d, e);
			if(err != nil)
				return (nil, o, err);
			e = ne;
			na := array[len a+1] of ref Bee;
			na[:] = a;
			na[len a] = b;
			a = na;
		}
		return (ref Bee.List(a), e, nil);

	'd' =>
		a := array[0] of (ref Bee.String, ref Bee);
		e := o+1;
		for(;;) {
			if(e >= len d)
				return (nil, o, "bad dict, missing end");
			if(d[e] == byte 'e') {
				e++;
				break;
			}
			
			(bb, ne, err) := beeunpack(d, e);
			if(err != nil)
				return (nil, o, err);
			e = ne;
			key: ref Bee.String;
			pick b := bb {
			String =>
				key = b;
			* =>
				return (nil, o, "bad dict, non-string as key");
			}
			(bb, e, err) = beeunpack(d, e);
			if(err != nil)
				return (nil, o, err);

			na := array[len a+1] of (ref Bee.String, ref Bee);
			na[:] = a;
			na[len a] = (key, bb);
			a = na;
		}
		return (ref Bee.Dict(a), e, nil);
		
	'0' to '9' =>
		e := o+1;
		while(e+1 < len d && d[e] >= byte '0' && d[e] <= byte '9')
			e++;
		if(e >= len d)
			return (nil, o, "bad string, missing end");
		if(d[e] != byte ':')
			return (nil, o, "bad string, bad end");
		n := int string d[o:e];
		if(e+1+n > len d)
			return (nil, o, "bad string, bad length");
		return (ref Bee.String(d[e+1:e+1+n]), e+1+n, nil);

	* =>
		return (nil, o, sprint("bad structure type %c (%#x)", int d[o], int d[o]));
	}
}

Bee.get(b: self ref Bee, l: list of string): ref Bee
{
	for(; b != nil && l != nil; l = tl l)
		b = b.find(hd l);
	return b;
}

Bee.gets(b: self ref Bee, l: list of string): ref Bee.String
{
	nb := b.get(l);
	if(nb == nil)
		return nil;
	pick bb := nb {
	String =>	return bb;
	* =>		return nil;
	}
}

Bee.geti(b: self ref Bee, l: list of string): ref Bee.Integer
{
	nb := b.get(l);
	if(nb == nil)
		return nil;
	pick bb := nb {
	Integer =>	return bb;
	* =>		return nil;
	}
}

Bee.getl(b: self ref Bee, l: list of string): ref Bee.List
{
	nb := b.get(l);
	if(nb == nil)
		return nil;
	pick bb := nb {
	List =>	return bb;
	* =>		return nil;
	}
}

Bee.getd(b: self ref Bee, l: list of string): ref Bee.Dict
{
	nb := b.get(l);
	if(nb == nil)
		return nil;
	pick bb := nb {
	Dict =>		return bb;
	* =>		return nil;
	}
}

beestr(s: string): ref Bee.String
{
	return ref Bee.String (array of byte s);
}

beebytes(d: array of byte): ref Bee.String
{
	return ref Bee.String (d);
}

beelist(l: list of ref Bee): ref Bee.List
{
	a := array[len l] of ref Bee;
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return ref Bee.List (a);
}

beeint(i: int): ref Bee.Integer
{
	return ref Bee.Integer (big i);
}

beebig(i: big): ref Bee.Integer
{
	return ref Bee.Integer (i);
}

beekey(s: string, b: ref Bee): (ref Bee.String, ref Bee)
{
	return (beestr(s), b);
}

beedict(l: list of (ref Bee.String, ref Bee)): ref Bee.Dict
{
	a := array[len l] of (ref Bee.String, ref Bee);
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return ref Bee.Dict (a);
}


MChoke, MUnchoke, MInterested, MNotinterested, MHave, MBitfield, MRequest, MPiece, MCancel:	con iota;
MLast:	con MCancel;

tag2type := array[] of {
tagof Msg.Choke =>	MChoke,
tagof Msg.Unchoke =>	MUnchoke,
tagof Msg.Interested =>	MInterested,
tagof Msg.Notinterested =>	MNotinterested,
tagof Msg.Have =>	MHave,
tagof Msg.Bitfield =>	MBitfield,
tagof Msg.Request =>	MRequest,
tagof Msg.Piece =>	MPiece,
tagof Msg.Cancel =>	MCancel,
};

tag2string := array[] of {
tagof Msg.Keepalive =>	"keepalive",
tagof Msg.Choke =>	"choke",
tagof Msg.Unchoke =>	"unchoke",
tagof Msg.Interested =>	"interested",
tagof Msg.Notinterested =>	"notinterested",
tagof Msg.Have =>	"have",
tagof Msg.Bitfield =>	"bitfield",
tagof Msg.Request =>	"request",
tagof Msg.Piece =>	"piece",
tagof Msg.Cancel =>	"cancel",
};

msizes := array[] of {
MChoke =>	1,
MUnchoke =>	1,
MInterested =>	1,
MNotinterested =>	1,
MHave =>	1+4,
MBitfield =>	1,	# +payload
MRequest =>	1+3*4,
MPiece =>	1+2*4,	# +payload
MCancel =>	1+3*4,
};

Msg.packedsize(mm: self ref Msg): int
{
	if(tagof mm == tagof Msg.Keepalive)
		return 4;
	msize := msizes[tag2type[tagof mm]];
	pick m := mm {
	Bitfield =>	msize += len m.d;
	Piece =>	msize += len m.d;
	}
	return 4+msize;
}

Msg.pack(mm: self ref Msg): array of byte
{
	msize := mm.packedsize();
	d := array[msize] of byte;
	mm.packbuf(d);
	return d;
}

Msg.packbuf(mm: self ref Msg, d: array of byte)
{
	msize := len d;
	i := p32i(d, 0, msize-4);

	if(tagof mm == tagof Msg.Keepalive)
		return;

	t := tag2type[tagof mm];
	d[i++] = byte t;

	pick m := mm {
	Choke or
	Unchoke or
	Interested or
	Notinterested =>
	Have =>
		i = p32i(d, i, m.index);
	Bitfield =>
		d[i:] = m.d;
		i += len m.d;
	Piece =>
		i = p32i(d, i, m.index);
		i = p32i(d, i, m.begin);
		d[i:] = m.d;
		i += len m.d;
	Request or
	Cancel =>
		i = p32i(d, i, m.index);
		i = p32i(d, i, m.begin);
		i = p32i(d, i, m.length);
	* =>
		raise "bad message type";
	};
	if(i != len d)
		raise "Msg.pack internal error";
}

Msg.unpack(d: array of byte): (ref Msg, string)
{
	if(len d == 0)
		return (ref Msg.Keepalive(), nil);
	if(int d[0] > MLast)
		return (nil, sprint("bad message, unknown type %d", int d[0]));

	msize := msizes[int d[0]];
	if(len d < msize)
		return (nil, "bad message, too short");

	i := 1;
	m: ref Msg;
	case int d[0] {
	MChoke =>	m = ref Msg.Choke();
	MUnchoke =>	m = ref Msg.Unchoke();
	MInterested =>	m = ref Msg.Interested();
	MNotinterested =>	m = ref Msg.Notinterested();
	MHave =>
		index: int;
		(index, i) = g32i(d, i);
		m = ref Msg.Have(index);
	MBitfield =>
		nd := array[len d-i] of byte;
		nd[:] = d[i:];
		i += len nd;
		m = ref Msg.Bitfield(nd);
		# xxx verify that bitfield has correct length?
	MPiece =>
		index, begin: int;
		(index, i) = g32i(d, i);
		(begin, i) = g32i(d, i);
		nd := array[len d-i] of byte;
		nd[:] = d[i:];
		i += len nd;
		m = ref Msg.Piece(index, begin, nd);
		# xxx verify that piece has right size?
	MRequest or
	MCancel =>
		index, begin, length: int;
		(index, i) = g32i(d, i);
		(begin, i) = g32i(d, i);
		(length, i) = g32i(d, i);
		if(int d[0] == MRequest)
			m = ref Msg.Request(index, begin, length);
		else
			m = ref Msg.Cancel(index, begin, length);
	}
	if(i != len d)
		return (nil, "bad message, leftover data");
	return (m, nil);
}

Msg.read(fd: ref Sys->FD): (ref Msg, string)
{
	buf := array[4] of byte;
	n := sys->readn(fd, buf, len buf);
	if(n < 0)
		return (nil, sprint("reading: %r"));
	if(n < len buf)
		return (nil, sprint("short read"));
	(size, nil) := g32i(buf, 0);
	buf = array[size] of byte;

	n = sys->readn(fd, buf, len buf);
	if(n < 0)
		return (nil, sprint("reading: %r"));
	if(n < len buf)
		return (nil, sprint("short read"));

	return Msg.unpack(buf);
}

Msg.text(mm: self ref Msg): string
{
	s := tag2string[tagof mm];
	pick m := mm {
	Have =>		s += sprint(" index=%d", m.index);
	Bitfield =>	; # xxx show bitfield...?
	Piece =>	s += sprint(" index=%d begin=%d length=%d", m.index, m.begin, len m.d);
	Request or
	Cancel =>	s += sprint(" index=%d begin=%d length=%d", m.index, m.begin, m.length);
	}
	return s;
}

encode(a: array of byte, verbatim: string): string
{
	s := "";
	for(i := 0; i < len a; i++)
		if(str->in(int a[i], verbatim))
			s[len s] = int a[i];
		else
			s += sprint("%%%02x", int a[i]);
	return s;
}


sanitizepath(s: string): string
{
	s = strip(s, "/");
	if(prefix("../", s) || suffix("/..", s) || s == "..")
		return nil;
	if(str->splitstrl(s, "/../").t1 != nil)
		return nil;
	return s;
}

foldpath(l: list of string): string
{
	path := "";
	if(l == nil)
		return nil;
	for(; l != nil; l = tl l)
		if(hd l == ".." || hd l == "" || index("/", hd l) >= 0)
			return nil;
		else
			path += "/"+hd l;
	return path[1:];
}

getint(b: ref Bee, k: string, def: int): int
{
	bb := b.geti(k::nil);
	if(bb == nil)
		return def;
	return int bb.i;
}

getstr(b: ref Bee, k: string, def: string): string
{
	bb := b.gets(k::nil);
	if(bb == nil)
		return def;
	return string bb.a;
}

checktrackurl(s: string): string
{
	(nil, err) := Url.unpack(s);
	return err;
}

Torrent.open(path: string): (ref Torrent, string)
{
	d := readfile(path, -1);
	if(d == nil)
		return (nil, sprint("%r"));

	(b, err) := Bee.unpack(d);
	if(err != nil)
		return (nil, sprint("parsing %s: %s", path, err));

	bannoun := b.gets("announce"::nil);
	if(bannoun == nil)
		return (nil, sprint("%s: missing/bad announce field", path));
	err = checktrackurl(string bannoun.a);
	if(err != nil)
		return (nil, sprint("%s: bad tracker %#q: %s", path, string bannoun.a, err));

	announces: array of array of string;
	al := b.get("announce-list"::nil);
	if(al != nil)
	pick a := al {
	List =>
		announces = array[len a.a] of array of string;
		for(i := 0; i < len a.a; i++)
			pick l := a.a[i] {
			List =>
				announces[i] = array[len l.a] of string;
				for(j := 0; j < len l.a; j++)
					pick s := l.a[j] {
					String =>
						url := announces[i][j] = string s.a;
						err = checktrackurl(url);
						if(err != nil)
							return (nil, sprint("%s: bad tracker %#q: %s", path, url, err));
					* =>
						return (nil, sprint("%s: bad type in list in announce-list", path));
					}
				randomize(announces[i]);
			* =>
				return (nil, sprint("%s: bad list in announce-list", path));
			}
	* =>
		return (nil, sprint("%s: bad type for announce-list", path));
	}

	binfo := b.get("info"::nil);
	if(binfo == nil)
		return (nil, sprint("%s: missing/bad info field", path));
	bd := binfo.pack();
	infohash := array[kr->SHA1dlen] of byte;
	kr->sha1(bd, len bd, infohash, nil);

	bpiecelen := binfo.geti("piece length"::nil);
	if(bpiecelen == nil)
		return (nil, sprint("%s: missing/bad 'piece length' field", path));
	piecelen := int bpiecelen.i;


	bpieces := binfo.gets("pieces"::nil);
	if(bpieces == nil)
		return (nil, sprint("%s: missing/bad field 'pieces' in 'info'", path));
	if(len bpieces.a % 20 != 0)
		return (nil, sprint("%s: bad length of 'pieces', not multiple of hash size", path));

	pieces := array[len bpieces.a/20] of array of byte;
	i := 0;
	for(o := 0; o < len bpieces.a; o += 20)
		pieces[i++] = bpieces.a[o:o+20];


	# file name, or dir name for files in case of multi-file torrent
	bname := binfo.gets("name"::nil);
	if(bname == nil)
		return (nil, "missing/bad destination file name");
	name := sanitizepath(string bname.a);
	if(name == nil)
		return (nil, sprint("weird name, refusing to create %#q", name));

	# determine paths for files, and total length
	length := big 0;
	blength := binfo.geti("length"::nil);
	files: array of ref File;
	if(blength != nil) {
		length = blength.i;
		files = array[] of {ref File (name, length)};
	} else {
		bfiles := binfo.getl("files"::nil);
		if(bfiles == nil)
			return (nil, sprint("%s: missing/bad field 'length' or 'files' in 'info'", path));
		if(len bfiles.a == 0)
			return (nil, sprint("%s: no files in torrent", path));
		files = array[len bfiles.a] of ref File;
		length = big 0;
		for(i = 0; i < len bfiles.a; i++) {
			blen := bfiles.a[i].geti("length"::nil);
			if(blen == nil)
				return (nil, sprint("%s: missing/bad field 'length' in 'files[%d]' in 'info'", path, i));
			files[i] = f := ref File;
			f.length = blen.i;

			pathl := bfiles.a[i].getl("path"::nil);
			if(pathl == nil)
				return (nil, sprint("missing/bad or invalid 'path' for file"));
			pathls: list of string;
			for(j := len pathl.a-1; j >= 0; j--)
				pick e := pathl.a[j] {
				String =>
					pathls = string e.a::pathls;
				* =>
					return (nil, sprint("bad type for element of 'path' for file"));
				}
			f.path = foldpath(name::pathls);
			if(f.path == nil)
				return (nil, sprint("weird path, refusing to create: %q", join(pathls, "/")));
			length += f.length;
		}
	}
	private := getint(b, "private", 0);
	createdby := getstr(b, "created by", "");
	createtime := getint(b, "creation date", 0);
	t := ref Torrent (string bannoun.a, announces, piecelen, infohash, len pieces, pieces, files, name, length, private, createdby, createtime);
	return (t, nil);
}

Torrent.piecelength(t: self ref Torrent, index: int): int
{
	piecelen := t.piecelen;
	if(index+1 == t.piececount) {
		piecelen = int (t.length % big t.piecelen);
		if(piecelen == 0)
			piecelen = t.piecelen;
	}
	return piecelen;
}

Torrent.pack(t: self ref Torrent): array of byte
{
	if(t.files == nil)
		raise "cannot make empty torrent";

	piecelen := beekey("piece length", beeint(t.piecelen));

	hashes := array[kr->SHA1dlen*len t.hashes] of byte;
	for(i := 0; i < len t.hashes; i++)
		hashes[i*kr->SHA1dlen:] = t.hashes[i];
	pieces := beekey("pieces", beebytes(hashes));

	info: ref Bee.Dict;
	if(len t.files == 1) {
		f := t.files[0];
		path := str->splitstrr(f.path, "/").t1;
		name := beekey("name", beestr(path));
		length := beekey("length", beebig(f.length));
		info = beedict(list of {name, length, piecelen, pieces});
	} else {
		name := beekey("name", beestr(t.name));
		fl: list of ref Bee.Dict;
		for(i = 0; i < len t.files; i++) {
			f := t.files[i];
			elems: list of ref Bee.String;
			for(e := sys->tokenize(f.path, "/").t1; e != nil; e = tl e)
				elems = beestr(hd e)::elems;
			elems = rev(elems);
			path := beekey("path", beelist(elems));
			length := beekey("length", beebig(f.length));
			fd := beedict(list of {length, path});
			fl = fd::fl;
		}
		files := beekey("files", beelist(rev(fl)));
		info = beedict(list of {name, files, piecelen, pieces});
	}

	bannounces: ref Bee.List;
	if(t.announces != nil) {
		l: list of ref Bee;
		for(i = 0; i < len t.announces; i++) {
			ll: list of ref Bee;
			for(j := 0; j < len t.announces[i]; j++)
				ll = beestr(t.announces[i][j])::ll;
			tier := beelist(rev(ll));
			l = tier::l;
		}
		bannounces = beelist(rev(l));
	}

	l := beekey("info", info)::nil;
	if(bannounces != nil)
		l = beekey("announce-list", bannounces)::l;
	l = beekey("announce", beestr(t.announce))::l;
	b := beedict(l);
	return b.pack();
}

mkdirs(elems: list of string): string
{
	if(elems == nil)
		return nil;

	path := ".";
	for(; elems != nil; elems = tl elems) {
		path += "/"+hd elems;
		(ok, dir) := sys->stat(path);
		if(ok == 0) {
			if(dir.mode & Sys->DMDIR)
				continue;
			return sprint("existing %q should be a directory but it is not", path);
		}
		fd := sys->create(path, Sys->OREAD, 8r777|Sys->DMDIR);
		if(fd == nil)
			return sprint("creating %q: %r", path);
	}
	return nil;
}

filename(f: ref File, nofix: int): string
{
	if(nofix)
		return f.path;
	return simplepath(f.path);
}

Torrentx.open(t: ref Torrent, tpath: string, nofix, nocreate: int): (ref Torrentx, int, string)
{
	statepath := str->splitstrr(tpath, "/").t1+".state";
	tx := ref Torrentx (t, array[len t.files] of ref Filex, statepath, nil);

	# attempt to open paths as existing files, and ensure they are unique
	names := Strhash[string].new(32, nil);
	opens: list of string;
	offset := big 0;
	for(i := 0; i < len t.files; i++) {
		f := t.files[i];
		path := filename(f, nofix);
		if(names.find(path) != nil)
			return (nil, 0, "duplicate path: "+path);
		names.add(path, path);

		fd := sys->open("./"+path, Sys->ORDWR);
		if(fd != nil) {
			(ok, dir) := sys->fstat(fd);
			if(ok != 0)
				return (nil, 0, sprint("fstat %s: %r", path));
			if(dir.length != f.length)
				return (nil, 0, sprint("%s: length of existing file is %bd, torrent says %bd", path, dir.length, f.length));
			opens = path::opens;
			say(sprint("opened %q", path));
		}
		pfirst := offset/big t.piecelen;
		pend := (offset+f.length+big (t.piecelen-1))/big t.piecelen;
		tx.files[i] = ref Filex (f, i, path, fd, offset, int pfirst, int pend-1);
		offset += f.length;
	}
	names = nil;
	if(len opens == len t.files)
		return (tx, 0, nil);
	if(len opens != 0)
		return (nil, 0, sprint("%s: already exists", hd opens));
	if(nocreate)
		return (nil, 0, nil); 

	# none could be opened, create paths as new files
	offset = big 0;
	for(i = 0; i < len t.files; i++) {
		fx := tx.files[i];
		(nil, elems) := sys->tokenize(fx.path, "/");
		err := mkdirs(rev(tl rev(elems)));
		if(err != nil)
			return (nil, 0, err);
		fx.fd = sys->create("./"+fx.path, Sys->ORDWR, 8r666);
		if(fx.fd == nil)
			return (nil, 0, sprint("create %s: %r", fx.path));
		dir := sys->nulldir;
		dir.length = fx.f.length;
		if(sys->fwstat(fx.fd, dir) != 0)
			return (nil, 0, sprint("fwstat file size %s: %r", fx.path));
		say(sprint("created %q", fx.path));
	}
	return (tx, 1, nil);
}

Torrentx.blockread(tx: self ref Torrentx, index, begin, length: int): (array of byte, string)
{
	buf := array[length] of byte;
	return (buf, tx.preadx(buf, len buf, big index*big tx.t.piecelen+big begin));
}

Torrentx.pieceread(tx: self ref Torrentx, index: int): (array of byte, string)
{
	buf := array[tx.t.piecelength(index)] of byte;
	return (buf, tx.preadx(buf, len buf, big index*big tx.t.piecelen));
}

Torrentx.piecewrite(tx: self ref Torrentx, index: int, buf: array of byte): string
{
	return tx.pwritex(buf, tx.t.piecelen, big index*big tx.t.piecelen);
}

iox(tx: ref Torrentx, buf: array of byte, n: int, off: big, read: int): string
{
	for(i := 0; n > 0 && i < len tx.files; i++) {
		f := tx.files[i];
		size := f.f.length;
		if(size <= off) {
			off -= size;
			continue;
		}

		want := n;
		if(size < off+big n)
			want = int (size-off);
		nn: int;
say(sprint("iox, read %d, n %d, off %bd", read, want, off));
		if(read)
			nn = preadn(f.fd, buf, want, off);
		else
			nn = sys->pwrite(f.fd, buf, want, off);
		if(read && nn >= 0 && nn < want)
			return sprint("short read (%r)");
		if(nn < 0) {
			if(read)
				return sprint("read: %r");
			return sprint("write: %r");
		}
		n -= nn;
		buf = buf[nn:];
		off = big 0;
	}
	if(n != 0)
		return sprint("leftover %d bytes", n);
	return nil;
}

Torrentx.preadx(tx: self ref Torrentx, buf: array of byte, n: int, off: big): string
{
	return iox(tx, buf, n, off, 1);
}

Torrentx.pwritex(tx: self ref Torrentx, buf: array of byte, n: int, off: big): string
{
	return iox(tx, buf, n, off, 0);
}

reader(tx: ref Torrentx, c: chan of (array of byte, string))
{
	piecelen := tx.t.piecelen;
	have := 0;
	buf := array[piecelen] of byte;

	for(i := 0; i < len tx.files; i++) {
		f := tx.files[i];
		size := f.f.length;
		o := big 0;
		while(o < size) {
			want := piecelen-have;
			if(size-o < big want)
				want = int (size-o);
			nn := preadn(f.fd, buf[have:], want, o);
			if(nn <= 0) {
				c <-= (nil, sprint("reading: %r"));
				return;
			}
			have += nn;
			o += big nn;
			if(have == piecelen) {
				c <-= (buf, nil);
				buf = array[piecelen] of byte;
				have = 0;
			}
		}
	}
	if(have != 0)
		c <-= (buf[:have], nil);
}

torrenthash(tx: ref Torrentx, haves: ref Bits): string
{
	spawn reader(tx, c := chan[2] of (array of byte, string));
	for(i := 0; i < len tx.t.hashes; i++) {
		(buf, err) := <-c;
		if(err != nil)
			return err;
		if(hex(sha1(buf)) == hex(tx.t.hashes[i]))
			haves.set(i);
	}
	return nil;
}


trackerget(tr: ref Trackreq): (ref Track, string)
{
	{
		return (trackerget0(tr), nil);
	} exception e {
	"track:*" =>
		return (nil, e[len "track:":]);
	}
}

trackerror(s: string)
{
	raise "track:"+s;
}

trackerget0(tr: ref Trackreq): ref Track
{
	if(tr.left < big 0)
		trackerror(sprint("bogus negative 'left' %bd", tr.left));

	if(tr.t.announces == nil) {
		say(sprint("trying single announce url %q", tr.t.announce));
		return trackerget00(tr, tr.t.announce);
	}

	lasterror: string;
	n := 0;
	for(i := 0; i < len tr.t.announces; i++) {
		tier := tr.t.announces[i];
		for(j := 0; j < len tier; j++) {
			{
				n++;
				url := tier[j];
				say(sprint("trying %q, tier %d, elem %d", url, i, j));
				r := trackerget00(tr, url);
				tier[1:] = tier[:j];
				tier[0] = url;
				return r;
			} exception e {
			"track:*" =>
				say(e);
				lasterror = e[len "track:":];
			}
		}
	}
	trackerror(sprint("all %d trackers failed, last error: %s", n, lasterror));
	return nil;
}

trackerget00(tr: ref Trackreq, u: string): ref Track
{
	(url, err) := Url.unpack(u);
	if(err != nil)
		trackerror("parsing announce url: "+err);

	case url.scheme {
	"udp" =>
		return trackergetudp(tr, u, url);
	"http" or
	"https" =>
		return trackergethttp(tr, u, url);
	}
	trackerror(sprint("url scheme %#q not supported", url.scheme));
	return nil;
}

unpackint(b: array of byte, l: int): int
{
    d := 0;

    for ( i := 0; i < l; i ++ )
        d += (int b[l - i - 1]) << (i * 8);

    return d;
}

unpack16i(b: array of byte): int { return unpackint(b, 2); }
unpack32i(b: array of byte): int { return unpackint(b, 4); }

packint(d, l: int): array of byte
{
    a := array[l] of byte;

    for ( i := 0; i < l; i ++ )
        a[i] = byte ((d >> ((l * 8 - 8) - (8 * i))) & 255);

    return a;
}

pack16i(d: int): array of byte { return packint(d, 2); }
pack32i(d: int): array of byte { return packint(d, 4); }

pack64i(d: big): array of byte
{
    a := array[8] of byte;

    for ( i := 0; i < 8; i ++ )
        a[i] = byte ((d >> (56 - (8 * i))) & big 255);

    return a;
}

fillbytes(sstart, dstart, length: int, src, dst: array of byte)
{
    for ( i := 0; i < length; i ++ )
        dst[dstart + i] = src[sstart + i];
}

trackergetudp(tr: ref Trackreq, u: string, url: ref Url): ref Track
{
    # UDP support based on udp tracker protocol spec at:
    #   http://www.bittorrent.org/beps/bep_0015.html
    #   http://www.rasterbar.com/products/libtorrent/udp_tracker_protocol.html

    say(sprint("trackergetudp, url %q", url.pack()));
    
    spawn trackergetudp0(tr, u, url, pidc := chan of int, kpidc := chan of int, rc := chan of (ref Track, string));

    # udp tracker protocol specifies a (15 * request number) backoff for re-transmitting messages... so we can re-use
    # the http tracker killer function, which simply kills the tracker comm process after 15 seconds with a timeout err
    spawn killer(pidc, kpidc, rc);

    (r, err) := <-rc;
    if (err != nil)
        trackerror(err);

    return r;
}

ipntos(ip: int): string
{
    # There's probably a builtin function for this... somewhere... but searching through inferno/limbo man pages, blindly,
    # is questionable at best and I didn't wanna spend too much time just looking for it when writing a simple function
    # would be faster... if anyone knows a better way/existing function to use, please let me know! -sandbender

    o := array[4] of int;

    o[0] = (int (ip / 16777216)) % 256;
    o[1] = (int (ip / 65536)) % 256;
    o[2] = (int (ip / 256)) % 256;
    o[3] = (int ip) % 256;

    return sprint("%d.%d.%d.%d", o[0], o[1], o[2], o[3]);
}

trackergetudp0(tr: ref Trackreq, u: string, url: ref Url, pidc: chan of int, kpidc: chan of int, rc: chan of (ref Track, string))
{
    # Not the cleanest or DRYest function I've ever written... but once again, I was going for speed of implementation here
    # and NOT elegance... ie: I wanted to use this to d/l UDP-tracker-based torrents ;) This code should be pretty stable, just
    # ugly :D -sandbender

    pidc <-= pid();
    kpid := <-kpidc;
    {
        txid := random->randombuf(Random->ReallyRandom, 4);

        # connect request...
        reqstruct := array[16] of byte;

        fillbytes(0, 0, 8, pack64i(16r41727101980), reqstruct);   # udp protocol identifier
        fillbytes(0, 8, 4, pack32i(0), reqstruct);   # 0 == connect action
        fillbytes(0, 12, 4, txid, reqstruct);

        # 'connect' to udp tracker...
        cn := dial->dial(sprint("udp!%s!%s", url.host, url.port), "");
        if (cn == nil)
            trackerror(sprint("Could not connect to UDP host %s:%s", url.host, url.port));

        # send the connect request
        if ( 16 != sys->write(cn.dfd, reqstruct, 16) )
            trackerror("Problem sending 'connect' udp datagram!");

        # parse response
        res := array[16] of byte;
        if ( 16 != sys->read(cn.dfd, res, 16) )
            trackerror("Problem - 'connect' response too small/broken!");

        if ( 0 != unpack32i(res[0:4]) )
            trackerror("Problem - 'connect' response has wrong action type!");

        if ( unpack32i(txid) != unpack32i(res[4:8]) )
            trackerror("Problem - 'connect' response has wrong txid!");

        cxid := res[8:];

        # announce request...
        annstruct := array[98] of byte;
        txid = random->randombuf(Random->ReallyRandom, 4);

        fillbytes(0, 0, 8, cxid, annstruct);
        fillbytes(0, 8, 4, pack32i(1), annstruct);   # 1 == announce action
        fillbytes(0, 12, 4, txid, annstruct);
        fillbytes(0, 16, 20, tr.t.infohash, annstruct);
        fillbytes(0, 36, 20, tr.peerid, annstruct);
        fillbytes(0, 56, 8, pack64i(tr.down), annstruct);
        fillbytes(0, 64, 8, pack64i(tr.left), annstruct);
        fillbytes(0, 72, 8, pack64i(tr.up), annstruct);

        if (tr.event != nil) {
            case tr.event {
                "completed" =>
                    fillbytes(0, 80, 4, pack32i(1), annstruct);
                "started" =>
                    fillbytes(0, 80, 4, pack32i(2), annstruct);
                "stopped" =>
                    fillbytes(0, 80, 4, pack32i(3), annstruct);
                * =>
                    fillbytes(0, 80, 4, pack32i(0), annstruct);
            }
        } else
            fillbytes(0, 80, 4, pack32i(0), annstruct);   # event default 0

        fillbytes(0, 84, 4, pack32i(0), annstruct);   # ip address... 0 == origin
        fillbytes(0, 88, 4, array of byte tr.key, annstruct);
        fillbytes(0, 92, 4, pack32i(200), annstruct);
        fillbytes(0, 96, 2, pack16i(tr.lport), annstruct);

        # send the announce request...
        sent := sys->write(cn.dfd, annstruct, 98);
        if ( 98 != sent )
            trackerror(sprint("Problem sending 'announce' udp datagram! %d", sent));

        # parse response
        res2 := array[2048] of byte;   # Grab biggest UDP packet we can... highly unlikely that anyone's MTU is bigger than this
        announce_read := sys->read(cn.dfd, res2, 2048);
        if ( 20 > announce_read )
            trackerror("Not enough data came back from announce request!");

        if ( 1 != unpack32i(res2[0:4]) )
            trackerror("Bad action type in response to announce request!");

        if ( unpack32i(txid) != unpack32i(res2[4:8]) )
            trackerror("Bad txid in announce response!");

        interval := unpack32i(res2[8:12]);
        leechers := unpack32i(res2[12:16]);
        seeders := unpack32i(res2[16:20]);

        num_to_track := announce_read - 20;   # bytes left for peer info
        num_to_track = num_to_track - (num_to_track % 6);   # ignore final incomplete peer info if present
        num_to_track = num_to_track / 6;  # 6 bytes / peer

        peers := array[num_to_track] of Trackpeer;

        pres := array[6] of byte;
        for ( i := 0; i < num_to_track; i ++ ) {
            fillbytes(20 + (i * 6), 0, 6, res2, pres);

            tp: Trackpeer;

            tp.ip = ipntos(unpack32i(pres[0:4]));
            tp.port = unpack16i(pres[4:6]);

            peers[i] = tp;
        }

        kill(kpid);
        rc <-= (ref Track(interval, interval, peers, u, nil), nil);

    } exception e {
        "*" =>
            rc <-= (nil, sprint("udp tracker error: %s", e));
    }
}

killer(pidc, kpidc: chan of int, rc: chan of (ref Track, string))
{
	opid := <-pidc;
	kpidc <-= pid();
	sys->sleep(15*1000);
	kill(opid);
	rc <-= (nil, "timeout");
}

trackergethttp(tr: ref Trackreq, u: string, url: ref Url): ref Track
{
	say(sprint("trackergethttp, url %q", url.pack()));
	spawn trackergethttp0(tr, u, url, pidc := chan of int, kpidc := chan of int, rc := chan of (ref Track, string));
	spawn killer(pidc, kpidc, rc);
	(r, err) := <-rc;
	if(err != nil)
		trackerror(err);
	return r;
}

trackergethttp0(tr: ref Trackreq, u: string, url: ref Url, pidc, kpidc: chan of int, rc: chan of (ref Track, string))
{
	pidc <-= pid();
	kpid := <-kpidc;
	{
		r := trackergethttp00(tr, u, url);
		kill(kpid);
		rc <-= (r, nil);
	} exception e {
	"track:*" =>
		rc <-= (nil, e[len "track:":]);
	}
}

trackergethttp00(tr: ref Trackreq, u: string, url: ref Url): ref Track
{
	s := "";
	s += "&info_hash="+encode(tr.t.infohash, nil);
	s += "&peer_id="+encode(tr.peerid, "a-zA-Z0-9-");
	s += sprint("&port=%d", tr.lport);
	s += sprint("&uploaded=%bd", tr.up);
	s += sprint("&downloaded=%bd", tr.down);
	s += sprint("&left=%bd", tr.left);
	s += "&compact=1";
	s += "&numwant=200";
	s += "&no_peer_id=1";
	if(tr.key != nil)
		s += "&key="+tr.key;
	if(tr.event != nil)
		s += "&event="+http->encodequery(tr.event);
	if(url.query == "")
		url.query = "?"+s[1:];
	else
		url.query += s;

	(nil, nil, fd, herr) := http->get(url, nil);
	if(herr != nil)
		trackerror("request: "+herr);
	n := sys->readn(fd, d := array[32*1024] of byte, len d);
	if(n < 0)
		trackerror(sprint("read: %r"));
	if(n == len d)
		trackerror("huge answer");
	d = d[:n];

	(b, err) := Bee.unpack(d);
	if(err != nil)
		trackerror("parsing: "+err);

	interval := b.geti("interval"::nil);
	if(interval == nil)
		trackerror("bad response, missing/bad key interval");
	bmininterval := b.geti("min interval"::nil);
	mininterval := -1;
	if(bmininterval != nil)
		mininterval = int bmininterval.i;

	bpeers := b.get("peers"::nil);
	if(bpeers == nil)
		trackerror("bad response, missing/bad key peers");
	pick peers := bpeers {
	List =>
		say("received traditional, non-compact form tracker response");
		p := array[len peers.a] of Trackpeer;
		for(i := 0; i < len peers.a; i++) {
			bip := peers.a[i].gets("ip"::nil);
			bport := peers.a[i].geti("port"::nil);
			bpeerid := peers.a[i].gets("peer id"::nil);
			if(bip == nil || bport == nil)
				trackerror("bad response, missing/bad key ip or port");
			(ok, ipaddr) := IPaddr.parse(string bip.a);
			if(ok != 0)
				trackerror(sprint("tracker sent bogus ip %#q", string bip.a));
			tp: Trackpeer;
			tp.ip = ipaddr.text();
			tp.port = int bport.i;
			if(tp.port < 0)
				trackerror(sprint("tracker sent bogus port %d", tp.port));
			if(bpeerid != nil) {
				if(len bpeerid.a != Peeridlen)
					trackerror(sprint("tracker sent bogus peerid of length %d", len bpeerid.a));
				tp.peerid = bpeerid.a;
			}
			p[i] = tp;
		}
		return ref Track (int interval.i, mininterval, p, u, b);

	String =>
		say("received compact form tracker response");
		if(len peers.a % 6 != 0)
			trackerror("bad response, bad length for compact form for key peers");
		p := array[len peers.a/6] of Trackpeer;
		i := 0;
		for(o := 0; o+6 <= len peers.a; o += 6) {
			ipstr := sprint("%d.%d.%d.%d", int peers.a[o], int peers.a[o+1], int peers.a[o+2], int peers.a[o+3]);
			(port, nil) := g16(peers.a, o+4);
			p[i++] = Trackpeer(ipstr, port, nil);
		}
		return ref Track (int interval.i, mininterval, p, u, b);
	}
	trackerror("bad response, bad type for key peers");
	return nil;
}

genpeerid(): array of byte
{
	peerid := sprint("-in%04d-", version);
	peerid += hex(random->randombuf(Random->ReallyRandom, (Peeridlen-len peerid)/2));
	return array of byte peerid;
}

sane(s: string): string
{
	ascii := "0-9a-zA-Z";
	ext0 := "!+,.:-";
	ext := "_"+ext0;

	# keep all good characters, replace all bad characters by underscore
	p1: string;
	for(i := 0; i < len s; i++)
		if(str->in(s[i], ascii+ext))
			p1[len p1] = s[i];
		else
			p1[len p1] = '_';

	# fold all multiples of underscores into a single one
	# remove all underscores before and after non-alphanumeric
	p2: string;
	for(i = 0; i < len p1; i++)
		if(p1[i] == '_' && (p2 == "" || str->in(p2[len p2-1], ext) || (i+1 < len p1 && str->in(p1[i+1], ext0))))
			;
		else
			p2[len p2] = p1[i];
	return p2;
}

simplepath(s: string): string
{
	(nil, toks) := sys->tokenize(s, "/");
	if(toks == nil)
		return nil;
	path: string;
	for(; toks != nil; toks = tl toks)
		path += "/"+sane(hd toks);
	return path[1:];
}

sha1(d: array of byte): array of byte
{
	digest := array[kr->SHA1dlen] of byte;
	kr->sha1(d, len d, digest, nil);
	return digest;
}

randomize[T](a: array of T)
{
	for(i := 0; i < len a; i++) {
		j := rand->rand(len a);
		(a[i], a[j]) = (a[j], a[i]);
	}
}


say(s: string)
{
	if(dflag)
		warn(s);
}
