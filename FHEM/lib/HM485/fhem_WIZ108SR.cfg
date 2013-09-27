attr global logfile -
attr global modpath .
attr global motd ...
attr global statefile ./log/fhem.save
attr global userattr devStateIcon icon webCmd
attr global verbose 3

define telnetPort telnet 7073 global
define autocreate autocreate

define WEB FHEMWEB 8093 global
attr WEB plotmode SVG
attr WEB plotsize 800,240

### HM485 Interface (WIZ108SR)
#
define HM485_LAN HM485_LAN localhost:2000
attr HM485_LAN HM485d_device 192.168.178.15:5000
attr HM485_LAN hmwId 00000001
attr HM485_LAN HM485d_bind 1

# on slow servers like fritzbox or raspberry pi it should necessarry to increase this value
attr HM485_LAN HM485d_startTimeout 2

attr HM485_LAN room HM485
attr HM485_LAN HM485d_logVerbose 4

# Test webCmd
attr HM485_LAN webCmd RAW 000085CD 98 00000001 780F00:discovery start
