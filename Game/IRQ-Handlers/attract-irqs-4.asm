/*  not enough room to tack this on to viewport irqs, break out and load elsewhere

//	Ground-up rewrite of option/attract/victory screens, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.


	2023-12-21	option/"attract" screen only
	2023-12-23	v2, provision for option and highscore screens
	2024-01-05	v3, added tune player, bell and lightning, waving flag

*/

//======================================================================================================
//	INTERRUPT -- 	DOES CHAR POINTER FLIPPING, BACKGROUND COLOR CHANGING, AND RASTERBAR DRAWING
//			FOR OPTION/ATTRACT SCREENS (NOT PART OF GRAPHIC KERNEL FOR GAMEPLAY)
//======================================================================================================

.align $100
irq_option:
		PRESTABILIZE_RASTER_AXS(irq_option_)	// 64-71 cycles after start of entry line

//======================================================================================================
//	INTERRUPT -- 	STABILIZED CODE FOR ATTRACT SCREENS
//======================================================================================================
irq_option_:
		FINESTABILIZE_RASTER_AXS()	
		WASTE_CYCLES_X(9)
		
		lda #GREEN
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #CYAN
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #LIGHT_GREEN
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		lda #LIGHT_GREY
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #CYAN
		sta EXTCOL	//border
		sta BGCOL0	//background
		//flip to atari font initial test in vicbank 0 put atari font at offset $3000
		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11101100
		sta $d018
		WASTE_CYCLES_X(63-10-6)	
		
		lda #GREEN
		sta EXTCOL	//border
		sta BGCOL0	//background


		WAIT_UNTIL_RASTERLSB_A($db)
ct:		WASTE_CYCLES_X(52-31)
		lda #DARK_GREY
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #LIGHT_BLUE
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #CYAN
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		lda #LIGHT_BLUE
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		lda #DARK_GREY
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		
		lda #BLUE
		sta EXTCOL	//border
		sta BGCOL0	//background

		
		WAIT_UNTIL_RASTERLSB_A($eb)
		WASTE_CYCLES_X(52-31)
		lda #BROWN
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #ORANGE
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)
		lda #LIGHT_RED
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		lda #ORANGE
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		lda #BROWN
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)	
		
		lda #RED
		sta EXTCOL	//border
		sta BGCOL0	//background

		// gets here on line $f6
		WAIT_UNTIL_RASTERLSB_A($ff)
		WASTE_CYCLES_X(61)
		WAIT_UNTIL_RASTERLSB_A($09)
		WASTE_CYCLES_X(50)
		
		lda #BLACK
		sta EXTCOL	//border
		sta BGCOL0	//background

		//flip back to petscii font
		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11100100
		sta $d018
		
		// cycle colors of "f7" and player number
		inc $a2						// also used to select a random seed
		lda $a2
		lsr
		lsr
		lsr
		and #$0f
		tax
		lda attractColorTbl1,x
		sta colorRam+$37f				// color mem at required offsets
		lda attractColorTbl2,x
		sta colorRam+$37f+81
		sta colorRam+$37f+82
		
		jsr waveFlag				// wave flag

		jsr attractSounds			// play the intro tune and bell tolling effects

		SET_6502_IRQ_VECTOR_A(irq_option)
		
		lda #$ca   				// rasterline at which to launch the irq handler 
	        sta RASTER

		lsr VICIRQ					// acknowledge this raster interrupt serviced	
	
		pla
		tay       
		pla
		tax     
		pla
	   
		rti

attractColorTbl1:
.byte BLUE, DARK_GREY, PURPLE, LIGHT_BLUE, CYAN, LIGHT_GREEN, LIGHT_GREY, WHITE, LIGHT_GREY, LIGHT_GREEN, CYAN, LIGHT_BLUE, PURPLE, DARK_GREY, BLUE, BLACK
attractColorTbl2:
.byte RED, ORANGE, LIGHT_RED, LIGHT_GREY, YELLOW, WHITE, YELLOW, LIGHT_GREY, LIGHT_RED, ORANGE, RED, DARK_GREY, BROWN, BLACK, BROWN, DARK_GREY

// last check ends at $97db so not a lot of gap to the next page




.align $100
//.pc = * "irq_highscore"
irq_highscore:
		PRESTABILIZE_RASTER_AXS(irq_highscore_)	// 64-71 cycles after start of entry line

