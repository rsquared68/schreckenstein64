/*	Attempting to integrate bits of original Schreckenstein game code with my map viewport
	display code.  Interrupt code here derived from poc7.asm proof-of-concept.

//	Ground-up construction of game display kernel, no original Schreckenstein code.
//	Copyright 2024 Robert Rafac; see license.txt granting reuse permissions.


	2023-03-13	viewport-irqs.asm v0.1
	2023-03-15	v0.2 modified to allow adjustable charset ptr and configurable statusbar color

	2023-05-30	v0.6 much more complicated delay paths in P1 statusbar, implementation of
			sprite strip working in view1 with additional raster irq for "move-pattern,"
			etc.  view2 is not yet implemented and timed

	2023-06-06	v0.8 properly timed both statusbars.  Double blit without erase into same
			sprite strip creates ghost of other character, address in next version.
			Corrected timing problem with sprite 6 on last line, cycle exact.

	2023-06-08	v0.9 Second sprite strip now uses sprite block in screen 2 memory to
			get rid of ghost. BASELINE VERSION THAT FULLY WORKS.

	2023-06-07	v0.9b refactor to consolidate delays, remove unused labels, etc.

	2023-06-11	v1.0 refactor to use direct labeling instead of +1 for SMC variables,
			also make rasterline trigger naming sensible

	2023-07-07	add in proper msb-setting for sprite strip transition, retime the
			middle portion of the p2 statusbar

	2023-07-17	v1.5 restructured timing to optimize

	2023-07-20	v1.6 retimed for increased guard bands, etc

	2023-07-26	v1.7 (17) failed to make CIA timer stabilizer work for P2 status.
			Margin to execute delay slide when YSCROL=2 seems not present for all
			possible jitter that might be encountered, eventually crashes after
			some seconds at Y=2. Discard this version.

	2023-07-26	v1.8 hybrid with CIA timer stabilizer for P1 status, double-irq for P2 status
			1-cycle retime of Y=7 for P2 status to avoid map tile intruding on grey at
			far right

	2023-10-xx	up to v2.4 Added in sprite-pointer flipping for level/tasks (S-tufe
			and O-bjektiv) and player numbers, timing adjustments for increased guard
			bands. Adjusted timing of rasterline triggers to play better with calls
			in block0.

	2023-10-24	retiming in blinky feet region, added #define diag for irq collisions
			speedup by redoing rasterline lookup tables
			moved PrepSB_2a two lines earlier because of collsions with next interrupt
			when player sprite is overlapping those lines.

	2023-10-25	redid blinky feet as I introduced them again

	2023-11-22	intermediate step for sound integration: consolidate delays

	2023-11-28	v26 last version using the original r2-macros, found bug where any WASTE_CYCLES_X(c) with c>14 was off by 1 cycle :(

	2023-11-28	v27 first version using r2-macros-2

	2023-12-03	v27 integrated 2 playVoice handlers as subroutines. Expanded delay ladder in hermit timer stabilizers for more latitude

	2023-12-05	v28 all sound handlers integrated. Sound-manager integrated inline with macros. Retuned for hermit timer stabilizers.
			Messed around with timing in/below SB2 *a lot*.  It's a mess behind the sprite cover, but there was an issue on the
			breadbin not seen elsewhere. With just random timing changes before black2 and and then patching things up for the
			spriteDelayDone2 I got the problem to go away on the breadbin.  There are other problems at the green-grey boundary
			that look similar to the "color fetch bug" seen on one specific VIC chip, but leave it as-is for now because they are
			hidden behind the sprites.  Both the breadbin and the C64C show that glitch when using frames instead of the full cover.
			It's possible that this glitch is caused by switching to the multicolor screen too early when map1y=3.

	2023-12-06	Rework save/restore to match the ZP deconfliction I did everywhere else, added sprite erase bug patch in common delay
			at setp2s. Start to clean up formatting and removal of old timing comments.

	2023-12-10	Merged bottom border irq with top. Since both are not cycle-constant, frees up more time for non-irq work to handle
			game mechanics.  Inserted char graphic pointer animation in sprite delay 2.  Renamed irq-handler sections to update
			labels/readability.

	2024-01-04	v32 moved subroutine DEGLITCH_STRIPS into this file so it is placed in memory in a relatively stable location. It was
			moving around too much when in helpers.asm, causing timing shifts as it is called from the SB handler segments.

	2024-11-12	v33 modifications for new sound architecture
			PlayerIndex_zp is never guaranteed to be sync'd with state_zp or pass through irq handler, so
			no opportunity to save cycles with SAVE/RESTOREPLAYERINDEX
			retune timing for stabilzer at s1/dbug

	2024-11-17	v34 local PlayerIndexIRQ_zp now for calls to block0 subroutines

	2024-11-22	v35 sound queue manager now in irq.  Refactored playVoice1,2 to take some stress off of stabilizer.  Retimed Y delay branches.

	2024-11-26	v36 reordered many of the sound parts, and re-timed for the stabilizers. Clean-up of timing near SNDMGRPHASE23 (d1:)

	2024-12-02	v36b new stabilizer for playVoice2, retimed all of SB1 and going into view1. Removed experimental PAUSESOUNDQUEUE stuff.

	2024-12-05	promote to v37 to have consistent version numbers in schreck-34, change ordering of configureBlit1 and updateView1SpriteStrip
			to improve strip blanking on teleport in conjuction with changes to block0 near move player to teleport exit; also minor cleanup

	2024-12-17	v38 add one more row of sprite strip blanking in deglitch strips, bottom of strip only. Retiming for deglitch required reworking the
			structure going into the top of SB2 (to get MCM right in bottom right of view 1) and below SB2. Note that it now has a different
			ordering than RC1 so it is not possible to do a direct timing compare above the "critical:" label.  Added pause key fetch at
			sprDly2 enabled by #define PAUSEKEY.
			
*/ 


/*	Labels needed for SMC in these handlers:

	X,Y Fine Scroll offsets:
	map1x, map1y
	map2x, map2y

	Sprite position control: 
	strip1xLo
	pre1HposMsb, fin1HposMsb	//isolated player sprite and strip sprites share same mask
	p1HposLsb
	p1VposLsb

	strip2xLo 
	pre2HposMsb, fin2HposMsb
	p2HposLsb
	p2VposLsb

*/


// 				Rasterlines for various interrupt triggers

.const irqLine_Statusbar1 = 	$35	// none  badlines can start appearing as soon as line $31 (yscroll=1), bottom/top border handler sets $d011=$17 so first badline is $37
.const irqLine_Work1 =		$4f	// green sensitive to view 1 yscroll, $4f currently right on the edge
.const irqLine_PrepSB_2a = 	$75	// blue	 if $77, occasionally too late when player sprite overlaps this region resulting in glitch
.const irqLine_PrepSB_2b = 	$8e	// none  right at bottom of player sprite
//.const irqLine_Statusbar2 = 		// none  fetched from raslntab2, depends on viewport 1 yscroll because of moving badlines
//.const irqLine_Work2			// orange+cyan defined in main as part of launch sequence
					
