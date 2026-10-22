/*
 * Learn Code.c
 *
 * Created: 14/06/1396 10:10:40 ق.ظ
 * Author : DESIGNER
 */ 

#include <avr/io.h>
#define F_CPU			16000000UL
#define USE_UART		 BOTH_UART
#include <util/delay.h>
#include <avr/interrupt.h>
#include <stdio.h>
#include <stdbool.h>
#include "compiler.h"
#include "EV17xx_Decoder.c"
#include "eeprom_store.c"
#include "uart_drv.c"
#include "uart_lib.c"

#define Key_Pin		PORTF0
#define Key_PORT	PORTF
#define Key_DDR		DDRF
#define Key_PIN		PINF

#define LED_Pin		PORTE5
#define	LED_PORT	PORTE
#define LED_DDR		DDRE

#define CH0_Pin		PORTE4
#define CH1_Pin		PORTE3
#define CH2_Pin		PORTE4
#define CH3_Pin		PORTE3
#define CH_PORT		PORTE
#define CH_DDR		DDRE

#define IS_Press_Key()		((Key_PIN&(1<<Key_Pin)))
#define LED_Tog()			LED_PORT ^= (1<<LED_Pin)
#define LED_On()			LED_PORT |= (1<<LED_Pin)

enum
{
	Nurmal = 0,
	Learn,
	Erase,
};

char buffer[50];

int main(void)
{
	_delay_ms(1000);
	
	uart_selected = UART_0;
	uart_init(CONF_8BIT_NOPAR_1STOP,9600);
    uart_put_string("START...",1);
	uart_put_string("START...",1);
	uart_put_string("START...",1);
	
	Key_DDR &=~(1<<Key_Pin); 
	Key_PORT |=(1<<Key_Pin); 
	LED_DDR  |=(1<<LED_Pin);
	CH_DDR   |=((1<<CH0_Pin) | (1<<CH1_Pin) | (1<<CH2_Pin) | (1<<CH3_Pin));
	
	// External Interrupt(s) initialization
	// INT4: On
	// INT4 Mode: Any change
	EICRB=(1<<ISC60);
	EIMSK=(1<<INT6);
	EIFR=(1<<INTF6);
	
	sei();

	uart_put_string("Zeus 4CH Remote Control",1);
	uart_put_string("This Code Write By DESIGNER2013.BLOGSKY.COM",1);
	uint32_t Press_Time = 0;
	uint32_t SysTime = 0;
	uint32_t LEDTime = 0;
	uint8_t  Work_Mode = Nurmal;
	uint32_t Lcode = 0;
	uint32_t CodeTime = 0;
	
    while (1) 
    {
		if(IS_Recive_Valid_Remote()) /*If Have Code For Remote*/
		{
			uint32_t Rcode = Get_Remote_Code_long();
			CodeTime = SysTime;
			if(Lcode!=Rcode)
			{
				Lcode = Rcode;

				if(Work_Mode==Nurmal)
				{
					if(EE_ISValidCode(Rcode&0xFFFFFFF0)) /*If Valid Code*/
					{
						uint8_t Rkey = Rcode&0xFF;
						sprintf(buffer,"Code Is Valid Action...%d",Rkey);
						uart_put_string(buffer,1);

						if(Rkey&1)
						CH_PORT ^= (1<<CH0_Pin);
						if(Rkey&2)
						CH_PORT ^= (1<<CH1_Pin);
						if(Rkey&4)
						CH_PORT ^= (1<<CH2_Pin);
						if(Rkey&8)
						CH_PORT ^= (1<<CH3_Pin);
					}
					else
					{
						uart_put_string("This Remote Not Valid!",1);
					}
				}
				else if(Work_Mode==Learn)
				{
					if(!EE_ISValidCode(Rcode&0xFFFFFFF0)) /*If Not Have Code*/
					{
						uart_put_string("Learn This Remote...",1);
						EE_StoreCode(Rcode&0xFFFFFFF0);
					}
					Work_Mode = Nurmal;
				}
			}
		}
		else
		{
			if((SysTime - CodeTime) > 500)
			{
				Lcode = 0; /*Reset Last Code*/
			}
		}
		
		if(IS_Press_Key()==0)
		{
			Press_Time++;
		}
		else
		{
			if(Press_Time>1000 && Press_Time<3000)
			{
				uart_put_string("Enter Learn Mode",1);
				Work_Mode = Learn;
			}
			else if(Press_Time>5000 && Press_Time<15000)
			{
				uart_put_string("Enter Erase Mode",1);
				LED_On();
				EE_Format();
				_delay_ms(3000);
				LED_Tog();
			}
			Press_Time = 0;
		}
		
		/*Blink Control LED*/
		if(Work_Mode==Nurmal)
		{
			if(LEDTime==0 || (SysTime-LEDTime) > 1000) /*Evry 1Sec*/
			{
				LEDTime = SysTime;
				LED_Tog();
			}
		}
		else if(Work_Mode==Learn)
		{
			if(LEDTime==0 || (SysTime-LEDTime) > 100) /*Evry 100 mSec*/
			{
				LEDTime = SysTime;
				LED_Tog();
			}
		}

		SysTime++;
		_delay_ms(1);
    }
}

