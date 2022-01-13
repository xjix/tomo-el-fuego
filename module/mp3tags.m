# This is free and unencumbered software released into the public domain.
# see /lib/legal/UNLICENSE
Mp3tags: module
{
	PATH:	con "/dis/lib/mp3tags.dis";

	genre:	fn(id: int): string;

	Mp3tag: adt {
		title, artist, album, year, comment: string;
		track, genre: int;

		unpack:	fn(d: array of byte): (ref Mp3tag, string);
		read:	fn(file: string): (ref Mp3tag, string);
	};
};
