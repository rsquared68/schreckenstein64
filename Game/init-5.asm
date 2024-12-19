/* 	init code for schreckenstein-64 port

//	New initialization subroutines specific to C64 architecture, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.


	2023-10-02	first breakout from main.asm
	2023-11-22	v2 add initialization of sound for FX players
	2023-12-21	v3 made score data relocatable L06xx etc.
	2023-12-23	v3 added extra leading zero to scores to match original game
	2023-12-26	veto display of player 2 when in 1 player mode
	2024-01-05	v4 changed a few things for proper re-init after victory
	2024-11-21	initi new SoundStack

*/

initialize:

	// note color ram and tile/mcm colors are level dependent so done elsewhere


//................................................................................................................. 
	
	// do the sprite setup not done elsewhere
	 
	//don't turn on sprites because interferes with loader timing
//	lda #%11111111	
//	sta $d015

	eor #$80
	sta $d01d	//double wide, except for player sprite #7
	lda #0
	sta $d01b	//in front of background


	// common to all levels
	lda #BLACK
	sta EXTCOL	//border
	sta BGCOL0	//background

	lda #$80
	sta $d01c	//player sprite MCM, all others hires
        lda #LIGHT_RED
        sta $d025	//MCM color 0
	lda #CYAN
	sta $d026	//MCM color 1

 	// most sprite init is done in frame by the irq handler, except for pointers in screen 2
	.var i = 0	
	.for(var n=0; n<5; n++) {	// with these pointers for statusbars
	.eval i = SB1List.get(n)	// mapping from sprite utilization plan
	lda #(SBsprites1-$4000 + $40*n)/$40
	sta $03f8+screenRam2+i		// need to handle screen2 as pointers move with screen swap but irq doesn't touch these
	}

	.for(var n=5; n<7; n++) {	// with these pointers for statusbars
	.eval i = SB1List.get(n)	// mapping from sprite utilization plan
	lda #(SBsprites2-$4000 + $40*(n-5))/$40
	sta $03f8+screenRam2+i		// need to handle screen2 as pointers move with screen swap but irq doesn't touch these
	}
	
//................................................................................................................. 	
	
	// some setup for scoring
	
	lda #<L060d	//$0d
	sta L0611	//$0611
	lda #>L060d	//$06
	sta L0611+1	//$0612		// setup pointer for score 

	lda #0				// clear scores 
	sta L060d
	sta L060d +1
	sta L060f
	sta L060f +1


//................................................................................................................. 

	// zero some other variables not handled prior to level load
	
	lda #0
	sta v1CoarseX
	sta v2CoarseX
	sta v1CoarseY
	sta v2CoarseY
	sta v1ScrollX
	sta v2ScrollX
	sta v1ScrollY
	sta v2ScrollY
	sta GameLevel_gbl		// note this can be set to 5 by the game completed sequence need to clear it after OPTION_SCREEN code is run
	//sta PlayerControlMode		// do not destroy previous setup
	//sta PlayerControlMode+1
	sta ZombieOffset1_zp
	sta ZombieOffset2_zp
	sta animCtr_zp			// generates charset pointer from frame count
	sta frameCtr_zp 		// counts how many times the irq handler reached top of frame
	sta SoundStackPtr_zp		// zero sound stack
	
//................................................................................................................. 	

	// set up the two random number generators

	// seed LFSR random number generator with A,X (!=0)
	lda $d012
	eor #$01
	tax
	lda $a2
	eor #$01		
	jsr SeedRandom
chkrand:

	// start SID voice 3 as random number generator, uses GenRandom
	jsr ConfigSIDrandom
	ldx rng_zp_high
!wait:
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop 		// waste 16 cycles
	dex		//
	bne !wait-	// random cycles wait for random SID phase

//.................................................................................................................

	// set up SID, lifted from soundfx-rle-2.asm

