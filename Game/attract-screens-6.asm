/*	implements start/end/highscore screens with rasterbars and petscii castle
	
//	Ground-up rewrite of option/attract/victory screens, no original Schreckenstein code.
//	Copyright 2024,2025 Robert Rafac; see license.txt granting reuse permissions.


	2023-12-15 	prototyping start, from castle.asm
	2023-12-20	integration start, code bits from start-end.asm
	2024-01-05	added tune player calls, three screen types with bell and lightning effects
	2024-11-21	v4 small changes for new sound architecture
	2024-12-06	v5 enable flash on key input 
	2024-12-10	v6 fix ignores f1 after victory screen

*/


.label castlePicScreen = vicMem3.get("VIDMAT_ABS")
         

OPTION_SCREEN:
		// displays game option screen with castle, as well as high score in attract mode and game complete screen.
		// overwrites map data at $ac00 in bank 2
		//
		
		sta ATDCY2			//4	restart stupid envelope otherwise first gate on keypress can be crap	
		sta FRELO2			//4
		sta FREHI2			//4
		lda #$f0
		sta SUREL2			//4

		lda #$01			// gate on
		sta VCREG2			//4


!wait:		WAIT_FRAME_A()			// wait 1-1.5 frames

		lda #$00			// gate off 
		sta VCREG2
		
		
playersInit:
		// get/set number of players on entry by reading from screen store
	    	lda castlePicStore+$37f			//  "1" = $31, "2" = $32
	   	and #1					// just get lsbit
	    	sta NumPlayers				// 1 = one player, 0 = two players
	    	sta PlayerControlMode+1			// Player 2 control mode:  0 = human, 1 = AI, 2 = Zombie
            	lda #0
	    	sta PlayerControlMode			// Player 1 control mode:  0 = human, 1 = AI  (always human)	
		
				

	   	// copy just the castle part of the option screen data = first 800 bytes from $0400 and color data from
		// $cc00 into bank 2 for display.  this portion of the screen is common to both the option and highscore
		// screens

	   	ldx #201
loop1:
    		lda castlePicStore-1,x
    		sta castlePicScreen-1,x  		
    		lda castlePicStore+199,x
    		sta castlePicScreen+199,x
		lda castlePicStore+399,x
    		sta castlePicScreen+399,x
    		lda castlePicStore+599,x
    		sta castlePicScreen+599,x
    		
    		lda castleColorStore-1,x
    		sta colorRam-1,x
    		lda castleColorStore+199,x
    		sta colorRam+199,x
		lda castleColorStore+399,x
    		sta colorRam+399,x
    		lda castleColorStore+599,x
    		sta colorRam+599,x
    		
    		dex
    		bne loop1
    		
    		// also the very last line "mit f7 zum spiel" is common to all 3 possible screens
		// though the colors are not
	   	ldx #40
loop2:
    		lda castlePicStore+959,x
    		sta castlePicScreen+959,x  		    		
    		dex
    		bne loop2

	
		// copy (part of) atari alphanumeric charset into bank 2; atariAlphas = $6000
		// only need 128 chars = $400 bytes, but do the whole thing first bc easy
		// follow "convenient" way of remapping/reordering
		//.fill 32*8, atari.get(i+8*96)	//lowercase	256 bytes
		//.fill 32*8, atari.get(i+8*0)	//space+numbers 256 bytes
		//.fill 64*8, atari.get(i+8*32)	//uppercase 	1024 bytes

.const		castleChars = $b000

		ldx #129			// loop runs over 16 chars = 128 bytes
loop3:
		lda atariAlphas-1 +8*96,x	// two blocks of 128 bytes for 256 total
		sta castleChars-1 +0,x
		
		lda atariAlphas-1 +128+8*96,x
		sta castleChars-1 +128,x
		//------------------------
		lda atariAlphas-1 +8*0,x
		sta castleChars-1 +256,x
		
		lda atariAlphas-1 +128+8*0,x
		sta castleChars-1 +128+256,x
		//------------------------
		lda atariAlphas-1 +8*32,x
		sta castleChars-1 +512,x
		
		lda atariAlphas-1 +128+8*32,x
		sta castleChars-1 +128+512,x
		//------------------------
		lda atariAlphas-1 +8*64,x
		sta castleChars-1 +768,x
		
		lda atariAlphas-1 +128+8*64,x
		sta castleChars-1 +128+768,x
		
		dex
		bne loop3
	
		jsr initTunePlayer			// config the SID and counters for the intro tune player
		lda #$ff
		sta soundPlaying2_zp			// used here as a flag for whether or not a complete cycle of tune + bell has completed
	
		// select VICBANK 2 with char rom mapped in -- ****** adjust bank and char stuff in irq handler to match!
		lda #(vicMem3.get("VICBANK_MASK") & 3)	//choose one of the four 16k VIC banks, lowest two bits do the select
		sta $b0					// save lower two bits any temp
		lda CI2PRA
		and #%11111100				// upper bits are manipulated by the loader so don't mess with these
		ora $b0
		sta CI2PRA

		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11100100
		sta $d018

		sei					// just in case

