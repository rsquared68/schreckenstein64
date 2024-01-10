//  helper function to configure VIC bank, pointers and such
// v0.1 2022-10-23


.function vicBank(mode, VICBANK_ABS, BITMAP_OFF, CHARMEM_OFF, VIDMAT_OFF) {

.var vicMem = Hashtable()

.eval vicMem.put("VICBANK_MASK", %11111100 | ($03-VICBANK_ABS/$4000) )

.if (mode=="bitmap" || mode=="BITMAP") { 
	.eval vicMem.put("BITMAP_MASK", %11110110 | ((BITMAP_OFF/$2000)<<3) )
	.eval vicMem.put("CHAR_MASK", %11111111)
	.var CHARMEM_OFF = $1000
} else {
	.eval vicMem.put("CHAR_MASK", %11110000 | ((CHARMEM_OFF/$0800)<<1) )
	.eval vicMem.put("BITMAP_MASK", %11111111)
}

.eval vicMem.put("VIDMAT_MASK", %00001110 | ((VIDMAT_OFF/$0400)<<4) )


.eval vicMem.put("VICBANK_ABS", VICBANK_ABS)
.eval vicMem.put("BITMAP_ABS", VICBANK_ABS+BITMAP_OFF)
.eval vicMem.put("CHARMEM_ABS", VICBANK_ABS+CHARMEM_OFF)
.eval vicMem.put("VIDMAT_ABS", VICBANK_ABS+VIDMAT_OFF)
.eval vicMem.put("VICMEM_MASK", vicMem.get("CHAR_MASK") & vicMem.get("BITMAP_MASK") & vicMem.get("VIDMAT_MASK") )	



.print "VICBANK_ABS = $"+toHexString(vicMem.get("VICBANK_ABS"),4)
.print "VICBANK_MASK= "+toBinaryString(vicMem.get("VICBANK_MASK"),8)
.print ""
.print "CHAR_ABS    = $"+toHexString(vicMem.get("CHARMEM_ABS"),4)
.print "CHAR_MASK    = "+toBinaryString(vicMem.get("CHAR_MASK"),8)
.print ""
.print "BITMAP_ABS  = $"+toHexString(vicMem.get("BITMAP_ABS"),4)
.print "BITMAP_MASK  = "+toBinaryString(vicMem.get("BITMAP_MASK"),8)
.print ""
.print "VIDMAT_OFF  = $"+toHexString(vicMem.get("VIDMAT_ABS"),4)
.print "VIDMAT_MASK  = "+toBinaryString(vicMem.get("VIDMAT_MASK"),8)
.print ""
.print "$D018       = "+toBinaryString(vicMem.get("VICMEM_MASK"),8)
.print ""

.return vicMem
}