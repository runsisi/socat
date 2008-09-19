/* source: sysutils.c */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* translate socket addresses into human readable form */

#include "config.h"
#include "xioconfig.h"

#include "sysincludes.h"

#include "compat.h"	/* socklen_t */
#include "mytypes.h"
#include "error.h"
#include "sycls.h"
#include "utils.h"
#include "sysutils.h"


#if WITH_UNIX
void socket_un_init(struct sockaddr_un *sa) {
#if HAVE_STRUCT_SOCKADDR_SALEN
   sa->sun_len         = sizeof(struct sockaddr_un);
#endif
   sa->sun_family      = AF_UNIX;
   memset(sa->sun_path, '\0', sizeof(sa->sun_path));
}
#endif /* WITH_UNIX */

#if WITH_IP4
void socket_in_init(struct sockaddr_in *sa) {
#if HAVE_STRUCT_SOCKADDR_SALEN
   sa->sin_len         = sizeof(struct sockaddr_in);
#endif
   sa->sin_family      = AF_INET;
   sa->sin_port        = 0;
   sa->sin_addr.s_addr = 0;
   sa->sin_zero[0]     = 0;
   sa->sin_zero[1]     = 0;
   sa->sin_zero[2]     = 0;
   sa->sin_zero[3]     = 0;
   sa->sin_zero[4]     = 0;
   sa->sin_zero[5]     = 0;
   sa->sin_zero[6]     = 0;
   sa->sin_zero[7]     = 0;
}
#endif /* WITH_IP4 */

#if WITH_IP6
void socket_in6_init(struct sockaddr_in6 *sa) {
#if HAVE_STRUCT_SOCKADDR_SALEN
   sa->sin6_len        = sizeof(struct sockaddr_in6);
#endif
   sa->sin6_family     = AF_INET6;
   sa->sin6_port       = 0;
   sa->sin6_flowinfo   = 0;
#if HAVE_IP6_SOCKADDR==0
   sa->sin6_addr.s6_addr[0] = 0;
   sa->sin6_addr.s6_addr[1] = 0;
   sa->sin6_addr.s6_addr[2] = 0;
   sa->sin6_addr.s6_addr[3] = 0;
   sa->sin6_addr.s6_addr[4] = 0;
   sa->sin6_addr.s6_addr[5] = 0;
   sa->sin6_addr.s6_addr[6] = 0;
   sa->sin6_addr.s6_addr[7] = 0;
   sa->sin6_addr.s6_addr[8] = 0;
   sa->sin6_addr.s6_addr[9] = 0;
   sa->sin6_addr.s6_addr[10] = 0;
   sa->sin6_addr.s6_addr[11] = 0;
   sa->sin6_addr.s6_addr[12] = 0;
   sa->sin6_addr.s6_addr[13] = 0;
   sa->sin6_addr.s6_addr[14] = 0;
   sa->sin6_addr.s6_addr[15] = 0;
#elif HAVE_IP6_SOCKADDR==1
   sa->sin6_addr.u6_addr.u6_addr32[0] = 0;
   sa->sin6_addr.u6_addr.u6_addr32[1] = 0;
   sa->sin6_addr.u6_addr.u6_addr32[2] = 0;
   sa->sin6_addr.u6_addr.u6_addr32[3] = 0;
#elif HAVE_IP6_SOCKADDR==2
   sa->sin6_addr.u6_addr32[0] = 0;
   sa->sin6_addr.u6_addr32[1] = 0;
   sa->sin6_addr.u6_addr32[2] = 0;
   sa->sin6_addr.u6_addr32[3] = 0;
#elif HAVE_IP6_SOCKADDR==3
   sa->sin6_addr.in6_u.u6_addr32[0] = 0;
   sa->sin6_addr.in6_u.u6_addr32[1] = 0;
   sa->sin6_addr.in6_u.u6_addr32[2] = 0;
   sa->sin6_addr.in6_u.u6_addr32[3] = 0;
#elif HAVE_IP6_SOCKADDR==4
   sa->sin6_addr._S6_un._S6_u32[0] = 0;
   sa->sin6_addr._S6_un._S6_u32[1] = 0;
   sa->sin6_addr._S6_un._S6_u32[2] = 0;
   sa->sin6_addr._S6_un._S6_u32[3] = 0;
#elif HAVE_IP6_SOCKADDR==5
   sa->sin6_addr.__u6_addr.__u6_addr32[0] = 0;
   sa->sin6_addr.__u6_addr.__u6_addr32[1] = 0;
   sa->sin6_addr.__u6_addr.__u6_addr32[2] = 0;
   sa->sin6_addr.__u6_addr.__u6_addr32[3] = 0;
#endif
}
#endif /* WITH_IP6 */


