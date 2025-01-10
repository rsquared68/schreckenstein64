// player one-step movement routines for integration with Atari code
//
//	Ground-up rewrite of player movement routines, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.
//
//
//
// 	2023-07-02 	derived from p1-v1-control3
//
//	2023-10-20	labels and minor speedup with internal rtses
//
//	2024-11-17	replace absolute access of $db with PlayerIndexIRQ_zp = $eb
//	2024-12-07	v7 increase player X coord limit in movePlayerRight from $ef to $f4 for wider map in game level 3. (AI gets stuck otherwise)
//			   decrease player Y coord min in movePlyerUp from $04 to $02, and viewport Y coord min from $01 to $00 (cmp is $01 because bcc)
//
//
//
// Pass View1CoordinateBase to use in $d1,2, then
//	v1Ypos16 is offset 0
//	v1Xpos16 is offset 2
//
// Pass Player1CoordinateBase to use in $d3,4, then
//	p1Xpos16 is offset 0
//	p1Ypos16 is offset 2
//	p1VposV1 is offset 4
//
// Pass player index in PlayerIndexIRQ_zp, then 
//	p1HposV1 is $8060 offset by PlayerIndexIRQ_zp
//	v1ScrollX is ViewFineScrollBase offset by PlayerIndexIRQ_zp
//	v1ScrollY is ViewFineScrollBase offset by 2 then by PlayerIndexIRQ_zp
//
//
//	These routines do not use any of the temp variables in ZP


// Make some definitions for offsets

		// viewbase in $d1
		.const viewY = 0
		.const viewX = 2

		// playerbase in $d3
		.const playerX = 0
		.const playerY = 2
		.const spriteVpos = 4
		
// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

movePlayerUp:
		// check if player Y already at limit
		ldy #playerY		// offset
		lda (PlayerCoordBase_zpw),y          
		cmp #$02		// changed from $04 with v7, could make view2 player sprite timing risky
		iny			// if lsb > $04, carry is set                     
		lda (PlayerCoordBase_zpw),y          
		sbc #$00		// if msb > $00, carry is set.  If carry is clear, the 16-bit value in v1Ypos16 < $0004     
		bcs !n+
		rts			//internal jmp !done+

		// player can move upward, so decrement the player Y coordinate	
!n:		sec
		ldy #playerY		// player Y at offset
		lda (PlayerCoordBase_zpw),y		
		sbc #1
		sta (PlayerCoordBase_zpw),y
		iny
		lda (PlayerCoordBase_zpw),y
		sbc #0
		sta (PlayerCoordBase_zpw),y		// subtracted 1 from player y coordinate


		// check whether desireable to move sprite...NOTE THAT ALLOWABLE VPOS IS DIFFERENT FOR P1 AND P2, but this is handled in player2Update as an offset 
		// p1 inner box bounds are $5e-$79, while p2 inner box bounds are $bf-$da 	
		ldy #spriteVpos		// offset
		lda (PlayerCoordBase_zpw),y		// p1VposV1				
		cmp #$5e
		bcc !view+		// branch if pVpos < inner range		
		jmp !vpos+		// room to move sprite so move its VPOS instead of viewport

		// try to move viewport, first check if at limit
!view:		ldy #viewY		// view Y is offset 0 from view coordinate base
		lda (ViewportCoordinateBase_zpw),y          
		cmp #$01		// changed from $02 with v7, note bcc below makes this the smallest possible value
		iny			// if lsb > $01, carry is set                     
		lda (ViewportCoordinateBase_zpw),y          
		sbc #$00		// if msb > $00, carry is set.  If carry is clear, the 16-bit value in v1Ypos16 < $0002     
		bcc !vpos+		// branch if no room to move viewport, so try to move sprite in the border region

		// room to move view so dec viewport Y coordinate and exit
		ldy #viewY		// offset			
		sec
		lda (ViewportCoordinateBase_zpw),y
		sbc #1
		sta (ViewportCoordinateBase_zpw),y
		iny
		lda (ViewportCoordinateBase_zpw),y
		sbc #0
		sta (ViewportCoordinateBase_zpw),y		// subtracted 1 from viewport Y
		rts	// internal jmp !done+		// and exit

		// move sprite vpos
