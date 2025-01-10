/*

	2024-01-02	derived from tunePlayer2.asm, broken up into subroutines to be called from attract mode
	2024-01-05	ready for first real use
	2024-11-11	updated symbol table load line 19 for new wavetable

*/


// repeat these definitions here since note() is used for bell frequencies in configureForBell
.const kPAL = pow(256,3)/(985248.0)	// compute SID frequencies from Atari clock divider  kPAL*floor(64000/n)
.const clock64 = 63514			// "64kHz" clock is actually not in PAL Ataris

.function note(n) {
	.if(n!=0) .return kPAL*floor(clock64/n)
	else .return 0
	}
	
#import "sound-fx-wavetables-7.sym"
.const tuneLength1 = 74		// number of note-pairs (note,duration) in tune; can get from .print in wavetable assembly
.const tuneLength2 = 52
.const tuneLength3 = 62

	
initTunePlayer:
	// does some pre-configuration that is required before irq handler routines that play the intro tune and
	// bell tolling effects are started. Envelope config is done outside depending on what screen type is selected

	//set volume
	lda #$00
	sta SIGVOL		// volume off
	sta fxIteration1_zp	// clear sound iteration
	sta fxIteration2_zp	// clear sound iteration
	sta fxIteration3_zp
	sta noteIndex+0
	sta noteIndex+1
	sta noteIndex+2

	lda #0			// fixed duty cycle 30% or something, atari I think has fixed 30% dc
	sta PWLO1
	sta PWLO2
	sta PWLO3
	lda #$06		// try to sound rougher than 50% dc
	sta PWHI1
	sta PWHI2
	sta PWHI3
	
	// gates and waves off
	lda #0
	sta VCREG3
	sta VCREG2
	sta VCREG1
	
	//note envelopes are configured for bell or tune later, depending on which one is to start first
	
	WAIT_FRAME_A()
	
	lda #$0f		// volume on
	sta SIGVOL
	
	rts

	

//-----------------------------------------------------------------------------------------------------------------

attractSounds:
	// routine that manages the music and sound effects for the attract mode screens from inside the interrupt handler(s) for those screens
	// the two subroutines PlayTune and TollBell handle the reconfig of the SID envelopes and the state transitions to chain one to the other
	// important: 	in order for this to work, soundPlaying1_zp = 0 and the SID must be configured for the tune on the first call of this routine

	lda soundPlaying1_zp
	bne !svcBell+			// select one of the two tune phases
!svcTune:
	jsr PlayTune
	rts				// internal
!svcBell:
	jsr TollBell
	rts

//-----------------------------------------------------------------------------------------------------------------

PlayTune:	
//     ------- VOICE 1 ---------	
!checkIter1:				//
	lda fxIteration1_zp		//3
	beq !newNote1+			//2,3
	jmp !continueNote1+		//3		
	
!newNote1:
	inc noteIndex+0			// next note
			
	ldy noteIndex+0			//4
	lda durationVoice1,y
	sta fxIteration1_zp
	lda freqVoice1Lo,y
	sta FRELO1			//4
	lda freqVoice1Hi,y
	sta FREHI1			//4
	beq !exit+			// don't gate if freq=0

	lda #$21			//2	gate on
	sta VCREG1			//4
	jmp !exit+
									
!continueNote1:	
	dec fxIteration1_zp		//5

	lda fxIteration1_zp
	cmp #3
	bcs !done1+
	lda #$20			//  if counter < 3, gate off
	sta VCREG1
!done1:	
	lda noteIndex+0			// bail when any part has finished
	cmp #tuneLength1-1
	bcc !exit+
	jmp !finishedTune+
!exit:	


//     ------- VOICE 2 ---------		
!checkIter2:				//
	lda fxIteration2_zp		//3
	beq !newNote2+			//2,3
	jmp !continueNote2+		//3		
	
!newNote2:
	inc noteIndex+1			// next note
			
	ldy noteIndex+1			//4
	lda durationVoice2,y
	sta fxIteration2_zp
	lda freqVoice2Lo,y
	sta FRELO2			//4
	lda freqVoice2Hi,y
	sta FREHI2			//4
	beq !exit+			// don't gate if freq=0

	lda #$21			//2	gate on
	sta VCREG2			//4
	jmp !exit+
									
!continueNote2:	
	dec fxIteration2_zp		//5

	lda fxIteration2_zp
	cmp #3
	bcs !done2+
	lda #$20			//  if counter < 3, gate off
	sta VCREG2
!done2:	
	lda noteIndex+1			// bail when any part has finished
	cmp #tuneLength2-1
	bcc !exit+
	jmp !finishedTune+