ConfigSIDsound:					
	//set volume and init the player registers
	lda #$00
	sta SIGVOL		// volume off
	sta fxIteration1_zp	// clear sound iteration
	sta fxIteration2_zp	// clear sound iteration
	sta p1Sound_zp		// clear sound select register 1
	sta p2Sound_zp		// clear sound select register 2
	sta soundPlaying1_zp
	sta soundPlaying2_zp
	sta SoundStackPtr_zp


	lda #0			// fixed duty cycle 50% or something, atari I think has fixed 50% dc
	sta PWLO1
	sta PWLO2  
	lda #$05		// try to sound rougher than 50% dc
	sta PWHI1
	sta PWHI2

	lda #0
	sta RESON	// filtercontrol:  filter off all voices

			// ********may need to force a sound to play here to init envelopes

	
	// set up an envelope for footsteps using the noise waveform on voice 3 already set up for the random number generator
	lda #$10
	sta ATDCY3	//attack decay
	lda #$a4	
	sta SUREL3	//volume and release

	lda #%00001111
	sta SIGVOL	//volume and filter type, voice 3 enab

	
//.................................................................................................................

	rts
	
	

//_________________________________________________________________________________________________________________________________________________________
//_________________________________________________________________________________________________________________________________________________________

loadScreen:

	jsr CLEAR_SCREEN_1
	
	lda #$c8			// mcm off, 40 columns
	sta $d016
	
	lda #GREEN			// don't make player 2 info visible if in 1 player mode
	sta loadScrnPlyrColr
	lda NumPlayers
	beq !n+				// branch if two players
	lda #BLACK
	sta loadScrnPlyrColr
!n:

	ldy GameLevel_gbl
	lda times40,y			// multiply by 40 columns to get row of text
	tax
				
	ldy #0
!lp:
	lda levelText,x
	sta screenRam1+10*40,y
	
	lda #ORANGE
	sta colorRam+10*40,y
	
	lda playerText,y
	sta screenRam1+15*40,y
	
	lda zeroText,y
	sta screenRam1+16*40,y
	
	lda #BLUE
	cpy #19
	bcc !n+
	lda loadScrnPlyrColr:#GREEN
!n:	sta colorRam+15*40,y
	sta colorRam+16*40,y
	
	inx
	iny
	cpy #40
	bne !lp-
	
	
	lda #$10		// this is needed or it just prints blanks, weird
	sta pad
	
	// do score
	lda #$86
	sta scoreScreenLoc
	lda #$7a
	sta scoreScreenLoc+1
	lda L060d
	sta num
	lda L060d+1
	sta num+1
	ldy #(4-1)		// 4 decimal digits 
	jsr Scrn16toDec

	lda #$9d
	sta scoreScreenLoc
	lda #$7a
	sta scoreScreenLoc+1
	lda L060f
	sta num
	lda L060f+1
	sta num+1
	ldy #(4-1)		// 4 decimal digits 
	jsr Scrn16toDec	
		
	lda #vicmem1	// switch screen1 memory to this text
	and #%11110000
	ora #%00001000	// atari charset at $6000-$4000
	sta $d018
	
	//jsr WAIT_TRIGGER
	
	rts


times40:
	.fill 5, i*40
	
	
levelText:
    		//	"0123456789012345678901234567890123456789"
.var level1name = 	"             im burgverlies             "
.var level2name =	"          das tor zur unterwelt         "
.var level3name =	"        katakomben der unterwelt        "
.var level4name =	"        tempel der toten masken         "
.var level5name =	"          die magischen augen           "

.encoding "ascii"					// needed!
.fill 40, (level1name.charAt(i)+$c0) & $3f		// this is converting ascii to the original game charset sequence
.fill 40, (level2name.charAt(i)+$c0) & $3f
.fill 40, (level3name.charAt(i)+$c0) & $3f
.fill 40, (level4name.charAt(i)+$c0) & $3f
.fill 40, (level5name.charAt(i)+$c0) & $3f
	
playerText:
.var playerStr =	"    spieler Q              spieler R    "
.fill 40, (playerStr.charAt(i)+$c0) & $3f

zeroText:
.var zeroStr =		"     P    P                 P    P      "
.fill 40, (zeroStr.charAt(i)+$c0) & $3f
		 
		 	