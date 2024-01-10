/* 	code generator for blitting sprite shapes with erase
	05-23-2023 derived from blit-erase.asm prototype

//	Sprite memcopy subroutines specific to C64 architecture, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.

	06-07-2023	v0.3 doubled routine to support two destination sprite blocks
	06-11-2023	v0.4 removed redundant offsetList, offsetTbl since only lsbs are used
	07-20-2023	v0.7 added wider guardbands for parts of code that displace by many y steps per frame
	09-22-2023	v0.7 fixed typo bug in configureBlit2.eraseShapeConfig, same line was erased TWICE
	10-21-2023	v0.8 add more lines of erase guard bands

*/

.label origin = $8a00 //$e000
.label BLITSRC = $07	//,$08

// sprite strip memory origin; must be page-aligned because it's a 256-byte block.  Consider putting these in 2nd half of a charset
.const spriteBlk2 = $7700 //PlayerSprites+60*$40
.const spriteBlk1 = $7e00 //in screen 2

// low byte of offset into destination sprite data blocks, high byte is always $77   222 elements including padding
.var offsetList = List()
	.for(var row=0; row<21; row++) { .eval offsetList.add(spriteBlk1+63, spriteBlk1+63) } 			// unused byte address to send out of range stuff to /dev/null  16+5
	.for(var row=0; row<21; row++) { .eval offsetList.add(spriteBlk1+3*row, spriteBlk1+3*row+1) }		//first sprite memory block
	.for(var row=9; row<21; row++) { .eval offsetList.add(spriteBlk1+64+3*row, spriteBlk1+64+3*row+1) }	//second sprite memory block (overlaps)
	.for(var row=0; row<21; row++) { .eval offsetList.add(spriteBlk1+128+3*row, spriteBlk1+128+3*row+1) }	//third and fourth sprites
	.for(var row=0; row<21; row++) { .eval offsetList.add(spriteBlk1+192+3*row, spriteBlk1+192+3*row+1) }
	.for(var row=0; row<21; row++) { .eval offsetList.add(spriteBlk1+63, spriteBlk1+63) } 			// unused byte address to send out of range stuff to /dev/null

// ---------------------- CODE ------------------------------
.pc = origin "Strip Blit Code"

.align $100
moveShape1:	{
		// ldx #0  THIS IS REQUIRED IN THE CALLING CODE
erase:
		ldx #$00			// erase bit pattern, normally 00

		stx topRow11: spriteBlk1	// note that on the very first pass these are uninitialized
		stx topRow12: spriteBlk1	// so that X will be stored in spriteBlk1 = address $7e00
		stx topRow21: spriteBlk1
		stx topRow22: spriteBlk1
		stx topRow31: spriteBlk1
		stx topRow32: spriteBlk1
		stx topRow41: spriteBlk1
		stx topRow42: spriteBlk1	// guard band of 4, handles a double displacement per cycle
		stx topRow51: spriteBlk1
		stx topRow52: spriteBlk1

		stx botRow11: spriteBlk1
		stx botRow12: spriteBlk1
		stx botRow21: spriteBlk1
		stx botRow22: spriteBlk1
		stx botRow31: spriteBlk1
		stx botRow32: spriteBlk1
		stx botRow41: spriteBlk1
		stx botRow42: spriteBlk1	// 4*20=80 cycles, 2+3*20=62 bytes  (was 64 cycles)
		stx botRow51: spriteBlk1
		stx botRow52: spriteBlk1
		
blit:		
.for(var i=0; i<32; i++) {
		lda data: #0			//2
		sta drawAddr: spriteBlk1	//4
		}				// 32*(4+2)+80+2 = 274 cycles not counting jsr/rts another 12 = 286
						// 32*(2+3)+1+62 = 223 bytes fits fully in one page
		rts					
}

.align $100
moveShape2:	{
		// ldx #0  THIS IS REQUIRED IN THE CALLING CODE
erase:
		ldx #$00				// erase bit pattern, normally 00

		stx topRow11: spriteBlk2		// note that on the very first pass these are uninitialized
		stx topRow12: spriteBlk2
		stx topRow21: spriteBlk2
		stx topRow22: spriteBlk2
		stx topRow31: spriteBlk2
		stx topRow32: spriteBlk2
		stx topRow41: spriteBlk2
		stx topRow42: spriteBlk2
		stx topRow51: spriteBlk2
		stx topRow52: spriteBlk2

		stx botRow11: spriteBlk2
		stx botRow12: spriteBlk2
		stx botRow21: spriteBlk2
		stx botRow22: spriteBlk2
		stx botRow31: spriteBlk2
		stx botRow32: spriteBlk2
		stx botRow41: spriteBlk2
		stx botRow42: spriteBlk2
		stx botRow51: spriteBlk2
		stx botRow52: spriteBlk2	
		
			
blit:		
.for(var i=0; i<32; i++) {
		lda data: #0				//2
		sta drawAddr: spriteBlk2		//4
}							// 
							// 
		rts					
}

// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

configureBlit1:	{  //PASS Y POSITION IN THE X REGISTER WHEN CALLING
eraseShapeConfig:
		txa
		sec
		sbc #5*2			// start of five rows above shape (5 rows, with two bytes in table for each)
		tay
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.topRow11		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.topRow12		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.topRow21		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.topRow22		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.topRow31		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.topRow32		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.topRow41		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.topRow42		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.topRow51		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.topRow52		// second column

		txa
		clc
		adc #$20			// A = next row after bottom of shape
		tay
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.botRow11		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.botRow12		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.botRow21		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.botRow22		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.botRow31		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.botRow32		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape1.botRow41		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape1.botRow42		// second column
		iny				// next row down							2
		lda offsetTbl,y			// table of offsets for non-sequential destination space		4
		sta moveShape1.botRow51		// lsb of address to erase, first column				4
		iny
		lda offsetTbl,y
		sta moveShape1.botRow52		// second column


		ldy #0				// reuse Y, now indexing the data byte in the source data shape (sprite)

drawShapeConfig:
.for(var i=0; i<32; i=i+2) {
		// first column
		lda (BLITSRC),y			// must be Y, post-indexed indirect addressing only works with Y in zp
		sta moveShape1.blit[i].data		// modifies immediate mode load data operand
		lda offsetTbl,x
		sta moveShape1.blit[i].drawAddr		// modifies lsb of address in which source data byte should be stored
		inx
		iny
		// second column
		lda (BLITSRC),y			// must be Y, post-indexed indirect addressing only works with Y in zp
		sta moveShape1.blit[i+1].data		// modifies immediate mode load data operand
		lda offsetTbl,x
		sta moveShape1.blit[i+1].drawAddr		// modifies lsb of address in which source data byte should be stored
		inx
		iny
		iny				// skip 3rd column of source sprite data as it is always empty and also not included in the table of dest offsets
					
		}				// 32*(5+4+4+4+2+2)+16*2 = 704 cycles
		rts					
}


configureBlit2:	{  //PASS Y POSITION IN THE X REGISTER WHEN CALLING
eraseShapeConfig:
		txa
		sec
		sbc #5*2			// start of five rows above shape (5 rows, with two bytes in table for each)
		tay
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.topRow11		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.topRow12		// second column
		iny				// next row down				
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.topRow21		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.topRow22		// second column
		iny				// next row down				
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.topRow31		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.topRow32		// second column
		iny				// next row down				
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.topRow41		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.topRow42		// second column
		iny				// next row down				
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.topRow51		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.topRow52		// second column

		txa
		clc
		adc #$20			// A = next row after bottom of shape
		tay
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.botRow11		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.botRow12		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.botRow21		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.botRow22		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.botRow31		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.botRow32		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.botRow41		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.botRow42		// second column
		iny				// next row down
		lda offsetTbl,y			// table of offsets for non-sequential destination space
		sta moveShape2.botRow51		// lsb of address to erase, first column
		iny
		lda offsetTbl,y
		sta moveShape2.botRow52		// second column

		ldy #0				// reuse Y, now indexing the data byte in the source data shape (sprite)

drawShapeConfig:
.for(var i=0; i<32; i=i+2) {
		// first column
		lda (BLITSRC),y			// must be Y, post-indexed indirect addressing only works with Y in zp
		sta moveShape2.blit[i].data		// modifies immediate mode load data operand
		lda offsetTbl,x
		sta moveShape2.blit[i].drawAddr		// modifies lsb of address in which source data byte should be stored
		inx
		iny
		// second column
		lda (BLITSRC),y			// must be Y, post-indexed indirect addressing only works with Y in zp
		sta moveShape2.blit[i+1].data		// modifies immediate mode load data operand
		lda offsetTbl,x
		sta moveShape2.blit[i+1].drawAddr		// modifies lsb of address in which source data byte should be stored
		inx
		iny
		iny				// skip 3rd column of source sprite data as it is always empty and also not included in the table of dest offsets
					
		}				// 32*(5+4+4+4+2+2)+16*2 = 704 cycles
		rts					

}

// ---------------------- CODE ------------------------------



		
offsetTbl:
.fill offsetList.size(), <offsetList.get(i)


shapeAddrTbl:
.lohifill 60, PlayerSprites+$0f+$40*i	//$0f offset because each shape has 5 rows*3 bytes = 15 bytes of blank at the beginning

.print "offset list num elements="+offsetList.size()