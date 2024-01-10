//  block0_1000-26c0.bin.csv translated from SourceGen with kickass-translate.py v0.1
//
//	Implement player motion
//
//	This file contains data and instructions disassembled and reverse-engineered from the binary
//	of the original Schreckenstein game found at memory locations $1000-$26C0, implementing
//	motion control of the two players.  Portions have been deleted, rewritten, or modified to
//	accomodate the C64 hardware and the structure of the port to that platform.  The majority
//	of the code in this block was written by Peter Finzel, and is used here with his written
//	permission.
//
//
//
//
//  *****WARNING:  MULTI-LABELS MAY NOT ALWAYS BE RESOLVED CORRECTLY, PLEASE CHECK MANUALLY
//
//  *****WARNING:  MUST MANUALLY SET ZEROPAGE LABELS WITH .zp { }
 
// 6502bench SourceGen v1.8.5 
//
//	2023-09-26	stripped out ai-motion routines to go from v5 to v6
//	2023-10-20	removed MOVE_PLAYER_ vector table, now jsrs go directly
//			turned off fractional tile adjust
//	2023-10-23	further optimization for speed
//	2023-10-25	inline SET_CAN_CLIMB, CHECK_A_BETWEEN_XY
//	2023-10-27	fixed bug in tile Y and map0 calculations, missed -1 in atari code
//	2023-10-30	fixed fractional adjust of tile X. Now it increments tile X whenever bit 2 is set in L1803,
//			that is, whenever the lowest 2 sig bits = 2 or 3. This "rounds" the tile X up whenever
//			the player is in the second half of the 4-bit wide tile, which has the effect of setting
//			the correct overlap when the player is coming just on to the left of the tile, and clearing
//			the overlap when the player is just leaving the right of the tile. Experimented with this in
//			three additional places for y_adjust, walk_right, and walk_left. I kept the changes only in
//			y_adjust because they seemed to not be improving things on ramps/slopes.
//			Added player sprite HPOS tunable offset main.h0 to teleport code.
//	2023-11-30	Changed set can climb macro to get rid of bonk sound if player is AI as AI bonks a lot
//	2023-12-04	More bonk adjust to stop retriggering on every frame
//	2023-12-06	Inline joystick routine (deleted from block2).  Name temp variables so they can be relocated.
//			This required a special new macro definition for A_BETWEEN_XY due to change in parameter variables
//
//                          
                    
.const playerXtileOffset = 4 //4  // if set to >4 in some corners player can climb up inside a wall and get stuck.
.const playerYtileOffset = 27	 // todo: offset and remove the kludges that made everything work     			*****************************************                
.const playerYspriteOffset = 40 - playerYtileOffset
                
// Jump table                                              
//.pc = $1600                    
//spriteHandler:                  rts	//jmp L177E                    //vector to sprite handling

//	Removed this original jump table to save a few cycles
/*                                                         
MOVE_PLAYER_LEFT:              jmp movePlayerLeft       //move player left by 1 -- all these move the coordinates and try to move view                                                       
MOVE_PLAYER_RIGHT:             jmp movePlayerRight      //move player right by 1                                                         
MOVE_PLAYER_UP:                jmp movePlayerUp       	//move player up by one                                                       
MOVE_PLAYER_DOWN:              jmp movePlayerDown       //move player down by one
*/

// ===================================================================================================================
//		Lookup table containing animation and sound sequence data for player motion
// ===================================================================================================================                                                          
// 
animLookupTable:                           
//                               .byte $75                      //shape data page (msb shape table address)
//                               .byte $00                      //offset of shape block first frame of animation
//                               .byte $00                      //offset of shape block last frame of animation
//                               .byte $00                      //chain to this animation next
//                               .byte $c8                      //timer interval at which sound effect should be repeated
//                               .byte $ff                      //ff
//                               .byte $00                      //index of which sound to play
//                               .byte $00                      // ?????

                               .byte $75 	// standing	00
                               .byte $00
                               .byte $00 
                               .byte $00
                               .byte $c8
                               .byte $ff
                               .byte $00
                               .byte $00
                                                     
                               .byte $74     	// run left    	01
                               .byte $05                      
                               .byte $08                      
                               .byte $01                      
                               .byte $02                      
                               .byte $ff                      
                               .byte $01                      
                               .byte $00
                                                     
                               .byte $74    	// run right   02
                               .byte $01                     
                               .byte $04                      
                               .byte $02                      
                               .byte $02                      
                               .byte $ff                      
                               .byte $01                      
                               .byte $00
                                                     
                               .byte $75    	// stationary on ladder	03
                               .byte $09                      
                               .byte $09     	//first climbing pose      
                               .byte $03                      
                               .byte $c8                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $75   	//climbing   04
                               .byte $09                      
                               .byte $0c    	//orig game has 5 steps, here only 4                      
                               .byte $04                      
                               .byte $02                      
                               .byte $ff                      
                               .byte $02                      
                               .byte $00
                                                     
                               .byte $75    	// jump left         05
                               .byte $08                      
                               .byte $08                      
                               .byte $05                      
                               .byte $0a                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $75   	// jump right        06                                    
                               .byte $01                      
                               .byte $01                      
                               .byte $06                      
                               .byte $0a                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $7e 	// 1st phase attacked, falling, confused         07             
                               .byte 24   	              
                               .byte 27                      
                               .byte $08     	// jump to 8                 
                               .byte $06                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $7e   	// 2nd phase attacked stunned stars        08      
                               .byte 28                      
                               .byte 31                      
                               .byte $08                      
                               .byte $02                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $76    	//1st phase death	09
                               .byte 20                      
                               .byte 23                      
                               .byte $0a                      
                               .byte $14                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $76   	// 2nd phase death   0a
                               .byte 23                      
                               .byte 23                  
                               .byte $0a                      
                               .byte $14                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $76    	//  robbed  0b
                               .byte 32                      
                               .byte 35                     
                               .byte $00                      
                               .byte $0a                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $77   	//teleporting in    0c    
                               .byte 13                     
                               .byte 16                     
                               .byte $0e                      
                               .byte $0a                      
                               .byte $ff                      
                               .byte $01                      
                               .byte $00
                                                     
                               .byte $77  	//teleporting out       0d        
                               .byte 16                      
                               .byte 19                      
                               .byte $00                      
                               .byte $0a                      
                               .byte $ff                      
                               .byte $01                      
                               .byte $00
                                                     
                               .byte $77        // during teleport...should be blank            0e  
                               .byte 16                     
                               .byte 16                      
                               .byte $0e                      
                               .byte $c8	//c8                      
                               .byte $ff                      
                               .byte $00                      
                               .byte $00
                                                     
AnimSeqTblPtr_const:           .word animLookupTable                    //constant pointer to start of sequence table above
AnimSeqTblPtr:                 .word animLookupTable                    //adjustable pointer to sequence table above
                               .byte $65                      
                               .byte $c8                      
L108D:                         .byte $00                      
L108E:                         .byte $00                      
ZombieShapeOffset:             .byte $00                      
                                                         

// ===================================================================================================================
//	Routines handling viewport and player motions, increasing in abstraction down listing
// =================================================================================================================== 
                                               
//                                                       
//   deleted increment/decrement player x,y from original Atari code
// 	implements player and viewport inc/dec                                                    
//                                                                                                            


// ASL contents of A into X a number of times given by value in mathTemp0
// moved here from block2 to deconflict $84,5 with UPDATE_ENEMY_VARS                                                     
ASL_A_INTO_X:                  ldy mathTemp0                      
                               beq !EXIT+                   
                               stx mathTemp1                      
!LOOP:                         asl                          
                               rol mathTemp1                      
                               dey                          
                               bne !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                               ldx mathTemp1                      
!EXIT:                         rts                             



// this routine accesses a table with start and end frames for the sprite animations and steps through them using a counter / mod-counter                                 
LOOKUP_ANIM_SOUND_SEQ:  
                          
                               lda PlayerSpriteCtrlBase_zpw  	//here, animB and animA are related to the way animations are cycled or chained together
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 		
                               sta $af                		//$ac --> offset 0 = animA
                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$01                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af			//$ae --> offset 1 = animB 
      
      
                               ldy #$00                     
                               lda ($ae),y                         
                               inc $ae                  						// +++ reworked, now $ae,f = offset 1
                               sta ($ae),y			// set animB = animA
 
                                
                               // get pointer to lookup table that configures the animation                  
                               //clc                          							// +++ ae,f unchanged offset 1, don't need
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$01                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                      
                               lda ($ae),y                  
                               asl                          
                               asl                          
                               asl                          		
                               sta $ac 				// $ac --> 8*animA start of row in table to use                     
                               clc                          
                               //lda AnimSeqTblPtr_const	// beginning of table address
                               //adc $ac
			       adc AnimSeqTblPtr_const		//+++ flipped to save 4+3-4 = 3 cycles                      
                               sta AnimSeqTblPtr            
                               lda AnimSeqTblPtr_const+1    
                               adc #$00                     
                               sta AnimSeqTblPtr+1          	// now AnimSeqTblPtr points to start of data row

				// configure player mod counter using table lookup
                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$02                     	// offset 2 = animation/sound interval counter (mod counter)
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af 
                               inc $ae										// +++ next offset in sequence = 2
                     
                               clc                          
                               lda AnimSeqTblPtr            
                               adc #$04                    	// offset 4 = mod counter value from data table
                               sta $ac                      
                               lda AnimSeqTblPtr+1          
                               adc #$00                     
                               sta $ad                      
                               lda ($ac),y                  
                               sta ($ae),y                 	//stuff into player interval variable


				// reset animation counter
                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$03                     	//offset 3 = animation counter
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af
			       inc $ae										// +++ next offset in sequence = 3
			                             
                               lda #$00                     
                               sta ($ae),y                 	 //reset animation counter to 0



			      // read the starting frame from the table and stuff it into the animation player variable for first frame
                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$04                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                      	// $ae = offset 4 = first frame of animation
                               inc $ae										// +++ next offset in sequence = 4
		 
                               clc                          
                               lda AnimSeqTblPtr            
                               adc #$01                     
                               sta $ac                      
                               lda AnimSeqTblPtr+1          
                               adc #$00                     
                               sta $ad                      	//$ac = offset 1 in table row = first frame of animation looked up
                               lda ($ac),y         
                               sta ($ae),y                  	//stuff this desired frame into SpriteCtrlBase+offset 4 which is where the animation will start



				// read the first animation frame
                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$04                  	//offset 4 = first frame that we set above
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                                   					// +++ still at offset 4, reworked this used to be below
                               
                               clc                          
                               lda PlayerCoordBase_zpw       
                               adc #$06                   	//offset 6 = player shape offset 0123, 4567 etc in sequence  
                               sta $a9                      
                               lda PlayerCoordBase_zpw+1     
                               adc #$00                     
                               sta $aa                                                                  
                               lda ($ae),y               	// start the player shape sequence with first frame
