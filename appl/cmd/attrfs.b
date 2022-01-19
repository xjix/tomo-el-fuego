# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.

# <https://source.heropunch.luxe/System/9/inferno-attrfs>
# <https://github.com/mjl-/attrfs>

implement Attrfs;

include "sys.m";
include "draw.m";
include "arg.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
include "styx.m";
	Tmsg, Rmsg: import Styx;
include "styxservers.m";
include "daytime.m";
include "tables.m";
include "attrdb.m";
include "lists.m";

sys: Sys;
str: String;
styx: Styx;
styxservers: Styxservers;
daytime: Daytime;
attrdb: Attrdb;
tables: Tables;
lists: Lists;

print, sprint, fprint, fildes: import sys;
Styxserver, Fid, Navigator, Navop: import styxservers;
Tuples, Dbentry, Dbf, Db, Dbptr, Attr: import attrdb;
Table, hash: import tables;
reverse, concat: import lists;

Dflag, dflag: int;

Eclosed:	con "selection closed";
Enotfound, Enotdir: import Styxservers;

Qroot, Qclone, Qattrs, Qkeys, Qdir, Qpick, Qall, Qattr0: con iota;
Qlast: int;
tab := array[] of {
	(Qroot,		".",		Sys->DMDIR|8r555),
	(Qclone,	"clone",	8r666),
	(Qattrs,	"attrs",	8r444),
	(Qkeys,		"keys",		8r444),
	(Qdir,		"",		Sys->DMDIR|8r555),
	(Qpick,		"pick",		8r666),
	(Qall,		"all",		8r444),
	(Qattr0,	"",		8r444),
};
srv: ref Styxserver;


Pick: adt {
	pickid:	int;
	clonefid:	int;
	picked:	int;
	ids:	list of int;
	sel:	list of (int, string);
	fids:	list of int;
	opens:	int;

	new:	fn(fid: int): ref Pick;
	clear:	fn(p: self ref Pick);
	select:	fn(p: self ref Pick, k: int, v: string);
	selectdata:	fn(p: self ref Pick): array of byte;
	project:	fn(p: self ref Pick, keys: array of int): array of byte;
};
lastpickid: int;
picks := array[0] of ref Pick;
fiddata: ref Table[array of byte];
fidallpick: ref Table[array of int];

Entry: adt {
	id:	int;
	vals:	array of string;

	mk:	fn(a: array of string): ref Entry;
	get:	fn(e: self ref Entry, k: int): string;
	set:	fn(e: self ref Entry, k: int, val: string);
};

Map: adt {
	tab:	array of list of (string, int);

	new:	fn(): ref Map;
	add:	fn(m: self ref Map, v: (string, int));
	find:	fn(m: self ref Map, v: string): list of int;
};

Strset: adt {
	a:	array of list of string;
	alc:	array of list of string;	# lower case versions

	new:	fn(slots: int): ref Strset;
	add:	fn(ss: self ref Strset, s: string);
	all:	fn(ss: self ref Strset): array of string;
};

maxentryid: int;
entries := array[256] of list of ref Entry;
maps: array of (string, ref Map);
attributes: array of string;
attrsdata, indexkeysdata: array of byte;

