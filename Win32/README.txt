Steps to getting a working Windows-based buildslave for MythTV:

1) Have a Windows (NT4 and newer) box with at least 1GB of RAM (2GB is even
   better), and at least 5-10GB free disk.

1) Download and install the latest mingw-get-inst from:
http://sourceforge.net/projects/mingw/files/Automated%20MinGW%20Installer/mingw-get-inst/

2) Install it, using the latest catalog, be sure to add:
	C++, MSYS basic system, MinGW Developer Toolkit

3) Take note of the install directory of MinGW and Msys
   (by default C:\MinGW and C:\MinGW\msys\1.0)

4) Download and install Git for windows (latest one called Git-*.exe) from:
http://code.google.com/p/msysgit/downloads/list?can=3

5) Take note of the install directory
   (by default C:\Program Files\Git)

6) Download and install glib, gettext-runtime and pkg-config from:
http://www.gtk.org/download/win32.php (you want the Tool for pkg-config, 
Run-time for GLib, gettext-runtime)

Install the files from bin into the MinGW/bin dir (C:\MinGW\bin) and from share
into MinGW/share

7) Install Python (python-2.6.4.msi) from:
http://www.python.org/download/

8) Take note of the install directory
   (by default C:\Python26)

9) Install pywin32 (latest py2.6 build) from:
https://sourceforge.net/projects/pywin32/files/

10) Install Twisted (latest py2.6 build) from:
http://twistedmatrix.com/trac/wiki/Downloads

11) Install Buildbot (0.8.4p2) from:
http://sourceforge.net/projects/buildbot/files/

12) Open a MSYS shell, and create a base directory for your buildslave.  I used
    D:\buildbot, but you put it where you want (make sure you have 5-10G space
    available)

13) Add to the system environment (in the advanced system settings):
	PATHEXT - add ;.PY to the end
	PATH - add (separated by ;):
		from 3):  C:\MinGW\bin;C:\MinGW\msys\1.0\bin
		from 5):  C:\Program Files\Git\bin
		from 7):  C:\Python26;C:\Python26\Scripts
		from 11): D:\buildbot\mythtv\common
	MACHTYPE = i686-pc-msys (likely have to create this one)

14) Extract the Buildbot zip and run (from a new MSYS shell)
	python setup.py install

15) obtain a slave name/password from the MythTV development team

16) create an ssh key and send the public key to the MythTV development team.
	ssh-keygen -t dsa -b 2048  (use an empty passphrase)

17) using that key, ssh git@code.mythtv.org (accept the host key), and it
    should show you have read access to buildbot-config repo

18) copy the id_dsa, id_dsa.pub and known_hosts file from ~/.ssh to 
    C:\Program Files\Git\.ssh (create the directory if you need to)

19) go to your buildbot base dir from 11), and run
	buildslave create-slave mythtv code.mythtv.org:9989 slavename passwd

20) cd mythtv/info, edit both files.  The "admin" file should contain your real
    name and email, the "host" file is a description of your slave (suggested
    to put in there the version of Windows, how much RAM, base hardware, etc)

21) create a new directory (I used D:\MythTV), cd to it, and do:
	git clone git@alcor.mythtv.org:buildbot-config

22) go back to your buildbot directory... (cd /d/buildbot/mythtv) and do:
	cp -prv /d/MythTV/buildbot/Win32/ common/

23) if you want to manually start the buildslave, create a new shortcut on your
    desktop with the target being D:\buildbot\mythtv\common\buildslave.bat, and
    the "Start in" set to C:\MinGW\msys\1.0.  If you used any other path than
    D:\buildbot, you will need to edit that file and change the paths (at the
    end of the batch file).

24) If you want ccache (and you likely do):  Open an MSYS shell, and
	git clone git://github.com/ramiropolla/ccache.git
	cd ccache
	./autogen.sh
	./configure
	make
	cp ccache.exe /mingw/bin

25) if you want to automatically start it...  I'm sure there's a way, I haven't
    figured that part out yet.
