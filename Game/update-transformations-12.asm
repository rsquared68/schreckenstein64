// routines that update all coordinate relationships

//	New helper subroutines specific to C64 architecture, no original Schreckenstein code though math concepts
//	are similar to the original.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.

// Convert the 16-bit player coordinates into 8-bit (tile) map coordinates
// can replace the shifts with the similar service routine from the game?

//  2023-07-20	updated offsets etc for increased erase guard bands
//  2023-07-25 	combined own-view player sprite coordinate update routines into one
//  2023-09-12 	changed temp zp variables to $b0... to avoid conflicts
//  2023-10-17 	v9 changed temp zp variables $ba,b,c,d to $a5,6,7,8 to avoid conflicts with block1
//		  which uses $bc,e,f; v9b new x-offsets 
//  2023-10-21	v10 new y-offsets added for yet another erase guard row added
//  2023-10-29	v11 changed translation from viewport 16-bit position to 3 bit fine-scroll register
//  2023-12-06	v12 redid temp variables for cleanup


/*
// these are the temporary zp variables that are used exclusively inside the irq handlers so as not to interfere with the outside game loop
.zp {
.label temp0 = $a0		//temp variable and used to pass parameters between routines only in this block		was $a5
.label temp1 = $a1		//temp variable and used to pass parameters between routines only in this block		was $a6
.label temp2 = $a2		//temp variable										was $a7	
.label temp3 = $a3		//temp, mine										was $a8
}
*/


//=============================================================================================================
//-------------------------------------------------------------------------------------------------------------
//=============================================================================================================

updateView1Param:

// Convert the 16-bit viewport position into the parameters the viewport drawing algo needs
!viewToParam:	// viewport #1				**note 2 C64 MCM clocks per 1 Atari color clock
		lda v1Xpos16	// lsb
		asl		// times 2
//		and #7		// bits 0-2
//		eor #7		// negate
//		sta v1ScrollX	// 7,5,3,1,7,5,3,1,...	//choose either to give a 1/2 mcm pixel viewport shift
		and #6
		eor #6
		sta v1ScrollX	// 6,2,4,0,6,2,4,0,...
		
		lda v1Xpos16+1	//msb
		lsr		//into carry
		lda v1Xpos16	//lsb
		ror		// divide by 2 with borrow
		lsr		// divide by 4
		sta v1CoarseX
		
		lda v1Ypos16	// lsb
		and #7		// bits 0-2
		eor #7		// negate
		sta v1ScrollY
		
		lda v1Ypos16+1	//msb
		lsr		//into carry
		lda v1Ypos16	//lsb
		ror		// divide by 2 with borrow
		lsr
		lsr		// divide by 8
		sta v1CoarseY

		rts

//=============================================================================================================
//-------------------------------------------------------------------------------------------------------------
//=============================================================================================================


updateView2Param:

// Convert the 16-bit viewport position into the parameters the viewport drawing algo needs
!viewToParam:	// viewport #2				**note 2 C64 MCM clocks per 1 Atari color clock	
		lda v2Xpos16	// lsb
		asl		// times 2
//		and #7		// bits 0-2
//		eor #7		// negate
//		sta v1ScrollX	// 7,5,3,1,7,5,3,1,...
		and #6
		eor #6
		sta v2ScrollX	// 6,2,4,0,6,2,4,0,...
		
		lda v2Xpos16+1	//msb
		lsr		//into carry
		lda v2Xpos16	//lsb
		ror		// divide by 2 with borrow
		lsr		// divide by 4
		sta v2CoarseX
		
		lda v2Ypos16	// lsb
		and #7		// bits 0-2
		eor #7		// negate
		sta v2ScrollY
		
		lda v2Ypos16+1	//msb
		lsr		//into carry
		lda v2Ypos16	//lsb
		ror		// divide by 2 with borrow
		lsr
		lsr		// divide by 8
		sta v2CoarseY
		
		rts


//	=========================================================================================================
//	=========================================================================================================
//	=========================================================================================================
//	=========================================================================================================


updateView1SpriteStrip:
// Convert the 16-bit viewport position and the other player 16-bit position into position parameters for the
// sprite strip

// ****need 4 bytes of zero page for delta-coordinate computations, find a good spot currently using DOSVEC and CASINI vectors
//     might be OK but atari routines do use these to reset/restart game

	//  Do math to determine position of player 1 inside viewport #2
		sec
		lda p2Xpos16
		sbc v1Xpos16
		sta temp0
		lda p2Xpos16+1
		sbc v1Xpos16+1
		sta temp0+1
		
		sec
		lda p2Ypos16
		sbc v1Ypos16
		sta temp2
		lda p2Ypos16+1
		sbc v1Ypos16+1
		sta temp2+1		//computes raw deltay and deltax

		asl temp0
		rol temp0+1		// 2*deltax because C64 MCM HPOS is 2*Atari HPOS.  Allowable range is $ffdc - $0118

