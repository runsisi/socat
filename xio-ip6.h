/* source: xio-ip6.h */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xio_ip6_h_included
#define __xio_ip6_h_included 1

#if WITH_IP6

extern const struct optdesc opt_ipv6_v6only;
extern const struct optdesc opt_ipv6_join_group;

extern
int xioparsenetwork_ip6(const char *rangename, struct xiorange *range);
extern int xiorange_ip6andmask(struct xiorange *range);

extern
int xiocheckrange_ip6(struct sockaddr_in6 *pa, struct xiorange *range);

#endif /* WITH_IP6 */

#endif /* !defined(__xio_ip6_h_included) */