.var tempMask = 0


//======================================================================================================
//	           STATUSBAR 1 INTERRUPT, DRAW P1 STATUSBAR     TIMER STABILIZED
//======================================================================================================
// rasterline for trigger = irqLine1 = line $35

.align $100

irqStatusbar1:
	// timer-based stabilizer, the "hermit version" discussed in https://csdb.dk/forums/?roomid=11&topicid=65658&firstpost=19
	// it has a limitation that if the code below ever finds $dc04=8, it will blow up by setting the bpl to $0f ahead. The
	// solution used here to keep the code compact is just to ensure that condition can never obtain in the course of vectoring
	// to this handler
        pha
         
	lda $dc04
        eor #$7	
        sta *+4
        bpl *+2
        cmp #$c9			// improved? delay ladder..12
	cmp #$c9			//
	bit $ea24
	bit $ea24			// 35-42 cycles (for A=7 to A=0)
   
        txa
        pha
        tya
        pha

				// timer sync got me 1 line plus 20 cycles with the longer delay ladder	
	bit $fe	
				// moved from below to consolidate cycles	next instruction starts $35, $190
	lda map1y		//4
	and #$7			//2
	tay			//2
	lda dV1midTbl,y		//4 get the delay path from a lookup table
	sta dV1midSelect	//4 no page crossings allowed b.c. only one byte address
				//16 cycles setup


	// Goal here is to switch to the statusbar context (xscroll=$c3, yscroll=$17, bkgd color GREEN,
	// and vicmem2 ptr) on line $37 by setting this all up starting with cycle ~55 of line $36

	// timing doesn't have to be perfect because cover sprites fill a lot of the statusbar
	// HOWEVER, the timing needs to satisfy a bunch of constraints to get the various screenmodes
	// and colors set so that they don't show through the cover sprites, not blow up the timing
	// stabilizer, and ensure the sprite modes, colors, and pointers are set at the right time
	// so that sprites are not corrupted on the last line of the statusbar or on the first line
	// of the upper player viewport.  The latter is handled by the spriteDelay block at the end.
	
	lda p1StatusColor_zp	//3		
	sta $d021		//4     background 0  
setp1s:	
	// currently on line 36...next badline condition on line $37

// **************  one row of blue bkgd with text numerics y=7 ****************

	lda #vicmem2		// 2

p1SBstart:			//	 next instruction cycle 12 of line $36  *** START OF P2 STATUSBAR NUMERICS (text) ***
	sta $d018		// 4	 done on cycle 16

	//execute blit and erase
	jsr moveShape1		// 222+16 +16 cycles

// ********  manage part of the sound  ********

	// 92 cycles below, but because of fetches not all are available
	PLAYVOICE3_A()		// 24
	SNDMGRPHASE1_AX()	// 44 

	nop			// original tuning delays
	nop			// cannot clear p1Sound, p2Sound here because of DMA
	nop
//	nop
	

// *********  one row of grey blocks with blue bkgd (for sprites) and variable y  *************

	lda Sb1Bg1:#LIGHT_GREY	//2	should match BGCOL1=GREY   light-grey(15) and yellow(7) are the same in mcm
grey1:	sta $d021		//4	this instruction starts $3e cycle 54 ($1b0) checked 11/23 using RC1 at different Y and during sound
	
	
p1SBmid: // line $40, cycle 12  need to waste some cycles but add an FLD line for y=7
	// nominally around 21 cycles needed here, but +/- depending

	jmp dV1midSelect: dV1mid_0	//3	 dummy for selector and to put msb of address in place

dV1mid_0:
dV1mid_1:
	WASTE_CYCLES_X(55	+2)		//*** +2 tuning for stabilizer
	jmp dV1midExit		

	// unfortunately y=5 is not combinable with the others
dV1mid_2:
dV1mid_3:
dV1mid_4:
	WASTE_CYCLES_X(14)
	jmp dV1midExit

dV1mid_6:
	WASTE_CYCLES_X(14   +9)	// tuning to match RC1 better											************
	jmp dV1midExit		
			
dV1mid_5:
	WASTE_CYCLES_X(16)

dV1mid_7:
dV1midExit:
	WASTE_CYCLES_X(26)	//cannot sub much in here because at very end of a line, so anything that needs to access memory in the first instruction will lose 17 cycles while sprite fetch happens				
	
	ldy map1y: #$13	//2	map 1 y position
		
screen1:
	lda #vicmem1	//2	switch to screen memory with viewport data, this also switches the sprite pointers!
	and #%11110000	//2
	ora charsetMask //4
s1:	sta $d018	//4	instruction starts line $40, cycle 47

	lda #0				//2
	sta p1Sound_zp 			//3	any sounds not successfully loaded are cleared and lost							************
	sta p2Sound_zp 			//3

	nop		//	in RC1, but removed in v33 with new sound to hit dbug timing as below and fix playVoice1 stabilizer			************
	bit $00
	
dbug:	sty $d011	//      starts line $41, cycle 18


	// LINE OF FLD IN THE MID-BAR TO AVOID P2 VIEWPORT JUMP ON Y=7 DEGENERATE CONDITION
	cpy #$17	//2
	bne fini1	//3,2
	
	nop 		//2	this instruction starts line $41 cycle 30
	lda #$12	//2	force badline on next line $42
	sta $d011	//4
	WASTE_CYCLES_X(39-2)	//get on to badline, because of sprites there are only a few cycles so this goes to the end
				//-2 for testing, cia stabilizer issue in playsound below
	nop		//2	finish badline to complete an FLD line
	sty $d011	//4	then set y back to desired value for viewport 2, this instruction finishes cycle 28 of line $43
	//nop		//      VICE needs this
	
	jmp fini7
	
fini1:	WASTE_CYCLES_X(38	-2)	// two cycles here and at nop above for tuning to match RC1  ***********************
	
fini7: 	
	// in earlier code without the sound players, originally the bne path burned 193 cycles here. 193-38 = 155

	jsr playVoice2		// 142 + jsr/rti 12 = 156, but takes 203 color clocks due to sprites
				// pay attenttion to ckcia1 to be certain there is margin for stabilizer and stabilizer
				// is not interrupted by sprite fetch


	ldx map1x: #$d3	//2	map 1 x position
	stx $d016	//4
			
	lda #BLACK	//2	