setShape:                      sta ($a9),y			// stores shape to $8026 or $8030 by using offset 6 from contents of $d3,4



				// read the final frame from the table and stuff it into the animation player variable for the last frame
                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$05                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                      	//$ae = offset 5 = last frame of animation
                               inc $ae										// +++ next offset in sequence = 5

                               clc                          
                               lda AnimSeqTblPtr            
                               adc #$02                     
                               sta $ac                      
                               lda AnimSeqTblPtr+1          
                               adc #$00                     
                               sta $ad                      	//$ac = offset 2 in table row = last frame of animation looked up
                               lda ($ac),y            
                               sta ($ae),y                  	//stuff this desired frame into SpriteCtrlBase+offset 5 which is where the animation will stop or repeat


                                                 
                               // tell the sprite routine the msb of the address to the shape data chunk	+++offset 6 from CoordBase still in $a9,a
			       // I don't use this directly on the C64, but it can be used to implement the switch to the zombie/vampire shape table

                               //clc                          
                               //lda PlayerCoordBase_zpw       
                               //adc #$07                  	// this is $8027/31 which I believe to be msb of pointer to shape memory from which to fetch
                               //sta $ae                      
                               //lda PlayerCoordBase_zpw+1     
                               //adc #$00                     
                               //sta $af
                               inc $a9							// reworked now $a9 is next offset in CoordBase seq = 7

/*                                                                           
                               lda AnimSeqTblPtr            
                               sta $ae                      
                               lda AnimSeqTblPtr+1          
                               sta $af            		// offset 0 in the table row is the msb                         
                               lda ($ae),y              	// get from table   
                               clc
			     //adc ZombieShapeOffset //L108F  
                               sta ($a9),y			// store in player variable
*/                                  
                                  
                               // set up some other state register unknown                  
                               //clc                          
                               //lda PlayerCoordBase_zpw       
                               //adc #$08                  	// $8028 / 8032 don't know some kind of state register
                               //sta $ae                      
                               //lda PlayerCoordBase_zpw+1     
                               //adc #$00                     
                               //sta $af
			       inc $a9							// +++ reworked, and now $a9 is next offset in CoordBase seq = 8
                                                     
                               lda #$01                     
                               sta ($a9),y 		 	// set to 1; if this is forced to 0 animation is stopped at the jump pose
								// this is cleared inside of a routine I deleted at $15e9 in the original
                 
                               // read offset 6 from row in table connected to sound effect and OR it into the sound register
                               clc                          
                               lda AnimSeqTblPtr            
                               adc #$06                     
                               sta $ae                      
                               lda AnimSeqTblPtr+1          
                               adc #$00                     
                               sta $af                      
                               lda SoundStateLo_zp 
                               ora ($ae),y                  
                               sta SoundStateLo_zp 
                               rts                          
                                                         
// COMPUTE_HPOS_VPOS_FROM_COORDS:

// This is called by the first work interrupt.  There is an issue that the zp pointers remain set up for whatever player was indexed by                                                          
STEP_MOTION_ANIM_SEQ:          lda PlayerSpriteCtrlBase_zpw  
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               sta $af                      	//$ae = SpriteCtrlBase
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$01                     
                               sta $ac                      
                               lda PlayerSpriteCtrlBase_zpw+1 	//$ac = SpriteCtrlBase + 1
                               adc #$00                     
                               sta $ad
                                                     
                               ldy #$00                     
                               lda ($ae),y       		//compare $8034 and $8035, these are the row indices from which to look up the animation data          
                               eor ($ac),y              	//   or   $803b and $803c
                               bne !L133F+                  
                               jmp !L1345+                  
                                                         
!L133F:                        jsr LOOKUP_ANIM_SOUND_SEQ    	//if not equal the animation is started so continue it	
                               rts				//internal jmp !L142C+                 	 //and exit

                                                         
!L1345:                        clc                         	//increment the animation counter
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$03                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $af                    	//offset 3 = animation counter
                               clc                          
                               lda ($ae),y                  
                               adc #$01                   	// add 1 to
                               sta ($ae),y                	//increment the animation counter

                               //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$03                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af 		 	//offset 3 = animation counter			+++ $ae,f still at offset 3 from above
                                                    
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$02                     
                               sta $ac                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $ad                   	//offset 2 = sound effect interval
                               lda ($ac),y                  
                               cmp ($ae),y               	// compare with animation counter
                               bcc !L137C+               	// if sound interval < counter value branch
                               rts				//internal jmp !L142C+               	// else skip to exit
                                                         
!L137C:                        //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$01                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1  // offset 1 = animA
                               //adc #$00                     
                               //sta $af
			       dec $ac				// dec $ac to offset 1
                      
                               lda ($ac),y                  
                               bne !L1390+		 	// if first shape != 0 do next           +++ changed to  use $ac,d from above    
                               rts				//internal jmp !L142C+              	// else exit
                                                         
!L1390:                        //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$03                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                	// offset 3 = animation counter			+++ $ae,f still at offset 3

                               lda #$00                     
                               sta ($ae),y              	// reset animation counter

                               clc                          
                               lda PlayerCoordBase_zpw       
                               adc #$06                 	// offset 6 = sprite shape displayed in current frame			+++ going to use offset 6 later, change to $a9,a
                               sta $a9                      
                               lda PlayerCoordBase_zpw+1     
                               adc #$00                     
                               sta $aa                      
                               clc                          
                               lda ($a9),y                  
                               adc #$01                     							// +++ change to $a9
                               sta ($a9),y			// increment shape counter to next shape in sequence
                                                 
                               clc                          
                               lda PlayerCoordBase_zpw       
                               adc #$08                 	// offset 8 = don't know, $8028 / $8032, some kind of state register?
                               sta $ae                      
                               lda PlayerCoordBase_zpw+1     
                               adc #$00                     
                               sta $af                      
                               lda #$01                     
                               sta ($ae),y			// set to 1.  If this is forced to zero, then the animation is stopped at the "jump pose"
								// this is cleared inside of a routine I deleted at $15e9 in the original
                                                 
                               clc                          
                               //lda PlayerCoordBase_zpw       
                               //adc #$06                   	// offset 6 = shape in sequence e.g. 0123 or 4567
                               //sta $ae                      
                               //lda PlayerCoordBase_zpw+1     
                               //adc #$00                     
                               //sta $af                      							+++ reuse $a9,a at offset 6 from above in cmp below
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$05                     	// offset 5 = shape index for last frame of animation
                               sta $ac                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $ad                      
                               lda ($ac),y                  	// get index of last animation frame
                               cmp ($a9),y                  	// compare to coord base + offset 6    		+++ changed from $ae to $a9
                               bcc !L13E9+                  	// branch if current frame < index of last frame to continue
                               rts				//internal jmp !L142C+                  	// else exit
                                                         
                                                         	// here's a place where we can check if the current frame >=59 and hold it if Zombie mode is set.  ****************************
                                                         
                                                         
!L13E9:                        clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$01                     	// offset 1 = animation table selector "animB"
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $af                      
                               lda ($ae),y                  	// load animB
                               asl                          
                               asl                          
                               asl                          
                               sta $ac                      	// 8*animB, table has 8 entries per row
                               clc                          
                               //lda AnimSeqTblPtr_const    	// $ac already in A 
                               //adc $ac 
			       adc AnimSeqTblPtr_const      	// +++ flipped to save 3 cycles              
                               sta AnimSeqTblPtr            
                               lda AnimSeqTblPtr_const+1    
                               adc #$00                     
                               sta AnimSeqTblPtr+1          	// AnimSeqTblPtr = constant address offset + 8*whichRow

                               //lda PlayerSpriteCtrlBase_zpw  
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //sta $af		    	// offset 0 = animA
			       dec $ae										//+++ instead dec from offset 1 above
                                                     
                               clc                          
                               lda AnimSeqTblPtr            
                               adc #$03                     
                               sta $ac                      
                               lda AnimSeqTblPtr+1          
                               adc #$00                     
                               sta $ad                      	// offset 3 from start of desired row = next animation type to play if chaining
			       
                               lda ($ac),y                                 
!store:                        sta ($ae),y                  	// store next anim in animA							***here

                               jsr LOOKUP_ANIM_SOUND_SEQ
                                   
!L142C:                        rts                          
                                                         
 
 
// ------------------------------------------------------------------------------------------------------------------------------------------------------- 
             
//SPRITE_MEMCOPY:                               
                                                        
//POSITION_SPRITE_OWN_VIEW:                   
                                                                                                            
//POSITION_SPRITE_OTHER_VIEW:                  
          
//DISPLAY_ALL_SPRITES:                         

/*                
//  extra returns                                        
L17a9:                         sec                          
                               php                          
                               cmp #$61                     
                               bcc !L17B5+                  
                               cmp #$7b                     
                               bcs !L17B5+                  
                               and #$df                     
!L17B5:                        plp                          
                               rts                          
                                                         
L17b7:                         lda L16D6          // gets code from a part I deleted ************************          
                               asl                          
                               tax                          
                               lda TILE_CLIMBABLE_1_EXIT_RETURNCODE+1,x //msb address to routine exit
                               pha                          
                               lda TILE_CLIMBABLE_1_EXIT_RETURNCODE,x 	//lsb address to routine exit
                               pha                          //pushing segment end (rts) onto stack then rts'ing there.  this might be self-modified code. without any mod, it just does inc $a0
                               rts                          

*/

