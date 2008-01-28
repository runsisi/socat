/* source: xio-ip6.c */
/* Copyright Gerhard Rieger 2001-2007 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for IP6 related functions */

#include "xiosysincludes.h"

#if WITH_IP6

#include "xioopen.h"
#include "xio-socket.h"
#include "xio-ip.h"	/* xiogetaddrinfo() */

#include "xio-ip6.h"

#ifdef IPV6_V6ONLY
const struct optdesc opt_ipv6_v6only = { "ipv6-v6only", "ipv6only", OPT_IPV6_V6ONLY, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_V6ONLY };
#endif
#ifdef IPV6_JOIN_GROUP
const struct optdesc opt_ipv6_join_group = { "ipv6-join-group", "join-group", OPT_IPV6_JOIN_GROUP, GROUP_SOCK_IP6, PH_PASTBIND, TYPE_IP_MREQN, OFUNC_SOCKOPT, SOL_IPV6, IPV6_JOIN_GROUP };
#endif

int xioparsenetwork_ip6(const char *rangename, struct xiorange_ip6 *range) {
   char *delimpos;	/* absolute address of delimiter */
   size_t delimind;	/* index of delimiter in string */
   int bits;
   char *baseaddr;
   union sockaddr_union sockaddr;
   socklen_t sockaddrlen = sizeof(sockaddr);
   union xioin6_u *rangeaddr = (union xioin6_u *)&range->addr;
   union xioin6_u *rangemask = (union xioin6_u *)&range->mask;
   union xioin6_u *nameaddr = (union xioin6_u *)&sockaddr.ip6.sin6_addr;

   if (rangename[0] != '[' || rangename[strlen(rangename)-1] != ']') {
      Error1("missing brackets for IPv6 range definition \"%s\"",
	     rangename);
      return STAT_NORETRY;
   }
   if ((delimpos = strchr(rangename, '/')) == NULL) {
      Error1("xioparsenetwork_ip6(\"%s\",,): missing mask bits delimiter '/'",
	     rangename);
      return STAT_NORETRY;
   }
   delimind = delimpos - rangename;

   if ((baseaddr = strdup(rangename+1)) == NULL) {
      Error1("strdup(\"%s\"): out of memory", rangename+1);
      return STAT_NORETRY;
   }
   baseaddr[delimind-1] = '\0';
   if (xiogetaddrinfo(baseaddr, NULL, PF_INET6, 0, 0, &sockaddr, &sockaddrlen,
		      0, 0)
       != STAT_OK) {
      return STAT_NORETRY;
   }
   rangeaddr->u6_addr32[0] = nameaddr->u6_addr32[0];
   rangeaddr->u6_addr32[1] = nameaddr->u6_addr32[1];
   rangeaddr->u6_addr32[2] = nameaddr->u6_addr32[2];
   rangeaddr->u6_addr32[3] = nameaddr->u6_addr32[3];
   bits = strtoul(delimpos+1, NULL, 10);
   if (bits > 128) {
      Error1("invalid number of mask bits %u", bits);
      return STAT_NORETRY;
   }
   if (bits < 32) {
      rangemask->u6_addr32[0] = htonl(0xffffffff << (32-bits));
      rangemask->u6_addr32[1] = 0;
      rangemask->u6_addr32[2] = 0;
      rangemask->u6_addr32[3] = 0;
   } else if (bits < 64) {
      rangemask->u6_addr32[0] = 0xffffffff;
      rangemask->u6_addr32[1] = htonl(0xffffffff << (64-bits));
      rangemask->u6_addr32[2] = 0;
      rangemask->u6_addr32[3] = 0;
   } else if (bits < 96) {
      rangemask->u6_addr32[0] = 0xffffffff;
      rangemask->u6_addr32[1] = 0xffffffff;
      rangemask->u6_addr32[2] = htonl(0xffffffff << (96-bits));
      rangemask->u6_addr32[3] = 0;
   } else {
      rangemask->u6_addr32[0] = 0xffffffff;
      rangemask->u6_addr32[1] = 0xffffffff;
      rangemask->u6_addr32[2] = 0xffffffff;
      rangemask->u6_addr32[3] = htonl(0xffffffff << (128-bits));
   }
   return 0;
}

int xiorange_ip6andmask(struct xiorange_ip6 *range) {
   int i;
#if 0
   range->addr.s6_addr32[0] &= range->mask.s6_addr32[0];
   range->addr.s6_addr32[1] &= range->mask.s6_addr32[1];
   range->addr.s6_addr32[2] &= range->mask.s6_addr32[2];
   range->addr.s6_addr32[3] &= range->mask.s6_addr32[3];
#else
   for (i = 0; i < 16; ++i) {
      range->addr.s6_addr[i] &= range->mask.s6_addr[i];
   }
#endif
   return 0;
}

/* check if peer address is within permitted range.
   return >= 0 if so. */
int xiocheckrange_ip6(struct sockaddr_in6 *pa, struct xiorange_ip6 *range) {
   union xioin6_u masked;
   int i;
   char peername[256];
   union xioin6_u *rangeaddr = (union xioin6_u *)&range->addr;
   union xioin6_u *rangemask = (union xioin6_u *)&range->mask;

   Debug16("permitted client subnet: [%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]:[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]",
	   htons(rangeaddr->u6_addr16[0]),  htons(rangeaddr->u6_addr16[1]),
	   htons(rangeaddr->u6_addr16[2]),  htons(rangeaddr->u6_addr16[3]),
	   htons(rangeaddr->u6_addr16[4]),  htons(rangeaddr->u6_addr16[5]),
	   htons(rangeaddr->u6_addr16[6]),  htons(rangeaddr->u6_addr16[7]),
	   htons(rangemask->u6_addr16[0]),  htons(rangemask->u6_addr16[1]),
	   htons(rangemask->u6_addr16[2]),  htons(rangemask->u6_addr16[3]),
	   htons(rangemask->u6_addr16[4]),  htons(rangemask->u6_addr16[5]),
	   htons(rangemask->u6_addr16[6]),  htons(rangemask->u6_addr16[7]));
   Debug1("client address is %s",
	  sockaddr_inet6_info(pa, peername, sizeof(peername)));

   for (i = 0; i < 4; ++i) {
      masked.u6_addr32[i] = pa->sin6_addr.s6_addr[i] & rangemask->u6_addr16[i];
   }
   Debug8("masked address is [%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]",
	   htons(masked.u6_addr16[0]),  htons(masked.u6_addr16[1]),
	   htons(masked.u6_addr16[2]),  htons(masked.u6_addr16[3]),
	   htons(masked.u6_addr16[4]),  htons(masked.u6_addr16[5]),
	   htons(masked.u6_addr16[6]),  htons(masked.u6_addr16[7]));

   if (masked.u6_addr32[0] != rangeaddr->u6_addr32[0] ||
       masked.u6_addr32[1] != rangeaddr->u6_addr32[1] ||
       masked.u6_addr32[2] != rangeaddr->u6_addr32[2] ||
       masked.u6_addr32[3] != rangeaddr->u6_addr32[3]) {
      Debug1("client address %s is not permitted", peername); 
      return -1;
   }
   return 0;
}

#endif /* WITH_IP6 */