#if _WITH_SOCKET
/* initializes the socket address of the specified address family. Returns the
   length of the specific socket address, or 0 on error. */
socklen_t socket_init(int af, union sockaddr_union *sa) {
   switch (af) {
#if WITH_UNIX
   case AF_UNIX:   socket_un_init(&sa->un);   return sizeof(sa->un);
#endif
#if WITH_IP4
   case AF_INET:   socket_in_init(&sa->ip4);  return sizeof(sa->ip4);
#endif
#if WITH_IP6
   case AF_INET6:  socket_in6_init(&sa->ip6); return sizeof(sa->ip6);
#endif
   default: Error1("socket_init(): unknown address family %d", af);
      memset(sa, 0, sizeof(union sockaddr_union));
      sa->soa.sa_family = af;
      return 0;
   }
}
#endif /* _WITH_SOCKET */

#if WITH_UNIX
#define XIOUNIXSOCKOVERHEAD (sizeof(struct sockaddr_un)-sizeof(((struct sockaddr_un*)0)->sun_path))
#endif

#if _WITH_SOCKET
char *sockaddr_info(const struct sockaddr *sa, socklen_t salen, char *buff, size_t blen) {
   char ubuff[5*UNIX_PATH_MAX+3];
   char *lbuff = buff;
   char *cp = lbuff;
   int n;

   if ((n = snprintf(cp, blen, "AF=%d ", sa->sa_family)) < 0) {
      Warn1("sockaddr_info(): buffer too short ("F_Zu")", blen);
      *buff = '\0';
      return buff;
   }
   cp += n,  blen -= n;

   switch (sa->sa_family) {
#if WITH_UNIX
   case 0:
   case AF_UNIX:
#if WITH_ABSTRACT_UNIXSOCKET
      if (salen > XIOUNIXSOCKOVERHEAD &&
	  sa->sa_data[0] == '\0') {
	 char *nextc;
	 nextc =
	    sanitize_string((char *)&sa->sa_data, salen-XIOUNIXSOCKOVERHEAD,
			    ubuff, XIOSAN_DEFAULT_BACKSLASH_OCT_3);
	 *nextc = '\0';
	 snprintf(cp, blen, "\"%s\"", ubuff);
      } else
#endif /* WITH_ABSTRACT_UNIXSOCKET */
      {
	 char *nextc;
	 nextc =
	    sanitize_string((char *)&sa->sa_data,
			    MIN(UNIX_PATH_MAX, strlen((char *)&sa->sa_data)),
			    ubuff, XIOSAN_DEFAULT_BACKSLASH_OCT_3);
	 *nextc = '\0';
	 snprintf(cp, blen, "\"%s\"", ubuff);
      }
      break;
#endif
#if WITH_IP4
   case AF_INET: sockaddr_inet4_info((struct sockaddr_in *)sa, cp, blen);
      break;
#endif
#if WITH_IP6
   case AF_INET6: sockaddr_inet6_info((struct sockaddr_in6 *)sa, cp, blen);
      break;
#endif
   default:
      if ((snprintf(cp, blen,
		    "0x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
		    sa->sa_data[0], sa->sa_data[1], sa->sa_data[2],
		    sa->sa_data[3], sa->sa_data[4], sa->sa_data[5],
		    sa->sa_data[6], sa->sa_data[7], sa->sa_data[8],
		    sa->sa_data[9], sa->sa_data[10], sa->sa_data[11],
		    sa->sa_data[12], sa->sa_data[13])) < 0) {
	 Warn("sockaddr_info(): buffer too short");
	 *buff = '\0';
	 return buff;
      }
   }
   return lbuff;
}
#endif /* _WITH_SOCKET */


#if WITH_UNIX
char *sockaddr_unix_info(const struct sockaddr_un *sa, socklen_t salen, char *buff, size_t blen) {
   blen = Min(blen, sizeof(sa->sun_path));
   strncpy(buff, sa->sun_path, blen);
   if (strlen(buff) >= blen) {
      buff[blen-1] = '\0';
   }
   return buff;
}
#endif /* WITH_UNIX */

#if WITH_IP4
/* addr in host byte order! */
char *inet4addr_info(uint32_t addr, char *buff, size_t blen) {
   if (snprintf(buff, blen, "%u.%u.%u.%u",
		(unsigned int)(addr >> 24), (unsigned int)((addr >> 16) & 0xff),
		(unsigned int)((addr >> 8) & 0xff), (unsigned int)(addr & 0xff)) < 0) {
      Warn("inet4addr_info(): buffer too short");
      buff[blen-1] = '\0';
   }
   return buff;
}
#endif /* WITH_IP4 */

