/*	Schreckenstein-64:  	Study of and attempt at translation of Peter Finzel's 1985 "Schreckenstein" for the Atari 8-bit line of
				computers to the Commodore 64.  Largely it is an introduction for me to the Atari which I had never
				used as a teen, and an opportunity to explore intensive VIC-coding and beam-racing approaches for the C64
				that have been developed since I last touched 6510 assembly in the mid-1980s.

				/Engine/block0 ,1, 2 contain diassembled game code from the Homesoft [a2] crack of the Atari game; comments
				and labels are mine.  Some sections have been optimized, inlined, etc.  The remainder of the code is mine.
				The display list, VBI etc graphics processing has been newly implemented using VIC raster interrupts in
				IRQ-Handlers/viewport-irqs etc. Coarse scrolling of the viewports and scrolling of the opponent sprites
				is implemented with speedcode dynamically generated in this handler.  The original code, gameplay design,
				and graphical assets are used with the written permission of Peter Finzel.  The remainder of the code is
				Copyright 2024 Robert Rafac, but may be freely reused in accordance with the license.txt file included in
				the root path of this package.

				The loader code is more or less taken verbatim from Covert Bitops Loadersystem Copyright (c) 2002-2023
				Lasse Öörni https://github.com/cadaver/c64loader and is incorporated here under the terms of the license
				agreement included in the /loader path of this package.

				Kick Assembler v5.x  
				

//                .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .


	2023-01-14	Initial map representation demonstration work with only tile scolling

			[see earlier files for complete version history]
	


	2024-01-05	schreck-31	BASELINE for RC1

			Integrated tune player; subroutine code integrated and located following the sound fx players.
			Correct behavior when game completed, goes from victory screen back to option/tune screen.
			Fixed bug: Spiders have never worked, because I always passed A=game level=0 to ENEMIES_FOR_LEVEL
			so every level had the number and type of enemies configured for level 0.  Improved irq startups
			after new level load so it always occurs in the same place (trigger msBit).  Fixed bug in COPY_SCORES
			as it was shifted by 1 byte in both read and write.  Removed keypress bell because it conflicts
			with tune.  Blanked AI score display like original game, updated COPY_SCORES to make it look right
			when switching back to 2 player mode. Removed keypress bell because of conflict with tune player.
			Added flag animation. New note screens, added loader border color changes. Added thunder sound effect
			to victory screen.

			All the changes moved code around substantially.  The deglitch-strips routine is time critical
			so I moved it to the end of viewport-irqs which rarely moves due to the fact that the start is
			page-aligned. Otherwise, an issue can appear for the very sensitive map1y=6 in SB2, either the
			middle will glitch or the last sprite in the strip is not configured in time.

			Next:
			Animation when bell tolls
			Sound effect gating improvement
			Better joy/key deconflicter possible?
			Key debounce interval a little long?
			Reduce number of enemies because spiders make game very difficult on levels 4/5?
			Revisit memory layout
			irq handlers still need to start at $a001?

			Bug?  In at least one example of forcing level promotion, teleporter not working on level 5



	2024-01-07	schreck-64 RC1	First release candidate

			Organize a bit for repo.  Remove USELOADER #define as it cannot work any longer.



	2024-11-16	schreck-33	deprecated, part one of new sound scheme

			Attempting new sound architecture: Player-triggered sounds are assigned to voice 1 for player 1
			and voice 2 for player 2 with no crossover. All sounds associated with sprite animation are triggered
			by the anim player (step, jump, climb, stunned, robbed, dying, teleporting) and these are blocked by
			any sounds currently playing. All sounds associated with player actions without associated sprite
			animations are are loaded by block0/1 routines and pre-empt any currently playing sounds (get object,
			use object, trigger trap; also reanimate).  Added logic so that motion sounds associated with sprite
			animation (stand, run, jump, climb) can never overwrite pending action sounds. This costs 12 cycles in
			step-motion-anim so need to watch out for player 1.

			The slight timing changes impact the play-voice1 stabilizer as usual; e.g. playing $11 got potion
			glitches hermit scheme. Needed to tune delays for entry into play-voice1 at dbug.

			PlayerIndex_zp is never guaranteed to be sync'd with state_zp or pass through irq handler, so
			no opportunity to save cycles with SAVE/RESTOREPLAYERINDEX, but can do something like make an
			isolated "PlayerIndex_IRQ_zp" in block0 to separate these completely.

			Issues:  When falling onto a candle or jumping onto it with joystick down, candle sound won't play
				 or can be cut off *sometimes*?
				 Activate lantern/well sound has too long a final decay

			New labels-9, sound-manager-4, wavetables-6a, tune-player-2, block0-slim-13, block1-slim-12,
			viewport-irqs-33.  Optimization of ldx PlayerIndex duplications in block0,1.

			Next steps:
				Isolate PlayerIndex in routines called by irq handler 		X
				Get play-voice3 going again for footsteps to free up voices	X
				Implement queued life dec, door tune, chirp, etc. 
				Remove all references to SoundStateLo/Hi			



	2024-11-17	schreck-33b	deprecated; new sound scheme with code optimization

			Replaced PlayerIndex_zp with PlayerIndexIRQ_zp in block0, ai-motion-indep-irq, viewport-irqs, labels.
			Optimization of ldx PlayerIndex in ai-motion teleport routines.
			Replaced absolute use of $db in player-moves with PlayerIndexIRQ_zp.  Ensure motion control is properly
			initialized with PlayerIndexIRQ here in main.



	2024-11-17	schreck-33c	baseline; re-enabled voice 3 for footsteps

			New sound control register labels-11, block0-slim-15, play-voice3-2 putting footsteps in voice 3.
			Works



	2024-11-21	schreck-33d	deprecated; implemented new virtual-stack based sound queue but
					needs extension for action sounds vs. queued sounds

			Q:  Should POP from queue and push to sound register run inside or outside IRQ?
			    Clocked_Sound_and_Life_Decrement runs about every 19k cycles, about once every frame or sometimes a little
			    more than one frame, so outside in block1 is OK

			Implemented virtual-stack based sound queue in block1, init, labels, schreck-macros, attract-screens
			Currently not playing splat sound in PLOT_BURST when enemy killed, there are so many sounds playing now
			SoundStateLo/Hi now no longer in labels.  SoundStackDepth currently 6 so using zeropage $60-65 for queue stack

			Because AI throws weapons constantly, can collide with search tune. Turned off throw-weapon sound pre-empt
			when LevelEndFlag=1.

			New scheme to stop player(s) and AI from moving after door exited; applies mask inside EXECUTE_PLAYER_AI_MOTION
			because AI routine running in IRQ can overwrite masking attempts done in the block0 inline joystick routine
			which is outside the IRQ handler.

			Retuned TrapAnimLength to try to prevent it from sometimes going slightly more than one char anim cycle.

			Issues:  Place door sound not played
				 Rarely, action sounds like got wizard can be overwritten by other stuff. As an experiment I invalidate
				 the sound queue (stack ptr to zero) to stop lightning sounds still in queue after wizard captured.
				 During teleport of player A, if player B is in frame he gets blanked at the same time as player A
				 that is before the viewport is relocated to a new part of the map--he disappears too early



	2024-11-21	schreck-33e	baseline, but queue sounds/action sounds race condition needs addressing

			Sound queue now managed in irq on alternate frames. Queue will not overwrite loaded sounds not yet playing.
			Most action sounds invalidate queue. Anim sounds do not pre-empt, because they can pre-empt themselves
			(e.g. jump will constantly retrigger).  Used state_zp to cut frequency of chirp being triggered in half.
			Fixed bug in that place door sound was not played.  Throw weapon sound no longer pre-empts.  Removed
			remaining references to old SoundQueue.

			This almost works except during intense sound queue utilization, some critical actions sounds aren't played.
			For example, picking up a potion during lightning or key during door tune.  Invalidating the queue by setting
			the pointer to zero does not help. I need a better method, maybe a PauseSoundQueue_zp flag.  Try that in
			next spin.



	2024-11-21	schreck-33f	FAILED BRANCH scheme to hacky, also doesn't accomplish goals.

			Pauses sound queue logic for anim = {teleport, stun, robbed, death} and action =  {got potion, got wizard, got key}.
			These are all the critical sounds that can happen during search tune and lightning phases. Got door has own
			logic	

			Pausing sound queue is not accomplishing what I want, got potion, wizard, robbed still overwritten by lightning?
			Re-ordered stop and pre-empt, better. Try stopping queue once per lightning load and tune note load.

			pre-empt (set soundPlaying to 0) then load (p1Sound,x = something) sometimes gets stuck with gate on and stale
			data, because irq can start "in-between" with soundPlaying=0 and no sound loaded yet.

			Next:  Using Load-Prempt (LP) only heard sound get stuck once. Possibly in irq I can just check for soundPlaying=0
			on each voice and if so, force the associated gate off.  try this then compare LP with PL--need to recheck PL code
			because I noticed and fixed some weirdness in it when creating LP.

			It's very "hacky" with all these corner cases.

			Renamed VoiceStream pointer labels to _zpw as they should be

			Saw another teleporter bug.  If the portal transports to the same view on the same vertical level (e.g. just displacing
			you on the same "level" sideways by a small amount) the portal sprite moves to the new location but the player does not.
			The player coordinates, hpos, vpos, and viewport position were not changed at all. At the time I was in the bottom right
			of the map so the viewport could not move, so maybe there's a condition where it can't do anything with the view so
			nothing gets updated?  It should have moved the player coordinates and the sprite position.

			Still have "other player in your view disappears at the same moment you disappear in the teleporter, before the viewport
			moves" bug



	2024-11-23	schreck-33g	DEPRECATED	"eliminate sound race conditions"  timing not correct yet

			Idea:  Set bit 7 of sound index if the sound engine should pre-empt or not on loading that sound in the irq handler.
				This allows a single memory write for both index and pre-empt, instead of two.  The race condition where
				the two are split apart by an interrupt won't obtain. There will still be other race conditions that need to
				be found and addressed...

			Pre-empting now handled directly in sound-manger. Bit 7 of sound index controls whether to pre-empt already playing
		  	sound (1) or to only load new sound if voice is already free (0).
			Removed extra "lda stepSound_zp" and switched to macro version of play-voice3 for speed.

			All non-move animation sounds (stun, robbed, death, teleport) have pre-empt bit set in block0 tables.
			All directly played action sounds with the exception of throw weapon have pre-empt bit set.
			Queued sounds are not pre-empting (chirp, life dec/portal update, reset trap, tune notes, place door, lightning)

			Quite a few changes were necessary to get a reliably working improvement over the RC1 baseline.  The stabilizers
			in playVoice1,2 were moved so that they stabilize the lda (),y only in reloadRegs. There are six indirect-indexed
			loads, so in the case of a page crossing for a sound's table, up to seven possible 1-cycle delays are possible.
			The stabilizer was moved so that it only handles these loads and not any other slop from branches across pages,
			mistimed paths, etc. The symptom of the stabilizer going out of range (A>7 after $dc04 load) is a crash or a
			"stuck" sound which can either be silent or gated on. Generally if it doesn't crash the stabilizer jumps over
			the iteration decrement instruction so it keeps playing the current iteration over and over until something
			writes 0 to soundPlaying for that voice.  It was necessary to rework all of the delays for the different Y
			timing branches to keep it in range.

			After fixing that, there were then a bunch of race conditions causing voice2 sounds to get messed up or not
			play. This is because the sequencing of code requesting sounds, the stuffing of the sounds into the "voice"
			registers in playSound1,2, and the setup of the VoiceStreamPtrs using the values in "voice" all happen in a
			sequence that is preferrable for the graphic kernel timing and not for anything sane.  However, switching
			the positions of playVoice1 and playVoice2 in the irq handler got rid of most of the conflicts.  This is partly
			also because the sound queue manager (stuffs sounds into availble voices) tries to utilize voice 2 first.
			The combination of the sequence and the preference of the queue to use voice 2 I believe caused too many
			overwrites of voice 2.  This is the current sequence:

		Manage queue > step motion 1 > step motion 0 > block 1 > playVoice3 >    sndmgr-1      > clear p#Sounds > playVoice2 > sndmgr-2,3 > block 1  > playVoice1 
		   queue	    anim 1	  anim 2      action12     play3     load voice regs      zero inputs      play 2     load ptr12   action12     play1


			This works mostly, player 2 does get overwritten still some times but not as bad.
			Timing is not stable at sprdly1_.  The stabilizer in playvoice2 is not perfect...




	2024-11-23	schreck-33h	DEPRECATED	New stabilizers for new sound architecture, correct timing, other fixes

			Cleaned up the delay structure that was messed up by separating zeroing the sound inputs p1Sound_zp, p2Sound_zp outside of sndmgrphase3.
			New stabilizer in play-voice1/2-3 which looks at the VoiceStreamPtr base to determine how many page crossings will occur, and then
			subtracts cycles in a delay slide. This is not prone to failure like the hermit stabilizer, but still needed a cycle added here
			and there I guess to accomodate sprite DMA. Re-timed irq v36b against sprDelayDone1/2, now seems as good as RC1.  All of the timings
			are recorded in the paper notes for both RC1 and 33h.  There is only one timer-based stabilizer left, for irqStatusBar1.

			Removed references to experimental "PAUSESOUNDQUEUE" that I never used. Null sound insertion scheme for lightning phase to get more
			irregular intervals, otherwise the queue manager stuffs the sound at a very regular interval.  Added WAITBURST switch to make splat
			graphic persist for full blit cycle when enemy killed--does not seem to slow things down too much and ensures burst is visible.
			Increased AI probability to climb from rand > $64 to rand > $40.




	2024-12-07	schreck-34	DEPRECATED	Teleport blanking, other features. Not ready for playtest release due to strip blanking.

			Fix teleport blanking issue: other player in own view (sprite strip) disappears just as player teleports, due to blanking applied
			to both strips before Y positions are updated.

			In the RC1 way of doing things, the other player in own view will be blanked before the perspective shifts to the new portal
			location. However, I do not see any evidence of opposite problem where the player is not blanked while Y is changing, which
			can result in a "ghost" image on the sprite strip that remains until it is over-written. 

			In this version I changed the ordering of the Y-compution (updateView1SpriteStrip, which sets blitY1) and the generation of the
			blit speedcode (uses blitY1) in order to make view 1 "stale" for a frame where it was not in earlier versions.  However, view 2
			was always stale for a frame so now they match. This allowed me to move the blanking enable in block0 (near move player to teleport
			exit) to a part of the sequence where the blanking should not happen too early for view 1 or 2.

			Fixed "AI gets stuck running into wall on right upper middle of third game level."  Caused be reaching X limit in movePlayerRight
			while there is still one traversable tile remaining to the right of the player. AFAIK this only happens on that map, because the
			walkable area is larger by one tile only on that map and in that area.  Changed X limit in plaer-moves-7:movePlayerRight from old
			value of $ef to $f4.

			Added sound queue invalidation during got door phase to ensure door sound plays--in one game I heard it overwritten by something.

			On level 4 the map has climable features above the current Y minimum of 4.  Made Y min 2 safely I think (1 is definitely bad)
			and view Y min reduced to 0 (note that the cmp must be $01 because bcc).  This is not enough to fix, so level 4 map was edited
			top middle: extend rock from which ladder hangs, and edit spiderweb to the right. The top middle narrow part of level 5 seems OK
			e.g for jumping.  Check spiderweb on atari top right level 4, can jump from web to platform?

			Added flash on key input during attract screens (settings and highscores).  Slightly retuned wavetable so that teleport and potion
			are not so mutually dissonant.  Removed an extra adc #$00 near block1:!COMPLETE_LEVEL.  Fixed "ignores f1" after victory screen in
			attract-screens (reset GameLevel_gbl)

			Instrumented code (#define TRAPSTRIP) for trapping too large a blit step.  One player fall while other jumping results in 4 line
			displacements (8) and teleport can result in arbitrary displacements. I think the critical issue are teleports that get close
			to the other player's Y, either coincidentally or due to "targeted" mode used by the zombie.

			Not able to create a failed blank/deglitch on demand. Consider adding another line of deglitch in just the bottom row of strips,
			costs 16 cycles and require retiming of SB2:critical and below

			In .d64 build, temporary new V34-Test notescreen.



	2024-12-17	schreck-35	BASELINE	enhancement of strip blank (required irq retime), pause feature, improved deglitch

			Even with instrumented code and trying to force various strip delta-y scenarios I could not reproduce the sporadic strip
			blanking issue in many hours of play.  There are cycles available below SB2 so I just added another row of deglitch
			blanking as insurance--although I don't know it will really be insurance because it's possible that the deglitch condition
			(blitY out of range) is never reached on the frame after the row fails to be erased.

			Completely reworked timing at the top of SB2, moving the deglitch up and away from the badlines. viewport-irqs-38
			Note that it now has a different ordering than RC1 so it is not possible to do a direct timing compare above the
			"critical:" label.

			Added game pause feature using shift-lock key.  viewport-irqs-38 looks for shift-lock/left-shift and sets pauseKey_zp.
			If set block0 will bypass step-anim and main-motion routines, and block1 will freeze in clock handler. Can be compiled
			conditionally with #define PAUSEKEY.  Uses new CHKPAUSE macro in shreck-macro. Pause code changes strip2 arrival for
			y1=7, y2=1 to line $ab cycle 31 from cycle 30 but seems OK. 

			Edited note screens for playtest release, pause control.


	
//                .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
*/ 


