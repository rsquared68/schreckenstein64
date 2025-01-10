
//	2022-10-24	Some cleanup to catch up with changes from past month
//	2023-12-06	Changes to reflect deconfliction of inside/outside irq with new temp0-5 and mathTemp labels
//	2024-01-05	added fxIteration3_zp
//	2024-11-17	irq PlayerIndex deconfliction, new sound architecture

//............................................definitions of zeropage segment................................................
.zp {
// $00,$01 processor port and DDR
// $02,$03 CASINI vector may be used
// $02 used by rng
.label rng_zp_low 	= $02		// this can be freed up not using the GenRandom routine anymore
.label rng_zp_high 	= $03
.label Random 		= $03 
.label NumOfPlayersPtr_zpw = $04	// $04,$05 pointer to $607
.label PORTA 		= $06
// $07,$08 pointer to sprite shape data used by blit routine
.label BlankStrips_zp 	= $09

// 			  $0a, $0b DOSVEC pointer used by $80ef SET_ENEMY_VARS_POINTED
// 			  $0c, $0d DOSINI pointer

.label animCtr_zp  	= $0f		// counter for charset animation
// 			  $10 POKMSK used by Atari keyboard routines
.label frameCtr_zp 	= $10
// 			  $11 counter index used by SET_ENEMY_VARS_POINTED

.label pauseKey_zp	= $18		// key status for game pause
.label state_zp		= $19		// used to determine which viewport to blit/update on a given frame

//.label zpBase 	= $30 		// $30-$2b used by covertbitops loader code external to all this

// new architecture sound stack
.label SoundStack_zp	= $60
.const SoundStackDepth	= 6		// sound queue maximum depth

// $82-$85 used by $80ef SET_ENEMY_VARS_POINTED

// $a0-$a5 temporary variables used for computation and parameter passing OUTSIDE IRQ handlers--possible that $a4,5 are actually now unused

// temporary variables used for computation and parameter passing INSIDE IRQ handlers
.label temp0 		= $a6		//temp variable and used to pass parameters between routines only in this block
.label temp1 		= $a7		//temp variable and used to pass parameters between routines only in this block
.label temp2 		= $a8		//temp variable
.label temp3 		= $a9		//temp, mine
.label temp4 		= $aa		//used to pass address in combination with temp3
.label temp5 		= $ab		//used to pass address in combination with temp4

// $ac,d $ae,f pointers used for address base+offset computation etc.

// $b0-$bf unused in Atari
.label mathTemp0 	= $b0		//deconflict $82-$85 with use by UPDATE_ENEMY_VARS called by block1 from outside irq
.label mathTemp1 	= $b1		//these two are used in block0 for math in coordinate computation, and to pass parameters to ASL_A_INTO_X now moved to block2

.label ZombieOffset1_zp		= $b6
.label ZombieOffset2_zp		= $b7

// $be heavily used as temporary variable in block1

// $c0-$c7 used by full Atari code but not by what i've tested, not sure if free

// old/new architectures common sound registers
.label 	soundPlaying1_zp 	= $c0	// could use nybbles for these 4
.label 	soundPlaying2_zp 	= $c1
.label	fxIteration1_zp 	= $c2
.label  fxIteration2_zp 	= $c3
.label	fxIteration3_zp 	= $c4
.label	Voice1StreamPtr_zpw 	= $c5 //,$c6
.label  Voice2StreamPtr_zpw 	= $c7 //,$c8
// new architecture sound registers
.label SoundStackPtr_zp 	= $c9
.label stepSound_zp    		= $ca	                      
.label p1Sound_zp		= $cb	//in original game, one-hot encoding for certain sounds. Now plays enumerated sound on voice 1 (for player 1)                        
.label p2Sound_zp	        = $cc   //in original game, certain sequential enumerated sounds. Now plays enumerated sound on voice 2 (for player 2)                    

// map and other pointers
.label map0_zpw		      	= $cd                      
.label map1_zpw                 = $cf                      
				//$d0               
.label ViewportCoordinateBase_zpw = $d1                      
.label PlayerCoordBase_zpw      = $d3                      
.label PlayerSpriteCtrlBase_zpw = $d5                      
.label SpriteHPOS_zp           	= $d7
.label OpponentInView_zp	= $d8	// might be HPOS msb?                          
.label SpriteVPOS_zpw          	= $d9                 
.label PlayerIndex_zp          	= $db                  
.label map2_zpw                	= $dc                      
.label map3_zpw                 = $de
                      		//$df
.label EnemyIndex_zp           	= $e0    
.label p1StatusColor_zp        	= $e1
.label p2StatusColor_zp        	= $e2
// $e3-$ef unused in Atari
.label map01_zpw		= $e3    // added these into block 1 to prevent irq/non-irq conflict                  
.label map11_zpw                = $e5    

// $eb used to isolate $db (player index) that might be clobbered by irq
.label PlayerIndexIRQ_zp	= $eb	// instance of PlayerIndex that used exculsively by routines called from the irq for motion
					// (block0, ai-motion-indep-irq, player-moves)

// $f0-$f2 temp variables for animation, sound, and motion control of player and views
.label AiControlMask_zp		= $f2	// only used in AI control routines
.label Joystick_zp		= $f3
.label NonMoveAnimState_zp	= $f4	// control register for animations like teleport, stun, death where player can't move

// $f5-$f8 calculation temp variables; joystick triggers also in $f5
// $f9-$fb unused
.label Player1JoystickMask_zp	= $f9	// new joystick mask scheme to better support the way AI stuffs joystick values
.label Player2JoystickMask_zp	= $fa
// $fc-$ff pointers state registers

.label InitIndex_zp		= $ff	// index for map object initialization loops (enemies, objects)
}

