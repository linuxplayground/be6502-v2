# Thoughts on the AY-3-8910

No single board computer that's designed to run games would be complete without some kind of sound output.

I decided to go with something era compatible, and selected the AY-3-8910 from Microchip. (formally general instrument)

The device is actually not to hard to figure out.  I have it hooked into my VIA but it's possible to wire it directly to he address bus and if you want to do that, have a look at the [HBC-56 project](https://github.com/visrealm/hbc-56).

For an introduction I suggest watching InternalRegister show how it works. - [Using an AY-3-8910 programmable sound generator with an Arduino](https://www.youtube.com/watch?v=srmNbi9yQNU)

The design on my breadboard is pretty much the same as what was done in this video but instead of using an Arduino I am using the VIA.

