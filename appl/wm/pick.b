# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.

# <https://source.heropunch.luxe/System/9/inferno-attrfs>
# <https://github.com/mjl-/attrfs>

implement WmPick;

include "sys.m";
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
include "arg.m";
include "tk.m";
include "tkclient.m";
include "sh.m";

sys: Sys;
draw: Draw;
str: String;
tk: Tk;
tkclient: Tkclient;
sh: Sh;

sprint, fprint, print, fildes: import sys;

WmPick: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

dflag, cflag: int;
pickfd: ref Sys->FD;
pickdir: string;
attrdir := "/mnt/attr";

rightmost := -1;
nlists: int;
keys: list of string;
t: ref Tk->Toplevel;
wmctl: chan of string;
buttons: array of ref (string, string);


tkcmds0 := array[] of {
	"frame .fup",
	"frame .fmid",
	"frame .fdown",
};

tkcmds1 := array[] of {
	"listbox .lbres -yscrollcommand {.resscroll set}",
	"scrollbar .resscroll -command {.lbres yview}",
	"pack .resscroll -side left -in .fdown -fill y",
	"pack .lbres -side left -in .fdown -fill both -expand 1",
};

tkcmds2 := array[] of {
	"button .bshow -command {send ctl show} -text show",
	"button .bclear -command {send sel -1} -text clear",
	"pack .bshow .bclear -in .fmid -side left",
	"pack .fup -fill both -expand 1",
	"pack .fmid -fill x",
	"pack .fdown -fill both -expand 1",
	"pack propagate . 0",
	". configure -width 800 -height 600",
	"update",
};

makelistbox(id: int, key: string)
{
	tkcmd(sprint("frame .fsel%d; frame .fctl%d", id, id));
	tkcmd(sprint("button .bb%d -text show -command {send showlist %d}", id, id));
	tkcmd(sprint("menu .m%d", id));
	for(l := keys; l != nil; l = tl l)
		tkcmd(sprint(".m%d add command -label %s -command {send showlist %d; .mb%d configure -text %s}", id, hd l, id, id, hd l));
	tkcmd(sprint("menubutton .mb%d -text %s -menu .m%d", id, key, id));
	tkcmd(sprint("frame .flb%d", id));
	tkcmd(sprint("listbox .lb%d -yscrollcommand {.lb%dscroll set}", id, id));
	tkcmd(sprint("scrollbar .lb%dscroll -command {.lb%d yview}", id, id));
	tkcmd(sprint("pack .lb%dscroll -side left -in .flb%d -fill y", id, id));
	tkcmd(sprint("pack .lb%d -side left -in .flb%d -fill both -expand 1", id, id));
	tkcmd(sprint("pack .bb%d .mb%d -in .fctl%d -side left", id, id, id));
	tkcmd(sprint("pack .fctl%d -in .fsel%d", id, id));
	tkcmd(sprint("pack .flb%d -in .fsel%d -fill both -expand 1", id, id));
	tkcmd(sprint("bind .lb%d <ButtonRelease-1> {send sel %d}", id, id));
	tkcmd(sprint("pack .fsel%d -in .fup -side left -fill both -expand 1", id));
}

init(ctxt: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	if(ctxt == nil)
		fail("no window context");
	draw = load Draw Draw->PATH;
	str = load String String->PATH;
	tk = load Tk Tk->PATH;
	tkclient= load Tkclient Tkclient->PATH;
	bufio = load Bufio Bufio->PATH;
	arg := load Arg Arg->PATH;
	sh = load Sh Sh->PATH;

	arg->init(args);
	arg->setusage(arg->progname()+" [-d] key ...");
	while((c := arg->opt()) != 0)
		case c {
		'b' =>	bname := arg->earg();
			bcmd := arg->earg();
			buttons = add(buttons, ref (bname, bcmd));
		'c' =>	cflag++;
		'd' =>	dflag++;
		* =>	arg->usage();
		}
	args = arg->argv();
	if(args == nil)
		arg->usage();

	sys->pctl(Sys->FORKNS, nil);

	keys = readkeys();
	nlists = len args;

	tkclient->init();
	(t, wmctl) = tkclient->toplevel(ctxt, "", "wm/pick", Tkclient->Appl);

	selch := chan of string;
	buttonch := chan of string;
	ctlch := chan of string;
	showlistch := chan of string;
	tk->namechan(t, selch, "sel");
	tk->namechan(t, buttonch, "button");
	tk->namechan(t, ctlch, "ctlch");
	tk->namechan(t, showlistch, "showlist");
	for(i := 0; i < len tkcmds0; i++)
		tkcmd(tkcmds0[i]);
	i = 0;
	for(; args != nil; args = tl args)
		makelistbox(i++, hd args);
	for(i = 0; i < len tkcmds1; i++)
		tkcmd(tkcmds1[i]);
	
	for(i = 0; i < len buttons; i++) {
		tkcmd(sprint("button .b%d -command {send button %d} -text '%s", i, i, buttons[i].t0));
		tkcmd(sprint("pack .b%d -in .fmid -side left", i));
		if(i == 0 && cflag)
			for(j := 0; j < nlists; j++)
				tkcmd(sprint("bind .lb%d <ButtonRelease-3> {.lb%d selection clear 0 end; .lb%d activate [.lb%d index @%%x,%%y]; .lb%d selection set [.lb%d index active]; send sel %d; send button 0}", j, j, j, j, j, j, j));
	}

	for(i = 0; i < len tkcmds2; i++)
		tkcmd(tkcmds2[i]);

	newsel(0);
	setlist(0, 1);

	tkclient->onscreen(t, nil);
	tkclient->startinput(t, "kbd"::"ptr"::nil);

	for(;;) alt {
	s := <-t.ctxt.kbd =>
		tk->keyboard(t, s);
	s := <-t.ctxt.ptr =>
		tk->pointer(t, *s);
	s := <-t.ctxt.ctl or s = <-t.wreq =>
		tkclient->wmctl(t, s);
	menu := <-wmctl =>
		case menu {
		"exit" =>
			return;
		* =>
			tkclient->wmctl(t, menu);
		}

	id := int <-selch =>
		say("selch");
		if(id > rightmost) {
			if(fprint(pickfd, "%s %s\n", getseltype(id), getsel(id)) < 0)
				fail(sprint("writing select: %r"));
		} else
			newsel(id+1);
		rightmost = id;
		clearbeyond(id+1);
		if(id+1 < nlists)
			setlist(id+1, 1);
		tkcmd(".lbres delete 0 end");
		if(rightmost > 0)
			show();

	id := int <-buttonch =>
		say("buttonch");
		sys->chdir(pickdir);
		sh->run(nil, buttons[id].t1::nil);

	op := <-ctlch =>
		say("ctlch");
		case op {
		"show" =>
			if(pickfd != nil)
				show();
		}

	id := <-showlistch =>
		say("showlistch");
		setlist(int id, 0);
		tkcmd(".lbres delete 0 end");
		if(rightmost > 0)
			show();
	}
}