#if WITH_IP4
char *sockaddr_inet4_info(const struct sockaddr_in *sa, char *buff, size_t blen) {
   if (snprintf(buff, blen, "%u.%u.%u.%u:%hu",
		((unsigned char *)&sa->sin_addr.s_addr)[0],
		((unsigned char *)&sa->sin_addr.s_addr)[1],
		((unsigned char *)&sa->sin_addr.s_addr)[2],
		((unsigned char *)&sa->sin_addr.s_addr)[3],
		htons(sa->sin_port)) < 0) {
      Warn("sockaddr_inet4_info(): buffer too short");
      buff[blen-1] = '\0';
   }
   return buff;
}
#endif /* WITH_IP4 */

#if !HAVE_INET_NTOP
/* http://www.opengroup.org/onlinepubs/000095399/functions/inet_ntop.html */
const char *inet_ntop(int pf, const void *binaddr,
		      char *addrtext, socklen_t textlen) {
   size_t retlen;
   switch (pf) {
   case PF_INET:
      if ((retlen =
	   snprintf(addrtext, textlen, "%u.%u.%u.%u",
		    ((unsigned char *)binaddr)[0],
		    ((unsigned char *)binaddr)[1],
		    ((unsigned char *)binaddr)[2],
		    ((unsigned char *)binaddr)[3]))
	  < 0) {
	 return NULL;	/* errno is valid */
      }
      break;
   case PF_INET6:
      if ((retlen =
	   snprintf(addrtext, textlen, "%x:%x:%x:%x:%x:%x:%x:%x",
		    ntohs(((uint16_t *)binaddr)[0]),
		    ntohs(((uint16_t *)binaddr)[1]),
		    ntohs(((uint16_t *)binaddr)[2]),
		    ntohs(((uint16_t *)binaddr)[3]),
		    ntohs(((uint16_t *)binaddr)[4]),
		    ntohs(((uint16_t *)binaddr)[5]),
		    ntohs(((uint16_t *)binaddr)[6]),
		    ntohs(((uint16_t *)binaddr)[7])
		    ))
	  < 0) {
	 return NULL;	/* errno is valid */
      }
      break;
   default:
      errno = EAFNOSUPPORT;
      return NULL;
   }
   addrtext[retlen] = '\0';
   return addrtext;
}
#endif /* !HAVE_INET_NTOP */

#if WITH_IP6
/* convert the IP6 socket address to human readable form. buff should be at
   least 50 chars long */
char *sockaddr_inet6_info(const struct sockaddr_in6 *sa, char *buff, size_t blen) {
   if (snprintf(buff, blen, "[%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x]:%hu",
#if HAVE_IP6_SOCKADDR==0
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
		sa->sin6_addr.s6_addr[15],
#elif HAVE_IP6_SOCKADDR==1
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr.u6_addr16)[7]),
#elif HAVE_IP6_SOCKADDR==2
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->sin6_addr.u6_addr16)[7]),
#elif HAVE_IP6_SOCKADDR==3
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->sin6_addr.in6_u.u6_addr16)[7]),
#elif HAVE_IP6_SOCKADDR==4
		(sa->sin6_addr._S6_un._S6_u8[0]<<8)|(sa->sin6_addr._S6_un._S6_u8[1]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[2]<<8)|(sa->sin6_addr._S6_un._S6_u8[3]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[4]<<8)|(sa->sin6_addr._S6_un._S6_u8[5]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[6]<<8)|(sa->sin6_addr._S6_un._S6_u8[7]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[8]<<8)|(sa->sin6_addr._S6_un._S6_u8[9]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[10]<<8)|(sa->sin6_addr._S6_un._S6_u8[11]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[12]<<8)|(sa->sin6_addr._S6_un._S6_u8[13]&0xff),
		(sa->sin6_addr._S6_un._S6_u8[14]<<8)|(sa->sin6_addr._S6_un._S6_u8[15]&0xff),
#elif HAVE_IP6_SOCKADDR==5
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[0]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[1]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[2]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[3]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[4]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[5]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[6]),
		ntohs(((unsigned short *)&sa->sin6_addr.__u6_addr.__u6_addr16)[7]),
#endif
		ntohs(sa->sin6_port)) < 0) {
      Warn("sockaddr_inet6_info(): buffer too short");
      buff[blen-1] = '\0';
   }
   return buff;
}
#endif /* WITH_IP6 */

/* fill the list with the supplementary group ids of user.
   caller passes size of list in ngroups, function returns number of groups in
   ngroups.
   function returns 0 if 0 or more groups were found, or 1 if the list is too
   short. */