black1:	sta $d021	//4	background 0   currently for y=7 starts $47 cycle 56 and completes $48 cycle 14, other y line $47 cycle 14

		
	// can configure sprite strip Y pos and enable mask while they are still scanning out as cover sprites			
	.for(var n=0; n<4; n++) {	
		.eval i = StripList.get(n)		// strip mapping from sprite utilization plan
		.if(n==0) {
			lda #($4d+$15*n-$2)	// Vpos
		} else {
			lda #($4d+$15*n-$b)
			}
		sta $d001+2*i
	}
	
	
	// have time to do this so why not
	SET_6502_IRQ_VECTOR_A(irq_Work1)	// next interrupt handler address
	
        lda #irqLine_Work1	// next irq trigger for reconfiguration of sprites 0,4 first two sprites in strip
        sta RASTER       

	
	//now wait until possible to turn the other player sprite strip on by giving it the correct set of pointers
sprDly1:

	//WASTE_CYCLES_X(87)	// original base delay before sound manager code inserted
d1:
	SNDMGRPHASE2_AX()	//24	 inline sound manager
	SNDMGRPHASE3_AX()	//34	 inline sound manager in place this macro takes 60 cycles, together in place it takes 133 color clocks

	nop			// temp add delay for change to sndmgr
																										  
						   
	nop
	nop
	nop
	nop
	nop
	bit $fe			// 15 cycles needed
	
d2:		
	WASTE_CYCLES_X(13)	// arrive here (d2) on line $4a, 158 (cycle 43) in RC1.          $4a cycle 45 in v36
d3:
	lda map1y		//4	line $4b, cycle 12 in v36
	cmp #$13		//2
	beq sprDly1_3		//3,2	branch if y=3, accumulating 9 cycles

	clc			//2	 range test, carry set if in range lower <= A <= upper
	adc #($ff-$16)		//2	 upper bound inclusive
	adc #($16-$14+1)	//2	 upper-lower+1
	bcc sprDlyDone		//3,2	 branch if out of range			this part 17 cycles if out of range, 100 cycles total

sprDly1_456:
	WASTE_CYCLES_X(24)		// check sprite for all y1 when tuning the above

sprDly1_3:
	nop		//2		// y=3 tuning delay
	nop		//2
	nop		//2
	nop
	nop
	nop
	nop
	nop		//3		two known options here. with 19 cycles (using the bit $fe) MCM is set too late by just under 4 chars (16 MCM pixels or 32 color clocks)
	nop		//2		with 18 cycles (switching a nop for the bit $fe) MCM is set too late by ~1 char and the last line
	nop		//2		of sprite 0 is lost.  These things only happen when Y=3
	nop		//2		By moving things around below the "problem" can either be color, MCM, or X-expand that is the problem
	nop		//2		Failing to set MCM seems the least noticable of the possible glitches.


sprDlyDone:	//next instruction line $4b, x=$108-150
		//configure strip pointers, expand, hpos, and color just after the cover sprites finish scanning	
	ldx strip1xLo: #00		// strip Hpos
	ldy #GREEN			// GREEN = 5	
	
		// setup of first sprite in strip is time-critical so do it separately	
strip1:
	lda #(screenRam2+$200)/$40				//														****STRIP POINTER		
	sta $03f8+screenRam1+StripList.get(0)			//4	this instruction starts at line $4a, $1a0 (cycle 52) and finishes on $4b, $50 (cycle 10) with 19 cycles above	
	stx $d000+2*StripList.get(0)				//4 	Hpos		-- needs to happen after the last line of sprite 0 scans out and it is double-wide
	sty $d027+StripList.get(0)				//4 	and color	-- color is common to all sprites so this needs to happen late

	lda pre1HposMsb: #0					//2 	this bit pattern must preserve msb-x HI for all coversprites except the one starting the strip
	sta $d010						//4


	.eval tempMask = %11111111 ^ pow(2,StripList.get(0)) 	// turn off double-wide for first strip sprite
	lda #tempMask						//2	config top sprite only because others are still being drawn in statusbar
	sta $d01d						//4	turn off double wide

	lda #~tempMask						//2	
	sta $d01c						//4	turn on MCM for topmost strip sprite
								// 	critical section total 30 cycles.  This is very close but MCM gets set 4-6 cycles too late when y=3

	.for(var n=1; n<4; n++) {
		.eval i = StripList.get(n)			// strip mapping from sprite utilization plan								
		lda #(screenRam2+$200+$40*n)/$40		//														****STRIP POINTER
		sta $03f8+screenRam1+i								
		sty $d027+i					// and color
		stx $d000+2*i					// Hpos	
	}


	//player 1 sprite position variables (also above)		
	lda fin1HposMsb: #0	
	ldx p1HposLsb: #171
	ldy p1VposLsb: #$7e

	stx $d000+2*Player1Sprite
	sty $d001+2*Player1Sprite   
	sta $d010

	// pointer to player sprite in viewport 1, this needs to be animated
//	lda #PlayerSprites/$40			//2	
	clc					//2
	lda Player1SpriteShape			//2
	adc #$a0				//2	($6800+$40*n-$4000)/$40  = $a0 + n
	adc ZombieOffset1_zp
	sta $03f8+screenRam1+Player1Sprite	//4

	lda #0
	sta $d01d		//turn off double wide for all sprites
	lda #$ff
	sta $d01c		//turn on MCM 

	// configure the player sprite belonging to this viewport
	lda #BLUE		// main color
	sta $d027+Player1Sprite

#if COLLISIONBRK
	lda $d012
	cmp #irqLineWork1 -1
	bcs !break+
#endif

	lsr VICIRQ		// acknowledge this raster interrupt serviced 

	pla
	tay       
	pla
	tax     
	pla
  
	rti

#if COLLISIONBRK
!break:       brk
#endif




//========================================================================================================
//	THIRD INTERRUPT, MISC WORK, MOVE PLAYER 2
//		line $4f
//========================================================================================================

// relatively timing sensitive interrupt,  note that player sprite can be moving in and out of this region
irq_Work1:
	pha        
	txa
	pha        
	tya
	pha  
	
#if RASTERTIME	
	lda #GREEN				//mark rastertime
#else
	lda #BLACK
#endif
	sta $d020

p2Motion:	
	lda #1					// run player motion for player 2
	sta PlayerIndexIRQ_zp
	jsr PLAYER_MAIN_MOTION_SEGMENT		// 1225 cycles when player is moving, currently taking too much time
		

	SET_6502_IRQ_VECTOR_A(irq_PrepSB_2a)	// next interrupt handler address
        lda #irqLine_PrepSB_2a			// next irq trigger for reconfiguration of sprites 0,4 first two sprites in strip
        sta RASTER       
        
#if RASTERTIME	
	lda #WHITE				//mark rastertime
#else
	lda #BLACK
#endif
	sta $d020
	
#if COLLISIONBRK
	lda $d012
	cmp #irqLinePrepSB_2a-1
	bcs !break+
#endif

	lsr VICIRQ				// acknowledge this raster interrupt serviced	   
	
	pla
	tay       
	pla
	tax     
	pla

	rti

