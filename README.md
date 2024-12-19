# Schreckenstein-64

This project is a study of Peter Finzel’s superb two-player head-to-head jump and run dungeon explorer for the Atari line of 8-bit home computers and my attempt to accurately port it to the Commodore 64. 


## Compatibility 

Since some users of RC1 have reported issues that are not actually bugs in the game but related to compatibility with various emulation setups, let me say what I know right now about compatibility:  tl;dr, real machines and VICE 3.7+ work well for me and among my immediate friends and colleagues.

The main issues that are observed will be graphical glitches in or around the statusbars showing the score, life, inventory, etc.  These regions are very sensitive to VIC and CPU timing, especially in the middle green statusbar where when fine YSCROLL = 6 in the top viewport.  At the transition to the statusbar where YSCROLL = 7 always, two badlines in a row occur where the second is on a line with 7 sprites. If you have a democoder’s eye you’ll notice a line of FLD appear there only at a certain point in the scrolling e.g. while player 1 is climbing a ladder.  If the VIC/CPU are emulated it’s possible that the bus accesses don’t get emulated with the right timing during the “takeover period” and this will mess up the timing of the whole statusbar.  I use many democoding screen tricks with the exception of VSP and border opening, so if a setup has problems with edge-case demos it may have problems with this code as well.

1) I have personally tested on my 4 real machines. Three are breadbins (326298 and 250407) all of which are NTSC-to-PAL converted, one with a VIC-II^2 switcher, and one with a Kawari board.  One was a C64C (250466 long board) sourced from Germany with no mods.  Some friends have tested very likely expanding the success rate to include C64C short boards.  Any issues I found on real machines, I think I fixed.

2) I know it runs fine in VICE 3.7 GTK3 and 3.8 GTK3 on Windows.  Also OK in Slajerek’s C64 Debugger v0.64.58.6 which is based on VICE 3.1.  In some versions of VICE before 3.7 it didn’t work but it could be made to work by shifting the timing by one cycle on that line. However that shift broke it on every real machine and the other emulators.  I hypothesize that what was happening was that the VIC was allowing either one too many or one too few CPU read or write accesses during the “takeover period” in that specific build of VICE, but I did not dive too deeply.  In some YouTube videos of users playing, this defect is visible as a flickering of junk in the green statusbar as the upper player’s viewport scrolls through YSCROLL=6, e.g. when falling or climbing on a ladder.  In principle I could release code specifically for that emulator version but as it’s been fixed by the VICE team since at least 3.7 it would seem there was little point.

3) I have an anecdotal report that it runs fine in some recent version of RetroPie.

4) I know nothing so far about Hoxs, The C64 Mini/Maxi etc.  I use the Covert Bitops fastloader in this code.  I have never seen any issues but some people reported it wouldn’t even load in their setup.

5) CIA revision (old/new) shouldn’t matter.  While some of the code sections use timer stabilization to stay aligned with raster X, there is enough slop for it to be OK.  I have tested on real hardware with both CIA types and did not see a problem, VICE 3.7+ also had no issue when switching CIAs.  Likely, this would result in a complete crash because the stabilizer is derived from Hermit’s shortest-possible approach and does not handle the “$dc04 equals 8” edge-case either for those who know it.  The application here doesn’t need more because it only has to handle a few cycles of variability for page crossings of a couple of indexed loads, and entry is timed to give plenty of margin. (Agreed it's dangerous and always needs checking when adjusting the code.)

6)  At least one scene production (a packed and trained version) has one or more defects.  One defect is related to the player 2 sprite pointer indirection in the animation state machine; initialization probably didn’t happen properly in that "crack."  I was impressed by the packing because I’m not experienced there and the file size and loading times were impressive to me.  However if any code or data was relocated there can be problems because the page-boundary alignment is critical to the timing of many sections of the code.  Also if the production’s loader/depacker doesn’t re-initialize zeropage and the variables in the $8000 region as well as re-sync the CIA timers to the raster that my code expects, bad things will happen.




## Introduction

I discovered this game when a friend gifted me an 800XL and I had a blast playing it. I had been thinking of trying a C64 project to build on what little 6510 coding skills I had remaining since the 1980s, and the complexity of the display of the original game seemed like it would be really challenging for me to implement.  However, with all that had been learned by democoders since I last touched a C64 it seemed like it was maybe possible. 

Now just about a year later I have something that works. It is a little slower than the original because of the CPU clock difference, the lack of CPU-independent display list processing in the C64, and the fact that screen memory occurs in fixed blocks within the VIC bank and you cant just point to an arbitrary memory location as the start of a screen like you can with the Atari.  Therefore the CPU is doing a lot of heavy lifting with raster interrupts not required on the Atari.  This is my first project of this type other than a few small and mostly unimpressive demoparts, so there were quite a few weeks where I thought it might actually be impossible.  But with the magic of memcopy speedcode generated realtime each frame to permit absolute loads and a few other tricks, I managed to be able to draw all of the graphical elements.  After convincing myself of the proof of concept, I started to disassemble and reverse-engineer the Homesoft [a2] crack of the original game to uncover and extract the game engine for integration with my graphical kernel.  That worked, so I somewhat hastily added a sound engine and option/hi-score/victory screen code to arrive at the RC1 package here.  Really the only thing Im unsatisfied with at this point is the sound-effect gating and arbitration.  In addition to its graphics, Peters original Atari game is remarkable for the variety and detail of the 32 different sound effects, which usually use 3 but sometimes 4 POKEY audio channels.  The SID only has three channels, has complicated re-gating requirements (due to the envelope bug), and I need to sparingly use channel 3 because it is also my random number generator.  As a result the sounds dont always trigger properly and some effects need to be pre-empted by others of higher priority. 

Special thanks are due to Peter Finzel himself, who graciously permitted me open release of his disassembled and reverse-engineered binary in this repository.  Hes still coding after so many years and it was great to have a short exchange of messages with him.  He mentioned that part of the original was written the Atari language Action! and you may detect a certain kind of repeating code template in the source if you examine it.  He also mention that he used his own Action! runtime library for some of the implementation; so this code represents quite a view into Atari development history for that time period. 


## Architectural discussion

TODO 