Attrfs: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	styx = load Styx Styx->PATH;
	styx->init();
	styxservers = load Styxservers Styxservers->PATH;
	styxservers->init(styx);
	daytime = load Daytime Daytime->PATH;
	attrdb = load Attrdb Attrdb->PATH;
	attrdb->init();
	tables = load Tables Tables->PATH;
	lists = load Lists Lists->PATH;

	arg->init(args);
	arg->setusage(arg->progname()+" [-Dd] attrdb mainkey indexkey,... attribute,...");
	while((c := arg->opt()) != 0)
		case c {
		'D' =>	Dflag++;
			styxservers->traceset(Dflag);
		'd' =>	dflag++;
		* =>	arg->usage();
		}
	args = arg->argv();
	if(len args != 4)
		arg->usage();
	dbpath := hd args;
	mainkey := hd tl args;
	indexkeys := sys->tokenize(hd tl tl args, ",").t1;
	l := concat(sys->tokenize(hd tl tl tl args, ",").t1, indexkeys);
	attributes = array[len l] of string;
	i := 0;
	for(; l != nil; l = tl l)
		attributes[i++] = hd l;

	Qlast = Qall+len attributes;
	maps = array[len indexkeys] of (string, ref Map);
	i = 0;
	for(l = indexkeys; l != nil; l = tl l)
		maps[i++] = (hd l, Map.new());

	fiddata = fiddata.new(32, nil);
	fidallpick = fidallpick.new(32, nil);
	s := "";
	for(i = 0; i < len attributes; i++)
		s += " "+attributes[i];
	attrsdata = array of byte s[1:];
	s = "";
	for(l = indexkeys; l != nil; l = tl l)
		s += " "+hd l;
	indexkeysdata = array of byte s[1:];

	db := Db.open(dbpath);
	if(db == nil)
		fail(sprint("open: %r"));
	start: ref Dbptr;
	e: ref Dbentry;
	empty := array[len attributes] of string;
	for(;;) {
		(e, start) = db.find(start, mainkey);
		if(e == nil)
			break;
		ent := Entry.mk(empty);
		for(t := e.lines; t != nil; t = tl t) {
			for(p := (hd t).pairs; p != nil; p = tl p)
				if((k := getkey((hd p).attr)) >= 0)
					ent.set(k, (hd p).val);
			if(has((hd t).pairs, mainkey)) {
				eadd(ent);
				for(i = 0; i < len maps; i++)
					maps[i].t1.add((ent.get(i), ent.id));
				ent = Entry.mk(ent.vals);
			}
		}
		maxentryid = ent.id;
	}

	navch := chan of ref Navop;
	spawn navigator(navch);

	nav := Navigator.new(navch);
	msgc: chan of ref Tmsg;
	(msgc, srv) = Styxserver.new(sys->fildes(0), nav, big Qroot);

done:
	for(;;) alt {
	gm := <-msgc =>
		if(gm == nil)
			break;
		pick m := gm {
		Readerror =>
			fprint(fildes(2), "read error: %s\n", m.error);
			break done;
		}
		dostyx(gm);
	}
}

dostyx(gm: ref Tmsg)
{
	pick m := gm {
	Open =>
		(fid, nil, nil, err) := srv.canopen(m);
		if(fid == nil)
			return replyerror(m, err);
		q := int fid.path&16rff;
		id := int fid.path>>8;
		p: ref Pick;
		if(q == Qclone)
			picks = add(picks, array[] of {p = Pick.new(m.fid)});
		else if((p = findpick(id)) != nil && q == Qpick && (m.mode & Sys->OTRUNC))
			p.clear();
		if((q == Qclone || q >= Qdir) && p != nil)
			p.opens++;
		srv.default(m);

	Write =>
		(f, err) := srv.canwrite(m);
		if(f == nil)
			return replyerror(m, err);
		q := int f.path&16rff;
		id := int f.path>>8;
		if((q == Qpick || q == Qall) && findpick(id) == nil)
			return replyerror(m, Eclosed);
		case q {
		Qclone or Qpick =>
			p: ref Pick;
			if(q == Qclone)
				p = findfidpick(m.fid);
			else
				p = findpick(id);
			for((nil, l) := sys->tokenize(string m.data, "\n"); l != nil; l = tl l) {
				(a, v) := str->splitstrl(hd l, " ");
				if(v != nil)
					v = v[1:];
				k := getkey(a);
				if(k < 0)
					return replyerror(m, "bad key: "+a);
				p.select(k, v);
				clearcache(p);
			}
			srv.reply(ref Rmsg.Write(m.tag, len m.data));
		Qall =>
			p := findpick(id);
			ks := fidallpick.find(m.fid);
			(nil, ll) := sys->tokenize(string m.data, "\n");
			for(; ll != nil; ll = tl ll) {
				k := getkey(hd ll);
				if(k < 0)
					return replyerror(m, "bad key: "+hd ll);
				ks = addintarray(ks, array[] of {k});
			}
			fidallpick.del(m.fid);
			fidallpick.add(m.fid, ks);
			p.fids = addint(p.fids, m.fid);
			srv.reply(ref Rmsg.Write(m.tag, len m.data));
		* =>
			srv.default(m);
		}

	Clunk or Remove =>
		f := srv.getfid(m.fid);
		if(f != nil) {
			q := int f.path&16rff;
			p: ref Pick;
			if(q == Qclone)
				p = findfidpick(m.fid);
			else if(q >= Qdir) {
				if(q == Qall)
					fidallpick.del(m.fid);
				fiddata.del(m.fid);
				id := int f.path>>8;
				p = findpick(id);
				if(p != nil)
					p.fids = delint(p.fids, m.fid);
			}
			if(f.isopen && p != nil && --p.opens <= 0) {
				say(sprint("clunk, removing pick %d", p.pickid));
				delpick(p);
			}
		}
		srv.default(m);

	Read =>
		f := srv.getfid(m.fid);
		if(f.qtype & Sys->QTDIR) {
			srv.default(m);
			return;
		}
		if(dflag) say(sprint("read f.path=%bd", f.path));
		q := int f.path&16rff;
		id := int f.path>>8;
		if(q >= Qdir && findpick(id) == nil)
			return replyerror(m, Eclosed);
		case q {
		Qclone =>
			p := findfidpick(m.fid);
			srv.reply(styxservers->readstr(m, string p.pickid));
		Qattrs =>
			srv.reply(styxservers->readbytes(m, attrsdata));
		Qkeys =>
			srv.reply(styxservers->readbytes(m, indexkeysdata));
		Qpick =>
			p := findpick(id);
			srv.reply(styxservers->readbytes(m, p.selectdata()));
		* =>
			d := getfiddata(m.fid, int f.path);
			srv.reply(styxservers->readbytes(m, d));
		}

	* =>
		srv.default(gm);
	}
}