/*	//modifies code in a part I deleted!                                                         
L17c5:                         lda L16D9                    
                               sta $08                      
                               lda L16D6+2                  
                               beq !L17D6+                  
                               lda #$00                     
                               sta L16D6+2                  
                               sta $08                      
!L17D6:                        sta L1621                    
                               lda #$ff                     
                               sta L16D9                    
                               jmp !L16DF_LOOP-             //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
                               rts
*/                                                         

// -------------------------------------------------------------------------------------------------------------------------------------------------------
                                                         
                               .byte $a0                      
                               .byte $00                      
                               .byte $b9                      
                               .byte $37                      
                               .byte $16                      
                               .byte $20                      
                               .byte $51                      
                               .byte $1c                      
                               .byte $f0                      
                               .byte $03
                              
                               .byte $c8, $d0, $f5, $a9                      
//                               .byte HPu)
                  
                               .byte $3a                      
                               .byte $d9                      
                               .byte $36                      
                               .byte $16                      
                               .byte $f0                      
                               .byte $1f                      
                               .byte $a2                      
                               .byte $03                      
                               .byte $bd                      
                               .byte $2c                      
                               .byte $18                      
                               .byte $99                      
                               .byte $37                      
                               .byte $16                      
                               .byte $c8                      
                               .byte $ca                      
                                                         
                                rts	//jmp CALL_PLAYER_MOTIONS      //not used
                                                         
L1803:                         .byte $03                      // $18d2 in rework; lower three bits of (lsb player X + 13)
L1804:                         .byte $00                      // lower three bits of (lsb player Y + 7)
L1805:                         .byte $00                      // watchdog counter that wakes up a routine every 5 seconds to see if player is trapped on a floor
L1806:                         .byte $00                      
L1807:                         .byte $00                      
                               .byte $04                      
                               .byte $06                      
                               .byte $02                      
                               .byte $03                      
                               .byte $04                      
//                               .res 26,$00
				.fill 26, $00                   
L1827:                         .byte $02                      
                               .byte $00                      
                               .byte $02                      
                               .byte $00                      
                               .byte $02                      
                               .byte $00                      
                               .byte $02                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $01                      
                               .byte $01                      
                               .byte $00                      
                               .byte $01                      
                               .byte $00                      
                               .byte $00                      
                               .byte $01                      
L1838:                         .byte $28                // probability that player 1 AI will make a decision to pursue player 2, smaller is more likely    
                               .byte $28                // probability that player 2 AI will make a decision to pursue player 1, smaller is more likely      
L183A:                         .byte $00      		// player's Y coordinate last time the "is player 1 ai stuck" watchdog woke up               
                               .byte $00                // player's Y coordinate last time the "is player 2 ai stuck" watchdog woke up      

// -------------------------------------------------------------------------------------------------------------------------------------------------------
                                                         
CHECK_IF_TILE_CLIMBABLE_1:     
			       sta temp1                      
                               stx temp2                      
                               ldy #$00                     
                               sty temp0                      
                               lda (temp1),y                  
                               and #$7f                     
                               cmp #$50                     
                               bcc !L1850+                  
                               cmp #$60                     
                               bcc !L185E+
                                                 
!L1850:                        ldy #$01                     
                               lda (temp1),y                  
                               and #$7f                     
                               cmp #$50                     
                               bcc !L1860+                  
                               cmp #$60                     
TILE_CLIMBABLE_1_EXIT_RETURNCODE: bcs !L1860+                  // not understood. code that gets this address is currently commented out

!L185E:                        inc temp0                      
!L1860:                        lda temp0                      
                               rts
                                                         
                                                         
CHECK_IF_TILE_CLIMBABLE_2:     sta temp1                      
                               stx temp2                      
                               ldy #$00                     
                               sty temp0                      
                               lda (temp1),y                  
                               and #$7f                     
                               cmp #$50                     
                               bcc !L1887+                  
                               cmp #$60                     
                               bcs !L1887+
                                                 
                               ldy #$01                     
                               lda (temp1),y                  
                               and #$7f                     
                               cmp #$50                     
                               bcc !L1887+                  
                               cmp #$60                     
                               bcs !L1887+
                                                 
                               inc temp0                      
!L1887:                        lda temp0                      
                               rts                          



                                                         
!AonEntry:                     .byte $4e         // pointer to map             
!XonEntry:                     .byte $4c                      
                                                         
CHECK_IF_TILE_WALKABLE:        //jmp !L188F+                  
                                                         
!L188F:                        stx !XonEntry-               
                               sta !AonEntry-               
                               lda !AonEntry-               
                               sta $ae                      
                               lda !XonEntry-               
                               sta $af
                                                     
                               ldy #$00                     
                               lda ($ae),y      //get the tile            
                               and #$7f
                               
                               // tiles < $65 can be walked on or moved through
/*                                                    
                               sta $ac                      
                               lda #$65                     
                               cmp $ac                      
                               bcc !L18B0+	//if $65 < tile --> if tile > $65, cant walk and branch to exit with returncode 1                           
*/                               
                               cmp #$65+1	//save 3 cycles by not doing the extra loads and stores
                               bcs !L18B0+	//branch if tile >= $65+1 --> branch if tile > $65 to exit with returncode 1                
                               jmp !L18B5+      //else try again            
                                                         
!L18B0:                        lda #$01                     
                               sta temp0                      
                               rts                          //internal
                                                         
!L18B5:                        inc !AonEntry-               //16-bit increment of pointer, so look one tile to the right
                               bne !L18BD+                  
                               inc !XonEntry-
                                              
!L18BD:                        lda !AonEntry-               
                               sta $ae                      
                               lda !XonEntry-               
                               sta $af 
                                                    
                               ldy #$00                     
                               lda ($ae),y                  
                               and #$7f
/*                                                    
                               sta $ac                      
                               lda #$65                     
                               cmp $ac                      
                               bcc !L18D8+	//if $65 < tile --> if tile > $65, cant walk and branch to exit with returncode 1
*/
                               cmp #$65+1	//save 3 cycles by not doing the extra loads and stores
                               bcc !L18DD+	//if tile < $65+1 --> if tile =< $65 tile is walkable and exit with returncode 0               
//                             jmp !L18DD+                  
                                                         
!L18D8:                        lda #$01        //else fall through and exit wtih returncode 1             
                               sta temp0                      
                               rts                          //internal
                                                         
!L18DD:                        lda #$00                     
                               sta temp0                      
                               rts                          




// this routine looks to the right of map0 and below it, and returns temp0=1 if the tile can be walked or climbed on
// map0 is set up way back in EXECUTE_PLAYER_AI_MOTION for this player
                                                      
CHECK_TILE_TRAVERSABLE:
		               clc                          
                               lda map0_zpw                      
                               adc #$01                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               adc #$00                     
                               sta map1_zpw+1		//tile to the right
                                    
                               lda $f1                      
                               eor #$05                     
                               beq !L18F8+               // fail immediately if $f1 contains 5   
                               jmp !L18FD+                  
                                                         
!L18F8:                        lda #$05                     
                               sta temp0                      
                               rts                          //internal
                                                         
!L18FD:                        lda $f1                      
                               eor #$01                     
                               beq !L1906+                  
                               jmp !L1933+                  
                                                         
!L1906:                        ldy #$00                     // look at tile occupied by player
                               lda (map0_zpw),y                  
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$50                     
                               bcs !L1917+                  
                               jmp !L192E+                  
                                                         
!L1917:                        lda (map1_zpw),y              // look at tile to the right of player    
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$50                     
                               bcs !L1926+                  
                               jmp !L192E+                  
                                                         
!L1926:                        lda #$05                     
                               sta temp0                      
                               rts                          //internal
                                                         
                               jmp !L1933+                  
                                                         
!L192E:                        lda #$01                     
                               sta temp0                      
                               rts                          //internal
                                                         
!L1933:                        ldy #$00                     
                               lda (map0_zpw),y            // look at tile occupied by player      
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$50                     
                               bcc !L1944+            // branch if tile < $50 = walkable      (tiles $50-$65 are walkable and climable)
                               //jmp !L1990+
			       lda #$00                     // inline L1990 returncode 0
                               sta temp0                      
                               rts                          //internal                      
                                                         
!L1944:                        lda (map1_zpw),y         // look at tile to the right of player         
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$50                     
                               bcc !L1953+           // branch if tile < $50 = walkable       
                               //jmp !L1990+
			       lda #$00                     // inline L1990 returncode 0
                               sta temp0                      
                               rts                          //internal                      
                                                         
!L1953:                        clc                     // look at tile one row below player     
                               lda map0_zpw                      
                               adc #$80              // tile beneath    
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               adc #$00                     
                               sta map1_zpw+1     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$50                     
                               bcc !L196F+            //branch if tile < $50 = walkable 
                               //jmp !L1990+
			       lda #$00                     // inline L1990 returncode 0
                               sta temp0                      
                               rts                          //internal                      
                                                         
!L196F:                        clc                     // look at tile one row below and one to the right of that     
                               lda map0_zpw                      
                               adc #$81                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               adc #$00                     
                               sta map1_zpw+1     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$50                     
                               bcc !L198B+                  
                               //jmp !L1990+
			       lda #$00                     // inline L1990 returncode 0
                               sta temp0                      
                               rts                          //internal                          
                                                         
!L198B:                        lda #$01                     
                               sta temp0                      
                               rts                          //internal
/*                                                         
!L1990:                        lda #$00                     
                               sta temp0                      
                               rts                          
*/                                    
                                    
                                    
                                                         
DO_JUMPING_MOTION:             sec                          
                               lda map0_zpw                      
                               sbc #$7f                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1     
                               ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta temp0                      
                               ldy #$7f                     
                               ldx #$60                     
                               //lda temp0                      
                               //jsr CHECK_A_BETWEEN_XY       
                               //lda temp0
			       A_BETWEEN_XY_IRQ()                      
                               sta $f5                      
                               sec                          
                               lda map0_zpw                      
                               sbc #$81                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1  
                               ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta temp0                      
                               ldy #$7f                     
                               ldx #$60                     
                               //lda temp0                      
                               //jsr CHECK_A_BETWEEN_XY       
                               //lda temp0
			       A_BETWEEN_XY_IRQ()                      
                               sta $f6                      
                               ldx PlayerIndex_zp           
                               lda TryingToMoveFlag,x       
                               beq !L19FC+                  
                               ldx map0_zpw+1                      
                               lda map0_zpw                      
                               jsr CHECK_IF_TILE_CLIMBABLE_2 
                               lda temp0                      
                               eor #$01                     
                               beq !L19FC+                  
                               lda $f5                      
                               eor #$01                     
                               beq !L19FC+                  
                               lda $f6                      
                               eor #$01                     
                               beq !L19FC+                  
                               jmp !L1A12+                  
                                                         
