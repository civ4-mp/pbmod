PBStats
=======

Mod for headless server hosting of Civ4:BTS Pitboss games. It allows an automated start and remote control of Pitboss servers.

Many host's of Civ4 Pitboss games knows that the Pitboss server contains many bugs
which made the hosting of your beloved game hard. This mod tries to solve some of this
problems. The Mod does not change any game mechanics.

Some example tasks which will be possible with this mod:
	* Reloading Saves
	* Changing timer of current turn or pause game
	* Complete or incomplete player turns
	* Changing password/color set of players
	* Remove signs of players
	* In game mod updater for players and PB server.
	* Allowing code changes on the server side **without** forcing players to update their mods.


Installation
=======

##A) As Player/User
Just download this Mod package and place the folder **PBMod_v10** in the mod folder of your Civ4:BTS installation ([Civ4 Installation Path]\Beyond the Sword\Mods ).
*Do not* place the folder into My Games\Beyond the Sword\Mods! Civ4 would interpret this as different version of the mod.
To start Civ4 with the modification create a new startup shortcut and extend the target with the mod-parameter. The result should look like
`[Your Civ 4 install folder]\Civ4\Beyond the Sword\Civ4BeyondSword.exe" mod= PBMod_v10"\"`

##B) As Pitboss Server Administrator.

This Mod package contains two components: **PBMod\_v10**, **PBs**
and can be combined with two other tools: **pbspy** and **pyconsole**

1. **PBMod\_v10** is the common mod folder. Place it in the mod folder of your Civ4:BTS installation.
2. The Pitboss server **must be started** with the ALTROOT parameter. Otherwise, some Python files can not be found! If you host multiple games on one machine you probably know this parameter...
The **PBs**-folder contains a prepared example for the start of the Pitboss server
with ALTROOT parameter. We recommend the usage of the startup script, see below.

The startup behavior of the pbmod can be controlled by configuration file *'pbSettings.json'* . If you like to
manage the server at run-time you probably want connect it to
a) a web-fronted, see https://github.com/civ4-mp/pbspy or
	Like civstats, this informs your players about the current game state and allows you to reload saves, change timers, etc.

b) an shell with full control over the game, see https://github.com/civ4-mp/pbconsole
  The shell also contain a list of predefined command to load/save games, etc.


Configuration of the ALTROOT Folder
=======

I assume here that you will start your Pitboss server with the ALTROOT argument.
First, note that this modification tries to load all preferences from
the config file **pbSettings.json** which is placed in the ALTROOT-directory.

Follow these steps to setup a new game:

0. Copy the **PBs** folder to your desired position.
Use this as root for your ALTROOT folders.

1. (Linux/Wine)
   * Open the script *'PBs/startPitboss.py'* and following the instruction to setup the environment variables.
	 (Adapting *'PBs/startPitbossEnv.py.example'*)
	 * Copy PBs/seed to PBs/PB1 to create your first instance.
	 * Start script with
	 `python3 startPitboss.py 1`
		Now, the example save should load and the PB window pops up.
    * Note that the startup of the Pitboss window is capsuled into a loop. Thus, the game will restart if you close the window. Use Ctrl+C to abort the script.
    * Set the autostart flag in **pbSettings.json** to 0 to setup a new game in the PB wizard dialog.
		If you protect your games with an *PB admin password* add it into **PBs/pbPasswords.json** or
		update the value in **pbSettings.json**.
		(I recommend to collect all game passwords in PBs/pbPasswords.json.  At startup, the server will find the correct one for the
	given save, if possible. Nervertheless you can still use the adminpw-field in pbSettings.json.)


2. (Windows)
For Windows users exists the script **startPitboss.bat**. The script contains two sample setups for the games 'PB1' and 'PB2'.
    * Open **startPitboss.bat** in a text editor and adapt the values of
