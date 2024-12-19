/*	sound effect wavetables for schreckenstein sounds
	
	2023-11-20	split out from main .asm block
	2023-11-26	second iter improved sounds, .pc changed to .align at end for integration
			potion sound is grating, bring into tune?
	2023-11-30	fixed search tune and "tone0"
	2023-12-03	adjust lightning decay to prevent restart issue
	2023-12-04	adjusted bonk again because it is re-gated rapidly, tweaks to envelopes to improve
			triggering, made restarts consistent for all effects
	2023-12-10	made zombie wake and lightning more substantial
	2024-01-03	added tune note/duration tables for intro tune, replaced 64000 with actual PAL value of clock64
	2024-11-11	v6 derived directly from v5, adjustments for new sound management scheme
			v6b reduced lantern repeat cycles, reduced splat cycles
	2024-12-06	v7 bring rev in line with v34 main, retuned potion and teleport for no dissonance
*/

.pc = $e000 "Sound effect wavetables"

//	#repeat, vcrtl, ad, sr, frelo, frehi
.const kPAL = pow(256,3)/(985248.0)	// compute SID frequencies from Atari clock divider  kPAL*floor(64000/n)
.const clock64 = 63514			// "64kHz" clock is actually not in PAL Ataris
.var fr = 0.0
.var fr2 = 0.0

//-----------------------------------------------------------------------------------------------------------------
nothing:
// just nothing
.byte 1,  $00, $0f, $00, $00, $00
//-----------------------------------------------------------------------------------------------------------------
footstep:
//60ms duration ramp up attack, around 1kHz
.byte 3,  $81, $70, $60, $00, $42
.byte 1,  $80, $70, $60, $00, $00 	//end
//-----------------------------------------------------------------------------------------------------------------
ladder:
//heavily modulated waveform, 140ms duration, 4 or 5 frequencies between 350 and 2kHz, starts square ends triangle
.eval fr = kPAL*floor(clock64/180)
.byte 1,  $51, $01, $b6, <fr, >fr
//.byte 1,  $81, $01, $b6, <fr, >fr	// sound is complicated and overwhelming, take some modulation out
.eval fr = kPAL*floor(clock64/64)
.byte 1,  $40, $00, $b6, <fr, >fr
//.byte 1,  $71, $12, $87, <fr, >fr
.eval fr = kPAL*floor(clock64/32)
.byte 1,  $70, $00, $87, <fr, >fr
.eval fr = kPAL*floor(clock64/96)
.byte 1,  $50, $00, $87, <fr, >fr
.eval fr = kPAL*floor(clock64/17)
.byte 1,  $10, $00, $87, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
jump:
// 500ms nearly constant amplitude (slightly increasing) upward frequency sweep from 1070Hz-to 3333Hz
// goes from square to sine so might try pulse, saw, tri every 100ms
.for(var n=60; n>20; n+=-2) {		//400ms
.eval fr = kPAL*clock64/n
.byte 1,  $41, $00, $f0, <fr, >fr
}
.eval fr = kPAL*clock64/20
.byte 1,  $21, $00, $f0, <fr, >fr
.eval fr = kPAL*clock64/18
.byte 1,  $11, $00, $f0, <fr, >fr	//another 40ms simulating LPF
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
bonk:
.byte 1,  $41, $00, $f2, $cb, $06	//
.byte 1,  $10, $00, $f2, $cb, $06	// shortened
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
stunned:
// attack 240ms, release: 740ms.  700Hz-1000Hz-460Hz   N=91 to 64 to 139
 .for (var n=94; n>63; n+=-5) {
 .eval fr = kPAL*floor(clock64/n)
.byte 2,  $11, $60, $f9, <fr, >fr
 }
.byte 2,  $10, $60, $fa, $40, $45	// start release

.for (var n=64; n<149; n+=5) {
 .eval fr = kPAL*floor(clock64/n)
.byte 2,  $10, $70, $fa, <fr, >fr
 }
 .byte 1,  $00, $0f, $80, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
