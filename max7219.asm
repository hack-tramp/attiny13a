.include "tn13adef.inc"
.dseg
.org SRAM_START
matrix:	.byte	8	;LED matrix in ram
.cseg
.org 0x00
#define MAX7219_REG_NOOP 0x00
#define MAX7219_REG_DIGIT0 0x01
#define MAX7219_REG_DIGIT1 0x02
#define MAX7219_REG_DIGIT2 0x03
#define MAX7219_REG_DIGIT3 0x04
#define MAX7219_REG_DIGIT4 0x05
#define MAX7219_REG_DIGIT5 0x06
#define MAX7219_REG_DIGIT6 0x07
#define MAX7219_REG_DIGIT7 0x08
#define MAX7219_REG_DECODEMODE 0x09
#define MAX7219_REG_INTENSITY 0x0A
#define MAX7219_REG_SCANLIMIT 0x0B
#define MAX7219_REG_SHUTDOWN 0x0C
#define MAX7219_REG_DISPLAYTEST 0x0F

#define DIO_PIN PB0 ; PB0 
#define CLK_PIN PB1 ; PB1 
#define CS_PIN PB2 ; PB2

#define scroll_speed 255 ;lower is faster, 255 max
#define space_byte 0xc2 ; when these 2 bytes are read from pmem/flash, it is treated as a space
;#define space_byte2 0xa0
#define end_byte 0x0d ;when this byte is read the text ends and scrolls out of view
;WARNING: as due to laziness only 1 endbyte is checked this means any character with a top byte of 0x0d(00001101) will be treated as the end
;same goes for spacebyte
#define space_dist 3 ;a space byte will be displayed as this +1 number of spaces, rather than the full 8 spaces

; the following registers are used for MAX7219:
;Z, Y, X, r16, r17, r18, r19, r20, r21, r22

;wait: r22,r17
;max send and write: r16,r17,r18,r19

rcall init



mainloop:

	rcall scroll_left ;scroll text in and out of view

	;ldi r24,50
	rcall wait_time ; wait a bit

	rjmp mainloop ;repeat


init:

	;Init port pins
	ldi r16,0b00000111
	out DDRB,r16



	ldi r18,MAX7219_REG_DECODEMODE
	ldi r19,0x00
    rcall max_send
	ldi r18,MAX7219_REG_SCANLIMIT
	ldi r19,0x07
    rcall max_send
	ldi r18,MAX7219_REG_INTENSITY
	ldi r19,0x0f
    rcall max_send
	ldi r18,MAX7219_REG_DISPLAYTEST
	ldi r19,0x00
    rcall max_send
	ldi r18,MAX7219_REG_SHUTDOWN
	ldi r19,0x01
    rcall max_send

	rcall clear_ram



ret

;uses: Z, Y, X, r20,r25,r17,r18,r19
;wait: r22,r17
;max send and write: r16,r17
scroll_left:
	ldi	ZL,LOW(2*text)		; initialize Z pointer
	ldi	ZH,HIGH(2*text)		; to pmem array address
	
	char_loop:
	
		clr r20 ; this is needed, lpm doesnt work properly if not
		lpm r20,Z
		cpi r20,space_byte ;first check if this char's first byte is a space byte
		brne normalchar ; if not just scroll as normal
		
		;if we got a space
		ldi r21,space_dist 
		rcall shift_space ; scroll space_dist
		adiw ZH:ZL,2 ;move Z up so we dont cover the space bytes again

		normalchar:

		ldi r21,0 ; counter for columns
		col_loop:
			ldi r20,0 ; counter for rows
			ldi	XL,LOW(matrix)		; initialize pointer
			ldi	XH,HIGH(matrix)		; to matrix address in ram

			row_loop:
				inc r20
				ld r19,X	;load byte from ram to r19 
				lsl r19 ; shift left 
				lpm	r18,Z+ ; load value from pmem 
				mov r17,r21 ; shift same number of total times to where we are
				shift:
					cpi r21,0
					breq no_shift
					lsl r18
					dec r17 ; use r17 as counter - also used in max_send
					brne shift
				no_shift:
				sbrc r18,7 ;add next bit from pmem/flash to end of byte
				ori r19,1 ;if it was set , set bit 0 to 1
				st X+,r19		;send that back to ram 
				mov r18,r20 ;re-use r18 , now as param for max_send
				rcall max_send ; send it to be drawn 
				cpi r20,8
				brne row_loop

			;ldi r24,scroll_speed ;counter for wait_time / how long before each scroll step
			rcall wait_time
			sbiw ZH:ZL,8 ; move Z 8 back/down to initial char pos
			inc r21
			cpi r21,8
			brne col_loop

			;add a space after every char
			ldi r21,1
			rcall shift_space
		adiw ZH:ZL,8 ;move Z ptr forward 8 to next char 
		;check if the next byte is the end byte
		clr r20
		lpm r20,Z
		cpi r20,end_byte
		brne char_loop ;if not, continue to next char
		ldi r21,7 ;final scroll off screen
		rcall shift_space