!chooseScreen:		
		// now decide which screen to display.   0=intro/select, 1=highscore, 3=game complete
		lda $a0
		bne !otherScreen+
		
!optionScreen:
		.const optionText = castlePicStore+800
		.const optionColor = castleColorStore+800
		
		lda #0
		sta GameLevel_gbl			// clear this otherwise f1 will be igorned after returning from victory screen
				
		jsr configureForTune			// start the sound sequence with the tune
		
		// do character data and color moves
		ldx #200				//do all five lines to keep it compact, though line 5 data is already moved
!lp:
		lda optionText-1,x
		sta castlePicScreen+799,x
		lda optionColor-1,x
		sta colorRam+799,x
		dex
		bne !lp-
				
		SET_6502_IRQ_VECTOR_A(irq_option)
	        jmp !displayScreen+


!otherScreen:
		cmp #3
		beq !victoryScreen+
		
!hiScoreScreen:
		lda #0
		sta GameLevel_gbl			// clear this otherwise f1 will be igorned after returning from victory screen

		jsr configureForBell			// start the sound sequence with the bell tolling 
		
		ldx #<(scoreColor1a-1)			// default to colors for 2 players
		ldy #>(scoreColor1a-1)
		lda NumPlayers				// if zero, 2 players so don't redo
		beq !mvmem+
		ldx #<(scoreColor1b-1)
		ldy #>(scoreColor1b-1)
					
!mvmem:		
		// do character data and color moves, do only the top 4 lines of data since the very last line is constant
		stx color1Src				// SMC to set source
		sty color1Src+1

		ldx #80					// colors depend on numPlayers, to display SPIELER 2 or not. break up into 2 line pairs
!lp:
		lda scoreText-1,x			// chars
		sta castlePicScreen+799,x
		lda scoreText-1+80,x
		sta castlePicScreen+799+80,x
		
		lda scoreColor1-1,x			// colors
		sta colorRam+799,x
		lda color1Src:scoreColor1a-1,x		// this second half will be scoreColor1a (blue and green) or 1b (blue and black/invisible)
		sta colorRam+799+80,x
		
		dex
		bne !lp-
		
		ldx #40					// the color of the last line is not constant
!lp:
		lda scoreColor2-1,x
		sta colorRam+799+160,x
		dex
		bne !lp-
		
		SET_6502_IRQ_VECTOR_A(irq_highscore)
		
		jmp !displayScreen+
		
		
!victoryScreen:
		lda #0					// chain to show the final score screen after the victory screen--needs to be zero
		sta $a0					// because change-over code just inverts bit 0 to effect the change
		lda #5
		sta GameLevel_gbl			// revert the game level; it was destroyed by re-init of player variables (***temp hack)
							// as hack it is used by the key reader to ignore keypresses during the game completed screen

		jsr configureForBell			// configure freqs, envelopes, # ring counter
		jsr configureForLightning
			
		// do character data and color moves
		ldx #160
!lp:
		lda victoryText-1,x
		sta castlePicScreen+799,x
		lda #GREY
		sta colorRam+799,x
		dex
		bne !lp-
				
		SET_6502_IRQ_VECTOR_A(irq_victory)	


		// start raster interrupt that flips charsets, background colors, and draws rasterbars	        	        	        	     	        	        
!displayScreen:
		lda #$ce   				// rasterline at which to launch the irq handler 
	        sta RASTER
	        	        	       
		lda #$1b				//default screen mode and clear msb of trigger rasterline
		sta SCROLY				//full height & width, hires, normal xscroll yscroll
		lda #$c8
		sta SCROLX	
	        
	        lda #$81        			// (re)enable raster interrupts for game display note sei should still be in effect
	        sta IRQMSK
		
		lsr VICIRQ				// acknowledge any pending raster interrupt serviced

				
		WAIT_UNTIL_RASTERMSB0_A()		// wait unti upper part of screen
	 	cli     				// start the option/score/victory screen handler
	 	

		// outside of raster interrupt, monitor function keys to configure game
		// for this to work properly, 1-player mode must already be configured on first start 