// ....................................................................................
		
	// Horizontal computations for sprite strip in view 1
		clc
		lda temp0
		adc #$26-2		// if viewports are not aligned, it usually means the initialization of hpos for p1,p2 is wrong
		sta temp0		
		sta strip1xLo		// <(2*deltax + $36), this is lsb of sprite hpos
		lda temp0+1
		adc #0			// >(2*deltax + $36), msb of sprite hpos
		sta temp0+1		// not needed except for diagnostic

						// allowable range is $013-$14e
		cmp #2
		bcs !notOk+		// if msb >=2 way out of range
		//lda temp0+1
		cmp #1
		beq !chklower+		// if msb =1 might be ok, check low end of range
		lda temp0
		cmp #$13
		bcs !ok+		// branch if contents of temp0 >= $13
		
!chklower:	//lda temp0
		cmp #$4e
		bcc !ok+
		// set offscreen
!notOk:		lda #0
		sta strip1xLo		//set lsb x=0
		jmp !n+			//set msb x=0

!ok:	//temp0,+1 = 2*(p1X-v2X) and temp2,+1 = p1Y-v2Y
		lda temp0+1
		and #$ff		// any bits set in the strip HPOS msb?
		beq !n+			// no, don't set x msbits in mask
	    	//    76543210		// strip list = (*0,*4,*5,*7), view 2 statusbar cover = (4,5,6,0,3,*2,*1)  *=ones we need to worry about
		lda #%10110111		// strip mask set bits high, always preserve last two sprites in cover
		bne !n1+
!n:		lda #%00000110		// strip mask set bits low, always preserve last two sprites in cover		
!n1:		sta pre1HposMsb		// store result that is used ONLY FOR THE FIRST FEW LINES OF THE VIEWPORT WHERE PLAYER SPRITE NEVER REACHES DON'T CARE IF PLAYER SPRITE BIT IS WRONG!!!

//-------------------------------------------------------------------------------------------------------------

	// Strip vertical computation for view 2.  Allowable delta y in range $ffea-$0047
		ldy #00 		//preload null position for "out of viewport" at the start of null band mapping into byte 63 of sprite

		lda temp2+1			//check hi byte
		beq !n+			// if not set possibly ok, check for <$47
		//negative range
		cmp #$ff		// if ff could be negative and in range
		bne !set+		// if not 0 or ff, definitely out of range
		lda temp2
		cmp #$e9
		bcs !ok+		// if between $ffea-$0000 it's good
		jmp !set+
		
		//positive range
!n:		lda temp2
		cmp #$47		// 00xx, check if xx<$46
		bcs !set+		// if >$47 out of range		
		//do math on lo byte
!ok:		asl
		clc
		adc #$34+2		// add offset (multiply by 2 before putting here!)
		tay			// replace null position
		
!set:		tya
		sta blitY1		//blit y position in move-pattern for viewport 1

!exit:		rts


		
		
//=============================================================================================================
//-------------------------------------------------------------------------------------------------------------
//=============================================================================================================

updateView2SpriteStrip:
// Convert the 16-bit viewport position and the other player 16-bit position into position parameters for the
// sprite strip

// ****need 4 bytes of zero page for delta-coordinate computations, find a good spot currently using DOSVEC and CASINI vectors
//     might be OK but atari routines do use these to reset/restart game

	//  Do math to determine position of player 1 inside viewport #2
		sec			
		lda p1Xpos16
		sbc v2Xpos16
		sta temp0
		lda p1Xpos16+1
		sbc v2Xpos16+1
		sta temp0+1
		
		sec			
		lda p1Ypos16
		sbc v2Ypos16
		sta temp2
		lda p1Ypos16+1
		sbc v2Ypos16+1
		sta temp2+1		//computes raw deltay and deltax

		asl temp0
		rol temp0+1		// 2*deltax because C64 MCM HPOS is 2*Atari HPOS.  Allowable range is $ffdc - $0118

