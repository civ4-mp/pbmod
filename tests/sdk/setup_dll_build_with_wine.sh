#!/bin/bash
#
# SDK Install Script for Wine
# 
# Based on https://forums.civfanatics.com/threads/compiling-the-dll-on-linux.658833/

CONFIG_FILE="$(basename --suffix=.sh "$0").config"
# SCRIPT_DIR="$(pwd)" # Could be wrong
SCRIPT_DIR="$(dirname "$0")"
SCRIPT_DIR="$(realpath "$SCRIPT_DIR")"

# Repo root dir
REPO_ROOT_DIR="$(realpath ${SCRIPT_DIR}/../..)"  

# Directory of CvGameCoreDLL
DLL_CODE_FOLDER="${REPO_ROOT_DIR}/CvGameCoreDLL"

MOD_ASSET_FOLDER="${REPO_ROOT_DIR}/PBMod_v10/Assets"

# Folder for downloads
TMP_FOLDER="/tmp"

# Folder for Installation aka Wineprefix (Root of new wine installation)
WINEPREFIX="$REPO_ROOT_DIR/wine_for_sdk"

TOOLKIT_URL="https://versaweb.dl.sourceforge.net/project/beyond-the-sword-sdk/Install%20Civ4%20Microsoft%20Windows%20SDK%20Visual%20C%20Toolkit.exe"
PSDK_URL="https://download.microsoft.com/download/7/5/e/75ec7f04-4c8c-4f38-b582-966e76602643/5.2.3790.1830.15.PlatformSDK_Svr2003SP1_rtm.img"

# UNATTENDED_INSTALL_ARCHIVE="https://raw.githubusercontent.com/civ4-mp/pbmod/master/tests/sdk/Civ4_SDK_Files.tgz.gpg"
UNATTENDED_INSTALL_ARCHIVE="https://civ.zulan.net/pb/volatile/Civ4_SDK_Files.tgz.gpg"
UNATTENDED_INSTALL_ARCHIVE_SHA256="6402eb23cd50d481a5cf7b76f821518a3153d17f2cea25c0562dbc6454a196d9"

if [ -e "$CONFIG_FILE" ] ; then
	source "$CONFIG_FILE"
fi

echo -e "Environment:\n" \
	"\n\tScript folder: $SCRIPT_DIR" \
	"\n\tDLL code folder: $DLL_CODE_FOLDER" \
	"\n\tMod assets folder: $MOD_ASSET_FOLDER" \
	"\n\tTemp folder: $TMP_FOLDER"\
	"\n\tWINEPREFIX: $WINEPREFIX\n"

if [ ! -e "$CONFIG_FILE" ] ; then
	echo "Put change of default variables into into '$CONFIG_FILE'"
fi


help() {
	echo -e "Available commands:\n\n" \
		"\tinstall\t\tInstall Microsoft SDK and Toolkit 2003 by GUI setup\n" \
		"\t\t\tThis needs some manual interaction, e.g. mounting a image\n" \
		"\t\t\tand cycle some setup dialogs…\n" \
		"\tunattended\tInstall Microsoft SDK and Toolkit 2003 without interaction.\n" \
		"\t\t\tThis could maybe failing in future.\n" \
		"\tbuild\t\tCall build script of Civ4 DLL\n" \
		"\t\t\tJust calling './CvGameCoreDLL/compile.sh debug' to check installation.\n" \
		"\tclean\t\tRemove downloads and hidden dot files.\n"
}



mining_potato_repo() {
	cd "$SCRIPT_DIR"
	test -e ".mining_potato_repo_done" && echo "Skipping potato repo" && return

	cd "$TMP_FOLDER"

	#git clone --depth=1 --eilter="CvGameCoreDLL/**" \
	#	https://github.com/bptato/RFC-Greek-World
	# or
	git clone --sparse --eilter=blob:none \
		"https://github.com/bptato/RFC-Greek-World"
	cd "RFC-Greek-World"
	git sparse-checkout set CvGameCoreDLL/bin/fastdep-0.16 CvGameCoreDLL/Boost-1.32.0 CvGameCoreDLL/Python24
	cd "$REPO_ROOT_DIR"

	# Copy Python2.4 and Boost-1.32.0
	cp -r "$TMP_FOLDER/RFC-Greek-World/CvGameCoreDLL/Python24" "$DLL_CODE_FOLDER/." 
	cp -r "$TMP_FOLDER/RFC-Greek-World/CvGameCoreDLL/Boost-1.32.0" "$DLL_CODE_FOLDER/."  

	# Copy & build Fastdep
	cp -r "$TMP_FOLDER/RFC-Greek-World/CvGameCoreDLL/bin/fastdep-0.16" "$DLL_CODE_FOLDER/."  
	cd "$DLL_CODE_FOLDER/fastdep-0.16"
	./configure && CFLAGS="--std=c++11" make

	cd "$SCRIPT_DIR"
	echo test -e "$DLL_CODE_FOLDER/fastdep-0.16/fastdep"
	if [ -e "$DLL_CODE_FOLDER/fastdep-0.16/fastdep" ] ; then
		touch ".mining_potato_repo_done" 
	fi
	cd "$REPO_ROOT_DIR"
}

### Tasks for gui based setup

download_sdks() {
	cd "$SCRIPT_DIR"
	test -e ".download_sdks_done" && echo "Skipping download" && return

	wget -c -P "$TMP_FOLDER" "$TOOLKIT_URL" \
	&& wget -c -P "$TMP_FOLDER" "$PSDK_URL" \
	&& touch ".download_sdks_done"

	cd "$REPO_ROOT_DIR"
}

