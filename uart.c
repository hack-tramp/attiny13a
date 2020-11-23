#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

#define    UART_RX_ENABLED        (1) // Enable UART RX
#define    UART_TX_ENABLED        (1) // Enable UART TX

#ifndef F_CPU
# define        F_CPU           (9600000UL) // 1.2 MHz
#endif  /* !F_CPU */

#if defined(UART_TX_ENABLED) && !defined(UART_TX)
# define        UART_TX         PB4 // Use PB4 as TX pin
#endif  /* !UART_TX */

#if defined(UART_RX_ENABLED) && !defined(UART_RX)
# define        UART_RX         PB3 // Use PB3 as RX pin
#endif  /* !UART_RX */

#if (defined(UART_TX_ENABLED) || defined(UART_RX_ENABLED)) && !defined(UART_BAUDRATE)
# define        UART_BAUDRATE   (9600)
#endif  /* !UART_BAUDRATE */

#define TXDELAY             (int)(246)
#define RXDELAY             (int)(246)
#define RXDELAY2            (int)(246)

#define   Buf_Size (uint8_t) 13                // Buffer Size for receiving        //
char   Rx_Buf[Buf_Size] = {'T','e','s','t','0','1','2','3','4','5',10,13,0}; // Buffer for receiving  //
volatile uint8_t  Rx_flags;         // [R0000000] Received flags register (highest bit is STOP-flag)  //

ISR(PCINT0_vect, ISR_NAKED) {                //  PCINT [0:5]   ( 114-120 bytes ) //
asm volatile( " push  r0            \n\t" //                  //
        " push  r1            \n\t" //                  //
        " in    r0,     0x3F    \n\t" //  Store SREG            //
        " push  r0            \n\t" //                  //
        " push  r18           \n\t" //  Store used registers          //
        " push  r26           \n\t" //  Store X             //
        " push  r30           \n\t" //  Store Z             //
        " clr   r1            \n\t" //  Bits counter            //
:::);                           //                  //
asm volatile( " add   %[end],   r30     \n\t" //  Set End-address of buffer       //
"Rx_Byte:"    " sbic  %[port],  %[Rx_line]  \n\t" //  START bit detector          //
        " rjmp  Exit_Receive      \n\t" //  EXIT receiver if START-bit is not detected  //
        " dec   r1            \n\t" //  Set Bits counter  mask to 0b11111111    //
"Delay_Rx:"   " mov   r0,     %[delay]  \n\t" //  Loop   for skipping current bit     //
"Do_Delay_Rx:"  " nop               \n\t" //               |      //
        " dec   r0            \n\t" //               |      //
        " brne  Do_Delay_Rx       \n\t" //  ______________________________|     //
#if UART_SPEED>115200                   //  Correction              //
        " nop               \n\t" //      for UART          //
        " nop               \n\t" //        speeds above      //
        " nop               \n\t" //            115200    //
#endif                            //                  //
        " lsr   r18           \n\t" //  Bit loader      ____________________  //
        " sbis  %[port],  %[Rx_line]  \n\t"   //  If RX-line up             | //
        " nop               \n\t" //    ... do delay              | //
        " sbic  %[port],  %[Rx_line]  \n\t"   //  else                  | //
        " ori   r18,    0x80    \n\t" //    ... set significant data bit        | //
        " lsr   r1            \n\t" //  Shift Bits-counter mask         | //
        " brne  Delay_Rx        \n\t" //  Repeat if Bits-counter mask is not zero__|  //
        " st    Z+,     r18     \n\t" //  Store current byte          //
        " cp    r30,    %[end]    \n\t" //  Overflow buffer control       //
        " breq  End_Receive       \n\t" //  Exit if reached end         //
        " mov   r0,     %[delay]  \n\t" //  Loop for skipping last bit  ________    //
"Skip:"     " nop               \n\t" //                |   //
        " nop               \n\t" //                |   //
        " dec   r0            \n\t" //                |   //
        " brne  Skip          \n\t" //  ___________________________________|    //
        " dec   r0            \n\t" //  r0 = 255              //
"Stop_Rx:"    " nop               \n\t" //  Loop   for skipping STOP-bit_______   //
        " dec   r0            \n\t" //                |   //
        " breq  End_Receive       \n\t" //  ___________________________________|    //
        " sbis  %[port],  %[Rx_line]  \n\t"   //  ... with finding new START bit    |   //
        " rjmp  Rx_Byte         \n\t" //                |   //
        " rjmp  Stop_Rx         \n\t" //  ___________________________________|    //
"End_Receive:"  " ldi   r18,    0x80    \n\t" //  Rx_flags  = 0x80          //
        " st    X,      r18     \n\t" //  Store Rx_flags            //
        " st    Z,      r0      \n\t" //  Zero string marker          //
"Exit_Receive:" //" ldi   r18,    0x20    \n\t" //  GIFR    = ( 1<<PCIF )     //
        //" out   0x3A,   r18     \n\t" //  (Reset all collected PCINT0 interrupts) // seems unneeded given PCIF is cleared when int routine is executed : see datasheet 9.3.3 
::[flag] "x" (&Rx_flags), [Buf]"z"(Rx_Buf), \
[Rx_line]"I"(UART_RX), [delay]"r"(RXDELAY), [end]"r"(Buf_Size), [port]"I" (_SFR_IO_ADDR(PINB)):"r18"); //
asm volatile( " pop   r30           \n\t" //  Restore Z             //
        " pop   r26           \n\t" //  Restore X             //
        " pop   r18           \n\t" //  Restore r18           //
        " pop   r0            \n\t" //  Restore SREG            //
        " out   0x3F,   r0      \n\t" //  Restore old SREG state        //
        " pop   r1            \n\t" //  Restore r1              //
        " pop   r0            \n\t" //  Restore r0              //
        " reti              \n\t" //  Exit Interrupt            //
:::);                           //                  //
} 

