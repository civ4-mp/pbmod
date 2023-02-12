#!/bin/sh
#Author: bluepotato
#Settings for compile.sh; sourced on start

#Path to your wine 1.7.55 binary:
wine17="$HOME/.wine_versions/linux-x86/1.7.55/bin/wine"
wine17="wine"
#Path to your wine 1.7.55 wineprefix:
OWINEPREFIX="/data/software/Civ4/wine_for_sdk"
#Path to your platform SDK installation:
PSDK="C:/Program Files/Microsoft Platform SDK"
#Path to your VC++2003 toolkit installation:
VCTOOLKIT="C:/Program Files (x86)/Civ4SDK/Microsoft Visual C++ Toolkit 2003"
#Path to your Python 2.4 folder
PYTHON="./Python24"
#Path to your Boost 1.32.0 folder
BOOST="./Boost-1.32.0"
#Path to your patched fastdep binary:
FASTDEP="./bin/fastdep-0.16/fastdep" 
FASTDEP="../../SDK/fastdep/fastdep-0.16/fastdep"
#Whether compile.sh should spawn child processes to use all processing power:
PARALLEL=true
#Where to put the DLL:
OUTPUT="../PBMod_v10/Assets/CvGameCoreDLL.dll"
