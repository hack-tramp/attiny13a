# attiny13a

  ## 💾 MAX7219 8x8 LED Matrix 
*250 Bytes*  
Supports scrolling text effect and custom graphics - stored in flash


  ## 💾 LED - ISR 

Example of using timer interrupt to control LED

*These UART codes were tested on bluetooth (baud 9600) module HC-06, no noticeable loss*<br>

  ## 💾 UART - Polling and ISR 

Rx/Tx 'echo' example (140 bytes) based on [AVR305](https://ww1.microchip.com/downloads/en/AppNotes/doc0952.pdf) but :<br>

- Can handle whole strings rather than just 1 byte
- Stores data in RAM, null terminated
- Loops receiving bytes until 0x0D is detected, marking end of string
- Tx routine loops over bytes in RAM until nullbyte marking end of string
- ISR version handles all chars/bytes inside interrupt routine

 ## 💾 UART - SPM  

This allows you to write to flash memory via bluetooth. <br>
It is useful when you need more than the 64 bytes of RAM.<br>
*(make sure you have set the fuses first to allow writing to flash via SPM)*<br>

* UART 'mode' triggered by PCINT, ends after x ms
* Data sent in (max) 32 byte chunks during this mode is appended to flash (no overwrite)
* Chunks smaller than 32 bytes will result in RAM trash written to flash (so send that chunk last)
* 32 byte size is due to SPM limited to 32 byte pagesize on attiny13a per execution
* Code reserves 400 bytes flash for writing but this can be increased / decreased
* After every SPM attiny sends back flash contents for verification




