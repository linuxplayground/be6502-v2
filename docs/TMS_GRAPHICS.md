# TMS9918A Integration with the 65C02

The TMS9918A VDP depends on dynamic ram.  In fact, the datasheets call for 8 DRAM chips each 16kb x 1bit.

While this would have been possible, I chose to go with an option presented on Hackaday over here: [https://hackaday.io/project/160851-tms9918-vdp-with-sram-video-memory](https://hackaday.io/project/160851-tms9918-vdp-with-sram-video-memory)

You can see this all laid out on the schematic PDF included in these here docs.

As the TMS9918A VDP controlls it's own memory all access to video ram is via the two registers.  There are some pretty cool projects on Youtube that I used to get started.

* [TMS9918A by krallja](https://www.youtube.com/playlist?list=PL3itg4Usn3F-24qjSrlY400MipDswKzk-) - starts out on an Arduino and ends up interfacing it to a standard Ben Eater 6502 build.
* For Z80 enthusiasts, you can learn a lot - and I do mean a LOT - from [John's Basement](https://www.youtube.com/JohnsBasement).  John has a range of videos detaling his design and implimentation of a Z80 retro board that runs CPM.  At the time of writing he has released a few videos of how he has integrated a TMS9118 (not a typo) into his project.  While differet to how I did it, the programming interface is identical.
* And of course, the amount of knowledge I absorbed while trawling through code over at the [HBC-56 project](https://github.com/visrealm/hbc-56/) was invaluable.
