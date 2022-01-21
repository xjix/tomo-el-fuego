# tomo el fuego

tomo is an inferno distribution. an adaptable operating system capable of
operating as an overly to a variety of conventional operating systems AND
natively on devices with as little as 1MiB of RAM. building on the already
innovative work of plan9 and inferno, tomo is an attempt to develop a novel
information-centring networking stack and an accompanying graphical application
runtime.

=> http://xj-ix.luxe/wiki/tomo/ tomo wiki
=> http://xj-ix.luxe/wiki/bbnet/
=> https://www.vitanuova.com/inferno/ inferno

## [UNIX] booting up

customize this script to get started from unix.

```
#!/bin/sh
## locations
iroot=/opt/tomo
emu_cmd="$iroot/Linux/386/bin/emu"
## resolutions
emu_display=800x480
## jit level
### c > 0 has issues on some systems that i use
emu_jit_level=0
## envs
EMU_OPTS="-r$iroot -c$emu_jit_level -g$emu_display"
exec $emu_cmd $EMU_OPTS /dis/tomo-init -u `whoami`
```

## see also

=> http://heropunch.luxe heropunch kooperativo
=> ./NOTICE license information

