/* 	separate ai motion routines from the bulk of block0

//	Implement computer player motion
//
//	This file contains data and instructions disassembled and reverse-engineered from the binary
//	of the original Schreckenstein game found at memory locations $1000-$26C0, implementing
//	motion control of the computer player.  Portions have been deleted, rewritten, or modified to
//	accomodate the C64 hardware and the structure of the port to that platform.  The majority
//	of the code in this block was written by Peter Finzel, and is used here with his written
//	permission.



	This file implements AI_MOTION_CONTROL which is called by block0.PLAYER_MAIN_MOTION_SEGMENT each frame when PlayerControlMode is 1=AI or 2=Zombie
	Uses anywhere from about 173 cycles when climbing to 500 or more when turning around at a wall

	irq embedded version. Reverted all the variable changes:
	AiControlMask_zp = $f2 is only used here			
	$a0, $a1, $a2, $ac, $ae are used and conflict	
	map0_zpw, map1_zpw are used and conflict		 

	these calls conflict					
	CHECK_A_BETWEEN_XY 					3 instances in this code. inlined them with a macro returning result in A to save a few cycles
	CHECK_IF_TILE_CLIMBABLE_1,2				3 instances in this code, map pointer passed in A,X -- map pointer was set in block0 so I need to do it here


	2023-10-19	v2: simplified PlayerControlMode=1 so that it uses fewer cycles, shrank by commenting out check enemy and trigger weapon subroutines
	2023-10-27	v3: fix map0 math, minor optimzations of sta...lda type
	2023-12-06	v4: temp labels for relocation, new A_BETWEEN_XY macro for new parameter passing isolated to irq handlers
	2024-11-24	v5: separate PlayerIndexIRQ_zp to avoid save/restore PlayerIndexIRQ_zp, optimization of ldx in teleportal routines
	2024-12-03	v5: increased AI probability to climb from rand > $64 to rand > $40 
			
*/



// ......................................................................


GET_TILE_ONE_OR_TWO_BELOW:     ldy #$80                     
                               lda (map1_zpw),y                  
                               ldy #$00                     
                               inc map1_zpw+1     
                               ora (map1_zpw),y                  
                               sta temp0                      
                               rts 

// ......................................................................


!AonEntry:                     .byte $a9                      
                                                         
AI_DECISION_TO_JUMP:           jmp !L213F+                  
                                                         
!L213F:                        sta !AonEntry-               
                               lda #$00                     
                               cmp !AonEntry-               
                               bcc !L214C+                  
                               jmp !L215E+                  
                                                         
!L214C:                        ldy #$00                     
                               lda (map1_zpw),y                  
                               eor !AonEntry-               
                               beq !L2158+                  
                               jmp !L215E+                  
                                                         
!L2158:                        lda AiControlMask_zp                      
                               ora #$01                     
                               sta AiControlMask_zp                      
!L215E:                        jsr GET_TILE_ONE_OR_TWO_BELOW 
                               lda temp0                      
                               beq !L2168+                  
                               jmp !L2197+                  
                                                         
!L2168:                        lda PlayerIndexIRQ_zp           
                               eor #$01                     
                               sta $ae                      
                               clc                          
                               ldx PlayerIndexIRQ_zp           
                               lda PlayerTileYcoordinate,x  
                               adc #$01                     
                               sta $ac                      
                               ldx $ae                      
                               lda PlayerTileYcoordinate,x  
                               cmp $ac                      
                               bcc !L2184+                 
                               jmp !L2197+                  
                                                         
!L2184:                        ldx PlayerIndexIRQ_zp           
                               lda L1838,x                  
                               cmp SID_RANDOM  //SKREST_ATARI             
                               bcc !L2191+                  
                               jmp !L2197+                  
                                                         
!L2191:                        lda AiControlMask_zp                      
                               ora #$01                     
                               sta AiControlMask_zp                      
!L2197:                        rts                          


// ......................................................................