!L19FC:                        clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$06                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $af                      
                               lda #$00                     
                               ldy #$00                     
                               sta ($ae),y                  
                               jmp !L1A63+                  
                                                         
!L1A12:                        clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$06                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $af                      
                               ldy #$00                     
                               lda ($ae),y                  
                               sta $f5                      
                               ldx $f5                      
                               lda L1827,x                  
                               sta $f5                      
                               //lda $f5                      
                               eor #$01                     
                               beq !L1A35+                  
                               jmp !L1A3E+                  
                                                         
!L1A35:                        jsr movePlayerUp           // jump upward phase
                               jsr movePlayerUp           
                               jmp !L1A4D+                  
                                                         
!L1A3E:                        lda $f5                      
                               eor #$02                     
                               beq !L1A47+                  
                               jmp !L1A4D+                  
                                                         
!L1A47:                        jsr movePlayerDown         // jump downward phase
                               jsr movePlayerDown  
                                      	
!L1A4D:                        //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  	//think not needed
                               //adc #$06                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                      
                               sec                          
                               ldy #$00                     
                               lda ($ae),y                  
                               sbc #$01                     
                               sta ($ae),y
                                                 
!L1A63:                        //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  //think not needed
                               //adc #$06                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                      
                               ldy #$00                     
                               lda ($ae),y                  
                               beq !L1A79+                  
                               rts			//internal jmp !L1A7C+                  
                                                         
!L1A79:                        iny                          
                               sty $f1                      
!L1A7C:                        rts                          






// this does a Y adjustment to allow the player sprite to follow the little up/down slopes
                                                         
ADJUST_Y_SLOPES_UNPHYS:        ldx map0_zpw+1                      
                               lda map0_zpw                      
                               jsr CHECK_IF_TILE_CLIMBABLE_1 
                               lda temp0                      
                               bne !L1A8B+               // branch if climable   
                               jmp !L1A90+                  
                                                         
!L1A8B:                        lda #$01                  // if the tile was climbable, player can get himself out
                               sta temp0                      
                               rts                       //internal
                                                         
!L1A90:                        ldy #$00                     
                               sty $f6                      
                               ldx PlayerIndex_zp           
                               lda PlayerJoystickBits,x     
                               and #$08                 // bit 3, set for every direction except right
                               sta $ae                      
                               //lda $ae                      
                               beq !L1AA4+ 		// if right, do next                 
                               jmp !L1AB0+              // else skip
/*                                                         
!L1AA4:                        lda L1803                // 1803    = lower three bits of (lsb player X + 13)
                               eor #$03                     
                               beq !L1AAE+              // increment $f6 if L1803 = 3    
                               jmp !L1AB0+                  
*/
				// C64 math difference
!L1AA4:				lda L1803 	// lower three bits of (lsb player X + 13)                   
				and #$02	//               
				beq !L1AB0+     // inc $f6 if bit 2 set in L1803                                                                      
	                                                                  
!L1AAE:                        inc $f6
                      
!L1AB0:                        clc                          
                               lda map0_zpw                      
                               adc $f6                      
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               adc #$00                     
                               sta map1_zpw+1     
                               ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta $f5                      
                               //lda $f5                      
                               cmp #$60                     
                               bcc !L1ACE+                  
                               jmp !L1AFF+                  
                                                         
!L1ACE:                        clc                          
                               lda map1_zpw                     
                               adc #$80                     
                               sta map1_zpw                     
                               lda map1_zpw+1     
                               adc #$00                     
                               sta map1_zpw+1     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta temp0                      
                               ldy #$7f                     
                               ldx #$60                     
                               //lda temp0                      
                               //jsr CHECK_A_BETWEEN_XY       
                               //lda temp0
			       A_BETWEEN_XY_IRQ()                      
                               bne !L1AF1+                  
                               jmp !L1AFC+                  
                                                        
!L1AF1:                        jsr movePlayerDown         //can't do two downward displacements on the same move cycle unless I add more guard bands
#if DOUBLEDOWN                 
			       //jsr movePlayerDown	// this is sort of used in falls but not absolutely necessary on slopes?
#endif         
                               lda #$00                     
                               sta temp0                      
                               rts                          //internal
                                                         
!L1AFC:                        //jmp !L1B96+            instead of jmp to exit with fail, inline it here
			       lda #$00                     
                               sta temp0                      
                               rts          		//internal 
                                                         
!L1AFF:                        ldy #$7f                     
                               ldx #$60                     
                               lda $f5                      
                               //jsr CHECK_A_BETWEEN_XY       
                               //lda temp0
			       A_BETWEEN_XY_IRQ()                      
                               bne !L1B0F+                  
                               //jmp !L1B96+		instead of jmp to exit with fail, inline it here
                               lda #$00                     
                               sta temp0                      
                               rts          		//internal                   
                                                         
!L1B0F:                        sec                          
                               lda $f5                      
                               sbc #$60                     
                               sta $ae                      
                               //ldx $ae
			       tax		//save 1 cycle                      
                               lda L1807,x                  
                               sta $f5                      
                               //lda $f5                      
                               beq !L1B24+                  
                               jmp !L1B71+                  
                                                         
!L1B24:                        sec                          
                               lda map1_zpw                     
                               sbc #$80                     
                               sta map1_zpw                     
                               lda map1_zpw+1     
                               sbc #$00                     
                               sta map1_zpw+1
                                    
                               ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta $f6
                                                     
                               ldy #$6c                     
                               ldx #$60                     
                               //lda $f6                      
                               //jsr CHECK_A_BETWEEN_XY       
                               //lda temp0 
			       A_BETWEEN_XY_IRQ()                     
                               bne !L1B49+                  
                               jmp !L1B71+                  
                                                         
!L1B49:                        jsr movePlayerUp
           
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$06                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $af
                                                     
                               sec                          
                               lda $f6                      
                               sbc #$60                     
                               sta $ac                      
                               sec                          
                               lda #$08                     
                               ldx $ac                      
                               sbc L1807,x                  
                               ldy #$00                     
                               sta ($ae),y                  
                               lda #$00                     
                               sta temp0                      
                               rts           		//internal
                                                         
!L1B71:                        lda L1804    		//lower three bits of (lsb player Y + 7)
                               cmp $f5                      
                               bcc !L1B7B+                  
                               jmp !L1B81+                  
                                                         
!L1B7B:                        jsr movePlayerDown         
                               jmp !L1B96+                  
                                                         
!L1B81:                        lda $f5                      
                               cmp L1804           	//lower three bits of (lsb player Y + 7)  
                               bcc !L1B8B+                  
                               jmp !L1B91+                  
                                                         
!L1B8B:                        jsr movePlayerUp           
                               jmp !L1B96+                  
                                                         
!L1B91:                        lda #$01                     
                               sta temp0                      
                               rts             		//internal
                                                         
!L1B96:                        lda #$00                     
                               sta temp0                      
                               rts                          
                                            
                                            
                                            
                                            
                                            
                                            
/*                                                         
SET_CAN_CLIMB:                 lda #$00                     
                               ldx PlayerIndex_zp           
                               sta TryingToMoveFlag,x       
                               lda #$00                     
                               //ldx PlayerIndex_zp           
                               sta PlayerCanClimbFlag,x     
                               lda SoundStateLo_zp 
                               ora #$08                     
                               sta SoundStateLo_zp 
                               rts                          
*/

/*
.macro SETCANCLIMB_AX() {
			       lda #$00                     
                               ldx PlayerIndex_zp           
                               sta TryingToMoveFlag,x                                   
                               sta PlayerCanClimbFlag,x     
                               lda SoundStateLo_zp 
                               ora #$08                     
                               sta SoundStateLo_zp 
}
*/

.macro SETCANCLIMB_AX() {      // "no AI bonk version" + "limited bonk repeat version"
			                         
                               ldx PlayerIndex_zp
                               lda PlayerControlMode,x
                               bne !skip+
                               
                               lda soundPlaying1_zp
                               bne !skip+           
 
                               lda SoundStateLo_zp 
                               ora #$08                     
                               sta SoundStateLo_zp 
!skip:                              
                               lda #$00   
                               sta TryingToMoveFlag,x                                   
                               sta PlayerCanClimbFlag,x    
}



                                                         
WALK_RIGHT:                    sec                          
                               lda map0_zpw                      
                               sbc #$7f                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1

                                    
                               lda L1803          	// lower three bits of (lsb player X + 13)
                               eor #$03                     
                               beq !L1BC7+		// 16-bit inc map1_zpw if L1803=3                  
                               jmp !L1BCD+

 /*                              
				// C64 math difference
				// keep original code for symmetry with WALK_LEFT
				lda L1803 	// lower three bits of (lsb player X + 13)                   
				and #$02	//               
				beq !L1BCD+     // 16-bit inc map1_zpw if bit 2 set in L1803
*/                                    
                                                                                                                                                                     
!L1BC7:                        inc map1_zpw                     
                               bne !L1BCD+                  
                               inc map1_zpw+1 
                                   
!L1BCD:                        ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$6d                     
                               bcs !L1BDE+                  
                               jmp !L1BE4+                  
                                                         
!L1BDE:                        //jsr SET_CAN_CLIMB
			       SETCANCLIMB_AX()      	// inline  
                               rts			//internal jmp !L1C0B+                  
                                                         
!L1BE4:                        jsr movePlayerRight        
                               lda $f1                      
                               eor #$02                     
                               beq !L1BF0+                  
                               jmp !L1BF7+                  
                                                         
