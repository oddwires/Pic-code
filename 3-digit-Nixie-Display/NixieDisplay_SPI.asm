
    list                p=16F1509, c=150            ; List directive to define processor, 150 column width
    #include            <p16F1509.inc>              ; Processor specific variable definitions
    errorlevel  -302
    
    #define             SPI                         ; Switch between Counter and SPI

; CONFIG1
; __config 0x1E4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF
; CONFIG2
; __config 0x19FC
 __CONFIG _CONFIG2, _WRT_ALL & _STVREN_OFF & _BORV_HI & _LPBOR_OFF & _LVP_OFF

; Pin definitions...
; SPI bus (limited connection options, so assign these first)...
SDI             equ         RB4                     ; SPI Data in  => Pin 13
SDO             equ         RC7                     ; SPI Data out => Pin  9         
SCK             equ         RB6                     ; SPI Clock    => Pin 11
SS1             equ         RC6                     ; SPI Select   => Pin  8

; Port A connection...
Anode_0         equ         RA2                     ; Pin 17
Anode_1         equ         RA0                     ; Pin 19
Anode_2         equ         RA1                     ; Pin 18
Cathode_4       equ         RA4                     ; Pin  3
Cathode_5       equ         RA5                     ; Pin  2

; Port B connections...       
Cathode_0       equ         RB7                     ; Pin 10
Cathode_6       equ         RB5                     ; Pin 12

; Port C connections...       
Cathode_1       equ         RC3                     ; Pin  7
Cathode_9       equ         RC0                     ; Pin 16
Cathode_8       equ         RC1                     ; Pin 15
Cathode_7       equ         RC2                     ; Pin 14
Cathode_2       equ         RC4                     ; Pin  6
Cathode_3       equ         RC5                     ; Pin  5

; Data Memory allocation...
    CBLOCK h'20'
                Counter_lo                           ; 16 bit number (0->999) to be displayed on Nixies
                Counter_hi
                COUNT1
                COUNT2
; Variables associated with the SPI communications...
                Data_lo
                Data_hi
; Variables associated with the Div16x8 function...
                Dividend_lo                         ; 16 bit
                Dividend_hi
                Divisor                             ; 8 bit
                Remainder                           ; 8 bit
                Quotient                            ; 8 bit
                Count
; Variables associated with driving the Nixie tubes...
                NixieBuff_0                         ; Numeric value to be displayed (interim result)
                NixiePortA_0                        ; Bit map required on PortA to display numeric.
                NixiePortB_0                        ; Bit map required on PortB to display numeric.
                NixiePortC_0                        ; Bit map required on PortC to display numeric.

                NixieBuff_1                         ; Numeric value to be displayed (interim result)
                NixiePortA_1                        ; Bit map required on PortA to display numeric.
                NixiePortB_1                        ; Bit map required on PortB to display numeric.
                NixiePortC_1                        ; Bit map required on PortC to display numeric.
;
                NixieBuff_2                         ; Numeric value to be displayed (interim result)
                NixiePortA_2                        ; Bit map required on PortA to display numeric.
                NixiePortB_2                        ; Bit map required on PortB to display numeric.
                NixiePortC_2                        ; Bit map required on PortC to display numeric.
    ENDC

    org         0x00

                goto        Main                    ; Reset vector at 0x00
                nop
                nop
                nop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt Service Routine.
; Can be triggered by...
;   1) Timer 0 Overflowing              (Fosc/4 counter)
;   2) SPI data recepton                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TestSPI:        
                banksel     PIR1
                btfss       PIR1,SSP1IF             ; SPI interrupt ?
                goto        TestTMR0                ; No  : Skip
                movfw       Data_lo                 ; Yes : Shift previous byte
                movwf       Data_hi
                movwf       Counter_hi              ; Copy to counter
                banksel     SSP1BUF
                movfw       SSP1BUF                 ; Get current byte
                banksel     0
                movwf       Data_lo
                movwf       Counter_lo              ; Copy to counter

                banksel     PIR1
                bcf         PIR1,SSP1IF             ; Clear Timer 0 interrupt flag                