show()
{
	b := bufio->open(pickdir+"/path", Bufio->OREAD);
	if(b == nil)
		fail(sprint("show open: %r"));
	for(;;) {
		l := b.gets('\n');
		if(l == nil)
			break;
		tkcmd(".lbres insert end '"+l[:len l-1]);
	}
	tkcmd("update");
}

getseltype(lbid: int): string
{
	return tkcmd(sprint(".mb%d cget -text", lbid));
}

getsel(lbid: int): string
{
	return tkcmd(sprint(".lb%d get [.lb%d curselection]", lbid, lbid));
}

newsel(count: int)
{
	pickfd = nil;
	pickdir = nil;

	f := sprint("%s/clone", attrdir);
	clonefd := sys->open(f, Sys->OREAD);
	if(clonefd == nil)
		fail(sprint("open %s: %r", f));
	n := sys->read(clonefd, d := array[1024] of byte, len d);
	if(n < 0)
		fail(sprint("read %s: %r", f));
	if(n == 0)
		fail(sprint("eof on %s", f));
	pickdir = sprint("%s/%s", attrdir, string d[:n]);
	say(sprint("have pickdir=%q", pickdir));
	pickfd = sys->open(pickdir+"/pick", Sys->OWRITE);
	if(pickfd == nil)
		fail(sprint("open %s/pick: %r", pickdir));
	clonefd == nil;

	for(i := 0; i < count; i++)
		if(tkcmd(sprint(".lb%d curselection", i)) != nil)
			if(fprint(pickfd, "%s %s\n", getseltype(i), getsel(i)) < 0)
				fail(sprint("writing selection %d, %q %q", i, getseltype(i), getsel(i)));
}

clearbeyond(lbid: int)
{
	for(; lbid < nlists; lbid++)
		tkcmd(sprint(".lb%d delete 0 end", lbid));
}

setlist(lbid: int, propagate: int)
{
	say(sprint("setlist %d", lbid));
	f := sprint("%s/%s", pickdir, getseltype(lbid));
	b := bufio->open(f, Bufio->OREAD);
	if(b == nil)
		fail(sprint("open %s: %r", f));
	tkcmd(sprint(".lb%d delete 0 end", lbid));
	for(n := 0;; n++) {
		l := b.gets('\n');
		if(l == nil)
			break;
		if(l[len l-1] == '\n')
			l = l[:len l-1];
		tkcmd(sprint(".lb%d insert end '%s", lbid, l));
	}
	if(propagate && n == 1 && lbid < nlists-1) {
		if(lbid > rightmost)
			rightmost = lbid;
		lbid++;
		tkcmd(sprint(".lb%d selection set 0; .lb%d activate 0", lbid, lbid));
		setlist(lbid, propagate);
	}
	tkcmd("update");
}

readkeys(): list of string
{
	f := sprint("%s/keys", attrdir);
	b := bufio->open(f, Bufio->OREAD);
	if(b == nil)
		fail(sprint("open %s: %r", f));
	l := b.gets('\n');
	return sys->tokenize(l, " ").t1;
}

tkcmd(s: string): string
{
	r := tk->cmd(t, s);
	if(r != nil && r[0] == '!')
		fprint(fildes(2), "tkcmd: %q: %s\n", s, r);
	return r;
}

add[T](a: array of T, e: T): array of T
{
	na := array[len a+1] of T;
	na[:] = a;
	na[len a] = e;
	return na;
}

say(s: string)
{
	if(dflag)
		fprint(fildes(2), "%s\n", s);
}

fail(s: string)
{
	fprint(fildes(2), "%s\n", s);
	raise "fail:"+s;
}
