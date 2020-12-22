;***************************************************************************
;*
;* Title: CLOCK_TIMER.asm
;* Author: Daniel Gomm
;* Version: 0.2
;* Last updated: 12/28/2015
;* Target: ATmega16
;*
;* DESCRIPTION
;* 
;* This Program utilizes an ATTINY85 chip to create a timer pulse that goes off
;* in one second intervals. This program can be used to drive clocks.
;*
;* Ports:
;*
;* PortB: INPUT / OUTPUT / ISP
;* This port reads in the init value of logic 1 on PB3. This starts the timer, which 
;* outputs the pulses on PB4. On boot, the program supports illuminating a status LED on PB1.
;* The programmer is also connected to this port.
;*
;* VERSION HISTORY
;* 0.1 Implemented full program that alternates values each second. Tests with the ATMega16a show correct operation.
;* 0.2 Timer was giving signals that were slightly longer than 1 second. Values adjusted to keep proper time.
;*
;* NX-1 Nixie Tube Clock Timer
;***************************************************************************
.nolist
.include "tn85def.inc"
.list

ldi r16, $13
out DDRB, r16

; ** STACK POINTER INITIALIZATION ** ;
ldi r16, high(RAMEND)
out SPH, r16

ldi r16, low(RAMEND)
out SPL, r16

init:
	cbi PORTB, 1
	rcall delay_sec
	sbi PORTB, 1
	rcall delay_sec
	cbi PORTB, 1
waitForStart:
	sbis PINB, 3
	rjmp waitForStart
	sbi PORTB, 1
main:
	sbi PORTB, 4
	sbi PORTB, 1
	rcall delay_sec
	cbi PORTB, 4
	cbi PORTB, 1
	rcall delay_sec
	rjmp main

;****************************************************************************
;*
;* delay_sec -- Delays for one second
;*
;* Description:
;* This subroutine delays for approximately 1.02 seconds.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATTINY85 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: r16, r17, r18
;*
;* Parameters: none
;*
;* Notes: This subroutine van be made into a variable delay if r18 is not set
;* but instead used as a parameter.
;*
;***************************************************************************
 delay_sec:
	clr r16
	ldi r17, $64								;load r17 with a value of 100
	ldi r18, $0A								;load r18 with a value of 10
	rjmp delay_loop								;begin at delay_loop
 ;delays for 1.02 s each iteration.
 outer_delay:
	dec r18										;inner_delay is run 'r18' times
	ldi r17, $5C								;re-load r17 with value of 100 so that inner_delay can be re-run.
	rjmp delay_loop								;restart at delay_loop
 ;delays for 0.100 s each iteration. We therefore need 10 iterations
 inner_delay:
	dec r17										;delay_loop is run 'r17' times
	clr r16
 ;delays for 0.001 s  each iteration. We therefore need 1000 iterations 
 delay_loop:									
	inc r16										;1 cycle
	cpi r16, $FA								;1 cycle
	brne delay_loop								;2 cycles

	;inner delay check
	cpi r17, $00								;is r17 = 0?
	brne inner_delay							;if not, run delay loop again

	cpi r18, $00								;is r18 = 0?
	brne outer_delay							;if not, run outer delay again
	nop
	ret											;if yes, return.