TestTMR0:       
                banksel     INTCON
                btfss       INTCON,TMR0IF           ; Timer 0 interrupt ?
                goto        IntExit                 ; No  : Skip
                banksel     PORTA                   ; Yes : Update display...
; Setup Anodes and Cathode data for Most Significant Digit...
                btfss       PORTA,Anode_0           ; Test if Anode_0 is active ?
                goto        Not000                  ; No : Skip
                bcf         PORTA,Anode_0           ; Yes: Anode_0 => off
                movfw       NixiePortA_0
                movwf       PORTA                   ; Set PORTA cathode bit...
                bsf         PORTA,Anode_1           ;    ... and overlay anode bit. Anode_1 => on
                movfw       NixiePortB_0
                movwf       PORTB                   ; Set PortB cathode bit
                movfw       NixiePortC_0
                movwf       PORTC                   ; Set PortC cathode bit
                goto        IntExit
;
; Setup Anodes and Cathode data for Next Digit...
Not000:         btfss       PORTA,Anode_1           ; Test if Anode_1 is active ?
                goto        Default                 ; No : Skip
                bcf         PORTA,Anode_1           ; Yes: Anode_1 => off
                movfw       NixiePortA_1
                movwf       PORTA                   ; Set PORTA cathode bit...
                bsf         PORTA,Anode_2           ;    ... and overlay anode bit. Anode2 => on
                movfw       NixiePortB_1
                movwf       PORTB                   ; Set PortB cathode bit
                movfw       NixiePortC_1
                movwf       PORTC                   ; Set PortC cathode bit
                goto        IntExit
;
; Setup Anodes and Cathode data for Least Significant Digit...
Default:        bcf         PORTA,Anode_1           ; Anode_1 => off
                bcf         PORTA,Anode_2           ; Anode_2 => off
                movfw       NixiePortA_2
                movwf       PORTA                   ; Set PORTA cathode bit...
                bsf         PORTA,Anode_0           ;    ... and overlay anode bit. Anode0 => on
                movfw       NixiePortB_2
                movwf       PORTB                   ; Set PortB cathode bit
                movfw       NixiePortC_2
                movwf       PORTC                   ; Set PortC cathode bit

IntExit:        bcf         INTCON,T0IF             ; Clear Timer 0 interrupt flag                
                retfie                              ; Done

Main:
                CLRF        PORTA                   ; Initialize PORTA by setting output data latches
                BANKSEL     ANSELA
                CLRF        ANSELA                  ; Digital I/O                
                BANKSEL     ANSELB
                CLRF        ANSELB                  ; Digital I/O                
                BANKSEL     ANSELC
                CLRF        ANSELC                  ; Digital I/O

                BANKSEL     TRISA
                MOVLW       0x00                    ; Set RA<4:0> as outputs
                movlw       b'00001000'             ; CS TRIS bit set, all others clear 
                MOVWF       TRISA                   ;     RA<6:7> as outputs

                BANKSEL     TRISB                   ; Initialise Port B...
                movlw       b'01010000'             ; SDI + CLK TRIS bit set, SCK TRIS bit clear, all others as outputs
                MOVWF       TRISB                   ; Set RB<7:0> as outputs

                BANKSEL     TRISC                   ; Initialise Port C...
                MOVLW       b'01000000'             ; CS input
                                                    ; SDO TRIS bit clear, all others as outputs
                MOVWF       TRISC                   ; Set RC<7:0> as outputs
                
                banksel     TMR0
                clrf        TMR0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INTCON register configuration...