throw:
//50ms partial ramp down then 1kHz noise ramp up down 50ms  515-->248Hz
.byte 1,  $41, $05, $50, $1e, $11	//$3c, $22	sounds better an octave lower
.byte 1,  $71, $05, $50, $2b, $03	//$57, $06
.byte 1,  $40, $05, $50, $54, $08	//$a8, $10
.byte 1,  $81, $31, $83, $2b, $02	//$57, $04
.byte 2,  $80, $31, $83, $2b, $02	//$57, $04
.byte 1,  $00, $0f, $00, $00, $00	// end
//----------------------------------------------------------------------------------------------------------------
lightning:
// pss thump 280ms.  Something like 800-1000-80Hz
.byte 3,  $81, $17, $60, $e1, $33	//had to reduce decay to 7 else restart problems
.byte 3,  $81, $17, $60, $40, $45
.byte 3,  $81, $17, $60, $7f, $8a
.byte 2,  $81, $17, $53, $40, $45
.byte 2,  $80, $17, $53, $7f, $8a

//.byte 2,  $41, $06, $44, $2a, $02	// thump just makes it kind of muddy
//.byte 2,  $40, $06, $44, $2a, $02
.byte 1,  $00, $0f, $00, $00, $00
//-----------------------------------------------------------------------------------------------------------------
death:
// 125, 178, 330Hz ish
.for (var i=0; i<10; i++) {
.byte 3,  $41, $01, $f5, $b6, $07	//gate  full speed SR=$f3. half speed $f8-$f9
.byte 3,  $40, $01, $f5, $6d, $0b	//sustain
.byte 3,  $40, $01, $fd, $ae, $20	//sustain/partial restart
}
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
lantern:
.eval fr = kPAL*floor(clock64/128)
.eval fr2 = kPAL*floor(clock64/20)
.for(var n=0; n<15; n++) {		// was 17, this whole thing is kind of long
.byte 1,  $81, $0a, $00, $00, $10
.byte 1,  $41, $0a, $00, $80, $18
.byte 1,  $81, $0a, $00, $00, $10
}
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
splat:
// 160ms  instant attack, slight decay, increasing frequency something like 800-1020Hz
.for(var n=88; n>50; n+=-8) {		//160		was -5
.eval fr = kPAL*clock64/n
.byte 1,  $81, $04, $a0, <fr, >fr
}
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
gotCandle:
.byte 2,  $41, $01, $f7, $00, $04 	//gate		decay=1 helps improve reliability of gating here
.byte 3,  $40, $00, $f7, $00, $04 	//sustain
.byte 2,  $00, $00, $00, $00, $04 	//restart

.byte 2,  $41, $01, $f7, $00, $04 	//gate
.byte 3,  $40, $01, $f7, $00, $04 	//sustain
.byte 2,  $00, $00, $00, $00, $04 	//restart

.byte 2,  $41, $01, $f7, $00, $04 	//gate
.byte 3,  $40, $01, $f7, $00, $04 	//sustain
.byte 2,  $00, $00, $00, $00, $04 	//restart

.byte 2,  $41, $01, $f7, $00, $04 	//gate
.byte 3,  $40, $01, $f7, $00, $04 	//sustain
.byte 2,  $00, $00, $00, $00, $04 	//restart

.byte 2,  $41, $01, $f8, $00, $04 	//gate
.byte 4,  $40, $01, $f8, $00, $04 	//sustain


.byte 1,  $00, $0f, $00, $00, $00	// end		4*3*5 + 3*5 + 5 = 80 bytes
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
gotKey:
// core element is an 8-frequency sequence, 20ms each, ramping in amplitude for the whole 100ms
// something like 300, 188, 133, 760, 300, 188, 133, 760 -- that's two blocks of 4 in the envelope
// n=213,340,481,84
// this is repeated five times
.var nList = List().add(213,340,481,84,213,340,481,84)

