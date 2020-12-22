;***************************************************************************
;*
;* Title: DivergenceClock.asm
;* Author: Daniel Gomm
;* Version: 1.0
;* Last updated: 1/1/2016
;* Target: ATmega16
;*
;* DESCRIPTION
;* 
;* This Program drives the nixie tube clock to be built for Carmen. It should 
;* have a total of 6 numeric displays that display, from left to right, the hours, 
;* minutes, and seconds of the current time. The system will have 3 buttons, which
;* are SET/ALM, INC, and DEC. For the alarm sound output, the circuit utilizes a
;* piezoelectric buzzer.
;*
;* Ports:
;* 
;* PORTA: OUTPUT
;* This port controls all of the IN-14 Nixie Tube displays
;*
;* PortB: INPUT / OUTPUT
;* This port reads in the input values from the three user input pushbuttons. Additionally PB3 is used as
;* the input for the external pulse generator coming from the ATTINY85. Setting PB4 to logic 1 initiates the
;* clock pulse start. PORTB also controls the ALARM_SET LED indicator on PB7. Note that as a multidirectional port, 
;* the sbi and cbi instructions must be used when using the ALM_SET LED. Writing directly to PORTB will disable 
;* the pullup resistors.
;*
;* PortC: N/A
;* This port is not used.
;*
;* PortD: OUTPUT
;* This port is used to sound the buzzer on PD7. It also controls the multiplexing of the
;* IN-14 Nixie Tube displays via the use of pnp transistors on PD0-PD6.
;*
;* VERSION HISTORY
;* 0.1 Tested the functionality of all circuit devices. All devices found to be working properly.
;* 0.2 Polished up delay subroutines and created the main program structure.
;* 0.3 Added in 7seg conversion subroutine. However need two digits for each value. Need to rework this approach to use BCD.
;* 0.4 Added a subroutine to utilize a BCD digit architecture. Register definitions were also edited to make this possible.
;* 0.5 Implemented a simple counter subroutine to test that all display values were correct. Device passed.
;* 0.6 PNP Transistor multiplexing hardware added. The display subroutine was implemented to use this hardware. Device passed all tests
;* 0.7 Multiple bugs fixed in the BCD subroutine related  to incorrect LSD counting past ten. Bug fix for "check_seconds".
;* 0.8 Similar bug related "check_seconds" bug on 0.7 fixed for "check_hours". Must check for max value before null return!
;* 0.9 Init boot subroutine implemented to set values for hours and seconds. Unit Passed all tests, and appears fully functional.
;* 1.0 Finished product. Alarm function implemented. Time setting indicators added to show which value is being edited by user.
;*
;* NX-1 Nixie Tube Clock
;***************************************************************************
 .nolist
 .include "m16def.inc"
 .list 

 ; ** REGISTER DEFINITIONS ** ;
 .def hours = r21
 .def minutes = r20
 .def seconds = r19

 .def hours_out = r23
 .def minutes_out = r24
 .def seconds_out = r25

 
 .def hours_out_L = r5
 .def hours_out_H = r4
 
 .def minutes_out_L = r3
 .def minutes_out_H = r2

 .def seconds_out_L = r1
 .def seconds_out_H = r0

 .def alm_hours = r7
 .def alm_minutes = r8
 
 .def tmp = r16
 .def tmp2 = r22

 .def tmrAlt = r6
 .def ALM_SET = r13

 ; ** PORT A INITIALIZATION ** ;
 ldi r16, $FF
 out DDRA, r16

 ; ** PORT B INITIALIZATION ** ;
 ldi r16, $90
 out DDRB, r16
 ldi r16, $07
 out PORTB, r16

 ; ** PORT D INITIALIZATION ** ;
 ldi r16, $FF
 out DDRD, r16

 ldi r17, $FF

 ; ** STACK POINTER INITIALIZATION ** ;
 ldi r16, high(RAMEND)
 out SPH, r16

 ldi r16, low(RAMEND)
 out SPL, r16

