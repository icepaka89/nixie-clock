/*
 * BOOST_CONVERTER_CONTROLLER.asm
 *
 *  Created: 12/3/2017 7:15:00 PM
 *   Author: icepaka89
 *  This program uses the internal Timer1/Counter1 of the ATTiny85 to output a signal with the desired duty cycle to the OC1B PWM pin (PB4)
 *  of the
 */ 

 .include "tn85def.inc"

 .org $0000

 setup:
	ldi r16, $FF
	out DDRB, r16				;PB as output pin
	ldi r16, 0b1000_0001		;set TCCR1 bits (prescalar, etc.)
	out TCCR1, r16				;load into TCCR1 reg
	ldi r16, 247				;SET DUTY CYCLE 245/255 = 96%
	out OCR1B, r16				;load into OCR0A compare reg
	ldi r16, 0b01010000
	out GTCCR, r16

main_loop:
	rjmp main_loop
