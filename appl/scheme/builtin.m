BuiltIn: module
{
	PATH: con "/dis/scheme/builtin.dis";

	init: fn(sy: Sys, sch: Scheme, c: SCell, m: Math, st: String,
		b: Bufio, in: ref Iobuf, out: ref Iobuf);
	closeinport: fn(args: ref Cell, env: list of ref Env): (int, ref Cell);

};
