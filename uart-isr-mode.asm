
.include "tn13adef.inc"

.dseg
.org SRAM_START
msg:	.byte	34	; allocate RAM space for UART data 


;***** Pin definitions

.equ RxD	= 3			;Receive pin is PB3
.equ TxD	= 4			;Transmit pin is PB4

;***** UART Rx/Tx delays

.equ tx_delay = 163
;Number of stop bits (1, 2, ...)
.equ		sb	= 1		

;***** Global register variables

.def	bitcnt	= R16			;bit counter
.def	temp	= R17			;temporary storage register

.def	Txbyte	= R18			;Data to be transmitted
.def	RXbyte	= R19			;Received data

;r20 flag - bit 0: rx flag, bit 1: mode flag
;r21 - used by interrupt timer because attiny13a prescaler is not enough

.cseg
.org 0
	rjmp init ;powerup / reset routine
    nop ; IRQ0
    rjmp PCINT ; PCINT0 (pin INT0 to INT5) PCMSK, MCUCR
	nop ; Timer0 Overflow 
	nop ; EEPROM Ready 
	nop ; Analog Comparator 
	rjmp TIMER0_COMPA ; Timer0 CompareA 




TIMER0_COMPA:
	;increase r21 
	inc r21
	cpi r21,50 ; if r21 is at ?, then run the code below
	brne end_t0 ; if not, exit interrupt

	clr r20 ;clear both rx and mode flags (rx should already be clear)

	out TIMSK0, r20 ;disable timer interrupt (use fact r20 is already cleared)

	end_t0:
reti


;***************************************************************************
;*
;* "putchar"
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

;***************************************************************************
;*
;* Send series of bytes from RAM
;*
;***************************************************************************


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
;* send first R22 bytes of flash_data
;*
;***************************************************************************

UART_Send_Flash:

	ldi ZL,LOW(2*flash_data) ;load the starting page address into Z
	ldi ZH,HIGH(2*flash_data)
	ldi r22, 100 ; first 100 bytes
	cli ;Prevent Global Interrupts	
	TX_Byte:    
		dec r22
		breq Exit_Transmit   ; Exit if equal, EXIT transmitting  
		lpm    r18,    Z+    ;Load data byte for sending
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
	    
	cbi PCMSK,RxD ; turn off PCINT
	getchar:	
			ldi bitcnt,9	;8 data bit + 1 stop bit
	getchar1:	
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
		cpi Rxbyte,0x0D ; check for carriage return byte
		breq exitrx ; if yes then end receiving
		;if not CR, do below:
		ldi bitcnt,9	;8 data bit + 1 stop bit
		sb_wait:	
			sbic PINB,RxD	;Wait for start bit
		rjmp sb_wait
		rjmp getchar1

	exitrx:
	ldi Rxbyte,0x0A ;add linebreak
	st Z+,Rxbyte 
	clr Rxbyte ; null terminated string
	st Z,Rxbyte
	
	sbr r20, 3 ;set both rx and mode flags -  bits 0 (rx) and 1 (mode) in r20 , binary/dec 11/3

	;enable timer interrupt
	ldi r16, 0b00000100 
	OUT TIMSK0, R16
	
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



;***************************************************************************
;*
;* SPM - Store Program Memory (flash)
;*
;***************************************************************************

