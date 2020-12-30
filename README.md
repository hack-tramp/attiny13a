# attiny13a
various programs for attiny13a

<b>UART </b> <br>
Rx/Tx 'echo' example (140 bytes) based on AVR305 but :
- can handle whole strings rather than just 1 byte
- stores data in RAM, null terminated
- loops receiving bytes until 0x0D is detected, marking end of string
- Tx routine loops over bytes in RAM until nullbyte marking end of string

tested on bluetooth (baud 9600) module HC-06, no noticeable loss / errors

https://ww1.microchip.com/downloads/en/AppNotes/doc0952.pdf