//======================================================================================================
//	INTERRUPT -- 	STABILIZED CODE FOR ATTRACT SCREENS
//======================================================================================================
irq_highscore_:
		FINESTABILIZE_RASTER_AXS()	
		WASTE_CYCLES_X(9+63+63)
		
		lda #LIGHT_GREY
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10-6)

		
		//flip to atari font initial test in vicbank 0 put atari font at offset $3000
		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11101100
		sta $d018
		
		lda #BLACK
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)


		WAIT_UNTIL_RASTERLSB_A($db)
		WASTE_CYCLES_X(63-10+15)
		lda #LIGHT_GREY
		sta EXTCOL	//border
		sta BGCOL0	//background
		WASTE_CYCLES_X(63-10)			
		lda #BLACK
		sta EXTCOL	//border
		sta BGCOL0	//background

		

		// gets here on line $f6
		WAIT_UNTIL_RASTERLSB_A($ff)
		WASTE_CYCLES_X(61)
		WAIT_UNTIL_RASTERLSB_A($10)
		WASTE_CYCLES_X(50)
		
		//flip back to petscii font
		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11100100
		sta $d018

 		
		// cycle colors of 6-digit hiscore
		inc $a2					// also used as a random seed
		lda $a2
		lsr
		lsr
		//lsr					// faster
		and #$1f				// here use all 32 colors i.e. both tables
		tax
		lda attractColorTbl1,x					
		sta colorRam+$33c
		sta colorRam+$33c+1
		sta colorRam+$33c+2
		sta colorRam+$33c+3
		sta colorRam+$33c+4
		sta colorRam+$33c+5

		jsr waveFlag				// wave flag

		jsr attractSounds			// play the intro tune and bell tolling effects
			

		SET_6502_IRQ_VECTOR_A(irq_highscore)
		
		lda #$ca   				// rasterline at which to launch the irq handler 
	        sta RASTER

		lsr VICIRQ				// acknowledge this raster interrupt serviced	
	
		pla
		tay       
		pla
		tax     
		pla
	   
		rti



.align $100
//.pc = * "irq_victory"
irq_victory:
		PRESTABILIZE_RASTER_AXS(irq_victory_)	// 64-71 cycles after start of entry line

//======================================================================================================
//	INTERRUPT -- 	STABILIZED CODE FOR ATTRACT SCREENS
//======================================================================================================
irq_victory_:
		FINESTABILIZE_RASTER_AXS()	
		WASTE_CYCLES_X(9+63+63+63)
		lda #BLACK
		sta EXTCOL	//border
		sta BGCOL0	//background
	
		lda #$c8
		sta SCROLX	
	
		//flip to atari font initial test in vicbank 0 put atari font at offset $3000
		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11101100
		sta $d018


		// got time so why not figure out if their should be lightning
		lda #BLACK				// defaults
		sta skyColor
		lda #$c8
		sta xShaker
		
		lda $a2
		cmp #$60				// only allow lightning part of the time
		bcc !n+					// branch if A < $60
		
		jsr GenRandom				// use result returned in rng_zp_low, high or A
		cmp #$30
		bcs !n+					// if random >= $30, skip the flash

		lda #DARK_GREY				// else change sky color, shake screen and make noise
		sta skyColor
		lda rng_zp_low
		and #3					// don't make it too severe lol
		ora $c8
		sta xShaker
		lda #$81
		sta VCREG3				// gate thunder. voices 1&2 used for bell
		jmp !bottomRasterBar+			
!n:
		lda #$80				// else ungate and change freq
		sta VCREG3
		lda $a2					// want sort of fast downward sweep from 0800 to 0200
		eor #$ff
                tax
                asl
		and #$07 
		sta FREHI3
		txa
		and #$07
		sta FRELO3
		
!bottomRasterBar:		
		// gets here on line $f6
		WAIT_UNTIL_RASTERLSB_A($ff)
		WASTE_CYCLES_X(61)
		WAIT_UNTIL_RASTERLSB_A($10)
		WASTE_CYCLES_X(50)

		
		//flip back to petscii font
		//lda vicMem3.get("VICMEM_MASK")	// point VIC to the right stuff in the bank
		lda #%11100100
		sta $d018

 		
		// cycle colors of ES IST VOLLBRACHT / 17 chars
		inc $a2
		lda $a2
		lsr
		//lsr
		//lsr					// faster
		and #$1f				// here use all 32 colors i.e. both tables
		tax
		lda attractColorTbl1,x
		.for(var i=0;i<17;i++) {					
		sta colorRam+$33c-17 +i
		}


		jsr waveFlag				// wave flag

		jsr attractSounds			// play bell tolling effects only for this part

		//get off the screen and set the sky color		do border???
		lda skyColor: #BLACK	
		sta BGCOL0
		lda xShaker: #$c8
		sta SCROLX

		SET_6502_IRQ_VECTOR_A(irq_victory)
		
		lda #$ca   				// rasterline at which to launch the irq handler 
	        sta RASTER

		lsr VICIRQ					// acknowledge this raster interrupt serviced	
	
		pla
		tay       
		pla
		tax     
		pla
	   
		rti		

// ==================================================================================================================

waveFlag:
		lda $a2
		lsr		
		lsr
		and #%00001100
		tax
		lda flagTopRow+0,x
		sta $b8ba+0
		lda flagTopRow+1,x
		sta $b8ba+1
		lda flagTopRow+2,x
		sta $b8ba+2
		lda flagTopRow+3,x
		sta $b8ba+3
		lda flagBottomRow+0,x
		sta $b8ba+40+0
		lda flagBottomRow+1,x
		sta $b8ba+40+1		
		lda flagBottomRow+2,x
		sta $b8ba+40+2
		lda flagBottomRow+3,x
		sta $b8ba+40+3				
		rts

flagTopRow:
.byte $e3,$62,$f8,$20, $e3,$f8,$62,$6f, $e3,$f8,$6f,$6f, $e3,$a0,$62,$79

flagBottomRow:
.byte $ef,$f9,$78,$e2, $ef,$a0,$f9,$77, $ef,$e4,$e2,$77, $ef,$f9,$78,$77