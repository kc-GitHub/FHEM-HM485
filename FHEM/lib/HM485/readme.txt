HM585 - Modul for Homematic Wired (HM485) communication
=======================================================
Von Dirk Hoffmann <dirk@FHEM_Forum (forum.fhem.de)>.

V 0.5.140

HM485 ist ein Modul für FHEM um mit den Homemaitc Wired Modulen komunizieren zu können.
Homematic Wired bassiert auf der RS485 Schnittstelle.

	
	
Fragen, Meinungen und Hinweise bitte im Forum
http://forum.fhem.de/index.php?topic=10607.new;topicseen#new
posten



History:
-----------

V0.5.135 - Weitere Optimierung auch fuer unbekannte Module
V0.5.136 - Bereinigung Hardcodierung, 
		- Verbesserung Unterstuetzung fuer HMW_IO12_SW14_DR
		- Verbesserung Einlesen Optionen aus Config
		- Vereinfachung Programmcode
V0.5.137 - toggle für Schalter ( SubType = switch) wieder eingeführt
		- fehlerhafte Anzeige der Readigs bereinigt
		- Fehler in Device:getFrameInfos beseitigt press_long und press_short loesen wieder Event aus
		- event-min-interval fuer jeden Kanal separat eingefuehrt
V0.5.138 - Fuer HMW-Sen-SC-12-DR on und off getauscht
		- Beseitigung Fehler bei Config- Optionen
		- Ansteuerung HMW_IO12_SW14_DR.frequency uebernommen
		- Verbesserung Autostart
		- Entfernen von stateFormat
V0.5.139 - Attribute werden bei der automatischen Erkennung nur noch gesetzt, wenn sie vorher noch
			nicht definiert worden sind
		- Fehler in Device.pm Zeile 879 korrigiert
		- allgemeine Aenderungen von Ralf und Harald eingearbeitet/ Peering noch nicht aktiv
		- Initialisierungsvorgang optimiert
V0.5.140 - Initialisierungsvorgang weiter optimiert
		- allgemeine Fehler in Device.pm und 10_HM485.pm beseitigt
V0.5.141 - event-on-change-reading eingefuehrt, Beispiel: attr <name des Channels> event-on-change-reading press_long
		- Fehler beim Einlesen der Config bei konfigurierbaren Ein-/Ausgaengen beseitigt
		- on-for-timer fuer Channels vom Typ switch hinzugefuegt
		- Fehler bei State Anzeige von HMW_IO12_SW14_DR Channel 15-20 und 21-26 beseitigt
		



Erklaerung aktuelle Verionsbezeichnung
	erste Ziffer
	0 : nicht alle Module werden unterstuetzt
	zweite Ziffer
	1 : 1. Modul wird voll unterstuetzt : HMW_LC_Bl1
	2 : 2. Modul wird voll unterstuetzt : HMW_Sen_SC_12
	3 : 3. Modul wird voll unterstuetzt : HMW_LC_Dim1L
	4 : 4. Modul wird voll unterstuetzt : HMW_IO_12_Sw7
	5 : 5. Modul wird voll unterstuetzt : HMW_IO_12_FM
	dritte Ziffer
	13x : Nummer der aktuellen Testversion

RS485 Hardware:
--------------
Derzeit benutzte und getestete RS485 Adapter:
- DIGITUS DA-70157: USB-Serial Adapter mit RS485 Schnittstelle, Funktioniert auch an der FritzBox
  http://www.reichelt.de/USB-Konverter/DIGITUS-DA-70157/3//index.html?ARTICLE=122187

- Wiznet - WIZ108SR Compact RS422/RS485-to-Ethernet module
  http://forum.fhem.de/index.php/topic,14096.msg88557.html#msg88557

- HMW-LAN-GW
  http://www.elv.de/homematic-rs485-gateway-1.html

- RS485 Tranceiver z.B. direkt am UART des Raspberry Pi angeschlossen
  http://forum.fhem.de/index.php/topic,12854.msg77861.html#msg77861

Installation:
- Der Inhalt vom Branch kommt in das Verzeichniss /FHEM/

- Je nach verwendetem Interface existiert eine Beispiel cfg-Datei
	USB -> RS485 Konverter:      fhem_SERIAL.cfg
	Netzwerk -> RS485 Konverter: fhem_WIZ108SR.cfg
	HMW-LAN-GW:                  fhem_HMW-LAN-GW.cfg

### TODOs ###

- Hardware Protokoll (HM485d)

- FHEM-Interface-Modul (00_HM485_LAN.pm)
	- discovery nur ausführen wenn das Interface verbunden ist
	
	- ctrl-byte richtig setzen
	- txState für Line richtig setzen bzw. interpretieren
	- Beim RAW Senden ggf. fremde Absenderadressen angeben können bzw. verbieten
	- Firmwareupdate der Module

- FHEM-Device-Modul (10_HM485.pm)
	- States richtig verarbeiten
	- Channel-Peering
	- Device- / Channel-Settings