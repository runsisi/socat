/* source: procan-cdefs.c */
/* Copyright Gerhard Rieger 2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* a function that prints compile time parameters */
/* the set of parameters is only a small subset of the available defines and
   will be extended on demand */


#include "xiosysincludes.h"
#include "mytypes.h"
#include "compat.h"
#include "error.h"

#include "procan.h"

int procan_cdefs(FILE *outfile) {
   /* basic C/system constants */
#ifdef FD_SETSIZE
   fprintf(outfile, "#define FD_SETSIZE %u\n", FD_SETSIZE);
#endif
#ifdef NFDBITS
   fprintf(outfile, "#define NFDBITS %u\n", NFDBITS);
#endif
#ifdef O_RDONLY
   fprintf(outfile, "#define O_RDONLY %u\n", O_RDONLY);
#endif
#ifdef O_WRONLY
   fprintf(outfile, "#define O_WRONLY %u\n", O_WRONLY);
#endif
#ifdef O_RDWR
   fprintf(outfile, "#define O_RDWR %u\n", O_RDWR);
#endif
#ifdef SHUT_RD
   fprintf(outfile, "#define SHUT_RD %u\n", SHUT_RD);
#endif
#ifdef SHUT_WR
   fprintf(outfile, "#define SHUT_WR %u\n", SHUT_WR);
#endif
#ifdef SHUT_RDWR
   fprintf(outfile, "#define SHUT_RDWR %u\n", SHUT_RDWR);
#endif

   /* termios constants */
#ifdef CRDLY
   fprintf(outfile, "#define CRDLY 0%011o\n", CRDLY);
#endif
#ifdef CR0
   fprintf(outfile, "#define CR0 0%011o\n", CR0);
#endif
#ifdef CR1
   fprintf(outfile, "#define CR1 0%011o\n", CR1);
#endif
#ifdef CR2
   fprintf(outfile, "#define CR2 0%011o\n", CR2);
#endif
#ifdef CR3
   fprintf(outfile, "#define CR3 0%011o\n", CR3);
#endif
#ifdef TABDLY
   fprintf(outfile, "#define TABDLY 0%011o\n", TABDLY);
#endif
#ifdef TAB0
   fprintf(outfile, "#define TAB0 0%011o\n", TAB0);
#endif
#ifdef TAB1
   fprintf(outfile, "#define TAB1 0%011o\n", TAB1);
#endif
#ifdef TAB2
   fprintf(outfile, "#define TAB2 0%011o\n", TAB2);
#endif
#ifdef TAB3
   fprintf(outfile, "#define TAB3 0%011o\n", TAB3);
#endif
#ifdef CSIZE
   fprintf(outfile, "#define CSIZE 0%011o\n", CSIZE);
#endif

   /* stdio constants */
#ifdef FOPEN_MAX
   fprintf(outfile, "#define FOPEN_MAX %u\n", FOPEN_MAX);
#endif
   return 0;
}
