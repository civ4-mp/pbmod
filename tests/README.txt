fix_upload_bug/watchdog:
	The pitboss server contains a bug which leads
	to very high bandwith usages.
 	This folder contailn server applications which 
	detect this bug and close the network connections.
	( It's fakes the disconnect messages of clients. )

	tests/watchdog is similar to tests/fix_upload_bug, but
	look for dead pitboss servers, too. Ignore this if
	you do not use a headless linux environment.


GetSaveOverHttp:
	Speed up the save game tranfer to lower the
	login times. ( Without these changes is the
	bandwidth limited to 10kb/s! )
	
	See: https://github.com/civ4-mp/save-over-http


Pyconsole:
	Allow remote access by a Python shell to a running PB game with the PB Mod.
  tests/Pyconsole contain a minimal standalone mod of this feature, but it
  is also integrated into the PB Mod_v7


Pylint_for_Civ4:
  Provides helpful list of classes/function stubs for Pylint. This gives Pylint
  or your text editor the capability to detect existing Civ4:SDK functions, etc.


Updater:
  Ingame mod updater component. A minimal working mod, Updater/Mods/Updater,
  and example server layout, Updater/server shows how automatic mod updating
  could be implemented.
  This feature is also integrated in PB Mod_v8.


Civ4BeyondSword2015.exe:
Civ4BeyondSword_Pitboss2014.exe:
	Modified executable where almost all gamespy domain names was replaced
	by a new domain. The new domain refers to Zulan's server which host
	a NAT service as gamespy replacement.
	This patch unlock the Direct IP mode again and fix statup issues of
	the Pitboss application, too.

	Data of Zulan's server:
	IP: 148.251.130.188
	DNS:
	civ4bts.natneg1.g.zulan.net
	civ4bts.natneg2.g.zulan.net
	civ4bts.natneg3.g.zulan.net
	civ4bts.available.g.zulan.net
	motd.g.zulan.net ( For http lookup. Server replies '404' )


Civ4BeyondSword2014.exe.patch:
	Open the command line and navigate to your BTS executeable.
	Create the patched EXE with
	bspatch Civ4BeyondSword.exe Civ4BeyondSword2014.exe Civ4BeyondSword2014.exe.patch

	Windows:
	Windows-Version of bsdiff is available here
	http://sites.inka.de/tesla/download/bsdiff4.3-win32.zip

	Linux:
	The default softwarerepository of your distrubution should
	contain the tool bspatch.

Civ4BeyondSword_Pitboss_Zulan.exe:
	Based on Civ4BeyondSword_Pitboss2014.exe, but fix save loading issue under Wine.
	If some of your saves not load, give this a try.
