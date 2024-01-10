/*
	Viewport coarse scroll handler from schreck-VIC-irq03.asm  Viewport memmove code only

//	New map coarse-scrolling subroutines specific to C64 architecture, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.



		v0.3 2023-02-14 test of unrolled-row map copy, around a 22% speed improvement but 163 bytes larger and 10 zp locations used (98 rasterlines)
				estimate that if the map-shift and single-column map copy is implemented one tile moves can be done in <58 rasterlines.
				Basis for one-tile shift eventually in macro is implemented, ~67 rasterlines, potential to get to ~66
				This won't work for the game though, because the enemies would still need to be blitted into screen memory as they 
				live entirely within the map and move within it!

		2023-06-11	v2 update for new label scheme without offset (i.e. map1x+1 --> map1x)

		2023-07-14	v6b various iterations gone by to maintain compatibility with evolution of the rest of the code

				Version 7 was failed move-in-place experiment

		2023-07-19	v8 slight tweak of 6b, found was blitting an extra column, removed sb text update

		2023-07-25	v9 switched from (),y to absolute addressing in memcpy (doubled code, saved avg of 575 cycles, measured 7 rasterlines)
				no more zeropage row table

		2023-10-20	v12 added more half-step update logic (stop jitter when ai dead etc)

		2023-10-30	v13 ability to turn half-step off, not needed with even-pixel stepping it seems

		2023-11-22	v14 removed original footstep/ladder sound hacks

*/


// #define NOHALFSTEP	// turns off alternate-viewport half-stepping  SET UP IN main.asm

.label dummyAddr = $0000

/*	Initializes a viewport into the map data.  X,Y contain map tile coordinates in map space        */
	
drawViewport:
		lda state_zp				// flip state register which drives player select $db
		eor #1
		sta state_zp
		beq !doView2+				// do view 1 if state=1
		jmp !doView1+


!doView2:	
		//compute view coordinates from most recent player coordinates
		jsr updateView2Param			// 204 cycles
		//ldx v2CoarseX
		ldy v2CoarseY
				
		lda v2ScrollX				//update the fine-scrolls to match where we're about to move the map
		ora #$d0
		sta map2x

		lda v2ScrollY
		ora #$10
		sta map2y

#if !NOHALFSTEP		
		// step the idle viewport by one (half) pixel in X.  This helps with the "length contraction" effect on C64
		// not present in atari because C64 has two color clocks per MCM pixel while atari has only one

		// ONLY DO THIS IF P1HPOSV1 IS AT HI OR LO LIMIT, ELSE IT WILL MOVE THE VIEWPORT WHEN VIEWPORT SHOULDNT
		// BE MOVED
		lda p1HposV1
		cmp #$38
		beq !n+
		cmp #$74
		beq !n+
		jmp !configLoop+		
!n:
		lda PlayerDelayCountdown		//check if this player not able to move in spite of pressing stick
		beq !n+
		jmp !configLoop+			// is stunned, skip
!n:		
		lda Player1SpriteShape
		bne !n+
		jmp !configLoop+			// is falling or standing still, skip		
!n:
		lda ZombieDelay
		bne !configLoop+			// is dead in urn, skip

		// else do the half displacement
		lda PlayerJoystickBits
		and #%00001000				//right
		bne !n+
		lda map1x
		cmp #$d0				//don't let it roll over
		beq !n+
		dec map1x
		
!n:		lda PlayerJoystickBits
		and #%00000100				//left
		bne !n+
		lda map1x
		cmp #$d7				//don't let it roll over
		beq !n+
		inc map1x		
!n:		
#endif
												      
		// x,y coordinates in map space (64 rows by 128 columns) in X,Y registers at start
		// idea is to memcpy map source to screen destination.  Screen destination is fixed from screenRam+40 to screenRam+439 (11 lines)
		
		// Compute the source lookup 
		// source start address = mapRam+Y*128+X is the first entry in the table
!configLoop:	lda v2CoarseX				//4		// txa if x coordinate were actually in X register
		//txa
		clc					//2
		adc mapRamRow0.lo,y			//4
		sta mvmem2[0].srcRowAddr		//2			//srcRowAddr
		lda mapRamRow0.hi,y			//4
		adc #00					//2
		sta mvmem2[0].srcRowAddr+1		//4 total 22 cycles	//srcRowAddr+1
		
		//fill out the rest of the source row pointer table by incrementing subsequent entries steps of 128 = one row of map
		.for(var r=0; r<10; r++) {
			lda #128			//2
			clc				//2
			adc mvmem2[r].srcRowAddr	//3
			sta mvmem2[r+1].srcRowAddr	//3	lo byte of next pointer
			lda #00				//2
			adc mvmem2[r].srcRowAddr+1	//3
			sta mvmem2[r+1].srcRowAddr+1	//3	hi byte of next pointer
			}								// 11*18 = 198 cycles + 22 cycles		***possible to hide this task in the statusbars split between fini1 and fini1_2?
			
			
		ldy #38					//preload column counter for mem move

