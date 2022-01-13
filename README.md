# tomo el fuego

> tomo is a rapidly evolving reserch project, use at your own risk.

tomo facilitates communication and information sharing in a dynamic environment
with severe constraints and intense challenges: deep space and the astral plane.
the companion application << star cult >> provides a rich simulated environment
for experimenting with safe and engaging interface design.

## what are the applications?

flying planes and controlling musical instruments i guess. later, drone swarm
coordination (using ad-hoc mesh) to control a cloud of synthetic butterflies.
flight controllers for LEO, space, and astral missions.

## design and lineage

tomo is an inferno distribution.

inferno represents services and resources in a file-like name hierarchy.
programs access them using only the file operations open, read/write, and close.
'files' are not just stored data, but represent devices, network and protocol
interfaces, dynamic data sources, and services. the approach unifies and
provides basic naming, structuring, and access control mechanisms for all system
resources. a single file-service protocol (the same as Plan 9's 9P) makes all
those resources available for import or export throughout the network in a
uniform way, independent of location. an application simply attaches the
resources it needs to its own per-process name hierarchy ('name space').

inferno can run 'native' on various ARM, PowerPC, SPARC and x86 platforms but
also 'hosted', under an existing operating system (including AIX, FreeBSD, IRIX,
Linux, MacOS X, Plan 9, and Solaris), again on various processor types.

## see also

* [tomo wiki](http://xjix.luxe/wiki/tomo/)
* [chaotic software](http://xj-ix.luxe/wiki/chaotic-software/)
* [bbnet](http://xj-ix.luxe/wiki/bbnet/)
* [heropunch kooperativo](http://heropunch.luxe/)

