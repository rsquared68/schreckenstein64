/*	sound effects code for use in schreck irq handler


	2022-11-22	sound manager ripped from soundfx-rle-2
	2022-11-26	-hack  using voice 3 for footsteps
	2022-11-28	consolidated "bit 1" avoidance as footstep handled by voice 3, FXarbTable no longer references the footstep sound
			adjusted for rev/bugfix of WASTE_CYCLES macro
	2022-12-04	Break up into macros for inlining

	2024-11-11	v4, new sound architecture
	2024-11-22	v5, added sound queue macros
	2024-11-23	v6 handle pre-empt flags
*/



// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv  needs to be constant time  vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
		
.macro SNDMGRPHASE1_AX() {				

// 	v3 was 28 cycles, no stabilizer.  v6 needs to check for pre-empt, 50 cycles.

//	in this phase, simply load voice control registers if sound is not playing on that channel

	lda p2Sound_zp			//3
	and #$7f			//2	check if pre-empt bit is set, stripping it in A at the same time
	cmp p2Sound_zp			//3
	beq !check2busy+		//2,3	if no, check if voice already busy
	nop				//2
	jmp !load2+			//3	else load over whatever's already going (jmp 1)

!check2busy:										// 11
	ldx soundPlaying2_zp		//2	don't destroy A!					
	bne !dly+			//2,3	busy, don't load.  this sound will be lost at the end of phase 3

!load2:											// 15 via (jmp 1), 15 via beq 
	sta voice2			//4
	jmp !skip+			//3	(jmp 2)

!dly:	//delay bc skipped load		//via bne:16
	nop				
	nop
	nop				//6

!skip:											// 22 via (jmp 2), 22 through dly 
	lda p1Sound_zp			//3
	and #$7f			//2	check if pre-empt bit is set, stripping it in A at the same time
	cmp p1Sound_zp			//3
	beq !check1busy+		//2,3	if no, check if voice already busy
	nop				//2
	jmp !load1+			//3	else load over whatever's already going (jmp 1)

!check1busy:										// 11
	ldx soundPlaying1_zp		//2	don't destroy A!					
	bne !dly+			//2,3	busy, don't load.  this sound will be lost at the end of phase 3

!load1:											// 15 via (jmp 1), 15 via beq 
	sta voice1			//4
	jmp !end+			//3	(jmp 2)

!dly:	//delay bc skipped load		//via bne:16
	nop				
	nop
	nop				//6

!end:					//	total 44 cycles	
//												---------------------------------
//												      no stabilizer needed
//												---------------------------------
}
//  -----------------------------------------------------------------------------------------------------------------------------


.macro SNDMGRPHASE2_AX() {

//	v3 was 36 cycles

//	In this phase, load voice 1
		
!doVoices:
	ldx @voice1:#00			//2	
	bne !load+			//2,3
	WASTE_CYCLES_X(17)
	jmp !skip+			//3

!load:	
	lda soundMapLo,x		//4							     confined to one page
	sta Voice1StreamPtr_zpw		//3
	lda soundMapHi,x		//4							     confined to one page
	sta Voice1StreamPtr_zpw+1	//3	initialize pointer to start of sound

	lda #$ff			//2
	sta soundPlaying1_zp		//3	start sound, this triggers the handler for voice 1 to do something
!skip:

//													24 cycles
//												---------------------------------
//												      no stabilizer needed
//												---------------------------------
	}
//  -----------------------------------------------------------------------------------------------------------------------------


.macro SNDMGRPHASE3_AX() {	

//	v3 was 38 cycles

//	In this phase, load voice 2

!doVoice2:
	ldx @voice2:#00			//2
	bne !load+			//2,3
	WASTE_CYCLES_X(17)
	jmp !done+			//3	
!load:	
	lda soundMapLo,x		//4							  
	sta Voice2StreamPtr_zpw		//3
	lda soundMapHi,x		//4							     confined to one page
	sta Voice2StreamPtr_zpw+1	//3

	lda #$ff			//2
	sta soundPlaying2_zp		//3	start sound, this triggers the handler for voice 2 to do something

!done:
  					//through bne:24; through jmp1:24
	lda #0				//2
	sta voice1			//4	need to clear these bc ptr-loader detects on these
	sta voice2			//4	
				
//													34 cycles
//												---------------------------------
//												      no stabilizer needed
//												---------------------------------

}

//  -----------------------------------------------------------------------------------------------------------------------------
		
.macro PUSHSOUNDONQUEUE_X() {	// push a sound onto the sound queue to be played whenever voice is free
	// needs sound index in A
	ldx SoundStackPtr_zp	//3
	cpx #SoundStackDepth	//2
	bcs !stackFull+		//3,2
	sta SoundStack_zp,x	//4
	inc SoundStackPtr_zp	//5
!stackFull:	
		}
		
//  -----------------------------------------------------------------------------------------------------------------------------
		
.macro MANAGESOUNDQUEUE_AX() { // dequeue sounds when a voice is free, not overwriting other loads
		ldx SoundStackPtr_zp		//3
		beq !EXIT+			//3,2
!getSound:
		lda SoundStack_zp-1,x		//4		
!tryVoice2:
		ldx p2Sound_zp			//3 		has something else already got a sound pending?
		bne !tryOther+			//3,2		yes, try other voice
		ldx soundPlaying2_zp		//3		is voice 2 busy?			are these better of using voice2?
		bne !tryOther+			//3,2		don't overwrite	
		sta p2Sound_zp			//3		A still holds sound from above
		jmp !success+			//3		
!tryOther:
		ldx p1Sound_zp			//3		has something else already got a sound pending?
		beq !EXIT+			//3,2		yes, bail
		ldx soundPlaying1_zp		//3		is voice 1 busy?
		bne !EXIT+			//3,2		don't overwrite
!otherOK:
		sta p1Sound_zp			//3
				
!success:	dec SoundStackPtr_zp		//5		only move the stack ptr if we loaded the sound into reg 1 or 2                               
                                 
!EXIT:         
		}		