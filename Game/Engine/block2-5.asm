//  block2_8000-8148.bin.csv translated from SourceGen with kickass-translate.py v0.1
//
//	Implement helper subroutines
//
//	This file contains data and instructions disassembled and reverse-engineered from the binary
//	of the original Schreckenstein game found at memory locations $8000-$8148, implementing
//	helper functions for the main program.  Portions have been deleted, rewritten, or modified to
//	accomodate the C64 hardware and the structure of the port to that platform.  The majority
//	of the code in this block was written by Peter Finzel, and is used here with his written
//	permission.
//

//  *****WARNING:  MULTI-LABELS MAY NOT ALWAYS BE RESOLVED CORRECTLY, PLEASE CHECK MANUALLY
//
//  *****WARNING:  MUST MANUALLY SET ZEROPAGE LABELS WITH .zp { }


// 6502bench SourceGen v1.8.5-dev1                           
//.label Random                  = $03 	// atari $d20a                    
//.label PORTA                   = $d300                    


// ===================================================================================================================
//	Data structures with variables defining the player, graphics rendering, and game state
// ===================================================================================================================                                                  
                               //.pc = $8000                    
                               .byte $3d                      
                               .byte $5b                      
                               .byte $20                      
                               .byte $31
                               
                               // View1CoordinateBase, structure containing viewport positioning variables                      
v1Ypos16:                      .byte $00	// View1CoordinateBase                      
                               .byte $00                      
v1Xpos16:                      .byte $0f                      
                               .byte $00                      
v1CoarseY:                     .byte $55                     
v1CoarseX:                     .byte $51                      
v2Ypos16:                      .byte $00                      
                               .byte $00                      
v2Xpos16:                      .byte $0f                    
                               .byte $00                      
v2CoarseY:                     .byte $57                     
v2CoarseX:                     .byte $53                      
                               .byte $04        //addr pointer to $8004 = v1Ypos16              
                               .byte $80                      
                               .byte $0a    	//addr pointer to $800a = v2Ypos16                 
                               .byte $80                      
                               .byte $10  	//addr pointer to $8010                   
                               .byte $80  	                    
                               .byte $1c                      
                               .byte $00                      
v1ScrollX:                     .byte $03                      
v2ScrollX:                     .byte $03                      
v1ScrollY:                     .byte $00                      
v2ScrollY:                     .byte $00                      
                               .byte $18  	//addr pointer to $8018 = v1ScrollX             
                               .byte $80                      
                               .byte $1a 	//addr pointer to $801a = v1ScrollY                     
                               .byte $80
                               
                               // Player1CoordBase, player positions and some sprite shape registers                      
p1Xpos16:                      .byte $32+8     //+8 to prevent view-player underflow             
                               .byte $00                      
p1Ypos16:                      .byte $2d                      
	                       .byte $00                      
p1VposV1:                      .byte $79     	//               
                               .byte $00                      
                               .byte $00                      
                               .byte $75                      
                               .byte $00                      
                               .byte $00                      
p2Xpos16:                      .byte $32+$30+8                     
                               .byte $00                      
p2Ypos16:                      .byte $2d                     
                               .byte $00                      
p2VposV2:                      .byte $d9-$60    //not sure if OK to put here         $802e       $60 is offset from top of screen 
                               .byte $00                      
                               .byte $00 //$02         player 2 sprite shape in my code, not used by atari?             
                               .byte $7e                      
                               .byte $00                      
                               .byte $00
                               
                               // Player1AnimBase, data structure related to sprite positioning and animation control                      
                               .byte $00                     
                               .byte $00                      
                               .byte $c8                      
                               .byte $79                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $08                      
                               .byte $08                      
                               .byte $02                      
                               .byte $02                      
                               .byte $00                      
                               .byte $03                      
                               .byte $00                      
                               .byte $20    // addr pointer to $8020 = p1Xpos16                  
                               .byte $80                      
                               .byte $2a    // addr pointer to $802a = p2Xpos16                  
                               .byte $80                      
                               .byte $42                      
                               .byte $80                      
                               .byte $00                      
                               .byte $00                      
                               .byte $34                      
                               .byte $80                      
                               .byte $3b                      
                               .byte $80                      
                               .byte $4a                      
                               .byte $80                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $94                      
                               .byte $00                      
                               .byte $95                      
                               .byte $00                      
                               .byte $96                      
                               .byte $00                      
                               .byte $97                      
                               .byte $00                      
                               .byte $00                      
                               .byte $52     	//addr pointer to $8052                 
                               .byte $80                      
                               .byte $5a   	//addr pointer to $805a                   
                               .byte $80                      
 p1HposV1:                     .byte $3e              
 p2HposV2:                     .byte $6e                     
 p2HposV1:                     .byte $93                      
 p1HposV2:                     .byte $53                      
                               .byte $60        // addr pointer to $8060 = p1HposV1              
                               .byte $80                      
                               .byte $62        // addr pointer to $8062 = p2HposV1              
                               .byte $80
                               
                               // Start of player status, map, input, motion control etc. variables                      
                               .byte $04                      
                               .byte $60                      
                               .byte $05                      
                               .byte $01                      
                               .byte $00                      
                               .byte $00                      
                               .byte $64		//b2 life force                      
                               .byte $64		//b7                      
                               .byte $00                      
                               .byte $00                      
                               .byte $01                      
                               .byte $01                      
                               .byte $00                      
                               .byte $00
                                                     
                               .byte $0c        // p1 tile X single byte coordinates for player tile position in map x=0-127, y=0=63              
                               .byte $1c	// p2 tile X                      
                               .byte $06     	// p1 tile Y                 
                               .byte $06	// p2 tile Y
                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $00                      
                               .byte $09                      
                               .byte $09                      
                               .byte $00                      
                               .byte $1d                      
     		               .byte $0f         //p1 joy dir             
                     	       .byte $0f         //p2 joy dir             
                     	       .byte $01         //p1 trigger             
                 	       .byte $01         //p2 trigger             
                               .byte $00                      
                               .byte $56                      
                               .byte $06                      
                               .byte $00                      
                               .byte $86                      
                               .byte $a1                      
                                            
