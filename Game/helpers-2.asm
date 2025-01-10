/* 	helper routines specific to commodore, in a separate block to help me with the memory utilization planning


//	New helper subroutines specific to C64 architecture, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.

	2023-10-07	initial
	2023-10-19	bugfix in clear_screen_1
	2024-01-04	v2 move deglitch-strips elsewhere


*/

// --------------------------------------------------------------------------------------------------
CLEAR_SCREEN_1:
		// clear screen 1 (screen 2 has stuff in it that must be preserved)
		ldx #250
		lda #$20							
!lp:			
		sta screenRam1-1,x	
		sta screenRam1-1+250,x		
		sta screenRam1-1+500,x
		sta screenRam1-1+750,x
			
		dex
		bne !lp-
		
		rts

// --------------------------------------------------------------------------------------------------
/*   GET_JOYSTICK no longer exists as it's been inlined
WAIT_TRIGGER:
	// wait for any trigger
	lda #0
	jsr GET_JOYSTICK
	lda #1
	jsr GET_JOYSTICK
	lda PlayerJoyTrigger
	and PlayerJoyTrigger+1
	bne WAIT_TRIGGER
	
	rts
*/	

// --------------------------------------------------------------------------------------------------	
SILENCE_SID:
		// turn sound off
		lda #0				// turn off SID volume
		sta SIGVOL

RESTART_WAVES_ENVELOPES:		//alternate entry point
		// gates and waves off
		sta VCREG3
		sta VCREG2
		sta VCREG1
		
		// restart config
		lda #$0f
		sta ATDCY1
		sta ATDCY2
		sta ATDCY3
		lda #$00
		sta SUREL1
		sta SUREL2
		sta SUREL3
	 	
	 	rts

// --------------------------------------------------------------------------------------------------
RETURN_OBJECT_TO_MAP: //rjr code
		// take object from player inventory and return it to the map
		// player index in X
	
		//ldx PlayerIndex_zp
		lda PlayerInventory,x		// if player has nothing, don't do it
		beq !EXIT+
	
		lda #$00                                   
		sta PlayerInventory,x		// clear player inventory
			                                                       
		//lda #$00                     
		clc           			// get pointer to taskbar tile
		adc StatusBarTaskPtr,x       
		sta map11_zpw                   
		       
		txa                          	// add player # to msb    
		adc #$7c                    	// player 1 should write to 7c00+2, player 2 7db8+2
		//adc #$00                     
		sta map11_zpw+1
		                        
		lda #$00                     
		ldy #$00                     
		sta (map11_zpw),y	  	// clear taskbar tile
		
		lda functionalTileTable+1       // getting the tile type for the level the first entry 0 = blank space/nothing
		sta $a0                      
		//lda $a0                      
		jsr PLOT_1_ON_FLOOR
	
!EXIT:		rts 

// --------------------------------------------------------------------------------------------------
COPY_SCORES:	
		// copy scores from game screen ram into score display screen buffer
		ldy #05		
!lp:		
		lda $7c13-1,y	// player 1
		clc
		adc #$20	// translate back to petscii
		sta scoreText-1+124,y
		
		lda $7dcb-1,y	// player 2
		clc
		adc #$20
		sta scoreText-1+151,y
		
		lda NumPlayers	// overwrite player 2 with zeros (in 1 player mode screen ram is blanks)
		beq !n+		// 0 --> 2 player mode
		lda #$30	
		sta scoreText-1+151,y
!n:		
		dey
		bne !lp-
		
		rts
		
// --------------------------------------------------------------------------------------------------
UPDATE_HIGHSCORE:
		// update highscore and copy into the score display screen buffer

!doPlayer1:		
		lda L060d
		cmp HighScore
		lda L060d+1
		sbc HighScore+1
		bcc !doPlayer2+		// branch if highScore is bigger, don't need to update highscore
		
		// set high to player 1	
		lda L060d
		sta HighScore
		lda L060d+1
		sta HighScore+1
	
!doPlayer2:			
		lda L060f
		cmp HighScore
		lda L060f+1
		sbc HighScore+1
		bcc !updateBuf+		// branch if highScore is bigger, don't need to update highscore
		
		// set high to player 2	
		lda L060f
		sta HighScore
		lda L060f+1
		sta HighScore+1
	
!updateBuf:
		lda #<(scoreText+29)
		sta scoreScreenLoc
		lda #>(scoreText+29)
		sta scoreScreenLoc+1
		lda HighScore
		sta num
		lda HighScore+1	//$60e
		sta num+1
		ldy #(4-1)		// 4 decimal digits 
		jsr Scrn16toDec		// generate score in screencodes
  		
		ldy #04			// not done yet because buffer is petscii		
!lp:		lda scoreText+29-1,y	// -1 because trailing zero is just a fixed object not part of the real score
		clc
		adc #$20		// translate back to petscii
		sta scoreText+29-1,y
				
		dey
		bne !lp-
				
		rts
		

		