#if COLLISIONBRK
!break:       brk
#endif



//========================================================================================================
//	FOURTH INTERRUPT
//	FIRST PHASE PARTIALLY PREPARING SPRITE CONTEXT FOR PLAYER 2 STATUSBAR, SPRITES 0 & 4
//		also update Y positions of static sprites and generate speedcode for view 2 strip blit
//	line $75
//========================================================================================================

irq_PrepSB_2a:
	pha        
	txa
	pha        
	tya
	pha  

#if RASTERTIME  	
	lda #BLUE				//mark rastertime
#else
	lda #BLACK
#endif
	sta $d020

	
//	preconfigure the topmost two sprites from the strip to get them ready for the player 2 statusbar
//	these are sprites 0,4 in the optimized scheme, and they are in tile positions 3,0 respectively

.const p2statusBarY = $95

	ldx p2StatusColor_zp
	ldy #p2statusBarY +1			//lsb y pos

	// sprite 0 tile 3 data is relative to SBsprites1
	lda #(SBsprites1-$4000 + $40*3)/$40	//data for tile 3			
	sta $03f8+screenRam1+0			//goes to sprite 0
	sta $03f8+screenRam2+0
	stx $d027+0				//color
	sty $d001+2*0				//lsb y

	// sprite 4 tile 0 data is relative to SBsprites1
	lda #(SBsprites1-$4000 + $40*0)/$40	//data for tile 0
	sta $03f8+screenRam1+4			//goes to sprite 4
	stx $d027+4				//color
	sty $d001+2*4				//lsb y

	// lsb x positions, same for both statusbars
	lda #<(24+48*3+7)			//tile position 3
	sta $d000+2*0				//sprite 0
	lda #<(24+48*0+7)			//tile position 0
	sta $d000+2*4				//sprite 4

	// update Y positions of static sprites.  Y and color are the only things changing for these within a frame
	.for(var n=0; n<7; n++){
	.eval i = SB2List.get(n)		// mapping from sprite utilization plan
	.if (i == StaticSpriteList.get(0) || i == StaticSpriteList.get(1) || i == StaticSpriteList.get(2)) {	
		lda #<(24+48*n+7)
		stx $d027+i			//color
		sty $d001+2*i			// lsb y
		}
	}

	// flip pointer for sprite 1							
	lda #(SBsprites2-$4000 + $40*(6 -5))/$40	//tile 6, = das "O"bjektiv
	sta $03f8+screenRam1+1				//goes to sprite 1
	sta $03f8+screenRam2+1

    // generate blit-and-erase speedcode for V2 sprite strip
	clc
	lda Player1SpriteShape			//4
	adc ZombieOffset1_zp
	
	ldy BlankStrips_zp
	beq !n+
	lda #16					// blank sprite data=16 decimal
!n:	
	tay
	lda shapeAddrTbl.lo,y			//5
	sta.zp BLITSRC				//3
	lda shapeAddrTbl.hi,y			//5
	sta.zp BLITSRC+1			//3	total 20 cycles, 13+128 = 141 bytes

	ldx blitY2: #0
	jsr configureBlit2


	SET_6502_IRQ_VECTOR_A(irq_prepSB_2b)	// next interrupt handler address 
	lda #irqLine_PrepSB_2b			// next trigger on next-to-last possible line of player sprite, relies on cycle exact delays in next section            
        sta RASTER
        
#if RASTERTIME         
	lda #DARK_GREY				//mark rastertime
#else
	lda #BLACK
#endif
	sta $d020
	
#if COLLISIONBRK
	lda $d012
	cmp #irqLine_PrepSB_2b -1
	bcs !break+
#endif

	lsr VICIRQ				// acknowledge this raster interrupt serviced	   
	
	pla
	tay       
	pla
	tax     
	pla

	rti

#if COLLISIONBRK
!break:       brk
#endif



//========================================================================================================
//	SECOND PHASE FINISHING PREP OF SPRITE CONTEXT FOR PLAYER 2 STATUSBAR, SPRITES 5 & 6
//	line $8e
//========================================================================================================

irq_prepSB_2b:
	pha        
	txa
	pha        
	tya
	pha  
	
//	lda #RED	// mark rastertime  LITERALLY NOT ENOUGH TIME TO DO THIS
//	sta $d020
	

// preconfigure sprites 5 and 6 for player 2 statusbar.  After this sprites 0,1,2,3,4,5,6 will have
// pointers, Y, lsb X, and colors completely set up.  Only remains to do msb X, MCM, and expand masks to
// transition to statusbar

// sprites 5,6 in the optimized scheme are in tile positions 1,2 respectively

	ldx p2StatusColor_zp
	ldy #p2statusBarY +1			//lsb y pos

	// sprite 5 tile 1 data is relative to SBsprites1
	lda #(SBsprites1-$4000 + $40*1)/$40	//data for tile 1		
	sta $03f8+screenRam1+5			//goes to sprite 5
	stx $d027+5				//color
	sty $d001+2*5				//lsb y

	// lsb x positions, same for both statusbars
	lda #<(24+48*1+7)			//tile position 1
	sta $d000+2*5				//sprite 5

	// in some timing scenarios sprite 6 is still scanning out as player, do x and color last

	SET_6502_IRQ_VECTOR_A(irq_Statusbar2)		// next interrupt handler address

      // original timing
	lda map1y				//4
	and #7					//2
	tay					//2	 map 1 y in x-register to use as index for jump table and rasterline table
	lda raslntab2,y				//4	 next irq trigger for p2 statusbar context
        sta RASTER

	ldy #p2statusBarY +1			// reload lsb y pos

	// delay to get timing right, if wrong player's feet can blink or disappear in the very lower right part of map on level 1
	bit $00					//3 cycles, this is enough on level 1 for sure partly because of wall on right of map


	// new sprite 6 tile 2 data "2" in "Spieler Nr". It won't fit in screen ram, will need to go in a charset block :(
	lda #($6600-$4000)/$40			//data for tile 2
	sta $03f8+screenRam1+6			//goes to sprite 6
	sta $03f8+screenRam2+6			//4
	sty $d001+2*6				//lsb y


	// lsb x positions, same for both statusbars
	lda #<(24+48*2+7)			//tile position 2
	sta $d000+2*6				//sprite 6

	stx $d027+6				//color
         
//	lda #DARK_GREY				//unmark rastertime
//	sta $d020

	lsr VICIRQ				// acknowledge this raster interrupt serviced
	
	pla
	tay       
	pla
	tax     
	pla
	   
late:	rti




//======================================================================================================
//	DRAW P2 STATUSBAR, DOUBLE-IRQ STABILIZED WITH VARIABLE RASTER TRIGGER
//	TO AVOID BADLINE INTERRUPTION
//	could not get timer interrupt to work reliably for yscroll=2 in view 1
//======================================================================================================
.align $100
irq_Statusbar2:
	PRESTABILIZE_RASTER_AXS(irq_Statusbar2_)	// 64-71 cycles after start of entry line

