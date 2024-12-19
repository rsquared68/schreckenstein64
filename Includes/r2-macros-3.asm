/*  Some macros for interrupt-driven VIC manipulations, delays, numeric processing etc.
	2023-01-31
	2023-11-28  bugfix, WASTE_CYCLES_X() implemented incorrect number of cycles for certain arguments
*/

.macro PRESTABILIZE_RASTER_AXS(nextIrqAddr) {
    // CYCLECOUNT: 20-27 cycles after Raster IRQ occurred.
	pha        
	txa
	pha        
	tya
	pha  

    // Set up IRQ vector
	lda #<nextIrqAddr
	sta $fffe
	lda #>nextIrqAddr
	sta $ffff

    // Set the Raster IRQ to trigger on the next Raster line
	inc $d012

    // Acknowlege current Raster IRQ
	lda #$01	//4
	sta $d019	//4

    // Store current Stack Pointer (will be messed up when the next IRQ occurs)
	tsx

    // Allow IRQ to happen (Remeber the Interupt flag is set by the Interrupt Handler).
	cli		//this is a 2 cycle instruction but if I change to a nop it doesn't work properly

    // Execute NOPs untill the raster line changes and the Raster IRQ triggers
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	// 64-71 cycles at exit

	.byte $02	// =jam, kil  definitively fail if here
    // Add one extra nop for 65 cycle NTSC machines
	}




.macro FINESTABILIZE_RASTER_AXS() {
    // At this point the next Raster Compare IRQ has triggered and the jitter is max 1 cycle.
    // CYCLECOUNT: 7-8 (7 cycles for the interrupt handler + [0-1] cycle Jitter for the NOP)

    // Restore previous Stack Pointer (ignore the last Stack Manipulation by the IRQ)
    	txs	//cyclecount 9-10										**I measure 11-12 after txs

        // PAL-63  // NTSC-64    // NTSC-65
        //---------//------------//-----------
	ldx #$08   // ldx #$08   // ldx #$09
	dex        // dex        // dex
	bne *-1    // bne *-1    // bne *-1			
	bit $00    // nop
	           // nop			2 + 8*(2+3) -1 + 3 = 44 here, cyclecount 52-53			**count 53-55

    // Check if $d012 is incremented and rectify with an aditional cycle if neccessary
	lda $d012  // 4										//cyclecount 57-58
	cmp $d012  // <- critical instruction (ZERO-Flag will indicate if Jitter = 0 or 1)	//cyclecount 61-62

    // CYCLECOUNT: [61 -> 62] <- Will not work if this timing is wrong

    // cmp $d012 is originally a 5 cycle instruction but due to piplining tech. the
    // 5th cycle responsible for calculating the result is executed simultaniously
    // with the next OP fetch cycle (first cycle of beq *+2).

    // Add one cycle if $d012 wasn't incremented (Jitter / ZERO-Flag = 0)
	beq *+2											//cyclecount 64
}



.macro FINESTABILIZE_RASTER_SPRITE_AXS() {
    	// Version of the fine-stabilizer that works when there is one active sprite on the line.
	// Need to get the lda $d012/cmp $d012 out of the way of the VIC sprite data accesses

//	5 5 5 5 5 5 5 5 6 6 6 6 |
//	2 3 4 5 6 7 8 9 0 1 2 3 |		cycle
//	637383940===========|   |
//	------------------------|
//	 x x x W W w     x x x x|		CPU
//	g g g g                 |
//	            0sss1   2   |		sprite data

	//At this point the next Raster Compare IRQ has triggered and the jitter is max 1 cycle.
    	//CYCLECOUNT: 7-8 (7 cycles for the interrupt handler + [0-1] cycle Jitter for the NOP)

    // Restore previous Stack Pointer (ignore the last Stack Manipulation by the IRQ)
    	txs	//cyclecount 9-10										**I measure 11-12 after txs

	ldx #$07   
	dex        
	bne *-1   	// 35
									
	lda $d012  	// 4		get current line. CPU can't read after cycle 54.  Starts on cycle 48 or 49, ends on cycle 52 or 53.

	nop		//2
	nop		//2		add 7 cycles to get to 59-60

	cmp $d012	//4             critical instruction (ZERO-Flag will indicate if Jitter = 0 or 1)

    // CYCLECOUNT: [61 -> 62] <- Will not work if this timing is wrong

    // cmp $d012 is originally a 5 cycle instruction but due to piplining tech. the
    // 5th cycle responsible for calculating the result is executed simultaniously
    // with the next OP fetch cycle (first cycle of beq *+2).

    // Add one cycle if $d012 wasn't incremented (Jitter / ZERO-Flag = 0)
	beq *+2											//cyclecount 64
}