// preproc switches

#define PAUSEKEY		// shift-lock pause feature
#undef TRAPSTRIP		// implement breakpoints at trap1 and trap2 if strip blit displaces more than a certain number of rows
#define WAITBURST		// after burst plotted, wait for one frame to be sure that view has had its blit cycle
#undef SLOWCHIRP		// reduce frequency of bat chrip
#undef RASTERTIME		// display rastertime in border for non-statusbar sections
#undef TILETRACKER		// diagnostic to track tileXY on map when turned on
#define	DOUBLEDOWN		// allows double stepping in y in some parts of code (other parts may still be commented out)
#define NOHALFSTEP		// turns off alternate-viewport xscroll half-stepping
#undef USEFRAMES		// switches to open rectangular frames for statusbar sprites for diagnostic purposes
#undef COLLISIONBRK		// attempted debug feature does brk instruction on irq exceeded alloted rastertime


// external labels and so on

#import "../Includes/vicBank.asm"
#import "../Includes/mapping.asm"
#import "../Includes/r2-macros-3.asm"
#import "../Includes/labels-12.asm"
#import "schreck-macros.asm"

#import "../Load-Control/load-control.sym"


//================================================================================================================
//		                        SOME CONSTANTS AND STUFF
//================================================================================================================

//.label charsetMask = $8069