.for(var r=0; r<5; r++) {
	.for(var i=0; i<8; i++) {
	.eval fr = kPAL*clock64/nList.get(i)
	.byte 1, $11, $80, $f0, <fr, >fr	
	}
.byte 1, $10, $80, $f0, <fr, >fr
}
.byte 1, $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
robbed:
// 64kHz/N where N goes from 180 to 36 in steps of -18. 3rd step is repeated twice. 200ms, ramp up attack=9 then nothing
.for(var n=180; n>18; n+=-18) {
.eval fr = kPAL*clock64/n
.byte 1,  $11, $90, $f0, <fr, >fr
.if(n==144) { .byte 1,  $61, $90, $f0, <fr, >fr }
}
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
trap:
.eval fr2 = kPAL*floor(clock64/20)
.for(var n=0; n<12; n++) {
.byte 1,  $41, $c0, $4f, $91, $15
.byte 1,  $81, $c0, $4f, $00, $10
.byte 1,  $81, $c0, $4f, $3c, $22
.byte 1,  $81, $c0, $4f, $00, $10
}
.byte 2,  $81, $02, $a5, <fr2, >fr2	// end pop
.byte 4,  $80, $02, $a5, <fr2, >fr2
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
resetTrap:
//????????????????????????????????????????????????????  if actual, just point to splat
//----------------------------------------------------------------------------------------------------------------
placeDoor:
// 1400ms duration 16 cycles of 80ms decay ramps,noise frequency increasing the entire time
//
.for(var i=820;i>20;i+= -50) {
.eval fr = kPAL*clock64/i
.byte 3,  $81, $04, $20, <fr, >fr
.byte 1,  $00, $00, $00, <fr, >fr
}
.byte 1,  $00, $0f, $00, $00, $00
//-----------------------------------------------------------------------------------------------------------------
gotPotion:
//60ms stairstep ramp up, noise modulated, repeated 13 times, around 800Hz fundamental?	
//can't do it so rapidly flip to zero freq to make a buzz
//was complicated and grating sounding in game so I took out noise bursts

//.eval fr = kPAL*floor(clock64/469)	$0902 between C-3 and C#-3
//.eval fr2 = kPAL*floor(clock64/313)	$0d7f between G-3 and G#-3

.eval fr = $09b7			// D-3 retune slightly because was very dissonant with teleporter (which was C#-3, now C-3)
.eval fr2 = $0cf8			// G-3

//.byte 1,  $00, $0f, $00, <fr, >fr	// preset envelopes w/ standard hard restart parameter
.for(var n=0; n<7; n++) {
.byte 1,  $41, $20, $ff, <fr, >fr
.byte 1,  $21, $20, $ff, <fr2, >fr2
.byte 1,  $21, $00, $ff, <fr2, >fr2
.byte 1,  $41, $20, $ff, <fr, >fr	//$00, $01
}
.byte 1,  $21, $20, $f7, <fr2, >fr2	// give a little ending ring
.byte 5,  $20, $20, $f7, <fr2, >fr2
.byte 1,  $00, $0f, $00, $00, $00	// end
//----------------------------------------------------------------------------------------------------------------
gotDoor:
// 1200ms of 100ms cycles 16ms attack, 72ms decay to level 3, this is repeated twice
// frequencies go like 250Hz, 125Hz, 250Hz alternating octaves
// starts at 125Hz (n=512) and goes to 937Hz (n=64)
.for(var n=0;n<2;n++) {
	.for(var i=512;i>128;i+=-24) {
	.eval fr = kPAL*clock64/i
	.byte 1,  $41, $10, $f4, <fr, >fr
	.byte 2,  $40, $10, $f4, <(2*fr), >(2*fr)
	.byte 1,  $00, $00, $00, <fr, >fr
	}
}	
.byte 1,  $00, $0f, $00, $00, $00
//----------------------------------------------------------------------------------------------------------------
gotGemLevel4:
// sort of ringing telephone sound 225Hz 80ms period |\|\|\... for 860ms
.for(var i=0; i<8; i++) {
.eval fr = kPAL*clock64/287
.byte 3,  $21, $00, $f2, <fr, >fr
.byte 1,  $20, $00, $f2, <fr, >fr
}
.byte 1,  $21, $00, $a4, <fr, >fr	//let it ring a bit
.byte 5,  $20, $00, $a4, <fr, >fr

.byte 1,  $00, $0f, $00, $00, $00	//end
//----------------------------------------------------------------------------------------------------------------
gotDiamond:
// similar to got door, but decending frequency and only played once, 1000ms
.for(var i=256; i<436; i+=32) {
.eval fr = kPAL*clock64/i
.byte 1,  $41, $10, $f2, <fr, >fr
.byte 1,  $00, $10, $00, <fr, >fr
.byte 1,  $40, $10, $f2, <(2*fr), >(2*fr)
.byte 1,  $00, $10, $00, <fr, >fr
}
.for(var i=436; i<616; i+=32) {
.eval fr = kPAL*clock64/(i-163)
.byte 1,  $41, $10, $f2, <fr, >fr
.byte 1,  $00, $10, $00, <fr, >fr
.byte 1,  $40, $10, $f2, <(2*fr), >(2*fr)
.byte 1,  $00, $10, $00, <fr, >fr
}
.eval fr = kPAL*clock64/512
.byte 1,  $00, $00, $00, <fr, >fr
.byte 1,  $41, $10, $f3, <fr, >fr
.byte 2,  $40, $10, $f3, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00	//end
//----------------------------------------------------------------------------------------------------------------
gotWizard:
// 1600ms decaying bong 465Hz/232/116 modulated
.byte 1,  $41, $00, $fb, $b6, $07
.for(var i=0;i<39;i++) {
.byte 1,  $40, $00, $fb, $6c, $0f
.byte 1,  $40, $00, $fb, $b6, $07
}
.byte 1,  $00, $0f, $00, $00, $00
//-----------------------------------------------------------------------------------------------------------------
batChirp:
// two phases
// second phase has 9 frequencies that look like they go from N=20-36 in steps of 2 64kHz/N
//phase 1 is higher than the SID can do, it goes from 10-4kHz in 4 steps. Just make a glitch
.byte 1,  $71, $00, $8f, $fe, $ff
.byte 1,  $40, $00, $8f, $fe, $ff
.byte 1,  $00, $00, $00, $00, $40	// restart, pause

