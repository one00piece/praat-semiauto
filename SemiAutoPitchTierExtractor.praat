# ################################################################################################################## #
# PRAAT SCRIPT "SEMI-AUTO PITCH CONTOUR EXTRACTOR"
# This script semi-automates extracting pitch tiers from sound files.  It cycles through a directory of sound files, opens them one at a time, displays the pitch contour over a
# narrowband spectrogram, and prompts the user to either: (1) accept the pitch measurement (2) adjust the pitch floor/ceiling and redraw, or (3) mark the file as unmeasurable,
# before continuing on to the next file.  Filename, duration, and pitch settings are saved to a tab-delimited file, and all files that are not skipped have their pitch tiers extracted.
#
# FORM INSTRUCTIONS
# "logFile" should specify the FULL PATH of the log file.  The log file will store the number, filename, duration, min/max pitch, and notes for each file.  "startingFileNum" allows
# you to pick up where you left off if you're processing a lot of files: just look at your log file from last time and enter the next number in sequence from the "number" column
# (if you do this, be sure to click "Append" when asked if you want to overwrite the existing log file).  If "carryover" is unchecked, then each new file analyzed will start out with
# the default pitch settings.  Otherwise, each new file (after the first one) will start out with the accepted settings from the preceding file (unless the preceding file was skipped,
# in which case the settings will revert to default).  If "interp" is checked, the script will interpolate pitch points (quadratically) before saving out the pitch tiers.
# 
# VERSION 0.1 (2012 05 29)
#
# AUTHOR: DANIEL MCCLOY: (drmccloy@uw.edu)
# LICENSED UNDER THE GNU GENERAL PUBLIC LICENSE v3.0: http://www.gnu.org/licenses/gpl.html
# DEVELOPMENT OF THIS SCRIPT WAS FUNDED BY THE NATIONAL INSTITUTES OF HEALTH, GRANT # R01DC006014 TO PAMELA SOUZA
# ################################################################################################################## #

# COLLECT ALL THE USER INPUT
form Pitch tier extractor: Select directories & starting parameters
	comment See the script's header for explanation of the form variables.
	sentence logFile ~/Desktop/PitchTierExtraction.log
	sentence Output_directory ~/Desktop/pitchtiers/
	sentence Sound_directory ~/Desktop/sounds/
	sentence Sound_extension .wav
	integer startingFileNum 1
	integer defaultMinPitch 75
	integer defaultMaxPitch 400
	boolean carryover 1
	boolean interp 1
endform

# BE FORGIVING IF THE USER FORGOT TRAILING PATH SLASHES OR LEADING FILE EXTENSION DOTS
call cleanPath 'output_directory$'
outputDir$ = "'cleanPath.out$'"
call cleanPath 'sound_directory$'
soundDir$ = "'cleanPath.out$'"
call cleanExtn 'sound_extension$'
soundExt$ = "'cleanExtn.out$'"

# INITIATE THE OUTPUT FILE
if fileReadable (logFile$)
	beginPause ("The log file already exists!")
		comment ("The log file already exists!")
		comment ("You can overwrite the existing file, or append new data to the end of it.")
	overwrite_setting = endPause ("Append", "Overwrite", 1)
	if overwrite_setting = 2
		filedelete 'logFile$'
		call initializeOutfile
	endif
else
	# THERE IS NOTHING TO OVERWRITE, SO CREATE THE HEADER ROW FOR THE NEW OUTPUT FILE
	call initializeOutfile
endif

# MAKE A LIST OF ALL SOUND FILES IN THE FOLDER
Create Strings as file list... list 'soundDir$'*'soundExt$'
fileList = selected("Strings")
fileCount = Get number of strings

# INITIALIZE SOME VARIABLES
minPitch = defaultMinPitch
maxPitch = defaultMaxPitch