_ALTROOT_BASEDIR=C:\PBStats\PBs_
_CIV4BTS_PATH=C:\Civ4\Beyond the Sword\_
    * Copy the folder PBs\seed to PBs\PB1 (and PBs\PB2, etc…).
    * Open PB1\CivilizationIV.ini and set the value of **PitbossSMTPLogin** to the full path of this directory, i.e. C:\PBStats\PBs\PB1. Without this information Civ4 can not find **pbSettings.json**!
    * Now, start the Batch-File and enter 1 to start PB1. The example save should load and the PB window pops up.
    * The startup is capsuled by a loop. Thus, the game will restart if you close the window. Use Ctrl+C to abort the script.
    * Set the autostart flag in **pbSettings.json** to 0 to setup a new game in the wizard dialog.
Update the saved password in **pbSettings.json**, if you active auto starting!

3. Setup of **pbSettings.json**
The most important values are
    * save.adminpw: Enter the admin password of your save game here. (This is the password which
normally should be entered in the Pitboss wizard at game loading.)
    * webserver.password: This password will be required to control this instance of the Pitboss server.
    * webserver.port: Use a unique value for each Pitboss instance.
    * webfrontent.url: This is the url which will be used to propagate the current status of the game.  Enter your web server here or use our service ( pb.zulan.net/pbspy ).
    * webfrontent.gameId: Create a game entry in the webfrontend to generate this id.

4. Create a game entry in the web interface. Your PB server should run if you register a new game.

5. (Optional) If you handle with different games or passwords you should edit the file PBs/pbPasswords.json and collect your passwords there. At startup, the server will find the correct one for the
	given save, if possible. Nervertheless you can still use the adminpw-field in pbSettings.json.


Extras
=======

We developed a few tools for Civ4:BTS players which are usable **without** this modification, too.

1. tests/fix_upload_bug contains a solution for the upload bug problematic of Pitboss servers. The executable (Windows) or Python script (Linux) will
analyze the traffic of your PB servers. If it detects that a client does not response but the server sends data, it will fake the reply of the client (to simulate a normal disconnection).
Development of the watchdog continues in a separate project:  https://github.com/civ4-mp/pb-watchdog

2. tests/Civ4BeyondSword2015.exe and tests/Civ4BeyondSword_Pitboss2014.exe
The shutdown of the Gamespy NATNEG Servers causes many issues for Multiplayer games. This was solved
by the community with open NATNEG servers for several games. We've patched the Civ4:BTS executable to
redirect you to a reliable and stable NATNEG server. The server is hosted for the next years by the well known community member *Zulan* of *civforum.de*.

If you do not want patch your executables you can also use the following entries in your hosts-File:
```
148.251.130.188 civ4bts.natneg1.gamespy.com
148.251.130.188 civ4bts.natneg2.gamespy.com
148.251.130.188 civ4bts.natneg3.gamespy.com
148.251.130.188 civ4bts.available.gamespy.com
```

Note that all players have to use the same NATNEG server.
Visit http://realmsbeyond.net/forums/showthread.php?tid=7123 (English) or
http://civ-wiki.de/wiki/Mehrspieler_(Civ4) (German) for more information.

3. The repo https://github.com/civ4-mp/save-over-http provides our solution for the incredible slow loading of
Pitboss games. We extended the Civ4:BTS executable and release the file transfer
from Civ4 to an external library (libcurl). The external library downloads the save
over http(s).

Information (German): https://civ-wiki.de/wiki/Pitboss_(Civ4)#Login_der_Spieler_beschleunigen
Prebuild binaries:  https://civ.zulan.net/pb/BTS_Wrapper_v9_with_gamespy_fix.zip

4. https://github.com/civ4-mp/mod-updater

5. Building DLL with Wine.
 Civfanatics user bluepotato wrote a script for compiling the DLL on Linux, see
 https://forums.civfanatics.com/threads/compiling-the-dll-on-linux.658833/

 We expanded this building script by an installation script of the required
 SDK files.
 To create a new wineprefix and downloading the required files, use. 
 ```test/sdk/setup_dll_build_with_wine.sh [install|unattended]
 ```

 Then, compile the DLL with
 ```CvGameCoreDLL/compile.sh [debug|release]
 ```
