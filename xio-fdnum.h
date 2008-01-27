/* $Id: xio-fdnum.h,v 1.6 2006/03/21 20:48:31 gerhard Exp $ */
/* Copyright Gerhard Rieger 2001-2006 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xio_fdnum_h_included
#define __xio_fdnum_h_included 1

extern const struct addrdesc addr_fd;

extern int xioopen_fd(struct opt *opts, int rw, xiosingle_t *xfd, int numfd, int dummy2, int dummy3);

#endif /* !defined(__xio_fdnum_h_included) */