.for (var n=20; n<38; n+=2) {		//phase 2
.eval fr = kPAL*floor(clock64/n)
.byte 1,  $41, $90, $f0, <fr, >fr
 }
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
wakeZombie:
// simple decaying bong 400ms, 90Hz, modulated 
.byte 2,   $41, $00, $fa, $14, $08
.for(var i=0;i<7;i++){
.byte 1,  $00, $00, $f9, $1f, $06
.byte 2,  $40, $00, $f9, $1f, $06
}
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
tone0:	// not sure what this is used for
// 363Hz for 220 ms, fast attack, slow decay to 1/4 amplitude, less modulation
// $1b
.eval fr = kPAL*363
.byte 9,  $21, $07, $40, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00
//-----------------------------------------------------------------------------------------------------------------
searchTone1:
// percussion instrument for door search tune
// similar to 0, 1040Hz noise, 80ms duration, more decay
.byte 4,  $81, $05, $10, $40, $45
.byte 1,  $00, $0f, $00, $00, $00	//for this and following tones, doubling the restart time does not work
//----------------------------------------------------------------------------------------------------------------
searchTone2:
// $1a, 182Hz for 220 ms, fast attack, slow decay to 1/4 amplitude, heavy pwm sound just do dominant tone
.eval fr = kPAL*182
.byte 9,  $41, $07, $40, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00
//----------------------------------------------------------------------------------------------------------------
searchTone3:
// $1b, 200ms, 100Hz
.eval fr = kPAL*100
.byte 8,  $41, $07, $40, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00
//----------------------------------------------------------------------------------------------------------------
searchTone4:
// $1c, 200ms,135Hz
.eval fr = kPAL*135
.byte 8,  $41, $07, $40, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00
//----------------------------------------------------------------------------------------------------------------
updateTeleportal: 
// 1650 Hz, instant attack, 200ms decay		
.eval fr = kPAL*floor(clock64/38)
.byte 2,  $41, $02, $c7, <fr, >fr
.byte 8,  $40, $02, $c7, <fr, >fr
.byte 1,  $00, $0f, $00, $00, $00	// end
//-----------------------------------------------------------------------------------------------------------------
useTeleportal:
// 800ms volume ramp 140Hz
// was $092c = C#-3, but very dissonant
.byte 3, 	$11, $b0, $80, $08, $08
.byte 4, 	$21, $b0, $80, $08, $08
.byte 33,	$41, $b0, $80, $08, $08
.byte 1, 	$00, $0f, $00, $00, $00
// extreme example here.  41*5=205 bytes in this wavetable. RLE would use 4+4*5 bytes = 24, saving 181 bytes.

endTable:
// there are 44 blocks containing 179 total repeated VBIs.  RLE could remove 5 bytes*(179-44) = 675 bytes,
// but will add back in probably 100 bytes for the run length data...something like a 10-15% compression 



.align $100
//.................................................................................................................
// some tables to map the sound indices to the start of each wavetable segment
//.................................................................................................................

.pc = * "Start of wavetable mapping table"

