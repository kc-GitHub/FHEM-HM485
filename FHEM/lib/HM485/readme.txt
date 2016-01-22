HM585 - Modul for Homematic Wired (HM485) communication
=======================================================
Von Dirk Hoffmann <dirk@FHEM_Forum (forum.fhem.de)>
Weitergeführt von Thorsten Pferdekämper

Version: ...steht im Kopf der Datei 10_HM485.pm

HM485 ist ein Modul für FHEM um mit Homematic Wired Modulen komunizieren zu können.
Homematic Wired bassiert auf der RS485 Schnittstelle.

Fragen, Meinungen und Hinweise am besten im FHEM-Forum im Homematic-Bereich posten. 
Bitte dem Titel "[HM-Wired]" voranstellen.


History:
-----------

Die (neuere) Historie findet sich im Git:
https://github.com/kc-GitHub/FHEM-HM485/ (Master bzw. "stabile" Version)
https://github.com/kc-GitHub/FHEM-HM485/tree/dev (Development-Version)

		
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
