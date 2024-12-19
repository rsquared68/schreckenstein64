/*	sound effects code for use in schreck irq handler


	2022-11-22	sound manager ripped from soundfx-rle-2
	2022-11-26	-hack  using voice 3 for footsteps
	2022-11-28	consolidated "bit 1" avoidance as footstep handled by voice 3, FXarbTable no longer references the footstep sound
			adjusted for rev/bugfix of WASTE_CYCLES macro
	2022-12-04	Break up into macros for inlining
*/



// vvvvvvvvvvvvvvvvvvvvvvvvvvvvvv  needs to be constant time  vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
		
.macro SNDMGRPHASE1_AX() {				

// do the lookup and arbitration for the $cb controlled sound effects via a table
// Convert $cb into 256 values, where the high and low nybbles of the return value contain the effect indices to be stuffed

	ldx $cb				//2
	lda FXarbTable,x		//4							     confined to one page
	tax				//2
	and #$0f			//2   
	sta voice1			//4
	txa				//2
	lsr				//2
	lsr				//2
	lsr				//2
	lsr				//2
	sta voice2			//4								28 cycles		
//												---------------------------------
//												      no stabilizer needed
//												---------------------------------
}

.macro SNDMGRPHASE2_AX() {
// if $cc has a value other than $ff it should pre-empt voice 2

	ldx $cc				//3
	cpx #$ff			//2
	bne !reloadVoice2+		//2,3
	nop				//2
	jmp !doVoices+			//3

!reloadVoice2:
	stx voice2			//4
		
!doVoices:
					//from bne:12, from jmp:12	
	ldx @voice1:#00			//2	sound 1 is always pre-emptable
	bne !load+			//2,3
	WASTE_CYCLES_X(17)
	jmp !skip+			//3

!load:	
	lda sound1MapLo,x		//4							     confined to one page
	sta Voice1StreamPtr_zp		//3
	lda sound1MapHi,x		//4							     confined to one page
	sta Voice1StreamPtr_zp+1	//3	initialize pointer to start of sound

	lda #$ff			//2
	sta soundPlaying1_zp		//3	start sound, this triggers the handler for voice 1 to do something
!skip:

//													36 cycles
//												---------------------------------
//												      no stabilizer needed
//												---------------------------------
	}


.macro SNDMGRPHASE3_AX() {			
	lda soundPlaying2_zp		//3	voice 2 is blocking
	beq !doVoice2+			//2,3
	WASTE_CYCLES_X(22+1)
	jmp !done+			//3

!doVoice2:
	ldx @voice2:#00			//2
	bne !load+			//2,3
	WASTE_CYCLES_X(17)
	jmp !done+			//3	
!load:	
	lda sound1MapLo,x		//4							     confined to one page
	sta Voice2StreamPtr_zp		//3
	lda sound1MapHi,x		//4							     confined to one page
	sta Voice2StreamPtr_zp+1	//3

	lda #$ff			//2
	sta soundPlaying2_zp		//3	start sound, this triggers the handler for voice 2 to do something

!done:					//through beq,bne:30; through jmp1:30; through beq,jmp2:30	total = 30+101 = 131
	lda $cb				//2
	and #1				//2  don't touch bit 1 footstep is separate
	sta $cb				//3
	lda #$ff			//2
	sta $cc				//3	12							
//													38 cycles
//												---------------------------------
//												      no stabilizer needed
//												---------------------------------

}
	