// ===================================================================================================================                                            
                                            
 
 
// =================================================================================================================== 
//	Various support routines
// ===================================================================================================================
                                                         
// writes the temp variable $a3 to whatever is pointed to by A lsb, X msb from                           
// offset in Y down to Y=0                               
WRITE_A3_TO_AX_LENGTH_Y:       sta $a0                      
                               stx $a1                      
                               lda $a3                      
!LOOP:                         dey                          
                               sta ($a0),y                  
                               bne !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                               rts                          
                                                         
// Copies from address pointed to by lo/hi pair (Y,$a3) to address pointed to by                           
// lo/hi pair (A,X) over a range passed in $a4                           
COPY_YA3_TO_AX_LENGTH_A4:      sta $a0                      // this is used to write the score to the screen among other things
                               stx $a1                      
                               sty $a2                      
                               ldy $a4                      
!LOOP:                         dey                          
                               lda ($a2),y                  
                               sta ($a0),y                  
                               cpy #$00                     
                               bne !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                               rts                          
                                                         
// Stores (#$00, X) to ($a0, $a1)                           
STORE_00X_TO_A0A1:             tax                          
                               lda #$00                     
                               sta $a0                      
                               stx $a1                      
                               rts                          
                                                         
// Checks whether A is inside the range [X,Y]. If true return $a0=X=1, else                           
// $a0=X=0                                               
CHECK_A_BETWEEN_XY:            stx $a1                      
                               ldx #$01                     
                               cmp $a1                      
                               bcc !A_OUTSIDE_RANGE+        //branch returning 0 if A < $a1 = X
                               sta $a0                      
                               cpy $a0                      
                               bcc !A_OUTSIDE_RANGE+        //branch returning 0 if Y < $a0 = A --> A > Y
                               stx $a0                      // else return 1
!SUCCESS:                      rts                          //internal jump   and exit
                                                         
!A_OUTSIDE_RANGE:              dex                          
                               stx $a0                      // return 0
                               rts                          // end exit
                                                         
// generates a random number according to a bitmask in A that is less than a                           
// parameter in X                                        
// Only used outside of irq handler by block1 (ensure this!)
GET_RAND_LESS_THAN_X:          
			       //and SID_RANDOM
			       sta $a0			// store bitmask from A
			       jsr GenRandom		// returns one random byte in A
			       and $a0                  
                               sta $a0                      
                               cpx $a0                      
                               bcc GET_RAND_LESS_THAN_X     
                               rts                          

/*  // not used                                                       
// LSR contents of X into A a number of times given by value of $84                                                   
LSR_X_INTO_A:                  ldy $84                      
                               beq !EXIT+                   //quit if $84 contains 0
                               stx $85                      
!LOOP:                         lsr $85                      
                               ror                          
                               dey                          
                               bne !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                               ldx $85                      
!EXIT:                         rts                          
*/

/*    // moved into block0 (only thing that uses this routine) to deconflict $84,5 with UPDATE_ENEMY_VARS                                                     
// ASL contents of A into X a number of times given by value in $84                                                     
ASL_A_INTO_X:                  ldy $84                      
                               beq !EXIT+                   
                               stx $85                      
!LOOP:                         asl                          
                               rol $85                      
                               dey                          
                               bne !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                               ldx $85                      
!EXIT:                         rts                          
*/


                                                         
// Routine that updates 1,2, or 3 of a routine's local enemy variables based on                           
// the contents of the CPU registers and a selector byte.                           
// Parameters in A,X,Y and 3 bytes immediately following the jsr XXXX to this                           
// routine.                                              
//                                                       
//  The 3 bytes are:                                     
//                                                       
//      A lsb,msb pointer to where the x-coordinate variable byte is stored                           
// locally, assuming the y-coordinate byte immediately follows it in memory                           
//                                                       
//     A byte selecting how many of the parameters are to be updated. 0=just x                           
// (from A), 1=x and y (from A,X), 2= x,y,substrate (from A,X,Y)                           
//                                                       
// Also checks break key and handles restart lol                           
// RTS returns 3 bytes *past* the original stack return address                           
UPDATE_ENEMY_VARS:	       sta $a0                      
                               stx $a1                      
                               sty $a2                      
                               clc                          
                               pla                          
                               sta $84                      
                               adc #$03                     
                               tay                          
                               pla                          
                               sta $85                      
                               adc #$00                     
                               pha                          
                               tya                          
                               pha                          
                               ldy #$01                     
                               lda ($84),y                  
                               sta $82                      
                               iny                          
                               lda ($84),y                  
                               sta $83                      
                               iny                          
                               lda ($84),y                  
                               tay                          
!LOOP:                         lda $a0,y            //+++ word to zp      
                               sta ($82),y                  
                               dey                          
                               bpl !LOOP-                   //******** WARNING CHECK LOCAL LABELS +/- ********
                               lda $11                      
                               bne !EXIT+                   
                               inc $11                      
//                             jmp ($000a)                 // DOSVEC  
                                                         
!EXIT:                         rts                          

