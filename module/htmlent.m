# This is free and unencumbered software released into the public domain.
# see /lib/legal/UNLICENSE
Htmlent: module
{
	PATH:	con "/dis/lib/htmlent.dis";
	entities:	array of (string, int);

	init:	fn();
	lookup:	fn(name: string): int;
	conv:	fn(s: string): string;
};