; Set Global Interupt and Timer 0 Interrupts active...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                banksel     INTCON
                movlw       b'10100000'             ; Bit 7 GIE: Global Interrupt Enable bit
                                                    ; *   1 = Enables all active interrupts
                                                    ;     0 = Disables all interrupts
                                                    ; Bit 6 PEIE: Peripheral Interrupt Enable bit
                                                    ;     1 = Enables all active peripheral interrupts
                                                    ; *   0 = Disables all peripheral interrupts
                                                    ; Bit 5 TMR0IE: Timer0 Overflow Interrupt Enable bit
                                                    ; *   1 = Enables the Timer0 interrupt
                                                    ;     0 = Disables the Timer0 interrupt
                                                    ; Bit 4 INTE: INT External Interrupt Enable bit
                                                    ;     1 = Enables the INT external interrupt
                                                    ; *   0 = Disables the INT external interrupt
                                                    ; Bit 3 IOCIE: Interrupt-on-Change Enable bit
                                                    ;     1 = Enables the interrupt-on-change
                                                    ; *   0 = Disables the interrupt-on-change
                                                    ; Bit 2 TMR0IF: Timer0 Overflow Interrupt Flag bit
                                                    ;     1 = TMR0 register has overflowed
                                                    ; *   0 = TMR0 register did not overflow
                                                    ; Bit 1 INTF: INT External Interrupt Flag bit
                                                    ;     1 = The INT external interrupt occurred
                                                    ; *   0 = The INT external interrupt did not occur
                                                    ; Bit 0 IOCIF: Interrupt-on-Change Interrupt Flag bit(1)
                                                    ;     1 = When at least one of the interrupt-on-change pins changed state
                movwf       INTCON                  ; *   0 = None of the interrupt-on-change pins have changed state                                                    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPTION_REG register configuration...
; Set Timer 0 Prescaler as 1::16...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                banksel     OPTION_REG
                movlw       b'10000011'             ; Bit 7 WPUEN: Weak Pull-up Enable ; ; 
                                                    ; *   1 = All weak pull-ups are disabled (except MCLR, if it is enabled)
                                                    ;     0 = Weak pull-ups are enabled by individual WPUx latch values
                                                    ; Bit 6 INTEDG: Interrupt Edge Select bit
                                                    ;     1 = Interrupt on rising edge of INT pin
                                                    ; *   0 = Interrupt on falling edge of INT pin
                                                    ; Bit 5 TMR0CS: Timer0 Clock Source Select bit
                                                    ;     1 = Transition on T0CKI pin
                                                    ; *   0 = Internal instruction cycle clock (FOSC/4)
                                                    ; Bit 4 TMR0SE: Timer0 Source Edge Select bit
                                                    ;     1 = Increment on high-to-low transition on T0CKI pin
                                                    ; *   0 = Increment on low-to-high transition on T0CKI pin
                                                    ; Bit 3 PSA: Prescaler Assignment bit
                                                    ;     1 = Prescaler is not assigned to the Timer0 module
                                                    ; *   0 = Prescaler is assigned to the Timer0 module                                                    
                                                    ;       Bit value   : TMR0 Rate
                                                    ;           000     :   1 : 1
                                                    ;           001     :   1 : 2
                                                    ;           010     :   1 : 8
                                                    ; *         011     :   1 : 16 (slowest without flicker)
                                                    ;           100     :   1 : 32
                                                    ;           101     :   1 : 64
                                                    ;           110     :   1 : 128
                movwf       OPTION_REG              ;           111     :   1 : 256

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSCON register configuration...
; Set CPU speed @ 16MHz...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                banksel     OSCCON
                movlw       b'01111010'             ; Bit 7 Unimplemented: Read as ?0?
                                                    ; Bit 6-3 IRCF<3:0>: Internal Oscillator Frequency Select bits
                                                    ; * 1111 = 16MHz
                                                    ;   1110 = 8MHz
                                                    ;   1101 = 4MHz
                                                    ;   1100 = 2MHz
                                                    ;   1011 = 1MHz
                                                    ;   1010 = 500 kHz(1)
                                                    ;   1001 = 250 kHz(1)
                                                    ;   1000 = 125 kHz(1)
                                                    ;   0111 = 500 kHz (default upon Reset)
                                                    ;   0110 = 250 kHz
                                                    ;   0101 = 125 kHz
                                                    ;   0100 = 62.5 kHz
                                                    ;   001x = 31.25 kHz
                                                    ;   000x = 31kHz LF
                                                    ; Bit 2 Unimplemented: Read as ?0?
                                                    ; Bit 1-0 SCS<1:0>: System Clock Select bits
                                                    ; * 1x = Internal oscillator block
                                                    ;   01 = Secondary oscillator
                movwf       OSCCON                  ;   00 = Clock determined by FOSC<2:0> in Configuration Words.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; APFCON register configuration...
