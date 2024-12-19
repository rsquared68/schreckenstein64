/*	sound effects code for use in schreck irq handler

	2023-11-22	rip from prototype code
	2023-12-03	longer delay ladder for more flexibility
	2023-12-04	fine tune w.r.t. badlines coming and going

	2024-11-24	new idea: stabilizer should only stabilize unstable part of path
	2024-12-01	this was difference between crash and work for new sound arch with pre-empt bit

*/
	// timed		vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

playVoice1:
	lda soundPlaying1_zp		//3	// do nothing if sound not playing
	bne !checkIter+			//3,2	

	WASTE_CYCLES_X(137-8  +1)	// delay if no sound.  playVoice2 to !stop = 137, but have 5 above and 3 for jmp below
					// +1 cycle seen when normal sound plays
					// tune for least disturbance to grey/black transition when sound playing, needed to add another below in nextIteration
	jmp !stop+			//3

!checkIter:				//from bne:6 total
 	lda fxIteration1_zp		//3
	beq !newData+			//2,3
	nop
	nop				
	nop
	nop				//8
	jmp !reloadRegs+		//3
	
!newData:				//		12 from beq
	ldy #0				//2				
	lda (Voice1StreamPtr_zpw),y	//5		This load will never cross a page boundary because the index y=0
	sta fxIteration1_zp		//3				  

!reloadRegs:				//from beq:22, from jmp:22	
	ldy #1				//2
	lda (Voice1StreamPtr_zpw),y	//5		These loads can result in a page boundary being crossed
	sta VCREG1			//4		e.g. if >ptr = $ff, every load will cross the page and 5 cycles are lost
	iny				//2
	lda (Voice1StreamPtr_zpw),y	//5
	sta ATDCY1			//4
	iny				//2
	lda (Voice1StreamPtr_zpw),y	//5
	sta SUREL1			//4
	iny				//2
	lda (Voice1StreamPtr_zpw),y	//5
	sta FRELO1			//4
	iny				//2
	lda (Voice1StreamPtr_zpw),y	//5
	sta FREHI1			//4
	sta halt1			//4	use msb freq == 0 to end the sound effect wavetable
					//	59		total: 59+22 = 81			


	// Experimental stabilizer ---------------------------------------------------------------------------------------------

					//		if msb of pointer = $ff 5 cycles, $fe 4 cycles, $fd 3 cycles ... $fb 1 cycle of delay introduced by lda (),y
	lda Voice1StreamPtr_zpw		//3		compute $ff-ptr lsb
	sec				//2
	sbc #$fb			//2		0 to 4 for $fb to $ff, want 7 cycles to 2 cycles added
ckd1:	sta variDly1			//4		PC + twos complement offset, so 0 is the next instruction after bcc below
	cmp #5				//2											13 cycles here
	bcc !doVari+			//2,3		do variable delay if A < 5
	nop
	nop
	nop
	nop				//8
	jmp !end+			//3

!doVari:				//											16 cycles here
	bcc variDly1:*+2		//3		bit does not touch carry						19
	cmp #$c9			//2 		delay ladder...2 to 7 cycles
	cmp #$24			//2 
	nop				//2	  	 C9 C9 C9 24 EA	

!end:					//											(25 to 21), 26 otherwise

	// Experimental stabilizer ---------------------------------------------------------------------------------------------
	//															81+26 = 107

!nextIteration:					//start new count
	dec fxIteration1_zp		//5
	beq !incPointer+		//2,3
	//bit $fe

	nop				//
	nop				//  	empirically added an extra cycle
	
	nop
	nop
	nop				//				
	nop
	nop
	nop				//15	16 are actually needed
	jmp !chkHalt+			//3

!incPointer:					// 8 from beq		     
	// 6 elements per step							
	clc				//2
	lda Voice1StreamPtr_zpw		//3
	adc #6				//2
	sta Voice1StreamPtr_zpw		//3
	lda Voice1StreamPtr_zpw+1	//3
	adc #0				//2
	sta Voice1StreamPtr_zpw+1	//3	
	

!chkHalt:					//from beq:25, from jmp:25	total 107+25=132
	lda halt1:#$ff			//2
	beq !stop+			//2,3
	bit $fe
	nop
	nop				//7
	jmp !done+			//3	

!stop:						//5 from beq			total 132+5=137
	lda #0				//2
	sta soundPlaying1_zp		//3	stop sound
	sta halt1			//4	reset halt

!done:					//from beq:14, from jmp:14		total for inline=132+14=146 cycles
	rts
	