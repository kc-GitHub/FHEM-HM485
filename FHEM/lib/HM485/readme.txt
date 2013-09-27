HM585 - Modul for Homematic Wired (HM485) communication
=======================================================
Von Dirk Hoffmann <dirk@FHEM_Forum (forum.fhem.de)>

V 0.0.3

HM485 ist ein Modul für FHEM um mit den Homemaic Wired Modulen komunizieren zu können.
Homematic Wired bassiert auf der RS485 Schnittstelle.

History:
-----------
V0.0.1 - Initiale Version
V0.0.2 - Überarbeitete Version mit eigenem Prozess
V0.0.3 - Angepasste Verzeichnissstruktur für bessere Integration in FHEM

RS485 Hardware:
--------------
Derzeit benutzte und getestete RS485 Adapter:
- DIGITUS DA-70157: USB-Serial Adapter mit RS485 Schnittstelle, Funktioniert auch an der FritzBox
  http://www.reichelt.de/USB-Konverter/DIGITUS-DA-70157/3//index.html?ARTICLE=122187

- Wiznet - WIZ108SR Compact RS422/RS485-to-Ethernet module
  http://tigal.at/product/2276
  http://forum.fhem.de/index.php?t=msg&th=14096&start=0&rid=0

- HMW-LAN-GW (der Test ist noch nicht bestätigt)
  http://www.elv.de/homematic-rs485-gateway-1.html

- RS485 Tranceiver z.B. direkt am UART des Raspberry Pi angeschlossen
  http://forum.fhem.de/index.php?t=msg&th=12854&start=0&rid=42

Installation:
- Der Inhalt vom Branch kommt in das Verzeichniss /FHEM/

- Je nach verwendetem Interface existiert eine Beispiel cfg-Datei
	USB -> RS485 Konverter:      fhem_SERIAL.cfg
	Netzwerk -> RS485 Konverter: fhem_WIZ108SR.cfg
	HMW-LAN-GW:                  fhem_HMW-LAN-GW.cfg

### TODOs ###

- Hardware Protokoll (HM485d)

- FHEM-Intervace-Modul (00_HM485_LAN.pm)
	- discovery nur ausführen wenn das Interface verbunden ist
	- Timeout nach dem der Discovery-Mode automatisch abgebrochen wird.
	
	- ctrl-byte richtig setzen
	- txState für Line richtig setzen bzw. interpretieren
	- Beim RAW Senden ggf. fremde Absenderadressen angeben können bzw. verbieten
	- Firmwareupdate der Module