navigator(c: chan of ref Navop)
{
again:
	for(;;) {
		navop := <-c;
		if(dflag) say(sprint("have navop, tag %d", tagof navop));
		id := int navop.path>>8;
		q := int navop.path&16rff;
		pick op := navop {
		Stat =>
			op.reply <-= (dir(int op.path, 0), nil);
		Walk =>
			if(op.name == "..") {
				if(q > Qdir)
					op.reply <-= (dir(Qdir|(id<<8), 0), nil);
				else
					op.reply <-= (dir(Qroot, 0), nil);
				continue again;
			}
			case q {
			Qroot =>
				for(i := Qclone; i <= Qkeys; i++)
					if(tab[i].t1 == op.name) {
						op.reply <-= (dir(tab[i].t0, 0), nil);
						continue again;
					}
				(nameid, rem) := str->toint(op.name, 10);
				if(rem == nil && findpick(nameid) != nil)
					op.reply <-= (dir(Qdir|(nameid<<8), 0), nil);
				else
					op.reply <-= (nil, Enotfound);

			Qdir =>
				for(i := Qdir+1; i <= Qall; i++)
					if(op.name == tab[i].t1) {
						op.reply <-= (dir(i|(id<<8), 0), nil);
						continue again;
					}
				for(i = 0; i < len attributes; i++)
					if(op.name == attributes[i]) {
						op.reply <-= (dir((Qattr0+i)|(id<<8), 0), nil);
						continue again;
					}
				op.reply <-= (nil, Enotfound);

			* =>
				op.reply <-= (nil, Enotdir);
			}
		Readdir =>
			if(int op.path == Qroot) {
				n := Qkeys+1-Qclone;
				have := 0;
				for(i := op.offset; have < op.count && i < n+len picks; i++)
					case Qclone+i {
					Qclone to Qkeys =>
						op.reply <-= (dir(Qclone+i, 0), nil);
						have++;
					* =>
						op.reply <-= (dir(Qdir|(picks[i-n].pickid<<8), 0), nil);
						have++;
					}
			} else {
				for(i := 0; i < op.count && i+op.offset < Qall-Qpick+1+len attributes; i++)
					op.reply <-= (dir(i+Qpick|(id<<8), 0), nil);
			}
			op.reply <-= (nil, nil);
		}
	}
}

dir(path, mtime: int): ref Sys->Dir
{
	tabq := q := path&16rff;
	if(tabq >= Qattr0)
		tabq = Qattr0;
	(nil, name, perm) := tab[tabq];
	d := ref sys->zerodir;
	d.name = name;
	if(q >= Qattr0)
		d.name = attributes[q-Qattr0];
	if(q == Qdir)
		d.name = string (path>>8);
	d.uid = d.gid = "attrfs";
	d.qid.path = big path;
	if(perm&Sys->DMDIR)
		d.qid.qtype = Sys->QTDIR;
	else
		d.qid.qtype = Sys->QTFILE;
	d.mtime = d.atime = mtime;
	d.mode = perm;
	return d;
}