;***************************************************************************
;*
;* Boot Initialization -- Tests display devices and sets init values
;*
;* Description:
;* At boot, the system powers all numeric display modules and transistors. The
;* buzzer is also briefly sounded to ensure its operation. The device will then
;* greet the user and prompt them to set the desired time.
;*
;* Authors: Daniel Gomm
;* Version: 1.1
;* Last updated: 12/29/2015
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;* Parameters: 
;*
;* Returns:
;***************************************************************************
boot_chirp: 
	ldi r16, $80
	out PORTD, r16
	rcall short_chirp
	clr r16
	out PORTD, r16
	dec r17
	brne boot_chirp
 
 post_display:
	ldi r16, $7F
	out PORTD, r16
	ldi r16, $00
	out PORTA, r16
	sbi PORTB, 7
	rcall delay_sec
	clr r16
	out PORTD, r16
	out PORTA, r16
	cbi PORTB, 7
	rcall delay_sec
 
 init:
	sbi PORTB, 4
	clr hours
	ldi minutes, $00
	ldi seconds, $00
	ldi tmp, $08
	mov tmrAlt, tmp

	;          bafg.cde
	ldi tmp, 0b10110101
	mov hours_out_H, tmp

	;          bafg.cde
	ldi tmp, 0b01110011
	mov hours_out_L, tmp

	;          bafg.cde
	ldi tmp, 0b00100011
	mov minutes_out_H, tmp

	;          bafg.cde
	ldi tmp, 0b00100011
	mov minutes_out_L, tmp

	;          bafg.cde
	ldi tmp, 0b11100111
	mov seconds_out_H, tmp

	;          bafg.cde
	ldi tmp, 0b00000000
	mov seconds_out_L, tmp
 display_greeting1:
	rcall display_text
	in tmp2, PINB
	andi tmp2, $08
	cp tmp2, tmrAlt
	breq display_greeting1
	cp tmp2, tmrAlt
	brne done_greeting1
 done_greeting1:
 	mov tmrAlt, tmp2

 prompt_hours:
	;          bafg.cde
	ldi tmp, 0b00000000
	out PORTA, tmp
	ldi tmp, 0b00000011
	out PORTD, tmp
	rcall delay_sec
 setHours:
	sbis PINB, 0
	rjmp incHours
	sbis PINB, 1
	rjmp waitSetMins
	sbis PINB, 2
	rjmp decHours
	rcall display
	rjmp setHours
 incHours:
	cpi hours, $0C
	breq setHours
	inc hours
	rjmp waitIncHr
 decHours:
	cpi hours, $00
	breq setHours
	dec hours
	rjmp waitDecHr
 waitIncHr:
	sbic PINB, 0
	rjmp setHours
	rjmp waitIncHr
 waitDecHr:
	sbic PINB, 2
	rjmp setHours
	rjmp waitDecHr
 waitSetMins:
	sbic PINB, 1
	rjmp promptSetMins
	rjmp waitSetMins
 promptSetMins:
	;          bafg.cde
	ldi tmp, 0b00000000
	out PORTA, tmp
	ldi tmp, 0b00001100
	out PORTD, tmp
	rcall delay_sec
 setMins:
	sbis PINB, 0
	rjmp incMins
	sbis PINB, 1
	rjmp done
	sbis PINB, 2
	rjmp decMins
	rcall display
	rjmp setMins
 incMins:
	cpi minutes, $3C
	breq setMins
	inc minutes
	rjmp waitIncMins
 decMins:
	cpi minutes, $00
	breq setMins
	dec minutes
	rjmp waitDecMins
 waitIncMins:
	sbic PINB, 0
	rjmp setMins
	rjmp waitIncMins
 waitDecMins:
	sbic PINB, 2
	rjmp setMins
	rjmp waitDecMins
 done:

