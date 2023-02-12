#!/bin/sh
# Adaption of https://github.com/bptato/RFC-Greek-World/
# Based on https://forums.civfanatics.com/threads/compiling-the-dll-on-linux.658833/
#
# Enable some specific changes required for this mod
PBMOD_BUILD=1

#Author: bluepotato
#This script is released into the public domain.
#A substitute for nmake for *nix systems.
#USAGE: ./compile.sh [release/debug/final_release] [clean]
#See also: compile_settings.sh, which is sourced by this script.

. ./compile_settings.sh

error() {
	echo "ERROR: $*" >&2
	exit 1
}

CLEAN=false

tolower() {
	printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

toupper() {
	printf '%s\n' "$1" | tr '[:lower:]' '[:upper:]'
}

dec() {
	printf '%d\n' $(($1-1))
}

if test $# -lt 1; then
	error "Unspecified target. USAGE: ./compile.sh [release/debug] [clean]"
else #iterate over arguments
	for arg in "$@"; do
		larg="$(tolower "$arg")"
		if test "$larg" = "release" -o "$larg" = "debug" -o "$larg" = "final_release" -o "$larg" = "clangd"; then
			TARGET="$(toupper "$(printf '%s\n' "$arg" | head -c1)")$(tolower "$(printf '%s\n' "$arg" | tail -c+2)")"
		elif test "$larg" = "clean"; then
			CLEAN=true
		else
			error "Invalid argument $arg"
		fi
	done
fi

export WINEDEBUG=-all

test -f compile_quit && rm compile_quit

if test "$TARGET"; then
	echo "TARGET: $TARGET"
fi

if test "$TARGET" = "Clangd"; then
	printf '[\n' > ./compile_commands.json.new
fi

#Clean mode.
if $CLEAN; then
	if test "$TARGET"; then
		if test -e "$TARGET"; then
			echo "CLEAN: cleaning $TARGET"
			rm -r ./"$TARGET"
		else
			echo "CLEAN: nothing to clean"
		fi
	else
		echo "CLEAN: cleaning all targets"
		if test -e Release; then
			rm -r ./Release/
		fi
		if test -e Final_release; then
			rm -r ./Final_release/
		fi
		if test -e Debug; then
			rm -r ./Debug/
		fi
		exit 0
	fi
fi

if ! test -e "$TARGET"; then
	mkdir "$TARGET"
fi


owine() { #wine 1.7.55
	WINEPREFIX="$OWINEPREFIX" $wine17 "$@"
}

generate_compile_command() {
	printf \
'{
"directory": "%s",
"command": "%s",
"file": "%s"
},\n' "$PWD" "$(printf '"%s" ' "$@" | sed 's/"\/G7" //g' | sed 's/"/\\"/g')" "$PWD/$2" >> compile_commands.json.new
}

cl() {
	if test "$TARGET" = "Clangd"; then
		generate_compile_command "$VCTOOLKIT/bin/cl.exe" "$@"
	elif ! test -f compile_quit && ! owine "$VCTOOLKIT/bin/cl.exe" "$@"; then
		echo q > compile_quit
		error "Failed to compile $1"
	fi
}

link() {
	owine "$VCTOOLKIT/bin/link.exe" "$@"
}

should_compile() {
	if test $# -gt 2; then
		compiled="$TARGET/$3"
	else
		compiled="$TARGET/${1%.*}.obj"
	fi

	if ! test -f "$compiled" || test "$(date -r "$compiled" +%s)" -lt "$(date -r "$1" +%s)"; then
		return 0
	fi

	set -- $(echo "$DEPENDS" | sed "${2}q;d")
	shift
	test "$(date -r "$compiled" +%s)" -lt "$(date -r "$(ls -rt $(find . -maxdepth 1 | grep -Eio "$(echo "$@" | sed "s/ /\|/g")") | tail -1)" +%s)"
}

PCH="$TARGET/CvGameCoreDLL.pch"

echo "Finding dependencies..."
DEPENDS="$("$FASTDEP" --objectextension=pch -q -O "$TARGET" CvGameCoreDLL.cpp)"
for file in *.cpp; do
	DEPENDS="$DEPENDS
$("$FASTDEP" --objectextension=obj -q -O "$TARGET" "$file")"
done

#Set flags for compilation
GLOBAL_CFLAGS="/MD /nologo /GR /Gy /W3 /EHsc /Gd /Gm- /DWIN32 /D_WINDOWS /D_USRDLL /DCVGAMECOREDLL_EXPORTS /YuCvGameCoreDLL.h /c /Fp$PCH"
if [ "$PBMOD_BUILD" = "1" ] ; then
	# /Oy => /Oy-
	if test "$TARGET" = "Release"; then
		set -- "/O2" "/Oy-" "/Oi" "/G7" "/DNDEBUG" "/DFINAL_RELEASE" $GLOBAL_CFLAGS
	elif test "$TARGET" = "Final_release"; then
		set -- "/O2" "/Oy-" "/Oi" "/G7" "/DNDEBUG" "/DFINAL_RELEASE" "/GL" $GLOBAL_CFLAGS
	elif test "$TARGET" = "Debug"; then
		set -- "/Z7" "/Od" "/D_DEBUG" "/RTC1" $GLOBAL_CFLAGS
	fi