//		  Use helper function to compute bitmasks for memory configuration

//                vicBank(mode, VICBANK_ABS, BITMAP_OFF, CHARMEM_OFF, VIDMAT_OFF) ;computes mask etc for $d018 etc
.print "VIC mem 1 / Bank 1:"
.var 	vicMem1 = vicBank("char", $4000, $0000, $0000, $3800)
.print "--------------------------------------------------------------------"
.print "VIC mem 2 / Bank 1:"
.var 	vicMem2 = vicBank("char", $4000, $0000, $2000, $3c00)
.print "--------------------------------------------------------------------"
.print "VIC mem 3 / Bank 2:"
.var 	vicMem3 = vicBank("char", $8000, $0000, $1000, $3800)
.print "--------------------------------------------------------------------"

.label 	colorRam = $d800

.label 	screenRam1 = vicMem1.get("VIDMAT_ABS")
.label 	vicmem1 = vicMem1.get("VICMEM_MASK")
.label 	charData = vicMem1.get("CHARMEM_ABS")

.label 	screenRam2 = vicMem2.get("VIDMAT_ABS")
.label 	vicmem2 = vicMem2.get("VICMEM_MASK")


//......................................SPRITE UTILIZATION PLAN...................................................

// Player 1 statusbar 
.var SB1List = List().add(4,5,6,7,3,2,1)
// Player 2 statusbar
.var SB2List = List().add(4,5,6,0,3,2,1)
// vertical sprite strip common to both viewports
.var StripList = List().add(0,4,5,7)
// Player sprite in own viewport
.const Player1Sprite = 6
.const Player2Sprite = 6
// sprites that never need to be reconfigured in x, y, or pointer because they are only in the statusbars
.var StaticSpriteList = List().add(1,2,3)
//................................................................................................................