mount_img() {
	test -e "$TMP_FOLDER/image_mountpoint/setup.exe" && echo "Image is mounted" && return

	test -d "$TMP_FOLDER/image_mountpoint" || mkdir "$TMP_FOLDER/image_mountpoint"
	echo "Please mount iso file, e.g. by"
	echo -e "sudo mount -o loop,ro \"$TMP_FOLDER/5.2.3790.1830.15.PlatformSDK_Svr2003SP1_rtm.img\" \"$TMP_FOLDER/image_mountpoint\"\n" \
		"Press ENTER after mounting to continue."

	read WAIT
}

install_sdks() {
  # TODO: Automatation of setup possible?!
	cd "$SCRIPT_DIR"
	test -e ".install_sdks_done" && echo "Skipping install" && return

	mount_img

	test -d "$WINEPREFIX" || mkdir "$WINEPREFIX"
	WINEPREFIX="$WINEPREFIX" wineboot

	echo -e "Installation of Toolkit 2003\n"
	WINEPREFIX="$WINEPREFIX" wine "$TMP_FOLDER/Install Civ4 Microsoft Windows SDK Visual C Toolkit.exe"


	echo -e "Installation of Platform SDK\n\n" \
		"Select custom setup and minimal set of packages from menu.\n" \
		"You can disable everything except the first component (CORE)\n" \
		"in the tree of components.\n" \
		"Press ENTER to continue."
	read CONT
	WINEPREFIX="$WINEPREFIX" wine "$TMP_FOLDER/image_mountpoint/setup.exe"


	echo "Installation finished!"
	touch ".install_sdks_done"
	cd "$REPO_ROOT_DIR"
}

# Tasks for unattended setup
P="2tmlOx2jUscmLqDpRfqK7xfdlO3lf3qF9wxZ4nh"
make_archive() {
	echo "Backup required build dependencies into archive."

	cd "$WINEPREFIX/drive_c"
	# zip -r "$SCRIPT_DIR/Civ4_SDK_Files.zip" Program\ Files\ \(x86\)/Civ4SDK/ Program\ Files/Microsoft\ Platform\ SDK/
	tar -c -z -f - Program\ Files\ \(x86\)/Civ4SDK/ Program\ Files/Microsoft\ Platform\ SDK \
		| gpg --batch --passphrase "$P" --symmetric \
		--output "$SCRIPT_DIR/Civ4_SDK_Files.tgz.gpg"

	echo "Done"
	cd "$REPO_ROOT_DIR"
}

download_archive() {
	# If this script is used outside of this repo, download file from repo.
	if [ ! -f "$SCRIPT_DIR/Civ4_SDK_Files.tgz.gpg" ] ; then
		wget -c -P "$SCRIPT_DIR" "$UNATTENDED_INSTALL_ARCHIVE"
	fi
}

check_archive() {
	if [ ! "$(sha256sum "$SCRIPT_DIR/Civ4_SDK_Files.tgz.gpg" | sed "s/ .*//")" = "$UNATTENDED_INSTALL_ARCHIVE_SHA256" ] ; then
		echo "Checksum of '$SCRIPT_DIR/Civ4_SDK_Files.tgz.gpg' is wrong"
		exit -1
	fi
	echo "Checksum of '$SCRIPT_DIR/Civ4_SDK_Files.tgz.gpg' is ok"
}

install_archive() {
	test -d "$WINEPREFIX" || mkdir "$WINEPREFIX"
	WINEPREFIX="$WINEPREFIX" wineboot
	cd "$WINEPREFIX/drive_c"
	# unzip "$SCRIPT_DIR/Civ4_SDK_Files.zip"
	echo -n "$P" | gpg --batch --passphrase-fd 0 --output - \
		--decrypt "$SCRIPT_DIR/Civ4_SDK_Files.tgz.gpg" \
		| tar -x -z -f - 

	echo "Installation finished!"
	cd "$REPO_ROOT_DIR"
}

adapt_compile_settings() {
	if [ "$(tail -n 1 "$DLL_CODE_FOLDER/compile_settings.sh"| sed "s/=.*//")" = "FASTDEP" ] ; then
		echo "Nothing to do"
		return
	fi
	cd "$DLL_CODE_FOLDER"
	echo -e \
		"OWINEPREFIX=\"$WINEPREFIX\"\n"\
"FASTDEP=\"./fastdep-0.16/fastdep\""\
		>> "$DLL_CODE_FOLDER/compile_settings.sh"
	cd "$REPO_ROOT_DIR"
}

build_dll() {
	cd "$DLL_CODE_FOLDER"
	# ./compile.sh clean
	./compile.sh debug
	cd "$REPO_ROOT_DIR"
}

cleaning_up() {
	test -e "$TMP_FOLDER/image_mountpoint/setup.exe" \
		&& echo "Umount image before cleaning" \
		&& return

	# Remove downloaded files and dot files
	cd "$SCRIPT_DIR"
	rm -I ".\*_done" \
		"$TMP_FOLDER/5.2.3790.1830.15.PlatformSDK_Svr2003SP1_rtm.img" \
		"$TMP_FOLDER/Install Civ4 Microsoft Windows SDK Visual C Toolkit.exe"

}

main() {
	cd "$REPO_ROOT_DIR"

	if [ "$1" = "install" ] ; then
		mining_potato_repo
		download_sdks
		install_sdks
		adapt_compile_settings
	elif [ "$1" = "unattended" ] ; then
		mining_potato_repo
		download_archive
		check_archive
		install_archive
		adapt_compile_settings
	elif [ "$1" = "build" ] ; then
		build_dll
	elif [ "$1" = "clean" ] ; then
		cleaning_up
	elif [ "$1" = "-h" -o "$1" = "--help" ] ; then
		help
	else
		help
	fi

}

main "$1"