!exit:

//     ------- VOICE 3 ---------		
!checkIter3:				//
	lda fxIteration3_zp		//3
	beq !newNote3+			//2,3
	jmp !continueNote3+		//3		
	
!newNote3:
	inc noteIndex+2			// next note

	ldy noteIndex+2			//4
	lda durationVoice3,y
	sta fxIteration3_zp		
	lda freqVoice3Lo,y
	sta FRELO3			//4
	lda freqVoice3Hi,y
	sta FREHI3			//4
	beq !exit+			// don't gate if freq=0

	lda #$21			//2	gate on
	sta VCREG3			//4
	jmp !exit+
									
!continueNote3:	
	dec fxIteration3_zp		//5

	lda fxIteration3_zp
	cmp #3
	bcs !done3+
	lda #$20			//  if counter < 3, gate off
	sta VCREG3
!done3:	
	lda noteIndex+2			// bail when any part has finished
	cmp #tuneLength3-1
	bcc !exit+
	jmp !finishedTune+
!exit:


!continueTune:
	rts				// internal

!finishedTune:
	// reset all of the tune counters and gate off	   	
	lda #0
	sta noteIndex
	sta noteIndex+1
	sta noteIndex+2
	sta fxIteration1_zp
	sta fxIteration2_zp
	
	lda #$20			//  gates off, routine above leaves them on
	sta VCREG1
	sta VCREG2
	sta VCREG3	
		
	lda soundPlaying2_zp
	eor #$ff
	sta soundPlaying2_zp		// let caller know ready to flip screen

!return:						
	rts	
	
	
//-----------------------------------------------------------------------------------------------------------------
noteIndex:
.byte $00, $00, $00

TollBell:
.const bellInterval = $70
	
	lda fxIteration1_zp	// note timer for bell & rest duration
	cmp #bellInterval-4
	bcs !gateOn+
!gateOff:
	lda #$20
	sta VCREG1
	sta VCREG2
	jmp !gateDone+
!gateOn:
	lda fxIteration1_zp
	and #1
	beq !gateDone+		// skip gating if rest
	lda #$21
	sta VCREG1
	sta VCREG2
!gateDone:
	lda fxIteration1_zp	// check note timer
	beq !newCycle+
	jmp !exit+		// else done	
!newCycle:
	lda #bellInterval	// reset note timer
	sta fxIteration1_zp
	dec fxIteration3_zp	// decrement sequence counter

!exit:
	dec fxIteration1_zp   	// dec note timer

	lda fxIteration3_zp	// check sequence counter
	bmi !finishedBell+

 
!continueBell:
	rts			// internal


!finishedBell:
	// reset the counters	   	
	lda #0
	sta fxIteration1_zp
	sta fxIteration3_zp
	sta FREHI1
	sta FREHI2
	lda #1
	sta FRELO1
	sta FRELO2
	
	lda soundPlaying2_zp
	eor #$ff
	sta soundPlaying2_zp	// let caller know ready to flip screen
				
!skip:					
	rts
	
//-----------------------------------------------------------------------------------------------------------------

configureForBell:
	lda #7				// number of times to ring bell
	sta fxIteration3_zp

configureForBell_:			// alternate entry that reconfigures without disturbing iteration counter
	lda #1				// set flag to bell
	sta soundPlaying1_zp
	
	// configure voice 1 and 2 envelopes for bell sound
	lda #$01
	sta ATDCY1
	sta ATDCY2
	lda #$cb		// longest tune note is 720ms, shortest is 120ms
	sta SUREL1
	sta SUREL2
	
	// and note frequencies
	lda #<note($ff*2)
	sta FRELO1
	lda #>note($ff*2)
	sta FREHI1
	lda #<note($fd*2)
	sta FRELO2
	lda #>note($fd*2)
	sta FREHI2
	
	// kill voice 3
	lda #0
	sta VCREG2
	sta FRELO3
	sta FREHI3
	
	rts
	
//-----------------------------------------------------------------------------------------------------------------
	
configureForTune:
	lda #0			// set flag to tune
	sta soundPlaying1_zp
	
	//set envelopes for tune
	lda #$01
	sta ATDCY1
	sta ATDCY2
	sta ATDCY3
	lda #$b5		// longest tune note is 720ms, shortest is 120ms
	sta SUREL1
	sta SUREL2
	sta SUREL3
	
	rts

//-----------------------------------------------------------------------------------------------------------------
	
configureForLightning:
	//set envelope for lightning
	lda #$02
	sta ATDCY3
	lda #$c9			//$c8		
	sta SUREL3
	
	rts	