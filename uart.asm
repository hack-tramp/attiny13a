.include "tn13adef.inc"
.dseg
.org SRAM_START
;tx_msg:	.byte	8	; text to be transmitted, stored in ram
.cseg
.org 0      ; interrupt vector table
    nop     ; reset handler
    nop     ; IRQ0
    rjmp PCINT      ; PCINT0 (pin INT0 to INT5) PCMSK, MCUCR
    nop     ; Timer 0 overflow
    nop     ; EEPROM ready
    nop     ; Analog comparator
    nop     ; Timer 0 compare A
    nop     ; Timer 0 compare B
    nop     ; watchdog
    nop     ; ADC conversion  

.org 0x10

tx_msg:.db	"Hello!",0x0D,0x0A,0 ;0D+0A=CR+LF, also msg must be null terminated
RX_BUFF: .db 'T','e','s','t','0','1','2','3','4','5',10,13,0


#define UART_TX PB4 ; Use PB4 as TX pin
#define UART_RX PB3 ; Use PB3 as RX pin
#define TXPORT PORTB
#define RXPORT PINB
#define TXDELAY 246
#define RXDELAY 246
;#define RXDELAY2 246

#define RX_BUFF_SZ 13

;#define   Buf_Size (uint8_t) 13                // Buffer Size for receiving        //
;char   Rx_Buf[Buf_Size] = {'T','e','s','t','0','1','2','3','4','5',10,13,0}; // Buffer for receiving  //
;volatile uint8_t  Rx_flags;         // [R0000000] Received flags register (highest bit is STOP-flag)  //

;DDRB   =  ( 0 << UART_RX ) | ( 1 << UART_TX )       //  Port Configuration          //
;in r24, DDRB ; //  Load an I/O Location to Register r24 [ 1 CPU Cycle ]
;ori r24, 0b00011000 ; // Logical OR r24 with Immediate value 0x1C [ 1 CPU Cycle ] 
ldi r24,0b00011000
out DDRB, r24 ; // Store Register r24 to I/O Location 0x04 [ 1 CPU Cycle ] 
sbi PORTB, UART_TX ;PORTB |=   1 << UART_TX 

;init for receiving
;this is done 'manually' but ideally should be done using ori
ldi r16,0b00100000 ;GIMSK   = (1<<PCIE);                //  Enable External Interrupts        //
out GIMSK,r16
ldi r16,0b00001000;PCMSK   = (1<<UART_RX);                 //  Enable accorded Interrupt (PCINT3)    //
sei;                          //  Allow Interrupts            //

ldi	ZL,LOW(2*tx_msg)	; initialize Z pointer
ldi	ZH,HIGH(2*tx_msg)	; to tx msg address

ldi r24,50 ;param for wait_time
ldi r20,0 ;this is the RX_FLAG

;############################################
;;########### MAIN LOOP #####################
;############################################
main_loop:

	cpi r20,0x80 ;test rx flag
	brne if_zero

	rcall UART_Send
	clr r20
	rcall wait_time
	if_zero:
rjmp main_loop
;############################################
;;########### MAIN LOOP #####################
;############################################


PCINT:                ;//  PCINT [0:5]   ( 114-120 bytes ) //

push  r0  ;store r0
push  r1      
in    r0,     0x3F    ;Store SREG          
push  r0          
push  r18   ;Store used registers       
push  r26   ;Store X   
push  r30  ;Store Z             
clr   r1   ;Bits counter
            
ldi	ZL,LOW(2*RX_BUFF)	; initialize Z pointer
ldi	ZH,HIGH(2*RX_BUFF)	; to rx buffer address

ldi r16,RXDELAY
ldi r17, RX_BUFF_SZ
add   r17,   r30     ; //  Set End-address of buffer       //
Rx_Byte:       sbic  RXPORT,  UART_RX  ; //  START bit detector          //
        rjmp  Exit_Receive      ; //  EXIT receiver if START-bit is not detected  //
        dec   r1            ; //  Set Bits counter  mask to 0b11111111    //
Delay_Rx:     
		rcall uart_delay  ; //  Loop   for skipping current bit     //
        lsr   r18           ; //  Bit loader      ____________________  //
        sbis  RXPORT,  UART_RX  ;   //  If RX-line up             | //
        nop               ; //    ... do delay              | //
        sbic  RXPORT,  UART_RX  ;   //  else                  | //
        ori   r18,    0x80    ; //    ... set significant data bit        | //
        lsr   r1            ; //  Shift Bits-counter mask         | //
        brne  Delay_Rx        ; //  Repeat if Bits-counter mask is not zero__|  //
        spm    Z+,     r18     ; //  Store current byte          //
        cp    r30, r17        ; //  Overflow buffer control       //
        breq  End_Receive       ; //  Exit if reached end         //
        mov   r0,     r16  ; //  Loop for skipping last bit  ________    //
