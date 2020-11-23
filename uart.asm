.include "tn13adef.inc"
.dseg
.org SRAM_START
tx_msg:	.byte	8	; text to be transmitted, stored in ram
.cseg
.org 0x00

#define UART_TX PB4 ; Use PB4 as TX pin
#define UART_RX PB3 ; Use PB3 as RX pin
#define RXPORT ((PORTB))
#define TXDELAY 246
#define RXDELAY 246
#define RXDELAY2 246

;DDRB   =  ( 0 << UART_RX ) | ( 1 << UART_TX )       //  Port Configuration          //
in r24, DDRB ; //  Load an I/O Location to Register r24 [ 1 CPU Cycle ]
ori r24, 0b00011000 ; // Logical OR r24 with Immediate value 0x1C [ 1 CPU Cycle ] 
out DDRB, r24 ; // Store Register r24 to I/O Location 0x04 [ 1 CPU Cycle ] 
sbi PORTB, UART_TX ;PORTB |=   1 << UART_TX 

ldi	ZL,LOW(tx_msg)	; initialize Z pointer
ldi	ZH,HIGH(tx_msg)	; to tx msg address
;put word 'hi' into RAM tx msg
ldi r18,0x68
st	Z+,r18
ldi r18,0x69
st	Z+,r18
ldi r18,0
st Z,r18

ldi r24,50
main_loop:

	rcall UART_Send

	rcall wait_time
	rjmp main_loop



UART_Send:
	ldi	ZL,LOW(tx_msg)	; initialize Z pointer
	ldi	ZH,HIGH(tx_msg)	; to tx msg address
	cli ;Prevent Global Interrupts
	TX_Byte:    
	ld    r18,    Z+    ;Load data byte for sending  
	cp    r18,    r1   ;Compare with ZERO
	breq  Exit_Transmit   ; Exit if equal, EXIT transmitting
	dec   r1           ;Setup bits counter mask        
	cbi   RXPORT,  UART_TX ;Setup START bit        
	Delay_TX:
		ldi r16,TXDELAY
		mov   r0,r16  ; Delay loop, forming bit delay on Tx line 
		Do_Delay_TX:
			nop   
			dec   r0           
			brne  Do_Delay_TX      
	TX_Bit:
	sbrc  r18,    0     ; Set current bit (0) on Tx line     
	sbi   RXPORT,  UART_TX  
	sbrs  r18,    0    
	cbi   RXPORT,  UART_TX
	lsr   r18           ; Setup next bit for sending      
	lsr   r1       ;  Shift bits counter mask      
	brcs  Delay_TX        ;  If carry is NOT ZERO, continue sending  
	sbi   RXPORT, UART_TX  ;  Set STOP bit on Tx line       
	mov   r0,     r16  ;  Delay forming STOP bit on Tx line   
	Stop_Bit_TX:
		nop              
		dec   r0           
		brne  Stop_Bit_TX     
	rjmp  TX_Byte       ;jump to next sending byte        
	Exit_Transmit:
	sei              ;Allow Global Interrupts    
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