; Assign SPI pins...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                banksel     APFCON
                movlw       b'00001000'            ; Bit 7-5 Unimplemented: Read as ?0?
                                                    ; Bit 4 SSSEL: Pin Selection bit
                                                    ;   1 = SS function is on RA3
                                                    ; * 0 = SS function is on RC6
                                                    ; Bit 3 T1GSEL: Pin Selection bit
                                                    ; * 1 = T1G function is on RA3
                                                    ;   0 = T1G function is on RA4
                                                    ; Bit 2 Unimplemented: Read as ?0?
                                                    ; Bit 1 CLC1SEL: Pin Selection bit
                                                    ;   1 = CLC1 function is on RC5
                                                    ; * 0 = CLC1 function is on RA2
                                                    ; Bit 0 NCO1SEL: Pin Selection bit
                                                    ;   1 = NCO1 function is on RC6
                movwf       APFCON                 ; * 0 = NCO1 function is on RC1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SSP1STAT + SSP1CON1 register configuration...
; Set SPI Slave mode...
; Initalize SPI...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                banksel     SSP1CON1
                bcf         SSP1CON1,SSPEN          ; Reset the SSP module
                movlw       b'01000000'             ; Bit 7 SMP: SPI Data Input Sample bit
                                                    ;   SPI Master mode:
                                                    ;     1 = Input data sampled at end of data output time
                                                    ;     0 = Input data sampled at middle of data output time
                                                    ;   SPI Slave mode:
                                                    ;   SMP must be cleared when SPI is used in Slave mode
                                                    ;     In I2 C Master or Slave mode:
                                                    ;     1 = Slew rate control disabled
                                                    ; *   0 = Slew rate control enabled
                                                    ; Bit 6 CKE: SPI Clock Edge Select bit (SPI mode only)
                                                    ;   In SPI Master or Slave mode:
                                                    ; *   1 = Transmit occurs on transition from active to Idle clock state
                                                    ;     0 = Transmit occurs on transition from Idle to active clock state
                                                    ;   In I2C mode only:
                                                    ;     1 = Enable input logic so that thresholds are compliant with SMBus specification
                                                    ;     0 = Disable SMBus specific inputs
                                                    ; Bit 5 D/A: Data/Address bit (I2C mode only)
                                                    ;     1 = Indicates that the last byte received or transmitted was data
                                                    ;     0 = Indicates that the last byte received or transmitted was address
                                                    ; Bit 4 P: Stop bit
                                                    ;   (I2C mode only. This bit is cleared when the MSSP module is disabled, SSPEN is cleared.)
                                                    ;     1 = Indicates that a Stop bit has been detected last (this bit is ?0? on Reset)
                                                    ;     0 = Stop bit was not detected last
                                                    ; Bit 3 S: Start bit
                                                    ;   (I2C mode only. This bit is cleared when the MSSP module is disabled, SSPEN is cleared.)
                                                    ;     1 = Indicates that a Start bit has been detected last (this bit is ?0? on Reset)
                                                    ;     0 = Start bit was not detected last
                                                    ; Bit 2 R/W: Read/Write bit information (I2C mode only)
                                                    ;   This bit holds the R/W bit information following the last address match. This bit is only valid from the address match
                                                    ;   to the next Start bit, Stop bit, or not ACK bit.
                                                    ;   In I2C Slave mode:
                                                    ;     1 = Read
                                                    ;     0 = Write
                                                    ;   In I2C Master mode:
                                                    ;     1 = Transmit is in progress
                                                    ;     0 = Transmit is not in progress
                                                    ;   OR-ing this bit with SEN, RSEN, PEN, RCEN or ACKEN will indicate if the MSSP is in Idle mode.
                                                    ;   bit 1 UA: Update Address bit (10-bit I2C mode only)
                                                    ;     1 = Indicates that the user needs to update the address in the SSPxADD register
                                                    ;     0 = Address does not need to be updated
                                                    ; Bit 0 BF: Buffer Full Status bit
                                                    ;   Receive (SPI and I2C modes):
                                                    ;     1 = Receive complete, SSPxBUF is full
                                                    ;     0 = Receive not complete, SSPxBUF is empty
                                                    ;   Transmit (I2C mode only):
                                                    ;     1 = Data transmit in progress (does not include the ACK and Stop bits), SSPxBUF is full
                movwf       SSP1STAT                ;     0 = Data transmit complete (does not include the ACK and Stop bits), SSPxBUF is empty                
