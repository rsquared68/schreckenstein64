/*  Some macros specific to Schreckenstein port, including some things used for inlining for speed

//	New helper macros specific to C64 architecture, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.


	2023-02-13
	2023-10-25
	2023-12-06	modified A_BETWEEN_XY so it doesn't trash $a0, $a1 from inside irq
*/


.macro A_BETWEEN_XY_IRQ() {
			stx temp1	//$a1        // "tempN" variables are for inside irq handler only!                              
			cmp temp1	//$a1                      
			bcc !A_OUTSIDE_RANGE+        // branch if A < $a1 = X
			sta temp0	//$a0                      
			cpy temp0	//$a0                      
			bcc !A_OUTSIDE_RANGE+	     // branch if A > Y

!SUCCESS:		lda #1                            
                        bne !DONE+                   // save a cycle 
                                                         
!A_OUTSIDE_RANGE:	lda #0                                            
!DONE:
}

.macro A_BETWEEN_XY() {
			stx $a1        // "tempN" variables are for inside irq handler only!                              
			cmp $a1                      
			bcc !A_OUTSIDE_RANGE+        // branch if A < $a1 = X
			sta $a0                      
			cpy $a0                      
			bcc !A_OUTSIDE_RANGE+	     // branch if A > Y

!SUCCESS:		lda #1                            
                        bne !DONE+                   // save a cycle 
                                                         
!A_OUTSIDE_RANGE:	lda #0                                            
!DONE:
}


.macro SETTASKBAR_AXY(task_addr, disp_addr) {	// displays task completion status starting at disp_addr, e.g. low nybble lit lanterns, high nybble carried candles

		lda task_addr
		sta complete+1
		and #%00000111
		sta npart+1
		ldx #00
		lda #$04 //filled circle
npart:		cpx #00
		beq complete
		sta disp_addr,x
		inx
		jmp npart
		
		lda #%01110000
complete:	and #00
		lsr
		lsr
		lsr
		lsr
		sta ncomp+1
		lda #$03 //open circle
		ldy #00
ncomp:		cpy #00
		beq done
		sta disp_addr,x
		iny
		inx
		jmp ncomp
done:		
}

/*	make sure not to use anymore 
.macro SAVEPARAMETERS_A() {	// saves subroutine parameters across irq events
		.for(var zpa=$a0; zpa<$a5; zpa++) {  
		lda zpa
		sta zpa+$10	//e.g. $a0-->$b0 etc
		}

		lda PlayerIndex_zp
		sta $eb
		lda $84
		sta $ec
}

.macro RESTOREPARAMETERS_A() {	// restores subroutine parameters across irq events
		.for(var zpa=$a0; zpa<$a5; zpa++) {  
		lda zpa+$10
		sta zpa		//e.g. $b0-->$a0 etc
		}
		
		lda $eb
		sta PlayerIndex_zp
		lda $ec
		sta $84
}
*/

/*
.macro SAVEPLAYERINDEX_A() {	// saves subroutine parameters across irq events
		lda PlayerIndex_zp
		sta keepPlayerIndex_zp
		}

.macro RESTOREPLAYERINDEX_A() {	// restores subroutine parameters across irq events	
		lda keepPlayerIndex_zp
		sta PlayerIndex_zp		
		}
*/		

.macro STEPCHARSETANIM_AX() {	// animate via character set pointer every 8 frames
	inc frameCtr_zp		//5
	lda frameCtr_zp		//3
	and #$07		//2
	beq !increment+		//2,3
	WASTE_CYCLES_X(24)	//24
	jmp !skip+		//3
!increment:					//13
	inc animCtr_zp		//5
	lda animCtr_zp		//3
	cmp #4			//2		same # cycles as counting backwards unless you re-order the charset
	beq !reset+		//2,3
	bit $fe			//3
	jmp !animate+		//3
!reset:
	lda #0			//2	
	sta animCtr_zp		//3
!animate:		
	//lda @animCtr		// already loaded 				31
	asl			//2
	and #%00001110		//2
	sta charsetMask		//4		long path total:39 cycles	
!skip:
		}
		

.macro CHKPAUSE_A(zp_add) {	// look for shift key
	lda #$fd		//2 connect bit 1 / keyboard row 1 for left-shift/shift-lock
	sta CIAPRA		//4
	lda CIAPRB		//4
	and #$80		//2 bit 7 is shift
	sta zp_add		//3
		
	lda #$ff		//2 restore joystick
	sta CIAPRA		//4							21 cycles
		}	