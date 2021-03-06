#!/bin/bash
rm -rf *.PRG *.BIN
acme -f cbm -o VTUI0.8.BIN -l vtuilib-generic.lst vtuilib-generic.asm
acme -f cbm -o EXAMPL01.PRG example01.asm
acme -f cbm -o EXAMPL02.PRG example02.asm
acme -f cbm -o ACME-EX1.PRG acme-ex01.asm
acme -f cbm -o ACME-EX2.PRG acme-ex02.asm
cl65 -t cx16 -o CA65-EX1.PRG ca65-ex01.asm