/*				//no longer used due to cycletime considerations 
                                                 
!AonEntry:                     .byte $38                      
                                                         
CHECK_ENEMY_AT_A:              jmp !L219C+                  
                                                         
!L219C:                        sta !AonEntry-
               
                               sec                          
                               lda map0_zpw                      
                               sbc !AonEntry-           // subtract map offset that was passed in accumulator    
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1
                                    
                               ldy #$00                  // get from map   
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta temp0                      
                               ldy #$28                     
                               ldx #$23                     
                               //lda temp0                      
                               //jsr CHECK_A_BETWEEN_XY       // is it a bat, small ghost, or spider?                             
			       A_BETWEEN_XY()	// returncode in A      
			       //lda temp0               // seems redundant but zero flag could be clobbered by irq. need to save status reg?
                               bne !L21C5+                  
                               jmp !L21CB+                  
                                                         
!L21C5:                        lda AiControlMask_zp                      
                               eor #$0c                     
                               sta AiControlMask_zp                      
!L21CB:                        rts                          

*/ 
                                            
// ......................................................................                                            

/*				//no longer used due to cycletime considerations 
                                                                                                                 
!AonEntry:                     .byte $38                      
                                                         
AI_TRIGGER_WEAPON:             jmp !L21D0+                  
                                                         
!L21D0:                        sta !AonEntry-               
                               sec                          
                               lda map0_zpw                      
                               sbc !AonEntry-               
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1    
                                
                               ldy #$00                     
                               lda (map1_zpw),y                  
                               and #$7f                     
                               sta temp0                      
                               ldy #$28                     //this range comprises baddie shapes, bats, ghosts, spiders
                               ldx #$23                     
                               //lda temp0                      
                               //jsr CHECK_A_BETWEEN_XY       
			       A_BETWEEN_XY()		// returncode in A
			       //lda temp0                                   
                               bne !L21F9+                  
                               jmp !L2200+                  
                                                         
!L21F9:                        lda #$00                     
                               ldx PlayerIndexIRQ_zp           
                               sta PlayerJoyTrigger,x       //activate trigger
!L2200:                        rts                          
                                                         
*/ 
                                                         
// ......................................................................
                                                                                                               
!AonEntry:                     .byte $21                      
!XonEntry:                     .byte $8d                      
                                                         
AI_DECISION_TO_CLIMB:          jmp !L2206+                  
                                                         
!L2206:                        stx !XonEntry-               
                               sta !AonEntry-               
                               sec                          
                               lda map0_zpw                      
                               sbc !AonEntry-               
                               sta temp0                      
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta temp1                      
                               ldx temp1                      
                               lda temp0                      
                               jsr CHECK_IF_TILE_CLIMBABLE_2 
                               lda temp0                      
                               eor #$01                     
                               beq !L222A+                  
                               jmp !L2243+                  
                                                         
!L222A:                        lda #$40		//#$64        	   was $64, but increase probability because sometimes gets stuck             
                               cmp SID_RANDOM  			// SKREST_ATARI             
                               bcc !L2234+                  	// don't climb if random > $64
                               jmp !L223C+                  	// else climb
                                                         
!L2234:                        lda !XonEntry-               
                               sta AiControlMask_zp                      
                               jmp !L2243+                  	// no, exit
                                                         
!L223C:                        lda #$01                     
                               ldx PlayerIndexIRQ_zp           
                               sta PlayerCanClimbFlag,x     
!L2243:                        rts                        



// ......................................................................
                                                                               
SET_TELEPORTAL_TARGET:      //opt: pass PlayerIndexIRQ_zp in X, and preserve X   
                               lda TeleportalState          
                               beq !L2125+                  
                               jmp !L213A+          // exit        
                                                         
!L2125:                        //ldx PlayerIndexIRQ_zp           
                               lda PlayerTileXcoordinate,x  
                               sta TeleportalTargetX        
                               //ldx PlayerIndexIRQ_zp           
                               lda PlayerTileYcoordinate,x  
                               sta TeleportalTargetY        
                               ldy #$01                     
                               sty TeleportalState    
                                     
!L213A:                        rts                          
          



// ......................................................................
// ......................................................................

                                                         
!temp1:                        .byte $a6                      
!temp2:                        .byte $db                      
                                                         