!L1BF0:                        lda #$04                     
                               sta $f0                      
                               rts			//internal jmp !L1C0B+                  
                                                         
!L1BF7:                        lda $f1                      
                               eor #$03                     
                               beq !L1C00+                  
                               jmp !L1C07+                  
                                                         
!L1C00:                        lda #$06                     
                               sta $f0                      
                               rts			//internal jmp !L1C0B+                  
                                                         
!L1C07:                        lda #$02                     
                               sta $f0    
                                                 
!L1C0B:                        rts                          



                                                         
WALK_LEFT:                     sec                          
                               lda map0_zpw                      
                               sbc #$80                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1

                                   
                               lda L1803        	//lower three bits of (lsb player X + 13)
                               beq !L1C21+              //16-bit dec map1_zpw if L1803=0    
                               jmp !L1C2E+                  
/*
				// C64 math difference  this might need to be dec if bit 2 NOT set e.g. = 0 or 1
				// but honestly seems to work better with the orignal code
				lda L1803 	// lower three bits of (lsb player X + 13)                   
				and #$02	//               
				bne !L1C2E+     // 16-bit dec map1_zpw if bit 2 not set in L1803       
*/
                                                         
!L1C21:                        sec                          
                               lda map1_zpw                     
                               sbc #$01                     
                               sta map1_zpw                     
                               lda map1_zpw+1     
                               sbc #$00                     
                               sta map1_zpw+1
                                    
!L1C2E:                        ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta $ae                      
                               //lda $ae                      
                               cmp #$6d                     
                               bcs !L1C3F+                  
                               jmp !L1C45+                  
                                                         
!L1C3F:                        //jsr SET_CAN_CLIMB
			       SETCANCLIMB_AX()		//inline            
                               rts			//internal jmp !L1C6C+                  
                                                         
!L1C45:                        jsr movePlayerLeft         
                               lda $f1                      
                               eor #$02                     
                               beq !L1C51+                  
                               jmp !L1C58+                  
                                                         
!L1C51:                        lda #$04                     
                               sta $f0                      
                               rts			//internal jmp !L1C6C+                  
                                                         
!L1C58:                        lda $f1                      
                               eor #$04                     
                               beq !L1C61+                  
                               jmp !L1C68+                  
                                                         
!L1C61:                        lda #$05                     
                               sta $f0                      
                               rts			//internal jmp !L1C6C+                  
                                                         
!L1C68:                        ldy #$01                     
                               sty $f0
                                                     
!L1C6C:                        rts



                          
                                                         
CLIMB_UP:                      ldx map0_zpw+1                      
                               lda map0_zpw                      
                               jsr CHECK_IF_TILE_CLIMBABLE_1 
                               lda temp0                      
                               sta $f5
                                                     
                               sec                          
                               lda map0_zpw                      
                               sbc #$80                     
                               sta temp0                      
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta temp1
                                                     
                               ldx temp1                      
                               lda temp0                      
                               jsr CHECK_IF_TILE_CLIMBABLE_1 
                               lda temp0                      
                               sta $f6                      
                               lda $f5                      
                               ora $f6                      
                               sta $ae                      
                               //lda $ae                      
                               bne !L1C9D+                  
                               jmp !L1CD0+                  
                                                         
!L1C9D:                        lda #$04                     
                               sta $f0                      
                               lda #$02                     
                               sta $f1
                                                     
                               sec                          
                               lda map0_zpw                      
                               sbc #$00                     
                               sta temp0                      
                               lda map0_zpw+1                      
                               sbc #$01                     
                               sta temp1
                                                     
                               ldx temp1                      
                               lda temp0                      
                               jsr CHECK_IF_TILE_WALKABLE   
                               lda temp0                      
                               beq !L1CC0+                  
                               jmp !L1CC6+                  
                                                         
!L1CC0:                        jsr movePlayerUp           
                               rts		//internal jmp !L1CCD+                  
                                                         
!L1CC6:                        //jsr SET_CAN_CLIMB
			       SETCANCLIMB_AX()	//inline            
                               lda #$03                     
                               sta $f0                      
!L1CCD:                        rts		//internal jmp !L1CDD+                  
                                                         
!L1CD0:                        lda #$00                     
                               ldx PlayerIndex_zp           
                               sta TryingToMoveFlag,x       
                               ldy #$00                     
                               sty $f0                      
                               sty $f1 
                                                    
!L1CDD:                        rts     



                     
                                                         
CLIMB_DOWN:                    ldx map0_zpw+1                    	  
                               lda map0_zpw                      	
                               jsr CHECK_IF_TILE_CLIMBABLE_1 		
                               lda temp0                      	
                               sta $f5
                                                     
                               clc                          
                               lda map0_zpw                      
                               adc #$80                     
                               sta temp0                      
                               lda map0_zpw+1                      
                               adc #$00                     
                               sta temp1
                                                     
                               ldx temp1                      
                               lda temp0                      
                               jsr CHECK_IF_TILE_CLIMBABLE_1
                               lda temp0                      	
                               sta $f6                      
/*                             lda $f5                  
                               ora $f6   */
                               ora $f5		//A already had $f6 in it so optimize                      
                               sta $ae                 
                               //lda $ae                      
                               bne !L1D0E+                  
                               jmp !L1D34+                  
                                                         
!L1D0E:                        lda #$04                 
                               sta $f0                      
                               lda #$02                     
                               sta $f1
                                                     
                               ldx map0_zpw+1                      
                               lda map0_zpw                     
                               jsr CHECK_IF_TILE_WALKABLE   
                               lda temp0                     
                               beq !L1D24+                  
                               jmp !L1D2A+             
                                                         
!L1D24:                        jsr movePlayerDown         
                               rts		//internal jmp !L1D31+                  
                                                         
!L1D2A:                        //jsr SET_CAN_CLIMB
			       SETCANCLIMB_AX()		//inline           
                               lda #$03                     
                               sta $f0                      
!L1D31:                        rts		//internal jmp !L1D41+                  
                                                         
!L1D34:                        lda #$00                     
                               ldx PlayerIndex_zp           
                               sta TryingToMoveFlag,x       
                               ldy #$00                     
                               sty $f0                      
                               sty $f1
                                                     
!L1D41:                        rts              





 // teleport jump uses $ae,af,ac,ad,aa
// my routine temporarily uses temp0, temp1 to store tile deltax,y          
                                                         
!teleportalX:                     .byte $1d                      
!teleportalY:                     .byte $8d                      
                                                         
MOVE_PLAYER_TO_TELEPORT_EXIT:  //jmp !L1D47+                  
                                                         
!L1D47:                        stx !teleportalY-               
                               sta !teleportalX-
                                              
                               lda #$00                     
                               sta $f6     
                                                
                               lda !teleportalX-               
                               sta $f5       
                                              
                               lda #$00                     
                               sta $f8 
                                                    
                               lda !teleportalY-               
                               sta $f7          
                                           
                               lda PlayerCoordBase_zpw       
                               sta $ae                      
                               lda PlayerCoordBase_zpw+1     
                               sta $af
                                                     
                               lda #$02                 // times to shift    
                               sta mathTemp0                      
                               lda $f6                      
                               tax			// preserve A = contents of $f6 = 00                         
                               lda $f5  		// portalX                    
                               jsr ASL_A_INTO_X         // 4*portalX   
                               sta $ac                                                    
                               txa                       // recall A = contents of $f6 = 00   
                               sta $ad			// $ac,d = 4*portal X, 0
                                                     
                               sec                          
                               lda $ac                      
                               sbc #playerXtileOffset-1       // $aa = 4*portalX - offset checked with 2x teleport and return player to upperleftmost position
                               sta $aa
                                                     
                               lda $ad                      
                               sbc #$00			// $ad = contents of $f6-0 = 0-0 = 0
                                                    
                               ldy #$01                     
                               sta ($ae),y		// store contents of $ad at PlayerCoordBase_zpw + 1 = msb player X coordinate
                                                 
                               lda $aa                      
                               dey                          
                               sta ($ae),y 		// store contents of $aa 4*portalX - $0c in lsb player X coordinate
                                                
                               clc                          
                               lda PlayerCoordBase_zpw       
                               adc #$02                  // offset 2 = player Y   variable
                               sta $ae                      
                               lda PlayerCoordBase_zpw+1     
                               adc #$00                     
                               sta $af 			// $ae,f = player Y coordinate
                                                    
                               lda #$03                     
                               sta mathTemp0                      
                               lda $f8                      
                               tax                          
                               lda $f7                      
                               jsr ASL_A_INTO_X          // multiply by 8   
                               sta $ac                      
                               txa                          
                               sta $ad 
                                                    
                               sec                          
                               lda $ac                      
                               sbc #playerYtileOffset	//27	//#$07     c64 offset 27                
                               sta $aa
                                                     
                               lda $ad                      
                               sbc #$00    
                               
                                                                          
                               ldy #$01                  
                               sta ($ae),y		// player Y coordinate msb
                                                 
                               lda $aa                      
                               dey                          
newY:                          sta ($ae),y		// player Y coordinate lsb		***checked, x and y for player computed correctly


               // this part is doing sprite updates and view updates  	************rewrite with own code!
	       //  going to be challenging because need to update viewport in a way that does not
	       //  cause it to go out of map memory when portal lands near perimeter
	       //  and then the sprite hpos,vpos need to be computed consistent with the player and
	       //  view coordinates...quickly!
	       //  teleportal relocator uses get_safe_2x2, the bounds of which are 2 < x < 3e, 4 < y < 7e
	       //  so indeed it can land anywhere in the map space

//             . . . . . . . . . . .					**** use some other zp for results of viewport calculation $45,6 7,8
//										will need f5,6 7,8 player coordinates later for sprite pos calc
setup:
		lda PlayerCoordBase_zpw       
		sta $ae                      
		lda PlayerCoordBase_zpw+1     
		sta $af  		// pointer to (now updated) player X

		ldy #0
		lda ($ae),y                  
		sta $f5
		iny                          
		lda ($ae),y
		sta $f6			// new player X in $f5,6
		sta $46		
							 
		clc                          
		lda PlayerCoordBase_zpw       
		adc #$02                     
		sta $ae                      
		lda PlayerCoordBase_zpw+1     
		adc #$00                     
		sta $af    		// player Y coordinate			
						 

		dey                          
		lda ($ae),y                  
		sta $f7 
		iny                          
		lda ($ae),y                  
		sta $f8   		// new player Y in $f7,8
		sta $48