else
	if test "$TARGET" = "Release"; then
		set -- "/O2" "/Oy" "/Oi" "/G7" "/DNDEBUG" "/DFINAL_RELEASE" $GLOBAL_CFLAGS
	elif test "$TARGET" = "Final_release"; then
		set -- "/O2" "/Oy" "/Oi" "/G7" "/DNDEBUG" "/DFINAL_RELEASE" "/GL" $GLOBAL_CFLAGS
	elif test "$TARGET" = "Debug"; then
		set -- "/Z7" "/Od" "/D_DEBUG" "/RTC1" $GLOBAL_CFLAGS
	fi
fi

#Generate precompiled header
ci=1
if should_compile "_precompile.cpp" $ci "CvGameCoreDLL.pch"; then
	cl "_precompile.cpp" "$@" \
		"/I$VCTOOLKIT/include" "/I$PSDK/Include" \
		"/I$PSDK/Include/mfc" "/I$BOOST/include" \
		"/I$PYTHON/include" "/YcCvGameCoreDLL.h" \
		"/Fo$TARGET/_precompile.obj"
fi

#Compile the files
if $PARALLEL; then
	PIDS=""
	for COMPILEFILE in *.cpp; do
		ci=$(($ci+1))
		if test "$COMPILEFILE" != "_precompile.cpp"; then
			(
			if should_compile "$COMPILEFILE" $ci; then
				cl "$COMPILEFILE" "$@" \
					"/I$VCTOOLKIT/include" "/I$PSDK/Include" \
					"/I$PSDK/Include/mfc" "/I$BOOST/include" \
					"/I$PYTHON/include" "/Fo$TARGET/${COMPILEFILE%.*}.obj"
			fi
			)&
			PIDS="$PIDS $!"
		fi
	done
	for p in $PIDS; do
		if test -f compile_quit; then
			for pp in $PIDS; do
				#this appears to work, kinda.
				kill -9 $pp >/dev/null 2>&1
			done
			rm compile_quit
			error "Failed to compile all files."
		fi
		wait $p
	done
	if test -f compile_quit; then
		rm compile_quit
		error "Failed to compile all files."
	fi
else
	for COMPILEFILE in *.cpp; do
		if test "$COMPILEFILE" != "_precompile.cpp"; then
			ci=$((ci+1))
			if should_compile "$COMPILEFILE" $ci; then
				cl "$COMPILEFILE" "$@" \
					"/I$VCTOOLKIT/include" "/I$PSDK/Include" \
					"/I$PSDK/Include/mfc" "/I$BOOST/include" \
					"/I$PYTHON/include" "/Fo$TARGET/${COMPILEFILE%.*}.obj"
			fi
		fi
	done
fi

if test "$TARGET" = "Clangd"; then
	cat compile_commands.json.new | head -n$(dec $(cat compile_commands.json.new | wc -l)) > compile_commands.json
	rm compile_commands.json.new
	printf '}\n]\n' >> compile_commands.json
else
	#Link resulting files
	if [ "$PBMOD_BUILD" = "1" ] ; then
		LINKFILES="$(find "$TARGET"/*.obj *.obj)"
	else
		LINKFILES="$(find "$TARGET"/*.obj)"
	fi

	GLOBALFLAGS="$LINKFILES /SUBSYSTEM:WINDOWS /LARGEADDRESSAWARE /TLBID:1 /DLL /NOLOGO /PDB:$TARGET/CvGameCoreDLL.pdb"
	if test "$TARGET" = "Release"; then
		FLAGS="$GLOBALFLAGS /INCREMENTAL:NO /OPT:REF /OPT:ICF"
		set -- ""
	elif test "$TARGET" = "Final_release"; then
		FLAGS="$GLOBALFLAGS /INCREMENTAL:NO /OPT:REF /OPT:ICF /LTCG"
		set -- ""
	else
		FLAGS="$GLOBALFLAGS /DEBUG /INCREMENTAL /IMPLIB:$TARGET/CvGameCoreDLL.lib"
		set -- " " "$PSDK/Lib/AMD64/msvcprtd.lib"
	fi

	if [ "$PBMOD_BUILD" = "1" ] ; then
		link $FLAGS "/LIBPATH:$PSDK/Lib/" "/LIBPATH:$BOOST/libs/" "/LIBPATH:$VCTOOLKIT/lib/" \
			"/LIBPATH:$PYTHON/libs/" "/LIBPATH:$ASSETSDIR/" \
			"boost_python-vc71-mt-1_32.lib" "python24.lib" "winmm.lib" "user32.lib" \
			"msvcprt.lib" "msvcrt.lib" "OLDNAMES.lib" \
			"/DEF:Updater.def" \
			"/out:$OUTPUT""$@"
	else
		link $FLAGS "/LIBPATH:$PSDK/Lib/" "/LIBPATH:$BOOST/libs/" "/LIBPATH:$VCTOOLKIT/lib/" \
			"/LIBPATH:$PYTHON/libs/" "/LIBPATH:$ASSETSDIR/" \
			"boost_python-vc71-mt-1_32.lib" "python24.lib" "winmm.lib" "user32.lib" \
			"msvcprt.lib" "msvcrt.lib" "OLDNAMES.lib" \
			"/out:$OUTPUT""$@"
	fi
fi
