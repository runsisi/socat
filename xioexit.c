/* source: xioexit.c */
/* Copyright Gerhard Rieger 2001-2005 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for the extended exit function */

#include "xiosysincludes.h"
#include "xio.h"


/* this function closes all open xio sockets on exit, if they are still open.
   It must be registered with atexit(). */ 
void xioexit(void) {
   int i;

   for (i = 0; i < XIO_MAXSOCK; ++i) {
      if (sock[i] != NULL && sock[i]->tag != XIO_TAG_INVALID) {
	 xioclose(sock[i]);
      }
   }
}