soundMapLo:
.byte	<nothing, <footstep, <ladder, <jump, <bonk, <stunned, <throw, <lightning, <death
.byte	<lantern, <splat, <gotCandle, <gotKey, <robbed, <trap, <splat, <placeDoor
.byte	<gotPotion, <gotDoor, <gotGemLevel4, <gotDiamond, <gotWizard, <batChirp, <wakeZombie, <tone0
.byte	<searchTone1, <searchTone2, <searchTone3, <searchTone4, <updateTeleportal, <useTeleportal
soundMapHi:
.byte	>nothing, >footstep, >ladder, >jump, >bonk, >stunned, >throw, >lightning, >death
.byte	>lantern, >splat, >gotCandle, >gotKey, >robbed, >trap, >splat, >placeDoor
.byte	>gotPotion, >gotDoor, >gotGemLevel4, >gotDiamond, >gotWizard, >batChirp, >wakeZombie, >tone0
.byte	>searchTone1, >searchTone2, >searchTone3, >searchTone4, >updateTeleportal, >useTeleportal




//=================================================================================================================
// Now the note tables for the intro tune
//=================================================================================================================

// original format seems to be noteDivisor, duration with three consecutive tables
// one for each voice.  Data starting at
// $982c, $98ba, $991c---> offsets $00, $8e, $f0
// total of 360 bytes of 3 voices * 2 values per note
// will become 540 bytes after translation

.const atariVoice1 = List().add($00,$10,$00,$40,				//dummy notes to exercise the envelopes
$A2,$0C,$7A,$0C,$81,$0C,$7A,$06,$6C,$06,$61,$0C,$6C,$0C,$81,$18,
$7A,$0C,$6C,$06,$61,$06,$5B,$18,$61,$0C,$5B,$06,$61,$06,$6C,$06,
$7A,$06,$51,$0C,$5B,$06,$61,$06,$6C,$06,$7A,$06,$81,$06,$7A,$06,
$7A,$18,$6C,$24,$6C,$0C,$6C,$0C,$61,$0C,$7A,$18,$81,$0C,$61,$0C,
$56,$0C,$51,$0C,$56,$24,$51,$0C,$56,$0C,$61,$0C,$6C,$0C,$7A,$0C,
$81,$0C,$7A,$0C,$91,$18,$A2,$24,$A2,$0C,$7A,$0C,$81,$0C,$7A,$06,
$6C,$06,$61,$0C,$6C,$0C,$81,$18,$7A,$0C,$6C,$06,$61,$06,$5B,$18,
$61,$0C,$5B,$06,$61,$06,$6C,$06,$7A,$06,$51,$0C,$5B,$06,$61,$06,
$6C,$06,$7A,$06,$A2,$0C,$7A,$0C,$81,$0C,$7A,$24, $00,$80, $00,$04)			// end of tune...delay

.const atariVoice2 = List().add($00,$10,$00,$40,
$C1,$18,$B6,$0C,$A2,$18,$91,$0C,$A2,$18,$A2,$0C,$91,$18,$81,$0C,
$7A,$0C,$91,$18,$7A,$0C,$91,$0C,$B6,$0C,$D8,$0C,$A2,$0C,$C1,$0C,
$81,$24,$A2,$24,$C1,$0C,$AC,$0C,$A2,$0C,$A2,$0C,$91,$0C,$81,$0C,
$91,$24,$A2,$24,$A2,$0C,$AC,$0C,$A2,$0C,$A2,$18,$AC,$0C,$00,$24,	
$C1,$18,$B6,$0C,$A2,$18,$A2,$0C,$A2,$18,$A2,$0C,$91,$18,$81,$0C,
$7A,$0C,$91,$18,$7A,$0C,$91,$0C,$B6,$0C,$C1,$18,$D8,$0C,$C1,$24, $00,$80, $00,$04)	//end of tune

.const atariVoice3 = List().add($00,$10,$00,$40,
$F2,$18,$D8,$0C,$C1,$18,$B6,$0C,$A2,$0C,$B6,$0C,$C1,$0C,$B6,
$06,$C1,$06,$D8,$18,$F2,$18,$B6,$0C,$C1,$0C,$B6,$0C,$91,$0C,$A2,
$0C,$C1,$0C,$F2,$0C,$A2,$24,$81,$18,$A2,$0C,$91,$18,$A2,$0C,$7A,
$18,$D8,$0C,$D8,$0C,$6C,$0C,$7A,$0C,$81,$18,$7A,$0C,$81,$0C,$91,
$0C,$A2,$0C,$C1,$0C,$D8,$18,$A2,$0C,$A2,$06,$B6,$06,$C1,$06,$D8,
$06,$F2,$18,$D8,$0C,$C1,$18,$B6,$0C,$A2,$0C,$B6,$0C,$C1,$0C,$B6,
$06,$C1,$06,$D8,$18,$F2,$18,$B6,$0C,$C1,$0C,$B6,$0C,$91,$0C,$A2,
$18,$A2,$0C,$F2,$24, $00,$80, $00,$04)							//end of tune