!vpos:		ldy #spriteVpos		// vpos offset 
		sec
		lda (PlayerCoordBase_zpw),y
		sbc #1
		sta (PlayerCoordBase_zpw),y		// subtracted 1 from vpos, it's one byte


!done:		rts


// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .	


movePlayerDown:
		// check if player Y already at limit
		ldy #playerY		// offset
		lda (PlayerCoordBase_zpw),y          
		cmp #$d5
		iny			// if lsb > $d5, carry is set                     
		lda (PlayerCoordBase_zpw),y          
		sbc #$01		// if msb > $01, carry is set.  If carry is clear, the 16-bit value in v1Ypos16 < $01d5     
		bcc !n+
		rts	//internal jmp !done+

		// player can move downward, so increment the player Y coordinate	
!n:		clc
		ldy #playerY		// player Y at offset
		lda (PlayerCoordBase_zpw),y		
		adc #1
		sta (PlayerCoordBase_zpw),y
		iny
		lda (PlayerCoordBase_zpw),y
		adc #0
		sta (PlayerCoordBase_zpw),y		// added 1 to player y coordinate


		// check whether desireable to move sprite...NOTE THAT ALLOWABLE VPOS IS DIFFERENT FOR P1 AND P2, but this is handled in player2Update as an offset 
		// p1 inner box bounds are $5e-$79, while p2 inner box bounds are $bf-$da 	
		ldy #spriteVpos		// offset
		lda (PlayerCoordBase_zpw),y		// p1VposV1				
		cmp #$79
		bcs !view+		// branch if pVpos > inner range		
		jmp !vpos+		// room to move sprite so move its VPOS instead of viewport

		// try to move viewport, first check if at limit
!view:		ldy #viewY		// view Y is offset 0 from view coordinate base
		lda (ViewportCoordinateBase_zpw),y          
		cmp #$a7
		iny			// if lsb > $a7, carry is set                     
		lda (ViewportCoordinateBase_zpw),y          
		sbc #$01		// if msb > $01, carry is set.  If carry is clear, the 16-bit value in v1Ypos16 < $01a7    
		bcs !vpos+		// branch if no room to move viewport, so try to move sprite in the border region

		// room to move view so inc viewport Y coordinate and exit
		ldy #viewY		// offset			
		clc
		lda (ViewportCoordinateBase_zpw),y
		adc #1
		sta (ViewportCoordinateBase_zpw),y
		iny
		lda (ViewportCoordinateBase_zpw),y
		adc #0
		sta (ViewportCoordinateBase_zpw),y		// added 1 to viewport Y
		rts	//internal jmp !done+		// and exit

		// move sprite vpos
!vpos:		ldy #spriteVpos		// vpos offset 
		clc
		lda (PlayerCoordBase_zpw),y
		adc #1
		sta (PlayerCoordBase_zpw),y		// added 1 to sprite VPOS, it's one byte

	
!done:		rts
		

// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .	

movePlayerLeft:
		// check if player X already at limit
		ldy #playerX		// offset
		lda (PlayerCoordBase_zpw),y          
		cmp #$0c
		iny			// if lsbX > $04, carry is set                     
		lda (PlayerCoordBase_zpw),y          
		sbc #$00		// if msbX > $00, carry is set.  If carry is clear, the 16-bit value in v1Xpos16 < $0004     
		bcs !n+
		rts	//internal jmp !done+

		// player can move leftward, so decrement the player X coordinate	
!n:		sec
		ldy #playerX		// player X at offset
		lda (PlayerCoordBase_zpw),y		
		sbc #1
		sta (PlayerCoordBase_zpw),y
		iny
		lda (PlayerCoordBase_zpw),y
		sbc #0
		sta (PlayerCoordBase_zpw),y		// subtracted 1 from player X coordinate

		// check whether desireable to move sprite 	
		ldy PlayerIndexIRQ_zp			// offset from p1HposV1
		lda p1HposV1,y		// p1HposV1				
		cmp #$39
		bcc !view+		// branch if pHpos < inner range		
		jmp !vpos+		// room to move sprite so move its HPOS instead of viewport

		// try to move viewport, first check if at limit