//......................................WHERE TO LAUNCH INTERRUPTS................................................

.const irqLine_Work2 =		$cb	// $ca seems about nominal, tune for race condition on viewport 2 render

//================================================================================================================
//================================================================================================================



//         ______--------`````````` Let's go! '''''''''''--------_______


.pc = $1000 "Main"
//.................................................................................................................

	// Launch and re-launch entry point.  Timer, memory banking configuration, and raster-irq stuff set up
	// assumes parameters {$a0,...} passed from loader

	sei
	lda #$7f       // disable timer interrupts
        sta CIAICR
        sta CI2ICR

//................................................................................................................

        // prepare timer for raster stabilization (needs sei, unsets sprites)

syncBeamCIA:
!sync:		      // hermit's original comments
	cmp $d012     //scan for begin rasterline (A=$11 after first return)
	bne *-3       //wait if not reached rasterline #$11 yet
	ldy #8        //the walue for cia timer fetch & for y-delay loop         //2 cycles
	sty $dc04     //CIA Timer will count from 8,8 down to 7,6,5,4,3,2,1      //4 cycles
	dey           //Y=Y-1 (8 iterations: 7,6,5,4,3,2,1,0)                    //2 cycles*8
	bne *-1       //loop needed to complete the poll-delay with 39 cycles    //3 cycles*7+2 cycles*1
	sty $dc05     //no need Hi-byte for timer at all (or it will mess up)    //4 cycles
	sta $dc0e,y   //forced restart of the timer to value 8 (set in dc04)     //5 cycles
	lda #$11      //value for d012 scan and for timerstart in dc0e           //2 cycles
	cmp $d012     //check if line ended (new line) or not (same line)
	sty $d015     //switch off sprites, they eat cycles when fetched
	bne !sync-    //if line changed after 63 cycles, resynchronize it!
//.................................................................................................................

	// memory

	lda #(vicMem1.get("VICBANK_MASK") & 3)	//choose one of the four 16k VIC banks, lowest two bits do the select
	sta $b0				// save lower two bits any temp
	lda CI2PRA
	and #%11111100			// upper bits are manipulated by the loader so don't mess with these
	ora $b0
	sta CI2PRA