int getusergroups(const char *user, gid_t *list, size_t *ngroups) {
   struct group *grp;
   size_t i = 0;

   setgrent();
   while (grp = getgrent()) {
      char **gusr = grp->gr_mem;
      while (*gusr) {
	 if (!strcmp(*gusr, user)) {
	    if (i == *ngroups)
	       return 1;
	    list[i++] = grp->gr_gid;
	    break;
	 }
	 ++gusr;
      }
   }
   endgrent();
   *ngroups = i;
   return 0;
}

#if !HAVE_HSTRERROR
const char *hstrerror(int err) {
   static const char *h_messages[] = {
      "success",
      "authoritative answer not found",
      "non-authoritative, host not found, or serverfail",
      "Host name lookup failure",	/* "non recoverable error" */
      "valid name, no data record of requested type" };

   assert(HOST_NOT_FOUND==1);
   assert(TRY_AGAIN==2);
   assert(NO_RECOVERY==3);
   assert(NO_DATA==4);
   if ((err < 0) || err > sizeof(h_messages)/sizeof(const char *)) {
      return "";
   }
   return h_messages[err];
}
#endif /* !HAVE_HSTRERROR */


/* this function behaves like poll(). It tries to do so even when the poll()
   system call is not available. */
int xiopoll(struct pollfd fds[], nfds_t nfds, int timeout) {
#if HAVE_POLL
    return Poll(fds, nfds, timeout);
#else /* HAVE_POLL */
    /*!!! wrap around Select() */
#endif /* !HAVE_POLL */
}
   

#if WITH_TCP || WITH_UDP
/* returns port in network byte order */
int parseport(const char *portname, int ipproto) {
   struct servent *se;
   char *extra;
   int result;

   if (isdigit(portname[0]&0xff)) {
      result = htons(strtoul(portname, &extra, 0));
      if (*extra != '\0') {
	 Error3("parseport(\"%s\", %d): extra trailing data \"%s\"",
		portname, ipproto, extra);
      }
      return result;
   }

   if ((se = getservbyname(portname, ipproto==IPPROTO_TCP?"tcp":"udp")) == NULL) {
      Error2("cannot resolve service \"%s/%d\"", portname, ipproto);
      return 0;
   }

   return se->s_port;
}
#endif /* WITH_TCP || WITH_UDP */

#if WITH_IP4 || WITH_IP6
/* check the systems interfaces for ifname and return its index
   or -1 if no interface with this name was found */
int ifindexbyname(const char *ifname) {
   /* Linux: man 7 netdevice */
   /* FreeBSD: man 4 networking */
   /* Solaris: man 7 if_tcp */

#if defined(HAVE_STRUCT_IFREQ) && defined(SIOCGIFCONF) && defined(SIOCGIFINDEX)
   /* currently we support Linux, FreeBSD; not Solaris */

#define IFBUFSIZ 1024
   int s;
   struct ifreq ifr;

   if (ifname[0] == '\0') {
      return -1;
   }
   if ((s = Socket(PF_INET, SOCK_DGRAM, IPPROTO_IP)) < 0) {
      Error1("socket(PF_INET, SOCK_DGRAM, IPPROTO_IP): %s", strerror(errno));
      return -1;
   }

   strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
   if (Ioctl(s, SIOCGIFINDEX, &ifr) < 0) {
      Close(s);
      Info3("ioctl(%d, SIOCGIFINDEX, {%s}): %s",
	     s, ifr.ifr_name, strerror(errno));
      return -1;
   }
   Close(s);
#if HAVE_STRUCT_IFREQ_IFR_INDEX
   return ifr.ifr_index;
#elif HAVE_STRUCT_IFREQ_IFR_IFINDEX
   return ifr.ifr_ifindex;
#endif /* HAVE_STRUCT_IFREQ_IFR_IFINDEX */

#else /* !defined(HAVE_ STRUCT_IFREQ) && defined(SIOCGIFCONF) && defined(SIOCGIFINDEX) */
   return -1;
#endif /* !defined(HAVE_ STRUCT_IFREQ) && defined(SIOCGIFCONF) && defined(SIOCGIFINDEX) */
}


/* like ifindexbyname(), but allows an index number as input.
   writes the resulting index to *ifindex and returns 0,
   or returns -1 on error */
int ifindex(const char *ifname, unsigned int *ifindex) {
   char *endptr;
   long int val;

   if (ifname[0] == '\0') {
      return -1;
   }
   val = strtol(ifname, &endptr, 0);
   if (endptr[0] == '\0') {
      *ifindex = val;
      return 0;
   }

   if ((val = ifindexbyname(ifname)) < 0) {
      return -1;
   }
   *ifindex = val;
   return 0;
}
#endif /* WITH_IP4 || WITH_IP6 */