//======================================================================================================
//	SIXTH INTERRUPT -- STABILIZED CODE FOR P2 STATUSBAR
//======================================================================================================
irq_Statusbar2_:
	FINESTABILIZE_RASTER_SPRITE_AXS()	//can stabilize to 1 cycle, but not completely eliminate jitter
						//exits after cycle 7-8 of entry line+2
	

	jsr DEGLITCH_STRIPS	//	64+12 = 72 cycles.  There are 12 writes to the sprite strip in here
				//	it used to be below setp2s, but get it out of the way of the sprite dma and badline change

	// Goal here is to switch to the statusbar context (xscroll=$c3, yscroll=$17, bkgd color GREEN,
	// and vicmem2 ptr) on line $97 by setting this all up starting with cycle ~40 of line $96
			// 	next instruction starts line $96, $18 (cycle 3)
	lda map1y	//3	get map1y position, note bit 4 is always set
	and #7		//2
	tay		//2	lo/hi jump table offset
	lda jump2hi,y	//4
	pha		//3
	lda jump2lo,y	//4
	pha		//3	21 cycles
	rts		//6	uses the stack as the jump vector, note addresses need to be -1 because rts 
			//	auto-increments the pc by 1


	// the challenging part here is delays will depend on where the dmas land
	// cpu can only be stopped on reads; max number of sequential cpu writes is 3

y2_2:
	nop
	nop
	nop
	nop
	bit $fe			//11			
	jmp setp2s		//3	14

y2_3:
y2_4:
y2_5:				
	WASTE_CYCLES_X(10)
	nop			//12		
	jmp setp2s		//3	15

y2_6:						// note two badlines in a row with 7 sprites!		
	WASTE_CYCLES_X(10)
	bit $fe			//13
	jmp setp2s		//3	16
			
y2_0:				 
y2_1:
y2_7:
setp2s:	
	WASTE_CYCLES_X(15)
	nop			//	17
	


critical: 			// line $96,5 except for y=6, then want $95,26
	lda #$7f		//2
	sta $d01d		//4	double wide, except for last strip sprite

	lda #$80		//2
	sta $d01c		//4	hires except for last strip sprite

	lda fin1HposMsb		//4	get hpos msb for view 1	
	and #%10000000		//2	pick out player sprite
	ora #%00000110		//2	or in cover sprite msbits  ****temp change, calculate
	sta $d010		//4

	lda p2StatusColor_zp		//3		// preload for immediate mode store
	sta p2StatusColorImmediate	//4		// 7 cycles deducted from set2ps to get an immediate mode store below

	lda #vicmem2		//2	preload vicmem mask
	ldy #$17		//2	preload yscroll 7, textmode	
	ldx #$c3		//2 	preload xscroll =3 and turn off text MCM


p2SBstart:	// all paths converge here on cycle 47 of line $96  *** START OF P2 STATUSBAR NUMERICS, and it's a badline ***
		// there are only 15(+5) cycles on $96 and 3(+5) cycles on $97
		// v35 2024-11-29 y1={0,1,2,3,4,5,7} line $96 cycle 47; y1={6} line $96 cycle 0
		// this is how it needs to be for y1=6. If say you increase by 5 cycles so it lands on cycle 5 instead of 0
		// the transition to the top of the SB will be destroyed by the badlines with the sprite fetches

// based on analysis followed by trial and error shifting a few cycles each way
	bit $00			//3
	sta $d018		//4				vicmem
	sty $d011		//4 				yscroll	
	stx $d016		//4				set xscroll =3 and turn off text MCM
	lda p2StatusColorImmediate: #GREEN //2			delays fucked if I add just one cycle so forced to use immediate with smc
	sta $d021		//4				sacrifice color change for speed, line covered by sprites anyway

	//execute blit and erase
	jsr moveShape2		// added another 16 cycles
	WASTE_CYCLES_X(9)								
	
				//NOTE: next LDA starts at line $9e $118 with all sprites enabled, or with sprite 7 (only) turned off
	lda map2y		//4		this instruction starts at line $3e $118, possible to move to $110
	and #$7			//2
	tay			//2
	lda dV2midTbl,y		//4
	sta dV2midSelect	//4 no page crossings allowed b.c. only one byte address
				//16 cycles setup

// *********  one row of grey blocks with green bkgd (for sprites) and variable y  *************

	lda Sb2Bg1:#LIGHT_GREY	//2	sprite text color, should match BGCOL1=GREY? don't quite understand but works
grey2:	sta $d021		//4  	this instruction starts line $9f, x=$48 cycle 9.  2024-11-29 verified v35 ok for all y1

		// Easiest way to tune below is to first replace playVoice2 with a dummy delay, else the timer stabilizer will
		// be crashing all the time while you're doing the raster/cycle measurements
		// Once it's close you can put playVoice2 back in but it will still crash for some corner cases
		// At that point, it's best to use a conditional break in VICE e.g. break ckcia2 a>7; command 1 "m map2y map2y"
		// to understand which path to adjust. 

		// Observed pathologies are playVoice2 gets stuck with soundPlaying2=ff but nothing iterating.  It can get stuck
		// in a silent phase, and then no sounds will ever be heard after that.  Or, it can be stuck in an on phase.
	
p2SBmid:	// line $a0, cycle 12  need to waste some cycles but add an FLD line for y=7
		// nominally around 21 cycles needed here, but +/- depending
	jmp dV2midSelect: dV2mid_0	//3	 dummy for selector and to put msb of address in place

dV2mid_0:
dV2mid_1:
	WASTE_CYCLES_X(75)	//	
	jmp dV2midExit		//

	// y=5 is combinable with the others in this statusbar
dV2mid_2:
	WASTE_CYCLES_X(40)	//
	jmp dV2midExit		//

dV2mid_3:
dV2mid_4:
dV2mid_5:
	WASTE_CYCLES_X(50)	//											
	jmp dV2midExit		//

dV2mid_6:
	WASTE_CYCLES_X(50)	// was 40, then 45 did nothing																			
	jmp dV2midExit		// 

dV2mid_7:			//																							
	WASTE_CYCLES_X(20)	// 
	jmp dV2midExit		//

dV2midExit:
	
	ldy map2y: #$13		//2	map 2 y position
	