// ....................................................................................
		
	// Horizontal computations for sprite strip in view 2
		clc
		lda temp0
		adc #$26-2		// if viewports are not aligned, it usually means the initialization of hpos for p1,p2 is wrong
		sta temp0		
		sta strip2xLo		// <(2*deltax + $36), this is lsb of sprite hpos
		lda temp0+1
		adc #0			// >(2*deltax + $36), msb of sprite hpos
		sta temp0+1		// not needed except for diagnostic

					// allowable range is $013-$14e
		cmp #2
		bcs !notOk+		// if msb >=2 way out of range
		//lda temp0+1
		cmp #1
		beq !chklower+		// if msb =1 might be ok, check low end of range
		lda temp0
		cmp #$13
		bcs !ok+		// branch if contents of temp0 >= $13
		
!chklower:	//lda temp0
		cmp #$4e
		bcc !ok+
		// set offscreen
!notOk:		lda #0
		sta strip2xLo		//set lsb x=0
		jmp !n+			//set msb x=0

!ok:	//temp0,+1 = 2*(p1X-v2X) and temp2,+1 = p1Y-v2Y
		lda temp0+1
		and #$ff		// any bits set in the strip HPOS msb?
		beq !n+			// no, don't set x msbits in mask
	    	//    76543210		// strip list = (*0,*4,*5,*7), view 2 statusbar cover = (4,5,6,0,3,*2,*1)  *=ones we need to worry about
		lda #%10110111		// strip mask set bits high, always preserve last two sprites in cover
		bne !n1+
!n:		lda #%00000110		// strip mask set bits low, always preserve last two sprites in cover		
!n1:		sta pre2HposMsb		// store result that is used ONLY FOR THE FIRST FEW LINES OF THE VIEWPORT WHERE PLAYER SPRITE NEVER REACHES DON'T CARE IF PLAYER SPRITE BIT IS WRONG!!!

//-------------------------------------------------------------------------------------------------------------

	// Strip vertical computation for view 2.  Allowable delta y in range $ffea-$0047
		ldy #00  		//preload null position for "out of viewport" at the start of null band mapping into byte 63 of sprite

		lda temp2+1			//check hi byte
		beq !n+			// if not set possibly ok, check for <$47
		//negative range
		cmp #$ff		// if ff could be negative and in range
		bne !set+		// if not 0 or ff, definitely out of range
		lda temp2
		cmp #$e9
		bcs !ok+		// if between $ffea-$0000 it's good
		jmp !set+
		
		//positive range
!n:		lda temp2
		cmp #$47		// 00xx, check if xx<=$46
		bcs !set+		// if >$47 out of range, set using null position	
		//do math on lo byte
!ok:		asl
		clc
		adc #$2c+8+2		// add offset (multiply by 2 before putting here!)
		tay			// replace null position
		
!set:		tya
		sta blitY2		//blit y position in move-pattern for viewport 2

!exit:		rts

// ....................................................................................
// ....................................................................................

updatePlayerSpriteBothViews:
!updateView1PlayerSprite:
	// update isolated player sprite in view 2 by modifying finHPOS and VPOS in irq code
		// note that finHPOS msb update must preserve the sprite strip portion of the same mask
		
		ldx pre1HposMsb
		clc
		lda p1HposV1
		asl			// multiply by two because C64 has two color clocks per pixel in MCM mode
		sta p1HposLsb		// update Hpos lsb in irq code
		bcc !n+
		
		.var hposMask = pow(2,Player1Sprite)
		txa			// recall mask for sprite strip, X = pre2HposMsb
		ora #hposMask		// set player bit hi
		jmp !done+
!n:		txa			// recall mask for sprite strip
		and #(~hposMask)	// set bit low
!done:		sta fin1HposMsb		// update "FINAL" Hpos msb in irq code
		
		lda p1VposV1
		sta p1VposLsb	 	// update Vpos in irq code

		//rts

!updateView2PlayerSprite:
	// update isolated player sprite in view 2 by modifying finHPOS and VPOS in irq code
		// note that finHPOS msb update must preserve the sprite strip portion of the same mask
		
		ldx pre2HposMsb
		clc
		lda p2HposV2
		asl			// multiply by two because C64 has two color clocks per pixel in MCM mode
		sta p2HposLsb		// update Hpos lsb in irq code
		bcc !n+
		
		.eval hposMask = pow(2,Player2Sprite)
		txa			// recall mask for sprite strip, X = pre2HposMsb
		ora #hposMask		// set player bit hi
		jmp !done+
!n:		txa			// recall mask for sprite strip
		and #(~hposMask)	// set bit low
!done:		sta fin2HposMsb		// update "FINAL" Hpos msb in irq code
		
		clc
		lda p2VposV2
		adc #$60		// account for viewport 2 offset from top of screen
		sta p2VposLsb	 	// update Vpos in irq code

		rts
		