//.................................................................................................................

	// init colors, sprites, SID, various global variables and so on

	lda #0				// force it to 0 = Level 1, not done in initialize bc option screen uses this	
	sta GameLevel_gbl
	
	lda #%00110101			//ok to turn off KERNAL now	(or, loader has already turned off kernal)	
	sta R6510

 	
OneOrTwoPlayer:
		
	// parameter passed from previous execution in $a0: 0=option screen, 1=highscore screen, 2=winning screen
	jsr OPTION_SCREEN		// this routine uses a raster interrupt but exits with irqs disabled
					// SID envelopes will be in arbitrary state when this returns

	jsr initialize			// SID envelopes for voice 3 will be set for playVoice3 "footstep" effect

//.................................................................................................................

	// SET UP INTERRUPT TRIGGERS FOR GAME'S GRAPHIC KERNEL
	                                      	
line0:  lda #irqLine_Work2   // rasterline at which to launch the irq handler 
        sta RASTER		
        lda #$17			//2 	there can still be badlines after line $31 depending on YSCROLL, even though text is hidden until line $37 !!!
	sta SCROLY			//4 	set this to clear bit 7 (msbit rasterline) and prevent spurious triggers on badlines
        
            
//.................................................................................................................        

	// map and tile loader

nextLevel:
	jsr SILENCE_SID

	//turn off sprites
	lda #0	
	sta $d015	
		
	jsr loadScreen			// draws and colors loadscreen for this level. assumes no interrupts are active!
					// needs the alpha tiles from file $20

	// prototyping
	lda GameLevel_gbl
	clc
	adc #$10
	jsr loader.LoadUnpacked		// e.g. "10" for level 1 map
	bcc !n+          	 	//Error if carry set
	jmp loader.LoadError
!n:	
	lda GameLevel_gbl
	clc
	adc #$20
	jsr loader.LoadUnpacked		// e.g. "21" for level 1 charset
	bcc !n+          	 	//Error if carry set
	jmp loader.LoadError
!n:

	// patch alpha charset with sprite data temporarily
	ldx #$3f
!lp:
	lda spieler2patch,x
	sta $6600,x
	dex
	bpl !lp-
	
	jsr CLEAR_SCREEN_1

	// initialize viewport coordinates
	ldx #0	
!lp:
	lda viewportInit,x
	sta View1CoordBase,x	//$8004-9
	sta View2CoordBase,x	//$800a-f
	inx
	cpx #$06
	bne !lp-
	

	// initialize player starting coordinates per level
	ldx GameLevel_gbl
	lda p1Xpos16init,x	//lsbs
	sta p1Xpos16
	lda p1Ypos16init,x
	sta p1Ypos16
	lda p1HposV1init,x
	sta p1HposV1
	lda p1VposV1init,x
	sta p1VposV1
	
	lda p2Xpos16init,x
	sta p2Xpos16
	lda p2Ypos16init,x
	sta p2Ypos16
	lda p2HposV2init,x
	sta p2HposV2
	lda p2VposV2init,x
	sta p2VposV2
	
	lda #0			//msbs
	sta p1Xpos16+1
	sta p1Ypos16+1
	sta p2Xpos16+1
	sta p2Ypos16+1
	
	
	//housekeeping from last level
	sta LoadLevelTrigger
	//turn joysticks back on if they were turned off at end of level. Joystick bit overwrite is handled near where interrupt handler is stopped at level end
	sta Player1JoystickMask_zp
	sta Player2JoystickMask_zp
	//init cycle state register; AFAIK doesn't matter 0/1 because
	//PlayerIndex ends up getting bounced around independently of state now
	sta state_zp
	
initColors:
	// schreck mcm map tile color definitions per level
	lda Color1PerLevel,x
	sta BGCOL1
	lda Color2PerLevel,x
	sta BGCOL2
		
	// schreck mcm color ram set up per level "individual color"	
	lda IndividualColorPerLevel,x
	ora #8				//MCM, msb must be set
	sta Sb1Bg1
	sta Sb2Bg1
	
	ldx #250								
!lp:			
	sta colorRam-1,x	
	sta colorRam-1+250,x		
	sta colorRam-1+500,x
	sta colorRam-1+750,x	
	dex
	bne !lp-


	// Fill map with objects and enemies  (can't do this until KERNAL has been switched out)

	jsr JUMP_6 //POPULATE_MAP		// normally vectored to via JUMP_6; I don't see anything configuring JUMP_6 and it's static in the C64 blocks
	lda GameLevel_gbl			// enemies_for_level takes parameter in A = which level to configure for
	jsr ENEMIES_FOR_LEVEL			//2703 --> 2e3a	inits enemy+weapon tables and weapon state regs	-- My JUMP_9

	ldx #$ff
!lx:		
	txa
	pha
	jsr CREATE_DESTROY_ENEMIES_WEAPONS	// get the enemies started -- My JUMP_8
	pla
	tax
	dex
	bne !lx-

	// make the SID noise frequency consistent, the random number initialization messes with this to "reseed" the SID
	lda #$ff
	sta $d40e // voice 3 frequency low byte
	sta $d40f // voice 3 frequency high byte
	lda #$80  // noise waveform, gate bit off
	sta $d412 // voice 3 control register	
	
	// setup extra "ones" digit for scores = 0 in the statusbars if 2 player game, else don't if 1 player
	lda #$10
	sta $7c1e-11+4
	sta $7dd6-11+4
	lda NumPlayers
	beq !n+			
	lda #$00				// overwrite player 2 with blank if 1 player game
	sta $7dd6-11+4
!n:	

	//blank sprite strip data left over from previous game if any
	ldy #0
	lda #0