check_x_hilo:
		ldx $f6			// player x msb
		bne doXhi

doXlo:
		lda $f5
		cmp #$4c+$a  
		bcc !else+		// branch if f5 = playerX =< 4c+a = 56

		sec			// enough room to subtract
		lda $f5
		sbc #$4c-playerXtileOffset 
		sta $45		//f5
		jmp check_y_hilo
		
!else:		
		lda #$a			// not enough room, $a is minimum viewport X
		sta $45		//f5
		jmp check_y_hilo

doXhi:
		lda $f5
		cmp #$b4		
		bcs !else+		// branch if f5 = player X-($4c-4) >= $16c --> player X >= $16c+($4c-4) = $1b4
		
		sec			// enough room
		lda $f5
		sbc #$4c-playerXtileOffset		// offset=4
		sta $45		//f5
		lda $f6
		sbc #0
		sta $46		//f6
		jmp check_y_hilo
		
!else:		
		lda #$6c		// not enough room $16c is max
		sta $45		//f5
		
		
check_y_hilo:
		ldx $f8			// player x msb
		bne doYhi

doYlo:
		lda $f7
		cmp #$28+0		// $28 halfwidth, 0 is min
		bcc !else+		// branch if f7 = player Y < $28

		sec
		lda $f7
		sbc #playerYspriteOffset //			**************************************
		sta $47		//f7
		jmp !done+
		
!else:		
		lda #$0			//not enough room, $0 is min
		sta $47		//f7
		jmp !done+

doYhi:
		lda $f7
		cmp #$b4		// 
		bcs !else+		// branch if $f7,8 = player Y-($28-27) >= 1a7  --> player Y >= 1a7+($28-27) = $1b4   
		
		sec
		lda $f7
		sbc #playerYspriteOffset 	 //			***********************************************		
		sta $47		//f7
		lda $f8
		sbc #0
		sta $48		//f8
		jmp !done+
		
!else:		
		lda #$a7	//$a7 is max
		sta $47		//f7

!done:                           
	       lda ViewportCoordinateBase_zpw 
	       sta $ae                      
	       lda ViewportCoordinateBase_zpw+1 
	       sta $af   		//offset 0 = viewport Y
	       
	       ldy #0                     
	       lda $47		//f7                                                                            
	       sta ($ae),y 
	                        
	       lda $48		//f8                      
	       iny                          
	       sta ($ae),y     
	       	       
	       lda $45		//f5
	       iny                          
	       sta ($ae),y
	       
	       lda $46		//f6
	       iny                          
	       sta ($ae),y    
	
		// now compute sprite vpos and hpos
	       clc
	       lda $d3			//PlayerCoordinateBase_zp 
	       adc #4			//offset 4 = vpos
	       sta $ae                      
	       lda $d4			//PlayerCoordinateBase_zp+1 
	       sta $af   		
	
		// offset y
		clc
		lda $f7
		adc #$4c		//sprite offset?
		sta $f7
		lda $f8
		adc #$0
		sta $f8	 
	
		
		sec
		lda $f7			// player y
		sbc $47			// minus viewport y
		ldy #0
		sta ($ae),y
		lda $f8
		sbc $48
		iny
		sta ($ae),y		// to vpos

		sec
		lda $f5			// player x
		sbc $45			// minus viewport x
		clc
		adc #$13+h0		//sprite offset, must be correct relative to starting position so h0 offset is applied
		ldx PlayerIndex_zp
		sta p1HposV1,x		// to hpos			
//
	        rts                          
                                                  
                                                  
                                                  
// do the non-move effects, also displace the player to the teleportal if you're doing teleport animation 
// issue:  displacing the player in Y without stepping results in not erasing the prior shape data.
// need to ensure a full VBI at the old and new coordinates with shape pointer poining at a blank I think

// $f4 state  = 00=normal, 01=falling, 02=climbing, 03=jumping right, 04=jumping left, 05=inside floor, 06=stunned, 08=surprised, 09 teleporting
// $f0 look up table block = 07 first phase attacked, 09 first phase death, 0b robbed, 0c first phase teleport, 0d second phase teleport

.const TeleportTimeDelay1 = $68 	// if this ends too early, teleportal state machine gets out of sync $50 is marginally too short with 1/3
					// clocking in main loop and ai motion outside of irq in main loop
.const TeleportTimeDelay2 = $40                                                
                                                         
DO_NONMOVE_ANIMATION:          ldx PlayerIndex_zp           
                               lda NonMoveAnimSeq,x          
                               sta $f4                      
                               lda #$00                     
                               //ldx PlayerIndex_zp           
                               sta NonMoveAnimSeq,x   
                                     
                               lda $f4                      
                               eor #$08               // is surprised by attack (robbed)	   
                               beq !L1E86+                  
                               jmp !L1E91+            // else is hurt by attack      
                                                         
!L1E86:                        lda #$08                     
                               sta $f1                  // $f1 controls whether player can interact with map during animation sequence    
                               lda #$0b                     
                               sta $f0                      
                               rts	//internal jmp !L1F18+               // exit   
                                                         
!L1E91:                        lda $f4                      
                               eor #$06 		// is already stunned/hurt                    
                               beq !L1E9A+                  
                               jmp !L1EA5+              // no    
                                                         
!L1E9A:                        lda #$06                 // when zombie is hit with weapon, does not go through this path *****************************
                               sta $f1                      
                               lda #$07                 // set the stunned animation sequence    
hurt:                          sta $f0                      
                               rts	//internal jmp !L1F18+               // exit   
                                                         
!L1EA5:                        lda $f4                      
                               eor #$09               // is starting teleport     
                               beq !L1EAE+                  
                               jmp !L1EB5+                  
                                                         
!L1EAE:                        lda #$09                     
                               sta $f1                      
                               rts	//internal jmp !L1F18+             // exit     
                                                         
!L1EB5:                        lda $f4                      
                               eor #$0a                     	// is during teleport
                               beq !L1EBE+                  
                               jmp !L1ED7+                  
                                                         
!L1EBE:                        			    
			       lda #$0c                     	// start first phase of teleport: starting portal location
                               sta $f0                      	// change anim sequence to entering portal. auto-chained to blank sequence $0e
                               lda #$09                     
                               sta $f1                      
                               lda #$0b                     
                               //ldx PlayerIndex_zp           
                               sta NonMoveAnimSeq,x         
                               lda #TeleportTimeDelay1  //#$3c              
                               //ldx PlayerIndex_zp           
                               sta PlayerDelayCountdown,x   
                               rts	//internal jmp !L1F18+                  	// exit
                                                         
!L1ED7:                        
			       lda $f4                      
                               eor #$0b                     // is in second phase/ending teleport
                               beq !L1EE0+                  
                               rts	//internal jmp !L1F18+                  // exit
                                                         
!L1EE0:                        
				// don't do more until animation is actually blank. 
                               clc                              
                               lda PlayerCoordBase_zpw       
                               adc #$06                   	//offset 6 = player shape offset 0123, 4567 etc in sequence  
                               sta temp3                      	//used $a9,aa but crash
                               lda PlayerCoordBase_zpw+1     
                               adc #$00                     
                               sta temp3+1
                               ldy #$00                                                                  
blank:                         lda (temp3),y               	// player shape 
			       cmp #16				// blank
			       beq !n+
			       jmp !L1F11+			       
!n:
                               lda #1
                               sta BlankStrips_zp	// blank the other player strip
			       
			       
			       lda TeleportalMode           
                               eor #$02                     
                               beq !L1EEA+                  // if = 2, portal has moved in map and now ready to move player coordinates
                               jmp !L1F11+                  
                                                         
!L1EEA:                                                                                
!do_jump:
	                       ldx TeleportalY              
                               lda TeleportalX              
	                       jsr MOVE_PLAYER_TO_TELEPORT_EXIT 		// it's important that animation is in "blank" phase when this is called
                               lda #$00                     			// else shape data in opponent view's strip will not be blanked before Y jumps
                               ldx PlayerIndex_zp      	//need to restore X finally     
                               sta TryingToMoveFlag,x       
                               lda #$03                     
                               sta TeleportalMode           
                               lda #$09                     
                               sta $f1                      
                               lda #$0d                     			   // change anim sequence to exiting portal
                               sta $f0                      
                               lda #TeleportTimeDelay2	//#$3c                     // control lockout delay countdown was $3c
                               //ldx PlayerIndex_zp           
                               sta PlayerDelayCountdown,x   
                               rts		//internal jmp !L1F18+                  
                                                         
!L1F11:                        lda #$0b                     
                               //ldx PlayerIndex_zp         // path to here has not destroyed X  
                               sta NonMoveAnimSeq,x         	// is this the "done" flag?

!L1F18:                        rts                          




// Routine that reads the joystick bit registers which were set either by joystick motion or by the automated player (AI)
// control, and translates it into motion and animation of the player sprites. 
                                                         
EXECUTE_PLAYER_AI_MOTION:      ldx PlayerIndex_zp           
                               lda PlayerJoystickBits,x     
                               sta $f3                      
                               lda #$01                     
                               //ldx PlayerIndex_zp           
                               sta TryingToMoveFlag,x       
                               //ldx PlayerIndex_zp  		// joystick bits into $f3
                                        
                               lda PlayerControlMode,x      // 0=human, 1=AI, 2=AI in zombie mode
                               eor #$02                     
                               bne !CHECK_IF_ALIVE+                  
                               jmp !CHECK_IF_NONMOVE+       // if already zombie don't need to check if alive          
                                                         
!CHECK_IF_ALIVE:             //ldx PlayerIndex_zp           // if human check if still alive
                               lda PlayerLifeForce,x        
                               beq !IS_DEAD+                  
                               jmp !CHECK_IF_NONMOVE+        // else skip being dead stuff
                                                         
!IS_DEAD:                      lda $f1                      // if dead check $f1=motion state
                               eor #$07                     // I think this is check if in urn, reanimating
                               bne !L1F46+                  
                               jmp !L1F54+                  // check/service death delay
                                                         
