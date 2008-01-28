/* source: xio-ip4.h */
/* Copyright Gerhard Rieger 2001-2007 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xio_ip4_h_included
#define __xio_ip4_h_included 1

extern const struct optdesc opt_ip4_add_membership;

extern
int xiocheckrange_ip4(struct sockaddr_in *pa, struct xiorange_ip4 *range);

#endif /* !defined(__xio_ip4_h_included) */
