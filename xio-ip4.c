/* source: xio-ip4.c */
/* Copyright Gerhard Rieger 2001-2008 */
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

/* returns information that can be used for constructing an environment
   variable describing the socket address.
   if idx is 0, this function writes "ADDR" into namebuff and the IP address
   into valuebuff, and returns 1 (which means that one more info is there).
   if idx is 1, it writes "PORT" into namebuff and the port number into
   valuebuff, and returns 0 (no more info)
   namelen and valuelen contain the max. allowed length of output chars in the
   respective buffer.
   on error this function returns -1.
*/
int
xiosetsockaddrenv_ip4(int idx, char *namebuff, size_t namelen,
		      char *valuebuff, size_t valuelen,
		      struct sockaddr_in *sa, int ipproto) {
   switch (idx) {
   case 0:
      strcpy(namebuff, "ADDR");
      strcpy(valuebuff,
	     inet4addr_info(ntohl(sa->sin_addr.s_addr), valuebuff, valuelen));
      switch (ipproto) {
      case IPPROTO_TCP:
      case IPPROTO_UDP:
#ifdef IPPROTO_SCTP
      case IPPROTO_SCTP:
#endif
	 return 1;	/* there is port information to also be retrieved */
      default:
	 return 0;	/* no port info coming */
      }
   case 1:
      strcpy(namebuff, "PORT");
      snprintf(valuebuff, valuelen, "%u", ntohs(sa->sin_port));
      return 0;
   }
   return -1;
}

#endif /* WITH_IP4 */