;flash is arranged as 512x16 bits
;for attiny13A PAGESIZE = 16 (words) so PAGESIZEB = 32
;PAGESIZEB = PAGESIZE*2 ;PAGESIZEB is page size in BYTES, not words // 1 word = 2 bytes
write_page:	
	;cli
	ldi	YL,LOW(msg)	 ;initialize Y pointer
	ldi	YH,HIGH(msg) ;to ram

	ldi r16,0b00000011 ;this is the page erase command
	rcall do_spm

	;transfer data from RAM to Flash page buffer
	;ldi r17, 4 ;init loop variable
	;ldi loophi, high(PAGESIZEB) ;not required for PAGESIZEB<=256
	ldi r16,0b00000001 ;load the page buffer with r0:r1
	;ldi r21,0x55
	;ldi r22,0x56
	;mov r0,r21
	;mov r1,r22
	mov r21,ZL
	mov r22,ZH
	wrloop: 
		ld r0, Y+
		ld r1, Y+

		rcall do_spm
		adiw ZH:ZL, 2 ;since one word is being programmed, increment twice
		;sbiw loophi:looplo, 2 ;use subi for PAGESIZEB<=256
		dec r23 ; same as subi r17,2 when r17 is 32
		brne wrloop
	push ZL
	push ZH
	;execute page write
	mov ZL,r21
	mov ZH,r22
	ldi r16, 0b00000101 ;page write command
	rcall do_spm
	pop ZH
	pop ZL
	;sei
;return
ret

do_spm:
	;input: spmcrval determines SPM action
	;disable interrupts if enabled, store status

	;in r19, SREG
	cli
	;check for previous SPM complete
	;wait: 
	;	in r18, SPMCSR
	;	sbrc r18, SPMEN
	;	rjmp wait
	;SPM timed sequence
	out SPMCSR, r16
	spm
	;restore SREG (to enable interrupts if originally enabled)
	;out SREG, r19
	sei
ret



;***** Program Execution Starts Here

init:		

; flash end: 512 (dec) 0x200 (hex)
;note:  flash is word addressed, so 1KB flash , end address is 512 (x16 bits)
;important: flash data to use with SPM MUST be at start of a page, so position MUST be a multiple of the pagesize (16 for attiny13a)
; e.g. (dec) 128, 256 etc
.org 0x130 
;304 (dec) in words, so 608(dec) in bytes, so 608 bytes max allowed for code
;392 bytes / 196 words reserved for our flash_data
;max 12 pages

flash_data: ; reserve FLASH memory for data storage
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	;.dw  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

.org 0x000A ; First address after interrupt vector table, see datasheet 9.1


sbi	PORTB,TxD	;Init port pins
sbi	DDRB,TxD

;init for receiving
ldi r16,0b00100000 ;GIMSK   = (1<<PCIE);   Enable External Interrupts 
out GIMSK,r16
sbi PCMSK,RxD ;PCMSK   = (1<<RxD);    Enable accorded Interrupt (PCINT3) 

;TIMER 
ldi r16,0b10000000
out TCCR0A,r16 ; Clear Timer on Compare match 

ldi r16,255 ;  set the compare match value 
out OCR0A,r16

IN R16, TCCR0B	;clk I/O /1024 (From prescaler)		
ORI R16, (1<<CS02) | (0<<CS01) | (1<<CS00) 
OUT TCCR0B, R16

;clr r16 - shouldnt be needed as bitcnt is loaded before use in routines
;clr r21 - not needed as 0 on powerup


sei;   Allow Interrupts  

;clr r20 ; rx flag - not needed as 0 on powerup

;############################################
;;########### MAIN LOOP #####################
;############################################
main_loop:


	receiving_mode:
	sbrs r20,1 ;check mode flag
	rjmp not_receiving

	sbrs r20,0;check rx flag
	rjmp receiving_mode

	rcall UART_Send 
	cbr r20,1 ; clear rx flag

	wait_for_idle:
		sbis 	PINB,RxD	;Wait for idle bit
		rjmp 	wait_for_idle
	sbi PCMSK,RxD ;re-enable PCINT once idle bit detected

	rjmp receiving_mode

	not_receiving:

	;stuff we do outside the UART receiving mode:

	;ldi r18,0x6b
	;rcall putchar
	
	;ldi r22,255
	;ldi r23,255
	;extra_delay:
	;	dec r22
	;	brne extra_delay
	;	dec r23
	;	brne extra_delay


rjmp main_loop
;############################################
;;########### MAIN LOOP #####################
;############################################

