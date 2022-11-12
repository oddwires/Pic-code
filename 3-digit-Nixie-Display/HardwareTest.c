/////////////////////////////////////////////////////////////////////////////////////////////
//
// Hardware test routine for the 3 Digit Nixie Display module.
// Creates a simple 3 digit counter, incrementing at 0.1 second intervals on the module.
// 
// Fail if the digits are in the wrong place. - Anode bus has got twisted.
// Fail if the digits aren't counting in the correct order. - Cathode bus has got twisted.
// Pass if the module displays a three digit counter ranging from 0 to 999.
// 
// Note: When debugging code, X IDE DOES NOT write correctly to the PIC output latches, and
//       may look like the code has errors. Always test as a PRODUCTION BUILD before chasing
//       phantom issue writing data to ports.
//
/////////////////////////////////////////////////////////////////////////////////////////////

#pragma warning disable 1020        // Disable warning to provide clean build

// PIC16F15344 Configuration Bit Settings

// CONFIG1
#pragma config FEXTOSC = OFF        // External Oscillator mode selection bits->Oscillator not enabled
#pragma config RSTOSC = HFINTPLL    // Power-up default value for COSC bits (HFINTOSC with 2x PLL, with OSCFRQ = 16 MHz and CDIV = 1:1 (FOSC = 32 MHz))
#pragma config CLKOUTEN = OFF       // Clock Out Enable bit->CLKOUT function is disabled; i/o or oscillator function on OSC2
#pragma config CSWEN = OFF          // Clock Switch Enable bit (The NOSC and NDIV bits cannot be changed by user software)
#pragma config FCMEN = OFF          // Fail-Safe Clock Monitor Enable bit (FSCM timer disabled)

// CONFIG2
#pragma config MCLRE = ON           // Master Clear Enable bit (MCLR pin is Master Clear function)
#pragma config PWRTE = OFF          // Power-up Timer Enable bit (PWRT enabled)
#pragma config LPBOREN = OFF        // Low-Power BOR enable bit (ULPBOR disabled)
#pragma config BOREN = OFF          // Brown-out reset enable bits (Brown-out reset disabled)
#pragma config BORV = HI            // Brown-out Reset Voltage Selection (Brown-out Reset Voltage (VBOR) is set to 2.7V)
#pragma config ZCD = OFF            // Zero-cross detect disable (Zero-cross detect circuit is disabled at POR.)
#pragma config PPS1WAY = ON         // Peripheral Pin Select one-way control (The PPSLOCK bit can be cleared and set only once in software)
#pragma config STVREN = OFF         // Stack Overflow/Underflow Reset Enable bit (Stack Overflow or Underflow will not cause a reset)

// CONFIG3
#pragma config WDTCPS = WDTCPS_31   // WDT Period Select bits (Divider ratio 1:65536; software control of WDTPS)
#pragma config WDTE = OFF           // WDT operating mode (WDT Disabled, SWDTEN is ignored)
#pragma config WDTCWS = WDTCWS_7    // WDT Window Select bits (window always open (100%); software control; keyed access not required)
#pragma config WDTCCS = HFINTOSC    // WDT input clock selector (WDT reference clock is the 31.25 kHz HFINTOSC)

// CONFIG4
#pragma config BBSIZE = BB512       // Boot Block Size Selection bits (512 words boot block size)
#pragma config BBEN = OFF           // Boot Block Enable bit (Boot Block disabled)
#pragma config SAFEN = OFF          // SAF Enable bit (SAF disabled)
#pragma config WRTAPP = OFF         // Application Block Write Protection bit (Application Block not write protected)
#pragma config WRTB = OFF           // Boot Block Write Protection bit (Boot Block not write protected)
#pragma config WRTC = OFF           // Configuration Register Write Protection bit (Configuration Register not write protected)
#pragma config WRTSAF = OFF         // Storage Area Flash Write Protection bit (SAF not write protected)
#pragma config LVP = OFF            // Low Voltage Programming Enable bit (High Voltage on MCLR/Vpp must be used for programming)