AI_MOTION_CONTROL:  	       //jmp !L2249+     
                                                         
!L2249:				
			      // need to create pointer to player position in map0, this was done by the caller when it was embedded in block0
			      // since this can be called for either player we need to redo the math 
				
				ldx PlayerIndexIRQ_zp
				beq !player1+
				
!player2:			clc                     //2    
				ldy PlayerTileYcoordinate+1           	//4
				iny					//2	due to weird math for map0
				lda YtoMapLsbTbl,y      //4     
				adc PlayerTileXcoordinate+1           	//4
				sta map0_zpw           //3     			this x-coordinate is wrong, real map0 uses X before fractional adjust
				lda YtoMapMsbTbl,y      //4     
				sta map0_zpw+1    	//3	26 cycles
				jmp !go+
 
!player1:			clc                          
				ldy PlayerTileYcoordinate
				iny					// due to weird math for map0        
				lda YtoMapLsbTbl,y           
				adc PlayerTileXcoordinate           
				sta map0_zpw                           //	this x-coordinate is wrong, real map0 uses X before fractional adjust 
				lda YtoMapMsbTbl,y           
				sta map0_zpw+1    


!go:				// now start the AI mechanics proper
                               lda #$01                     
                               //ldx PlayerIndexIRQ_zp           
                               sta PlayerJoyTrigger,x       		// unset joy trigger

                               lda #$f5                     		// decide whether or not to set trigger to throw weapon
                               cmp SID_RANDOM  //SKREST_ATARI             
                               bcc !L225A+                  		// probabalistic branch if random > $f5
                               jmp !L2261+                  
                                                         
!L225A:                        lda #$00                     
                               //ldx PlayerIndexIRQ_zp           
                               sta PlayerJoyTrigger,x       		// set joy trigger

!L2261:                        //ldx PlayerIndexIRQ_zp           
                               lda PlayerJoystickBits,x     		// get current control settings
                               eor #$0f                     
                               sta AiControlMask_zp                     // store in AiControlMask_zp
                               //lda AiControlMask_zp                      
                               eor #$0f                     		// compare with $0f = no input
                               beq !L2277+				// branch if no input
                                                 			
                               lda AiControlMask_zp                      
                               beq !L2277+                  		// branch if all directions are set (seems unphysical, but means all possibilities are still open/no decision yet)
                               jmp !L2282+                  
                               
                               // no input or all inputs, set AiControlMask_zp=2 and mark direction as blocked                          
!L2277:                        lda #$02                     		// set AiControlMask_zp = 2, eliminating the possibility to go down
                               sta AiControlMask_zp                      
                               lda #$00                     
                               //ldx PlayerIndexIRQ_zp           
                               sta TryingToMoveFlag,x       		// set movement = blocked can't move

!L2282:                        lda AiControlMask_zp                      		
                               and #$0c                     		// mask out stick left and right bits
                               sta $ae                      
                               //lda $ae                      		// store in a temp variable $ae
                               bne !L228F+  				// stick input contains left or right                
                               jmp !L2295+                  
                               
                               // allow left and right                          
!L228F:                        lda AiControlMask_zp                     // mask out left and right bits
                               and #$0c                     
                               sta AiControlMask_zp			// store in AiControlMask_zp
                                                     
!L2295:                        lda AiControlMask_zp                      
                               and #$03      				// mask out stick up and down bits	               
                               sta $ae                      
                               //lda $ae                      		// store in a temp variable $ae
                               bne !L22A2+                  		// stick input contains up or down
                               jmp !L22FB+                  		// else jump over all of the next stuff that considers right/left movement
                                                         
!L22A2:                        //ldx PlayerIndexIRQ_zp           		
                               lda TryingToMoveFlag,x       
                               beq !L22AC+                  		// branch if can't move in this direction
                               jmp !L22F8+                  		// else jump over all the next stuff that considers right/left movement
                                                         
!L22AC:                        lda #$01                     		// set the desire to climb flag
                               //ldx PlayerIndexIRQ_zp           
                               sta PlayerCanClimbFlag,x     		
                               //ldx PlayerIndexIRQ_zp           
                               lda L1838,x                  		// L1838,9 probability of intentionally going towards other player vs making a random choice. smaller is more probable
                               cmp SID_RANDOM  //SKREST_ATARI             
