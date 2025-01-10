# this makefile uses some of the Covert Bit Ops tools and exomizer v3.1.0
# https://cadaver.github.io/	https://csdb.dk/release/?id=198340

disk : load-control-3.prg exo
	"C:/C64/Tools/bin/makedisk.exe" ".\!Release-D64\Schreck64-100%.d64" ".\!Release-D64\commandfile.txt" R^2__PAL-ONLY
	
load-control-3.prg : sound-fx-wavetables-7.bin
	java -jar "C:\jac\wudsn\Tools\ASM\KICKASS\KickAss.jar" ".\Load-Control\load-control-3.asm"

sound-fx-wavetables-7.bin : 
	java -jar "C:\jac\wudsn\Tools\ASM\KICKASS\KickAss.jar" -binfile ".\Game\Sound\sound-fx-wavetables-7.asm"

main.bin : load-control-3.prg 
	java -jar "C:\jac\wudsn\Tools\ASM\KICKASS\KickAss.jar" -binfile ".\Game\main.asm"

exo : main.bin sound-fx-wavetables-7.bin
	"C:/C64/Tools/bin/exomizer.exe" raw -T4 -M256 -P-32 -c -o ".\Game\01.prg" ".\Game\main.bin"
	"C:/C64/Tools/bin/exomizer.exe" raw -T4 -M256 -P-32 -c -o ".\Game\Sound\02.prg" ".\Game\Sound\sound-fx-wavetables-7.bin"

clean :
	rm -f ./Load-Control/load-control-2.prg ./Load-Control/load-control-2.sym ./Load-Control/load-control-2.dbg
	rm -f ./Game/Sound/sound-fx-wavetables-7.prg ./Game/Sound/sound-fx-wavetables-7.sym ./Game/Sound/sound-fx-wavetables-7.dbg \
	      ./Game/Sound/sound-fx-wavetables-7.bin ./Game/Sound/02.prg
	rm -f ./Game/main.prg ./Game/main.sym ./Game/main.dbg ./Game/main.bin ./Game/01.prg
	rm -f ./!Release-D64/Schreck64*.d64

