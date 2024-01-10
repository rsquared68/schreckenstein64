/*	sound effects code for use in schreck irq handler

	2023-11-22	rip from prototype code
	2023-12-03	longer delay ladder for more flexibility
	2023-12-04	fine tune w.r.t. badlines coming and going

*/
	// timed, 146 cycles from t0 to end of stabilizer at tEnd vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

playVoice2:
	lda soundPlaying2_zp		//3	// do nothing if sound not playing
	bne !checkIter+			//3	taken
	// long delay of  121 total -6 +5 -3 = 117
	WASTE_CYCLES_X(117-4   -1)	// exactly what is happening here depends on where badlines are in lower half of SB2,
					// tune for least disturbance to grey/black transition when sound playing
	jmp !done+			//3

!checkIter:				//from bne:6 total
	lda fxIteration2_zp		//3
	beq !newData+			//2,3
	nop
	nop
	nop
	nop				//8
	jmp !reloadRegs+		//3		
	
!newData:			
	ldy #0				//2
	lda (Voice2StreamPtr_zp),y		//5
	sta fxIteration2_zp		//3				

!reloadRegs:				//from beq:22, from jmp:22	*
	ldy #1				//2
	lda (Voice2StreamPtr_zp),y		//5
	sta VCREG2			//4
	iny				//2
	lda (Voice2StreamPtr_zp),y		//5
	sta ATDCY2			//4
	iny				//2
	lda (Voice2StreamPtr_zp),y		//5
	sta SUREL2			//4
	iny				//2
	lda (Voice2StreamPtr_zp),y		//5
	sta FRELO2			//4
	iny				//2
	lda (Voice2StreamPtr_zp),y		//5
	sta FREHI2			//4
	sta halt2			//4	use msb freq == 0 to end the sound effect wavetable
					//	59		total: 59+22 = 81											
!nextIteration:	
	dec fxIteration2_zp		//5
	beq !incPointer+		//2,3
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop				//16
	jmp !chkHalt+			//3

!incPointer:	
	// 6 elements per step
	clc				//2
	lda Voice2StreamPtr_zp		//3
	adc #6				//2
	sta Voice2StreamPtr_zp		//3
	lda Voice2StreamPtr_zp+1		//3
	adc #0				//2
	sta Voice2StreamPtr_zp+1		//3	18		

!chkHalt:				//from beq:26, from jmp:26	total=26+81 = 107	*
	lda halt2:#$ff			//2
	beq !stop+			//2,3
	bit $fe
	nop
	nop				//7
	jmp !done+			//3	


!stop:	
	lda #0				//2
	sta soundPlaying2_zp		//3	stop sound
	sta halt2			//4	reset halt


!done:					//from beq:14, from jmp:14		total for inline=107+14 = 121 cycles
 
 	//hermit version cia timer sync to remove jitter caused by lda ( ),y crossing page boundaries on occasion in code above
 	lda $dc04			//4
ckcia2:	eor #$7				//2	 if $dc04 ever = 8 this explodes, because the jump becomes +$0f.  this code needs to be placed with absolute timing such that it never has the condition $dc04=8
	sta *+4				//4
	bpl *+2				//3	+15 cycles plus the slop that is taken out

	cmp #$c9			// improved? delay ladder...12
	cmp #$c9			// 
	bit $ea24
	bit $ea24

/* 
	lda #$a9			// 	delay ladder...8
	lda #$a9
	lda $eaa5
*/

	// timed, 146 cycles from t0 to here ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	rts
	