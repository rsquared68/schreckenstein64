/* noter for schreck prerelease 

	2023-11-29	v2 added load of sound effect wavetables
	2023-12-20	refactor for proper start/end screen, manually corrected castle colormap
	2023-12-25	manually corrected castle charmap (some bad tiles in last column), changed logic to add game win
	2024-01-03	added some loading color changes
*/

.filenamespace loader 

#import "../Includes/vicBank.asm"

//                vicBank(mode, VICBANK_ABS, BITMAP_OFF, CHARMEM_OFF, VIDMAT_OFF) ;computes mask etc for $d018 etc
.var 	vicMem1 = vicBank("char", $0000, $0000, $3000, $2000)
.var 	vicMem2 = vicBank("char", $0000, $0000, $3000, $2400)
.var 	vicMem3 = vicBank("char", $0000, $0000, $3000, $2800)

.label 	colorRam = $d800
/* 
.label 	screenRam1 = vicMem1.get("VIDMAT_ABS")
.label 	screenRam2 = vicMem2.get("VIDMAT_ABS")
.label 	screenRam3 = vicMem3.get("VIDMAT_ABS")
*/
.label 	vicmem1 = vicMem1.get("VICMEM_MASK")
.label 	vicmem2 = vicMem2.get("VICMEM_MASK")
.label 	vicmem3 = vicMem3.get("VICMEM_MASK")

.label 	charData = vicMem1.get("CHARMEM_ABS")



// start/end screen castle picture and color data are initially loaded into $0400-$07ff / $0800-$0bff
// screen is eventually copied into map space $cc00-$cfff


.pc = $0801 "Main"

#import "loader/config.asm"

                .byte $0b,$08            //Address of next BASIC instruction
                .word 10                 //Line number
                .byte $9e                //SYS-token
                .byte $32,$30,$36,$31    //2061 in ASCII
                .byte $00,$00,$00        //BASIC program end

Start:
		// detect PAL
w0:		lda $D012
w1:		cmp $D012
		beq w1
    		bmi w0
    		and #$03		// 03 if PAL
    		eor #3
    		beq go
    		
w2:		lda $D012		//if failed try again, not 100% reliable 
w3:		cmp $D012
		beq w3
    		bmi w2
    		and #$03		// 03 if PAL
    		eor #3
    		beq go
    		
    		ldy #0
!lp:
		tya
		pha   		
		lda errTbl,y
    		jsr $ffd2
    		pla
    		tay
    		iny
    		cmp #40
    		bne !lp-
    		
    		jmp *
    		
    		.encoding "petscii_upper"
    		     //0123456789012345678901234567890123456789'
errTbl:		.text "--== SORRY, PAL MACHINE TYPE ONLY ! ==--"  	

// .pc = * "Main"
go:	
		clc                     //Init loader with fastload allowed,
                jsr InitLoader          //Kernal will be switched off

		lda #BLUE
		sta $d021	//background color
		sta $d020	//border color

		lda #(vicMem1.get("VICBANK_MASK"))	//choose one of the four 16k VIC banks
		and #3
		sta $b0				// save lower two bits any temp
		lda $dd00
		and #%11111100			// upper bits are manipulated by the loader so don't mess with these
		ora $b0
		sta $dd00
		
		ldx #250
		lda #WHITE							
!lp:			
		sta colorRam-1,x	
		sta colorRam-1+250,x		
		sta colorRam-1+500,x
		sta colorRam-1+750,x	
		dex
		bne !lp-

startNote:	
		lda #vicmem1
		sta $d018
		
		jsr WaitSpace
		
		lda #vicmem2
		sta $d018
		
		jsr WaitSpace
		
		lda #vicmem3
		sta $d018
		
		jsr WaitSpace
		
		// make junk that is going to load into this screen's memory invisible
		ldx #250
		lda #BLUE							
!lp:			
		sta colorRam-1,x	
		sta colorRam-1+250,x		
		sta colorRam-1+500,x
		sta colorRam-1+750,x	
		dex
		bne !lp-



//. . . . . . . . done with note  . . . . . . . . .
// move castle picture data into its permanent storage spot at $0400 and color data to its permanent storage spot at $cc00
// in original game the scoring stuff at $60d 

.label	castlePicStore = $0400
.label	castleColorStore = $cc00


getPic:		  	
	
	   	ldx #251
