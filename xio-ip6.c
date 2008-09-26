/* source: xio-ip6.c */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for IP6 related functions */

#include "xiosysincludes.h"

#if WITH_IP6

#include "xioopen.h"
#include "xio-ascii.h"
#include "xio-socket.h"
#include "xio-ip.h"	/* xiogetaddrinfo() */

#include "xio-ip6.h"


static char *inet6addr_info(const struct in6_addr *sa, char *buff, size_t blen);


#ifdef IPV6_V6ONLY
const struct optdesc opt_ipv6_v6only = { "ipv6-v6only", "ipv6only", OPT_IPV6_V6ONLY, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_V6ONLY };
#endif
#ifdef IPV6_JOIN_GROUP
const struct optdesc opt_ipv6_join_group = { "ipv6-join-group", "join-group", OPT_IPV6_JOIN_GROUP, GROUP_SOCK_IP6, PH_PASTBIND, TYPE_IP_MREQN, OFUNC_SOCKOPT, SOL_IPV6, IPV6_JOIN_GROUP };
#endif
const struct optdesc opt_ipv6_pktinfo = { "ipv6-pktinfo", "pktinfo", OPT_IPV6_PKTINFO, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_PKTINFO };
#ifdef IPV6_RECVPKTINFO
const struct optdesc opt_ipv6_recvpktinfo = { "ipv6-recvpktinfo", "recvpktinfo", OPT_IPV6_RECVPKTINFO, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVPKTINFO };
#endif
const struct optdesc opt_ipv6_rthdr   = { "ipv6-rthdr",   "rthdr",   OPT_IPV6_RTHDR,   GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RTHDR };
#ifdef IPV6_RECVRTHDR
const struct optdesc opt_ipv6_recvrthdr   = { "ipv6-recvrthdr",   "recvrthdr",   OPT_IPV6_RECVRTHDR,   GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVRTHDR };
#endif
#ifdef IPV6_AUTHHDR
const struct optdesc opt_ipv6_authhdr = { "ipv6-authhdr", "authhdr", OPT_IPV6_AUTHHDR, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_AUTHHDR };
#endif
const struct optdesc opt_ipv6_dstopts = { "ipv6-dstopts", "dstopts", OPT_IPV6_DSTOPTS, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_DSTOPTS };
#ifdef IPV6_RECVDSTOPTS
const struct optdesc opt_ipv6_recvdstopts = { "ipv6-recvdstopts", "recvdstopts", OPT_IPV6_RECVDSTOPTS, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVDSTOPTS };
#endif
const struct optdesc opt_ipv6_hopopts = { "ipv6-hopopts", "hopopts", OPT_IPV6_HOPOPTS, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_HOPOPTS };
#ifdef IPV6_RECVHOPOPTS
const struct optdesc opt_ipv6_recvhopopts = { "ipv6-recvhopopts", "recvhopopts", OPT_IPV6_RECVHOPOPTS, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVHOPOPTS };
#endif
#ifdef IPV6_FLOWINFO /* is in linux/in6.h */
const struct optdesc opt_ipv6_flowinfo= { "ipv6-flowinfo","flowinfo",OPT_IPV6_FLOWINFO,GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_FLOWINFO };
#endif
const struct optdesc opt_ipv6_hoplimit= { "ipv6-hoplimit","hoplimit",OPT_IPV6_HOPLIMIT,GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_HOPLIMIT };
const struct optdesc opt_ipv6_unicast_hops= { "ipv6-unicast-hops","unicast-hops",OPT_IPV6_UNICAST_HOPS,GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_IPV6, IPV6_UNICAST_HOPS };
#ifdef IPV6_RECVHOPLIMIT
const struct optdesc opt_ipv6_recvhoplimit= { "ipv6-recvhoplimit","recvhoplimit",OPT_IPV6_RECVHOPLIMIT,GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVHOPLIMIT };
#endif
#ifdef IPV6_RECVERR
const struct optdesc opt_ipv6_recverr = { "ipv6-recverr", "recverr", OPT_IPV6_RECVERR, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVERR };
#endif
#ifdef IPV6_TCLASS
const struct optdesc opt_ipv6_tclass     = { "ipv6-tclass",     "tclass",     OPT_IPV6_TCLASS,     GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_IPV6, IPV6_TCLASS };
#endif
#ifdef IPV6_RECVTCLASS
const struct optdesc opt_ipv6_recvtclass = { "ipv6-recvtclass", "recvtclass", OPT_IPV6_RECVTCLASS, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVTCLASS };
#endif
#ifdef IPV6_RECVPATHMTU
const struct optdesc opt_ipv6_recvpathmtu = { "ipv6-recvpathmtu", "recvpathmtu", OPT_IPV6_RECVPATHMTU, GROUP_SOCK_IP6, PH_PASTSOCKET, TYPE_BOOL, OFUNC_SOCKOPT, SOL_IPV6, IPV6_RECVPATHMTU };
#endif