hpursuit:                      bcc !L22C0+                  		// decide to go right/left towards other player if SID_RANDOM > L1838,x
                               jmp !L22E3+                  		// decide to try to climb
                                                         
!L22C0:                        lda PlayerIndexIRQ_zp           
                               eor #$01                     		// get the other player's index
                               sta $ae                      		// store in $ae
                               //ldx PlayerIndexIRQ_zp           
                               lda PlayerTileXcoordinate,x  
                               ldx $ae                      		// NOTE CHANGED X REGISTER, NEED TO RELOAD PLAYERINDEX
                               cmp PlayerTileXcoordinate,x  		
                               bcc !L22D5+                  		// branch if player X > opponent X
                               jmp !L22DC+                  
                                                         
!L22D5:                        lda #$08     				// set AiControlMask_zp=8, eliminating the possibility to go right                
                               sta AiControlMask_zp                      
                               jmp !L22E0+                  
                                                         
!L22DC:                        lda #$04      				// set AiControlMask_zp=4, eliminating the possibility to go left               
                               sta AiControlMask_zp                      
!L22E0:                        jmp !L22F8+                  
                                        
                                        
                                                         
!L22E3:                        lda #$7f                     		// decided not to climb so must decide whether to change direction
                               cmp SID_RANDOM  //SKREST_ATARI             
                               bcc !L22ED+                  
                               jmp !L22F4+                  
                                                         
!L22ED:                        lda #$08                    		 
                               sta AiControlMask_zp                      		// eliminate left
                               jmp !L22F8+                  		// skip all the climbinb stuff below
                                                         
!L22F4:                        lda #$04                     
                               sta AiControlMask_zp                      		// eliminate right
!L22F8:                        jmp !L2421+                  		// skip all the climbing stuff below


                               // . . . . . . . . . . . . . . . . big jump skips stuff below  . . . . . . . . . . . . . . . . . . 
                                                         
!L22FB:                        ldx PlayerIndexIRQ_zp           
                               lda PlayerCanClimbFlag,x     
                               beq !L2305+                  
                               jmp !L2359+                  		// continue to try to climb upward
                                                         
!L2305:                        //ldx PlayerIndexIRQ_zp           
                               lda L1838,x                  		// L1838,9 probability of intentionally going towards other player vs making a random choice. smaller is more probable
                               cmp SID_RANDOM  //SKREST_ATARI             
vpursuit:                      bcc !L2312+                  		// locate other player and climb towards him
                               jmp !L233B+                  		// or do random choice
                                                         
!L2312:                        lda PlayerIndexIRQ_zp           		// find other player
                               eor #$01                     
                               sta $ae                      
                               //ldx PlayerIndexIRQ_zp           
                               lda PlayerTileYcoordinate,x  
                               ldx $ae                      		// NEED TO RELOAD X WITH PLAYERINDEX
                               cmp PlayerTileYcoordinate,x  
                               bcc !L2327+                  
                               jmp !L2331+                  
                                                         
!L2327:                        ldx #$02                     // eliminate down
                               lda #$00                     
                               jsr AI_DECISION_TO_CLIMB     
                               jmp !L2338+                  
                                                          
!L2331:                        ldx #$01                    // eliminate up  
                               lda #$80                     
                               jsr AI_DECISION_TO_CLIMB     
!L2338:                        jmp !L2356+                  
                                                         
!L233B:                        lda #$7f                     
                               cmp SID_RANDOM  //SKREST_ATARI             
                               bcc !L2345+                  
                               jmp !L234F+                  
                                                         
!L2345:                        ldx #$02                     // eliminate down
                               lda #$00                     
                               jsr AI_DECISION_TO_CLIMB     
                               jmp !L2356+                  
                                                         
!L234F:                        ldx #$01                     // eliminate up
                               lda #$80                     
                               jsr AI_DECISION_TO_CLIMB     
!L2356:                        jmp !L2394+                  
                               
                               // look for climbing substrate above player         map pointers need to be set in this block!               
