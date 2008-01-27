/* $Id: xiohelp.h,v 1.2 2001/11/04 17:19:21 gerhard Exp $ */
/* Copyright Gerhard Rieger 2001 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xiohelp_h_included
#define __xiohelp_h_included 1

extern int xioopenhelp(FILE *of,
	       int level	/* 0..only addresses, 1..and options */
	       );

#endif /* !defined(__xiohelp_h_included) */