int xioparsenetwork_ip6(const char *rangename, struct xiorange *range) {
   char *delimpos;	/* absolute address of delimiter */
   size_t delimind;	/* index of delimiter in string */
   int bits;
   char *baseaddr;
   union sockaddr_union sockaddr;
   socklen_t sockaddrlen = sizeof(sockaddr);
   union xioin6_u *rangeaddr = (union xioin6_u *)&range->netaddr.ip6.sin6_addr;
   union xioin6_u *rangemask = (union xioin6_u *)&range->netmask.ip6.sin6_addr;
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

int xiorange_ip6andmask(struct xiorange *range) {
   int i;
#if 0
   range->addr.s6_addr32[0] &= range->mask.s6_addr32[0];
   range->addr.s6_addr32[1] &= range->mask.s6_addr32[1];
   range->addr.s6_addr32[2] &= range->mask.s6_addr32[2];
   range->addr.s6_addr32[3] &= range->mask.s6_addr32[3];
#else
   for (i = 0; i < 16; ++i) {
      range->netaddr.ip6.sin6_addr.s6_addr[i] &=
	 range->netmask.ip6.sin6_addr.s6_addr[i];
   }
#endif
   return 0;
}

/* check if peer address is within permitted range.
   return >= 0 if so. */
int xiocheckrange_ip6(struct sockaddr_in6 *pa, struct xiorange *range) {
   union xioin6_u masked;
   int i;
   char peername[256];
   union xioin6_u *rangeaddr = (union xioin6_u *)&range->netaddr.ip6.sin6_addr;
   union xioin6_u *rangemask = (union xioin6_u *)&range->netmask.ip6;

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


#if defined(HAVE_STRUCT_CMSGHDR) && defined(CMSG_DATA)
/* provides info about the ancillary message */
int xiolog_ancillary_ip6(struct cmsghdr *cmsg, int *num,
			 char *typbuff, int typlen,
			 char *nambuff, int namlen,
			 char *envbuff, int envlen,
			 char *valbuff, int vallen) {
   char scratch1[42];	/* can hold an IPv6 address in ASCII */
   char scratch2[32];
   size_t msglen;

   *num = 1;	/* good for most message types */
   msglen = cmsg->cmsg_len-((char *)CMSG_DATA(cmsg)-(char *)cmsg);
      envbuff[0] = '\0';
   switch (cmsg->cmsg_type) {
   case IPV6_PKTINFO: {
      struct in6_pktinfo *pktinfo = (struct in6_pktinfo *)CMSG_DATA(cmsg);
      *num = 2;
      strncpy(typbuff, "IPV6_PKTINFO", typlen);
      snprintf(nambuff, namlen, "%s%c%s", "dstaddr", '\0', "if");
      snprintf(envbuff, envlen, "%s%c%s", "IPV6_DSTADDR", '\0', "IPV6_IF");
      snprintf(valbuff, vallen, "%s%c%s",
	       inet6addr_info(&pktinfo->ipi6_addr, scratch1, sizeof(scratch1)),
	       '\0', xiogetifname(pktinfo->ipi6_ifindex, scratch2, -1));
   }
      return STAT_OK;
   case IPV6_HOPLIMIT:
      strncpy(typbuff, "IPV6_HOPLIMIT", typlen);
      strncpy(nambuff, "hoplimit", namlen);
      snprintf(valbuff, vallen, "%d", *(int *)CMSG_DATA(cmsg));
      return STAT_OK;
   case IPV6_RTHDR:
      strncpy(typbuff, "IPV6_RTHDR", typlen);
      strncpy(nambuff, "rthdr", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
#ifdef IPV6_AUTHHDR
   case IPV6_AUTHHDR:
      strncpy(typbuff, "IPV6_AUTHHDR", typlen);
      strncpy(nambuff, "authhdr", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
#endif
   case IPV6_DSTOPTS:
      strncpy(typbuff, "IPV6_DSTOPTS", typlen);
      strncpy(nambuff, "dstopts", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
   case IPV6_HOPOPTS:
      strncpy(typbuff, "IPV6_HOPOPTS", typlen);
      strncpy(nambuff, "hopopts", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
#ifdef IPV6_FLOWINFO
   case IPV6_FLOWINFO:
      strncpy(typbuff, "IPV6_FLOWINFO", typlen);
      strncpy(nambuff, "flowinfo", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
#endif
#ifdef IPV6_TCLASS
   case IPV6_TCLASS:
      strncpy(typbuff, "IPV6_TCLASS", typlen);
      strncpy(nambuff, "tclass", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
#endif
   default:
      snprintf(typbuff, typlen, "IPV6.%u", cmsg->cmsg_type);
      strncpy(nambuff, "data", namlen);
      xiodump(CMSG_DATA(cmsg), msglen, valbuff, vallen, 0);
      return STAT_OK;
   }
   return STAT_OK;
}
#endif /* defined(HAVE_STRUCT_CMSGHDR) && defined(CMSG_DATA) */


/* convert the IP6 socket address to human readable form. buff should be at
   least 50 chars long. output includes the port number */
static char *inet6addr_info(const struct in6_addr *sa, char *buff, size_t blen) {
   if (snprintf(buff, blen, "[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]",
#if HAVE_IP6_SOCKADDR==0
		(sa->s6_addr[0]<<8)+sa->s6_addr[1],
		(sa->s6_addr[2]<<8)+sa->s6_addr[3],
		(sa->s6_addr[4]<<8)+sa->s6_addr[5],
		(sa->s6_addr[6]<<8)+sa->s6_addr[7],
		(sa->s6_addr[8]<<8)+sa->s6_addr[9],
		(sa->s6_addr[10]<<8)+sa->s6_addr[11],
		(sa->s6_addr[12]<<8)+sa->s6_addr[13],
		(sa->s6_addr[14]<<8)+sa->s6_addr[15]
#elif HAVE_IP6_SOCKADDR==1
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->u6_addr.u6_addr16)[7])
#elif HAVE_IP6_SOCKADDR==2
		ntohs(((unsigned short *)&sa->u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->u6_addr16)[7])
#elif HAVE_IP6_SOCKADDR==3
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->in6_u.u6_addr16)[7])
#elif HAVE_IP6_SOCKADDR==4
		(sa->_S6_un._S6_u8[0]<<8)|(sa->_S6_un._S6_u8[1]&0xff),
		(sa->_S6_un._S6_u8[2]<<8)|(sa->_S6_un._S6_u8[3]&0xff),
		(sa->_S6_un._S6_u8[4]<<8)|(sa->_S6_un._S6_u8[5]&0xff),
		(sa->_S6_un._S6_u8[6]<<8)|(sa->_S6_un._S6_u8[7]&0xff),
		(sa->_S6_un._S6_u8[8]<<8)|(sa->_S6_un._S6_u8[9]&0xff),
		(sa->_S6_un._S6_u8[10]<<8)|(sa->_S6_un._S6_u8[11]&0xff),
		(sa->_S6_un._S6_u8[12]<<8)|(sa->_S6_un._S6_u8[13]&0xff),
		(sa->_S6_un._S6_u8[14]<<8)|(sa->_S6_un._S6_u8[15]&0xff)
#elif HAVE_IP6_SOCKADDR==5
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->__u6_addr.__u6_addr16)[7])
#endif
		) < 0) {
      Warn("sockaddr_inet6_info(): buffer too short");
      buff[blen-1] = '\0';
   }
   return buff;
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
xiosetsockaddrenv_ip6(int idx, char *namebuff, size_t namelen,
		      char *valuebuff, size_t valuelen,
		      struct sockaddr_in6 *sa, int ipproto) {
   switch (idx) {
   case 0:
      strcpy(namebuff, "ADDR");
      snprintf(valuebuff, valuelen, "[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]",
	       (sa->sin6_addr.s6_addr[0]<<8)+
	       sa->sin6_addr.s6_addr[1],
	       (sa->sin6_addr.s6_addr[2]<<8)+
	       sa->sin6_addr.s6_addr[3],
	       (sa->sin6_addr.s6_addr[4]<<8)+
	       sa->sin6_addr.s6_addr[5],
	       (sa->sin6_addr.s6_addr[6]<<8)+
	       sa->sin6_addr.s6_addr[7],
	       (sa->sin6_addr.s6_addr[8]<<8)+
	       sa->sin6_addr.s6_addr[9],
	       (sa->sin6_addr.s6_addr[10]<<8)+
	       sa->sin6_addr.s6_addr[11],
	       (sa->sin6_addr.s6_addr[12]<<8)+
	       sa->sin6_addr.s6_addr[13],
	       (sa->sin6_addr.s6_addr[14]<<8)+
	       sa->sin6_addr.s6_addr[15]);
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
      snprintf(valuebuff, valuelen, "%u", ntohs(sa->sin6_port));
      return 0;
   }
   return -1;
}

#endif /* WITH_IP6 */