scrn1_2:			//	next instruction line $a0, cycle 37
	lda #vicmem1		//2	switch to screen memory with viewport data, this also switches the sprite pointers!
	and #%11110000		//2
	ora charsetMask 	//4
	sta $d018		//4	arrive at this instruction $a0, cycle 45

	nop
	nop
	nop
	nop
	nop
	nop			//											
	nop			//	changed from bit
	sty $d011		//      start line $a1 cycle 16 finish cycle 20


	// below, reason for shifting and adding delays is to ensure hermit stabilizer in playVoice1 does not 
	// ever encounter a timing where the timer=8, for which it does not work.

	// LINE OF FLD IN THE MID-BAR TO AVOID P2 VIEWPORT JUMP ON Y=7 DEGENERATE CONDITION
	cpy #$17		//2
	bne fin1_2		//3,2
badline2:
	nop 			//2	this instruction starts line $a1 cycle 24   					in v36b, $a1 cycle 26
	lda #$12		//2	force badline on next line $a2
	sta $d011		//4
	WASTE_CYCLES_X(37)	//      get on to badline, because of sprites there are only a few cycles so this goes to the end	
				//						
	nop			//2	finish badline to complete an FLD line     
	sty $d011		//4	then set y back to desired value for viewport 2, next line cycle 32 of $a3	in v36b, $a3 cycle 24 finishes cycle 28
	nop 			//**	
	nop 			//**
	jmp fin7_2
				// schreck-24 is 200 cycles from bne for y!=7 to the ldx
				// 		 216 cycles from bne for y=7              
	
fin1_2:	WASTE_CYCLES_X(37)	// 37+playVoice2(154) = 191+nop = original 193		
	
fin7_2: // PUT CORRECT DELAY HERE TO GET BLACK BACKGROUND SET LINE $a7 BEFORE CYCLE 13
	// in RC1, arrive here between $a2 cycle 46 and $a3 cycle 33   
	// before sound effect integration, burned 161 cycles here but actually takes 212 color clocks because of sprites
	
	
//	WASTE_CYCLES_X(161)	// use for tuning timings above (no crash with this)
	jsr playVoice1		// new, no timer-based stabilizer		
				// 

			
	ldx map2x: #$d3		//2	map 1 x position
	stx $d016		//4
			
	lda #BLACK		//2	
black2:	sta $d021		//4	background 0   starts $a8, 14 in RC1			$a8, 15 with new sound v36


	// can configure sprite strip Y pos and enable mask while they are still scanning out as cover sprites		
	.for(var n=0; n<4; n++) {	
		.eval i = StripList.get(n)	// strip mapping from sprite utilization plan
		.if(n==0) {
			lda #($ad+$15*n-$2)	// Vpos
		} else {
			lda #($ad+$15*n-$b)
			}
		sta $d001+2*i
	}
	
	
	// have time to do this so why not
	SET_6502_IRQ_VECTOR_A(irq_Work2)	// next interrupt handler address
	
        lda #irqLine_Work2	 		// next irq trigger 
        sta RASTER       
	
	//now wait until possible to turn the other player sprite strip on by giving it the correct set of pointers
sprDly2:
	//WASTE_CYCLES_X(94)	// base delay  -6 for setting player sprite pointer above
	STEPCHARSETANIM_AX()	//39

#if PAUSEKEY
	CHKPAUSE_A(pauseKey_zp)	//21	check for shift-lock, store mask in zp
	WASTE_CYCLES_X(57-21)	
#else
	WASTE_CYCLES_x(57)	// +2 retune for y=0,1
#endif


	lda map2y		//4
	cmp #$13		//2
	beq sprDly2_3		//3,2	branch if y=3, accumulating 9 cycles

	clc			//2	 range test, carry set if in range lower <= A <= upper
	adc #($ff-$16)		//2	 upper bound inclusive
	adc #($16-$14+1)	//2	 upper-lower+1
	bcc sprDlyDone2		//3,2	 branch if out of range		this part 17 cycles if y=0,1,2,7


sprDly2_456:
	WASTE_CYCLES_X(23-2)

sprDly2_3:
	//bit $fe		//3		Tune for the most critical condition y=3; arrival at setup below is sensitive to 1 cycle
	nop			//2		By moving things around below the "problem" can either be color, MCM, or X-expand that is the problem
	nop			//2		Failing to set MCM seems the least noticable of the possible glitches, and all versions even RC1 do this
				//		For y=3, arrival at sprDlyDone2 is line $aa, cycle 50.  If arrive at cycle 49, the SB cover sprites will glitch


sprDlyDone2:			//next instruction line $4b, x=$108-150
				//configure strip pointers, expand, hpos, and color just after the cover sprites finish scanning	
	ldx strip2xLo: #00	// strip Hpos
	ldy #BLUE		// 
	
	// setup of first sprite in strip is time-critical so do it separately	
strip2:
	lda #(PlayerSprites-$4000 + $40*(0+60))/$40	//2	 pointer													****STRIP POINTER		
	sta $03f8+screenRam1+StripList.get(0)		//4	this instruction starts at line $4a, $1a0 (cycle 52) and finishes on $4b, $50 (cycle 10) with 19 cycles above	
	stx $d000+2*StripList.get(0)			//4 	Hpos		-- needs to happen after the last line of sprite 0 scans out and it is double-wide
	sty $d027+StripList.get(0)			//4 	and color	-- color is common to all sprites so this needs to happen late

	lda pre2HposMsb: #0				//2 	this bit pattern must preserve msb-x HI for all coversprites except the one starting the strip
	sta $d010					//4


	.eval tempMask = %11111111 ^ pow(2,StripList.get(0)) // turn off double-wide for first strip sprite
	lda #tempMask					//2	config top sprite only because others are still being drawn in statusbar
	sta $d01d					//4	turn off double wide

	lda #~tempMask					//2	
	sta $d01c					//4	turn on MCM for topmost strip sprite
							// 	critical section total 30 cycles.  This is very close but MCM gets set too late when y=3

	
	.for(var n=1; n<4; n++) {
		.eval i = StripList.get(n)		// strip mapping from sprite utilization plan	
		lda #(PlayerSprites-$4000 + $40*(n+60))/$40	// pointers to the memory into which the shape will be copied							****STRIP POINTER
		sta $03f8+screenRam1+i								
		sty $d027+i				// and color
		stx $d000+2*i				// Hpos	
	}


	// Player 2 sprite position variables
	lda fin2HposMsb: #0
	ldx p2HposLsb: #171
	ldy p2VposLsb: #$d7
	
	stx $d000+2*Player2Sprite
	sty $d001+2*Player2Sprite
	sta $d010

	// pointer to player sprite in viewport 2, animated	
	clc						//2
	lda Player2SpriteShape				//player2ShapeIndex: #00		
	adc #$a0					//2	($6800+$40*n-$4000)/$40  = $a0 + n
	adc ZombieOffset2_zp
	sta $03f8+screenRam1+Player2Sprite
	
	lda #0
	sta $d01d					//turn off double wide for all sprites to end statusbar
	lda #$ff
	sta $d01c					//turn on MCM 

	// configure the player sprite belonging to this viewport
	lda #GREEN					// main color
	sta $d027+Player2Sprite

