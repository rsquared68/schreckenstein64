//  block1_26c0-3fe6.bin.csv translated from SourceGen with kickass-translate.py v0.1
//
//	Implement game mechanics
//
//	This file contains data and instructions disassembled and reverse-engineered from the binary
//	of the original Schreckenstein game found at memory locations $26C0-$3FE6, implementing
//	game mechanics and motion of the enemies.  Portions have been deleted, rewritten, or modified
//	to accomodate the C64 hardware and the structure of the port to that platform.  The majority
//	of the code in this block was written by Peter Finzel, and is used here with his written
//	permission.
//
//
//  *****WARNING:  MULTI-LABELS MAY NOT ALWAYS BE RESOLVED CORRECTLY, PLEASE CHECK MANUALLY
//
//  *****WARNING:  MUST MANUALLY SET ZEROPAGE LABELS WITH .zp { }
 
// 6502bench SourceGen v1.8.5-dev1       
 /*
 		2023-10-07	changed some labels clarifying EnemySubstrateTbl1,2,3 used locally vs EnemySubstrateIndexTbl global
				made relocatable by fixing some pointer references

		2023-10-17	some small optimizations in lightning related routines

		2023-10-17	patch to add_life to prevent zombie from getting life points on level advance in 1 player mode

		2023-10-19	v7 added logic to keep objects from being put to close to walls. added logic to return candle held by zombie to map

		2023-10-24	v8, removed most "jmp !START+" headers, fixed broken logic in object placement introduced in v7,
				make main routine run weapons twice per iteration to prevent slowdown during magic phase

		2023-10-25	still v8, inline jumps to rts / internal, inline CHECK_A_BETWEEN_XY

		2023-10-27	v9 from v8b, removed patches to shift tile y because I fixed implementation error in block0

		2023-11-30	v10 tweaks to sound handling, Improved sound-queue handler so that it doesn't push a sound into $cc unless
				voice 2 is inactive (in CLOCKED_something decrement etc)

		2023-12-21	v11 made score data relocatable with labels L060x etc., veto bat chirp sound when more important sound playing

 */
      
                                                           


// =================================================================================================================== 
 
 				// I labeled these since I found no references anywhere in the code disassembled
				// so far, but they are analogous to the other jump tables 1-7
                                                         
JUMP_8:                        jmp CREATE_DESTROY_ENEMIES_WEAPONS                                                         
JUMP_9:                        jmp ENEMIES_FOR_LEVEL        		// uses L0609 but L0609 is never written anywhere?


// ===================================================================================================================
//		Local variables for map object states
// ===================================================================================================================                                                         
WeaponGroupNum:                .byte $00                      
                               .byte $cf                      
tempSubstrate1:                .byte $5f                      
tempSubstrate2:                .byte $00                      
tempSubstrate3:                .byte $5d                      
WeaponIdx:                     .byte $00                      
PlayerNum:                     .byte $01                      
WeaponXtbl:                    .byte $00                      
                               .byte $00                      
                               .byte $04                      
                               .byte $00                      
WeaponYtbl:                    .byte $00                      
                               .byte $00                      
                               .byte $04                      
                               .byte $00                      
WeaponPropCtrTbl:              .byte $00                      
                               .byte $00                      
                               .byte $04                      
                               .byte $00                      
WeaponDirectionTbl:            .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
EnemyTilesTbl_3:               .byte $a3 & $7f                     
                               .byte $a5 & $7f                     
                               .byte $27                      
EnemySubstrateTbl1:            .byte $00     			//there is an issue here, this is misspelled but EnemySubstrateTbl is defined in labels.asm and is used by                  
                               .byte $00                      
                               .byte $50                      
EnemySubstrateTbl2:            .byte $00                      
                               .byte $00                      
                               .byte $50                      
EnemySubstrateTbl3:            .byte $5f                      
                               .byte $5f                      
                               .byte $50                      
WeaponTileTbl:                 .byte $20                      
                               .byte $21                      
WeaponState:                   .byte $01                      
                               .byte $01                      


// ===================================================================================================================
//	Routines handling map objects and their interactions, abstraction increasing down listing
// =================================================================================================================== 

                                                         
// Erases enemy tiles from map and replaces them with expected substrates (empty                           
// air or spiderwebs etc)                                
// Pointer to map space passed in via $dc,$de and enemy type passed in via A                           
ERASE_ENEMY:                   tay                          
                               lda EnemyTilesTbl_3,y        
                               sta $a0                      
                               ldx EnemySubstrateTbl1,y
                                      
                               ldy #$00                     
                               lda (map2_zpw),y               
                               cmp $a0                      
                               bne !RIGHTSIDE+              
                               txa                          
                               sta (map2_zpw),y               
!RIGHTSIDE:                    ldy #$01                     
                               inc $a0                      
                               lda (map2_zpw),y               
                               cmp $a0                      
                               bne !EXIT+                   
                               txa                          
                               sta (map2_zpw),y               
!EXIT:                         rts                          
                                                         
// Routine to plot enemies in map space checking tiles to see if OK to plot enemy                           
// on top (e.g. won't plot inside walls etc)                           
// Tile space X-coordinate passed in via A, Y-coordinate via X, and enemy type                           
// passed in via Y                                       
PLOT_ENEMY_TO_MAP:             clc                          // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               adc YtoMapLsbTbl,x           
                               sta map2_zpw                   
                               lda YtoMapMsbTbl,x           
                               sta map2_zpw+1
                                                
                               lda EnemySubstrateTbl1,y       
                               sta $a0                      
                               ldx EnemyTilesTbl_3,y
                                       
                               ldy #$00                     
                               lda (map2_zpw),y               
                               cmp $a0                      
                               bne !LEFTSIDE+               
                               txa                          
                               sta (map2_zpw),y               
!LEFTSIDE:                     ldy #$01                     
                               lda (map2_zpw),y               
                               cmp $a0                      
                               bne !EXIT+                   
                               inx                          
                               txa                          
                               sta (map2_zpw),y               
!EXIT:                         rts                          
                                                         
// Inits local variables for enemy, checking to see if there is at least one                           
// horizontal space free to move into (on right)                           
// Return with 1 in $a0 if successful, otherwise return 0 if failed.                           
!xCoordinate:                  .byte $49                      
!yCoordinate:                  .byte $33                      
!substrate:                    .byte $00                      
INIT_ENEMY_VARS:               //jmp !START+                  
                                                         
