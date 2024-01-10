/*-------------------------------------------------------------------------------
; Covert Bitops Loadersystem V3.x, configuration
;-------------------------------------------------------------------------------*/
.filenamespace loader //continue use of loader namespace

        // Conditionals

#undef USETURBOMODE               //Can undef if you are not going to use
                                  //SCPU/C128 fast mode

#undef INCLUDESAVE          	//undef to remove save routines

        // Zeropage config
.zp {
.const zpBase          = $30 		//$02  Base for zeropage vars

.label fileOpen        = zpBase
.label loadTempReg     = zpBase+1
.label loadBufferPos   = zpBase+2
.label fastLoadEor     = zpBase+3      //Needed for NTSC version of 2-bit protocol
.label zpLenLo         = zpBase+4      //For depackers & save
.label zpSrcLo         = zpBase+5
.label zpSrcHi         = zpBase+6
.label zpBitsLo        = zpBase+7
.label zpBitsHi        = zpBase+8
.label zpBitBuf        = zpBase+9
.label zpDestLo        = zpBase+10
.label zpDestHi        = zpBase+11
}

        /* Non-zeropage memory defines; loadBuffer can be relocated if needed, but
        ; note that all of $0200-$02ff cannot be used by your program with Kernal 
        ; loading */

.label loadBuffer      = $0200
.label ELoadHelper     = $0200
.label StopIrq         = $02a7