!repeat:
		lda $a0
		pha
	    	jsr GetFn				//  this routine is blocking until keypress, so monitor for delay counter is done there
		pla
		cmp $a0					// if $a0 changed during keyscan loop, tune/bell sequence has completed
		beq !actOnKey+
		jmp !chooseScreen-

!actOnKey:
		// interpret keypress
	    	lda $10					//  f1 mask $10, f7 mask $08
	    	and #$18				//  test against key buf
	    	beq !repeat-
	    	cmp #$10
	    	beq !setplayr+
	    	jmp !keydone+				// if f7 pressed, pass to exit and start game
							// NOTE that f7 works on the game completed screen (think it's proper behavior)
!setplayr:
	    	lda #0
	    	sta $10					//  clear key buf

		// this needs to distinguish between the three possibilities of what to do on keypress		
		// $a0 = 0 option screen flip bit 0
		// $a0 = 1 score screen flip colors under Spieler 2 and score
		// $a0 = 3 do nothing; currently this is detected by GameLevel_gbl = 5

!adjustableOrNot:
		lda GameLevel_gbl
		cmp #5					// 
		beq !repeat-				// if true we are on the game won screen, don't respond to keys / do nothing

	    	lda castlePicStore +$37f		//  "1" = $31, "2" = $32
	    	eor #3					//  flip between the two player states so that the right char data 1 or 2 is in the screen store
	    	sta castlePicStore +$37f		//  set screen store to flipped value permanently
		// we need to also configure the game
!setNewMode:  
	    	lda NumPlayers				// old value;	1 = one player, 0 = two players
		eor #1
		sta NumPlayers				// flip to new value, then set corresponding control modes
	    	sta PlayerControlMode+1			// Player 2 control mode:  0 = human, 1 = AI, 2 = Zombie
            	lda #0
	    	sta PlayerControlMode			// Player 1 control mode:  0 = human, 1 = AI  (always human)

		// now update the screen, might wait until we are on a faraway rasterline
		ldx $a0					//  what screen are we displaying currently?
		bne !highScoreScrn+			//  if 1, skip next and modify as for highscore screen
							//  else modify as for option screen
!option:
		lda castlePicStore  +$37f
		sta castlePicScreen +$37f		//  0, we are displaying option screen so flip the player number
		jmp !otherKeyEvents+


!highScoreScrn:
		ldx #<(scoreColor1a-1)			// default to colors for 2 players
		ldy #>(scoreColor1a-1)
		lda NumPlayers				// if zero, 2 players so don't overwrite
		beq !mvmem+
		ldx #<(scoreColor1b-1)
		ldy #>(scoreColor1b-1)
		
!mvmem:		// do character data and color moves
		stx color1Src_				// SMC to set source
		sty color1Src_+1

		ldx #80					// colors depend on numPlayers, to display SPIELER 2 or not. break up into 2 line pairs
!lp:	
		lda scoreColor1-1,x			// colors
		sta colorRam+799,x
		lda color1Src_:scoreColor1a-1,x		// this second half will be scoreColor1a (blue and green) or 1b (blue and black/invisible)
		sta colorRam+799+80,x
		
		dex
		bne !lp-

!otherKeyEvents:
/*  
!keyBell:
		// play some kind of sound here, comment out until I have a better way of deconflicting with tune player

		lda #$00
		sta ATDCY3			//4
		lda #$d9
		sta SUREL3			//4
		lda #$7f		
		sta FRELO3			//4
		lda #$a8
		sta FREHI3			//4

		lda #$41			// gate on
		sta VCREG3			//4


!wait:		WAIT_FRAME_A()			// wait 1-1.5 frames

		lda #$40			// gate off 
		sta VCREG3
		
		ldx #30
!wait:		WAIT_FRAME_A()			// wait some time before allowing retrigger
		dex
		bne !wait-

		//  reset envelopes
		lda soundPlaying1_zp
		bne !restoreBell+	
				
!restoreTune:	jsr configureForTune
		jmp !skip+
		
!restoreBell:	jsr configureForBell_		// _ = alternate entry point without trashing the iteration counter		
!skip:

*/ 
		lda #GREY			// else change sky color
		sta settingsColor
		sta highScoresColor
		
		WAIT_FRAME_A()
		
		lda #DARK_GREY			
		sta settingsColor
		sta highScoresColor

		ldx #4
!wait:		WAIT_FRAME_A()			// wait some time before allowing retrigger
		dex
		bne !wait-
		
		lda #BLACK
		sta settingsColor
		sta highScoresColor
 
		ldx #20