; ** CLEAR ALL NEEDED REGISTERS ** ;
clr tmp
clr tmp2
clr tmrAlt

clr seconds

clr hours_out_H
clr hours_out_L
clr minutes_out_H
clr minutes_out_L
clr seconds_out_H
clr seconds_out_L

clr hours_out
clr minutes_out
clr seconds_out

clr alm_hours
clr alm_minutes

rcall delay_sec
rcall chirp
inc seconds

; main loop
 main: 
	rcall check_seconds		;~2					;Update seconds value first.
	rcall check_hours		;~2
	rcall check_minutes		;~2
	rcall display
	rcall checkInput
	rcall poll_alm_status
	rjmp main

;***************************************************************************
;*
;* poll_alm_status -- check if the alarm should go off
;*
;* Description:
;* This subroutine checks to see if the alarm time is equal to the current time. If so, 
;* it will sound the alarm until the "set" button is pressed by the user. 
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: 1/1/2016
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;* Notes:
;* Possibly add a snooze button to this?
;***************************************************************************
 poll_alm_status:
	ldi tmp, $01
	cp ALM_SET, tmp
	breq poll_alm_hrs
	ret
 poll_alm_hrs:
	cp alm_hours, hours
	breq poll_alm_mins
	ret
 poll_alm_mins:
	cp alm_minutes, minutes
	breq alarm
	ret
 alarm:
	clr tmp2
 alarm_loop:
	cpi tmp2, $00
	breq up_freq
	cpi tmp2, $01
	breq down_freq
	cpi tmp2, $02
	breq mid_freq
	cpi tmp2, $03
	breq low_freq
 buzz:
	rcall check_seconds
	rcall check_minutes
	sbis PINB, 1					;need to make sure alarm can always be turned off.
	rjmp alm_return
	sbis PINB, 3
	rjmp buzz
	rcall alm_buzz
	clr ALM_SET
	cbi PORTB, 7
	inc tmp2
	sbis PINB, 1
	rjmp alm_return
	rjmp alarm_loop
 up_freq:
	ldi r17, $02
	rjmp buzz
 down_freq:
	ldi r17, $00
	rjmp buzz
 mid_freq:
	ldi r17, $01
	rjmp buzz
 low_freq:
	ldi r17, $07
	clr tmp2
	rjmp buzz
 alm_return:
	rcall delay_sec
	ret

;***************************************************************************
;*
;* checkInput -- Check if any pushbuttons are pressed
;*
;* Description:
;* This subroutine checks to see if any pushbuttons are pressed during the main
;* loop. The buttons have different functions when operating in the main loop.
;* inc = ALM_SET
;* set = RESET
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: 1/1/2016
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;* Notes:
;* The "dec" button does not have a function in the main loop and is not checked
;* by this subroutine.
;***************************************************************************
checkInput:
	sbis PINB, 0
	rjmp wait_alm_set
	sbis PINB, 1
	rjmp set_new_time
	ret
 set_alm:
	ldi tmp, $01
	cp ALM_SET, tmp
	breq alm_off
 alm_on:
	sbi PORTB, 7			;Turn on ALM_SET indicator
	mov ALM_SET, tmp
	rcall init_alm_set
	ret
 alm_off:
	clr ALM_SET
	cbi PORTB, 7			;turn off ALM_SET indicator
	ret
 wait_alm_set:
	sbic PINB, 0
	rjmp set_alm 
	rjmp wait_alm_set	
 set_new_time:
	rcall chirp
	rcall delay_sec
	rjmp prompt_hours

