//******************************************************************************
//! @file $RCSfile: compiler.h,v $
//!
//! Copyright (c) 2007 Atmel.
//!
//! Use of this program is subject to Atmel's End User License Agreement.
//! Please read file license.txt for copyright notice.
//!
//! @brief This file (re)defines ATMEL-App.Lab compiler keywords in order to
//! to ensure that any source file can be processed. The device targeted belongs
//! to AT90CANxx family.
//!
//! This file can be parsed by Doxygen for automatic documentation generation.
//! This file has been validated with AVRStudio-413528/WinAVR-20070122.
//!
//! @version $Revision: 3.20 $ $Name: jtellier $
//!
//! @todo
//! @bug
//******************************************************************************

#ifndef _COMPILER_H_
#define _COMPILER_H_

//_____ D E C L A R A T I O N S ________________________________________________

typedef unsigned char      Bool;

typedef unsigned char       U8 ;
typedef unsigned short      U16;
typedef unsigned long       U32;
typedef unsigned long long  U64;
typedef signed char         S8 ;
typedef signed short        S16;
typedef signed long         S32;
typedef signed long long    S64;

typedef union
{
  U16 h   ;     // h as HALF-WORD
  U8  b[2];     // b as BYTE
} Union16;

typedef union
{
  U32 w   ;     // w as WORD
  U16 h[2];     // h as HALF-WORD
  U8  b[4];     // b as BYTE
} Union32;

typedef union
{
  U64 d   ;     // d as DOUBLE-WORD
  U32 w[2];     // w as WORD
  U16 h[4];     // h as HALF-WORD
  U8  b[8];     // b as BYTE
} Union64;

//_____ M A C R O S ____________________________________________________________

//! Some usefull macros...
    // Max(a, b): Take the max between a and b
    // Min(a, b): Take the min between a and b
    // Align_up(val, n):   Around (up)   the number (val) on the (n) boundary
    // Align_down(val, n): Around (down) the number (val) on the (n) boundary
#define Max(a, b)          ( (a)>(b) ? (a) : (b) )
#define Min(a, b)          ( (a)<(b) ? (a) : (b) )
#define Align_up(val, n)   ( ((val)+(n)-1) & ~((n)-1) )
#define Align_down(val, n) (  (val)        & ~((n)-1) )

//! Bit and bytes manipulations
#define Low(data_w)                ((U8)data_w)
#define High(data_w)               ((U8)(data_w>>8))
#define Tst_bit_x(addrx,mask)   (*addrx & mask)
#define Set_bit_x(addrx,mask)   (*addrx = (*addrx |  mask))
#define Clr_bit_x(addrx,mask)   (*addrx = (*addrx & ~mask))

//! The default value to initialise pointers
#define  NULL              ((void *)0)

//! Constants
#define ENABLE   1
#define ENABLED  1
#define DISABLED 0
#define DISABLE  0
#define FALSE   (0==1)
#define TRUE    (1==1)
#define KO      0
#define OK      1
#define CLR     0
#define SET     1
#define OFF     2
#define ON      1

//______________________________________________________________________________
#ifndef TYPEDEFS_H
#define TYPEDEFS_H
//==============================================================================
// S E N S I R I O N AG, Laubisruetistr. 50, CH-8712 Stefa, Switzerland
//==============================================================================
// Project : SHT2xSample Code (V1.2)
// File : typedefs.h
// Author : MST
// Controller: Atmega32
// Compiler : AtmelStudio compiler for AVR
// Brief : Definitions of typedefs for good readability and portability
//==============================================================================
//----------Defines -----------------------------------------------------------//Processor endian system
//#define BIG ENDIAN //e.g. Motorola (not tested at this time)
#define LITTLE_ENDIAN  //e.g. PIC, 8051, NEC V850
//==============================================================================
// basic types: making the size of types clear
//==============================================================================

typedef unsigned char	u8t;	///< range: 0 .. 255
typedef signed	 char	i8t;	///< range: -128 .. +127
typedef unsigned short  u16t;	///< range: 0 .. 65535
typedef signed	 short  i16t;	///< range: -32768 .. +32767
typedef unsigned long   u32t;	///< range: 0 .. 4'294'967'295
typedef signed	 long	i32t;	///< range: -2'147'483'648 .. +2'147'483'647
typedef			 float	ft;		///< range: +-1.18E-38 .. +-3.39E+38
typedef			 double dt;		///< range: .. +-1.79E+308
typedef			 bool	bt;		///< values: 0, 1 (real bool used)

typedef union{
	u16t u16;  // element specifier for accessing whole u16
	i16t i16;  // element specifier for accessing whole i16
	struct{
		#ifdef LITTLE_ENDIAN  //Byte-order is little endian
		u8t u8L;  // element specifier for accessing low u8
		u8t u8H;  // element specifier for accessing high u8
		#else  // Byte-order is big endian
		u8t u8H;  // element specifier for accessing low u8
		u8t u8L;  // element specifier for accessing high u8
		#endif
	} s16;  // element spec. for acc. struct with low or high u8
} nt16;

typedef union{
	u32t u32;  // element specifier for accessing whole u32
	i32t i32;  // element specifier for accessing whole i32
	struct{
		#ifdef LITTLE_ENDIAN  // Byte-order is little endian
		u16t u16L;  // element specifier for accessing low u16
		u16t u16H;    // element specifier for accessing high u16
		#else  // Byte-order is big endian
		u16t u16H;  // element specifier for accessing low u16
		u16t u16L;  // element specifier for accessing high u16
		#endif
	} s32;  // element spec. for acc. struct with low or high u16
} nt32;
#endif


#endif // _COMPILER_H_