!L2359:                        ldx map0_zpw+1                      
                               lda map0_zpw                      
                               jsr CHECK_IF_TILE_CLIMBABLE_1 
                               lda temp0                      
                               sta !temp1-                  // temp1 = tile behind player is climbable
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
                               sta !temp2-                // temp2 = tile above player is climbable  
                               lda !temp1-                  
                               ora !temp2-                  
                               sta $ae                	 // $ae = 1 means player can climb from this position      
                               //lda $ae                      
                               beq !L238D+               // if zero player can't climb 
                               jmp !L2394+                  
                                                         
!L238D:                        lda #$00                     // indicate that player can't climb from here
                               ldx PlayerIndexIRQ_zp           // NEED X WAS CLOBBERED
                               sta PlayerCanClimbFlag,x
                                    
!L2394:                        ldx PlayerIndexIRQ_zp           // NEED X WAS CLOBBERED
                               lda TryingToMoveFlag,x       
                               eor #$01                     
                               bne !L23A0+                  
                               jmp !L23AC+                  
                                                         
!L23A0:                        lda #$0c                     
                               //and #$0c                     // why do this? no effect...
                               sta $ae                      
                               lda AiControlMask_zp                      
                               eor $ae                      
                               sta AiControlMask_zp                      
!L23AC:                        lda AiControlMask_zp                      
                               eor #$08                     
                               beq !L23B5+                  
                               jmp !L23E8+                  
                                                         
!L23B5:                        sec                          
                               lda map0_zpw                      
                               sbc #$7f                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1
                                    
//                             ldx PlayerIndexIRQ_zp           	// don't run control mode 1 as it takes too long
/*                             lda PlayerControlMode,x       
                               eor #$01                     
                               beq !L23CE+                  
                               jmp !L23E0+                  
                                                         
!L23CE:                        lda #$2b                     	// this block part of control mode 1
                               jsr AI_DECISION_TO_JUMP      
                               lda #$7f                     
                               jsr CHECK_ENEMY_AT_A      
                               lda #$7e                     
                               jsr AI_TRIGGER_WEAPON        
                               jmp !L23E5+               	*/  
                                                         
!L23E0:                        lda #$00                    	// this block part of control mode 2
                               jsr AI_DECISION_TO_JUMP      
!L23E5:                        jmp !L2421+                  
                                                         
!L23E8:                        lda AiControlMask_zp                      
                               eor #$04                     
                               beq !L23F1+                  
                               jmp !L2421+                  
                                                         
!L23F1:                        sec                          
                               lda map0_zpw                      
                               sbc #$80                     
                               sta map1_zpw                     
                               lda map0_zpw+1                      
                               sbc #$00                     
                               sta map1_zpw+1
                                    
//                             ldx PlayerIndexIRQ_zp            
/*                             lda PlayerControlMode,x      // don't run control mode 1 as it takes too long
                               eor #$01                     
                               beq !L240A+                  
                               jmp !L241C+                  
                                                         
!L240A:                        lda #$80                     // this block part of control mode 1
                               jsr AI_DECISION_TO_JUMP      
                               lda #$80                     
                               jsr CHECK_ENEMY_AT_A      
                               lda #$81                     
                               jsr AI_TRIGGER_WEAPON        
                               jmp !L2421+                  */
                                                         
!L241C:                        lda #$00                     // this block part of control mode 2
                               jsr AI_DECISION_TO_JUMP    
                               
                               // . . . . . . . . . . . . . . . . big jump skips above  . . . . . . . . . . . . . . . . . . 
  
!L2421:                        lda AiControlMask_zp                      
                               eor #$08                     
                               beq !L2430+                  
                               lda AiControlMask_zp                      
                               eor #$04                     
                               beq !L2430+                  
                               jmp !L2436+                  
                                                         
!L2430:                        lda AiControlMask_zp                      
                               ora #$02                     // eliminate down
                               sta AiControlMask_zp 
                                                    
