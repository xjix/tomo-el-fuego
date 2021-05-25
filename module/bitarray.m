# This is free and unencumbered software released into the public domain.
# see /lib/legal/UNLICENSE
Bitarray: module
{
	PATH:	con "/dis/lib/bitarray.dis";

	Bits: adt {
		d:	array of byte;
		have:	int;
		total:	int;

		new:		fn(n: int): ref Bits;
		mk:		fn(n: int, d: array of byte): (ref Bits, string);
		clone:		fn(b: self ref Bits): ref Bits;
		get:		fn(b: self ref Bits, i: int): int;
		set:		fn(b: self ref Bits, i: int);
		setall:		fn(b: self ref Bits);
		clear:		fn(b: self ref Bits, i: int);
		clearall:	fn(b: self ref Bits);
		invert:		fn(b: self ref Bits);
		clearbits:	fn(b: self ref Bits, o: ref Bits);
		nand:		fn(a, na: ref Bits): ref Bits;
		isempty:	fn(b: self ref Bits): int;
		isfull:		fn(b: self ref Bits): int;
		bytes:		fn(b: self ref Bits): array of byte;
		rand:		fn(b: self ref Bits): int;
		all:		fn(b: self ref Bits): list of int;
		iter:		fn(b: self ref Bits): ref Bititer;
		inviter:	fn(b: self ref Bits): ref Bititer;
		text:		fn(b: self ref Bits): string;
	};

	Bititer: adt {
		b:	ref Bits;
		last:	int;
		inv:	int;
		seen:	int;

		next:	fn(b: self ref Bititer): int;
	};
};
