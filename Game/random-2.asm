/* 
  Random number generator from codebase64

//	New random number subroutines specific to C64 architecture, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.



  Xorshift fast pseudorandom generator algorithm originally developed by George Marsaglia.
  John Metcalf found a 16-bit version of the algorithm that is fast on 8-bit platforms with only
  single bit shifts available. It has a period of 65535 and passes reasonable tests for
  randomness. 
  

*/ 

/*
.zp {
.label rng_zp_low = $02
.label rng_zp_high = $03
}
*/

SeedRandom:   			// seeding via A,X
        // LDA #1 		// seed, can be anything except 0
        sta rng_zp_low
        //ldx #0
        stx rng_zp_high
        
        
        // the RNG. You can get 8-bit random numbers in A or 16-bit numbers
        // from the zero page addresses. Leaves X/Y unchanged.
GenRandom:	
	lda rng_zp_high		//3
        lsr			//2
        lda rng_zp_low		//3
        ror			//2
        eor rng_zp_high		//3 
        sta rng_zp_high 	//3 	high part of x ^= x << 7 done
        ror             	//2 	A has now x >> 9 and high bit comes from low byte
        eor rng_zp_low		//3
        sta rng_zp_low  	//3 	x ^= x >> 9 and the low part of x ^= x << 7 done
        eor rng_zp_high 	//3	
        sta rng_zp_high 	//3 	x ^= x << 8 done
				// total: 30 cycles
        rts
        

ConfigSIDrandom:					//.label SID_RANDOM	       = $d41b 
	jsr GenRandom // get random 
	sta $d40e // voice 3 frequency low byte
	ora $f0	 //  set  msbits so not too small
	sta $d40f // voice 3 frequency high byte
	lda #$80  // noise waveform, gate bit off
	sta $d412 // voice 3 control register
	
	rts       