# LOOP THROUGH THE LIST OF FILES...
for curFile from startingFileNum to fileCount

	# READ IN THE SOUND...
	select Strings list
	soundname$ = Get string... curFile
	Read from file... 'soundDir$''soundname$'
	filename$ = selected$ ("Sound", 1)
	totalDur = Get total duration

	# GET READY TO SHOW THE EDITOR WINDOW
	zoomStart = 0
	zoomEnd = totalDur

	# SHOW THE EDITOR WINDOW
	select Sound 'filename$'
	View & Edit
	editor Sound 'filename$'
		# HIDE THE SPECTROGRAM & ANALYSES TO PREVENT ANNOYING FLICKERING
		Show analyses... no no no no no 10
		Zoom... zoomStart zoomEnd

		# SET ALL THE RELEVANT SETTINGS
		Spectrogram settings... 0 2500 0.025 50
		Advanced spectrogram settings... 1000 250 Fourier Gaussian yes 100 6 0
		if carryover = 0
			Pitch settings... defaultMinPitch defaultMaxPitch Hertz autocorrelation automatic
		else
			Pitch settings... minPitch maxPitch Hertz autocorrelation automatic
		endif
		Advanced pitch settings... 0 0 no 15 0.03 0.45 0.01 0.35 0.14
		
		# DISPLAY NARROWBAND SPECTROGRAM AND PITCH (MAKING SURE "MAX ANALYSIS" IS LONG ENOUGH SO THE SPECTROGRAM ACTUALLY SHOWS UP)
		Show analyses... yes yes no no no totalDur+1
	endeditor

	# INITIALIZE SOME VARIABLES FOR THE PAUSE U.I.
	clicked = 1
	if carryover = 0 or maxPitch = 0  ;  THE maxPitch=0 CONDITION PREVENTS ERRORS WHEN carryover=1 AND THE PREV. FILE WAS SKIPPED
		minPitch = defaultMinPitch
		maxPitch = defaultMaxPitch
	endif

	# SHOW A U.I. WITH PITCH SETTINGS.  KEEP SHOWING IT UNTIL THE USER ACCEPTS OR CANCELS
	repeat
		beginPause ("Adjust pitch analysis settings")
			comment ("File 'filename$' (file number 'curFile' of 'fileCount')")
			comment ("You can change the pitch settings if the pitch track doesn't look right.")
			integer ("newMinPitch", minPitch)
			integer ("newMaxPitch", maxPitch)
			comment ("clicking RESET will reset minPitch and maxPitch to the default values.")
			comment ("Clicking REDRAW will redraw the pitch contour with the settings above;")
			comment ("clicking SKIP will write zeros to the log file and skip pitch tier extraction.")
			sentence ("Notes", "")
		clicked = endPause ("Play","Reset", "Redraw", "Accept", "Skip", 4)
		minPitch = newMinPitch
		maxPitch = newMaxPitch
		editor Sound 'filename$'
			Pitch settings... minPitch maxPitch Hertz autocorrelation automatic
		endeditor

		# IF THE USER CLICKS "PLAY"
		if clicked = 1
			editor Sound 'filename$'
				Play... 0 totalDur
			endeditor

		# IF THE USER CLICKS "RESET"
		elif clicked = 2
			minPitch = defaultMinPitch
			maxPitch = defaultMaxPitch
		endif

		# IF clicked = 3 (REDRAW) THEN THE WHOLE repeat... until BLOCK GETS RERUN WITH THE CHANGED SETTINGS

	until clicked >3

	# IF THE USER SKIPS, WRITE OVERRIDE VALUES
	if clicked = 5
		minPitch = 0
		maxPitch = 0
				
	# IF THE USER ACCEPTS THE PITCH TRACK SETTINGS, CREATE A MANIPULATION OBJECT...
	elif clicked = 4
		#Select Sound 'filename$'  ;  IT'S ALREADY THE ONLY THING SELECTED, SO THIS THROWS AN ERROR
		To Manipulation... 0.01 minPitch maxPitch
		
		# INTERPOLATE PITCH POINTS IF REQUESTED
		if interp = 1
			select Manipulation 'filename$'
			View & Edit
			editor Manipulation 'filename$'
				Interpolate quadratically... 4
			endeditor
		endif
		
		# EXTRACT PITCH TIER AND WRITE TO FILE
		select Manipulation 'filename$'
		Extract pitch tier
		select PitchTier 'filename$'
		Save as text file... 'outputDir$''filename$'.PitchTier

		# CLEAN UP
		select Manipulation 'filename$'
		plus PitchTier 'filename$'
		Remove
	endif

	# CLEAN UP
	select Sound 'filename$'
	Remove

	# WRITE TO FILE
	resultline$ = "'curFile''tab$''filename$''tab$''totalDur''tab$''minPitch''tab$''maxPitch''tab$''notes$''newline$'"
	fileappend "'logFile$'" 'resultline$'
endfor

# REMOVE THE STRINGS LIST AND GIVE A SUCCESS MESSAGE
select Strings list
Remove
clearinfo
files_read = fileCount - startingFileNum + 1
printline Done! 'files_read' files read.'newline$'

# FUNCTIONS (A.K.A. PROCEDURES) THAT WERE CALLED EARLIER
procedure cleanPath .in$
	if not right$(.in$, 1) = "/"
		.out$ = "'.in$'" + "/"
	else
		.out$ = "'.in$'"
	endif
endproc

procedure cleanExtn .in$
	if not left$(.in$, 1) = "."
		.out$ = "." + "'.in$'"
	else
		.out$ = "'.in$'"
	endif
endproc

procedure initializeOutfile
	headerline$ = "number'tab$'filename'tab$'duration'tab$'pitch_floor'tab$'pitch_ceiling'tab$'notes'newline$'"
	fileappend "'logFile$'" 'headerline$'
endproc
