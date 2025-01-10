/*	sound effects code for use in schreck irq handler

	2023-11-27	create from junk I had patched into update-viewports, change to macro
	2023-11-29	revert to subroutine because I seem to have time
	2024-11-17	version 2 for new sound architecture
	2024-11-23	corrected extraneous lda, retimed, switched back to macro for inlining

*/

/* 

		// timing not verified
playVoice3:
		lda stepSound_zp	//3
		and state_zp		//3		 use viewport state to do this only on alternate frames
		and #1			//2
		beq !gateOff+		//2,3		 gate off if not requested		
!gateOn:		
		lda #$81		//2		 gate on and noise
		sta VCREG3		//4		 voice 3 ctrl	
		lda #0			//2
		sta stepSound_zp	//3
		jmp !done+		//3
!gateOff:		
		lda #$80		//2 gates off
		sta VCREG3		//4			1
		bit $00			//3
		nop
		nop			//4

tEnd3:
!done:		rts			// 27 from jump and beq
*/



.macro PLAYVOICE3_A() {

		lda stepSound_zp	//3
		and state_zp		//3		 use viewport state to do this only on alternate frames
		and #1			//2
		beq !gateOff+		//2,3		 gate off if not requested		
!gateOn:												//10
		lda #$81		//2		 gate on and noise
		sta VCREG3		//4		 voice 3 ctrl	
		lda #0			//2
		sta stepSound_zp	//3
		jmp !done+		//3
!gateOff:							//11 from beq							
		lda #$80		//2 gates off
		sta VCREG3		//4			
		bit $00			//3
		nop
		nop			//4
tEnd3:
!done:								//24 from jmp, 24 from beq
			}