loop:
    		lda CastlePicData-1,x
    		sta castlePicStore-1,x
    		lda CastlePicData+249,x
    		sta castlePicStore+249,x
		lda CastlePicData+499,x
    		sta castlePicStore+499,x
    		lda CastlePicData+749,x
    		sta castlePicStore+749,x
    		
    		lda CastleColorData-1,x
    		sta castleColorStore-1,x
    		lda CastleColorData+249,x
    		sta castleColorStore+249,x
		lda CastleColorData+499,x
    		sta castleColorStore+499,x
    		lda CastleColorData+749,x
    		sta castleColorStore+749,x
    		dex
    		bne loop
		

 		
getGame:	lda #LIGHT_GREY
		sta $d020
		lda #$02		// $02 = main program
                jsr LoadUnpacked        //Load file 02 as unpacked data and with startaddress
                bcc !n+          	//Error if carry set
		jmp LoadError
!n:


getSounds:	lda #GREY
		sta $d020
		lda #$06		// $06 = wavetables and sound vector tables
                jsr LoadUnpacked        //Load file 06 as unpacked data and with startaddress
                bcc !n+          	//Error if carry set
		jmp LoadError
!n:

getChars:	lda #DARK_GREY
		sta $d020
		lda #$20		// $2x = charset; need part of an atari charset for the option screen and the level loader screen
                jsr LoadUnpacked        //Load file 20 as unpacked data and with startaddress
                bcc !n+          	//Error if carry set
		jmp LoadError
!n:



                // hand off to game code
do:		
		// some inits for the very first launch of the game
		lda #0
		sta $a0			// this is the parameter determining which kind of attract screen.
					// this is the first start so begin with the option screen + tune  = 0	  
		sta $0300		//HighScore
		sta $0301		//HighScore+1		 clear highscore store

		jmp $1000          

endGame:	// main game exits here

		// determine if game was completed successfully
		lda #1			// assume players died
		sta $a0			// this is the parameter determining which kind of attract screen 1=highscore + bell
					// if the game is returning, player(s) have either died or completed the game.

		lda  $806a		//GameLevel_gbl
		cmp #5
		bne getVars
		lda #3			// 3 = victory screen
		sta $a0
		
		// reset the player variables
getVars:	lda #$05		// $05 = original player variables (nb I think GameLevel is 5 in this file doh)
                jsr LoadUnpacked        //Load file 05 as unpacked data and with startaddress
                bcc !n+          	//Error if carry set
		jmp LoadError 
!n:			

		jmp $1000		//relaunch
		
		              
//-----------------------------------------------------------------------------------------------------------------  
            
LoadError:      lda #$02
                sta $d020
WaitExit:       lda $dc00
                and $dc01
                and #$10
                bne WaitExit
                inc $01                 //Kernal back on to reset
                jmp 64738

/*
loadWaitMsg:
		ldy #0
!lp:		lda loadtext,y
		sta $400+7+24*40,y
		lda #WHITE
		sta colorRam+7+24*40,y
		iny
		cpy #28
		bne !lp-
		rts
*/		
//-----------------------------------------------------------------------------------------------------------------
 
WaitSpace:
!scan:		lda #$7f
		sta $dc00
		lda $dc01 
		and #$10 
		bne !scan-
		
!nokey:		lda #$7f		
		sta $dc00
		lda $dc01 
		cmp #$ff
		bne !nokey-
	
		ldx #$ff		//debounce wait
!l0:		cpx $d012
		bne !l0-
		dex
		cpx #$ea
		bne !l0-
		
		rts
//-----------------------------------------------------------------------------------------------------------------

.encoding "screencode_mixed"
//		012345678901234567890123456789023456789
loadtext:.text "please wait while loading..."


//-----------------------------------------------------------------------------------------------------------------

//.align $100	//timing critical, can't cross page boundaries in certain loops
.pc = $0b00 "Loader *Runtime*"
		#import "loader/loader.asm"			//runtime, length $ef
		#import "loader/loadunpacked.asm"		//runtime
.pc = $1000 "Loader Init Disposable"
		#import "loader/loaderinit.asm"		//disposable after calling InitLoader, length $0605

//-----------------------------------------------------------------------------------------------------------------

// note screens to be at $400, $800, $c00 (-$0fff)
.pc = vicMem1.get("VIDMAT_ABS") "Note Screens Disposable"