void Init_UART_Receiving()                  //            ( 12 bytes )  //
{                             //                  //
  GIMSK   = (1<<PCIE);                //  Enable External Interrupts        //
  PCMSK   = (1<<UART_RX);                 //  Enable accorded Interrupt (PCINT3)    //
  sei();                          //  Allow Interrupts            //
} 

int
main(void)
{

  DDRB   =  ( 0 << UART_RX ) | ( 1 << UART_TX );        //  Port Configuration          //
  PORTB |=  ( 1 << UART_TX );       
  Init_UART_Receiving();  
    //while(1){
    //  UART_Send("Hello World!\n");
    //  delay(1000);
    //}
  while(1){                       //                  //
    if ( Rx_flags & 0x80 ) {              //  Test receiving flag         //
      UART_Send("Received: ");             //  Send description          //
      UART_Send(Rx_Buf);                //  Send received buffer        //
      Rx_flags=0;                   //  Clear receiving flag          //
    } 
  }

}





void
UART_Send(char* text)
{
#ifdef    UART_TX_ENABLED


asm volatile( " cli               \n\t" //  Prevent Global Interrupts       //
"TX_Byte:"    " ld    r18,    Z+      \n\t" //  Load data byte for sending        //
        " cp    r18,    r1      \n\t" //  Compare with ZERO         //
        " breq  Exit_Transmit     \n\t" //  Exit if equal, EXIT transmitting      //
        " dec   r1            \n\t" //  Setup bits counter mask         //
        " cbi   %[port],  %[TX_line]  \n\t" //  Setup START bit           //
"Delay_TX:"   " mov   r0,     %[delay]  \n\t" //  Delay loop, forming bit delay on Tx line  //
"Do_Delay_TX:"  " nop               \n\t" //                 |  //
        " dec   r0            \n\t" //                 |  //
        " brne  Do_Delay_TX       \n\t" //  ________________________________________| //
"TX_Bit:"   " sbrc  r18,    0     \n\t"   //  Set current bit (0) on Tx line      //
        " sbi   %[port],  %[TX_line]  \n\t" //               |      //
        " sbrs  r18,    0     \n\t"   //               |      //
        " cbi   %[port],  %[TX_line]  \n\t" //  ______________________________|     //
        " lsr   r18           \n\t" //  Setup next bit for sending        //
        " lsr   r1            \n\t" //  Shift bits counter mask       //
        " brcs  Delay_TX        \n\t" //  If carry is NOT ZERO, continue sending  //
        " sbi   %[port],  %[TX_line]  \n\t" //  Set STOP bit on Tx line       //
        " mov   r0,     %[delay]  \n\t" //  Delay forming STOP bit on Tx line   //
"Stop_Bit_TX:"  " nop               \n\t" //                |   //
        " dec   r0            \n\t" //                |   //
        " brne  Stop_Bit_TX       \n\t" //  ___________________________________|    //
        " rjmp  TX_Byte         \n\t" //  Jump to next sending byte         //
"Exit_Transmit:"" sei               \n\t" //  Allow Global Interrupts       //
:: [Buf]"z"(text), [TX_line]"I"(UART_TX), [delay]"r"(TXDELAY), [port]"I"(_SFR_IO_ADDR(PORTB)):"r18");



#endif /* !UART_TX_ENABLED */
}