!L1F46:                        lda SoundStateLo_zp 	
                               ora #$80                     
                               sta SoundStateLo_zp 		//set bit 7 of the motion/sound state register
                               lda #$09                     
dead:                          sta $f0                      	// sound effect state
                               lda #$07                     
                               sta $f1                      	// motion state

!L1F54:                        lda #$00                     
                               //ldx PlayerIndex_zp           
                               cmp PlayerDelayCountdown,x   
                               bcc !L1F60+           		// branch if delay counter > 0       
                               rts	//jmp !L1F6D+           //internal       
                                                         
!L1F60:                        sec                          // decrement delay counter and exit
                               //ldx PlayerIndex_zp           
                               lda PlayerDelayCountdown,x   
                               sbc #$01                     
                               //ldx PlayerIndex_zp           
                               sta PlayerDelayCountdown,x   
!L1F6D:                        rts                          //internal
                                                         
!CHECK_IF_NONMOVE:             lda #$00                     //check if player is in a non-move sequence like teleporting or being stunned
                               //ldx PlayerIndex_zp           
                               cmp NonMoveAnimSeq,x         
                               bcc !L1F7A+                  
                               jmp !L1F7D+                  
                                                         
!L1F7A:                        jsr DO_NONMOVE_ANIMATION     //execute the special animation sequence

!L1F7D:                        ldy #$09                     
                               ldx #$06                     
                               lda $f1                      
                               //jsr CHECK_A_BETWEEN_XY       //is motion state between 6 and 9 which are nonmove sequences?
                               //lda temp0 
			       A_BETWEEN_XY_IRQ()                     
                               bne !L1F8D+                  
                               jmp !L1FAE+                  
                                                         
!L1F8D:                        ldx PlayerIndex_zp           //if in a nonmove sequence, check if it is over
                               lda PlayerDelayCountdown,x   
                               beq !L1F97+                  
                               jmp !L1FA0+                  
                                                         
!L1F97:                        ldy #$00                     //it's over, set the states to idle
                               sty $f1                      // animation state
                               sty $f0                      // sound effect state
                               jmp !L1FAE+                  
                                                         
!L1FA0:                        sec                          
                               ldx PlayerIndex_zp           
                               lda PlayerDelayCountdown,x   
                               sbc #$01                     
                               //ldx PlayerIndex_zp           
                               sta PlayerDelayCountdown,x   
                               rts                          //internal
                                                         
!L1FAE:                        lda $f1                      
                               beq !L1FB5+                  
                               jmp !L2004+                  
                                                         
!L1FB5:                        lda $f3                      //check joystick bits
                               eor #$06                     
                               beq !L1FBE+                  //branch if up and to right
                               jmp !L1FDE+                  
                                                         
!L1FBE:                        lda #$03                     //set state to "jumping right"
                               sta $f1                      
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  //from $d5,6, address of animation base for this player $8034 or $803b
                               adc #$06                     //offset 6
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     
                               sta $af                      //$ae,f = $803a which is a counter associated with jumping motion
                               lda #$10                     
                               ldy #$00                     
                               sta ($ae),y		// initialize the jump sequence counter
                                                 
                               lda SoundStateLo_zp 
                               ora #$04                     
                               sta SoundStateLo_zp	//set the motion/sound state register bit 2
                               jmp !L2004+                  
                                                         
!L1FDE:                        lda $f3                     //check joystick bits 
                               eor #$0a                     
                               beq !L1FE7+                  //branch if up and to left
                               jmp !L2004+                  
                                                         
!L1FE7:                        lda #$04                     //set state to "jumping left"
                               sta $f1                      
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$06                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                     // $ae,f could be anything due to branch structure above
                               sta $af                      
                               lda #$10                     
                               ldy #$00                     //as above, initialize the jump sequence counter
                               sta ($ae),y 
                                                
                               lda SoundStateLo_zp 
                               ora #$04                     
                               sta SoundStateLo_zp	//set the motion/sound state register bit 2
                               
!L2004:                        lda $f1                      
                               eor #$03                     
                               beq !L200D+                  //branch if jumping right
                               jmp !L2017+                  
                                                         
!L200D:                        jsr WALK_RIGHT               //do jump up and displacement then exit
                               jsr DO_JUMPING_MOTION        
                               rts                          //internal
                                                         
                               jmp !L2027+                  
                                                         
!L2017:                        lda $f1                      
                               eor #$04                     
                               beq !L2020+                  //branch if jumping left
                               jmp !L2027+                  //not jumping either way, do other motion
                                                         
!L2020:                        jsr WALK_LEFT                //do jump up and displacement then exit
                               jsr DO_JUMPING_MOTION        
                               rts                          //internal
                                                         
!L2027:                        jsr CHECK_TILE_TRAVERSABLE     //returns whether it is possible to walk or climb on the tiles around map0  
                               lda temp0                      
                               sta $f1                      
                               //lda $f1                      
                               eor #$05                     //check if somehow got inside of floor or wall
                               beq !L2037+                  
                               jmp !L204B+                  
                                                         
!L2037:                        jsr ADJUST_Y_SLOPES_UNPHYS   //push player out of unphysical position
                               lda temp0                      
                               eor #$01                     
                               beq !L2043+                  
                               jmp !L204A+                  
                                                         
!L2043:                        ldy #$00                     
                               sty $f1                      
                               jmp !L204B+                  
                                                         
!L204A:                        rts                          //internal
                                                         
!L204B:                        lda $f1                      
                               eor #$01                     
                               beq !L2054+                  
                               jmp !L205F+                  
                                                          //used in falls
!L2054:                        jsr movePlayerDown         //get back into position and exit, can't do two displacements per cycle
#if DOUBLEDOWN
		               jsr movePlayerDown
#endif      
                               ldy #$00                     
                               sty $f0                      
                               rts                          //internal
                                                         
!L205F:                        ldx map0_zpw+1                      
                               lda map0_zpw                      
	                       jsr CHECK_IF_TILE_CLIMBABLE_1 //map0 pointer, player tile in map memory
                               lda temp0                      
                               bne !L206D+                //branch if climbable
                               jmp !L2078+                  
                                                         
!L206D:                        lda #$03                     
                               sta $f0                      
                               lda #$02                     
                               sta $f1                   // set $f0=3, $f1=2  which I think is the state where sprite turns into climbing/standing position
                               jmp !L207C+                  
                                                         
!L2078:                        ldy #$00                     
                               sty $f0			// else set $f0=0
                                                     
!L207C:                        clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$06                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 	// get jump counter from offset 6
                               adc #$00                     
                               sta $af 
                                                    
                               lda #$00                     
                               ldy #$00                     
                               cmp ($ae),y               	   
                               bcc !L2094+                  // branch if jump counter > 0
                               jmp !L20BC+                  
                                                         
!L2094:                        //clc                          
                               //lda PlayerSpriteCtrlBase_zpw  
                               //adc #$06                     
                               //sta $ae                      
                               //lda PlayerSpriteCtrlBase_zpw+1 
                               //adc #$00                     
                               //sta $af                      						// +++ $ae,f offset 6 from above
                               sec                          
                               lda ($ae),y                  
                               sbc #$01                     
                               sta ($ae),y		// decrement jump counter
                                                 
                               clc                          
                               lda PlayerSpriteCtrlBase_zpw  
                               adc #$01                     
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               adc #$00                  // $ae,f = offset zero animA offset into table  
                               sta $af                      
                               lda ($ae),y                  
                               sta $f0                  // set $f0 to table row     
                               jmp !L2105+              // jumping, so skip all other normal motions    
                                                        
                                                        
                               // this block, get joystick position and do the motion                          
!L20BC:                        lda $f3                      
                               and #$08                     
                               sta $ae                      
                               //lda $ae                      
                               beq !L20C9+                  
                               jmp !L20CF+                  
                                                         
!L20C9:                        jsr WALK_RIGHT               
                               jmp !L2105+                  
                                                         
!L20CF:                        lda $f3                      
                               and #$04                     
                               sta $ae                      
                               //lda $ae                      
                               beq !L20DC+                  
                               jmp !L20E2+                  
                                                         
!L20DC:                        jsr WALK_LEFT                
                               jmp !L2105+                  
                                                         
!L20E2:                        lda $f3                      
                               and #$01                     
                               sta $ae                      
                               //lda $ae                      
                               beq !L20EF+                  
                               jmp !L20F5+                  
                                                         
!L20EF:                        jsr CLIMB_UP                 
                               jmp !L2105+                  
                                                         
!L20F5:                        lda $f3                      
                               and #$02                     
                               sta $ae                      
                               //lda $ae                      
                               beq !L2102+                  
                               jmp !L2105+                  
                                                         
!L2102:                        jsr CLIMB_DOWN  
             
!L2105:                        lda $f1                      
                               beq !L210C+                  
                               rts			//internal jmp !L210F+                  
                                                         
!L210C:                        jsr ADJUST_Y_SLOPES_UNPHYS
   
!L210F:                        rts



                          
                                                         
 // This routine sets up relevant pointers to the current player with index passed in A, computes the player own-sprite and opposing-player sprite
// positions from player coordinates and viewport coordinates, computes the map tile coordinates from the player coordinates, computes the map
// tile memory location from the player coordinates, selects the base shape to use for the animation, gets the control inputs either from joystick
// or the automated (AI opponent) routines, and passes that to EXECUTE_PLAYER_AI_MOTION.  On return from that routine it updates some of the shape
// sequence variables in $80xx and zp in the event that the result of the motion changes the needed shape (e.g. stopped walking, becomes standing)
                                                                                                                
                                                         
!whichPlayer:                  .byte $01        //which player          
!localTemp1:                   .byte $20 	// two temp vars used to calculate the map memory location from the tile coordinates via the lookup tables at 9200, 9240                     
!localTemp2:                   .byte $09                      
                                                         
PLAYER_MAIN_MOTION_SEGMENT:   //jmp !L24D1+                  
                                                         
!L24D1:                        sta !whichPlayer-               
                               lda !whichPlayer-               
                               sta PlayerIndex_zp