// CONFIG5
#pragma config CP = OFF             // UserNVM Program memory code protection bit (UserNVM code protection disabled)

#define _XTAL_FREQ          32000000

#include <xc.h>
#include <pic16f15344.h>                     // MPLAB XC8 header file

// Variables...
uint16_t                Value = 0, TempValue ;                  // 16 bit value to be displayed
uint8_t                 Nixie[3] ;                              // Digits to be displayed on NIXIE tubes
uint8_t                 Temp, AnodeCtr ;                        // 8 bit bitmap to sequence Anode output pins
// Lookup tables...
const uint8_t           PORT_A[10] = { 0x01, 0x02, 0x04, 0x20, 0x10, 0, 0, 0, 0, 0 } ;  // Port A Cathode connections
const uint8_t           PORT_B[10] = { 0, 0, 0, 0, 0, 0, 0, 0x80, 0x10, 0x20 } ;        // Port B Cathode connections
const uint8_t           PORT_C[10] = { 0, 0, 0, 0, 0, 0x40, 0x80, 0, 0, 0 } ;           // Port C Cathode connections

/////////////////////////////////////////////////////////////////////////////////////////////
// Interrupt Service Routine
/////////////////////////////////////////////////////////////////////////////////////////////
void __interrupt() InterruptServiceRoutine (void) {
    if(PIE0bits.TMR0IE == 1 && PIR0bits.TMR0IF == 1) {
        // TMR0 Interrupt, multiplex the display...
        switch (AnodeCtr) {
            case 0b00000001:                        // Current Anode = Anode_0
                AnodeCtr = 0b00100000 ;             // Next Anode    = Anode_1
                Temp = Nixie[1] ;                   // Next digit    = digit_1
                break ;
            case 0b00100000:                        // Current Anode = Anode_1
                AnodeCtr = 0b00010000 ;             // Next Anode    = Anode_2
                Temp = Nixie[2] ;                   // Next digit    = digit_2
                break ;
            default:                                // Current Anode = Anode_2
                AnodeCtr = 0b00000001 ;             // Next Anode    = Anode_0
                Temp = Nixie[0] ;                   // Next digit    = digit_0
                break ;
        }
        // Update the Nixie ports to create the display scan...                
        LATA = PORT_A[Temp] ;
        LATB = PORT_B[Temp] ;
        LATC = PORT_C[Temp] | AnodeCtr ;            // Merge Cathode and Anode bits onto the port
        
        // Reload the counter, and re-enable interrupts...
        TMR0H = 0xC1;                               // TMR0H 193; 
        TMR0L = 0x80;                               // TMR0L 128; 
        PIR0bits.TMR0IF = 0;                        // Clear Interrupt flag
    }
    if(PIE4bits.TMR1IE == 1 && PIR4bits.TMR1IF == 1)  {
        // TMR1 Interrupt, bump the display value...
        Value ++ ;                                  // Bump value
        if ( Value > 999 ) { Value = 0 ; }          // Wrap around on overflow
        // Calculate the values for the individual digits...
        TempValue = Value ;                         // Need to preserve Value for next interrupt
        Nixie[0] = TempValue % 10 ;                 // Units
        TempValue /= 10 ;
        Nixie[1] = TempValue % 10 ;                 // 10's
        TempValue /= 10 ;
        Nixie[2] = TempValue % 10 ;                 // 100's
        
        // Reload the counter, and re-enable interrupts...
        TMR1H = 0xF3;                               // TMR1H 243; 
        TMR1L = 0xCB;                               // TMR1L 203; 
        PIR4bits.TMR1IF = 0;
    }   
}