;***************************************************************************
;*
;* init_alm_set -- Set Alarm Time
;*
;* Description:
;* This subroutine allows the user to set a time for the alarm to go off.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: 1/1/2016
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;* Notes:
;***************************************************************************
init_alm_set:
	push hours
	push minutes

	clr hours
	clr minutes

	;          bafg.cde
	ldi tmp, 0b00000000
	out PORTA, tmp
	ldi tmp, 0b00000011
	out PORTD, tmp
	rcall delay_sec
	inc seconds

 alm_setHours:
	rcall check_seconds
	sbis PINB, 0
	rjmp alm_incHours
	sbis PINB, 1
	rjmp alm_waitSetMins
	sbis PINB, 2
	rjmp alm_decHours
	rcall display
	rjmp alm_setHours
 alm_incHours:
	cpi hours, $0C
	breq alm_setHours
	inc hours
	rjmp alm_waitIncHr
 alm_decHours:
	cpi hours, $00
	breq alm_setHours
	dec hours
	rjmp alm_waitDecHr
 alm_waitIncHr:
	sbic PINB, 0
	rjmp alm_setHours
	rjmp alm_waitIncHr
 alm_waitDecHr:
	sbic PINB, 2
	rjmp alm_setHours
	rjmp alm_waitDecHr
 alm_waitSetMins:
	sbic PINB, 1
	rjmp prompt_alm_setMins
	rjmp alm_waitSetMins

 prompt_alm_setMins:
	;          bafg.cde
	ldi tmp, 0b00000000
	out PORTA, tmp
	ldi tmp, 0b00001100
	out PORTD, tmp
	rcall delay_sec
	inc seconds

 alm_setMins:
	rcall check_seconds
	sbis PINB, 0
	rjmp alm_incMins
	sbis PINB, 1
	rjmp alm_set_done
	sbis PINB, 2
	rjmp alm_decMins
	rcall display
	rjmp alm_setMins
 alm_incMins:
	cpi minutes, $3C
	breq alm_setMins
	inc minutes
	rjmp alm_waitIncMins
 alm_decMins:
	cpi minutes, $00
	breq alm_setMins
	dec minutes
	rjmp alm_waitDecMins
 alm_waitIncMins:
	sbic PINB, 0
	rjmp alm_setMins
	rjmp alm_waitIncMins
 alm_waitDecMins:
	sbic PINB, 2
	rjmp alm_setMins
	rjmp alm_waitDecMins
 alm_set_done:
	mov alm_hours, hours
	mov alm_minutes, minutes

	pop minutes
	pop hours

	rcall delay_sec
	rcall chirp
	ret

;***************************************************************************
;*
;* testBtn -- Hardware test subroutine
;*
;* Description:
;* This subroutine sounds the buzzer if any button is pressed by the user.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;* Notes:
;* NOTE THAT THIS SUBROUTINE USER "tmp2" which is defined as r22. THIS SUBROUTINE
;* WILL REWRITE "alm" SINCE IT IS ALSO DEFINED AS r22 !!!
;***************************************************************************
 testBtn:
	in tmp, PINB
	andi tmp, $07
	cpi tmp, $07
	brlo goChirp
	ret
 goChirp:
	rcall chirp
	ret
 
;***************************************************************************
;*
;* testCounter -- Hardware test subroutine
;*
;* Description:
;* This subroutine counts to 9 and outputs each number to the displays for 1 second.
;* Once it reaches 9, it loops around and begins at zero again.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;***************************************************************************
 testCounter:
	cpi tmp2, $09
	breq clrRet
	inc tmp2
	rcall hex_2_7seg
	out PORTA, seconds
	rcall delay_sec
	ret
 clrRet:
	clr tmp2
	rcall hex_2_7seg
	out PORTA, seconds
	rcall delay_sec
	ret

;***************************************************************************
;*
;* check_hours -- Handles the hours value
;*
;* Description:
;* This subroutine updates the hours value appropriately
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: Usually 2
;* Low registers modified: none
;* High registers modified: none
;*
;***************************************************************************
 check_hours:
	cpi minutes, $3C				;1 cycle	;Check if minutes = 60
	breq inc_hours					;1 cycle	;If so, increment hours
	ret
 inc_hours:
	cpi hours, $0C								;if hours = 12, reset hours
	breq clr_hours					
	inc hours									;increment hours
	ret
 clr_hours:
	ldi hours, $01								;reset hours value back to 1
	ret											;return					