!lp:	dey
	sta PlayerSprites+60*$40,y		//screen1
	sta PlayerSprites+$0700+60*$40,y	//screen2
	bne !lp-
	
	//set first strip blit out of range and create the speedcode to keep it blank when the interrupts first start
	lda #0	
	sta blitY1
	sta blitY2	
	jsr configureBlit1			// create the blit speedcode for view 1, it will be stale from previous game
			
	lda #$ff
	sta $d015				// turn on all sprites
	
	lda #$00
	//sta PlayerIndex_zp			// run this once or weird stuff is in zp temp pointers causing a sound to get played, coordinates will be assigned wrong, etc.
	sta PlayerIndexIRQ_zp
	jsr PLAYER_MAIN_MOTION_SEGMENT		// when interrupt is first started at the bottom of the frame						
	//inc PlayerIndex_zp
	inc PlayerIndexIRQ_zp			
	jsr PLAYER_MAIN_MOTION_SEGMENT


//.................................................................................................................	

	SET_6502_IRQ_VECTOR_A(irq_Work2)
        
        lda #$81        			// enable raster interrupts for game display note sei should still be in effect
        sta IRQMSK
	
	lsr VICIRQ				// acknowledge any pending raster interrupt serviced
	
	WAIT_UNTIL_RASTERMSB0_A()		// wait until upper part of screen	... need consistent startup of graphic kernel or possible crash	
	WAIT_UNTIL_RASTERLSB_A($ff)
	
 	cli             			// enable interrupts to handle graphics, ready to start game loop!

	//         ######################## GAME GRAPHIC, SOUND, AND MOTION KERNEL INTERRUPTS ACTIVE ###########################  

	lda #%00001111				//restore SID sound if it had been turned off, ok to do once irq handler for SID is active
	sta $d418				//volume and filter type, voice 3 enab

//.................................................................................................................

//.................................................................................................................

gameServiceLoop:
	
	// Put numeric values in statusbars for life counter, score, level, and tasks to complete

	// do life
	lda #$1e
	sta scoreScreenLoc
	lda #$7c
	sta scoreScreenLoc+1
	lda PlayerLifeForce
	sta num
	ldy #(3-1)		// 3 decimal digits 
	jsr Scrn16toDec

	lda #$d6
	sta scoreScreenLoc
	lda #$7d
	sta scoreScreenLoc+1
	lda PlayerLifeForce+1
	sta num
	ldy #(3-1)		// 3 decimal digits 
	jsr Scrn16toDec

	// do score
	lda #$1e-11
	sta scoreScreenLoc
	lda #$7c
	sta scoreScreenLoc+1
	lda L060d	//$60d
	sta num
	lda L060d+1	//$60e
	sta num+1
	ldy #(4-1)		// 4 decimal digits 
	jsr Scrn16toDec

	// NEED TO ADD:  if one player, don't display score for AI
	// temporary hack:  just zero the AI's score, reliable because check for game over happens before main engine loop
	lda NumPlayers
	beq !n+			// if = 0, player 2 is human so branch
	lda #0
	sta L060f		
	sta L060f+1		// else take away the AI score so it doesn't contribute to anything
	jmp !skip+		// and skip writing to the screen
!n:	

	lda #$d6-11
	sta scoreScreenLoc
	lda #$7d
	sta scoreScreenLoc+1
	lda L060f	//$60f
	sta num
	lda L060f+1	//$610
	sta num+1
	ldy #(4-1)		// 4 decimal digits 
	jsr Scrn16toDec

!skip:	
	//do level "S"
	lda GameLevel_gbl
	clc
	adc #1
	ora #$10
	sta $7c1e+7
	//do objectives (combined tasks) "O"
	lda NumberOfTasksRemaining			// this is actually number of tasks needed for the level
	sec
	sbc CombinedTasksComplete
	ora #$10
	sta $7dd6+7

// ......................................................................

	// check if level completed or game over and handle reload/recycle

	lda LoadLevelTrigger	
	beq !isGameOver+

	// yes, prepare to recycle

	WASTE_CYCLES_X(16*63)	// wait some time with interrupts still enabled to ensure sound had a chance to load

	// wait for level complete sound to end before stopping interrupts

	lda #0			// otherwise sounds on stack will get played at start of next level
	sta SoundStackPtr_zp
!lp:	
	lda soundPlaying1_zp 
	ora soundPlaying2_zp 
	bne !lp-
	
	
	sei
	lda #$f0        	// disable raster interrupts
	sta $d01a 		// ICR
	lda #0			// allow input again
	sta Player1JoystickMask_zp
	sta Player2JoystickMask_zp

!isGameCompleted:
	inc GameLevel_gbl
	lda GameLevel_gbl
	cmp #5
	bne !doNextLevel+
	jmp !gameOver+		// if final level completed game is over
	
!doNextLevel:
	jsr SILENCE_SID
	jmp nextLevel		// go on to next level

!isGameOver:
	lda PlayerControlMode  // check if game over
	cmp #2
	bne !nope+		// player 1 is still alive
	
	// player 1 dead
	eor PlayerControlMode+1
	beq !gameOver+		// both players dead

	// player 1 dead but player 2 alive
	lda NumPlayers
	beq !nope+		// 0=2 player game so let player 2 contine

!gameOver:
	// zombie delay counter can end at $0, $1, $fe, etc. so not reliable
!wait:	
	sei			// stop the interrupts!
	lda #$f0       		// disable raster interrupts
	sta $d01a 		// ICR
	lsr VICIRQ		// acknowledge anything pending
	
	//kill sprites
	lda #0
	sta $d015
	
	// make junk that is going to load into this screen's memory invisible
	ldx #250
	lda #BLACK							
