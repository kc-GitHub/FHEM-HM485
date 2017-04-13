#!/bin/bash
#convert the CCU Device-xmlfiles into FHEM Device-pm Haschfiles
./xmlHelper.pl -inputFile ../Devices/xml/*.xml -outputPath ../Devices