;***************************************************************************
;*
;* check_minutes -- Handles the minutes value
;*
;* Description:
;* This subroutine updates the minutes value appropriately
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: Usually 2
;* Low registers modified: none
;* High registers modified: none
;*
;***************************************************************************
 check_minutes:	
	cpi seconds, $3C							;check if seconds = 60
	breq inc_minutes							;if so,inc minutes
	cpi minutes, $3C							;check if minutes = 60
	breq clr_minutes							;if so, clear minutes, not inc
	ret
 inc_minutes:
	inc minutes
	ret
 clr_minutes:
	clr minutes									;clear minutes value
	ret											;return
 
;***************************************************************************
;*
;* check_seconds -- Handles the seconds value
;*
;* Description:
;* This subroutine updates the seconds value appropriately
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: Usually 2
;* Low registers modified: none
;* High registers modified: none
;*
;***************************************************************************
 check_seconds:
	cpi seconds, $3C
	breq clr_seconds
	in tmp, PINB
	andi tmp, $08
	cp tmp, tmrAlt
	breq return_null
	cp tmp, tmrAlt
	brne update
 update:
	inc seconds
	mov tmrAlt, tmp
	ret
 clr_seconds:
	clr seconds
 return_null:
	ret

;***************************************************************************
;*
;* chirp -- short buzzer chirp
;*
;* Description:
;* This subroutine plays a short chirp on the buzzer. Can be used to verify 
;* pushbutton presses.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: none
;*
;* Notes:
;* <Important info>
;*
;***************************************************************************
 chirp: 
	ldi r16, $80
	out PORTD, r16
	rcall short_chirp
	clr r16
	out PORTD, r16
	dec r17
	brne chirp
	ret
 
;***************************************************************************
;*
;* alm_buzz -- alarm noise
;*
;* Description:
;* This subroutine creates a load noise on the buzzer which is used for 
;* the alarm
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: 1/1/2016
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: r16 <tmp> ,r17
;*
;* Notes:
;* <Important info>
;*
;***************************************************************************
 alm_buzz:
	ldi tmp, $80
	out PORTD, tmp
	rcall alm_buzz_delay
	clr tmp
	out PORTD, tmp
	ret

;***************************************************************************
;*
;* display -- displays values of hours, minutes, and seconds 
;*
;* Description:
;* This subroutine displays the values of hours, minutes, and seconds to their respective displays.
;* It also handles the multiplexing of the 7seg display modules.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: tmp
;*
;* Parameters: 
;*
;* Returns:
;*
;* Notes:
;* <Important info>
;*
;***************************************************************************
 display:
	rcall bin2BCDAll
	rcall hex_2_7seg		;51 cycles

	ldi tmp, 0b00000001
	out PORTD, tmp
	out PORTA, hours_out_H 
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b00000010
	out PORTD, tmp
	out PORTA, hours_out_L
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b00000100
	out PORTD, tmp
	out PORTA, minutes_out_H
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b00001000
	out PORTD, tmp
	out PORTA, minutes_out_L
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b00010000
	out PORTD, tmp
	out PORTA, seconds_out_H
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b00100000
	out PORTD, tmp
	out PORTA, seconds_out_L
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

; ** RESET ALL OUTPUT TEMP VALUES ** ;
	clr hours_out_H
	clr hours_out_L
	clr minutes_out_H
	clr minutes_out_L
	clr seconds_out_H
	clr seconds_out_L

	clr hours_out
	clr minutes_out
	clr seconds_out

	ret
 