!lp:			
	sta colorRam-1,x	
	sta colorRam-1+250,x		
	sta colorRam-1+500,x
	sta colorRam-1+750,x	
	dex
	bne !lp-
		
	jsr SILENCE_SID
	
	jsr COPY_SCORES		// overwrite last game's score text in buffer used by attract-screens
	jsr UPDATE_HIGHSCORE	// determine if new highscore and update as done for last game's scores
	
	
	jmp loader.endGame	//endGame in loader
	
!nope:
// ......................................................................

	// do actual game service

	ldx #0
!lp:	

	txa
	pha
	
	jsr CREATE_DESTROY_ENEMIES_WEAPONS
	jsr JUMP_7 //LEVELS134	// normally vectored to via JUMP_7,  this makes traps and teleporters work ... I don't see anything configuring JUMP_7 and it's static in the C64 blocks

	pla
	tax
		
	and #3
	bne !skip+		// slow the clocks down. the player delay countdown interacts with the teleporter state so pay attention
				// on level 1, life decrements every 5s in one-player mode of original game
				// c64 timed here to be 4.5s using an interval of 7
	txa
	pha
	
	jsr JUMP_5		// MAIN_HANDLER_1	// has all the clocks for life counters and so on.  Normally vectored to via JUMP_5; I don't see anything configuring JUMP_5 and it's static in the C64 blocks

	pla
	tax
!skip:	

	inx			// here controlling how often the game engine runs relative to the scoretext update, game over checks, etc
speed:	cpx #80			// timed, this loop is exited at an interval of 0.42s when = 90 decimal, so that's the score update lag.
				// 
	bne !lp-		// this setting does not seem to have a major impact on perceived speed, was 60 decimal

// 0000000000000000000000000000000000000000000000000000000000000000000000
// tile tracking
#if TILETRACKER
	lda #$10		// bit 4 = play button on datasette
	bit $01
	bne !n+

	clc			// lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)
	ldx PlayerTileYcoordinate
	inx        
	lda YtoMapLsbTbl,x           
	adc PlayerTileXcoordinate           
	sta map01_zpw                            
	lda YtoMapMsbTbl,x           
	sta map01_zpw+1  
	
	ldy #0
	lda (map01_zpw),y
	eor #$80
	sta (map01_zpw),y
!n:
#endif
// 0000000000000000000000000000000000000000000000000000000000000000000000	  
// ......................................................................

	jmp gameServiceLoop



//........................................................................................................................................................

// level initialization tables

.const	h0 = -1	 	//sprite hpos offset adjust, note these numbers end up getting multiplied by 2 in code that converts to C64 screen pos
			//legacy of MCM having two color clocks per pixel on C64 and one on Atari
			//note this is also used when positioning the player sprite after a teleport
			

p1Xpos16init:	.byte $3b, $45, $41, $3c, $3e
p1Ypos16init:	.byte $2d, $1d, $15, $11, $1d
p1HposV1init:	.byte $3f+h0, $49+h0, $45+h0, $40+h0, $42+h0
p1VposV1init:	.byte $79, $69, $61, $5d, $69

p2Xpos16init:	.byte $65, $68, $65, $6d, $6a
p2Ypos16init:	.byte $2d, $1d, $15, $11, $1d
p2HposV2init:	.byte $69+h0, $6c+h0, $69+h0, $71+h0, $6e+h0
p2VposV2init:	.byte $79, $69, $61, $5d, $69

viewportInit:	.byte $00, $00, $0f, $00, $00, $03 

Color1PerLevel:		.byte	GREY,	ORANGE,	LIGHT_GREY,	ORANGE, BLUE
Color2PerLevel:		.byte	RED, 	BROWN, 	BROWN, 		BROWN,	CYAN	// CYAN GREEN possibly LIGHT_GREEN			
IndividualColorPerLevel:.byte	YELLOW,	YELLOW,	YELLOW,		YELLOW,	YELLOW	// Individual Color appears as MCM complement
										// in the statusbar, so really only YELLOW->GREY and
										// GREEN->LIGHT_GREEN can possibly work.
spieler2patch:
		.byte $ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
		.byte $00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$81,$ff,$f8,$c4,$e1
		.byte $fc,$c4,$d8,$fc,$c1,$f1,$fc,$c5,$e3,$fc,$c5,$c6,$fc,$84,$c0,$f8
		.byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0c
										
//........................................................................................................................................................




//_________________________________________________________________________________________________________________________________________________________
//_________________________________________________________________________________________________________________________________________________________


num: 	.word 0000 
pad:	.byte $0

Scrn16toDec:
        sty buflen			// store a copy of Y
              
PrDec16Lp1:
	ldx #$ff
	sec                             // Start with digit=-1
   
PrDec16Lp2:
	lda num+0
	sbc PrDec16Tens.lo,Y
	sta num+0  			// Subtract current tens
	lda num+1
	sbc PrDec16Tens.hi,Y
	sta num+1
	inx
	bcs PrDec16Lp2                  // Loop until <0
   
	lda num+0
	adc PrDec16Tens.lo,Y
	sta num+0			// Add current tens back in
	lda num+1
	adc PrDec16Tens.hi,Y
	sta num+1
	txa
	bne PrDec16Digit                // Not zero, print it
   
	lda pad
	bne PrDec16Print
	beq PrDec16Next			// pad<>0, use it
	
PrDec16Digit:
	ldx #$10
	stx pad                      	// No more zero padding
	ora #$10                        // Print this digit
   
PrDec16Print:
	sta ReverseBuf,Y
 
PrDec16Next:
	dey
	bpl PrDec16Lp1                  // Loop for next digit

Replay:
	ldy buflen
	ldx #0
ReLp:	lda ReverseBuf,Y
	sta scoreScreenLoc:$7c1e,X

	inx
	dey
	bpl ReLp
	
	rts

