/*	sound effects code for use in schreck irq handler

	2023-11-22	rip from prototype code
	2023-11-28	correct for rev/bugfix of WASTE_CYCLES macro

*/
	// timed, 142 cycles from t0 to end of stabilizer at tEnd vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

playVoice1:
	lda soundPlaying1_zp		//3	// do nothing if sound not playing
	bne !checkIter+			//3	taken
	// long delay of  121 total -6 +5 -3 = 117
	WASTE_CYCLES_X(117-4)		// don't understand was off by 3 cycles not sure where those were made up? piplining effect?
	jmp !done+			//3

!checkIter:				//from bne:6 total
	lda fxIteration1_zp		//3
	beq !newData+			//2,3
	nop
	nop
	nop
	nop				//8
	jmp !reloadRegs+		//3		
	
!newData:			
	ldy #0				//2
	lda (Voice1StreamPtr_zp),y		//5
	sta fxIteration1_zp		//3				

!reloadRegs:				//from beq:22, from jmp:22	*
	ldy #1				//2
	lda (Voice1StreamPtr_zp),y		//5
	sta VCREG1			//4
	iny				//2
	lda (Voice1StreamPtr_zp),y		//5
	sta ATDCY1			//4
	iny				//2
	lda (Voice1StreamPtr_zp),y		//5
	sta SUREL1			//4
	iny				//2
	lda (Voice1StreamPtr_zp),y		//5
	sta FRELO1			//4
	iny				//2
	lda (Voice1StreamPtr_zp),y		//5
	sta FREHI1			//4
	sta halt1			//4	use msb freq == 0 to end the sound effect wavetable
					//	59		total: 59+22 = 81											
!nextIteration:	
	dec fxIteration1_zp		//5
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
	lda Voice1StreamPtr_zp		//3
	adc #6				//2
	sta Voice1StreamPtr_zp		//3
	lda Voice1StreamPtr_zp+1		//3
	adc #0				//2
	sta Voice1StreamPtr_zp+1		//3	18		

!chkHalt:				//from beq:26, from jmp:26	total=26+81 = 107	*
	lda halt1:#$ff			//2
	beq !stop+			//2,3
	bit $fe
	nop
	nop				//7
	jmp !done+			//3	


!stop:	
	lda #0				//2
	sta soundPlaying1_zp		//3	stop sound
	sta halt1			//4	reset halt
//	sta old1			//4	**********************************temp for hack


!done:					//from beq:14, from jmp:14		total for inline=107+14 = 121 cycles
 
 	//hermit version cia timer sync to remove jitter caused by lda ( ),y crossing page boundaries on occasion in code above
 	lda $dc04			//4
ckcia1:	eor #$7				//2	 if $dc04 ever = 8 this explodes, because the jump becomes +$0f.  this code needs to be placed with absolute timing such that it never has the condition $dc04=8
	sta *+4				//4
	bpl *+2				//3	+15 cycles plus the slop that is taken out
/*
	lda #$a9			// 	delay ladder...8
	lda #$a9
	lda $eaa5
*/

	cmp #$c9			// improved? delay ladder..12
	cmp #$c9			// this one is better but ruins timing fix later
	bit $ea24
	bit $ea24

	

	// timed, 142 cycles from t0 to here ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

	rts
