;**********************************************************************
;Program reads up to 64 MIDI bytes and displays them on a 16x4 LCD screen
;Mark Jensen - December 15th, 2014    Ver.  1.0
;Final.  Tested and working, January 9th, 2015
;**********************************************************************


        #include "p16F628A.inc"
        ERRORLEVEL	0,	-302        ;suppress bank selection messages

; CONFIG
; __config 0x3D09
 __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

;4MHz Oscillator (XT) mode

;pins
;ra0 = output LED for test and read / write mode.  ON = Read, OFF = WRITE
;ra1
;ra2 = input from MIDI device
;ra3 = output timing blips out to scope
;ra4 = input button to switch between Read & Write mode.
;ra5
;rb0-7 = LCD

;registers

realnum     equ     20
lcdnum      equ     21
mreg        equ     22
count       equ     30
count1      equ     31
counta      equ     32
countb      equ     33
bytctr      equ     23
colctr      equ     24
rowctr      equ     25

;definitions

LCD_PORT	equ	PORTB
LCD_TRIS	equ	TRISB
LCD_RS		equ	0x04			;LCD handshake lines
LCD_RW		equ	0x06
LCD_E		equ	0x07


            org	0x0000

            movlw	0x07
            movwf	CMCON			;turn comparators off (make it like a 16F84)
            bsf status,5
            movlw B'00010100'
            movwf trisa
            movlw B'00000000'
            movwf trisb
            movlw B'11000000'
            movwf option_reg
            bcf status,5

            clrf porta
            clrf portb

            call Delay100
            call LCD_Init
            call test
            call clear
            movlw 0xA0              ;initialize pointer to RAM
            movwf FSR

;read loop

read        bsf porta,0             ;set LED for beginning of Read mode.
mn          btfss porta,2           ;wait for midi input to be 1.
            goto mn
            bsf porta,3             ;new byte blips
            bcf porta,3


waita       btfss porta,2           ;wait for start bit of word a
            goto strt
            btfsc porta,4           ;check button
            goto write
            goto waita

strt        clrf mreg
            call dela

            nop
            bsf porta,3
            btfsc porta,2           ;read bit 1
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 2
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 3
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 4
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 5
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 6
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 7
            bsf mreg,7
            bcf porta,3
            nop
            call delz

            rrf mreg,f
            bsf porta,3
            btfsc porta,2           ;read bit 8
            bsf mreg,7
            bcf porta,3

;filter out active sensing?

            movf mreg,w
            movwf INDF
            incf FSR,f
            goto read

;write loop

write       bcf porta,0             ;turn off LED for Write mode
            movlw D'4'              ;load # of lines
            movwf rowctr
            movlw 0xA0              ;move pointer to beginning of data section
            movwf FSR
         
lnloop      movlw D'8'             ;load # of spaces per line
            movwf colctr

wrloop2     call LCD_Char
            call Delay255

            incf FSR,f
            decf colctr,f
            btfss status,z
            goto wrloop2

            decf rowctr,f
            btfsc status,z
            goto waitb
            movf rowctr,w
            addwf PCL,f
            nop
            goto LCD_Line4
            goto LCD_Line3
            goto LCD_Line2

waitb       btfsc porta,4           ;wait for read button
            goto cont
            goto waitb

cont        call Delay255
            call clear
            call LCD_Clr
            movlw 0xA0              ;initialize pointer to RAM
            movwf FSR
            goto read

;LCD routines

;clear chip data registers
clear       movlw D'64'
            movwf colctr
            movlw 0xA0              ;initialize pointer to RAM
            movwf FSR
clrlp       clrf INDF               ;indirectly clear register (pointed to by FSR)
            incf FSR,f              ;inc pointer
            decf colctr,f
            btfss status,z          ;all done?
            goto clrlp
            retlw 0x00

;Initialise LCD
LCD_Init	movlw	0x20			;Set 4 bit mode
            call	LCD_Cmd

            movlw	0x28			;Set display shift
            call	LCD_Cmd

            movlw	0x06			;Set display character mode
            call	LCD_Cmd

            movlw	0x0d			;Set display on/off and cursor command
            call	LCD_Cmd

            call	LCD_Clr			;clear display

            retlw	0x00

; command set routine
LCD_Cmd		movwf	realnum
            swapf	realnum,	w       ;send upper nibble
            andlw	0x0f                ;clear upper 4 bits of W
            movwf	LCD_PORT
            bcf     LCD_PORT, LCD_RS	;RS line to 0
            call	Pulse_e             ;Pulse the E line high

            movf	realnum,	w       ;send lower nibble
            andlw	0x0f                ;clear upper 4 bits of W
            movwf	LCD_PORT
            bcf	LCD_PORT, LCD_RS        ;RS line to 0
            call	Pulse_e             ;Pulse the E line high
            call 	Delay5
            retlw	0x00