ret

shift_space: ; scroll left adding a space. param: r25, no. of spaces 
	;mov r17,r18 ;ldi r17,7
	shift_loop:
		ldi	XL,LOW(matrix)		; initialize pointer
		ldi	XH,HIGH(matrix)		; to matrix address in ram
		clr r18
		add_space:
			inc r18
			ld r19,X	;load byte from ram to r19 
			lsl r19 ; shift left 
			st X+,r19		;send that back to ram 
			rcall max_send ; send it to be drawn 
			cpi r18,8
			brne add_space
		;ldi r24,scroll_speed ;counter for wait_time / how long before each scroll step
		rcall wait_time
		dec r21
		brne shift_loop
ret



clear_ram:
	ldi XL,LOW(matrix); reset pointer to first matrix byte
	ldi XH,HIGH(matrix)
	ldi r16,8
	clear_loop:
		st X+, r17 ; use any cleared register, store in ram -this works only because max_send was just used so r17 is zero
        dec r16
		brne clear_loop        ;    do it 8 times
	ret



UART_delay:	
	ldi	r17,163 ;1c
UART_delay1:	
	dec	r17 ;1c
	brne UART_delay1 ;1c
ret

wait_time:
	clr r22
	wait_for_timer:
	inc r22
	rcall UART_delay ;this is ugly but avoids using more registers
	rcall UART_delay
	rcall UART_delay
	rcall UART_delay
	rcall UART_delay
	cpi r22,scroll_speed
	brne wait_for_timer
ret                     




max_write: ; param r16 input byte
	nop
	ldi r17,8 ;do this 8 times
	cycle:
		cbi PORTB, CLK_PIN ;clk low
		nop
		sbrs r16,7 ;skip if bit 7 in register is set
		cbi PORTB, DIO_PIN ; data low
		sbrc r16,7 ;skip if bit 7 in register is 0
		sbi PORTB, DIO_PIN ; data high
		sbi PORTB, CLK_PIN ; clk high
		add r16,r16
		dec r17
		brne cycle
	ret


max_send: ; params r18 reg/row, r19 data
	sbi PORTB, CS_PIN ; cs high
	mov r16,r18
	rcall max_write
	mov r16,r19
	rcall max_write
	cbi PORTB, CS_PIN ;cs low
	nop
	sbi PORTB, CS_PIN ; cs high
	ret


text:   .db 0b11111111,0b10000001,0b10000001,0b11111111,0b10000001,0b10000001,0b10000001,0b10000001 ;A
		.db 0xc2,0xa0 ;space
		.db	0b11111110,0b10000001,0b10000001,0b11111110,0b10000001,0b10000001,0b10000001,0b11111110 ;B
		.db	0b11111111,0b10000000,0b10000000,0b10000000,0b10000000,0b10000000,0b10000000,0b11111111 ;C
		.db 0x0d,0x0a ;end

