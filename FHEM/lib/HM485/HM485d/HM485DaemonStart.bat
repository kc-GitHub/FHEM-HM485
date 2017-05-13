rem This is to start the HM485d daemon on windows systems.

set FHEMDir=%~dp0
cd /d "%FHEMDir%"

rem The following line needs to be changed to match reality.
perl HM485d.pl --hmwId 00000002 --serialNumber SGW0123456 --device COM11@19200 --localPort 2000 --verbose 5
pause