.var note1 = LoadBinary("note-screens/unote1_rc1.bin")
.var note2 = LoadBinary("note-screens/unote2_rc1.bin")
.var note3 = LoadBinary("note-screens/unote3_rc1.bin")

.fill 1000, note1.get(i)
.fill 24, 0
.fill 1000, note2.get(i)
.fill 24, 0
.fill 1000, note3.get(i)

//-----------------------------------------------------------------------------------------------------------------

// build fonts from junk I had around

.var ufChars = LoadBinary("chars/uchars.bin")
.var atari = LoadBinary("chars/L1-raw-chars_1bpp_7000-73FF.bin")

.pc = charData "Character/Tile Sets Disposable"		// nominally $3800

.fill 32*8, atari.get(i+8*96)	//lowercase

.fill 32*8, atari.get(i+8*0)	//space+numbers

.fill 64*8, atari.get(i+8*32)	//uppercase

.fill 128*8, ufChars.get(i+8*128)	//uf double high


// castle start / end screen and color data
.pc = $1700 "Castle Screen Pic Disposable"
CastlePicData:
.byte 32,32,233,239,105,233,236,229,111,97,233,251,233,236,233,236,245,233,105,233,236,233,223,223,233,239,105,207,224,223,233,236,233,117,233,223,223,32,96,32
.byte 32,32,95,255,223,207,32,207,105,97,207,32,252,90,207,32,207,223,96,252,90,207,95,246,95,255,223,32,207,32,207,90,245,97,207,95,246,32,32,32
.byte 46,32,95,247,105,95,252,229,96,97,95,46,95,252,95,252,229,95,223,95,252,95,32,246,95,247,105,46,95,32,95,252,245,97,95,32,246,46,32,32
.byte 32,32,32,32,32,32,32,46,32,32,32,233,223,233,96,46,32,100,32,100,46,100,100,32,32,32,32,32,32,46,32,32,32,32,233,126,97,233,32,46
.byte 32,100,46,111,96,111,32,32,233,223,96,224,105,95,96,96,32,229,76,229,76,161,246,32,32,103,227,248,98,121,32,96,32,96,236,223,252,254,96,96
.byte 32,229,246,203,234,224,101,108,174,186,96,224,96,46,95,105,32,245,174,160,186,174,79,32,46,103,239,249,226,119,32,46,108,121,252,105,98,245,108,123
.byte 32,229,174,174,160,174,75,124,186,174,101,95,223,96,233,223,32,204,160,106,160,160,101,46,32,233,123,32,32,32,32,32,225,174,252,203,174,252,160,126
.byte 32,39,160,186,160,117,46,32,160,160,97,46,95,224,224,105,46,245,174,106,160,174,101,32,32,174,167,44,32,46,32,32,32,160,224,160,160,174,160,32
.byte 32,46,160,106,160,117,32,46,174,106,97,207,123,248,96,207,116,245,174,227,160,160,101,32,224,174,186,97,32,32,32,32,32,160,167,186,160,160,234,46
.byte 46,103,186,106,160,76,104,104,160,106,97,225,252,174,252,254,101,245,160,106,160,167,101,46,229,224,160,117,32,32,32,46,32,203,174,160,106,174,246,32
.byte 32,103,224,227,174,186,102,92,160,227,160,245,106,160,186,174,117,203,160,106,174,160,102,92,229,106,160,117,46,32,32,32,32,160,160,174,106,160,186,32
.byte 32,103,160,174,160,161,102,92,160,174,174,186,227,160,106,160,76,160,160,227,160,160,102,102,167,227,160,92,111,111,111,111,122,186,174,160,227,160,160,32
.byte 96,122,174,160,174,221,160,92,160,160,174,221,160,106,160,160,186,207,247,247,208,160,102,102,229,174,106,186,174,174,160,174,200,161,160,174,160,174,175,32
.byte 103,167,160,160,160,161,160,92,160,160,160,186,160,227,174,160,213,160,226,226,160,201,102,102,229,174,227,186,174,160,174,160,186,220,160,160,160,160,160,32
.byte 103,204,160,160,204,160,160,204,160,160,204,160,160,207,160,207,161,160,252,254,160,161,208,102,207,224,204,224,224,204,224,224,204,160,224,204,160,224,207,32
.byte 103,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,161,91,91,91,91,161,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,32
.byte 103,224,131,173,182,180,160,144,143,146,148,160,130,153,160,160,161,91,91,91,91,161,160,132,133,147,137,135,142,133,132,160,130,153,160,160,160,160,160,32
.byte 103,224,224,224,224,160,160,224,224,224,224,224,224,224,224,160,161,91,91,91,91,161,224,224,160,160,160,224,224,224,224,224,224,224,160,160,160,160,224,32
.byte 103,160,160,160,160,146,143,130,160,146,129,134,129,131,160,160,161,91,91,91,91,161,160,160,160,144,133,148,133,146,160,134,137,142,154,133,140,160,160,32
.byte 32,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,32
//optionText:
.byte 32,32,32,64+1,14,26,1,8,12,32,4,5,18,32,64+13,9,20,19,16,9,5,12,5,18,58,32,6,49,32,4,18,$1d,3,11,5,14,32,32,32,32
.byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
.byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,49,32,64+19,64+16,64+9,64+5,64+12,64+5,64+18,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
.byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
.byte 32,32,32,32,32,32,32,32,32,32,32,32,64+13,64+9,64+20,32,6,49+6,32,64+26,64+21,64+13,32,64+19,64+16,64+9,64+5,64+12,32,32,32,32,32,32,32,32,32,32,32,32
.fill 24, $ff

