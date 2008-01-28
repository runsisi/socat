/* source: xio-ip4.c */
/* Copyright Gerhard Rieger 2001-2007 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for IP4 related functions */

#include "xiosysincludes.h"

#if WITH_IP4

#include "xioopen.h"
#include "xio-socket.h"
#include "xio-ip.h"
#include "xio-ip4.h"

/* check if peer address is within permitted range.
   return >= 0 if so. */
int xiocheckrange_ip4(struct sockaddr_in *pa, struct xiorange_ip4 *range) {
   struct in_addr *netaddr_in = &range->netaddr;
   struct in_addr *netmask_in = &range->netmask;
   char addrbuf[256], maskbuf[256];
   char peername[256];

   /* is provided client address valid? */
   if (pa->sin_addr.s_addr == 0) {
      Warn("invalid client address 0.0.0.0");
      return -1;
   }
   /* client address restriction */
   Debug2("permitted client subnet: %s:%s",
	  inet4addr_info(ntohl(netaddr_in->s_addr), addrbuf, sizeof(addrbuf)),
	  inet4addr_info(ntohl(netmask_in->s_addr), maskbuf, sizeof(maskbuf)));
   Debug1("client address is 0x%08x",
	  ntohl(pa->sin_addr.s_addr));
   Debug1("masked address is 0x%08x",
	  ntohl(pa->sin_addr.s_addr & netmask_in->s_addr));
   if ((pa->sin_addr.s_addr & netmask_in->s_addr)
       != netaddr_in->s_addr) {
      Debug1("client address %s is not permitted",
	     sockaddr_inet4_info(pa, peername, sizeof(peername)));
      return -1;
   }
   return 0;
}

#endif /* WITH_IP4 */
