; Clock Frequency set to 8MHz

/*
Connections -
	PA0/ADC0 - Sine wave generator
	PB0 :: PB7 - A8 :: A1 of DAC0808
*/

/*

MATLAB FDATool Parameters -
Equiripple FIR
Order = 5
Density Factor = 20
Fs = 8KHz
Fpass = 100Hz
Fstop = 1000Hz

Original Coefficients -
0.155304109165325388008938034545280970633
0.113741106353925161553952705162373604253
0.130326902710015513076058368824305944145
0.130326902710015513076058368824305944145
0.113741106353925161553952705162373604253
0.155304109165325388008938034545280970633

Magnitude Response -
	100Hz = -1.9dB
	1000Hz = -13.8dB
	1200Hz = -27.2dB
	1268Hz = -66.6dB
*/

.INCLUDE "M32ADEF.INC"

.ORG 0

.EQU H0 = 40
.EQU H1 = 29			; original cofficients multiplied by 255
.EQU H2 = 33	
.EQU H3 = 33	
.EQU H4 = 29	
.EQU H5 = 40	

RJMP MAIN

.ORG 0x014
	JMP TIMER_INT_HANDLER	; Timer driven interrupt used to start ADC Conversion
.ORG 0x020				
	JMP ADC_INT_HANDLER		; ADC Interrupt to signal end of conversion

MAIN:

	; Stack Initialization
	LDI R16,HIGH(RAMEND)
	OUT SPH,R16
	LDI R16,LOW(RAMEND)
	OUT SPL,R16

	; Set Port B Output and Port A Input
	LDI R16,0XFF
	OUT DDRB,R16
	LDI R16,0
	OUT DDRA,R16

	; ADC Initialization
	LDI R16,0b10001110	; ADC Enable (ADEN) 1, ADC start conversion (ADSC) 0, ADC Auto trigger 0, ADC Interrupt Flag 0, ADC Interrupt Enable 1, ADPS 110 = C/64
	OUT ADCSRA, R16		; ADC Clock = 8MHz/64 = 125KHz (Maximum allowable clock = 200KHz); Maximum Sampling Rate = 125/13 = 9.6KHz (ADC requires 13 clock cycles)
	LDI R16, 0b11100000	; REFS 11 (Int 2.56V), ADLAR 1 (left adjust), MUX 00000 (ADC0)
	OUT ADMUX, R16
	SEI					; Global Interrupt Enable

	; Computation register initialization
	LDI R22, 0x00
	LDI R23, 0x00
	LDI R24, 0x00
	LDI R25, 0x00
	LDI R26, 0x00
	LDI R27, 0x00
	LDI R29, 0x00

	; Initialize Timer0
	LDI R16, 0b00001010	; WGM00 WGM01 01 (Clear on Compare Match), CS02:00 010 Prescaler=CLK/8 (Timer Clock = 8MHz/8 = 1MHz)
	OUT TCCR0,R16
	LDI R16,125			; Compare with 125, Timer interrupts at 1MHz/125 = 8KHz
	OUT OCR0,R16	
	LDI R16, 0b00000010	; OCIE0 = 1 (Timer0 Interrupt Enable) when TCNT0 == OCR0
	OUT TIMSK,R16

DO_NOTHING:				; Do nothing until Timer Interrupt or ADC Interrupt
	JMP DO_NOTHING

TIMER_INT_HANDLER:
	SBI ADCSRA,ADSC		; Start Conversion
	RETI

ADC_INT_HANDLER:

	IN R20, ADCL		; Read 2 least significant bits into R20
	IN R21, ADCH		; Read 8 most significant bits into R21

	LDI R28, H0			;Load filter coefficient H0
	MOV R22, R21		;Move 8 MSB to R22
	MUL R28, R22		; 2 Clock cycle MULtiplication R1:R0 = R28*R22
	ADD R29, R0
	ADC R30, R1

	LDI R28, H1			;Load filter coefficient H1
	MUL R28, R23		; 2 Clock cycle MULtiplication R1:R0 = R28*R23
	ADD R29, R0
	ADC R30, R1

	LDI R28, H2			;Load filter coefficient H2
	MUL R28, R24		; 2 Clock cycle MULtiplication R1:R0 = R28*R24
	ADD R29, R0
	ADC R30, R1

	LDI R28, H3			;Load filter coefficient H3
	MUL R28, R25		; 2 Clock cycle MULtiplication R1:R0 = R28*R25
	ADD R29, R0
	ADC R30, R1

	LDI R28, H4			;Load filter coefficient H4
	MUL R28, R26		; 2 Clock cycle MULtiplication R1:R0 = R28*R26
	ADD R29, R0
	ADC R30, R1

	LDI R28, H5			;Load filter coefficient H5
	MUL R28, R27		; 2 Clock cycle MULtiplication R1:R0 = R28*R27
	ADD R29, R0
	ADC R30, R1

	OUT PORTB, R30		;Output most significant bits to DAC

	; Shift Input Samples
	MOV R27, R26
	MOV R26, R25
	MOV R25, R24
	MOV R24, R23
	MOV R23, R22
	
	; Reset accumulation registers
	LDI R30, 0
	LDI R29, 0

	RETI