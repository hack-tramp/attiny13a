# attiny13a

<b>LED - ISR </b> <br>
Example of using timer interrupt to control LED

<b>UART (Polling and ISR) </b> <br>
Rx/Tx 'echo' example (140 bytes) based on AVR305 but :
- can handle whole strings rather than just 1 byte
- stores data in RAM, null terminated
- loops receiving bytes until 0x0D is detected, marking end of string
- Tx routine loops over bytes in RAM until nullbyte marking end of string
- ISR version handles all chars/bytes inside interrupt routine

tested on bluetooth (baud 9600) module HC-06, no noticeable loss / errors

https://ww1.microchip.com/downloads/en/AppNotes/doc0952.pdf