.function note(n) {
	.if(n!=0) .return kPAL*floor(clock64/n)
	else .return 0
	}

.pc = * "Converted Tune Table"
freqVoice1Lo:
.fill atariVoice1.size()/2, <note(atariVoice1.get(i*2))
freqVoice1Hi:
.fill atariVoice1.size()/2, >note(atariVoice1.get(i*2))
durationVoice1:
.fill atariVoice1.size()/2, atariVoice1.get(1+i*2)-1

.var duration1 = 0
.for (var i=0; i<atariVoice1.size()/2; i++) { .eval duration1 += atariVoice1.get(1+i*2) }
.print "# notes 1  ="+atariVoice1.size()/2
.print "duration 1 ="+duration1



freqVoice2Lo:
.fill atariVoice2.size()/2, <note(atariVoice2.get(i*2))
freqVoice2Hi:
.fill atariVoice2.size()/2, >note(atariVoice2.get(i*2))
durationVoice2:
.fill atariVoice2.size()/2, atariVoice2.get(1+i*2)-1

.var duration2 = 0
.for (var i=0; i<atariVoice2.size()/2; i++) { .eval duration2 += atariVoice2.get(1+i*2) }
.print "# notes 2  ="+atariVoice2.size()/2
.print "duration 2 ="+duration2



freqVoice3Lo:
.fill atariVoice3.size()/2, <note(atariVoice3.get(i*2))/2	// drop this an octave for more interest
freqVoice3Hi:
.fill atariVoice3.size()/2, >note(atariVoice3.get(i*2))/2
durationVoice3:
.fill atariVoice3.size()/2, atariVoice3.get(1+i*2)-1

.var duration3 = 0
.for (var i=0; i<atariVoice3.size()/2; i++) { .eval duration3 += atariVoice3.get(1+i*2) }
.print "# notes 3  ="+atariVoice3.size()/2
.print "duration 3 ="+duration3

//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------

// print to console to help with debugging sounds that cross page boundaries



.function ranges(l1,l2) {
	.return toHexString(l1)+'-'+toHexString(l2-1)
	}

.print @"nothing:\t"+ranges(nothing, footstep)

.print @"footstep:\t"+ranges(footstep, ladder)

.print @"ladder:\t"+ranges(ladder, jump)

.print @"jump:  \t"+ranges(jump, bonk)

.print @"bonk:  \t"+ranges(bonk, stunned)

.print @"stunned:\t"+ranges(stunned, throw)

.print @"throw:\t"+ranges(throw, lightning)

.print @"lightning:\t"+ranges(lightning, death)

.print @"death:\t"+ranges(death, lantern)

.print @"lantern:\t"+ranges(lantern, splat)

.print @"splat:\t"+ranges(splat, gotCandle)

.print @"gotCandle:\t"+ranges(gotCandle, gotKey)

.print @"gotKey:\t"+ranges(gotKey, robbed)

.print @"robbed:\t"+ranges(robbed, trap)

.print @"trap:  \t"+ranges(trap, placeDoor)

.print @"placeDoor:\t"+ranges(placeDoor, gotPotion)

.print @"gotPotion:\t"+ranges(gotPotion, gotDoor)

.print @"gotDoor:\t"+ranges(gotDoor, gotGemLevel4)

.print @"gotGemLevel4:\t"+ranges(gotGemLevel4, gotDiamond)

.print @"gotDiamond:\t"+ranges(gotDiamond, gotWizard)

.print @"gotWizard:\t"+ranges(gotWizard, batChirp)

.print @"batChirp:\t"+ranges(batChirp, wakeZombie)

.print @"wakeZombie:\t"+ranges(wakeZombie, tone0)

.print @"tone0:\t"+ranges(tone0, searchTone1)

.print @"searchTone1:\t"+ranges(searchTone1, searchTone2)

.print @"searchTone2:\t"+ranges(searchTone2, searchTone3)

.print @"searchTone3:\t"+ranges(searchTone3, searchTone4)

.print @"searchTone4:\t"+ranges(searchTone4, updateTeleportal)

.print @"updateTeleportal:\t"+ranges(updateTeleportal, useTeleportal)

.print @"useTeleportal:\t"+ranges(useTeleportal, endTable)