Skip:        nop               ; //                |   //
        nop               ; //                |   //
        dec   r0            ; //                |   //
        brne  Skip          ; //  ___________________________________|    //
        dec   r0            ; //  r0 = 255              //
Stop_Rx:       nop               ; //  Loop   for skipping STOP-bit_______   //
        dec   r0            ; //                |   //
        breq  End_Receive       ; //  ___________________________________|    //
        sbis  RXPORT,  UART_RX  ;   //  ... with finding new START bit    |   //
        rjmp  Rx_Byte         ; //                |   //
        rjmp  Stop_Rx         ; //  ___________________________________|    //
End_Receive:     ;ldi   r18,    0x80    ; //  Rx_flags  = 0x80          //
        ldi r20,      0x80     ; //  Store Rx_flags            //
        spm    Z,      r0      ; //  Zero string marker          //
Exit_Receive:  ;//  ldi   r18,    0x20    ; //  GIFR    = ( 1<<PCIF )     //
    ;//  out   0x3A,   r18     ; //  (Reset all collected PCINT0 interrupts) // seems unneeded given PCIF is cleared when int routine is executed : see datasheet 9.3.3 
;[flag]  x  (&Rx_flags), 
;[Buf] z (Rx_Buf), \
;[Rx_line] I (UART_RX), [delay] r (RXDELAY), [end] r (Buf_Size), [port] I  (_SFR_IO_ADDR(PINB)): r18 ); //

pop   r30           ; //  Restore Z             //
pop   r26           ; //  Restore X             //
pop   r18           ; //  Restore r18           //
pop   r0            ; //  Restore SREG            //
out   0x3F,   r0      ; //  Restore old SREG state        //
pop   r1            ; //  Restore r1              //
pop   r0            ; //  Restore r0              //

reti              ; //  Exit Interrupt            //






UART_Send:
	ldi	ZL,LOW(2*tx_msg)	; initialize Z pointer
	ldi	ZH,HIGH(2*tx_msg)	; to tx msg address
	cli ;Prevent Global Interrupts
	TX_Byte:    
		lpm    r18,    Z+    ;Load data byte for sending  
		cp    r18,    r1   ;Compare with ZERO
		breq  Exit_Transmit   ; Exit if equal, EXIT transmitting
		dec   r1           ;Setup bits counter mask        
		cbi   TXPORT,  UART_TX ;Setup START bit        
		Delay_TX:
			rcall uart_delay ; Delay loop, forming bit delay on Tx line     
		TX_Bit:
			sbrc  r18,    0     ; Set current bit (0) on Tx line     
			sbi   TXPORT,  UART_TX  
			sbrs  r18,    0    
			cbi   TXPORT,  UART_TX
			lsr   r18           ; Setup next bit for sending      
			lsr   r1       ;  Shift bits counter mask      
			brcs  Delay_TX        ;  If carry is NOT ZERO, continue sending  
			sbi   TXPORT, UART_TX  ;  Set STOP bit on Tx line       
			rcall uart_delay  ;  Delay forming STOP bit on Tx line   
			rjmp  TX_Byte       ;jump to next sending byte        
	Exit_Transmit:
	sei              ;Allow Global Interrupts    
ret





uart_delay:
	ldi r16,TXDELAY
	Do_Delay_TX:
		nop   
		dec   r16           
		brne  Do_Delay_TX     
ret

wait_time: ;r24 is param for amount of time to wait
	ldi r22,0                   ; these are timer counters
	ldi r23,0
	timer2:
		inc r22                     ; do 256 iterations - 1 clock
		brne timer2					; branch if not equal to beginning of timer2 - 1 clock * 256, then 1
		inc r23                     ; do 256 times - 1 clock
		brne timer2					; branch if not equal to beginning of timer2 - 1 clock * 256, then 1
		dec r24						; do x times - 1 clock
		brne timer2                 ; branch if not equal to beginning of timer2 - 1 clock * r24, then 1
ret                         ; once there have been 256 * 256 * r24 loops, return                      ; once there have been 256 * 256 * r24 loops, return
