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
#define scroll_speed 3 ;lower is faster
#define space_dist 3 ;a 0 (space) char will be displayed as this +1 number of spaces, rather than the full 8 spaces
#define charno 7 ;number of chars to display - should reflect how many are in flash (including empty/space chars)
;note: the following registers are used as counters in loops:
;17,22,23,24

rcall init



mainloop:

	rcall scroll_left ;scroll text in and out of view

	ldi r24,50
	rcall wait_time ; wait a bit

	ldi	ZL,LOW(2*space_invader)	;load space invader into ram
	ldi	ZH,HIGH(2*space_invader)		
	rcall load_char
	rcall draw_ram ;draw space invader

	ldi r24,100
	rcall wait_time ; wait a bit

	rcall clear_ram ;erase
	rcall draw_ram

	ldi r24,50
	rcall wait_time ; wait a bit

	rjmp mainloop ;repeat


init:

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

scroll_left:
	ldi	ZL,LOW(2*text)		; initialize Z pointer
	ldi	ZH,HIGH(2*text)		; to pmem array address
	ldi r21,charno ; number of chars (excludes spaces) 
	char_loop:

		;first check if this char is 0 (space)
		mov r28,ZL ;save current pmem char ptr
		mov r29,ZH ;in ptr Y (r28 and r29)
		ldi r25,8 ; counter for 8 bytes in char
		space_check:
			lpm	r20,Z+ ; load value from pmem 
			cpi r20,0 
			brne not_space ;if the current row isnt 0 then just go straight onto scrolling as normal
			dec r25
			brne space_check
			ldi r25,space_dist ;if we got through the char and all is zero (space)
			rcall shift_space
			subi r28,-8 ; add 8 to restore old Z ptr value 
			subi r29,-8


		not_space:
		mov ZL,r28
		mov ZH,r29
		ldi r25,0 ; counter for columns
		col_loop:
			ldi r20,0 ; counter for rows
			ldi	XL,LOW(matrix)		; initialize pointer
			ldi	XH,HIGH(matrix)		; to matrix address in ram
			row_loop:
				inc r20
				ld r19,X	;load byte from ram to r19 
				lsl r19 ; shift left 
				lpm	r18,Z+ ; load value from pmem 
				mov r17,r25 ; shift same number of total times to where we are
				shift:
					cpi r25,0
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
			ldi r24,scroll_speed ;counter for wait_time / how long before each scroll step
			rcall wait_time
			subi	ZL,8		; initialize Z pointer
			subi	ZH,8		; to pmem array address
			inc r25
			cpi r25,8
			brne col_loop
			;add a space after every char
			ldi r25,1
			rcall shift_space
		subi ZL,-8 ;move Z ptr forward 8 to next char (neg subi = add)
		subi ZH,-8
		dec r21
		brne char_loop
		ldi r25,7
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
		ldi r24,scroll_speed ;counter for wait_time / how long before each scroll step
		rcall wait_time
		dec r25
		brne shift_loop
	ret

load_char:
	ldi	XL,LOW(matrix)		; initialize pointer
	ldi	XH,HIGH(matrix)		; to matrix address in ram
	ldi r17,8
	arrLp:	
		lpm	r16,Z+			; load value from pmem array
		st X+,r16			; store value to SRAM array
		dec	r17			; decrement loop count
		brne arrLp			; repeat loop for all bytes in array
	ret



draw_ram:
	ldi	XL,LOW(matrix)		; initialize pointer
	ldi	XH,HIGH(matrix)		; to matrix address in ram
	clr r18
	draw_loop:
		inc r18
		ld r19,X+
		rcall max_send
		cpi r18,8
		brne draw_loop
	ret

clear_ram:
	ldi XL,LOW(matrix); reset pointer to first matrix byte
	ldi XH,HIGH(matrix)
	ldi r17,8
	ldi r16,0
	clear_loop:
		st X+, r16
        dec r17
		brne clear_loop        ;    do it 8 times
	ret

clear_max:
	clr r18
	drw_loop:
		inc r18
		ldi r19,0
		rcall max_send
		cpi r18,8
		brne drw_loop
	ret


wait_time:
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


cs_high: 
	sbi PORTB, CS_PIN
	ret
cs_low:
	cbi PORTB, CS_PIN
	ret
clk_high:
	sbi PORTB, CLK_PIN
	ret
clk_low:
	cbi PORTB, CLK_PIN
	ret
data_high:
	sbi PORTB, DIO_PIN
	ret
data_low:
	cbi PORTB, DIO_PIN
	ret

max_write: ; param r16 input byte
	nop
	ldi r17,8 ;do this 8 times
	cycle:
		rcall clk_low
		nop
		sbrs r16,7 ;skip if bit 7 in register is set
		rcall data_low
		sbrc r16,7
		rcall data_high
		rcall clk_high 
		add r16,r16
		dec r17
		brne cycle
	ret


max_send: ; params r18 reg/row, r19 data
	rcall cs_high
	mov r16,r18
	rcall max_write
	mov r16,r19
	rcall max_write
	rcall cs_low
	nop
	rcall cs_high
	ret


text:   ;.db 0b11111111,0b10000001,0b10000001,0b11111111,0b10000001,0b10000001,0b10000001,0b10000001 ;A
		;.db	0b11111110,0b10000001,0b10000001,0b11111110,0b10000001,0b10000001,0b10000001,0b11111110 ;B
		;.db	0b11111111,0b10000000,0b10000000,0b10000000,0b10000000,0b10000000,0b10000000,0b11111111 ;C
		.db 0b11000011,\
		    0b11000011,\
			0b11000011,\
			0b11111111,\
			0b11000011,\
			0b11000011,\
			0b11000011,\
			0b11000011 ;H

		.db 0b01111110,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b01111110 ;I

		.db 0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000 ;space

		.db 0b11111111,\
			0b01111110,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b00011000,\
			0b00011000 ;T

		.db 0b11000011,\
			0b11000011,\
			0b11000011,\
			0b11111111,\
			0b11000011,\
			0b11000011,\
			0b11000011,\
			0b11000011 ;H

		.db 0b11111111,\
			0b11000000,\
			0b11000000,\
			0b11111110,\
			0b11000000,\
			0b11000000,\
			0b11000000,\
			0b11111111 ;E

		.db	0b11111110,\
			0b11000011,\
			0b11000011,\
			0b11111100,\
			0b11100110,\
			0b11000011,\
			0b11000011,\
			0b11000011 ;R

		.db 0b11111111,\
			0b11000000,\
			0b11000000,\
			0b11111110,\
			0b11000000,\
			0b11000000,\
			0b11000000,\
			0b11111111 ;E

space_invader:
	.db 0b00100100,0b10011001,0b10111101,0b11011011,0b11111111,0b01111110,0b00100100,0b01000010 
