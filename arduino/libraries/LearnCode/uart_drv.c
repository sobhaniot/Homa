//******************************************************************************
//! @file $RCSfile: uart_drv.c,v $
//!
//! Copyright (c) 2007 Atmel.
//!
//! Use of this program is subject to Atmel's End User License Agreement.
//! Please read file license.txt for copyright notice.
//!
//! @brief This file contains the low level functions (drivers) of:
//!             - Both UARTs
//!             - for AT90CAN128/64/32
//!
//! This file can be parsed by Doxygen for automatic documentation generation.
//! This file has been validated with AVRStudio-413528/WinAVR-20070122.
//!
//! @version $Revision: 3.20 $ $Name: jtellier $
//!
//! @todo
//! @bug
//******************************************************************************

//_____ I N C L U D E S ________________________________________________________
//#include "config.h"
#include "uart_drv.h"
//#include "timer16_drv.h"

//_____ D E F I N I T I O N S __________________________________________________

//_____ D E C L A R A T I O N S ________________________________________________
#if (USE_UART == BOTH_UART)
    U8 uart_selected;
#endif

//_____ F U N C T I O N S ______________________________________________________

#if ((UART_BAUDRATE == VARIABLE_UART_BAUDRATE) || (UART_BAUDRATE == UART_AUTOBAUD))
//------------------------------------------------------------------------------
//  @fn uart_set_baudrate
//!
//! This function programs the UBRRH register of both the UARTs from the
//! value passed as parameter or from an automatic timing detection if
//! there is an 'U' character received on the serial link. This function
//! is called by "Uart_set_baudrate(baudrate)" macro.
//! The function rounds to nearest the division result (i.e. FOSC/BAUDRATE).
//!
//! @warning Lower limit is 300 Bauds per MHz (ex: at 8MHz, lower limit
//!          is 2400 Bauds).
//!          Writting UBBR_L triggers an immediate update of the baud
//!          rate prescaler.
//!     Note the role of SOF_DETECTION !
//!
//! @param  !=0: baudrate value
//!         ==0: automatic baudrate detection
//!
//! @return Baudrate Status
//!         ==0: baudrate configuration failed
//!         ==1: baudrate performed
//------------------------------------------------------------------------------
U8 uart_set_baudrate (U32 baudrate)
{
    U16 t_meas_4=0;

    if (baudrate != 0)
    {
        // UBRRN Value (rounded to nearest division) with U2Xn=1
        t_meas_4 = (U16)(( (((((U32)F_CPU)<<1)/((U32)baudrate*8))+1)>>1)-1);
    }

    #if (USE_UART ==  UART_0)
        UBRR0H  = (U8)((t_meas_4)>>8);
        UBRR0L  = (U8) (t_meas_4)    ;
        UCSR0A |=  (1<<U2X0);
    #elif (USE_UART ==  UART_1)
        UBRR1H  = (U8)((t_meas_4)>>8);
        UBRR1L  = (U8) (t_meas_4)    ;
        UCSR1A |=  (1<<U2X1);
    #elif (USE_UART ==  BOTH_UART)
        if (uart_selected == UART_0)
        {
            UBRR0H  = (U8)((t_meas_4)>>8);
            UBRR0L  = (U8) (t_meas_4)    ;
            UCSR0A |=  (1<<U2X0);
        }
        if (uart_selected == UART_1)
        {
            UBRR1H  = (U8)((t_meas_4)>>8);
            UBRR1L  = (U8) (t_meas_4)    ;
            UCSR1A |=  (1<<U2X1);
        }
    #   else
    #       error USE_UART definition is not referenced in "uart_drv.h" file
    #endif
    
    return 1;
}

#endif  // #endif of '((UART_BAUDRATE == ...'


//------------------------------------------------------------------------------
//  @fn uart_rx_get_3_data
//!
//! This function returns the UART pin value sampled 3 times.
//!
//! @warning none
//!
//! @param  none
//!
//! @return UART pin value sampled 3 times
//------------------------------------------------------------------------------
Bool uart_rx_get_3_data (void)
{
U8 u8_temp = 0;

#if ((USE_UART == UART_0) || (USE_UART == UART_1))
    u8_temp = Uart_rx_get_3_data();
    
#elif (USE_UART ==  BOTH_UART)
    if (uart_selected == UART_0)
    {
        u8_temp = (UART_0_PORT_IN  & UART_0_PORT_IN  & UART_0_PORT_IN  & (1<<UART_0_INPUT_PIN)) >> UART_0_INPUT_PIN;
    }
    if (uart_selected == UART_1)
    {
        u8_temp = (UART_1_PORT_IN  & UART_1_PORT_IN  & UART_1_PORT_IN  & (1<<UART_1_INPUT_PIN)) >> UART_1_INPUT_PIN;
    }
#   else
#       error USE_UART definition is not referenced in "uart_drv.h" file
#endif

    return u8_temp;
}


//------------------------------------------------------------------------------
//  @fn uart_rx_get_data
//!
//! This function returns the UART pin value.
//!
//! @warning none
//!
//! @param  none
//!
//! @return UART pin value
//------------------------------------------------------------------------------
Bool uart_rx_get_data (void)
{
U8 u8_temp = 0;

#if ((USE_UART == UART_0) || (USE_UART == UART_1))
    u8_temp = Uart_rx_get_data();
    
#elif (USE_UART ==  BOTH_UART)
    if (uart_selected == UART_0)
    {
        u8_temp = (UART_0_PORT_IN  & (1<<UART_0_INPUT_PIN)) >> UART_0_INPUT_PIN;
    }
    if (uart_selected == UART_1)
    {
        u8_temp = (UART_1_PORT_IN  & (1<<UART_1_INPUT_PIN)) >> UART_1_INPUT_PIN;
    }
#   else
#       error USE_UART definition is not referenced in "uart_drv.h" file
#endif

    return u8_temp;
}