// $200-$2ff disk load buffer

.label HighScore	       	= $0300	//, 01		 in original game this is at $b12a,b but I will just put it here with the other originally obfuscated scoring stuff
// in the orginal game these are at $60x, but they are in the middle of my screen storage at $400
.label NumPlayers	       	= $0307
.label L0609                   	= $0309			//I believe this was part of some copy protection removed by Homesoft in the version I worked from
.label L060d		       	= $030d //, 0e		//player 1 16-bit score
.label L060f		       	= $030f //, 10		//player 2 16-bit score
.label L0611		       	= $0311 //, 12		//pointer to score


// used for blocks of screen data storage
.label	castlePicStore 		= $0400
.label	castleColorStore 	= $cc00
.label  atariAlphas 		= $6000


// used globally to init
.label View1CoordBase	       = $8004
.label View2CoordBase	       = $800a

// THESE ARE LOCAL VARIABLES AND ALL SHOULD BE MOVED TO THE START OF BLOCK 2
.label ptrViewYCoordSelect     = $8014
.label Player1SpriteShape      = $8026

.label Player2SpriteShape      = $8030
                    
.label ptrCoordBaseSelect      = $8046                    
.label ptrAnimBaseSelect       = $804e                    
.label SpriteShapeTable        = $805c                    
.label ShapeTablePtrMsb        = $805d                    
.label HPOS_P1_IN_V1           = $8060                    
.label ptrSpriteHPOS_player1   = $8064                    
.label ptrSpriteHPOS_player2   = $8066                    
.label charsetMask             = $8069     // was called charsetBase      
.label GameLevel_gbl           = $806a                    
.label LoadLevelTrigger        = $806b                    
.label CombinedTasksComplete   = $806c
.label GamePauseRegister       = $806d                    
.label PlayerLifeForce         = $806e                    
.label PlayerControlMode       = $8070                    
.label TryingToMoveFlag        = $8072                    
.label PlayerCanClimbFlag      = $8074                    
.label PlayerTileXcoordinate   = $8076      // also p1TileX              
.label PlayerTileYcoordinate   = $8078      // also p1TileY              
.label PlayerDelayCountdown    = $807a                    
.label NonMoveAnimSeq          = $807c                    
.label PlayerShapeSelect       = $807e
.label StunDelay               = $8080
.label PlayerJoystickBits      = $8082                    
.label PlayerJoyTrigger        = $8084                    
.label TeleportalMode          = $8086                    
.label TeleportalX             = $8087                    
.label TeleportalY             = $8088                    
.label TeleportalState         = $8089                        
.label TeleportalTargetX       = $808a                    
.label TeleportalTargetY       = $808b                      
                                      
   
.label YtoMapLsbTbl            = $9200                    
.label YtoMapMsbTbl            = $9240                    
.label EnemyXarray             = $9300                    
.label EnemyYarray             = $9340                    
.label EnemyStateRegArray      = $9380                    
.label EnemySubstrateIndexTbl  = $93c0     

.label HPOSP0_ATARI            = $d000                    
.label HPOSP2_ATARI            = $d002                    
.label HPOSP3_ATARI            = $d003                    
.label TRIG0_ATARI             = $d010                    
//.label SKREST_ATARI            = $d20a

.label SID_RANDOM	       = $d41b                   