;***************************************************************************
;*
;* hex_2_7seg -- Converts hex values to their 7seg display equivalents
;*
;* Description:
;* This subroutine takes the hex values in hours, minutes, and seconds and converts them to their equivalent
;* display values on the 7seg display. The output values are stored in hours_out, minutes_out, and seconds_out.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: 12/20/2015
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 51
;* Low registers modified: hours_out, minutes_out, seconds_out
;* High registers modified: none
;*
;* Parameters: 
;* The values of time stored in the hours, minutes, and seconds registers
;* Returns:
;* 7seg display values in hours_out, minutes_out, and seconds_out
;*
;* Notes:
;* This subroutine does not edit the values of hours, minutes, or seconds. 
;* A value of $0A will return a zero value to the associated regs.
;*
;***************************************************************************
 hex_2_7seg:
	push r17						;2
	ldi r17, $00					;1
		
	; ** HOURS CONVERSION ** ;			/ ** 14 cycles ** /
	ldi ZH, high(hextable * 2)		;1
	ldi ZL, low(hextable * 2)		;1

	add ZL, hours_out_H				;1
	adc ZH, r17						;1

	lpm hours_out_H, Z				;3

	ldi ZH, high(hextable * 2)		;1
	ldi ZL, low(hextable * 2)		;1

	add ZL, hours_out_L				;1
	adc ZH, r17						;1

	lpm hours_out_L, Z				;3

	; ** MINUTES CONVERSION ** ;		/ ** 14 Cycles ** /
	ldi ZH, high(hextable * 2)		;1
	ldi ZL, low(hextable * 2)		;1

	add ZL, minutes_out_H			;1
	adc ZH, r17						;1

	lpm minutes_out_H, Z			;3

	ldi ZH, high(hextable * 2)		;1
	ldi ZL, low(hextable * 2)		;1

	add ZL, minutes_out_L			;1
	adc ZH, r17						;1

	lpm minutes_out_L, Z			;3

	; ** SECONDS CONVERSION ** ;		/ ** 14 Cycles ** /
	ldi ZH, high(hextable * 2)		;1
	ldi ZL, low(hextable * 2)		;1

	add ZL, seconds_out_H			;1	
	adc ZH, r17						;1

	lpm seconds_out_H, Z			;3

	ldi ZH, high(hextable * 2)		;1
	ldi ZL, low(hextable * 2)		;1

	add ZL, seconds_out_L			;1
	adc ZH, r17						;1

	lpm seconds_out_L, Z			;3

	pop r17							;2
	ret								;4

;Table of segment values to display digits 0 - F
;		       0    1    2    3    4    5    6    7    8  | 9    A    b    C    d    E    F
hextable: .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $00, $C0, $31, $97, $30, $38

;***************************************************************************
;*
;* "bin2BCDAll" - All values BCD conversion
;*
;* This subroutine takes the values of hours, minutes, and seconds and converts
;* them to BCD numbers spanned across hours_out_H:hours_out_L, minutes_out_H:minutes_out_L,
;* and seconds_out_H:seconds_out_L. 
;*
;* Low registers used	:r5-r0
;* High registers used  :hours_out, minutes_out, seconds_out, tmp
;*
;* Notes: 
;* This subroutine does NOT convert these numbers to output values. There is
;* another subroutine that is used for this.
;*
;***************************************************************************
bin2BCDAll:
	mov hours_out, hours			
	mov minutes_out, minutes		
	mov seconds_out, seconds		
hr2BCD:
	subi hours_out, 10	
	brcs min2BCD					
	inc hours_out_H
	rjmp hr2BCD
min2BCD:
	subi minutes_out, 10
	brcs sec2BCD
	inc minutes_out_H
	rjmp min2BCD
sec2BCD:
	subi seconds_out, 10
	brcs return
	inc seconds_out_H
	rjmp sec2BCD
 return:
	clr tmp
	; ** HOURS LOW BYTE ** ;
	mov tmp, hours
	cpi tmp, $0A				;if tmp >= 10, subtract ten
	brsh subHour
	cpi tmp, $0A				;if tmp < 10, 
	brlo loadHour
subHour:
	subi tmp, $0A
	cpi tmp, $0A
	brsh subHour