/////////////////////////////////////////////////////////////////////////////////////////////
// Main Routine
/////////////////////////////////////////////////////////////////////////////////////////////
int main(void) {
//    Micro Controller pin assignments...
//     
//     Initialise the ports on the Micro Controller as per the diagram below.
//     Notes: 1) Arrows indicate input/output.
//            2) Ports RA0 and RA1 normally function as outputs, but double up as inputs
//               when using the ICSP port to program the device.
//     
//                      |===============|
//                    --| Vdd       Vss |--
//         Cathode_3 <--| RA5       RA0 |<-> Cathode_0 / CSPDAT
//         Cathode_4 <--| RA4       RA1 |<-> Cathode_1 / CSPCLK
//              MCLR -->| RA3       RA2 |--> Cathode_2
//           Anode_0 <--| RC5       RC0 |--> Anode_1
//           Anode_2 <--| RC4       RC1 |<-- SPI CLK
//            SPI CS -->| RC3       RC2 |<-- SPI DTA In
//         Cathode_5 <--| RC6       RB4 |--> Cathode_8
//         Cathode_6 <--| RC7       RB5 |--> Cathode_9
//         Cathode_7 <--| RB7       RB6 |--> SPI DTA Out
//                      |===============|
//                         PIC16F15344
//
    
    // Initialise PPS pin mappings...
    SSP1CLKPPS = 0x11;                  // MSSP1:SCK1 (SPI CLK) -> RC1
    RB6PPS = 0x16;                      // MSSP1:SDO1 (SPI DO ) -> RB6
    SSP1DATPPS = 0x12;                  // MSSP1:SDI1 (SPI DI ) -> RC2
    SSP1SSPPS = 0x13;                   // MSSP1:SS1  (SPI CS ) -> RC3    
    
    // Initialise Port A...
    ANSELA = 0 ;                        // All pins on PORTA digital
    PORTA = 0 ;                         // All outputs lows
    TRISA = 0 ;                         // All pins on PORTA outputs
    WPUA = 0;                           // Disable weak pull ups
    
    // Initialise Port B...
    ANSELB = 0 ;                        // All pins on PORTB digital
    PORTB = 0 ;                         // All outputs low
    TRISB = 0 ;                         // All pins on PORTB outputs
    WPUB = 0;                           // Disable weak pull ups
    
    // Initialise Port C...
    ANSELC = 0 ;                        // All pins on PORTC digital
    PORTC = 0 ;                         // All outputs low
    TRISC = 0 ;                         // All pins on PORTC outputs
    WPUC = 0;                           // Disable weak pull ups

    // Timer 0 controls the display scan and triggers every 4ms...
    T0CON0 = 0x90;                      // Output scaler 1:1; T0EN enabled; 16-bit;
    T0CON1 = 0x63;                      // HFINTOSC; Non-synchronous; T0CKPS 1:8;
    TMR0H = 0xC1;                       // TMR0H 193; 
    TMR0L = 0x80;                       // TMR0L 128; 

    // Timer 1 controls the display Value increment and triggers every 100ms...
    T1GCON = 0x00;                      // T1GE disabled; T1GTM disabled; T1GPOL low; T1GGO done; T1GSPM disabled; 
    T1GATE = 0x00;                      // GSS T1G_pin; 
    T1CLK = 0x06;                       // CS MFINTOSC_31.25kHz; 
    T1CON = 0x01;                       // CKPS 1:1; nT1SYNC synchronise; TMR1ON enabled; T1RD16 disabled; 
    TMR1H = 0xF3;                       // TMR1H 243; 
    TMR1L = 0xCB;                       // TMR1L 203; 
    
    // Enable interrupts...
    PIR0bits.TMR0IF = 0;                // Clear Interrupt flag before enabling the interrupt
    PIE0bits.TMR0IE = 1;                // Enable TMR0 interrupt
    PIR4bits.TMR1IF = 0;                // Clear Interrupt flag before enabling the interrupt
    PIE4bits.TMR1IE = 1;                // Enable TMR1 interrupt
    INTCONbits.GIE = 1 ;                // Enable Global Interrupts

    while(1) {
        // Nothing to see here. Its all going on in the Interrupt Service Routine.
    }
}