!view:		ldy #viewX		// view X is offset 0 from view coordinate base
		lda (ViewportCoordinateBase_zpw),y          
		cmp #$0b
		iny			// if lsbX > $02, carry is set                     
		lda (ViewportCoordinateBase_zpw),y          
		sbc #$00		// if msbX > $00, carry is set.  If carry is clear, the 16-bit value in v1Xpos16 < $0002     
		bcc !vpos+		// branch if no room to move viewport, so try to move sprite in the border region

		// room to move view so dec viewport X coordinate and exit
		ldy #viewX		// offset			
		sec
		lda (ViewportCoordinateBase_zpw),y
		sbc #1
		sta (ViewportCoordinateBase_zpw),y
		iny
		lda (ViewportCoordinateBase_zpw),y
		sbc #0
		sta (ViewportCoordinateBase_zpw),y		// subtracted 1 from viewport X
		rts	//internal jmp !done+		// and exit

		// move sprite hpos
!vpos:		ldy PlayerIndexIRQ_zp			// offset from p1HposV1 
		sec
		lda p1HposV1,y
		sbc #1
		sta p1HposV1,y		// subtracted 1 from sprite HPOS, it's one byte
	
!done:		rts


// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .	

movePlayerRight:
		// check if player X already at limit
		ldy #playerX		// offset
		lda (PlayerCoordBase_zpw),y          
		cmp #$f4						//was originally $ef, but AI gets stuck on third game level due to wider map
		iny			// if lsbX > $e6, carry is set                     
		lda (PlayerCoordBase_zpw),y          
		sbc #$01		// if msbX > $01, carry is set.  If carry is clear, the 16-bit value in v1Xpos16 < $01e7     
		bcc !n+
		rts	//internal jmp !done+

		// player can move right, so increment the player X coordinate	
!n:		clc
		ldy #playerX		// player X at offset
		lda (PlayerCoordBase_zpw),y		
		adc #1
		sta (PlayerCoordBase_zpw),y
		iny
		lda (PlayerCoordBase_zpw),y
		adc #0
		sta (PlayerCoordBase_zpw),y		// added 1 to player X coordinate

		// check whether desireable to move sprite 	
		ldy PlayerIndexIRQ_zp			// offset from p1HposV1
		lda p1HposV1,y		// p1HposV1				
		cmp #$74
		bcs !view+		// branch if pHpos >= inner range		
		jmp !vpos+		// room to move sprite so move its HPOS instead of viewport

		// try to move viewport, first check if at limit
!view:		ldy #viewX		// view X is offset 0 from view coordinate base
		lda (ViewportCoordinateBase_zpw),y          
		cmp #$6c
		iny			// if lsb > $6c, carry is set                     
		lda (ViewportCoordinateBase_zpw),y          
		sbc #$01		// if msb > $01, carry is set.  If carry is clear, the 16-bit value in v1Xpos16 < $016c    
		bcs !vpos+		// branch if no room to move viewport, so try to move sprite in the border region

		// room to move view so inc viewport X coordinate and exit
		ldy #viewX		// offset			
		clc
		lda (ViewportCoordinateBase_zpw),y
		adc #1
		sta (ViewportCoordinateBase_zpw),y
		iny
		lda (ViewportCoordinateBase_zpw),y
		adc #0
		sta (ViewportCoordinateBase_zpw),y		// added 1 to viewport X
		rts	//internal jmp !done+		// and exit

		// move sprite hpos
!vpos:		ldy PlayerIndexIRQ_zp			// offset from p1HposV1 
		clc
		lda p1HposV1,y
		adc #1
		sta p1HposV1,y		// added 1 to sprite HPOS, it's one byte
	
!done:		rts