Pick.new(fid: int): ref Pick
{
	return ref Pick(lastpickid++, fid, 0, nil, nil, nil, 0);
}

Pick.clear(p: self ref Pick)
{
	p.picked = 0;
	p.ids = nil;
	p.sel = nil;
}

Pick.select(p: self ref Pick, k: int, v: string)
{
	if(dflag) say(sprint("select, k=%d v=%q", k, v));
	p.sel = (k, v)::p.sel;
	if(p.picked) {
		r: list of int;
		for(ids := p.ids; ids != nil; ids = tl ids)
			if(eget(hd ids).get(k) == v)
				r = hd ids::r;
		p.ids = r;
	} else {
		p.ids = nil;
		for(i := 0; i < len entries; i++)
			for(l := entries[i]; l != nil; l = tl l)
				if((hd l).get(k) == v)
					p.ids = (hd l).id::p.ids;
	}
	if(dflag)
		for(ids := p.ids; ids != nil; ids = tl ids)
			say(sprint("\t%d", hd ids));
	p.picked = 1;
}

Pick.selectdata(p: self ref Pick): array of byte
{
	s := "";
	for(l := p.sel; l != nil; l = tl l)
		s += " "+attributes[(hd l).t0]+" "+(hd l).t1+"\n";
	if(len s > 0)
		s = s[1:];
	return array of byte s;
}

Pick.project(p: self ref Pick, ks: array of int): array of byte
{
	if(dflag) say(sprint("project, len ks=%d", len ks));
	if(!p.picked) {
		p.ids = nil;
		for(i := 0; i < maxentryid; i++)
			p.ids = i::p.ids;
		p.picked = 1;
	}
	slots := len p.ids/8;
	if(slots == 0)
		slots = 2;
	ss := Strset.new(slots);
	for(ids := p.ids; ids != nil; ids = tl ids) {
		if(dflag) say(sprint("project, id=%d", hd ids));
		e := eget(hd ids);
		if(ks == nil) {
			for(i := 0; i < len attributes; i++)
				ss.add(e.get(i));
		} else {
			for(i := 0; i < len ks; i++)
				ss.add(e.get(ks[i]));
		}
	}
	res := ss.all();
	qsort(res);
	s := "";
	for(i := 0; i < len res; i++)
		s += res[i]+"\n";
	return array of byte s;
}

Strset.new(slots: int): ref Strset
{
	return ref Strset(array[slots] of list of string, array[slots] of list of string);
}

Strset.add(ss: self ref Strset, s: string)
{
	ls := str->tolower(s);
	ls = str->drop(ls, " \t");
	while(ls != nil && str->in(ls[len ls-1], " \t"))
		ls = ls[:len ls-1];
	i := hash(ls, len ss.alc);
	if(!hasstr(ss.alc[i], ls)) {
		ss.alc[i] = ls::ss.alc[i];
		ss.a[i] = s::ss.a[i];
	}
}

hasstr(l: list of string, s: string): int
{
	for(; l != nil; l = tl l)
		if(hd l == s)
			return 1;
	return 0;
}

Strset.all(ss: self ref Strset): array of string
{
	size := 0;
	for(i := 0; i < len ss.a; i++)
		size += len ss.a[i];
	a := array[size] of string;
	j := 0;
	for(i = 0; i < len ss.a; i++)
		for(t := ss.a[i]; t != nil; t = tl t)
			a[j++] = hd t;
	return a;
}

clearcache(p: ref Pick)
{
	for(; p.fids != nil; p.fids = tl p.fids) {
		fiddata.del(hd p.fids);
		fidallpick.del(hd p.fids);
	}
}

getfiddata(fid: int, path: int): array of byte
{
	d := fiddata.find(fid);
	if(d == nil) {
		q := path&16rff;
		ks: array of int;
		if(q == Qall)
			ks = fidallpick.find(fid);
		else
			ks = array[] of {q-Qattr0};
		id := path>>8;
		p := findpick(id);
		d = p.project(ks);
		fiddata.add(fid, d);
		p.fids = addint(p.fids, fid);
	}
	return d;
}