#if COLLISIONBRK
	lda $d012
	cmp #irqLine_Work2 -1
	bcs !break+
#endif
	
	lsr VICIRQ					// acknowledge this raster interrupt serviced	

	pla
	tay       
	pla
	tax     
	pla
   
	rti

#if COLLISIONBRK
!break:       brk
#endif



//======================================================================================================
//	BOTTOM/TOP BORDER WORK INTERRUPT -- UPDATE VIEW #1 SPRITE STRIP, ANIMATE PLAYER 2 SPRITES,
//	ITERATE ENEMY MOTION, AND ALTERNATING FRAME UPDATE OF MAP+ENEMY TILES
//	line $af
//======================================================================================================
irq_Work2:

	pha        
	txa
	pha        
	tya
	pha

#if RASTERTIME	
	lda #WHITE			// mark rastertime
#else
	lda #BLACK
#endif
	sta EXTCOL
	
	
    // sprite data source pointer setup for blit of player 2 shape into sprite strip 
	clc
	lda Player2SpriteShape
	adc ZombieOffset2_zp
	
	ldy BlankStrips_zp
	beq !n+
	lda #16 //16			// blank sprite data=16 decimal
!n:
	
	tay			
	lda shapeAddrTbl.lo,y		//5
	sta.zp BLITSRC			//3
	lda shapeAddrTbl.hi,y		//5
	sta.zp BLITSRC+1		//3	total 20 cycles, 13+128 = 141 bytes
    
    	// generate blit-and-erase speedcode for V1 sprite strip, and update both sprite strips for latest XY coordinates

	//jsr updateView1SpriteStrip	// updates blitY1	OLD, move after configureBlit so that view1 and view2 have same level of "staleness"
	jsr updateView2SpriteStrip 	// updates blitY2  need to do this before the blitcode is generated for view 2. Currently just above the p2 statusbar

	ldx blitY1: #0
	jsr configureBlit1		// I think this takes around 716 cycles

      	jsr updateView1SpriteStrip	// updates blitY1
      
      
#if RASTERTIME	
	lda #PURPLE			// mark rastertime
#else
	lda #BLACK
#endif      
	sta EXTCOL
	
	
	
	lda PlayerIndex_zp		// there's a gap before this interrupt block starts in which action sounds might be requested
	beq !skip+			// skip to let voice 1 sounds go through; this may be needed when queue is super active

	MANAGESOUNDQUEUE_AX()		// note that both step-motion routines (anim sounds) run right after this, then block 1 (action sounds)
					// all loading happens after recycle to the top (line $37). However, pointers are set out of order in sndmgr2,3
		// Manage queue > step motion 1 > step motion 0 > block 1 > playVoice3 > sndmgr-1     > clear p#Sounds > playVoice2 > sndmgr-2,3 > block 1  > playVoice1 
		//   queue	    anim 1	    anim 2	  action12     play3   load voice regs   zero inputs      play 2     load ptr12	  action12     play1
!skip:
	

p2Animation:	
	lda #1
	sta PlayerIndexIRQ_zp	
	jsr STEP_MOTION_ANIM_SEQ	// animate player 2; pointers are still configured for player 2 from irq above.  This may request new blanking
 

//-------------------------------------------------------------------------------------------------------------------------------------------------------------

	// here I'm going to be racing the beam with the viewport blit ROOM TO ADD SOME CYCLES, MAYBE SIMPLE SOUND
	// following code initializes or updates a viewport in screen memory, there is no VIC manipulation
	// however, the update needs to start early enough so it can finish before the raster scans out the lower right
	// part of the viewport on the bottom of the screen

#if RASTERTIME	
	lda #ORANGE			// mark rastertime
#else
	lda #BLACK
#endif
	sta EXTCOL


	// this is the RC1 blank-reset time
	lda #0				// blanking requested by block0:PlayerMainMotionSegment:ExecutePlayerAIMotion:DoNonmoveAnimation:MovePlayerToTeleportExit
	sta BlankStrips_zp		// This will clear any blanking coming from STEP_MOTION



	//  --- there seems to be room here for at least 30 cycles of untimed code ---

#if TRAPSTRIP
// trap strip blits that might go out of range vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// combination of one player jumping and other falling can result in 2-4 lines (delta y=6-8); teleport aribtrary delta?
	lda $71
	beq !done1+
	lda blitY1
	beq !done1+	// skip if out of range

	sec
	sbc $71		// subtract from old value
	sta $71
	bpl !pos+	// get abs()
  	lda #0
  	sec
  	sbc $71
!pos:	cmp #9 //(2*3)	// vpos is 2x per step
	bcc !done1+	// done1 if abs(y1new-y1old) < 2*3steps
trap1:	nop		// else trap

!done1:	
	lda $72
	beq !done2+
	lda blitY2
	beq !done2+	// skip if out of range

	sec
	sbc $72		// subtract from old value
	sta $72
	bpl !pos+	// get abs()
  	lda #0
  	sec
  	sbc $72
!pos:	cmp #9 //(2*3)	// vpos is 2x per step
	bcc !done2+	// done2 if abs(y2new-y2old) < 2*3steps
trap2:	nop		// else trap	

!done2:
	lda blitY1	// store new values
	sta $71
	lda blitY2
	sta $72
#endif


	//don't start this too early
	//need to sync for beam racing if irqLineMapUpdate =< $cb
	WAIT_UNTIL_RASTERLSB_A($e9)	

	
time:					// you need to burn enough rastertime above in order to race the beam through the p2 viewport
	jsr drawViewport		// in test code, drawViewport is the thing that is driving the player select register 'state'
					// version 9 this takes ~4533 cycles or ~72 rasterlines


        
//========================================================================================================
//		        Bottom of frame to top of frame, handling many tasks
//========================================================================================================

	
#if RASTERTIME	
	lda #CYAN		//mark rastertime
#else
	lda #BLACK
#endif
	sta $d020

//========================================================================================================
//	             HANDLE PLAYER 1 MOTION, PLAYER 1 ANIMATION, AND AN ENEMY UPDATE
//========================================================================================================

	// this is a two-part process, where you both need to do the move (PLAYER_MAIN_MOTION_SEGMENT) and also
	// handle the animation (STEP_MOTION_ANIM_SEQ) before switching players. This is because
	// the animation stepping routine uses the zp pointers to the animation and coordinate structures
	// that are set up in the first call.

	// So the way this is done: I call p1 main motion here and also the anim
	// then, p2 main motion is done in the work1 handler, and anim while delaying to race the
	// beam for the view 2 blit

  	// player own-view sprite coordinate update needs to be done for both players every frame or player
	// motions are only 50% of the speed of the original game
	// and strip guard bands will not be wide enough to do erases for the resulting 2-pixel vertical moves

	
	jsr updatePlayerSpriteBothViews	// update the vpos and hpos lo,hi via SMC


