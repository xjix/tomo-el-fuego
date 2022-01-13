# tomo el fuego

tomo is an inferno distribution.

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
EMU_INIT="sh -c '/dis/tomo-init -u `whoami`'"
exec $emu_cmd $EMU_OPTS $EMU_INIT
```

## see also

* [tomo wiki](http://xjix.luxe/wiki/tomo/)
* [chaotic software](http://xj-ix.luxe/wiki/chaotic-software/)
* [bbnet](http://xj-ix.luxe/wiki/bbnet/)
* [heropunch kooperativo](http://heropunch.luxe/)