loadHour:
	andi tmp, $0F
	mov hours_out_L, tmp

	clr tmp
	; ** MINUTES LOW BYTE ** ;
	mov tmp, minutes
	cpi tmp, $0A
	brsh subMin
	cpi tmp, $0A
	brlo loadMin
subMin:
	subi tmp, $0A
	cpi tmp, $0A
	brsh subMin
loadMin:
	andi tmp, $0F
	mov minutes_out_L, tmp

	clr tmp
	; ** SECONDS LOW BYTE ** ;
	mov tmp, seconds
	cpi tmp, $0A
	brsh subSec
	cpi tmp, $0A
	brlo loadSec
subSec:
	subi tmp, $0A
	cpi tmp, $0A
	brsh subSec
loadSec:
	andi tmp, $0F
	mov seconds_out_L, tmp
	
	ret

;***************************************************************************
;*
;* display_text -- displays text based on values of hours, minutes, and seconds 
;*
;* Description:
;* This subroutine displays text on the 7seg displays based on the output temp 
;* values of hours_out_H:hours_out_L, minutes_out_H:minutes_out_L, and seconds_out_H:seconds_L. 
;* It is used to display messages at boot. Assumes the registers have already been given 
;* correct 7seg output values.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: 12/30/2015
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: r5-r0
;* High registers modified: tmp
;*
;* Parameters: 
;*
;* Returns:
;*
;* Notes:
;* THIS SUBROUTINE DOES NOT CALL "hex_2_7seg" OR "bin2BCDAll" !!!!
;*
;***************************************************************************
 display_text:
	ldi tmp, 0b01111110
	out PORTD, tmp
	out PORTA, hours_out_H 
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b01111101
	out PORTD, tmp
	out PORTA, hours_out_L
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b01111011
	out PORTD, tmp
	out PORTA, minutes_out_H
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b01110111
	out PORTD, tmp
	out PORTA, minutes_out_L
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b01101111
	out PORTD, tmp
	out PORTA, seconds_out_H
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ldi tmp, 0b01011111
	out PORTD, tmp
	out PORTA, seconds_out_L
	rcall chirp_delay
	clr tmp
	out PORTA, tmp

	ret

;***************************************************************************
;*
;* delay_sec -- Delays for one second
;*
;* Description:
;* This subroutine delays for approximately 1.02 seconds.
;*
;* Authors: Daniel Gomm
;* Version: 1.0
;* Last updated: <date>
;* Target: ATmega16 @ 1 MHz
;* Number of words: 
;* Number of cycles: 
;* Low registers modified: none
;* High registers modified: r16, r17, r18
;*
;* Parameters: none
;*
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
	ldi r17, $64								;re-load r17 with value of 100 so that inner_delay can be re-run.
	rjmp delay_loop								;restart at delay_loop
 ;delays for 0.102 s each iteration. We therefore need 10 iterations
 inner_delay:
	dec r17										;delay_loop is run 'r17' times
 ;delays for 0.00102 s  each iteration. We therefore need 1000 iterations 
 delay_loop:									
	inc r16										;1 cycle
	cpi r16, $FF								;1 cycle
	brne delay_loop								;2 cycles

	;inner delay check
	cpi r17, $00								;is r17 = 0?
	brne inner_delay							;if not, run delay loop again

	cpi r18, $00								;is r18 = 0?
	brne outer_delay							;if not, run outer delay again
	nop
	ret											;if yes, return.

 short_chirp:
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	ret

 alm_buzz_delay:
	clr r16
	dec r17										;delay_loop is run 'r17' times
 ;delays for 0.00102 s if r17 = $FF 
 alm_delay_loop:									
	inc r16										;1 cycle
	cp r16, r17							
	brne alm_delay_loop
	ret
 /*
	 !! SMALL DELAY USED FOR BOOT CHIRP. DO NOT EDIT !!
 */
 chirp_delay: 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 

	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
	nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop 
  
	ret