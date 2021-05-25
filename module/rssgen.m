# This is free and unencumbered software released into the public domain.
# see /lib/legal/UNLICENSE
Rssgen: module
{
	PATH:	con "/dis/lib/rssgen.dis";

	Item: adt {
		title, link, descr: string;
		time, timetzoff:	int;
		guid:	string;
		cats:	list of string;

		text:	fn(it: self ref Item): string;
	};

	rssgen:	fn(title, link, descr: string, items: list of ref Item): string;
};
