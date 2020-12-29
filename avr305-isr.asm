
.include "tn13adef.inc"

.dseg
.org SRAM_START
msg:	.byte	20	; text to be transmitted, stored in ram


;***** Pin definitions

.equ RxD	=3			;Receive pin is PB3
.equ TxD	=4			;Transmit pin is PB4

;***** UART Rx/Tx delays

.equ tx_delay = 163
;Number of stop bits (1, 2, ...)
.equ		sb	=1		

;***** Global register variables

.def	bitcnt	=R16			;bit counter
.def	temp	=R17			;temporary storage register

.def	Txbyte	=R18			;Data to be transmitted
.def	RXbyte	=R19			;Received data



.cseg
.org 0
	rjmp	init
    nop     ; IRQ0
    rjmp PCINT      ; PCINT0 (pin INT0 to INT5) PCMSK, MCUCR


.org 0x000A ; First address after interrupt vector table





;***************************************************************************
;*
;* "putchar"
;*
;*
;***************************************************************************


putchar:	
	ldi	bitcnt,9+sb	;1+8+sb (sb is # of stop bits)
	com	Txbyte		;Inverte everything
	sec			;Start bit

putchar0:	
	brcc	putchar1	;If carry set
	cbi	PORTB,TxD	;    send a '0'
	rjmp	putchar2	;else	

putchar1:	
	sbi	PORTB,TxD	;    send a '1'
	nop

putchar2:	
	rcall UART_delay	;One bit delay 
	rcall UART_delay  

	lsr	Txbyte		;Get next bit
	dec	bitcnt		;If not all bit sent
	brne	putchar0	;   send next
				;else
	ret			;   return



UART_Send:
	ldi	ZL,LOW(msg)	; initialize Z pointer
	ldi	ZH,HIGH(msg)	; to tx msg address
	cli ;Prevent Global Interrupts	
	TX_Byte:    
		ld    r18,    Z+    ;Load data byte for sending  
		cpi    r18,    0   ;Compare with ZERO
		breq Exit_Transmit   ; Exit if equal, EXIT transmitting  
		rcall putchar
		rjmp  TX_Byte       ;jump to next sending byte        
	Exit_Transmit:
	sei              ;Allow Global Interrupts    
ret



;***************************************************************************
;*
;* "getchar"
;*
;***************************************************************************




PCINT:  
	in    r0,     0x3F    ;Store SREG          
	push  r0          
	ldi	ZL,LOW(msg)	; initialize Z pointer
	ldi	ZH,HIGH(msg)	; to tx msg address      
	    
	sbic 	PINB,RxD ;if line is low (0), continue as we have a startbit
	rjmp end_rx ;otherwise skip to end
	getchar:	ldi 	bitcnt,9	;8 data bit + 1 stop bit

	getchar1:	;sbic 	PINB,RxD	;Wait for start bit
			;rjmp 	getchar1

			rcall UART_delay	;0.5 bit delay

	getchar2:	
			rcall UART_delay	;1 bit delay
			rcall UART_delay		

			clc			;clear carry
			sbic 	PINB,RxD	;if RX pin high
			sec			;

			dec 	bitcnt		;If bit is stop bit
			breq 	getchar3	;   return
						;else
			ror 	Rxbyte		;   shift bit into Rxbyte
			rjmp 	getchar2	;   go get next

	getchar3:

		st Z+,Rxbyte 
		ldi Rxbyte,0x00 ; null terminated string
		st Z,Rxbyte
	
	       
	ldi r20, 0x80     ;  set rx flag 

	end_rx:
	pop   r0            ;  Restore SREG           
	out   0x3F,   r0        

reti   


;***************************************************************************
;*
;* "UART_delay"
;*
;* This delay subroutine generates the required delay between the bits when
;* transmitting and receiving bytes. The total execution time is set by the
;* constant "b":
;*
;*	3·b + 7 cycles (including rcall and ret)


.equ	b	= 163	;9600 bps @ 9.6 MHz crystal


UART_delay:	
	ldi	temp,b ;1c
UART_delay1:	
	dec	temp ;1c
	brne UART_delay1 ;1c
ret

uartd:
	dec	temp ;1c
	brne UART_delay1 ;1c
ret

;***** Program Execution Starts Here

;***** Test program

init:		

sbi	PORTB,TxD	;Init port pins
sbi	DDRB,TxD

;init for receiving
ldi r16,0b00100000 ;GIMSK   = (1<<PCIE);   Enable External Interrupts 
out GIMSK,r16
sbi PCMSK,RxD ;PCMSK   = (1<<RxD);    Enable accorded Interrupt (PCINT3) 
sei;   Allow Interrupts  


ldi r20,0 ; rx flag



;############################################
;;########### MAIN LOOP #####################
;############################################
main_loop:


	cpi r20,0x80 ;test rx flag
	brne main_loop
	rcall UART_Send 
	clr r20
rjmp main_loop
;############################################
;;########### MAIN LOOP #####################
;############################################