ReverseBuf:
.fill 5, 0
buflen:
.byte 0
PrDec16Tens:
.lohifill 5, pow(10,i)


//_________________________________________________________________________________________________________________________________________________________
//_________________________________________________________________________________________________________________________________________________________


.pc = * "Player Moves"				// new player movement subroutines (player, viewport, sprite)
	#import "player-moves-7.asm"
.pc = * "Update Transformations"		// math for sprite, sprite strip, and viewport positioning
	#import "update-transformations-12.asm"
.pc = * "Schreck Block 0"			// original player control, player movement, and sprite animation routines; runs in irq
	#import "Engine/block0-slim-18.asm"
.pc = * "AI control routines (formerly in block 0)"
	#import "ai-motion-indep-irq-5.asm"	
.pc = * "Schreck Block 1"  			// original 26c0-3fe6  movement and map interaction routines
	#import "Engine/block1-slim-16.asm" 	// most of game mechanics / engine which runs outside of irq
.pc = * "Random Number Generator"
	#import "random-2.asm"

// origin location in file
	#import "move-pattern-8.asm" 
	
//........................................................................................................................................................
// Charsets are loaded here
	.pc = charData "Character/Tile Sets dummy fill"
	.fill $2800, 00		
	
//........................................................................................................................................................
// Redrawn player sprites. File contains all 64 sprites that will fit here, though only 60 are defined as of 2023-03-17
.var PlayerSpriteData = LoadBinary("../Game-Assets/sprites/Player Sprites Reorder-Blank16.bin")
.pc = $6800 "Player Sprites"
	PlayerSprites:	.fill PlayerSpriteData.getSize(), PlayerSpriteData.get(i)
//........................................................................................................................................................
// one VIC bank is hardly enough, so put statusbar sprites in the part of screen 2 that is never displayed (screen 2 only used for 4 lines of statusbar)
// nominally at $7c00

#if USEFRAMES
	.var SBspriteData = LoadBinary("../Game-Assets/sprites/SB-Test-Blank-Frames2.bin")
#else	
	.var SBspriteData = LoadBinary("../Game-Assets/sprites/Proto-game-SB-Full-FullCover4.bin")
#endif	

	.pc = screenRam2+$40 "Statusbar Sprites Pt 1"      //upper half of screenmem, i.e., in viewport 1
	SBsprites1:	.fill 5*$40, SBspriteData.get(i)
// sprite strip data memory occupies $7e00-7eff
	.pc = screenRam2+$300 "Statusbar Sprites Pt 2"			//remember sprite strip in view 1 uses screenRam2+$200-$2ff 
	SBsprites2:	.fill 3*$40, SBspriteData.get(i+5*$40)		//not enough room to do 4

//	.pc = $6000 + 192*8 "Statusbar Sprites Pt 3 (Spieler 2)"	// put it at the end of the atari alpha chars
//	SBsprites3:	.fill 1*$40, SBspriteData.get(i+7*$40)

//........................................................................................................................................................
.pc = $8000 "Schreck Block 2"  // original 8000-8148  helper routines, should be made relocatable but it is currently initializing the variable table at $8000
	#import "Engine/block2-5.asm"
.pc = * "Initialization Routines"
	#import "init-5.asm" 
.pc = * "Option/Attract Routines"
	#import "attract-screens-6.asm" 
.pc = * "Commodore Helpers"
	#import "helpers-2.asm"
//........................................................................................................................................................
.pc = $9200 ".fill Generated Math Tables, other stuff follows to -$93ed"
	.fill $20, [$00,$80]
	.fill $20, [$ac+i, $ac+i]
// this table implements the transformation from x,y tile coordinates to map lsb = $80*(y%2) + x,  msb = $ac + floor(y/2)	
//........................................................................................................................................................
.pc = $9400 "Sound effect and music players"
	#import "Sound/play-voice1-3.asm"	// now stabilized without cia
.pc = $9500					// do this as you can afford to not let anything timing critical cross a page boundary
	#import "Sound/play-voice2-3.asm"	// now stabilized without cia
	#import "Sound/play-voice3-2.asm"	// macro
	#import "Sound/sound-manager-6.asm"	// macros for inlining
	#import "Sound/tune-player-2.asm"
//........................................................................................................................................................
.pc = * "IRQ Handlers (Option/Attract Screens)"
	#import "IRQ-Handlers/attract-irqs-4.asm"
//........................................................................................................................................................
.pc = $a001 "IRQ Handlers (Gameplay Kernel)"		// +1 because stupid emulator
	#import "IRQ-Handlers/viewport-irqs-38.asm"
	#import "update-viewports-14.asm"
//........................................................................................................................................................
.label mapRam = $ac00
	
.pc = mapRam "-$cbff Map Data dummy fill"
//	.fill $2000, 00	

//........................................................................................................................................................
	.pc = $e000 "-$f383 Sound effect wavetables and tune notes dummy fill"
//	.fill $1383, 00	

//_________________________________________________________________________________________________________________________________________________________
//_________________________________________________________________________________________________________________________________________________________

.function substituteColors(b) {		//color for trap ghost on level 1 was incorrect, fixed by switching to 2nd half of charset (right thing to do?)

	.var cOld = 0
	.var cNew = 0
	.var bNew = 0
	
	.for (i=0; i<4; i++) {
	
		//.print toBinaryString(b)
		//.print toBinaryString(bNew)
		//.print " "
		.eval cOld = b & 3
		.eval cNew = cOld
		.if(cOld==1) {
			.eval cNew = 3
		} else {
		.if(cOld==3) {
			.eval cNew = 1
			     }
			}
		.eval b = b >> 2
		.eval bNew = (cNew << 2*i) | bNew	
		}
	.return bNew
	}

