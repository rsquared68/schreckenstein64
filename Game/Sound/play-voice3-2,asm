/*	sound effects code for use in schreck irq handler

	2023-11-27	create from junk I had patched into update-viewports, change to macro
	2023-11-29	revert to subroutine because I seem to have time

*/

		// timing not verified
playVoice3:
		lda SoundStateLo_zp	//3
		and state_zp		//3		 use viewport state to do this only on alternate frames
		and #1			//2
		beq !gateOff+		//2,3		 gate off if not requested		
!gateOn:		
		lda #$81		//2		 gate on and noise
		sta VCREG3		//4		 voice 3 ctrl
		lda SoundStateLo_zp	//3		
		and #$fe		//2
		sta SoundStateLo_zp	//3
		jmp !done+		//3
!gateOff:		
		lda #$80		//2 gates off
		sta VCREG3		//4			17 from start
		nop
		nop
		nop
		nop
		nop			//10
tEnd3:
!done:		rts			// 27 from jump and beq






// macro version for inlining
/* 
.macro PLAYVOICE3_A() {
		// timing not verified
playVoice3:
		lda SoundStateLo_zp	//3
		and state_zp		//3		 use viewport state to do this only on alternate frames
		and #1			//2
		beq !gateOff+		//2,3		 gate off if not requested		
!gateOn:		
		lda #$81		//2		 gate on and noise
		sta VCREG3		//4		 voice 3 ctrl
		lda SoundStateLo_zp	//3		
		and #$fe		//2
		sta SoundStateLo_zp	//3
		jmp !done+		//3
!gateOff:		
		lda #$80		//2 gates off
		sta VCREG3		//4			17 from start
		nop
		nop
		nop
		nop
		nop			//10
tEnd3:
!done:					// 27 from jump and beq
}
*/
	