LCD_Char	movf    INDF,w              ;move byte to W reg.
            movwf	realnum
            swapf   realnum,    w       ;process first real nibble
            andlw   0x0F                
            call    HEX_Table
            movwf   lcdnum

            swapf	lcdnum,     w       ;send upper LCD nibble
            andlw	0x0F                ;clear upper 4 bits of W
            movwf	LCD_PORT
            bsf	LCD_PORT, LCD_RS        ;RS line to 1
            call	Pulse_e             ;Pulse the E line high

            movf	lcdnum,     w       ;send lower LCD nibble
            andlw	0x0f                ;clear upper 4 bits of W
            movwf	LCD_PORT
            bsf	LCD_PORT, LCD_RS        ;RS line to 1
            call	Pulse_e             ;Pulse the E line high
            call 	Delay5

            movf    realnum,    w       ;process second real nibble
            andlw   0x0F                
            call    HEX_Table
            movwf   lcdnum

            swapf	lcdnum,     w       ;send upper LCD nibble
            andlw	0x0F                ;clear upper 4 bits of W
            movwf	LCD_PORT
            bsf	LCD_PORT, LCD_RS        ;RS line to 1
            call	Pulse_e             ;Pulse the E line high

            movf	lcdnum,     w       ;send lower LCD nibble
            andlw	0x0f                ;clear upper 4 bits of W
            movwf	LCD_PORT
            bsf	LCD_PORT, LCD_RS        ;RS line to 1
            call	Pulse_e             ;Pulse the E line high
            call 	Delay5

            retlw	0x00

LCD_Line1	bcf	LCD_PORT, LCD_RW        ;RW line to 0
            bcf	LCD_PORT, LCD_RS        ;RS line to 0
            movlw	0x80                ;move to 1st row, first column
            call	LCD_Cmd
            goto    lnloop

LCD_Line2	bcf	LCD_PORT, LCD_RW        ;RW line to 0
            bcf	LCD_PORT, LCD_RS        ;RS line to 0
            movlw	0xC0                ;move to 2nd row, first column
            call	LCD_Cmd
            goto    lnloop

LCD_Line3	bcf	LCD_PORT, LCD_RW        ;RW line to 0
            bcf	LCD_PORT, LCD_RS        ;RS line to 0
            movlw	0x90                ;move to 3rd row, first column
            call	LCD_Cmd
            goto    lnloop

LCD_Line4	bcf	LCD_PORT, LCD_RW        ;RW line to 0
            bcf	LCD_PORT, LCD_RS        ;RS line to 0
            movlw	0xD0                ;move to 4th row, first column
            call	LCD_Cmd
            goto    lnloop

LCD_Line1W	addlw	0x80                ;move to 1st row, column W
            call	LCD_Cmd
            retlw	0x00

LCD_Line2W	addlw	0xc0                ;move to 2nd row, column W
            call	LCD_Cmd
            retlw	0x00

LCD_CurOn	movlw	0x0d                ;Set display on/off and cursor command
            call	LCD_Cmd
            retlw	0x00

LCD_CurOff	movlw	0x0c                ;Set display on/off and cursor command
            call	LCD_Cmd
            retlw	0x00

LCD_Clr		movlw	0x01                ;Clear display
            call	LCD_Cmd
            retlw	0x00

HEX_Table       ADDWF   PCL,f
            	RETLW   0x30
            	RETLW   0x31
            	RETLW   0x32
            	RETLW   0x33
            	RETLW   0x34
            	RETLW   0x35
            	RETLW   0x36
            	RETLW   0x37
            	RETLW   0x38
            	RETLW   0x39
            	RETLW   0x41
            	RETLW   0x42
            	RETLW   0x43
            	RETLW   0x44
            	RETLW   0x45
            	RETLW   0x46

;Delays

Delay255	movlw	0xff		;delay 255 mS
            goto	d0
Delay100	movlw	d'100'		;delay 100mS
            goto	d0
Delay50		movlw	d'50'		;delay 50mS
            goto	d0
Delay20		movlw	d'20'		;delay 20mS
            goto	d0
Delay5		movlw	0x05		;delay 5.000 ms (4 MHz clock)
            goto    d0
dela        movlw   0x0D        ;delay 56 µs
            movwf   count1
            goto    d2
delz        movlw   0x06        ;delay 32 µs
            movwf   count1
            nop
            goto    d2

d0          movwf	count1
d1          movlw	0xC7			;delay 1mS
            movwf	counta
            movlw	0x01
            movwf	countb
Delay_0
            decfsz	counta, f
            goto	$+2
            decfsz	countb, f
            goto	Delay_0

            decfsz	count1	,f
            goto	d1
            retlw	0x00

d2          decfsz  count1
            goto    d2
            retlw   0x00

Pulse_e		bsf	LCD_PORT, LCD_E
            nop
            bcf	LCD_PORT, LCD_E
            retlw	0x00

;end of LCD routines

test    bsf porta,0             ;lights LED for quarter second x 2
        call Delay255
        bcf porta,0
        call Delay255
        bsf porta,0
        call Delay255
        bcf porta,0
        return

            end