// need these bits to set up the zp pointers to player, view, and animation table
                                           
                               lda PlayerIndex_zp           
                               asl                         // player idx*2 
                               php                         // C to stack
                               clc                          
                               adc ptrAnimBaseSelect       // lsb of pointer to pointer that selects the animBase, always $4a
                               sta $ae                     // ptr to ptr in animBase with offset 2 = animBase of player 1 or player 2...so $ae = $4a or $4c, lsb of ptrToPlayerAnimBase
                               lda #$00                     
                               rol                         // rol in the carry 
                               plp                         // recover carry from the result of asl PlayerIndex_zp 
                               adc ptrAnimBaseSelect+1      
                               sta $af			   // $ae,f contains the ptrToPlayer1AnimBase $8034 or ptrToPlayer2AnimBase $803b as selected by PlayerIndex_zp
                                                     
                               ldy #$01                     
                               lda ($ae),y                 // Y=1 
                               sta PlayerSpriteCtrlBase_zpw+1 
                               dey                         // Y=0  
                               lda ($ae),y                  
                               sta PlayerSpriteCtrlBase_zpw // set the row in the animation table from which to pull the sequence
                                 
	                       lda PlayerIndex_zp           
                               asl                          
                               php                          
                               clc                          
                               adc ptrCoordBaseSelect       
                               sta $ae                      
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrCoordBaseSelect+1     
                               sta $af                      
                               iny            		            
                               lda ($ae),y		// Y=1                    
                               sta PlayerCoordBase_zpw+1     
                               dey                          
                               lda ($ae),y		// Y=0                    
                               sta PlayerCoordBase_zpw	// set the zp pointer to the player coordinate base
                               
                                      
                               lda PlayerIndex_zp           
                               asl                          
                               php                          
                               clc                          
                               adc ptrViewYCoordSelect      
                               sta $ae                      
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrViewYCoordSelect+1    
                               sta $af                      
                               iny                          
                               lda ($ae),y 		// Y=1                   
                               sta ViewportCoordinateBase_zpw+1 
                               dey                          
                               lda ($ae),y		// Y=0                    
                               sta ViewportCoordinateBase_zpw	// set the zp pointer to the player viewport coordinate base



		// Since I appear to be starved for rastertime I'm going to avoid the indirect addressing the original code relies on so much
		// Need to do the tile-coordinate conversions here because the various positioning routines rely on them.

				lda PlayerIndex_zp
				bne !player2+
			
!player1:			// convert player 1 global 16-bit coordinates to map tile space
				clc			// X
				lda p1Xpos16
				adc #playerXtileOffset  // offset, which is 13 in the original code	
				sta mathTemp0
				and #$7
				sta L1803		//lower three bits of (lsb player X + 13), used by slope and unphysical position adjust algos
				lda p1Xpos16+1
				adc #0
				//sta mathTemp1
				
				//lsr mathTemp1	// shift msbit into carry
				lsr		// save 5 cycles
				ror mathTemp0		// divide by 2
				lda mathTemp0
				lsr		// divide by 2
				sta PlayerTileXcoordinate
				
				clc
				lda p1Ypos16	// Y
   				adc #playerYtileOffset	// offset; this is 7 in atari code
				sta mathTemp0
				and #$7
				sta L1804	//lower three bits of (lsb player Y + offset) used by slope and unphysical position adjust algos
				lda p1Ypos16+1
				adc #0
				//sta mathTemp1
					
				//lsr mathTemp1	// shift msbit into carry
				lsr		// save 5 cycles
				ror mathTemp0		// divide by 2
				lda mathTemp0
				lsr
				lsr		// divide by 4
				clc
				sta PlayerTileYcoordinate	//in Atari code, this is an intermediate result because the final tile Y = (Y16 - 7)/8 - 1

		
		// Create pointer to player 1 location in map in map0_zpw,e using the intermediate X and Y results
				clc                          
				ldx PlayerTileYcoordinate        
				lda YtoMapLsbTbl,x           
				adc PlayerTileXcoordinate         
				sta map0_zpw                            
				lda YtoMapMsbTbl,x           
				sta map0_zpw+1
				
				dec PlayerTileYcoordinate	// now final result  

				
				// original code does this only *after* the map0 pointer is constructed!
				// I think the point of this is that ladders etc are two tiles wide so the map needs to be
				// considered as a grid where the grid lines are on the boundaries between tiles,
				// where the objects need to be considered as centered on their tiles.
				lda L1803 	// lower three bits of (lsb player X + 13)                   
				and #$02	//eor $03 in original code                 
				beq !n+         //inc tile x if L1803 = 3 in original code
						//change to inc tile x if bit 2 is set in L1803                                                                       
	         
				inc PlayerTileXcoordinate	// add 1 every 4 steps... final result	
		!n:  			

				// diagnostic
//				lda L1803
//				sta $b5
							
				jmp !tilesDone+

	// . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .			
			
			
		
!player2:			// convert player 2 global 16-bit coordinates to map tile space
				clc			// X
				lda p2Xpos16
				adc #playerXtileOffset	//offset, 13 in atari code	
				sta mathTemp0
				and #$7
				sta L1803	//lower three bits of (lsb player X + 13), used by slope and unphysical position adjust algos
				lda p2Xpos16+1
				adc #0
				//sta mathTemp1
				
				//lsr mathTemp1	// shift msbit into carry 2+5=7 cycles vs just lsr_A = 2 cycles
				lsr
				ror mathTemp0		// divide by 2
				lda mathTemp0
				lsr		// divide by 2
				sta PlayerTileXcoordinate+1
				
				clc
				lda p2Ypos16	// Y
				adc #playerYtileOffset // offset; this is 7 in atari code
				sta mathTemp0
				and #$7
				sta L1804	//lower three bits of (lsb player Y + offset) used by slope and unphysical position adjust algos
				lda p2Ypos16+1
				adc #0
				//sta mathTemp1
					
				//lsr mathTemp1	// shift msbit into carry 2+5=7 cycles vs just lsr_A = 2 cycles
				lsr
				ror mathTemp0		// divide by 2
				lda mathTemp0
				lsr
				lsr		// divide by 4
				clc
				sta PlayerTileYcoordinate+1	//in Atari code, this is an intermediate result because the final tile Y = (Y16 - 7)/8 - 1


		// Create pointer to player 2 location in map in map0_zpw,e using the intermediate X and Y results
				clc                          
				ldx PlayerTileYcoordinate+1        
				lda YtoMapLsbTbl,x           
				adc PlayerTileXcoordinate+1          
				sta map0_zpw                            
				lda YtoMapMsbTbl,x           
				sta map0_zpw+1
				
				dec PlayerTileYcoordinate+1	// now final result  

				
				// original code does this only *after* the map0 pointer is constructed!
				// I think the point of this is that ladders etc are two tiles wide so the map needs to be
				// considered as a grid where the grid lines are on the boundaries between tiles,
				// where the objects need to be considered as centered on their tiles.
				lda L1803 	// lower three bits of (lsb player X + 13)                       
				and #$02	//eor $03 in original code                
				beq !n+         //inc tile x if L1803 = 3 in original code
						//change to inc tile x if bit 2 is set in L1803                                                                            
	         
				inc PlayerTileXcoordinate+1	// add 1 every 4 steps... final result	
		!n:  	

		
!tilesDone:		
                            
!L265D:                        ldx PlayerIndex_zp           
                               lda PlayerShapeSelect,x      	// the current shape 0=normal, 1=falling, 2=climbing --> upper nybble of shape selector
                               sta $f1        
                                            
                               lda PlayerSpriteCtrlBase_zpw  	// i.e. $d5,6
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               sta $af                      	// pointer to current combined shape index e.g. to $803b

                               ldy #$00                     
                               lda ($ae),y                  
                               sta $f0                      // put combined shape index in $f0.  At this point $f0,1 = 01,00 walk left; 02,00 walk right; 00,00 stand etc.


                               lda #$00                     
                               //ldx PlayerIndex_zp         // +++ still in X from above
                               cmp PlayerControlMode,x      // 0=human, 1=AI, 2=AI in zombie mode
                               //bcc !L267E+
			       bcc !L269A+
/*			                         
                               jmp !L2684+                  
                                                         
!L267E:                        //jsr AI_MOTION_CONTROL 	// put auto control into joystick registers
                               jmp !L269A+                  
*/
                                                         
!L2684:                        lda PlayerIndex_zp           	// else, get input from sticks and triggers
                               //jsr GET_JOYSTICK		// inline the now modified joystick routine here, to get it out of block2
!GET_JOYSTICK:                                        
                               beq !GET_PLAYER1+            
                               jmp !GET_PLAYER2+            
                                                         
!GET_PLAYER1:                  lda CIAPRA                   
                               and #$0f
                               ora Player1JoyMask:#$00                     
                               sta PlayerJoystickBits

	                       lda #%00010000		//trigger
			       bit CIAPRA
			       bne !n+
			       lda #0
			       jmp !done+
!n:	       		       lda #1		
!done:
			       sta PlayerJoyTrigger                             
                               jmp !EXIT+

                                                         
!GET_PLAYER2:                  lda CIAPRB                    
			       and #$0f
			       ora Player2JoyMask:#$00                          
                               sta PlayerJoystickBits+1  
                               
                               lda #%00010000		//trigger
			       bit CIAPRB
			       bne !n+
			       lda #0
			       jmp !done+
!n:	       		       lda #1		
!done:
			       sta PlayerJoyTrigger+1                                                                                                                                     
!EXIT:                                                                
                                     
!L269A:                        jsr EXECUTE_PLAYER_AI_MOTION 	// do the motion corresponding to the joystick registers

                               lda $f1                      	// I believe the motion routine updates $f1 e.g. if the motion state has transitioned from walking to standing etc.
                               ldx PlayerIndex_zp           
                               sta PlayerShapeSelect,x      	// update to match the new shape
                               
                               lda PlayerSpriteCtrlBase_zpw  
                               sta $ae                      
                               lda PlayerSpriteCtrlBase_zpw+1 
                               sta $af                      
                               lda $f0                      
                               ldy #$00                     
                               sta ($ae),y                  	// stores $f0 in animA
                               rts                          
         
         
                          
                                                      
                     