.pc = * "Castle Color Data Disposable"
CastleColorData:
.byte 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,9,0
.byte 0,0,14,14,14,14,6,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,0,6
.byte 14,0,3,3,3,3,3,3,3,3,3,1,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,3,3,3,3,3,3,3,3,3,6,0,0
.byte 0,0,0,0,0,0,0,1,8,8,14,6,6,6,14,1,8,8,8,8,14,8,8,8,8,8,0,0,0,6,0,0,0,0,1,1,1,1,1,1
.byte 8,8,14,8,8,8,8,1,8,8,14,6,6,6,14,14,9,8,8,8,8,8,8,8,8,9,10,10,10,10,8,14,14,14,1,1,1,1,1,8
.byte 8,8,8,8,8,8,8,8,8,8,14,6,1,1,2,2,9,8,8,8,8,8,8,9,14,9,10,10,10,10,9,14,8,8,1,1,8,1,8,8
.byte 0,8,8,8,8,8,8,8,8,8,8,6,6,1,6,6,0,8,8,7,8,8,8,1,9,8,8,9,0,6,0,0,8,8,8,8,8,8,8,8
.byte 0,8,8,8,8,8,14,9,8,8,8,14,6,6,6,6,6,8,8,7,8,8,8,1,0,8,8,8,0,14,1,1,9,8,8,8,8,8,8,0
.byte 0,6,8,7,8,8,0,15,8,7,8,8,8,8,8,8,8,8,8,8,8,8,8,9,8,8,8,8,1,0,10,1,9,8,8,8,8,8,8,6
.byte 15,8,8,7,8,8,8,9,8,7,8,8,8,8,8,8,8,8,8,7,8,8,8,14,8,8,8,8,9,1,1,1,0,8,8,8,7,8,8,0
.byte 0,8,8,8,8,8,8,9,8,8,8,8,7,8,8,8,8,8,8,7,8,8,8,8,8,7,8,8,1,0,0,1,1,8,8,8,7,8,8,0
.byte 0,8,8,8,8,8,8,8,8,8,8,8,8,8,7,8,8,8,8,8,8,8,8,9,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0
.byte 8,8,8,8,8,8,8,9,8,8,8,8,8,7,8,8,8,7,7,7,7,8,8,9,8,8,7,8,8,8,8,8,8,8,8,8,8,8,8,0
.byte 8,8,8,8,8,8,8,9,8,8,8,8,8,8,8,8,7,7,7,7,7,7,9,9,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0
.byte 8,7,7,8,7,7,8,7,7,8,7,7,8,7,8,7,7,7,7,7,7,7,7,9,7,8,7,7,8,7,7,8,7,7,8,7,7,8,7,7
.byte 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,12,12,12,12,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
.byte 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,12,12,12,12,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
.byte 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,12,12,12,12,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
.byte 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,12,12,12,12,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
.byte 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,15,15,15,15,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
//optionColor:
.byte 13,13,13,13,13,13,13,13,13,14,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,14,13,13,13,13,13,13,13,13,13,13,13
.byte 14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14
.byte 14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,10,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14
.byte 10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10
.byte 10,15,15,15,15,15,15,15,15,15,15,15,15,15,15,10,10,10,10,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,10,10
.fill 24, $ff