delpick(p: ref Pick)
{
	for(i := 0; i < len picks; i++)
		if(picks[i] == p) {
			picks[i] = picks[len picks-1];
			picks = picks[:len picks-1];
			break;
		}
	clearcache(p);
}

findpick(id: int): ref Pick
{
	for(i := 0; i < len picks; i++)
		if(picks[i].pickid == id)
			return picks[i];
	return nil;
}

findfidpick(fid: int): ref Pick
{
	for(i := 0; i < len picks; i++)
		if(picks[i].clonefid == fid)
			return picks[i];
	return nil;
}

replyerror(m: ref Tmsg, s: string)
{
	srv.reply(ref Rmsg.Error(m.tag, s));
}

has(l: list of ref Attr, k: string): int
{
	for(; l != nil; l = tl l)
		if((hd l).attr == k)
			return 1;
	return 0;
}

Entry.mk(a: array of string): ref Entry
{
	na := array[len a] of string;
	na[:] = a;
	return ref Entry(maxentryid++, na);
}

Entry.get(e: self ref Entry, k: int): string
{
	return e.vals[k];
}

Entry.set(e: self ref Entry, k: int, val: string)
{
	e.vals[k] = val;
}

getkey(s: string): int
{
	for(i := 0; i < len attributes; i++)
		if(s == attributes[i])
			return i;
	return -1;
}

eget(id: int): ref Entry
{
	if(dflag) say(sprint("eget, id=%d", id));
	for(l := entries[id%len entries]; l != nil; l = tl l)
		if((hd l).id == id) {
			if(dflag) say("eget, have entry");
			return hd l;
		}
	if(dflag) say("eget, NOT FOUND");
	return nil;
}

eadd(e: ref Entry)
{
	i := e.id%len entries;
	entries[i] = e::entries[i];
}

mapfind(attr, value: string): list of int
{
	if(dflag) say(sprint("mapfind attr=%q value=%q", attr, value));
	for(i := 0; i < len maps; i++)
		if(maps[i].t0 == attr)
			return maps[i].t1.find(value);
	return nil;
}

Map.new(): ref Map
{
	return ref Map(array[256] of list of (string, int));
}

Map.add(m: self ref Map, v: (string, int))
{
	if(dflag) say(sprint("map.add: %q %d", v.t0, v.t1));
	i := hash(v.t0, len m.tab);
	m.tab[i] = v::m.tab[i];
}

Map.find(m: self ref Map, v: string): list of int
{
	i := hash(v, len m.tab);
	r: list of int;
	for(l := m.tab[i]; l != nil; l = tl l)
		if((hd l).t0 == v)
			r = (hd l).t1::r;
	return r;
}

addint(l: list of int, i: int): list of int
{
	return i::delint(l, i);
}

delint(l: list of int, i: int): list of int
{
	r: list of int;
	for(; l != nil; l = tl l)
		if(hd l != i)
			r = hd l::r;
	return r;
}

add[T](a: array of T, aa: array of T): array of T
{
	na := array[len a+len aa] of T;
	na[:] = a;
	na[len a:] = aa;
	return na;
}

addintarray(a: array of int, aa: array of int): array of int
{
	na := array[len a+len aa] of int;
	na[:] = a;
	na[len a:] = aa;
	return na;
}

_qsort(a: array of string, left, right: int)
{
	if(left >= right)
		return;
	store := left;
	for(i := left; i < right; i++)
		if(a[i] <= a[right]) {
			(a[store], a[i]) = (a[i], a[store]);
			store++;
		}
	(a[store], a[right]) = (a[right], a[store]);
	_qsort(a, left, store-1);
	_qsort(a, store+1, right);
}

qsort(a: array of string)
{
	_qsort(a, 0, len a-1);
}

kill(pid: int)
{
	fd := sys->open(sprint("/prog/%d/ctl", pid), Sys->OWRITE);
	if(fd != nil)
		sys->fprint(fd, "kill");
}

say(s: string)
{
	if(dflag)
		sys->fprint(sys->fildes(2), "%s\n", s);
}

fail(s: string)
{
	fprint(fildes(2), "%s\n", s);
	raise "fail:"+s;
}
