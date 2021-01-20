;based on https://embeddedthoughts.com/2016/05/27/attiny85-blinking-without-clock-cycles/
.include "tn13Adef.inc"
.org 0
	rjmp	init
	nop ; IRQ0 Handler
	nop ; PCINT0 Handler
	nop ; Timer0 Overflow Handler
	nop ; EEPROM Ready Handler
	nop ; Analog Comparator Handler
	rjmp TIMER0_COMPA ; Timer0 CompareA Handler
	nop ; Timer0 CompareB Handler
	nop ; Watchdog Interrupt Handler
	nop ; ADC Conversion Handler


.org 0x000A ; First address after interrupt vector table                       

TIMER0_COMPA:
;increase r16 
inc r16
cpi r16,255 ; if r16 is at 255, then run the LED code below
brne end_t0 ; if not, exit interrupt

;if on, turn off. if off, turn on
sbis PORTB, PB2 
rjmp turn_on
cbi PORTB, PB2
rjmp end_t0
turn_on:
sbi PORTB, PB2
end_t0:
reti


init: 
	ldi r16,0b10000000
	out TCCR0A,r16 ; Clear Timer on Compare match 

	ldi r16,255 ;  set the compare match value 
	out OCR0A,r16

	IN R16, TCCR0B			
	ORI R16, (1<<CS02) | (0<<CS01) | (1<<CS00) ;clk I/O /1024 (From prescaler)
	OUT TCCR0B, R16

	IN R16, TIMSK0		  ; set the Output Compare Interrupt Enable (OCIE0A) bit in the Timer/Counter Interrupt Mask Register (TIMSK0)
	ORI R16, (1<<OCIE0A)  ; to enable the timer compare match interrupt we will use
	OUT TIMSK0, R16
	clr r16
    sbi DDRB, PB2               ; PB2 as output
	sei
loop:

    rjmp loop					; loop back to beginning