!L2436:                        lda #$28                   // lower limit = maximum probability of deciding to pursue other player  
                               ldx PlayerIndexIRQ_zp           
                               cmp L1838,x                // L1838,9 probability of intentionally going towards other player vs making a random choice. smaller is more probable 
                               bcc !L2442+                // **** 
                               jmp !L244F+                  
                                                         
!L2442:                        sec                       // ****this seems to be decrementing too fast   
                               ldx PlayerIndexIRQ_zp          
                               lda L1838,x               // L1838,9 probability of intentionally going towards other player vs making a random choice. smaller is more probable     
                               sbc #$01                  // make it more probable to go towards other player   
                               //ldx PlayerIndexIRQ_zp           
                               sta L1838,x              // L1838,9 probability of intentionally going towards other player vs making a random choice. smaller is more probable  

!L244F:                        lda L1805                 // watchdog counter to check if ai is spending too much time in one Y position   
                               beq !L2457+                  
                               jmp !L24B8+     		// decrement L1805, store joystick bits, and exit             
                               
                               // check if we are trapped on a floor                           
!L2457:                        lda #$c8                     
                               sta L1805                    // reset L1805 watchdog counter
                               ldx PlayerIndexIRQ_zp           
                               lda PlayerTileYcoordinate,x  
                               sta !temp1-                  // temp1 now has this ai player's Y coordinate
                               //ldx PlayerIndexIRQ_zp           
                               lda L183A,x                  // this is this ai player's Y coordinate from the last time we ran this routine
                               sta temp0
                                                     
                               sec                          
                               lda !temp1-                  
                               sbc #$03                     
                               sta temp1    
                                                 
                               clc                          
                               lda !temp1-                  
                               adc #$03                     
                               sta temp2		 // temp1 = tile Y - 3, temp2 = tile Y + 3
                                                     
                               ldy temp2                 // this ai player Y+3     
                               ldx temp1                 // this ai player Y-3     
hosed:                         lda temp0                 // are we still within +/-3 tiles of the Y position when this routine ran last?
                               //jsr CHECK_A_BETWEEN_XY       		//          in this code A = Y+3 usually
			       A_BETWEEN_XY_IRQ()	// returncode in A
			       //lda temp0              //                  
                               bne !L248B+         	// yes, summon the portal to come get us from this floor 
                               jmp !L2495+         	// no, we are moving in Y so don't need to call the portal         
                               
                               // whether this works OK is sensitive to TeleportTimeDelay1 needs to be >$50 for sure                          
!L248B:                        lda #$b4                     // reset the pursuit probability to 30%			
                               ldx PlayerIndexIRQ_zp	    // zapped by a_between   
                               sta L1838,x                  // L1838,9 probability of intentionally going towards other player vs making a random choice. smaller is more probable 

							    // optimization: SET_TELEPORTAL_TARGET needs PlayerIndexIRQ_zp in X, and it will preserve X
                               jsr SET_TELEPORTAL_TARGET    // bring the teleportal to player indexed by PlayerIndexIRQ_zp, IF TeleportalState = 0

!L2495:                        lda !temp1-                  // temp1 still has this player's Y coordinate
                               ldx PlayerIndexIRQ_zp        // zapped by a_between 
                               sta L183A,x                  // save this player's Y coordinate in L183A
                               lda #$32                     
                               cmp L1806                    
                               bcc !L24A7+                  
                               jmp !L24B2+                  
                                                         
!L24A7:                        ldy #$00                     
                               sty L1806                    
                               jsr SET_TELEPORTAL_TARGET // bring the teleportal to player indexed by PlayerIndexIRQ_zp , IF TeleportalState = 0
                               jmp !L24B5+              // set PlayerJoystickBits and exit     
                                                         
!L24B2:                        inc L1806                    
!L24B5:                        jmp !L24C1+      	// set PlayerJoystickBits and exit            
                                                         
!L24B8:                        sec                          
                               lda L1805                    
                               sbc #$01                     
                               sta L1805
                                                   
!L24C1:                        lda AiControlMask_zp                      
                               eor #$0f                     
                               //ldx PlayerIndexIRQ_zp	//opt           
                               sta PlayerJoystickBits,x     
                               
                               rts                          
                                                         