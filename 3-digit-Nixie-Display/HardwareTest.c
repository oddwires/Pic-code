/* 
 * Hardware test routine for the 3 Digit Nixie Display module.
 * Creates a simple 3 digit counter on the module.
 * 
 * Fail if the digits are in the wrong place. - Anode bus has got twisted.
 * Fail if the digits aren't counting in the correct order. - Cathode bus has got twisted.
 * Pass if the module displays a three digit counter ranging from 0 to 999.
 * 
 * Note: When debugging code, X IDE DOES NOT write correctly to the PIC output latches, and may look like
 *       the code has errors. To avoid this issue, build the code for production, and re-test on module.
 * 
 * TBD:
 *  1) Nixie digit numbering is reversed
 *  2) Implement interrupt routine.
 *  3) List full pin assignments.
 */

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
#define _SCAN_PERIOD        7       // milli-seconds

#include <xc.h>                     // MPLAB XC8 header file

/*
#define ANODE_0             LATC0
#define ANODE_1             LATC5
#define ANODE_2             LATC4
#define CATHODE_0           LATA0   //  CSPDAT
#define CATHODE_1           LATA1   //  CSPCLK
#define CATHODE_2           LATA2
#define CATHODE_3           LATA5
#define CATHODE_4           LATA4
#define CATHODE_5           LATC6
#define CATHODE_6           LATC7
#define CATHODE_7           LATB7
#define CATHODE_8           LATB4
#define CATHODE_9           LATB5
*/

uint16_t                Value, TempValue ;                      // 16 bit value to be displayed
uint8_t                 Nixie[3] ;                              // Digits to be displayed on NIXIE tubes
uint8_t                 AnodeCtr ;                              // 8 bits
uint8_t                 Timer ;                                 // Loop counter
uint8_t                 temp ;

// Lookup tables...
const uint8_t           PORT_A[10] = { 0x01, 0x02, 0x04, 0x20, 0x10, 0, 0, 0, 0, 0 } ;  // Port A Cathode connections
const uint8_t           PORT_B[10] = { 0, 0, 0, 0, 0, 0, 0, 0x80, 0x10, 0x20 } ;        // Port B Cathode connections
const uint8_t           PORT_C[10] = { 0, 0, 0, 0, 0, 0x40, 0x80, 0, 0, 0 } ;           // Port C Cathode connections

///////////////////////////////
// Interrupt Service Routine //
///////////////////////////////
void __interrupt () isr(void) {
    // TBD
}

int main(void) {
    // Initialise SPI port...
    SSP1CLKPPS = 0x11;                  // MSSP1:SCK1 -> RC1
    RB6PPS = 0x16;                      // MSSP1:SDO1 -> RB6
    SSP1SSPPS = 0x13;                   // MSSP1:SS1  -> RC3    
    SSP1DATPPS = 0x12;                  // MSSP1:SDI1 -> RC2
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

    while(1) {
        // Outer loop - counter to increment the display value from 0 to 999...        
        for ( Value=0;  Value<=999; Value++) {
            // Convert the 16 bit value into 3 digits for display.
            //         Note: Value and TempValue both need to be 16 bit variables...          
            TempValue = Value ;              // Need to preserve Value for loop counter
            Nixie[0] = TempValue % 10 ;      // 100's
            TempValue /= 10 ;
            Nixie[1] = TempValue % 10 ;      // 10's
            TempValue /= 10 ;
            Nixie[2] = TempValue % 10 ;      // Units

            for ( Timer=0;  Timer<10; Timer++ ) {          
            // Timer loop - number of display scans before incrementing the counter...
                switch (AnodeCtr) {
                    case 0b00000001:                        // Current Anode = Anode_0
                        AnodeCtr = 0b00100000 ;             // Next Anode    = Anode_1
                        temp = Nixie[1] ;                   // Next digit    = digit_1
                        break ;
                    case 0b00100000:                        // Current Anode = Anode_1
                        AnodeCtr = 0b00010000 ;             // Next Anode    = Anode_2
                        temp = Nixie[2] ;                   // Next digit    = digit_2
                        break ;
                    default:                                // Current Anode = Anode_2
                        AnodeCtr = 0b00000001 ;             // Next Anode    = Anode_0
                        temp = Nixie[0] ;                   // Next digit    = digit_0
                        break ;
                }
                // Update the Nixie ports to create the display scan...                
                LATA = PORT_A[temp] ;
                LATB = PORT_B[temp] ;
                LATC = PORT_C[temp] | AnodeCtr ;            // Merge Cathode and Anode bits onto the port

                // Pause before displaying the next digit...
                __delay_ms(_SCAN_PERIOD);
            }
        }
    }    
}


