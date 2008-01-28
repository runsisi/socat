/* source: xio-stdio.h */
/* Copyright Gerhard Rieger 2001-2006 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xio_stdio_h_included
#define __xio_stdio_h_included 1



extern int xioopen_stdio_bi(xiofile_t *sock);

extern const struct addrdesc addr_stdio;
extern const struct addrdesc addr_stdin;
extern const struct addrdesc addr_stdout;
extern const struct addrdesc addr_stderr;

#endif /* !defined(__xio_stdio_h_included) */