.macro QUICKSTABILIZE_RASTER_XS() {
	// Restore previous Stack Pointer (ignore the last Stack Manipulation by the IRQ)
    	txs	//cyclecount 9-10							
}

.macro SET_6502_IRQ_VECTOR_A(irqaddr) {
.label IRQVECLO = $fffe
.label 	IRQVECHI = $ffff
	lda #<irqaddr
        sta IRQVECLO
        lda #>irqaddr
        sta IRQVECHI
}

.macro WAIT_UNTIL_RASTERLSB_A(line) {
	lda #line-1
	cmp $d012
	bcs *-3
}

.macro WAIT_UNTIL_RASTERMSB0_A() {
	lda #%10000000
	bit $d011
	bne *-3
}


.macro WASTE_CYCLES_X(cycles) {
	.var fives = floor(cycles/5)
	.var left = mod(cycles,5)

    .if (fives>2 && left==1) {		// if left == only one cycle, need to undershoot because else no way to compensate
	ldx #fives-1  	//2	build a loop to handle the fives
	dex  		//2
	bne *-1  	//3,2	
	bit $fe		//2	2+(fives-1)*5-1+3 = fives*5 - 1
	.eval left += 1		// pass the leftover cycle on
	} else {
	    .if (fives>2 && left!=1) {
	    	ldx #fives-1  	//2
		dex  		//2
		bne *-1  	//3,2	
		nop		//2
		nop		//2	2+(fives-1)*5-1+4 = fives*5
				// no cycles are leftover from the fives
		}
	}
	
				// now do any leftover cycles
    .if (fives<=2) {.eval left = cycles}  	
    .var nops = floor(left/2)
    .var rem = left&1
    .var c = left
    
    .if (left>0) {
	    .if (rem == 0) {
	        .for (var i = 0; i < nops; i++) {
	            nop
	            .eval c -= 2
	        }
	    } else {
	        .for (var i = 0; i < nops-1; i++) {
	            nop
	            .eval c -= 2
	        }
	        bit $fe
	        .eval c -= 3
	    }
	}
}



.macro DISP_BCD_NUM_AXY(disp_addr, bcd_addr, num_dig, zero_char) {	//BCD bytes, addr screen location, num digits to display, char code for zero
	.var num_bytes = ceil(num_dig/2)-1	
	
	ldx #num_bytes		//2	bytes of BCD data
	ldy #num_dig		//2	how many digits (nybbles) to draw

	clc			//2						cc:6
!lp:	lda bcd_addr,x		//4						|
	sta copy+1		//4						|
	and #%00001111		//2						|
	adc #zero_char		//2						|
	sta disp_addr-1,y 	//5						|
	dey			//2						| cc:19 in least sig digit loop
	beq done		//2,3	
	
	lda #%11110000		//2						|
copy:	and #0			//2						|
	lsr			//2						|									
	lsr			//2						|	
	lsr			//2						|	
	lsr			//2						|	
	adc #zero_char		//2						|
	sta disp_addr-1,y	//5						|
	dex			//2						|
	dey			//2						| cc:23 in most sig digit loop
	bne !lp-		//3,2						
done:	

}				// 5-digit number 6+3*(19+2) + 2*(23+3) + 1 = 122 cycles, 3-digit number 6+2*(19+2) + 1*(23+3) + 1 = 75 cycles
				// checked with emulator

				
.macro INC_DECIMAL_AX(bcd_addr, num_dig) {	//bcd bytes, number of digits in representation, number to add in A
	.var num_bytes = ceil(num_dig/2)
	
	sed
	clc
	ldx #num_bytes
	adc bcd_addr-1,x
	sta bcd_addr-1,x
!lp:	dex
	beq done
	lda #00
	adc bcd_addr-1,x
	sta bcd_addr-1,x
	dex
	bne !lp-
done:	cld
}

.macro DEC_DECIMAL_AX(bcd_addr, num_dig) {	//bcd bytes, number of digits in representation, number to subtract in A
	.var num_bytes = ceil(num_dig/2)
	
	sta subtr+1
	sed
	sec
	ldx #num_bytes
	lda bcd_addr-1,x
subtr:	sbc #00
	sta bcd_addr-1,x
!lp:	dex
	beq done
	lda bcd_addr-1,x
	sbc #00
	sta bcd_addr-1,x
	dex
	bne !lp-
done:	cld
}

.macro WAIT_FRAME_A() {			//wait for a frame to elapse

	lda #$80
!w:					//wait until msbit of raster is clear
	bit $d011
	bne !w-	
					
!w:
	bit $d011			//wait until msbit of raster is set
	beq !w-

!w:					//wait until msbit of raster is clear
	bit $d011
	bne !w-	
}
	