mvmem2:	.for(var r=0; r<11; r++) {
		lda srcRowAddr: $0000,y			//4		setup code needs to store here at mvmem[i].addr instead of in zp table
		sta screenRam1+40*(r+12),y		//5		the source address never crosses a page boundary in the iteration over y
		}
							//99
		dey
		bpl mvmem2				//(99+2+3)*39 - 1 = 4055 cycles, but costs 46 cycles more in setup
							//unrolling the y loop to get rid of the branch becomes (99+2)*39 = 3939 cycles saving 116 


		rts					//jmp viewDone 


		//-----------------	
	
	
			
!doView1:
		
		//compute view coordinates from most recent player coordinates
		jsr updateView1Param
		
		//ldx v1CoarseX
		ldy v1CoarseY

		lda v1ScrollX				//update the fine-scrolls to match where we're about to move the map
		ora #$d0
		sta map1x

		lda v1ScrollY
		ora #$10
		sta map1y

#if !NOHALFSTEP		
		// step the idle viewport by one (half) pixel in X.  This helps with the "length contraction" effect on C64
		// not present in atari because C64 has two color clocks per MCM pixel while atari has only one

		// ONLY DO THIS IF P2HPOSV2 IS AT HI OR LO LIMIT, ELSE IT WILL MOVE THE VIEWPORT WHEN VIEWPORT SHOULDNT
		// BE MOVED
		lda p2HposV2
		cmp #$38
		beq !n+
		cmp #$74
		beq !n+
		jmp !configLoop+		
!n:
		lda PlayerDelayCountdown+1		//check if this player not able to move in spite of pressing stick
		beq !n+
		jmp !configLoop+
!n:
		lda Player2SpriteShape
		bne !n+
		jmp !configLoop+			// is falling or standing still, skip		
!n:
		lda ZombieDelay+1
		bne !configLoop+			// is dead in urn, skip

		// else do the half displacement			
		lda PlayerJoystickBits+1
		and #%00001000				//right
		bne !n+
		lda map2x
		cmp #$d0				//don't let it roll over
		beq !n+
		dec map2x
		
!n:		lda PlayerJoystickBits+1
		and #%00000100				//left
		bne !n+
		lda map2x
		cmp #$d7				//don't let it roll over
		beq !n+
		inc map2x
!n:
#endif

		// Compute the source lookup 
		// source start address = mapRam+Y*128+X is the first entry in the table
!configLoop:	lda v1CoarseX				// txa if x coordinate were actually in X register
		//txa
		clc
		adc mapRamRow0.lo,y
		sta mvmem1[0].srcRowAddr		//srcRowAddr
		lda mapRamRow0.hi,y
		adc #00
		sta mvmem1[0].srcRowAddr+1		//srcRowAddr+1
		
		//fill out the rest of the source row pointer table by incrementing subsequent entries steps of 128 = one row of map
		.for(var r=0; r<10; r++) {
			lda #128			//2
			clc				//2
			adc mvmem1[r].srcRowAddr	//3
			sta mvmem1[r+1].srcRowAddr	//3	lo byte of next pointer
			lda #00				//2
			adc mvmem1[r].srcRowAddr+1	//3
			sta mvmem1[r+1].srcRowAddr+1	//3	hi byte of next pointer
			}								// 11*18 = 198 cycles
			
			
		ldy #38					//preload column counter for mem move

mvmem1:	.for(var r=0; r<11; r++) {
		lda srcRowAddr: $0000,y			//4		setup code needs to store here at rLoop[i].data instead of in zp table
		sta screenRam1+40*(r+1),y		//5
		}
							//99
		dey
		bpl mvmem1				//(99+2+3)*39 - 1 = 4055 cycles, but costs 46 cycles more in setup 

viewDone:
		rts
		
    		// consumes 98 rasterlines and 348 bytes of code to update one viewport (compared to 125 lines and 184 bytes previously)
		// (around 26 cycles of this is for the statusbars and fine x etc)
	
	
  

mapRamRow0:	
		.lohifill 64-11, mapRam+128*i	