p1Motion:
	lda #0				// do player motion for player 1
	sta PlayerIndexIRQ_zp
	jsr PLAYER_MAIN_MOTION_SEGMENT	// 1225 cycles when player is moving original "slim," mostly fully optimized now 1163
p1Animation:  
	jsr STEP_MOTION_ANIM_SEQ	// this will only animate the player whose zp pointer bases are set up currently.
					// Saved only 3 extra cycles after optimizing, but got an extra line from the two!

	// run the AI if necessary
	lda PlayerControlMode
	beq !n1+			// if 0=human, check other player
	
	jsr AI_MOTION_CONTROL		// PlayerIndexIRQ still configured for player 1 (index 0)
	jmp !n2+			// done, only one player can be AI, because there is only one AiControlMask !
!n1:
					
	lda PlayerControlMode+1
	beq !n2+			// if 0=human, done
	
	lda #1				// run for player 2
	sta PlayerIndexIRQ_zp
	jsr AI_MOTION_CONTROL
!n2:


//========================================================================================================
//	                  PREPARE SPRITE CONTEXT FOR PLAYER 1 STATUSBAR
//========================================================================================================

	
	lda #$17			//2 	there are still badlines after line $33, even though text is hidden until line $37 !!!
	sta $d011			//4 	

	lda #$c3			//2	set xscroll =3 and turn off MCM
	sta $d016			//4


//    preconfigure sprites for the P1 status bar		

	lda #%11111111
	sta $d01d			//double wide

	lda #$00000000
	sta $d01c			//player sprite MCM, all others hires


	ldx p1StatusColor_zp
	ldy #$38-3+1			//lsb y pos


	.for(var n=0; n<5; n++) {	// with these pointers for statusbars
	.eval i = SB1List.get(n)	// mapping from sprite utilization plan. n=tile position, i=sprite index
	lda #(SBsprites1-$4000 + $40*n)/$40
	sta $03f8+screenRam1+i
	.if(n==2) {sta $03f8+screenRam2+i}		// "spieler 1"
	stx $d027+i			//color
	sty $d001+2*i			//lsb y
	}

	.for(var n=5; n<7; n++) {	// with these pointers for statusbars
	.eval i = SB1List.get(n)	// mapping from sprite utilization plan
	.if(n==6) {lda #(SBsprites2-$4000 + $40*(n-5+1))/$40} else {lda #(SBsprites2-$4000 + $40*(n-5))/$40}  // game level, die "S"tufe
	sta $03f8+screenRam1+i		
	.if(n==6) {sta $03f8+screenRam2+i}
	stx $d027+i			//color
	sty $d001+2*i			//lsb y
	}
	
	
	
	// lsb x positions, same for both statusbars
	.for(var n=0; n<7; n++){
	.eval i = SB1List.get(n)	// mapping from sprite utilization plan
		lda #<(24+48*n+7)
		sta $d000+2*i
	}
	
	.eval tempMask = 0
	.for(var n=5; n<7; n++) { .eval tempMask += pow(2,SB1List.get(n)) }   //last two sprites are x>255
	lda #tempMask		//2	msbits 
	sta $d010		//4
	

        SET_6502_IRQ_VECTOR_A(irqStatusbar1) 	// irq1 = p1 statusbar context, irq2 = p2 statusbar context
         
        lda #irqLine_Statusbar1 		// next irq trigger for p1 statusbar context
        sta RASTER      
         
#if RASTERTIME	
	lda #DARK_GREY				//mark rastertime
#else
	lda #BLACK
#endif
	sta $d020

#if COLLISIONBRK
	lda $d012
	cmp #irqLine_Statusbar1 -1
	bcs !break+
#endif

	lsr VICIRQ				// acknowledge this raster interrupt serviced   
	
	pla
	tay       
	pla
	tax     
	pla

	rti

#if COLLISIONBRK
!break:       brk
#endif



// --------------------------------------------------------------------------------------------------------------------------------------
		//$a734
raslntab2: 	.byte $92, $92, $91, $91, $91, $91, $91, $92	// all data in this table must be on same page

		//$a73c
dV1midTbl:	.byte <dV1mid_0, <dV1mid_1, <dV1mid_2, <dV1mid_3, <dV1mid_4, <dV1mid_5, <dV1mid_6, <dV1mid_7
dV2midTbl:	.byte <dV2mid_0, <dV2mid_1, <dV2mid_2, <dV2mid_3, <dV2mid_4, <dV2mid_5, <dV2mid_6, <dV2mid_7

		//$a74c
jump2hi:  	.byte >(y2_0-1), >(y2_1-1), >(y2_2-1), >(y2_3-1), >(y2_4-1), >(y2_5-1), >(y2_6-1), >(y2_7-1)
jump2lo:	.byte <(y2_0-1), <(y2_1-1), <(y2_2-1), <(y2_3-1), <(y2_4-1), <(y2_5-1), <(y2_6-1), <(y2_7-1)

// --------------------------------------------------------------------------------------------------------------------------------------

DEGLITCH_STRIPS:
	// clean top and bottom edges of sprite strips whenever blitY1 or 2 are in the out-of-range position
	// strips are sprites 0,4,5,7 pointing to a 4*$40 contiguous data block at $7e00 (view1) and $7700 (view2)

	ldx #0				//2
!strip1:
	lda blitY1			//4	local label in viewport-irqs, not zp for viewport #1
	beq !clear1+			//2,3
	WASTE_CYCLES_X(22)
	jmp !strip2+			//3
!clear1:
	stx spriteBlk1+$40*0		//4	two bytes top row of strip  block 2 is data block for strip in viewport 2
	stx spriteBlk1+$40*0+1		//4	in all this, only leftmost two bytes of sprite data rows are used
	
	stx spriteBlk1+$40*3+57		//4	two bytes bottom of strip
	stx spriteBlk1+$40*3+58		//4

	stx spriteBlk1+$40*3+60		//4	another two bytes bottom row of strip
	stx spriteBlk1+$40*3+61		//4

!strip2:				// through beq: 33 cycles
	lda blitY2			//4	local label in viewport-irqs, not zp for viewport #2
	beq !clear2+			//2,3
	WASTE_CYCLES_X(22)
	jmp !done+			//3
!clear2:				// through beq: 40 cycles
	stx spriteBlk2+$40*0		//4	two bytes top row of strip
	stx spriteBlk2+$40*0+1		//4
	
	stx spriteBlk2+$40*3+57		//4	two bytes bottom of strip
	stx spriteBlk2+$40*3+58		//4

	stx spriteBlk2+$40*3+60		//4	another two bytes bottom row of strip
	stx spriteBlk2+$40*3+61		//4

!done:					//	total:	64 cycles	can maybe put near setp2s

	rts