!wait:		WAIT_FRAME_A()			// wait some time before allowing retrigger
		dex
		bne !wait-

!goRound:
		jmp !repeat-
	    
	    
!keydone:
		// de-configure/stop interrupt
		sei
		
		lda #$80        			// disable raster interrupts for option screen 
        	sta IRQMSK
        	
        	// reconfigure vic bank
        	lda #(vicMem1.get("VICBANK_MASK") & 3)	//choose one of the four 16k VIC banks, lowest two bits do the select
		sta $b0					// save lower two bits any temp
		lda CI2PRA
		and #%11111100				// upper bits are manipulated by the loader so don't mess with these
		ora $b0
		sta CI2PRA
        	
        	lda vicMem1.get("VICMEM_MASK")		// point VIC to the right stuff in the bank
		sta $d018

		jsr SILENCE_SID
		
		lda #0					// reset various sound stuff, otherwise fx player will time things wrong on first effect
		sta soundPlaying1_zp
		sta soundPlaying2_zp
		sta fxIteration1_zp
		sta fxIteration2_zp
		sta fxIteration3_zp
		sta noteIndex+0
		sta noteIndex+1
		sta noteIndex+2	
	    	    
		rts					// return to launch game




//-----------------------------------------------------------------------------------------------------------------

// Get function keys f1, f7 with provision to veto interference from joystick in control port 1

GetFn:
		ldx $dc00				// preserve port settings for joystick vs keyboard so game operates properly
		stx portA
		ldx $dc01
		stx portB
		
		ldx #$ff	
ctrlPort:
	    	stx $dc00    				// disconnect all keyboard rows
	    	cpx $dc01     				// only Control Port activity will be detected
	    	bne ctrlPort				// don't start scan until control port activity is absent

!scan:		
		lda soundPlaying2_zp			// flag for whether or not a complete cycle of tune + bell has completed
		bne !notYet+				// branch if sound sequence not ended yet
		
		lda #$ff
		sta soundPlaying2_zp			// reset sound sequence flag to restart it
		lda $a0
		eor #1				
		sta $a0					// switch to other screen type
		jmp !restorePorts+			// exit so that caller can manage screen switch

!notYet:
		lda #$fe				// connect bit 0 / keyboard row 0
		sta $dc00
		lda $dc01
		eor #$ff 
		and #%00011000
		beq !scan-
		sta $10
		
	    	stx $dc00       			// disconnect all keyboard rows
	    	cpx $dc01       			// only Control Port activity will be detected
	    	bne ctrlPort				// discard the keyscan if control port activity detected afterward	
		
!nokey:		lda #$fe				// wait for key release	
		sta $dc00
		lda $dc01 
		cmp #$ff
		bne !nokey-

!restorePorts:		
		ldx portA:#$ff
		stx $dc00
		ldx portB:#$ff
		stx $dc01
		
		rts

//-----------------------------------------------------------------------------------------------------------------
.encoding "screencode_mixed"
scoreText:
//		 0123456789012345678901234567890123456789
.const text1 =  "      H\CHSTER PUNKTESTAND: 000000      "		//5 bytes of score start at scoreText+28
.const text2 = 	"                                        "
.const text3 = 	"  SPIELER 1                  SPIELER 2  "
.const text4 = 	"   000000                     000000    "		//5 bytes of score start at scoreText+123,+150

.fill 40, text1.charAt(i)
.fill 40, text2.charAt(i)
.fill 40, text3.charAt(i)
.fill 40, text4.charAt(i)

scoreColor1:			//4 top lines of score color, variable
.fill 40, GREY
.fill 40, BLACK
scoreColor1a:
.fill 20, LIGHT_BLUE
.fill 20, LIGHT_GREEN
.fill 20, LIGHT_BLUE
.fill 20, LIGHT_GREEN
scoreColor1b:
.fill 20, LIGHT_BLUE
.fill 20, BLACK
.fill 20, LIGHT_BLUE
.fill 20, BLACK

scoreColor2:			//last line of score color, constant
.fill 15, ORANGE
.fill  4, BROWN
.fill 21, ORANGE

victoryText:
//		 0123456789012345678901234567890123456789
.const text5 =  "           ES IST VOLLBRACHT!           "		
.const text6 = 	" Der Fluch der unseligen Augen is durch "
.const text7 = 	"  Euer mutiges Handeln gebrochen. Eine  "
.const text8 = 	"   reiche Belohnung ist Euch gewiss!    "

.fill 40, text5.charAt(i)
.fill 40, text6.charAt(i)
.fill 40, text7.charAt(i)
.fill 40, text8.charAt(i)