;
                movlw       b'01100100'             ; Bit 7 WCOL: Write Collision Detect bit
                                                    ;   Master mode:
                                                    ;     1 = A write to the SSPxBUF register was attempted while the I2C conditions were not valid for a transmission to be started
                                                    ;     0 = No collision
                                                    ;   Slave mode:
                                                    ;     1 = The SSPxBUF register is written while it is still transmitting the previous word (must be cleared in software)
                                                    ;     0 = No collision
                                                    ; Bit 6 SSPOV: Receive Overflow Indicator bit(1)
                                                    ;   In SPI mode:
                                                    ;     1 = A new byte is received while the SSPxBUF register is still holding the previous data. In case of overflow, the data in SSPxSR is lost.
                                                    ;     Overflow can only occur in Slave mode. In Slave mode, the user must read the SSPxBUF, even if only transmitting data, to avoid
                                                    ;     setting overflow. In Master mode, the overflow bit is not set since each new reception (and transmission) is initiated by writing to the
                                                    ;     SSPxBUF register (must be cleared in software).
                                                    ;     0 = No overflow
                                                    ;   In I2 C mode:
                                                    ;     1 = A byte is received while the SSPxBUF register is still holding the previous byte. SSPOV is a ?don?t care? in Transmit mode
                                                    ;     (must be cleared in software).
                                                    ;     0 = No overflow
                                                    ; Bit 5 SSPEN: Synchronous Serial Port Enable bit
                                                    ;   In both modes, when enabled, these pins must be properly configured as input or output
                                                    ;   In SPI mode:
                                                    ; *   1 = Enables serial port and configures SCKx, SDOx, SDIx and SSx as the source of the serial port pins(2)
                                                    ;     0 = Disables serial port and configures these pins as I/O port pins
                                                    ;   In I2 C mode:
                                                    ;     1 = Enables the serial port and configures the SDAx and SCLx pins as the source of the serial port pins(3)
                                                    ;     0 = Disables serial port and configures these pins as I/O port pins
                                                    ; Bit 4 CKP: Clock Polarity Select bit
                                                    ;   In SPI mode:
                                                    ;     1 = Idle state for clock is a high level
                                                    ; *   0 = Idle state for clock is a low level
                                                    ;   In I2 C Slave mode:
                                                    ;     SCLx release control
                                                    ;     1 = Enable clock
                                                    ;     0 = Holds clock low (clock stretch). (Used to ensure data setup time.)
                                                    ;   In I2C Master mode:
                                                    ;     Unused in this mode
                                                    ; Bit 3-0 SSPM<3:0>: Synchronous Serial Port Mode Select bits
                                                    ;   0000 = SPI Master mode, clock = FOSC/4
                                                    ;   0001 = SPI Master mode, clock = FOSC/16
                                                    ;   0010 = SPI Master mode, clock = FOSC/64
                                                    ;   0011 = SPI Master mode, clock = T2_match/2
                                                    ; * 0100 = SPI Slave mode, clock = SCKx pin, SS pin control enabled
                                                    ;   0101 = SPI Slave mode, clock = SCKx pin, SS pin control disabled, SSx can be used as I/O pin
                                                    ;   0110 = I2C Slave mode, 7-bit address
                                                    ;   0111 = I2C Slave mode, 10-bit address
                                                    ;   1000 = I2C Master mode, clock = FOSC/(4 * (SSPxADD+1)
                                                    ;   1001 = Reserved
                                                    ;   1010 = SPI Master mode, clock = FOSC/(4 * (SSPxADD+1))
                                                    ;   1011 = I2C firmware controlled Master mode (Slave idle)
                                                    ;   1100 = Reserved
                                                    ;   1101 = Reserved
                                                    ;   1110 = I2C Slave mode, 7-bit address with Start and Stop bit interrupts enabled
                                                    ;   1111 = I2C Slave mode, 10-bit address with Start and Stop bit interrupts enabled                
                movwf       SSP1CON1                ; SPI Slave Mode, SS pin control enabled, Clock idle=low, re-enable the SSP module 

                movwf       b'00001000'
                movwf       PIE1                    ; Enable Synchronous Serial Port (MSSP) Interrupt Enable
;
                banksel     0
LoopReset:      clrf        Counter_hi
                clrf        Counter_lo
                movwf       Counter_lo
MainLoop:
#ifdef          SPI    
; Code to read from SPI...    
;                banksel     SSP1BUF
;                movfw       SSP1BUF
;                banksel     0
;                movwf       Counter_lo
 #endif
                
                bcf         INTCON,GIE              ; Suspend interrupts

                movfw       Counter_lo              ; Load 16 bit dividend value
                movwf       Dividend_lo
                movfw       Counter_hi              ; Load 16 bit dividend value
                movwf       Dividend_hi
; Calculate the values for the Most Significant Digit...
                movlw       d'100'                  ; Load Divisor value (8 bit)
                movwf       Divisor
                call        Div16x8
; Use the value to check if we have reached the display limit...
                movfw       Quotient                ; W => Number of 100's
                sublw       d'10'                   ; Check for overflow (>999)
                btfsc       STATUS,Z
                goto        LoopReset               ; Reset counter and start again
;
                movfw       Quotient                ; W => Number of 100's
                movwf       NixieBuff_0             ; Write 100's
                call        PortA_Lookup            ; Get PortA bitmap required for this value
                movwf       NixiePortA_0            ; Store bitmap for use by Interrupt routine
                movfw       Quotient                ; Restore value, W => Number of 100's
                call        PortB_Lookup            ; Get PortB bitmap required for this value
                movwf       NixiePortB_0            ; Store bitmap for use by Interrupt routine
                movfw       Quotient                ; Restore value, W => Number of 100's
                call        PortC_Lookup            ; Get PortC bitmap required for this value
                movwf       NixiePortC_0            ; Store bitmap for use by Interrupt routine
; Calculate the values for the Next Digit...
                movfw       Remainder               ; Remainder becomes new dividend value
                movwf       Dividend_lo
                clrf        Dividend_hi             ; As number is <100, this will always be zero
                movlw       d'10'                   ; Load Divisor value (8 bit)
                movwf       Divisor
                call        Div16x8
                movfw       Quotient                ; W => Number of 10's
                movwf       NixieBuff_1             ; Write 10's
                call        PortA_Lookup            ; Get PortA bitmap required for this value
                movwf       NixiePortA_1            ; Store bitmap for use by Interrupt routine
                movfw       Quotient                ; Restore value, W => Number of 10's
                call        PortB_Lookup            ; Get PortB bitmap required for this value
                movwf       NixiePortB_1            ; Store bitmap for use by Interrupt routine
                movfw       Quotient                ; Restore value, W => Number of 10's
                call        PortC_Lookup            ; Get PortC bitmap required for this value
                movwf       NixiePortC_1            ; Store bitmap for use by Interrupt routine
; Remainder becomes the value for the Least Significant Digit...
                movfw       Remainder               ; W => Number of 1's
                movwf       NixieBuff_2             ; Write 1's
                call        PortA_Lookup            ; Get PortA bitmap required for this value
                movwf       NixiePortA_2            ; Store bitmap for use by Interrupt routine
                movfw       Remainder               ; Restore value, W => Number of 1's
                call        PortB_Lookup            ; Get PortB bitmap required for this value
                movwf       NixiePortB_2            ; Store bitmap for use by Interrupt routine
                movfw       Remainder               ; Restore value, W => Number of 1's
                call        PortC_Lookup            ; Get PortC bitmap required for this value
                movwf       NixiePortC_2            ; Store bitmap for use by Interrupt routine

#ifndef         SPI
; Code to bump 16 bit counter...
                incf        Counter_lo              ;  Increment the Lower Byte
                btfsc       STATUS, Z               ;  If the Zero Flag is Set
                incf        Counter_hi              ;  Increment the Upper Byte
#endif
                
                bsf         INTCON,GIE              ; Resume interrupts
                call        DELAY3
                goto        MainLoop
;
PortA_Lookup:   addwf       PCL,F
                retlw       0                       ; Cathode 0 not on Port A
                retlw       0                       ; Cathode 1 not on Port A
                retlw       0                       ; Cathode 2 not on Port A
                retlw       0                       ; Cathode 3 not on Port A
                retlw       (1<<Cathode_4)
                retlw       (1<<Cathode_5)
                retlw       0                       ; Cathode 6 not on Port A
                retlw       0                       ; Cathode 7 not on Port A
                retlw       0                       ; Cathode 8 not on Port A
                retlw       0                       ; Cathode 9 not on Port A
PortB_Lookup:   addwf       PCL,F
                retlw       (1<<Cathode_0)
                retlw       0                       ; Cathode 1 not on Port B
                retlw       0                       ; Cathode 2 not on Port B
                retlw       0                       ; Cathode 3 not on Port B
                retlw       0                       ; Cathode 4 not on Port B
                retlw       0                       ; Cathode 5 not on Port B
                retlw       (1<<Cathode_6)
                retlw       0                       ; Cathode 7 not on Port B
                retlw       0                       ; Cathode 8 not on Port B
                retlw       0                       ; Cathode 9 not on Port B
PortC_Lookup:   addwf       PCL,F
                retlw       0                       ; Cathode 0 not on Port C
                retlw       (1<<Cathode_1)
                retlw       (1<<Cathode_2)
                retlw       (1<<Cathode_3)
                retlw       0                       ; Cathode 4 not on Port C
                retlw       0                       ; Cathode 5 not on Port C
                retlw       0                       ; Cathode 6 not on Port C
                retlw       (1<<Cathode_7)
                retlw       (1<<Cathode_8)
                retlw       (1<<Cathode_9)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Div 16 bit by 8 bit integer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Long division, just like they taught me back in skhool. Only with a couple of differences...
;       1) It's in binary, not decimal
;       2) Instead of shifting the Divisor to the right, the Dividend gets shifted to the left.
;              (this gives better use of registers, and more compact code)
;
; Inputs:  16 bit Dividend  - Dividend_hi
;                             Dividend_lo
;           8 bit Divisor   - Divisor
; Outputs:  8 bit Quotient  - Quotient
;           8 bit Remainder - Remainder     
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Div16x8:        clrf        Quotient
                movlw       8 + 1                   ; 8 shifts will fully move the lo byte into the hi byte
                movwf       Count                   ;   Loop mechanism needs n+1
DivLoop:        movfw       Divisor                 ; Get Divisor value
                subwf       Dividend_hi,W           ; Attempt subtraction
                btfsc       STATUS,C                ; Is hi byte >= Divisor ?
                movwf       Dividend_hi             ;     Yes: Replace Dividend_hi with (Dividend_hi - Divisor)
                rlf         Quotient,F              ;     No : Continue: Shift result into Quotient
                movfw       Dividend_hi             ; Grab Remainder before it gets destroyed (shifted)
                movwf       Remainder               ; Store result
                rlf         Dividend_lo,F           ; 16 bit shift Dividend for the next itteration.
                rlf         Dividend_hi,F
                decfsz      Count,F                 ; Repeat 8 times
                goto        DivLoop
                return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Rough and Ready time delay routine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY3:         DECFSZ      COUNT1,F
                GOTO        DELAY3
                DECFSZ      COUNT2,F
                GOTO        DELAY3
                RETURN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    end


