/* source: xio-ip4.h */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xio_ip4_h_included
#define __xio_ip4_h_included 1

extern const struct optdesc opt_ip4_add_membership;

extern
int xioparsenetwork_ip4(const char *rangename, struct xiorange *range);
extern
int xiocheckrange_ip4(struct sockaddr_in *pa, struct xiorange *range);

#endif /* !defined(__xio_ip4_h_included) */