!START:                        jsr UPDATE_ENEMY_VARS	// parameters passed in next three bytes:        
                               .byte <!xCoordinate-	//$7a                   //lsb pointer to coordinates   (as X,Y)
                               .byte >!xCoordinate-	//$27                   //msb pointer to coordinates  
                               .byte $02                   			//selector for what kind of update to perform   
                               clc                          
                               ldx !yCoordinate-            
                               lda YtoMapLsbTbl,x           
                               adc !xCoordinate-            
                               sta map2_zpw
                                                  
                               //ldx !yCoordinate-            
                               lda YtoMapMsbTbl,x           // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               sta map2_zpw+1
                                                
                               ldx !substrate-              
                               lda EnemySubstrateTbl3,x     
                               sta tempSubstrate1
                                          
                               //ldx !substrate-              
                               lda EnemySubstrateTbl2,x      
                               sta tempSubstrate2
                                          
                               ldy #$00                     
                               lda (map2_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL+              
                               lda tempSubstrate1           
                               cmp tempSubstrate3           
                               bcc !EXIT_FAIL+              
                               jmp !CONTINUE+               
                                                         
!EXIT_FAIL:                    lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!CONTINUE:                     inc map2_zpw                   
                               bne !GET+                    
                               inc map2_zpw+1                 
!GET:                          ldy #$00                     
                               lda (map2_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL1+             
                               lda tempSubstrate1           
                               cmp tempSubstrate3           
                               bcc !EXIT_FAIL1+             
                               jmp !EXIT_SUCCESS+           
                                                         
!EXIT_FAIL1:                   lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!EXIT_SUCCESS:                 lda #$01                     
                               sta $a0                      
                               rts                          
                                                         
// Check if tile immediately to left of map2 pointer is OK to move into                           
// Return with 1 in $a0 if yes/successful, otherwise return 0 if not/failed.                           
CHK_TILE_LEFT:                 //jmp !START+                  
                                                         
!START:                        sec                          
                               lda map2_zpw                   
                               sbc #$01                     
                               sta map3_zpw                   
                               lda map2_zpw+1                 
                               sbc #$00                     
                               sta map3_zpw+1
                                                
                               ldy #$00                     
                               lda (map3_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL+              
                               lda tempSubstrate1           
                               cmp tempSubstrate3           // future opt
                               bcc !EXIT_FAIL+              
                               jmp !EXIT_SUCCESS+           
                                                         
!EXIT_FAIL:                    lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!EXIT_SUCCESS:                 lda #$01                     
                               sta $a0                      
                               rts                          
                                                         
// Check if tile immediately to right of map2 pointer is OK to move into                           
// Return with 1 in $a0 if yes/successful, otherwise return 0 if not/failed.                           
CHK_TILE_RIGHT:                //jmp !START+                  
                                                         
!START:                        clc                          
                               lda map2_zpw                   
                               adc #$02                     
                               sta map3_zpw                   
                               lda map2_zpw+1                 
                               adc #$00                     
                               sta map3_zpw+1
                                                
                               ldy #$00                     
                               lda (map3_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               eor #$2b                     
                               beq !PLAY_CHIRP+             
                               jmp !SKIP+                   
                                                         
!PLAY_CHIRP:                   
			       lda soundPlaying2_zp	// don't pre-empt a more important sound with bat chirp -RJR add
			       bne !SKIP+
			       
			       lda #$16                     
                               sta SoundStateHi_zp
                                           
!SKIP:                         lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL+              
                               lda tempSubstrate1           
                               cmp tempSubstrate3      // future opt     
                               bcc !EXIT_FAIL+              
                               jmp !EXIT_SUCCESS+           
                                                         
!EXIT_FAIL:                    lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!EXIT_SUCCESS:                 lda #$01                     
                               sta $a0                      
                               rts                          
                                                         
// Check if 2 tiles immediately above map2 pointer are OK to move into                           
// Return with 1 in $a0 if yes/successful, otherwise return 0 if not/failed.                           
CHK_2_TILES_ABOVE:             //jmp !START+                  
                                                         
!START:                        sec                          
                               lda map2_zpw                   
                               sbc #$80                     
                               sta map3_zpw                   
                               lda map2_zpw+1                 
                               sbc #$00                     
                               sta map3_zpw+1
                                                
                               ldy #$00                     
                               lda (map3_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL1+             
                               lda tempSubstrate1           
                               cmp tempSubstrate3           // future opt
                               bcc !EXIT_FAIL1+             
                               jmp !CONTINUE+               
                                                         
!EXIT_FAIL1:                   lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!CONTINUE:                     inc map3_zpw                   
                               bne !NO_MSB+                 
                               inc map3_zpw+1                 
!NO_MSB:                       ldy #$00                     
                               lda (map3_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL2+             
                               lda tempSubstrate1           
                               cmp tempSubstrate3      // future opt    
                               bcc !EXIT_FAIL2+             
                               jmp !EXIT_SUCCESS+           
                                                         
!EXIT_FAIL2:                   lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!EXIT_SUCCESS:                 lda #$01                     
                               sta $a0                      
                               rts                          
                                                         
// Check if two tiles immediately below map2 pointer are OK to move into                           
// Return with 1 in $a0 if yes/successful, otherwise return 0 if not/failed.                           
CHK_2_TILES_BELOW:             //jmp !START+                  
                                                         
!START:                        clc                          
                               lda map2_zpw                   
                               adc #$80                     
                               sta map3_zpw                   
                               lda map2_zpw+1                 
                               adc #$00                     
                               sta map3_zpw+1                 
                               ldy #$00                     
                               lda (map3_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL1+             
                               lda tempSubstrate1           
                               cmp tempSubstrate3     // future opt      
                               bcc !EXIT_FAIL1+             
                               jmp !CONTINUE+               
                                                         
!EXIT_FAIL1:                   lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!CONTINUE:                     inc map3_zpw                   
                               bne !NO_MSB+                 
                               inc map3_zpw+1                 
!NO_MSB:                       ldy #$00                     
                               lda (map3_zpw),y               
                               sta tempSubstrate3           
                               //lda tempSubstrate3           
                               cmp tempSubstrate2           
                               bcc !EXIT_FAIL2+             
                               lda tempSubstrate1           
                               cmp tempSubstrate3        // future opt   
                               bcc !EXIT_FAIL2+             
                               jmp !EXIT_SUCCESS+           
                                                         
!EXIT_FAIL2:                   lda #$00                     
                               sta $a0                      
                               rts                          
                                                         
!EXIT_SUCCESS:                 lda #$01                     
                               sta $a0                      
                               rts                          
                                                         
// Check for tiles at map2 pointer and pointer+1 of type $22 (sparkly explosion                           
// caused by player weapon).  If type $22, clear it/them.  If not exit with fail.                           
CLEAR_WEAPON_HIT_TILE:         ldy #$00                     
                               sty $a0                      
                               ldx #$01                     
                               lda (map2_zpw),y               
                               cmp #$22                     
                               bne !CONTINUE+               
                               tya                          
                               sta (map2_zpw),y               
                               stx $a0
                                                     
!CONTINUE:                     iny                          
                               lda (map2_zpw),y               
                               cmp #$22                     
                               bne !EXIT+
                                                  
                               lda #$00                     
                               sta (map2_zpw),y               
                               stx $a0
                                                     
!EXIT:                         lda $a0                      
                               sta $a0                      
                               rts                          
                                                         
// Manages motion of an enemy or destruction of an enemy via FSM transitions. On                           
// entry $e0 contains index to "which enemy"                           
!xCoordinate:                  .byte $2a                      
!yCoordinate:                  .byte $13                      
!substrate:                    .byte $00                      
MANAGE_ENEMY_MOTION:           //jmp !START+                  
                                                         
!START:                        ldx EnemyIndex_zp               
                               lda EnemyXarray,x            
                               sta !xCoordinate-            
                               //ldx EnemyIndex_zp               
                               lda EnemyYarray,x            
                               sta !yCoordinate-            
                               //ldx EnemyIndex_zp               
                               lda EnemySubstrateIndexTbl,x	// I created some confusion here when naming labels. EnemySubstrateTbl1,2,3 are used locally by this routine. The game also uses this table
                               sta !substrate-              	// lda L93C0,x   ;index into table for substrate type indices (table of 10 zeros followed by 10 ones followed by 25 $ffs) in original code
                               //ldx EnemyIndex_zp               
                               lda EnemyStateRegArray,x     
                               sta InitIndex_zp
                                                     
                               ldx !substrate-              
                               lda EnemySubstrateTbl3,x     
                               sta tempSubstrate1           
                               //ldx !substrate-              
                               lda EnemySubstrateTbl2,x      
                               sta tempSubstrate2
                                          
                               clc                          
                               ldx !yCoordinate-            
                               lda YtoMapLsbTbl,x           
                               adc !xCoordinate-            
                               sta map2_zpw                   
                               //ldx !yCoordinate-            
                               lda YtoMapMsbTbl,x           // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               sta map2_zpw+1                 
                               jsr CLEAR_WEAPON_HIT_TILE    
                               lda $a0                      
                               bne !ERASE_HIT+              
                               jmp !NOT_HIT+                
                                                         
!ERASE_HIT:                    lda !substrate-              
                               jsr ERASE_ENEMY              
                               lda #$00                     
                               ldx EnemyIndex_zp               
                               sta EnemyXarray,x            
                               rts                          //internal
                                                         
!NOT_HIT:                      lda InitIndex_zp                      
                               beq !CHECK_SPACE+            
                               jmp !NEXT_STATE_1+           
                                                         
!CHECK_SPACE:                  jsr CHK_2_TILES_ABOVE		     
                               lda $a0                      
                               bne !MOVE_UP+                
                               jmp !SET_STATE_2+            
                                                         
!MOVE_UP:                      lda !substrate-              
                               jsr ERASE_ENEMY              
                               sec                          
                               lda !yCoordinate-            
                               sbc #$01                     
                               sta !yCoordinate-            
                               ldy !substrate-              
                               //ldx !yCoordinate-
			       tax            
                               lda !xCoordinate-            
                               jsr PLOT_ENEMY_TO_MAP        
                               jmp !NEXT_STATE+             
                                                         
!SET_STATE_2:                  lda #$02                     
                               sta InitIndex_zp                      
!NEXT_STATE:                   jmp !CHOOSE_UPDATE+          
                                                         
!NEXT_STATE_1:                 lda InitIndex_zp                      
                               eor #$01                     
                               beq !LOOK_BELOW+             
                               jmp !NEXT_STATE_2+           
                                                         
!LOOK_BELOW:                   jsr CHK_2_TILES_BELOW        
                               lda $a0                      
                               bne !MOVE_DOWN+              
                               jmp !SET_STATE_3+            
                                                         
!MOVE_DOWN:                    lda !substrate-              
                               jsr ERASE_ENEMY              
                               inc !yCoordinate-            
                               ldy !substrate-              
                               ldx !yCoordinate-            
                               lda !xCoordinate-            
                               jsr PLOT_ENEMY_TO_MAP        
                               jmp !FINISH_EARLY+           
                                                         
!SET_STATE_3:                  lda #$03                     
                               sta InitIndex_zp                      
!FINISH_EARLY:                 jmp !CHOOSE_UPDATE+          
                                                         
!NEXT_STATE_2:                 lda InitIndex_zp                      
                               eor #$02                     
                               beq !LOOK_LEFT+              
                               jmp !NEXT_STATE_3+           
                                                         
!LOOK_LEFT:                    jsr CHK_TILE_LEFT            
                               lda $a0                      
                               bne !MOVE_LEFT+              
                               jmp !SET_STATE_1+            
                                                         
!MOVE_LEFT:                    lda !substrate-              
                               jsr ERASE_ENEMY              
                               sec                          
                               lda !xCoordinate-            
                               sbc #$01                     
                               sta !xCoordinate-            
                               ldy !substrate-              
                               ldx !yCoordinate-            
                               //lda !xCoordinate-            
                               jsr PLOT_ENEMY_TO_MAP        
                               jmp !SKIP+                   
                                                         
!SET_STATE_1:                  ldy #$01                     
                               sty InitIndex_zp                      
!SKIP:                         jmp !CHOOSE_UPDATE+          
                                                         
!NEXT_STATE_3:                 lda InitIndex_zp                      
                               eor #$03                     
                               beq !LOOK_RIGHT+             
                               jmp !CHOOSE_UPDATE+          
                                                         
!LOOK_RIGHT:                   jsr CHK_TILE_RIGHT           
                               lda $a0                      
                               bne !MOVE_RIGHT+             
                               jmp !SET_STATE_0+            
                                                         
!MOVE_RIGHT:                   lda !substrate-              
                               jsr ERASE_ENEMY              
                               inc !xCoordinate-            
                               ldy !substrate-              
                               ldx !yCoordinate-            
                               lda !xCoordinate-            
                               jsr PLOT_ENEMY_TO_MAP        
                               jmp !CHOOSE_UPDATE+          
                                                         
!SET_STATE_0:                  ldy #$00                     
                               sty InitIndex_zp
                                                     
!CHOOSE_UPDATE:                //jsr GenRandom
			       lda #$dc                     
                               cmp SID_RANDOM                   
                               bcc !NEW_RANDOM_STATE+       
                               jmp !UPDATE_ARRAYS+          
                                                         
!NEW_RANDOM_STATE:             //jsr GenRandom
                               lda SID_RANDOM                   
                               and #$03                     
                               sta InitIndex_zp                      
!UPDATE_ARRAYS:                lda InitIndex_zp                      
                               ldx EnemyIndex_zp               
                               sta EnemyStateRegArray,x     
                               lda !xCoordinate-            
                               //ldx EnemyIndex_zp               
                               sta EnemyXarray,x            
                               lda !yCoordinate-            
                               //ldx EnemyIndex_zp               
                               sta EnemyYarray,x            
                               rts                          
                                                      
                                                      
                                                         
// Initializes an enemy into map space and sets up its FSM. On entry $e0 is the                           
// index number of enemy to initialize/create.                           
// $a0 contains return code                              
!xCoordinate_temp:             .byte $49                      
!yCoordinate_temp:             .byte $33                      
!tempSubstrate:                .byte $00                      
INIT_ENEMY:                    //jmp !START+                  
                                                         
!START:                        ldx #$78                     
                               lda #$7f                     
                               jsr GET_RAND_LESS_THAN_X           
                               lda $a0                      
                               sta !xCoordinate_temp-       
                               ldx EnemyIndex_zp               
                               lda EnemySubstrateIndexTbl,x      
                               sta !tempSubstrate-          
                               ldx #$3c                     
                               lda #$3f                     
                               jsr GET_RAND_LESS_THAN_X           
                               lda $a0                      
                               sta !yCoordinate_temp-       
                               ldy !tempSubstrate-          
                               ldx !yCoordinate_temp-       
                               lda !xCoordinate_temp-       
                               jsr INIT_ENEMY_VARS          
                               lda $a0                      
                               bne !SAVE_AND_PLOT+          
                               rts			//internal jmp !EXIT+                   
                                                         
!SAVE_AND_PLOT:                lda !xCoordinate_temp-       
                               ldx EnemyIndex_zp               
                               sta EnemyXarray,x            
                               lda !yCoordinate_temp-       
                               //ldx EnemyIndex_zp               
                               sta EnemyYarray,x
                               
                               //jsr GenRandom    	// +++ my GenRandom only trashes A, X is preserved        
                               lda SID_RANDOM                                                 
                               and #$03                     
                               //ldx EnemyIndex_zp               
                               sta EnemyStateRegArray,x
                                    
                               ldy !tempSubstrate-          
                               ldx !yCoordinate_temp-       
                               lda !xCoordinate_temp-       
                               jsr PLOT_ENEMY_TO_MAP    
                                   
!EXIT:                         rts                          
                                                         
// Initialize enemies by starting their state machines.                           
// Number of enemies of each type is configured in the table at $93c0                           
INIT_ALL_ENEMIES:              //jmp !START+                  
                                                         
!START:                        ldx EnemyIndex_zp               
                               lda EnemySubstrateIndexTbl,x      
                               cmp #$ff                     
                               bcc !CHECK_IF_DONE+          
                               jmp !NEXT_ENEMY+             
                                                         
!CHECK_IF_DONE:                ldx EnemyIndex_zp               
                               lda EnemyXarray,x            
                               beq !INIT+                   
                               jmp !MOVE+                   
                                                         
!INIT:                         jsr INIT_ENEMY               
                               jmp !NEXT_ENEMY+             
                                                         
!MOVE:                         jsr MANAGE_ENEMY_MOTION      
!NEXT_ENEMY:                   inc EnemyIndex_zp               
                               lda #$2c                     
                               cmp EnemyIndex_zp               
                               bcc !DONE+                   
                               rts			//internal jmp !EXIT+                   
                                                         
!DONE:                         ldy #$00                     
                               sty EnemyIndex_zp               
!EXIT:                         rts                          
                                                
                                                
                                                         
// Check for joystick input to thow a weapon and initialize the popagating                           
// projectile if needed                                  
WEAPON:                        //jmp !START+                  
                                                         
!START:                        lda #$00                     
                               ldx PlayerNum                
                               cmp PlayerDelayCountdown,x   
                               bcc !EXIT1+                  
                               jmp !CHECK_LIFE+             
                                                         
!EXIT1:                        rts                          
                                                         
!CHECK_LIFE:                   //ldx PlayerNum                
                               lda PlayerLifeForce,x              
                               beq !CHECK_ZOMBIE+           
                               jmp !JOY_DIRECTION+          
                                                         
!CHECK_ZOMBIE:                 //ldx PlayerNum                
                               lda PlayerControlMode,x      
                               eor #$02                     
                               bne !EXIT2+                  
                               jmp !JOY_DIRECTION+          
                                                         
!EXIT2:                        rts                          
                                                         
!JOY_DIRECTION:                //ldx PlayerNum                
                               lda PlayerJoystickBits,x           
                               and #$0c                   // =%1100 filter out right/left bits  
                               sta $fd                  
                               //ldx PlayerNum                
                               lda WeaponState,x            
                               eor #$01                     
                               beq !JOY_TRIGGER+            
                               rts			//internal jmp !EXIT3+                  
                                                         
!JOY_TRIGGER:                  //ldx PlayerNum                
                               lda PlayerJoyTrigger,x        
                               beq !GET_THROW_DIRECTION+    
                               rts			//internal jmp !EXIT3+                  
                                                         
!GET_THROW_DIRECTION:          lda $fd                  
                               eor #$0c                     
                               bne !CHECK_MAP+              
                               rts			//internal jmp !EXIT3+                  
                                                         
!CHECK_MAP:                    //ldx PlayerNum                
                               lda PlayerTileXcoordinate,x      
                               sta InitIndex_zp                      
                               //ldx PlayerNum                
                               lda PlayerTileYcoordinate,x
                               sta $fe
                                                                                 
                               clc                          
                               //ldx $fe 
			       tax                     // instead
                               lda YtoMapLsbTbl,x           // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               adc InitIndex_zp                      
                               sta map2_zpw                   
                               ldx $fe                      
                               lda YtoMapMsbTbl,x           
                               sta map2_zpw+1                 
                               ldy #$00                     
                               lda (map2_zpw),y               
                               beq !LAUNCH_WEAPON+          
                               rts			//internal jmp !EXIT3+                  
                                                         
!LAUNCH_WEAPON:                lda InitIndex_zp                      
                               ldx WeaponIdx                
                               sta WeaponXtbl,x             
                               lda $fe                      
                               //ldx WeaponIdx                
                               sta WeaponYtbl,x             
                               lda #$0f                     
                               //ldx WeaponIdx                
                               sta WeaponPropCtrTbl,x       
                               lda #$03                     
                               ora $fd                  // $fd=right, left bits of joystick
                               //ldx WeaponIdx                
                               sta WeaponDirectionTbl,x 
                                   
                               lda #$00                     
                               ldx PlayerNum                
                               sta WeaponState,x            
                               lda SoundStateLo_zp       
                               ora #$20                     
                               sta SoundStateLo_zp
                                      
!EXIT3:                        rts                          
                                                         
// Propagate weapon in flight and transform it into a damage burst if it hits an                           
// enemy                                                 
!weaponYcoordinate:            .byte $28                      
!tileUnderWeapon:              .byte $50                      
!delta_X:                      .byte $ff                      
!delta_X_map:                  .byte $ff                      
!delta_Y:                      .byte $ff                      
!delta_Y_map:                  .byte $ff                      
                                                         
PROPAGATE_WEAPON:              //jmp !START+                  
                                                         
!START:                        ldx WeaponIdx                
                               lda WeaponYtbl,x             
                               sta !weaponYcoordinate-                                   
                               clc                          
                               ldx !weaponYcoordinate-      
                               lda YtoMapLsbTbl,x           // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               ldx WeaponIdx                
                               adc WeaponXtbl,x             
                               sta map2_zpw                   
                               ldx !weaponYcoordinate-      
                               lda YtoMapMsbTbl,x           
                               sta map2_zpw+1                     
                               ldx WeaponIdx                
                               lda WeaponDirectionTbl,x     // future opt (move earlier to avoid ldx?)
                               and #$02                     
                               sta $be                  
                               //lda $be                   
                               beq !MOVE_DOWN+              
                               jmp !MOVE_UP+                
                                                         
// Propagation code here is confusing, because just here below the map pointers                           
// are updated to the next location for the weapon but the X,Y coordinates are                           
// not.  The byte X,Y coordinates are updated only at the very end of this                           
// subroutine. This allows the routine to "look ahead" on the map to see if the                           
// weapon will hit something and handle that case, but it is sort of convoluted                           
// code.                                                 
!MOVE_DOWN:                    ldy #$00                     
                               sty !delta_Y_map-            
                               iny                          
                               sty !delta_Y-                
                               clc                          
                               lda map2_zpw                   
                               adc #$80                     
                               sta map3_zpw                   
                               lda map2_zpw+1                      
                               adc #$00                     
                               sta map3_zpw+1                     
                               jmp !DONE+                   
                                                         
!MOVE_UP:                      lda #$ff                     
                               sta !delta_Y_map-            
                               lda #$ff                     
                               sta !delta_Y-                
                               sec                          
                               lda map2_zpw                   
                               sbc #$80                     
                               sta map3_zpw                   
                               lda map2_zpw+1                     
                               sbc #$00                     
                               sta map3_zpw+1
!DONE:                         ldx WeaponIdx                
                               lda WeaponDirectionTbl,x     
                               and #$08                     
                               sta $be                  
                               //lda $be                 
                               beq !SETUP_RIGHT+            
                               jmp !SETUP_LEFT+             
                                                         
!SETUP_RIGHT:                  ldy #$00                     
                               sty !delta_X_map-            
                               iny                          
                               sty !delta_X-                
                               jmp !CHECK_MAP+              
                                                         
!SETUP_LEFT:                   lda #$ff                     
                               sta !delta_X_map-            
                               lda #$ff                     
                               sta !delta_X-
                                               
!CHECK_MAP:                    clc                          
                               lda map3_zpw                   
                               adc !delta_X-                
                               sta map3_zpw                   
                               lda map3_zpw+1                 
                               adc !delta_X_map-            
                               sta map3_zpw+1
                                                
                               ldy #$00                     
                               lda (map3_zpw),y               
                               sta !tileUnderWeapon-        
                               lda EnemyTilesTbl_3          //left half of enemy
                               sta $a1
                               tax		//+++                      
                               clc                          
                               lda EnemyTilesTbl_3+1        //right half of enemy
                               adc #$01                     
                               sta $a2                      
                               //ldy $a2
			       tay		//+++                      
                               //ldx $a1          //+++ see above            
                               lda !tileUnderWeapon-        
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0 
			       A_BETWEEN_XY()                     
                               bne !BURST_WEAPON+           
                               jmp !NO_ENEMY_HIT+           
                                                         
!BURST_WEAPON:                 lda #$22                     
                               ldy #$00                     
                               sta (map3_zpw),y               
                               lda !tileUnderWeapon-        
                               eor EnemyTilesTbl_3          
                               beq !MAP_PTR_RIGHT+
                                         
                               lda !tileUnderWeapon-        
                               eor EnemyTilesTbl_3+1        
                               beq !MAP_PTR_RIGHT+          
                               jmp !MAP_PTR_LEFT+           
                                                         
!MAP_PTR_RIGHT:                inc map3_zpw                   
                               bne !SKIP+                   
                               inc map3_zpw+1                     
!SKIP:                         jmp !CHECK_FOR_HIT+          
                                                         
!MAP_PTR_LEFT:                 sec                          
                               lda map3_zpw                   
                               sbc #$01                     
                               sta map3_zpw                   
                               lda map3_zpw+1                      
                               sbc #$00                     
                               sta map3_zpw+1                      
!CHECK_FOR_HIT:                ldy #$00                     
                               lda (map3_zpw),y               
                               sta $a0                      
                               lda EnemyTilesTbl_3          
                               sta $a1
                               tax                      
                               clc                          
                               lda EnemyTilesTbl_3+1        
                               adc #$01                     
                               sta $a2                      
                               //ldy $a2 
                               tay		//+++                     
                               //ldx $a1        // above              
                               lda $a0                      
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0 
			       A_BETWEEN_XY()                     // ************debug here for problem
                               bne !PLOT_BURST+             
                               jmp !CLEAR_TILE+             
                                                         
!PLOT_BURST:                   lda #$22                     
                               ldy #$00                     
                               sta (map3_zpw),y               
!CLEAR_TILE:                   lda #$00                     
                               ldy #$00                     
                               sta (map2_zpw),y               
                               lda #$00                     
                               ldx WeaponIdx                
                               sta WeaponDirectionTbl,x     
                               lda #$0a                     
                               sta SoundStateHi_zp            
                               rts			//internal jmp !EXIT+                   
                                                         
!NO_ENEMY_HIT:                 ldy #$00                     
                               lda (map3_zpw),y               
                               bne !BOUNCE_OFF_WALL+        
                               jmp !WEAPON_FLYING+          
                                                         
!BOUNCE_OFF_WALL:              ldx WeaponIdx                
                               lda WeaponDirectionTbl,x     
                               eor #$02                     
                               //ldx WeaponIdx                
                               sta WeaponDirectionTbl,x     
                               sec                          
                               //ldx WeaponIdx                
                               lda WeaponPropCtrTbl,x       
                               sbc #$01                     
                               //ldx WeaponIdx                
                               sta WeaponPropCtrTbl,x       
                               //ldx WeaponIdx                
                               //lda WeaponPropCtrTbl,x       
                               beq !WEAPON_DEAD+            
                               rts			//internal jmp !TO_EXIT+                
                                                         
!WEAPON_DEAD:                  lda #$00                     
                               //ldx WeaponIdx                
                               sta WeaponDirectionTbl,x     
                               lda #$00                     
                               sta (map2_zpw),y               
!TO_EXIT:                      rts			//internal jmp !EXIT+                   
                                                         
!WEAPON_FLYING:                clc                          
                               ldx WeaponIdx        // need this        
                               lda WeaponYtbl,x             
                               adc !delta_Y-                
                               //ldx WeaponIdx                
                               sta WeaponYtbl,x             
                               clc                          
                               //ldx WeaponIdx                
                               lda WeaponXtbl,x             
                               adc !delta_X-                
                               //ldx WeaponIdx                
                               sta WeaponXtbl,x             
                               lda #$00                     
                               ldy #$00                     
                               sta (map2_zpw),y               
                               ldx PlayerNum                
                               lda WeaponTileTbl,x          
                               sta (map3_zpw),y  
                                            
!EXIT:                         rts                          
                                                         
// Routine which runs weapon state machines                           
RUN_WEAPON_FSMS:               //jmp !START+                  
                                                         
!START:                        ldx PlayerNum                
                               lda PlayerJoyTrigger,x        
                               bne !STATE_1+                
                               jmp !TRIGGER_PRESSED+        
                                                         
!STATE_1:                      lda #$01                     
                               //ldx PlayerNum                
                               sta WeaponState,x            
!TRIGGER_PRESSED:              //lda PlayerNum
			       txa			// +++                
                               eor #$01                     
                               beq !GET_PLYR_1_SLOT+        
                               jmp !GET_PLYR_2_SLOT+        
                                                         
!GET_PLYR_1_SLOT:              clc                          
                               lda WeaponGroupNum           
                               adc #$02                     
                               sta WeaponIdx                
                               jmp !GET_INPUTS+             
                                                         
!GET_PLYR_2_SLOT:              lda WeaponGroupNum           
                               sta WeaponIdx                
!GET_INPUTS:                   //ldx WeaponIdx
			       tax			//+++                
                               lda WeaponDirectionTbl,x     // 2719,x
                               and #$01                     
                               sta $be                  
                               //lda $be                
                               beq !CHECK_INPUT+            
                               jmp !THROW_WEAPON+           
                                                         
!CHECK_INPUT:                  jsr WEAPON                   
                               jmp !NEXT_PLAYER+            
                                                         
!THROW_WEAPON:                 jsr PROPAGATE_WEAPON    
     
!NEXT_PLAYER:                  inc PlayerNum                
                               lda #$01                     
                               cmp PlayerNum                
                               bcc !WRAP_UP+                
                               rts			//internal jmp !EXIT+                   
                                                         
!WRAP_UP:                      ldy #$00                     
                               sty PlayerNum                
                               inc WeaponGroupNum           
                               lda WeaponGroupNum           
                               cmp #$02                      
                               bcs !ALL_WEAPONS_CHCKD+      
                               rts			//internal jmp !EXIT+                   
                                                         
!ALL_WEAPONS_CHCKD:            sty WeaponGroupNum
           
!EXIT:                         rts                          
     
     
     
                                                         
// Run enemy and weapon state machines handling creation destruction and movement                           
CREATE_DESTROY_ENEMIES_WEAPONS: jmp !START+                  
                                                         
!START:                        jsr INIT_ALL_ENEMIES         
                               jsr RUN_WEAPON_FSMS
                               // check if in magic phase          
			       lda LightningDelayCounter
			       ora LightningDelayCounter+1
			       bne !n+
			       jsr RUN_WEAPON_FSMS		// this gets slow during magic phase so run twice
!n:                            rts                          



                                                         
// Sets up a number of enemy slots in $93c0 and initializes their X-coordiantes                           
// to zero (which other routines interpret as "inactive")                           
// Parameters A = number of enemies, X=enemy type selector (0,1,$ff), $e0 first                           
// enemy slot                                            
// Example, A=10, $e0=$13 (d19), X=1 will set enemy slots 19 through 28 as type 1                           
// = small ghost                                         
!numEnemies:                   .byte $00                      
!enemyType:                    .byte $02                      
                                                         
SETUP_ENEMY_SLOTS:             //jmp !START+                  
                                                         
!START:                        stx !enemyType-              
                               sta !numEnemies-             
!LOOP:                         lda #$00                     
                               cmp !numEnemies-             
                               bcc !READY_ENEMY+            
                               rts			//internal jmp !EXIT+                   
                                                         
!READY_ENEMY:                  lda !enemyType-              
                               ldx EnemyIndex_zp               
                               sta EnemySubstrateIndexTbl,x      
                               lda #$00                     
                               ldx EnemyIndex_zp               
                               sta EnemyXarray,x            
                               sec                          
                               lda !numEnemies-             
                               sbc #$01                     
                               sta !numEnemies-             
                               inc EnemyIndex_zp               
                               jmp !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!EXIT:                         rts                          
                
                
                
                                                         
// Initializes the enemy and weapon tables and enemy and weapon state registers.                            
// Configuration of enemies is done on a per-level basis using a table below.                           
// Accumulator on entry holds the number of the level to configure 0-3                           
gameLevel:                     .byte $00
                      
numType0tbl:                   .byte $0a                     
                               .byte $0b                      
                               .byte $14                      
                               .byte $0f                      
                               .byte $0c
                                                     
numType1tbl:                   .byte $0a                    
                               .byte $0e                      
                               .byte $0a                      
                               .byte $12                      
                               .byte $17
                                                     
numType2tbl:                   .byte $00                      
                               .byte $00                      
                               .byte $05                      
                               .byte $07                      
                               .byte $0a
                               
// Set up enemies, takes argument A=game level number                                                     
ENEMIES_FOR_LEVEL:             //jmp !START+                  
                                                         
!START:                        sta gameLevel                
                               ldy #$00                     
                               sty InitIndex_zp                      
!LOOP:                         lda #$2c                     
                               cmp InitIndex_zp                      
                               bcs !CLEAR_ENEMIES_TBL+      
                               jmp !INIT_GROUPS+            
                                                         
!CLEAR_ENEMIES_TBL:            lda #$ff                     
                               ldx InitIndex_zp                      
                               sta EnemySubstrateIndexTbl,x      
                               inc InitIndex_zp                      
                               jmp !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!INIT_GROUPS:                  ldy #$00                     
                               sty EnemyIndex_zp               
                               ldx gameLevel                
                               lda numType0tbl,x            
                               sta $a0                      
                               ldx #$00                     
                               lda $a0                      
                               jsr SETUP_ENEMY_SLOTS        
                               ldx gameLevel                
                               lda numType1tbl,x            
                               sta $a0                      
                               ldx #$01                     
                               lda $a0                      
                               jsr SETUP_ENEMY_SLOTS        
                               ldx gameLevel                
                               lda numType2tbl,x            
                               sta $a0                      
                               ldx #$02                     
                               lda $a0                      
                               jsr SETUP_ENEMY_SLOTS
                                       
                               lda #$00                  // since this has no effect on anything, could remove to save 
                               cmp gameLevel             // a bunch of cycles--but it runs only during level setup so 
                               bcc !NULL_BRANCH+         // no benefit to gameplay speed.   
                               jmp !CLEAR_COUNTER+          
                                                         
!NULL_BRANCH:                  lda L0609                 // only on very first level; L0609 does not appear explicitly in any of the atari code   
                               eor #$01                     
                               beq !CLEAR_COUNTER+      // does not do anything in this from the [a2] homesoft version!    
                               jmp !CLEAR_COUNTER+      // it looks like this was part of some crappy copy protection by investigating the
							// [a1] crack which doesn't work well. L0609 is set by the Axis/Ariola loader and
							// and if not, the game will corrupt itself and crash   
                                                         
!CLEAR_COUNTER:                ldy #$00                     
                               sty InitIndex_zp                      
!CHECK_DONE_LOOP:              lda #$03                     
                               cmp InitIndex_zp                      
                               bcs !CLEAR_WEAPON+           
                               jmp !DONE+                   
                                                         
!CLEAR_WEAPON:                 lda #$00                     
                               ldx InitIndex_zp                      
                               sta WeaponDirectionTbl,x     
                               inc InitIndex_zp                      
                               jmp !CHECK_DONE_LOOP-        //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!DONE:                         ldy #$00                     
                               sty EnemyIndex_zp               
                               sty WeaponGroupNum           
                               sty PlayerNum                
                               rts                          
                                                         
                               rts                          

/*			//bunch of nothing???                                                         
                               .byte $27                      
                               .byte $60                      
                               .byte $60                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00    
*/                               
                                                 
// This jump table appears to be static, I did not see it modified on a complete                           
// playthrough of level 0 nor on partial plays of all of the remaining levels to                           
// the game won screen                                   
JUMP_5:                        jmp MAIN_HANDLER_1        
                                                         
JUMP_6:                        jmp POPULATE_MAP             
                                                         
JUMP_7:                        jmp LEVELS134                
                                                         
LevelEndFlag:                  .byte $00                      
HasDiamond:                    .byte $01        // 00=has a diamond             
NumberOfTasksObjectsOnMap:     .byte $08        // on levels 1,3,4 only 4 objects (e.g. diamonds) are on the map at any time even if 6 or 8 are needed to complete           
TrapState:                     .byte $00                      
TrapAnimationCounter:          .byte $00                      
enemyInventory:                .byte $00                      
XcoordinateDivBy4:             .byte $0f                      
SBsearchColorFlag:             .byte $00                      
LifeForceDecDelay:             .byte $2f	//was $2f                      
SoundEffectQueue:              .byte $ff                      
NumberOfTasksRemaining:         .byte $08	//this is the number of tasks for the level

                      		// the following table of vectors is used to configure JUMP_2 and JUMP_3.  JUMP_1 is configured separately, and JUMP_4 is used as a constant to configure JUMP_1
JumpConfigTable:               .byte <HANDLE_TASKS_LVLS02 	//$eb                      // $32eb = handle_tasks_lvls 	LeVeLS 02 OR 134
                               .byte >HANDLE_TASKS_LVLS02	//$32                      
                               .byte <INTERACT_ENEMY_LVLS02	//$71                      // $3271 = interact_enemy_lvls	LeVeLS 02 OR 134
                               .byte >INTERACT_ENEMY_LVLS02	//$32
                                                     
LightningDelayCounter:         .byte $00                      
                               .byte $00
                                                     
PortalDelayCounter:            .byte $da                      
                               .byte $05
                                                     
LightningTable:                .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00
                                                     
ptrLightningTable:             .byte <LightningTable //$1c                // this should point backwards 10 bytes     
                               .byte >LightningTable //$2f 
                                                    
                               .byte <(unknownSMC+1)  //$2f              // in the original code, this points to the argument of an absolute lda inside GET_SAFE_2x2   
                               .byte >(unknownSMC+1)  //$eb		// but I have never seen it used even when going through and loading all levels in the original
                                                     
AnimationLocationPtr:          .byte $06                      
                               .byte $55
                                                     
TeleportalMapPtr:              .byte $6e                      
                               .byte $5b
                                                     
                               .byte $00                 // don't know     
                               .byte $23                      
                               .byte $27
                                                     
StatusBarTaskPtr:              .byte $02 //$1a           //offset from start of screen mem for status indicators           
                               .byte $ba //$5a
                    
PlayerInventory:               .byte $00        	// player 1     
                               .byte $00		// player 2
                                                     
functionalTileTable:           .byte $00                // unoccupied space                                     
                               .byte $31            	// "tool" object tiles (candle, stone, etc)         
                               .byte $30		// key object tile
                                                     
unlitLanternTbl:               .byte $44                      
                               .byte $b2                      
                               .byte $44                      
                               .byte $b2                      
                               .byte $b2                      
                               .byte $44
                                                     
litLanternTbl:                 .byte $c4                      
                               .byte $00                      
                               .byte $b6                      
                               .byte $00                      
                               .byte $c4
                                                     
NumberDiamonds:                .byte $00                      
                               .byte $00
                                                     
WeaponTile:                    .byte $21                      
                               .byte $20
                                                     
ZombieDelay:                   .byte $00                      
                               .byte $00
                                                     
PointsTbl:                     .byte $0a                      
                               .byte $14                      
                               .byte $1e                      
                               .byte $28                      
                               .byte $32                      
                                                         
                                                         
                                                         
// This jump table is dynamically modified according to which level is being                           
// played.                                               
// Level 1 and 3 are of the type where you use an object to activate other                           
// objects, and the jumps are                            
//                                                       
// 3bcf, 3271, 32eb, 3b64                                
// RTS, INTERACT_ENEMY_LVLS02, HANDLE_TASKS_LVLS02, END_MAGIC                           
//                                                       
// Level 2,4,5 are of the type where you just collect objects, and the jumps are                           
//                                                       
// 3aa0, 32a3, 3439, 3b64                                
// START_MAGIC, INTERACT_ENEMY_LVLS134, HANDLE_TASKS_LVLS134, END_MAGIC                           
//                                                       
// the intervening byte data seems unchanged

// The table of 2 words at ConfigJumpTable is used to configure JUMP_2 and JUMP_3 as appropriate for the current game level.
// JUMP_1 is configured separately to control the wizard/lightning mechanics, and JUMP_4 is used as a constant to configure JUMP_1
// when the wizard is captured and the magic end phase routine needs to be run.  When the magic phase state machine is finished
// JUMP_1 just points to the RTS at the END_MAGIC routine so it does nothing.
           
               
JUMP_1:                        jmp !EXIT_END_MAGIC+         	// this is just an RTS at the end of the END_MAGIC routine
                                                         
JUMP_2:                        jmp INTERACT_ENEMY_LVLS02 + 3	//+3 skipping the jmp !start+ header                  
                                                         
!unknown:                      .byte $4f                      	// data?
                                                         
JUMP_3:                        jmp HANDLE_TASKS_LVLS02 + 3    	//+3 skipping the jmp !start+ header              
                                                         
                               //.byte $8d                      // data or code?
                               //.byte $54                      
                               //.byte $2f                      
                               //.byte $60 

				sta !unknown-			// 2f58	sta $2f54  I have never seen this do anything when playing the first two levels
				rts
                                           
JUMP_4:                        jmp END_MAGIC + 3		//+3 skipping the jmp !start+ header      AFAIK this is never called directly. It is just a placeholder
								//storing the location of END_MAGIC that is copied from here into the JUMP_1 vector at the time that
								//the wizard is caught and the magic lightning phase should end           
                                                         
                               rts                          
                                  
                                  
                                                         
// Takes an (x,y) coordinate pair in ($fd, $fc) and checks to see if ok to store                           
// a 2x2 object there.  Returncode in $a1 and map pointer in MAP2 ($dc,e)                           
// Returns a possible location to use in the MAP2 pointer, and whether it is safe                           
// (0) in $a0 or not safe (!=0) to place an object there.                           
COORDINATE_TO_MAP_2X2:         ldx $fc                  
                               lda YtoMapMsbTbl,x           // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               sta map2_zpw+1                 
                               clc                          
                               ldx $fc                  
                               lda YtoMapLsbTbl,x           
                               adc $fd                  
                               sta map2_zpw                   
                               ldy #$01                     
                               sty $fe                      
                               dey                          
                               lda (map2_zpw),y               
                               sta $a0                      
                               ldy #$70                     
                               ldx #$66                     
                               lda $a0                      
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0
			       A_BETWEEN_XY()                      
                               eor #$01                     
                               beq !CHECK_ABOVE+            
                               jmp !EXIT+                   
                                                         
!CHECK_ABOVE:                  clc                          
                               lda map2_zpw                   
                               adc #$01                     
                               sta map3_zpw                   
                               lda map2_zpw+1                 
                               adc #$00                     
                               sta map3_zpw+1                 
                               ldy #$00                     
                               lda (map3_zpw),y               
                               sta $a0                      
                               ldy #$70                     
                               ldx #$66                     
                               lda $a0                      
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0 
			       A_BETWEEN_XY()                     
                               eor #$01                     
                               beq !SUCCESS+                
                               jmp !EXIT+                   
                                                         
!SUCCESS:                      sec                          
                               lda map3_zpw                   
                               sbc #$01                     
                               sta map3_zpw                   
                               lda map3_zpw+1                 
                               sbc #$01                     
                               sta map3_zpw+1                 
                               ldy #$00                     
                               lda (map3_zpw),y               
                               iny                          
                               ora (map3_zpw),y               
                               ldy #$80                     
                               ora (map3_zpw),y               
                               iny                          
                               ora (map3_zpw),y               
                               sta $fe
                                                     
!EXIT:                         lda $fe                      
                               sta $a0                      
                               rts                          
                                        
                                        
                                                         
// Generate and return a random safe location to store a 2x2 object as a pointer                           
// in $a0,$a1                                            
GET_SAFE_2X2:                  ldx #$3f-1-2                     //upper left tile position in c64 game is (4,9) at least on level 1
                               lda #$3f                     	//AND mask
                               jsr GET_RAND_LESS_THAN_X           
                               clc                          
                               lda $a0                      
                               adc #$04		//was 2                     
                               sta $fc  
                                               
                               ldx #$7f-1-9                     
                               lda #$7f                     
                               jsr GET_RAND_LESS_THAN_X           
                               clc                          
                               lda $a0                      
unknownSMC:                    adc #$09	//was 4  -- there is a pointer to this in one of the data blocks in the original code                   
                               sta $fd                  
                               jsr COORDINATE_TO_MAP_2X2    
                               lda $a0                      
                               beq !GOOD_SPOT+              
                               jmp GET_SAFE_2X2             
                                                         
!GOOD_SPOT:                    sec                          
                               lda map2_zpw                   
                               sbc #$80                     
                               sta $a0                      
                               lda map2_zpw+1                 
                               sbc #$00                     
                               sta $a1                      
                               rts                          
                            
                            
                                                         
// Routine to get coordinates to place a 2x2 object.  Tries 30 times to find                           
// something near (x,y)=(A,X), if fails finds a spot somewhere else in the map.                           
!xCoordinate:                  .byte $30                      
!yCoordinate:                  .byte $8e                      
!idx:                          .byte $03                      
                                                         
GET_TARGETED_2X2:              //jmp !START+                  
                                                         
!START:                        stx !yCoordinate-            
                               sta !xCoordinate-            
                               ldy #$00                     
                               sty !idx-                    
!X_LOOP:                       sec                          
                               lda !xCoordinate-            
                               sbc #$07                     
                               sta $be
                               //jsr GenRandom                  
                               lda SID_RANDOM                  
                               and #$0f                     
                               sta $bc                  
                               clc                          
                               lda $be                  
                               adc $bc                  
                               sta $fd                  
                               ldy #$7e                     
                               ldx #$04                     
                               lda $fd                  
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0
			       A_BETWEEN_XY()                      
                               bne !FIND_Y+                 
                               jmp !X_LOOP-                 //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!FIND_Y:                       sec                          
                               lda !yCoordinate-            
                               sbc #$03                     
                               sta $be
                               //jsr GenRandom                  
                               lda SID_RANDOM                  
                               and #$07                     
                               sta $bc                  
                               clc                          
                               lda $be                  
                               adc $bc                  
                               sta $fc                  
                               ldy #$3f                     
                               ldx #$02                     
                               lda $fc                  
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0 
			       A_BETWEEN_XY()                     
                               bne !CHECK_IF_SAFE+          
                               jmp !X_LOOP-                 //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!CHECK_IF_SAFE:                jsr COORDINATE_TO_MAP_2X2    
                               lda $a0                      
                               beq !SUCCESS_TARGETED+       
                               jmp !NO_LUCK+                
                                                         
!SUCCESS_TARGETED:             sec                          
                               lda map2_zpw                   
                               sbc #$80                     
                               sta map2_zpw                   
                               lda map2_zpw+1                 
                               sbc #$00                     
                               sta map2_zpw+1                 
                               jmp !EXIT+                   
                                                         
!NO_LUCK:                      inc !idx-                    
                               lda #$1e                     
                               cmp !idx-                    
                               bcc !GET_RANDOM_SPOT+        
                               jmp !TRY_AGAIN+              
                                                         
!GET_RANDOM_SPOT:              jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map2_zpw+1                 
                               lda $a0                      
                               sta map2_zpw                   
                               jmp !EXIT+                   
                                                         
!TRY_AGAIN:                    jmp !X_LOOP-                 //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!EXIT:                         lda map2_zpw+1                 
                               sta $a1                      
                               lda map2_zpw                   
                               sta $a0                      
                               rts                          
   
   
                                                         
// Stores a 2x2 object to map, where A=first of 4 tiles, X=map pointer lo, Y=map                           
// pointer high                                          
PLOT_2X2:                      stx $a0                      
                               sty $a1                      
                               clc                          
                               ldy #$00                     
                               sta ($a0),y                  
                               iny                          
                               adc #$01                     
                               sta ($a0),y                  
                               dec $a1                      
                               ldy #$80                     
                               adc #$01                     
                               sta ($a0),y                  
                               iny                          
                               adc #$01                     
                               sta ($a0),y                  
                               rts                          
 
 
                                                         
// Clears a 2x2 object from map, where A=map pointer lo, X=map pointer high                           
ERASE_2X2:                     sta $a0                      
                               stx $a1                      
                               ldy #$00                     
                               tya                          
                               sta ($a0),y                  
                               iny                          
                               sta ($a0),y                  
                               dec $a1                      
                               ldy #$80                     
                               sta ($a0),y                  
                               iny                          
                               sta ($a0),y                  
                               rts                          


                                                         
// Store tile of type A_onEntry+$80 to map in a random empty space on top of a                           
// wall                                                  
!tileToPlot:                   .byte $2a                      
                                                         
PLOT_1_ON_FLOOR:               //jmp !START+                  
                                                         
!START:                        sta !tileToPlot-             
!FIND_LOCATION_LOOP:           ldx #$3b                     
                               lda #$3f                     
                               jsr GET_RAND_LESS_THAN_X
                                          
                               clc                          
                               lda $a0                      
                               adc #$02                     
                               sta $fc                  
                               ldx $fc                  
                               lda YtoMapMsbTbl,x           
                               sta map2_zpw+1
                                                
                               ldx #$78                     
                               lda #$7f                     
                               jsr GET_RAND_LESS_THAN_X
                                          
                               clc                          
                               lda $a0                      
                               adc #$03                     
                               sta $fd                  
                               clc                          
                               ldx $fc                  
                               lda YtoMapLsbTbl,x           
                               adc $fd                  
                               sta map2_zpw
                                                  
                               clc                          
                               lda map2_zpw                   
                               adc #$80                     
                               sta map3_zpw                   
                               lda map2_zpw+1                 
                               adc #$00                     
                               sta map3_zpw+1
                                                
                               ldy #$00                     
                               lda (map2_zpw),y               
                               beq !CHECK_BENEATH+          // empty space?
                               jmp !DO_OVER+                
                                                         
!CHECK_BENEATH:                lda (map3_zpw),y 	// map3 is one of tiles down              
                               sta $a0                      
                               ldy #$70                 // note Y gets trashed right here!    
                               ldx #$66                     
                               lda $a0                      
                               //jsr CHECK_A_BETWEEN_XY                    
                               //lda $a0
			       A_BETWEEN_XY()                      
                               eor #$01                     
                               beq !CHECK_RIGHT+  //!PLOT_TILE+	// floor beneath?  rjr changed branch structure for extra below
			       jmp !DO_OVER+	
                               
                               // rjr added, prevents object from being put next to wall where it might not be possible to pick up
!CHECK_RIGHT:		       ldy #$01				//  reload y to give an offset of 1
     		               lda (map2_zpw),y
			       beq !PLOT_TILE+			// if space to right is empty plot tile, else redo
                                                                                                                               
!DO_OVER:                      jmp !FIND_LOCATION_LOOP-     	//******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!PLOT_TILE:                    clc                          
                               lda !tileToPlot-             
                               adc #$80                   
			       and #$7f			// difference in charset mapping
                               ldy #$00                     
                               sta (map2_zpw),y    
                                          
                               rts                          
 
 
 
                                                         
// Increments player score by amount passed in A.  Uses pointer at $be,f to find                           
// where scores are located.                             
// Possibly intended as a kind of obfuscation to prevent cheating? Player 1 score                           
// at $060d,e and Player 2 score at $060f, 0610                           
!pointsToAdd:                  .byte $14                      
                                                         
UPDATE_SCORE:                  //jmp !START+                  // nb score is actually written to display memory by L8098 <-- L8a9e <--L8b00
                                                         
!START:                        sta !pointsToAdd-            
                               lda NumPlayers
                                                                                                          
                               beq !ONE_PLAYER+             
                               jmp !TWO_PLAYERS+            
                                                         
!ONE_PLAYER:                   asl !pointsToAdd-   	// if one player, give them twice the points         
!TWO_PLAYERS:                  lda PlayerIndex_zp              
                               asl                          
                               php                          
                               clc                          
                               adc L0611                    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc L0611+1                    
                               sta $bf			// $be,f is the pointer to a player's score
                                                 
                               clc                          
                               ldy #$00                     
                               lda ($be),y              
                               adc !pointsToAdd-            
                               sta $bc                  
                               iny                          
                               lda ($be),y
                                             
                               adc #$00			//#$00                     
                               sta ($be),y              
                               lda $bc                  
                               dey                          
                               sta ($be),y              		// was writing to $2020 which is inside the AI decision to jump code, I set $611,12 into screen in main to temp fix
                               rts                          



                                                         
// Inflict damage/decrease life force on player by amount passed in A                           
!damagePoints:                 .byte $01                      
                                                         
INFLICT_DAMAGE_OR_KILL:        //jmp !START+                  
                                                         
!START:                        sta !damagePoints-           
                               ldx PlayerIndex_zp              
                               lda PlayerLifeForce,x              
                               cmp !damagePoints-           
                               bcc !DEAD+                   
                               jmp !SUBTRACT_LIFE+          
                                                         
!DEAD:                         lda #$00                     
                               ldx PlayerIndex_zp              
                               sta PlayerLifeForce,x              
                               //ldx PlayerIndex_zp			     
                               lda ZombieDelay,x            
                               beq !MAKE_ZOMBIE+            
                               rts			//internal jmp !TO_EXIT+                
                                                         
!MAKE_ZOMBIE:                  lda #$fa                     
                               ldx PlayerIndex_zp              
                               sta ZombieDelay,x   
!TO_EXIT:                      rts			//internal jmp !EXIT+                   
                                                         
!SUBTRACT_LIFE:                sec                          
                               ldx PlayerIndex_zp              
                               lda PlayerLifeForce,x              
                               sbc !damagePoints-           
                               ldx PlayerIndex_zp              
                               sta PlayerLifeForce,x                                             
!EXIT:                         rts                          
                                                      
                                                      
                                                      
                                                         
// This routine increases the life force of player indexed by A by an amount                           
// stored in X                                           
!playerNum:                    .byte $18                      
!lifePoints:                   .byte $ae                      
                                                         
ADD_LIFE:                      //jmp !START+                  
                                                         
!START:                        stx !lifePoints-             
                               sta !playerNum-  
                                           
                               clc                          
                               ldx !playerNum-              
                               lda PlayerLifeForce,x
                               beq !EXIT+			//added this, otherwise zombie gets life when player advances to next level causing all sorts of issues
                                             
                               adc !lifePoints-         	//if not completely dead, add the life points and store the new value back                                   
                               //ldx !playerNum-              
                               sta PlayerLifeForce,x 
                                            
                               lda #$c8                     
                               ldx !playerNum-              
                               cmp PlayerLifeForce,x              
                               bcc !CEILING_MAX+            
                               rts				//internal jmp !EXIT+                   
                                                         
!CEILING_MAX:                  lda #$c8                     
                               ldx !playerNum-              
                               sta PlayerLifeForce,x    
                                         
!EXIT:                         rts                          
                                      
                                      
                                      
                                                         
// Bookkeeping for when player sustains damage by weapon trap or enemy X=0a A=f0                           
!stunCounter:                  .byte $a6                      
!damagePoints:                 .byte $db                      
                                                         
DAMAGE_ROUTINE:                //jmp !START+                  
                                                         
!START:                        stx !damagePoints-           
                               sta !stunCounter-            
                               ldx PlayerIndex_zp              
                               lda PlayerDelayCountdown,x   
                               beq !CHECK_DEAD+             
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_DEAD:                   lda #$00                     
                               ldx PlayerIndex_zp              
                               cmp PlayerLifeForce,x              
                               bcc !DO_DAMAGE+              
                               rts				//internal jmp !EXIT+                   
                                                         
!DO_DAMAGE:                    lda !stunCounter-            
                               ldx PlayerIndex_zp              
                               sta PlayerDelayCountdown,x   
                               lda #$06                     
                               ldx PlayerIndex_zp              
                               sta NonMoveAnimSeq,x         	//stun sequence
                               lda #$1e                     
                               ldx PlayerIndex_zp              
                               sta StunDelay,x              
                               lda SoundStateLo_zp       
                               ora #$10                     
                               sta SoundStateLo_zp       
                               lda !damagePoints-           
                               jsr INFLICT_DAMAGE_OR_KILL  
                                
!EXIT:                         rts                          
                                                        
                                                        
                                                        
                                                        
                                                         
// object stolen by ghost, do associated actions like sound, animation etc.                           
!object:                       .byte $ad                      
                                                         
OBJECT_STOLEN:                 //jmp !START+                  
                                                         
!START:                        sta !object-                 
                               lda #$0d                     
                               sta SoundStateHi_zp
                                           
                               lda !object-                 
                               sta enemyInventory
                                          
                               clc                          
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               adc StatusBarTaskPtr,x       
                               sta map11_zpw                   
                               
                               txa                          // add player # to msb    
                               adc #$7c                     // testing testing. player 1 should write to 7c00+2, player 2 7db8+2
                               //adc #$00                     
                               sta map11_zpw+1
                                                
                               lda #$00                     
                               ldy #$00                     
                               sta (map11_zpw),y
                                             
                               lda #$08                     
                               ldx PlayerIndex_zp              
                               sta NonMoveAnimSeq,x         
                               lda #$28                     
                               ldx PlayerIndex_zp              
                               sta PlayerDelayCountdown,x   
                               lda #$1e                     
                               ldx PlayerIndex_zp              
                               sta StunDelay,x              
                               rts                          
                                                        
                                                        
                                                        
                                                         
// Implements damage by small ghosts, or stealing an object player is carrying on                           
// levels with candles/stones (0 and 2) where the player can only carry one                           
// object and collection of objects is only a means to activate lanterns, wells                           
// etc.                                                  
INTERACT_ENEMY_LVLS02:         jmp !START+                  
                                                         
!START:                        lda #$00                     
                               ldx PlayerIndex_zp              
                               cmp PlayerInventory,x        
                               bcc !STEAL_OBJECT+           
                               jmp !HURT_PLAYER+            
                                                         
!STEAL_OBJECT:                 ldx PlayerIndex_zp              
                               lda PlayerInventory,x        
                               sta $a0                      
                               lda $a0                      
                               jsr OBJECT_STOLEN            
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               sta PlayerInventory,x        
                               lda #$05                     
                               jsr INFLICT_DAMAGE_OR_KILL   
                               rts				//internal jmp !EXIT+                   
                                                         
!HURT_PLAYER:                  ldx #$0a                     
                               lda #$32                     
                               jsr DAMAGE_ROUTINE 
                                         
!EXIT:                         rts                          
                                                   
                                                   
                                                   
                                                         
// Implements enemy attack and stealing of objects on levels 1,3 and 4 where                           
// player can have many objects (e.g. diamonds) in inventory                           
INTERACT_ENEMY_LVLS134:        jmp !START+                  
                                                         
!START:                        lda #$00                     
                               ldx PlayerIndex_zp              
                               cmp NumberDiamonds,x         
                               bcc !STEAL+                  
                               jmp !NOTHING_TO_STEAL+       
                                                         
!STEAL:                        sec                          
                               ldx PlayerIndex_zp              
                               lda StatusBarTaskPtr,x       
                               sbc #$01                     
                               ldx PlayerIndex_zp              
                               sta StatusBarTaskPtr,x       
                               sec                          
                               lda CombinedTasksComplete    
                               sbc #$01                     
                               sta CombinedTasksComplete    
                               sec                          
                               ldx PlayerIndex_zp              
                               lda NumberDiamonds,x         
                               sbc #$01                     
                               ldx PlayerIndex_zp              
                               sta NumberDiamonds,x         
                               lda #$0a                     
                               jsr OBJECT_STOLEN            
                               lda #$05                     
                               jsr INFLICT_DAMAGE_OR_KILL   
                               rts				//internal jmp !EXIT+                   
                                                         
!NOTHING_TO_STEAL:             ldx #$0a                     
                               lda #$32                     
                               jsr DAMAGE_ROUTINE           
!EXIT:                         rts                          
                                                         
                                                         
                                                         
                                                         
// This routine handles the interaction of the player with task objects (candles,                           
// stones, lanterns, wells etc) and updates the task registers                           
// and statusbar icons as task phases are completed for levels 0 and 2                           
!tileUnderPlayer:              .byte $ae                      
                                                         
HANDLE_TASKS_LVLS02:           jmp !START+                  
                                                         
!START:                        sta !tileUnderPlayer- 
       
                               ldy #$00                                                  
                               lda (map01_zpw),y           // checking to see if on lantern or well. Weird logic because tile should already have been passed in A?    
                               ldx GameLevel_gbl            
                               eor unlitLanternTbl,x        
                               beq !CHECK_INVENTORY+        
                               jmp !START_TASK+             
                                                         
!CHECK_INVENTORY:              ldx PlayerIndex_zp              
                               lda PlayerInventory,x        
                               eor #$01                     
                               beq !COMPLETE_TASK+         // if at lantern or well and has object to complete this task, do it 
                               jmp !START_TASK+            // else look instead for candle or stone 
                                                         
!COMPLETE_TASK:                ldx GameLevel_gbl            
                               lda litLanternTbl,x          
                               sta $a0                      
                               ldy map01_zpw+1                 
                               ldx map01_zpw                   
                               lda $a0                      
                               jsr PLOT_2X2                 
                               lda #$09                     
                               sta SoundStateHi_zp            
                               clc                          
                               lda #$00                     
                               ldx PlayerIndex_zp             
                               adc StatusBarTaskPtr,x       
                               sta map11_zpw
                               
                               txa                   		// player 1 7c, player 2 7b
                               adc #$7c				//test                    
                               //adc #$00                     
                               sta map11_zpw+1
                                                
                               lda #$04                     //$c4 closed circle  
                               ldy #$00                     
                               sta (map11_zpw),y               
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               sta PlayerInventory,x        
                               ldx PlayerIndex_zp              
                               inc StatusBarTaskPtr,x       
                               inc CombinedTasksComplete    
                               ldx GameLevel_gbl            
                               lda PointsTbl,x              
                               sta $a0                      
                               lda $a0                      
                               jsr UPDATE_SCORE             
                               rts				//internal jmp !EXIT+                   
                                                         
!START_TASK:                   lda !tileUnderPlayer-        
                               eor #$31                     
                               beq !GET_CANDLE+             
                               rts				//internal jmp !EXIT+                   
                                                         
!GET_CANDLE:                   ldx PlayerIndex_zp              
                               lda PlayerInventory,x        
                               beq !PICK_UP_OBJECT+         
                               rts				//internal jmp !EXIT+                   
                                                         
!PICK_UP_OBJECT:               lda #$00                     
                               ldy #$00                     
                               sta (map01_zpw),y               
                               lda #$0b                     
                               sta SoundStateHi_zp            
                               clc                          
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               adc StatusBarTaskPtr,x       
                               sta map11_zpw
                               
                               txa                   
                               adc #$7c                //testing     
                               //adc #$00                     
                               sta map11_zpw+1
                                                
                               lda #$03                     //$c3
                               sta (map11_zpw),y	
                                              
                               lda #$01                     
                               ldx PlayerIndex_zp              
                               sta PlayerInventory,x        
                               lda #$05                     
                               jsr UPDATE_SCORE             
                               
!EXIT:                         rts                          
                                             
                                             
                                             
                                                         
// Check tile underneath player passed in A to handle endgame of picking up key                           
// and unlocking door                                    
!tileUnderPlayer:              .byte $30                      
                                                         
END_LEVEL_PHASE:               jmp !START+              //if I comment this out, can't pick up key. Is read to configure the jump table!
                                                         
!START:                        sta !tileUnderPlayer-        
                               lda !tileUnderPlayer-        
                               eor #$30			//$30                     
                               beq !CHECK_INVENTORY+        
                               jmp !CHECK_DOOR+             
                                                         
!CHECK_INVENTORY:              ldx PlayerIndex_zp              
                               lda PlayerInventory,x        
                               beq !PICK_UP_KEY+            
                               jmp !CHECK_DOOR+             
                                                         
!PICK_UP_KEY:                  lda #$00                     
                               ldy #$00                     
                               sta (map01_zpw),y               
                               lda #$0c                     
                               sta SoundStateHi_zp            
                               clc                          
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               adc StatusBarTaskPtr,x       
                               sta map11_zpw
                               
                               txa                   
                               adc #$7c      //testing               
                               //adc #$00                     
                               sta map11_zpw+1
                                                     
                               lda #$05                    //#$c5 
                               sta (map11_zpw),y 
                              
                                             
                               lda #$02                     
                               ldx PlayerIndex_zp              
                               sta PlayerInventory,x        
                               lda #$1e                     
                               jsr UPDATE_SCORE             
                               rts			//internal jmp !EXIT+                   
                                                         
!CHECK_DOOR:                   lda !tileUnderPlayer-        
                               eor #$40                     
                               beq !CHECK_INVENTORY+        
                               rts			//internal jmp !EXIT+                   
                                                         
!CHECK_INVENTORY:              ldx PlayerIndex_zp              
                               lda PlayerInventory,x        
                               eor #$02                     
                               beq !COMPLETE_LEVEL+         
                               rts			//internal jmp !EXIT+                   
                                                         
!COMPLETE_LEVEL:               ldy #$01                     
                               sty LoadLevelTrigger         
                               ldx #$28                     
                               lda #$00                     
                               jsr ADD_LIFE                 
                               ldx #$28                     
                               lda #$01                     
                               jsr ADD_LIFE                 
                               clc                          
                               lda #$32                     
                               ldx GameLevel_gbl            
                               adc PointsTbl,x              
                               sta $a0                      
                               lda $a0                      
                               jsr UPDATE_SCORE             
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               sta PlayerInventory,x
                               
                               	//----added to ensure got door sound is not blocked or pre-empted----
			       	//----and player can't run away from door after got it

				lda #$ff		// mask out joysticks for both players
			       	sta Player1JoyMask
			       	sta Player2JoyMask
!lp:	
				lda soundPlaying1_zp 
				ora soundPlaying2_zp 
				bne !lp-
				//------------------------------------------------------------------                               
                                       
                               lda #$12                 //got door sound    
                               sta SoundStateHi_zp                                   
                                     
                               clc                          
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               adc StatusBarTaskPtr,x       
                               sta map11_zpw
                               
                               txa
                               adc #$7c
                                          	                   
                               adc #$00                     
                               sta map11_zpw+1		
                                                     
                               lda #$00                     
                               ldy #$00                     
score:                         sta (map11_zpw),y   
           
!EXIT:                         rts                          
                                 
                                 
                                 
                                                         
// Handle completion collection tasks which are the objectives of levels 1, 3,                           
// and 4. If not level 4, expects Y register to contain reference to 2x2 tile                           
// object.  Does nothing for some values of A.                           
!AonEntry:                     .byte $85                      
                                                         
HANDLE_TASKS_LVLS134:          jmp !START+                  
                                                         
!START:                        sta !AonEntry-               
                               lda #$b2                     
                               and #$7f                     
                               sta $be                  
                               lda !AonEntry-               
                               eor $be                  
                               beq !WHAT_LEVEL+             
                               rts				//internal jmp !EXIT+                   
                                                         
!WHAT_LEVEL:                   lda GameLevel_gbl            
                               eor #$04                     
                               beq !LEVEL_4+                
                               jmp !OTHER_LEVELS+           
                                                         
!LEVEL_4:                      ldy map01_zpw+1                 
                               ldx map01_zpw                   
                               lda #$ba                     
                               jsr PLOT_2X2                 
                               lda #$13                     
                               sta SoundStateHi_zp            
                               jmp !UPDATE_TASKBAR+         
                                                         
!OTHER_LEVELS:                 ldx map01_zpw+1                 
                               lda map01_zpw                   
                               jsr ERASE_2X2                
                               lda #$14                     
                               sta SoundStateHi_zp            
!UPDATE_TASKBAR:               ldx PlayerIndex_zp              
                               inc NumberDiamonds,x         
                               clc                          
                               lda #$00                     
                               ldx PlayerIndex_zp              
                               adc StatusBarTaskPtr,x       
                               sta map11_zpw
                               
                               txa                   
                               adc #$7c                     //testing
                               //adc #$00                     
                               sta map11_zpw+1 
                                               
                               lda #$06				// $c6 diamond                     
                               ldy #$00                     
                               sta (map11_zpw),y     
                                         
                               ldx PlayerIndex_zp              
                               inc StatusBarTaskPtr,x       
                               inc CombinedTasksComplete    
                               sty HasDiamond               
                               ldx GameLevel_gbl            
                               lda PointsTbl,x              
                               sta $a0                      
                               lda $a0                      
                               jsr UPDATE_SCORE 
                                           
!EXIT:                         rts                          
                                                         
                                                         
                                                         
                                                         
// this routine implements the capture of the wizard, erasing him                           
// from the map, configuring the jump table to stop the lightning, and increasing                           
// the player's score and life points                           
!TILE_UNDER_PLAYER:            .byte $36                      
                                                         
CAPTURE_WIZARD:                jmp !START+                  	// don't comment out, gets read to configure the jump table
							                                                          
!START:                        sta !TILE_UNDER_PLAYER-      
                               lda !TILE_UNDER_PLAYER-      
                               eor #$36                     	//wizard
                               beq !CONFIG_JUMP_ENDMAGIC_RTS+  
                               rts				//internal jmp !EXIT+                   
                                                         
// this is getting the address of the END_MAGIC routine, and putting it in the                           
// first jump table slot.                                
!CONFIG_JUMP_ENDMAGIC_RTS:     lda JUMP_4+2                 
                               sta JUMP_1+2                 
                               lda JUMP_4+1                 
                               sta JUMP_1+1
                                                
                               ldx map01_zpw+1                 
                               lda map01_zpw                   
                               jsr ERASE_2X2			// erasing the wizard from map
                                               
// setting jump table so that the routines for levels 1 3, 4 get run                           
                               lda HANDLE_TASKS_LVLS134+2   
                               sta JumpConfigTable+1        
                               lda HANDLE_TASKS_LVLS134+1   
                               sta JumpConfigTable          
                               lda #$15                     
                               sta SoundStateHi_zp            
                               lda #$32                     
                               jsr UPDATE_SCORE             
                               ldx #$14                     
                               lda PlayerIndex_zp              
                               jsr ADD_LIFE   
                                             
!EXIT:                         rts                          
                             
                             
                             
                                                         
// This routine checks for damage done by opponents, enemies, and magic and                           
// updates player stats accordingly                           
//  - does not implement traps                           
!tileUnderPlayer:              .byte $db                      
                                                         
DO_ATTACK:                     //jmp !START+                  
                                                         
!START:                        sta !tileUnderPlayer-        
                               lda !tileUnderPlayer-        
                               ldx PlayerIndex_zp              
                               eor WeaponTile,x             
weap:	                       beq !HIT_BY_WEAPON+          
                               jmp !LEFT_BAT+               
                                                         
!HIT_BY_WEAPON:                ldx #$0a                     
                               lda #$f0                     
                               jsr DAMAGE_ROUTINE           
!LEFT_BAT:                     lda !tileUnderPlayer-        
                               eor #$23                     
                               beq !LEFT_BAT_ATTACK+        
                               jmp !RIGHT_BAT+              
                                                         
!LEFT_BAT_ATTACK:              clc                          
                               lda map01_zpw                   
                               adc #$01                     
                               sta map11_zpw                   
                               lda map01_zpw+1		//$ce                      
                               adc #$00                     
                               sta map11_zpw+1                      
                               ldy #$00                     
                               lda (map11_zpw),y               
                               and #$7f                     
                               sta $be                  
                               lda $be                  
                               eor #$24                     
                               beq !DO_DAMAGE1+             
                               rts				//internal jmp !PASS_TO_EXIT1+          
                                                         
!DO_DAMAGE1:                   ldx #$0f                     
                               lda #$64                     
                               jsr DAMAGE_ROUTINE           
!PASS_TO_EXIT1:                rts				//internal jmp !EXIT+                   
                                                         
!RIGHT_BAT:                    lda !tileUnderPlayer-        
                               eor #$24                     
                               beq !RIGHT_BAT_ATTACK+       
                               jmp !SPIDER+                 
                                                         
!RIGHT_BAT_ATTACK:             sec                          
                               lda map01_zpw                   
                               sbc #$01                     
                               sta map11_zpw                   
                               lda map01_zpw+1		//lda $ce                      
                               sbc #$00                     
                               sta map11_zpw+1                      
                               ldy #$00                     
                               lda (map11_zpw),y               
                               and #$7f                     
                               sta $be                  
                               lda $be                  
                               eor #$23                     
                               beq !DO_DAMAGE2+             
                               rts				//internal jmp !PASS_TO_EXIT+           
                                                         
!DO_DAMAGE2:                   ldx #$0f                     
                               lda #$64                     
                               jsr DAMAGE_ROUTINE           
!PASS_TO_EXIT:                 rts				//internal jmp !EXIT+                   
                                                         
!SPIDER:                       lda !tileUnderPlayer-        
                               eor #$27                     
                               beq !DO_DAMAGE3+             
                               lda !tileUnderPlayer-        
                               eor #$28                     
                               beq !DO_DAMAGE3+             
                               jmp !SMALL_GHOST+            
                                                         
!DO_DAMAGE3:                   ldx #$14                     
                               lda #$64                     
                               jsr DAMAGE_ROUTINE           
                               rts				//internal jmp !EXIT+                   
                                                         
!SMALL_GHOST:                  lda !tileUnderPlayer-        
                               eor #$25                     
                               beq !CHECK_ENEMY_INVENTORY+  
                               lda !tileUnderPlayer-        
                               eor #$26                     
                               beq !CHECK_ENEMY_INVENTORY+  
                               jmp !LIGHTNING+              
                                                         
!CHECK_ENEMY_INVENTORY:        lda enemyInventory           
                               beq !DAMAGE_OR_THEFT+        
                               rts				//internal jmp !PASS_TO_EXIT2+          
                                                         
!DAMAGE_OR_THEFT:              jsr JUMP_2                   // does INTERACT_ENEMY for the appropriate level mechanics
!PASS_TO_EXIT2:                rts				//internal jmp !EXIT+                   
                                                         
!LIGHTNING:                    lda !tileUnderPlayer-        
                               eor #$48                     
                               beq !DO_DAMAGE4+             
                               rts				//internal jmp !EXIT+                   
                                                         
!DO_DAMAGE4:                   ldx #$05                     
                               lda #$1e                     
                               jsr DAMAGE_ROUTINE 
                                         
!EXIT:                         rts                          
                                                         
// Checks for trap at map pointer and triggers trap expansion animation sequence                           
// if present                                            
!mapLsb:                       .byte $23                      
!mapMsb:                       .byte $44                      
                                                         
SERVICE_TRAPS:                 //jmp !START+                  
                                                         
!START:                        stx !mapMsb-                 
                               sta !mapLsb-                 
                               lda !mapLsb-                 
                               sta $be                  
                               lda !mapMsb-                 
                               sta $bf                  
                               ldy #$00                     
                               lda ($be),y              
                               and #$7f                     
                               sta $bc                  
                               lda $bc                  
                               eor #$2b                     
                               beq !HANDLE_TRAP+            
                               jmp !EXIT+                   
                                                         
!HANDLE_TRAP:                  lda TrapState                // there is some kind of a state machine for the trap that I am not currently running
                               beq !TRIGGER_TRAP+           
                               jmp !EXIT+                   
                                                         
!TRIGGER_TRAP:                 lda #$0e                     
                               sta SoundStateHi_zp            
                               iny                          
                               sty TrapState                // set trap state to 1
                               lda !mapMsb-                 
                               sta AnimationLocationPtr+1   //
                               lda !mapLsb-                 
                               sta AnimationLocationPtr     // 2ea8,9 tell the animator where to do it
!EXIT:                         rts                          
                                            
                                            
                                            
                                                         
// Scan for traps to right and left of player                           
!tileUnderPlayer:              .byte $0c                      
                                                         
TRAP_SCAN:                     //jmp !START+                  
                                                         
!START:                        sta !tileUnderPlayer-        
                               sec                          
                               lda map01_zpw                   
                               sbc #$02                     
                               sta $a0                      
                               lda map01_zpw+1                 
                               sbc #$00                     
                               sta $a1                      
                               ldx $a1                      
                               lda $a0                      
                               jsr SERVICE_TRAPS            
                               clc                          
                               lda map01_zpw                   
                               adc #$02                     
                               sta $a0                      
                               lda map01_zpw+1                 
                               adc #$00                     
                               sta $a1                      
                               ldx $a1                      
                               lda $a0                      
                               jsr SERVICE_TRAPS            
// part below handles case where trap is already triggered and player enters                           
// expanding trap                                        
                               lda !tileUnderPlayer-        
                               eor #$2c                     
                               beq !DO_DAMAGE+              
                               lda !tileUnderPlayer-        
                               eor #$2d                     
                               beq !DO_DAMAGE+              
                               rts			//internal jmp !EXIT+                   
                                                         
!DO_DAMAGE:                    ldx #$0a                     
                               lda #$50                     
                               jsr DAMAGE_ROUTINE           
!EXIT:                         rts                          
                                                 
                                                 
                                                 
                                                         
// Routine to check for and initiate a player or zombie jump through the tele-                           
// portal                                                
// Object under player passed in A                           
!tileUnderPlayer:              .byte $0c                      
                                                         
INITIATE_PORTAL_TRAVEL:        //jmp !START+                  
                                                         
!START:                        sta !tileUnderPlayer-        
                               lda !tileUnderPlayer-        
                               eor #$4c                     
                               beq !CHECK_JSTICK+           
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_JSTICK:                 ldx PlayerIndex_zp              
                               lda PlayerJoystickBits,x           
                               and #$02                     
                               sta $be                  
                               lda $be                  
                               beq !CHECK_PORTAL_STATE+     
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_PORTAL_STATE:           lda TeleportalMode           
                               beq !PORTAL_JUMP_NORMAL+     
                               rts				//internal jmp !EXIT+                   
                                                         
!PORTAL_JUMP_NORMAL:           ldy #$01                     
                               sty TeleportalMode           
                               sty PortalDelayCounter+1     
                               lda #$2c                     
                               sta PortalDelayCounter       
                               lda #$0a                     
                               ldx PlayerIndex_zp              
                               sta NonMoveAnimSeq,x         
                               ldx PlayerIndex_zp              
                               lda PlayerControlMode,x      
                               eor #$02                     
                               beq !PORTAL_JUMP_ZOMBIE+     
                               rts				//internal jmp !EXIT+                   
                                                         
!PORTAL_JUMP_ZOMBIE:           lda PlayerIndex_zp              
                               eor #$01                     
                               sta $be                  
                               ldx $be                  
                               lda PlayerTileXcoordinate,x      
                               sta TeleportalTargetX       
                               lda PlayerIndex_zp              
                               eor #$01                     
                               sta $be                  
                               ldx $be                  
                               lda PlayerTileYcoordinate,x      
                               sta TeleportalTargetY       
                               lda #$02                     
                               sta TeleportalState   
                                      
!EXIT:                         rts                          
                                             
                                             
                                             
                                                         
// Check for zombie attack and do damage as necessary                           
!AonEntry:                     .byte $1f                      
                                                         
ZOMBIE_ATTACK:                 //jmp !START+                  
                                                         
!START:                        sta !AonEntry-               
                               lda PlayerIndex_zp              
                               eor #$01                     
                               sta $be                  
                               ldx $be                  
                               lda PlayerControlMode,x      
                               eor #$02                     
                               beq !ZOMBIE_ACTIVE+          
                               rts				//internal jmp !EXIT+                   
                                                         
!ZOMBIE_ACTIVE:                lda PlayerIndex_zp              
                               eor #$01                     
                               sta $be                  
                               ldx $be                  
                               lda PlayerDelayCountdown,x   
                               beq !CHECK_X_OVERLAP+        
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_X_OVERLAP:              lda PlayerTileXcoordinate        // checking X overlap of two players
                               eor PlayerTileXcoordinate+1	//PlayerTileXcoordinate	      
                               beq !CHECK_Y_OVERLAP+        
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_Y_OVERLAP:              lda PlayerTileYcoordinate        /// checking Y overlap of two players
                               eor PlayerTileYcoordinate+1	//PlayerDelayCountdown-1   
                               beq !DO_DAMAGE+              
                               rts				//internal jmp !EXIT+                   
                                                         
!DO_DAMAGE:                    ldx #$14                     
                               lda #$78                     
                               jsr DAMAGE_ROUTINE  
                                        
!EXIT:                         rts                          
                                                      
                                                      
                                                      
                                                         
// Main routine handling all direct interactions of the player with map objects and enemies on map.
// HANDLE_TASKS is called to implement the interactions.
// The results of those interactions are implemented here as life, death, and zombification of a player.  Player index passed in A                           
!playerNumInput:               .byte $01                      
!xCoordinate:                  .byte $0c                      
!yCoordinate:                  .byte $08                      
                                                         
LIFE_DEATH_MOTION_AND_STUN:    //jmp !START+                    
                                                         
!START:                        sta !playerNumInput-         // Player index passed into this routine via A
                               //lda !playerNumInput-         
                               sta PlayerIndex_zp
                                             
                               ldx PlayerIndex_zp              
                               lda PlayerTileYcoordinate,x      
                               sta !yCoordinate-

                               clc                          // lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
                               ldx !yCoordinate-            
                               lda YtoMapLsbTbl,x           
                               ldx PlayerIndex_zp              
                               adc PlayerTileXcoordinate,x      
                               sta map01_zpw                   
                               ldx !yCoordinate-            
                               lda YtoMapMsbTbl,x           
                               sta map01_zpw+1
                                                
                               ldy #$00                     
                               lda (map01_zpw),y               
                               and #$7f                     
                               sta !xCoordinate-	   // no longer used as xCoordinate, now contains tile under player
                                           
                               ldx PlayerIndex_zp              
                               lda PlayerLifeForce,x              
                               beq !ALREADY_DEAD+           
                               jmp !LIVE_PLAYER_CONTROL+    
                                                         
!ALREADY_DEAD:                 ldx PlayerIndex_zp              
                               lda PlayerControlMode,x      
                               eor #$02                     
                               beq !ALREADY_ZOMBIE+         
                               jmp !CHECK_ZOMBIFICATION_DELAY+  
                                                         
!ALREADY_ZOMBIE:               lda !xCoordinate-            
                               ldx PlayerIndex_zp              
                               eor WeaponTile,x             
                               beq !SWITCH_ZOMBIE_CONTROL+  
                               jmp !ZOMBIE_TELEPORT+        
                                                         
!SWITCH_ZOMBIE_CONTROL:        lda #$03                     
                               ldx PlayerIndex_zp              
                               sta PlayerControlMode,x      
                               lda #$fa                     
                               ldx PlayerIndex_zp              
                               sta ZombieDelay,x                                                 
                                           
!ZOMBIE_TELEPORT:              lda !xCoordinate-            
                               jsr INITIATE_PORTAL_TRAVEL   
                               jmp !PASS_TO_EXIT+           
                                                         
!CHECK_ZOMBIFICATION_DELAY:    ldx PlayerIndex_zp              
                               lda ZombieDelay,x            
                               eor #$01                     
                               beq !WAKE_UP_FROM_DELAY+     
                               jmp !DECREMENT_DELAY_TIMER+  
                                                         
!WAKE_UP_FROM_DELAY:           lda #$02                     	// set to zombie control mode
                               ldx PlayerIndex_zp              
                               sta PlayerControlMode,x
                               
                               lda #$24				// switch the sprite patterns
                               sta ZombieOffset1_zp,x
                               
                               jsr RETURN_OBJECT_TO_MAP		//rjr added, if player had candle/stone/etc when killed return it to the map 
                                     
                               lda #$17                     
                               sta SoundStateHi_zp            
                               rts				//internal jmp !PASS_TO_EXIT+           
                                                         
!DECREMENT_DELAY_TIMER:        sec                          
                               ldx PlayerIndex_zp              
                               lda ZombieDelay,x            
                               sbc #$01                     
                               ldx PlayerIndex_zp              
                               sta ZombieDelay,x            
!PASS_TO_EXIT:                 rts				//internal jmp !EXIT+                   
                                                         
!LIVE_PLAYER_CONTROL:          ldx PlayerIndex_zp              
                               lda PlayerJoystickBits,x           
                               and #$02                     
                               sta $be                  
                               lda $be                  
                               beq !CHECK_POTION+           
                               jmp !CHECK_LONG_STUN+        
                                                         
!CHECK_POTION:                 lda !xCoordinate-            // here xCoordinate contains tile under player
                               jsr JUMP_3                   // does HANDLE_TASKS for the appropriate level mechanics
                               lda !xCoordinate-            
                               eor #$2a                     
                               beq !USE_POTION+             
                               jmp !CHECK_LONG_STUN+        
                                                         
!USE_POTION:                   ldx #$0a                     
                               lda PlayerIndex_zp              
                               jsr ADD_LIFE                 
                               lda #$00                     
                               ldy #$00                     
                               sta (map01_zpw),y               
                               lda #$11                     
                               sta SoundStateHi_zp          
                                 
!CHECK_LONG_STUN:              ldx PlayerIndex_zp              
                               lda PlayerDelayCountdown,x   
                               beq !CHECK_SHORT_STUN+       
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_SHORT_STUN:             ldx PlayerIndex_zp              
                               lda StunDelay,x              
                               beq !CHECK_CAN_INTERACT_TILE+  
                               jmp !DECREMENT_IMMUNITY_TIMER+  
                                                         
!CHECK_CAN_INTERACT_TILE:      lda #$1f                     
                               cmp !xCoordinate-            
                               bcc !CHECK_IF_FALLING+       
                               jmp !ATTACK+                 
                                                         
!CHECK_IF_FALLING:             ldx PlayerIndex_zp              
                               lda PlayerShapeSelect,x                  
                               eor #$01                      // falling "shape" which is fixed standing pose animation
                               bne !HANDLE_ATTACKS_TRAPS+   
                               jmp !ATTACK+                 
                                                         
!HANDLE_ATTACKS_TRAPS:         lda !xCoordinate-            
                               jsr DO_ATTACK                
!ATTACK:                       jsr ZOMBIE_ATTACK            
                               lda !xCoordinate-            
                               jsr INITIATE_PORTAL_TRAVEL   
                               lda !xCoordinate-            
                               jsr TRAP_SCAN                
                               rts				//internal jmp !EXIT+                   
                                                         
!DECREMENT_IMMUNITY_TIMER:     sec                          
                               ldx PlayerIndex_zp              
                               lda StunDelay,x              
                               sbc #$01                     
                               ldx PlayerIndex_zp              
                               sta StunDelay,x 
                                            
!EXIT:                         rts                          
                                                        
                                                        
                                                        
                                                         
// Determines when tasks are complete on a level and plays a sequence of sound                           
// effects to make the little "duh-dum-deh" tune that plays during the search for                           
// key and door                                          
!tuneTbl:                      .byte $04                      
                               .byte $00                      
                               .byte $00                      
                               .byte $02                      
                               .byte $00                      
                               .byte $03                      
                               .byte $00                      
                               .byte $00                      
                               .byte $01                      
                               .byte $02                      
                               .byte $00                      
                               .byte $03                      
                               .byte $04                      
                               .byte $00                      
                               .byte $01                      
                               .byte $02                      
                               .byte $00                      
                               .byte $00                      
                               .byte $04                      
                               .byte $00                      
                               .byte $00                      
                               .byte $02                      
                               .byte $00                      
                               .byte $03                      
                               .byte $04                      
                               .byte $00                      
                               .byte $00                      
                               .byte $02                      
                               .byte $00                      
                               .byte $00                      
                               .byte $01                      
                               .byte $01                      
                               .byte $01                      
                               .byte $02                      
                               .byte $00                      
                               .byte $00                      
!note_idx:                     .byte $00                      
!counter:                      .byte $00                      
                                                         
SEARCH_TUNE:                   //jmp !START+                  
                                                         
!START:                        lda #$00                     
                               cmp !counter-                
                               bcc !CONTINUE+               //branch if counter > 00
                               jmp !COUNT_OBJECTS+          
                                                         
!CONTINUE:                     sec                          
                               lda !counter-                
                               sbc #$01                     
                               sta !counter-                
                               jmp !EXIT+                   
                                                         
!COUNT_OBJECTS:                lda PlayerInventory          
                               asl                          
                               sta $be                  
                               sec                          
                               lda #$0d                     
                               sbc $be                  
                               sta $bc                  
                               lda PlayerInventory+1        
                               asl                          
                               sta $be                  
                               sec                          
                               lda $bc                  
                               sbc $be                  
                               sta !counter-                //@counter = $0d - 2*(p1_objects+p2_objects)
                               lda #$23                     
                               cmp !note_idx-               
                               bcc !RESET_TUNE+             
                               jmp !GET_NOTE+               
                                                         
!RESET_TUNE:                   ldy #$00                     
                               sty !note_idx-               
!GET_NOTE:                     lda #$00                     
                               ldx !note_idx-               
                               cmp !tuneTbl- ,x             
                               bcc !CHECK_SOUND+            
                               jmp !SKIP_THIS_NOTE+         
                                                         
!CHECK_SOUND:                  lda SoundStateHi_zp            
                               eor #$ff                     
                               beq !PLAY_NOTE+              
                               jmp !SKIP_THIS_NOTE+         
                                                         
!PLAY_NOTE:                    clc                          
                               ldx !note_idx-               
                               lda !tuneTbl- ,x             
                               adc #$18                     
                               sta SoundStateHi_zp            
!SKIP_THIS_NOTE:               inc !note_idx-               
!EXIT:                         rts                          
                                 


                       
// Routine that handles statusbar color changes when searching for key or exit                           
// door                                                  
SEARCH_COLORBAR:
 		               lda #BLUE	//$60 blue    ****this structure can cause flicker bc sets default colors every pass
                               sta p1StatusColor_zp                      
                               lda #GREEN	//$a2 green
                               sta p2StatusColor_zp                   
                                  
                               lda LevelEndFlag             
                               beq !CHECK_SEARCH_FLAG+      
                               jmp !CHECK_PLAYER_1+         
                                                         
!CHECK_SEARCH_FLAG:            lda SBsearchColorFlag        
                               beq !EXIT1+                  
                               jmp !CHECK_PLAYER_1+         
                                                         
!EXIT1:                        rts                          
                                                         
!CHECK_PLAYER_1:               lda PlayerTileXcoordinate        //Player 1
                               lsr                          
                               lsr                          
                               sta $be                  
                               //lda $be                  
                               eor XcoordinateDivBy4        
                               beq !SET_PLAYER_1_RED+       
                               jmp !CHECK_PLAYER_2+         
                                                         
!SET_PLAYER_1_RED:             lda #RED	//$22                     //red
                               sta p1StatusColor_zp           
                                          
!CHECK_PLAYER_2:               lda PlayerTileXcoordinate+1      //Player 2
                               lsr                          
                               lsr                          
                               sta $be                  
                               //lda $be                  
                               eor XcoordinateDivBy4        
                               beq !SET_PLAYER_2_RED+       
                               rts				//internal jmp !EXIT3+                  
                                                         
!SET_PLAYER_2_RED:             lda #RED //$22                     //red
                               sta p2StatusColor_zp   
                                                  
!EXIT3:                        rts                          
                                       
                                       
                                       
                                                         
// Handlle life force decrement and sound effect queue                           
!deathRate:                    .byte $f9                      // life decrement interval per game level
                               .byte $e1                      
                               .byte $d2                      
                               .byte $be                      
                               .byte $b4 
                                                    
CLOCKED_SOUND_AND_LIFE_DEC:    //jmp !START+                  
                                                         
!START:                        lda #$00                     
                               cmp LifeForceDecDelay        
                               bcc !SERVICE_COUNTER+        
                               jmp !SET_RATE_FOR_LEVEL+     
                                                         
!SERVICE_COUNTER:              sec                          
                               lda LifeForceDecDelay        
                               sbc #$01                     
                               sta LifeForceDecDelay        
                               jmp !CHECK_SOUND+            
                                                         
!SET_RATE_FOR_LEVEL:           ldx GameLevel_gbl            
                               lda !deathRate- ,x           
                               sta LifeForceDecDelay        
                               ldy #$00                     
                               sty PlayerIndex_zp              
                               lda #$01                     
                               jsr INFLICT_DAMAGE_OR_KILL   
                               ldy #$01                     
                               sty PlayerIndex_zp              
                               lda #$01                     
                               jsr INFLICT_DAMAGE_OR_KILL   
!CHECK_SOUND:                  lda SoundStateHi_zp		//$ff when free
			       ora soundPlaying2_zp		//$00 when free		 added, don't load unless voice 2 is free            
                               eor #$ff                     
                               beq !PLAY_NEXT_SOUND+        
                               rts				//internal jmp !EXIT+                   
                                                         
!PLAY_NEXT_SOUND:              lda SoundEffectQueue         
                               sta SoundStateHi_zp            
                               lda #$ff                     
                               sta SoundEffectQueue         
!EXIT:                         rts                          
 
                  
                  
                                                         
// Handles some basic things not including interaction with enemies.                           
// I know this is called from $85cd through the jump table at $2f00    
                       
!canInteractState:             .byte $01                      
                                                         
MAIN_HANDLER_1:                jmp !START+                  
                                                         
!START:                        lda JumpConfigTable+1        // JUMP_3 does HANDLE_TASKS mechanics appropriate for the game level 
                               sta JUMP_3+2                 
                               lda JumpConfigTable          
                               sta JUMP_3+1
                                                
                               lda JumpConfigTable+3        // JUMP_2 does INTERACT_ENEMY_LVLS02 mechanics appropriate for the game level 
                               sta JUMP_2+2                 
                               lda JumpConfigTable+2        
                               sta JUMP_2+1     
                                           
                               lda #$01                     
                               and #$01                     
                               sta $be                  
                               lda !canInteractState-       
                               eor $be                  
                               sta !canInteractState-       
                               lda !canInteractState- 
                                     
                               jsr LIFE_DEATH_MOTION_AND_STUN 	//in this routine, the map01 pointer is generated from the tile coordinates PlayerTileX/Ycoord
                               jsr SEARCH_COLORBAR          
                               jsr CLOCKED_SOUND_AND_LIFE_DEC 
                               
                               lda LevelEndFlag             
                               eor #$01                     
                               beq !CHECK_SEARCH+           
                               jmp !CHECK_LIGHTNING_DELAY+  
                               
                                                         
!CHECK_SEARCH:                 jsr SEARCH_TUNE    
          
!CHECK_LIGHTNING_DELAY:        lda #$00                     
                               cmp LightningDelayCounter    
                               lda #$00                     
                               sbc LightningDelayCounter+1  
                               bcc !DEC_LIGHTNING_DELAY+    
                               rts				//internal jmp !EXIT+                   
                                                         
!DEC_LIGHTNING_DELAY:          sec                          
                               lda LightningDelayCounter    
                               sbc #$01                     
                               sta LightningDelayCounter    
                               lda LightningDelayCounter+1  
                               sbc #$00                     
                               sta LightningDelayCounter+1  
                               
!EXIT:                         rts                          
                                       
                                       
                                       
                                                         
PLACE_A_TRAP_ON_MAP:           //jmp !START+                  
                                                         
!START:                        jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map2_zpw+1                 
                               lda $a0                      
                               sta map2_zpw                   
                               lda #$2b                     
                               ldy #$00                     
                               sta (map2_zpw),y               
                               inc map2_zpw                   
                               bne !PLOT_TRAP+              
                               inc map2_zpw+1                 
!PLOT_TRAP:                    lda #$80                     
                               sta (map2_zpw),y         
                                     
                               rts                          
                                                         
// Some start of level initialization of inventory and inventory display. Sets                           
// inventories to zero and clears statusbar markers, resets marker pointers.                           
// Zeros memory at $2f33, $2f34, $911a-$9122, $915a-$9162. Then it stores                           
// A_onEntry+#$1a into $2f31 and A_onEntry+#$5a into $2f32                           
!taskMarkPtrOffset:            .byte $00                      
                                                         
INIT_PLAYER_INVENTORIES:       //jmp !START+                  
                                                         
!START:                        sta !taskMarkPtrOffset-      
                               lda #$00                     
                               sta PlayerInventory          // player 1
                               lda #$00                     
                               sta PlayerInventory+1	    // player 2
                                       
                               lda #$00                     
                               sta $a3                      
                               ldy #$08                     
                               ldx #$7c                    
                               lda #$02                     
                               jsr WRITE_A3_TO_AX_LENGTH_Y    //$911a - $911a+8 player 1 statusbar marker slots --> 7c02-
                               lda #$00                     
                               sta $a3                      
                               ldy #$08                     
                               ldx #$7d                     
                               lda #$ba                     
                               jsr WRITE_A3_TO_AX_LENGTH_Y    //$915a - $915a+8 player 2 statusbar marker slots --> 7dba

                               clc                          
                               lda #$02                       // task marker offset from edge of screen, sprite is there to block bus junk
                               adc !taskMarkPtrOffset-        // this is from A=0 in POPULATE_MAP, but A=3 from LEVELS134
                               sta StatusBarTaskPtr
                                        
                               clc                          
	                       lda #$ba 		     // offset from 7d00 is $ba               
                               adc !taskMarkPtrOffset-       // this is from A=0 in POPULATE_MAP, but A=3 from LEVELS134
                               sta StatusBarTaskPtr+1       
                               rts                          
                                                         
// Update random location pointers for lightning effect and plot the lighting on                           
// the map                                               
!idx:                          .byte $dd                      
                                                         
MAKE_LIGHTNING:                jmp !START+      	   	 // this is read to make jump table, don't comment out            
                                                         
!START:                        inc !idx-                    
                               lda SBsearchColorFlag        
                               cmp !idx-                    
                               bcc !START_UPDATE+           
                               rts				//internal jmp !EXIT+                   
                                                         
!START_UPDATE:                 ldy #$00                     
                               sty !idx-                    
                               sty InitIndex_zp                      
!LOOP:                         lda #$04                     
                               cmp InitIndex_zp                      
                               bcs !MAKE_MAP_POINTERS+      
                               jmp !RANDOM_DELAY+           
                                                         
!MAKE_MAP_POINTERS:            lda InitIndex_zp                      
                               asl                          
                               php                          
                               clc                          
                               adc ptrLightningTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrLightningTable+1  
                               sta $bf                  
                               ldy #$01                     
                               lda ($be),y              
                               sta $a1                      
                               dey                          
                               lda ($be),y              
                               sta $a0                      
                               ldx $a1                      
                               //lda $a0                      
                               jsr ERASE_2X2                
                               lda InitIndex_zp                      
                               asl                          
                               php                          
                               clc                          
                               adc ptrLightningTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrLightningTable+1  
                               sta $bf                  
                               //lda $bf                  
                               pha                          
                               lda $be                  
                               pha                          
                               jsr GET_SAFE_2X2             
                               pla                          
                               sta $be                  
                               pla                          
                               sta $bf                  
                               lda $a1                      
                               ldy #$01                     
                               sta ($be),y              
                               lda $a0                      
                               dey                          
                               sta ($be),y              
                               lda InitIndex_zp                      
                               asl                          
                               php                          
                               clc                          
                               adc ptrLightningTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrLightningTable+1  
                               sta $bf                  
                               iny                          
                               lda ($be),y              
                               sta $a2                      
                               dey                          
                               lda ($be),y              
                               sta $a1                      
                               ldy $a2                      
                               ldx $a1                      
                               lda #$48                     
                               jsr PLOT_2X2                 
                               inc InitIndex_zp                      
                               jmp !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!RANDOM_DELAY:                 lda SoundStateLo_zp       
                               ora #$40                     
                               sta SoundStateLo_zp       
                               clc                          
                               //lda #$0f
                               //jsr GenRandom                     
                               adc SID_RANDOM                  
                               sta $be                  
                               //lda $be                  
                               and #$3f                     
                               sta SBsearchColorFlag     
                                  
!EXIT:                         rts                          
                                     
                                     
                                     
                                                         
// // Plot the wizard and start the magic lightning effect                           
WIZARD_AND_LIGHTNING:          jmp !START+                  
                                                         
!START:                        lda LightningDelayCounter    
                               ora LightningDelayCounter+1  
                               beq START_MAGIC              
                               rts				//internal jmp !EXIT+                   
                                                         
START_MAGIC:                   lda CAPTURE_WIZARD+2    
                               sta JumpConfigTable+1        
                               lda CAPTURE_WIZARD+1    
                               sta JumpConfigTable          
                               lda MAKE_LIGHTNING+2         
                               sta JUMP_1+2                 
                               lda MAKE_LIGHTNING+1         
                               sta JUMP_1+1                 
                               jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map01_zpw+1                 
                               lda $a0                      
                               sta map01_zpw                   
                               ldy map01_zpw+1			//ldy $ce                      
                               ldx map01_zpw                   
                               lda #$36                     	//wizard tiles
                               jsr PLOT_2X2                 
                               lda $fd                  
                               lsr                          
                               lsr                          
                               sta XcoordinateDivBy4        
                               ldy #$00                     
                               sty InitIndex_zp                      
// This is a copy of the lightning routine in $39e8.  This must just run through                           
// the loop of 5 lightning slots once to initialize the effect.                           
!LIGHTNING_SLOTS_LOOP:         lda #$04                     
                               cmp InitIndex_zp                      
                               bcs !MAKE_LIGHTNING+         
                               jmp !WRAP_UP+                
                                                         
!MAKE_LIGHTNING:               lda InitIndex_zp                      
                               asl                          
                               php                          
                               clc                          
                               adc ptrLightningTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrLightningTable+1  
                               sta $bf                  
                               //lda $bf                  
                               pha                          
                               lda $be                  
                               pha                          
                               jsr GET_SAFE_2X2             
                               pla                          
                               sta $be                  
                               pla                          
                               sta $bf                  
                               lda $a1                      
                               ldy #$01                     
                               sta ($be),y              
                               lda $a0                      
                               dey                          
                               sta ($be),y              
                               lda InitIndex_zp                      
                               asl                          
                               php                          
                               clc                          
                               adc ptrLightningTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrLightningTable+1  
                               sta $bf                  
                               iny                          
                               lda ($be),y              
                               sta $a2                      
                               dey                          
                               lda ($be),y              
                               sta $a1                      
                               ldy $a2                      
                               ldx $a1                      
                               lda #$48                     //lightning tiles
                               jsr PLOT_2X2                 
                               inc InitIndex_zp                      
                               jmp !LIGHTNING_SLOTS_LOOP-   //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!WRAP_UP:                      ldx #$3f                     
                               lda #$3f                     
                               jsr GET_RAND_LESS_THAN_X           
                               clc                          
                               lda #$1e                     
                               adc $a0                      
                               sta SBsearchColorFlag        
                               
!EXIT:                         rts                          
                                                        
                                                        
                                                        
                                                         
// End the magic lightning effect and restart the lightning holdoff/delay counter    
                       
MagicDelayPerLevelTable:       .byte $00                      // table of 16-bit delays between magic/lightning phases for each level
                               .byte $00                      // this is different than the init table. For example, the initial delay
                               .byte $94                      // for the second level is $09c4 (50sec) then it recycles at interval $1194 (90sec)
                               .byte $11                      
                               .byte $00                      
                               .byte $00                      
                               .byte $74                      
                               .byte $0e                      
                               .byte $8c                      
                               .byte $0a 
                                                    
ptrMagicDelayPerLevelTable:    .byte <MagicDelayPerLevelTable //$53                     
                               .byte >MagicDelayPerLevelTable //$3b
                                                     
                               .byte $c5                      
                               .byte $ff                      
                                                                                                                                         
END_MAGIC:                     jmp !START+                  // ********** this might be impacted by SMC
                                                         
!START:                        ldy #$00                     
                               sty InitIndex_zp                      
!ERASER_LOOP:                  lda #$04                     
                               cmp InitIndex_zp                      
                               bcs !GET_POINTERS+           
                               jmp !SET_JUMP_TABLE+         
                                                         
!GET_POINTERS:                 lda InitIndex_zp                      
                               asl                          
                               php                          
                               clc                          
                               adc ptrLightningTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrLightningTable+1  
                               sta $bf                  
                               ldy #$01                     
                               lda ($be),y              
                               sta $a1                      
                               dey                          
                               lda ($be),y              
                               sta $a0                      
                               ldx $a1                      
                               lda $a0                      
                               jsr ERASE_2X2                
                               inc InitIndex_zp                      
                               jmp !ERASER_LOOP-            //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!SET_JUMP_TABLE:               lda WIZARD_AND_LIGHTNING+2 
                               sta JUMP_1+2                 
                               lda WIZARD_AND_LIGHTNING+1 
                               sta JUMP_1+1
                               
                               // get lightning delay appropriate to each game level                 
test:                          lda GameLevel_gbl            
                               asl                          
                               php                          
                               clc                          
                               adc ptrMagicDelayPerLevelTable    
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc ptrMagicDelayPerLevelTable+1 
                               sta $bf
                                                 
                               ldy #$01                     
                               lda ($be),y              
                               sta LightningDelayCounter+1  
                               dey                          
                               lda ($be),y              
                               sta LightningDelayCounter 
                                  
                               sty SBsearchColorFlag        
                               rts                          
                                                         
!JMP_TO_END_MAGIC_EXIT:        jmp !EXIT_END_MAGIC+         // impacted by smc
                                                         
!EXIT_END_MAGIC:               rts                          
                                       
                                       
        
                                       
                                                         
// Handles teleportal behavior, relocating it according to different modes of                           
// operation for players and zombies                           
UPDATE_TELEPORTAL:             lda #$00                     
                               cmp PortalDelayCounter       
                               lda #$00                     
                               sbc PortalDelayCounter+1     
                               bcc !DECREMENT_DELAY+        
                               jmp !RELOCATE_PORTAL+        
                                                         
!DECREMENT_DELAY:              sec                          
                               lda PortalDelayCounter       
                               sbc #$01                     
                               sta PortalDelayCounter       
                               lda PortalDelayCounter+1     
                               sbc #$00                     
                               sta PortalDelayCounter+1     
                               rts				//internal jmp !EXIT+                   
                                                         
!RELOCATE_PORTAL:              clc                          
                               lda #$dc
                               //jsr GenRandom                     
                               adc SID_RANDOM                   
                               sta PortalDelayCounter       
                               lda #$05                     
                               adc #$00                     
                               sta PortalDelayCounter+1     
                               ldx TeleportalMapPtr+1       
                               lda TeleportalMapPtr         
                               jsr ERASE_2X2                
                               lda TeleportalState          
                               eor #$01                     
                               beq !CHECK_MODE1+            
                               jmp !CHECK_STATE+            
                                                         
!CHECK_MODE1:                  lda TeleportalMode           
                               beq !GET_TARGET_POINTERS+    
!CHECK_STATE:                  lda TeleportalState          
                               eor #$02                     
                               beq !CHECK_MODE2+            
                               jmp !RANDOM_MODE+            
                                                         
!CHECK_MODE2:                  lda TeleportalMode           
                               eor #$01                     
                               beq !GET_TARGET_POINTERS+    
                               jmp !RANDOM_MODE+            
                                                         
!GET_TARGET_POINTERS:          ldx TeleportalTargetY       
                               lda TeleportalTargetX       
                               jsr GET_TARGETED_2X2       // GET_SAFE, GET_TARGETED etc return the X,Y coordinates of the 2x2 block in $fd,$fc  
                               lda $a1                      
                               sta TeleportalMapPtr+1       
                               lda $a0                      
                               sta TeleportalMapPtr         
                               ldy #$00                     
                               sty TeleportalState          
                               jmp !TARGETED_MODE+          
                                                         
!RANDOM_MODE:                  jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta TeleportalMapPtr+1       
                               lda $a0                      
                               sta TeleportalMapPtr
                                        
!TARGETED_MODE:                lda $fd                  // GET_SAFE, GET_TARGETED etc return the X,Y coordinates of the 2x2 block in $fd,$fc
                               sta TeleportalX              
                               lda $fc                  
                               sta TeleportalY  
                                           
                               ldy TeleportalMapPtr+1       // plot it
                               ldx TeleportalMapPtr         
                               lda #$cc                     
                               jsr PLOT_2X2                 
                               lda TeleportalMode           
                               eor #$01                     
                               beq !END_MODE_1+             
                               jmp !END_OTHER_MODES+        
                                                         
!END_MODE_1:                   lda #$02                     
                               sta TeleportalMode           // this triggers block0 to call move_player_to_teleportal_exit
                               lda #$1e                     
                               sta SoundEffectQueue         
                               ldy #$00                     
                               sty TeleportalState          
                               rts				//internal jmp !EXIT+                   
                                                         
!END_OTHER_MODES:              ldy #$00                     
                               sty TeleportalMode           
                               lda #$1d                     
                               sta SoundEffectQueue 
                                       
!EXIT:                         rts                          
            
            
            
            
                                                         
// Main procedure for levels of type where objects are collected                           
// Levels 1, 3, 4  (not 0, 2)                            
                               .byte $3b                      
                               .byte $ad                      
                               .byte $6c                      
                                                         
LEVELS134:                     jmp !START+                  
                                                         
!START:                        jsr JUMP_1                   // this jump does 1 of 4 things: (init) WIZARD_AND_LIGHTNING, (sustain) MAKE_LIGHTNING, (terminate) END_MAGIC, or just (nothing) RTS. 
                               jsr UPDATE_TELEPORTAL        
                               lda CombinedTasksComplete    
                               eor NumberOfTasksRemaining    
                               beq !START_END_PHASE+        
                               jmp !CHK_ENEMY_DIAMOND+      
                                                         
!START_END_PHASE:              lda LevelEndFlag             
                               beq !PLACE_DOOR+             
                               jmp !CHK_ENEMY_DIAMOND+      
                                                         
!PLACE_DOOR:                   lda #$10                     
                               sta SoundEffectQueue         
                               jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map2_zpw+1                 
                               lda $a0                      
                               sta map2_zpw                   
                               ldy map2_zpw+1                      
                               ldx map2_zpw                   
                               lda #$c0                     
                               jsr PLOT_2X2                 
                               lda $fd                  //door search
                               lsr                          
                               lsr                          
                               sta XcoordinateDivBy4        
                               ldy #$01                     
                               sty LevelEndFlag             
                               lda #$30 //#$30                     
                               jsr PLOT_1_ON_FLOOR          //place first key
                               lda #$30 //#$30                     
                               jsr PLOT_1_ON_FLOOR          //place second key

				// configure jump tables for this level                           
                               lda END_LEVEL_PHASE+2        
                               sta JumpConfigTable+1        
                               lda END_LEVEL_PHASE+1        
                               sta JumpConfigTable          
                               lda INTERACT_ENEMY_LVLS02+2  
                               sta JumpConfigTable+3        
                               lda INTERACT_ENEMY_LVLS02+1  
                               sta JumpConfigTable+2        
                               
				// reset tasks and inventories and turn off magic mechanics                           
                               lda #$03                     
                               jsr INIT_PLAYER_INVENTORIES  
                               lda !JMP_TO_END_MAGIC_EXIT- +2 
                               sta JUMP_1+2                 
                               lda !JMP_TO_END_MAGIC_EXIT- +1 
                               sta JUMP_1+1                 
                               
// Section below is pretty convoluted.  The jump tables are handling what game                           
// mechanics need to be serviced.  That is, for levels 0 and 2                           
// INTERACT_ENEMY_LVLS02 (which implements attacks and stealing of candles,                           
// stones which player can only carry one at a time) and HANDLE_TASKS_LVLS02                           
// (implements picking up single objects and using them to activate other                           
// objects) are called.  Similarly for levels 1, 3, and 4, INTERACT_ENEMY_LVLS134                           
// (implements attacks and stealing of diamonds which player can carry multiple),                           
// HANDLE_TASKS_LVLS134 (implements picking up multiple objects), and START_MAGIC                           
// (implements wizard lighnting phase) are called. This code has to manage                           
// both scenarios so looks at jump table to figure out what is going on, which I                           
// guess is faster than a CASE statement where you need to look at (0,2) vs                           
// (1,3,4) in the GameLevel register.                           

!CHK_ENEMY_DIAMOND:            lda enemyInventory           
                               eor #$0a                     
                               beq !DROP_STOLEN_DIAMOND+    
                               jmp !CHECK_ENEMY_CANDLE+     
                                                         
!DROP_STOLEN_DIAMOND:          jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map2_zpw+1                 
                               lda $a0                      
                               sta map2_zpw                   
                               ldy map2_zpw+1                 
                               ldx map2_zpw                   
                               lda #$b2                     
                               jsr PLOT_2X2                 
                               ldy #$00                     
                               sty enemyInventory           
                               jmp !WHICH_LVL_MECHANICS+    
                                                         
!CHECK_ENEMY_CANDLE:           lda #$00                     
                               cmp enemyInventory           
                               bcc !DROP_STOLEN_CANDLE+     
                               jmp !WHICH_LVL_MECHANICS+    
                                                         
!DROP_STOLEN_CANDLE:           ldx enemyInventory           
                               lda functionalTileTable,x      // getting whether the enemy has a key or a candle that needs to be dropped. the first entry 0 = blank space/nothing
                               sta $a0                      
                               //lda $a0                      
                               jsr PLOT_1_ON_FLOOR          
                               ldy #$00                     
                               sty enemyInventory
                                          
!WHICH_LVL_MECHANICS:          lda JumpConfigTable          
                               eor HANDLE_TASKS_LVLS134+1   
                               bne !PASS_THROUGH+           
                               ora JumpConfigTable+1        
                               eor HANDLE_TASKS_LVLS134+2   
!PASS_THROUGH:                 beq !DIAMOND_COLLECTION+     
                               jmp !CHECK_TRAP_TRIGGERED+   
                                                         
!DIAMOND_COLLECTION:           lda HasDiamond               
                               beq !CHECK_NEED_DIAMOND+     
                               jmp !CHECK_TRAP_TRIGGERED+   
                                                         
!CHECK_NEED_DIAMOND:           lda NumberOfTasksObjectsOnMap    
                               cmp NumberOfTasksRemaining    
                               bcc !DIAMOND_TO_MAP+         	// put a diamond back on the map if there are not enough there to complete level, branch if NumberOfTaskObjectsOnMap < NumberOfTasksToComplete
                               jmp !CHECK_TRAP_TRIGGERED+   
                                                         
!DIAMOND_TO_MAP:               jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map2_zpw+1                 
                               lda $a0                      
                               sta map2_zpw                   
                               ldy map2_zpw+1                 
                               ldx map2_zpw                   
                               lda #$b2                     
                               jsr PLOT_2X2                 
                               inc NumberOfTasksObjectsOnMap    
                               ldy #$01                     	// remove diamond from inventory
                               sty HasDiamond   
                                           
!CHECK_TRAP_TRIGGERED:         lda TrapState                
                               eor #$01                     
                               beq !CHECK_ANIM_START_PHASE+  
                               jmp !CHECK_TRAP_STATE+       
                                                         
!CHECK_ANIM_START_PHASE:       lda animCtr_zp 	//CharsetBase              
                               eor #$00  	//#$60                     
                               beq !PLOT_TRAP_OPEN+         
                               jmp !CHECK_TRAP_STATE+       
                                                         
!PLOT_TRAP_OPEN:               ldy AnimationLocationPtr+1   
                               ldx AnimationLocationPtr     
                               lda #$2c		//$ac         // $ac is in the second half so colors are transposed, change to #$2c but may cause a retrigger?
                               jsr PLOT_2X2                 
                               lda #$02                     
                               sta TrapState                
                               lda #$6e                     
                               sta TrapAnimationCounter     
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_TRAP_STATE:             lda TrapState                
                               eor #$02                     
                               beq !CHECK_ANIMATION_TIMER+  
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_ANIMATION_TIMER:        lda #$00                     
                               cmp TrapAnimationCounter     
                               bcc !DECREMENT_ANIMATION_TIMER+  
                               jmp !CHECK_ANIM_END_PHASE+   
                                                         
!DECREMENT_ANIMATION_TIMER:    sec                          
                               lda TrapAnimationCounter     
                               sbc #$01                     
                               sta TrapAnimationCounter     
                               rts				//internal jmp !EXIT+                   
                                                         
!CHECK_ANIM_END_PHASE:         lda animCtr_zp 	//CharsetBase              
                               eor #$00		//#$60                     
                               beq !RESET_TRAP+             
                               rts				//internal jmp !EXIT+                   
                                                         
!RESET_TRAP:                   ldx AnimationLocationPtr+1   
                               lda AnimationLocationPtr     
                               jsr ERASE_2X2                
                               jsr PLACE_A_TRAP_ON_MAP      
                               ldy #$00                     
                               sty TrapState                
                               lda #$0f                     
                               sta SoundEffectQueue  
                                      
!EXIT:                         rts                          
              
              
              
              
              
              
              
                                                         
TrapsPerLevelTbl:              .byte $08                      
                               .byte $0c                      
                               .byte $11                      
                               .byte $13                      
                               .byte $16
                                                     
PotionsPerLevelTbl:            .byte $04                      
                               .byte $04                      
                               .byte $03                      
                               .byte $03                      
                               .byte $01
                                                     
InitMagicDelayTable:           .byte $00                      
                               .byte $00                      
                               .byte $c4                      
                               .byte $09                      
                               .byte $00                      
                               .byte $00                      
                               .byte $d0                      
                               .byte $07                      
                               .byte $dc                      
                               .byte $05
                                                     
PtrInitMagicDelayTable:        .byte <InitMagicDelayTable	//$05                      
                               .byte >InitMagicDelayTable	//$3e
                                                     
                               .byte $00                      
                               .byte $8d                      
                                                         
POPULATE_MAP:                  //jmp !START+                  
                                                         
!START:                        lda #$00                     
                               sta NumberDiamonds           
                               lda #$00                     
                               sta NumberDiamonds+1         
                               lda #$00                     
                               sta ZombieDelay              
                               lda #$00                     
                               sta ZombieDelay+1            
                               ldy #$00                     
                               sty TrapState                
                               sty LevelEndFlag             
                               sty CombinedTasksComplete    
                               sty enemyInventory           
                               sty TeleportalMode           
                               sty TeleportalState          
                               sty SBsearchColorFlag        
                               lda #$fa                     
                               sta LifeForceDecDelay        
                               lda #$ff                     
                               sta SoundEffectQueue         
                               lda END_MAGIC+2              
                               sta JUMP_4+2                 
                               lda END_MAGIC+1              
                               sta JUMP_4+1
                                                
                               lda NumPlayers                    // 1 player mode has NumPlayers = 1
                               eor #$01                     
                               beq !ONE_PLAYER+             
                               jmp !TWO_PLAYERS_COOP+       
                                                         
!ONE_PLAYER:                   lda #$06                     
                               sta NumberOfTasksRemaining    
                               jmp !PRESERVE_TASK_NUM+      
                                                         
!TWO_PLAYERS_COOP:             lda #$08                     
                               sta NumberOfTasksRemaining 
                                  
!PRESERVE_TASK_NUM:            lda GameLevel_gbl            
                               beq !LEVEL2+                 
                               lda GameLevel_gbl            
                               eor #$02                     
                               beq !LEVEL2+                 
                               jmp !CONFIG_JUMPS+           
                                                         
!LEVEL2:                       lda HANDLE_TASKS_LVLS02+2    
                               sta JumpConfigTable+1        
                               lda HANDLE_TASKS_LVLS02+1    
                               sta JumpConfigTable          
                               lda INTERACT_ENEMY_LVLS02+2  
                               sta JumpConfigTable+3        
                               lda INTERACT_ENEMY_LVLS02+1  
                               sta JumpConfigTable+2        
                               lda NumberOfTasksRemaining    
                               sta NumberOfTasksObjectsOnMap    
                               lda !JMP_TO_END_MAGIC_EXIT- +2 
                               sta JUMP_1+2                 
                               lda !JMP_TO_END_MAGIC_EXIT- +1 
                               sta JUMP_1+1
                                                
                               ldy #$00                     
                               sty InitIndex_zp                      
                               lda NumberOfTasksRemaining    
                               sta !numCandlesToPlace+      
!LOOP1:                        lda !numCandlesToPlace+      
                               cmp InitIndex_zp                      
                               bcs !PLOT_CANDLE+            
                               jmp !INIT_LANTERNS+          
                                                         
!numCandlesToPlace:            .byte $08                      
                                                         
!PLOT_CANDLE:                  lda #$31                     
                               jsr PLOT_1_ON_FLOOR          
                               inc InitIndex_zp                      
                               jmp !LOOP1-                  //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!INIT_LANTERNS:                ldy #$01                     
                               sty InitIndex_zp                      
                               lda NumberOfTasksRemaining    
                               sta !numLanternsToPlace+     
!LOOP2:                        lda !numLanternsToPlace+     
                               cmp InitIndex_zp                      
                               bcs !PLACE_LANTERNS+         
                               jmp !NEXT+                   
                                                         
!numLanternsToPlace:           .byte $08                      
                                                         
!PLACE_LANTERNS:               jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map01_zpw+1                      
                               lda $a0                      
                               sta map01_zpw                   
                               ldx GameLevel_gbl            
                               lda unlitLanternTbl,x        
                               sta $a0                      
                               ldy map01_zpw+1                 
                               ldx map01_zpw                   
                               lda $a0                      
                               jsr PLOT_2X2                 
                               inc InitIndex_zp                      
                               jmp !LOOP2-                  //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!NEXT:                         jmp !PLACE_TRAPS+            
                                                         
!CONFIG_JUMPS:                 lda HANDLE_TASKS_LVLS134+2   
                               sta JumpConfigTable+1        
                               lda HANDLE_TASKS_LVLS134+1   
                               sta JumpConfigTable          
                               lda INTERACT_ENEMY_LVLS134+2 
                               sta JumpConfigTable+3        
                               lda INTERACT_ENEMY_LVLS134+1 
                               sta JumpConfigTable+2   
                                    
                               ldy #$01                     			// I don't understand this part
                               sty HasDiamond               			// 0=carrying a diamond
                               lda #$04                     
                               sta NumberOfTasksObjectsOnMap    			//*************why, this should be 8 or 6?

                               lda WIZARD_AND_LIGHTNING+2 
                               sta JUMP_1+2                 
                               lda WIZARD_AND_LIGHTNING+1 
                               sta JUMP_1+1                 
                               lda GameLevel_gbl            
                               asl                          
                               php                          
                               clc                          
                               adc PtrInitMagicDelayTable      
                               sta $be                  
                               lda #$00                     
                               rol                          
                               plp                          
                               adc PtrInitMagicDelayTable+1    
                               sta $bf                  
                               lda ($be),y              
                               sta LightningDelayCounter+1  
                               dey                          
                               lda ($be),y              
                               sta LightningDelayCounter    
                               iny                          
                               sty InitIndex_zp                      
!LOOP3:                        lda #$04                     
                               cmp InitIndex_zp                      
                               bcs !PLACE_LANTERNS2+        
                               jmp !PLACE_TRAPS+            
                                                         
!PLACE_LANTERNS2:              jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta map01_zpw+1                 
                               lda $a0                      
                               sta map01_zpw                   
                               ldx GameLevel_gbl            
                               lda unlitLanternTbl,x        
                               sta $a0                      
                               ldy map01_zpw+1                 
                               ldx map01_zpw                   
                               lda $a0                      
                               jsr PLOT_2X2                 
                               inc InitIndex_zp                      
                               jmp !LOOP3-                  //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!PLACE_TRAPS:                  ldy #$00                     
                               sty InitIndex_zp                      
                               ldx GameLevel_gbl            
                               lda TrapsPerLevelTbl,x       
                               sta !numTrapsToPlace+        
!LOOP4:                        lda !numTrapsToPlace+        
                               cmp InitIndex_zp                      
                               bcs !PLOT_TRAPS+             
                               jmp !NEXT2+                  
                                                         
!numTrapsToPlace:              .byte $08                      
                                                         
!PLOT_TRAPS:                   jsr PLACE_A_TRAP_ON_MAP      
                               inc InitIndex_zp                      
                               jmp !LOOP4-                  //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!NEXT2:                        ldy #$00                     
                               sty InitIndex_zp                      
                               ldx GameLevel_gbl            
                               lda PotionsPerLevelTbl,x     
                               sta !numPotionsToPlace+      
!LOOP5:                        lda !numPotionsToPlace+      
                               cmp InitIndex_zp                      
                               bcs !PLOT_POTIONS+           
                               jmp !PLOT_TELEPORTAL+        
                                                         
!numPotionsToPlace:            .byte $04                      
                                                         
!PLOT_POTIONS:                 lda #$2a                     
                               jsr PLOT_1_ON_FLOOR          
                               inc InitIndex_zp                      
                               jmp !LOOP5-                  //******** WARNING CHECK LOCAL LABELS +/- ********
                                                         
!PLOT_TELEPORTAL:              lda #$05                     
                               sta PortalDelayCounter+1     
                               lda #$dc                     
                               sta PortalDelayCounter       
                               jsr GET_SAFE_2X2             
                               lda $a1                      
                               sta TeleportalMapPtr+1       
                               lda $a0                      
                               sta TeleportalMapPtr         
                               ldy TeleportalMapPtr+1       
                               ldx TeleportalMapPtr         
                               lda #$cc & $7f  // portal upper bit set?                   
                               jsr PLOT_2X2                 
                               lda #$00                     
                               jsr INIT_PLAYER_INVENTORIES  
                               rts                          
                                                         
                               jmp !EXIT+                   
                                                         
!EXIT:                         rts           

               
                               //.adrend  $26c0                
