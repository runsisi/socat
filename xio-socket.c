/* source: xio-socket.c */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for socket related functions */

#include "xiosysincludes.h"

#if _WITH_SOCKET

#include "xioopen.h"
#include "xio-socket.h"
#include "xio-named.h"
#if WITH_IP4
#include "xio-ip4.h"
#endif /* WITH_IP4 */
#if WITH_IP6
#include "xio-ip6.h"
#endif /* WITH_IP6 */
#include "xio-ip.h"
#include "xio-ipapp.h"	/*! not clean */
#include "xio-tcpwrap.h"

const struct optdesc opt_so_debug    = { "so-debug",    "debug", OPT_SO_DEBUG,    GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_DEBUG };
#ifdef SO_ACCEPTCONN /* AIX433 */
const struct optdesc opt_so_acceptconn={ "so-acceptconn","acceptconn",OPT_SO_ACCEPTCONN,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_ACCEPTCONN};
#endif /* SO_ACCEPTCONN */
const struct optdesc opt_so_broadcast= { "so-broadcast", "broadcast", OPT_SO_BROADCAST,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_BROADCAST};
const struct optdesc opt_so_reuseaddr= { "so-reuseaddr", "reuseaddr", OPT_SO_REUSEADDR,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_REUSEADDR};
const struct optdesc opt_so_keepalive= { "so-keepalive", "keepalive", OPT_SO_KEEPALIVE,GROUP_SOCKET, PH_FD, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_KEEPALIVE};
#if HAVE_STRUCT_LINGER
const struct optdesc opt_so_linger   = { "so-linger",    "linger",    OPT_SO_LINGER,   GROUP_SOCKET, PH_PASTSOCKET, TYPE_LINGER,OFUNC_SOCKOPT,SOL_SOCKET, SO_LINGER };
#else /* !HAVE_STRUCT_LINGER */
const struct optdesc opt_so_linger   = { "so-linger",    "linger",    OPT_SO_LINGER,   GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_LINGER };
#endif /* !HAVE_STRUCT_LINGER */
const struct optdesc opt_so_oobinline= { "so-oobinline", "oobinline", OPT_SO_OOBINLINE,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_OOBINLINE};
const struct optdesc opt_so_sndbuf   = { "so-sndbuf",    "sndbuf",    OPT_SO_SNDBUF,   GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_SNDBUF};
const struct optdesc opt_so_sndbuf_late={ "so-sndbuf-late","sndbuf-late",OPT_SO_SNDBUF_LATE,GROUP_SOCKET,PH_LATE,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_SNDBUF };
const struct optdesc opt_so_rcvbuf   = { "so-rcvbuf",    "rcvbuf",    OPT_SO_RCVBUF,   GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_RCVBUF};
const struct optdesc opt_so_rcvbuf_late={"so-rcvbuf-late","rcvbuf-late",OPT_SO_RCVBUF_LATE,GROUP_SOCKET,PH_LATE,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_RCVBUF };
const struct optdesc opt_so_error    = { "so-error",     "error",     OPT_SO_ERROR,    GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_ERROR};
const struct optdesc opt_so_type     = { "so-type",      "type",      OPT_SO_TYPE,     GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_TYPE };
const struct optdesc opt_so_dontroute= { "so-dontroute", "dontroute", OPT_SO_DONTROUTE,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_DONTROUTE };
#ifdef SO_RCVLOWAT
const struct optdesc opt_so_rcvlowat = { "so-rcvlowat",  "rcvlowat", OPT_SO_RCVLOWAT, GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_RCVLOWAT };
#endif
#ifdef SO_RCVTIMEO
const struct optdesc opt_so_rcvtimeo = { "so-rcvtimeo",  "rcvtimeo", OPT_SO_RCVTIMEO, GROUP_SOCKET, PH_PASTSOCKET, TYPE_TIMEVAL,OFUNC_SOCKOPT,SOL_SOCKET,SO_RCVTIMEO };
#endif
#ifdef SO_SNDLOWAT
const struct optdesc opt_so_sndlowat = { "so-sndlowat",  "sndlowat", OPT_SO_SNDLOWAT, GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_SNDLOWAT };
#endif
#ifdef SO_SNDTIMEO
const struct optdesc opt_so_sndtimeo = { "so-sndtimeo",  "sndtimeo", OPT_SO_SNDTIMEO, GROUP_SOCKET, PH_PASTSOCKET, TYPE_TIMEVAL,OFUNC_SOCKOPT,SOL_SOCKET,SO_SNDTIMEO };
#endif
/* end of setsockopt options of UNIX98 standard */

#ifdef SO_AUDIT	/* AIX 4.3.3 */
const struct optdesc opt_so_audit    = { "so-audit",     "audit",    OPT_SO_AUDIT,    GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_AUDIT };
#endif /* SO_AUDIT */
#ifdef SO_ATTACH_FILTER
const struct optdesc opt_so_attach_filter={"so-attach-filter","attachfilter",OPT_SO_ATTACH_FILTER,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_ATTACH_FILTER};
#endif
#ifdef SO_DETACH_FILTER
const struct optdesc opt_so_detach_filter={"so-detach-filter","detachfilter",OPT_SO_DETACH_FILTER,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_DETACH_FILTER};
#endif
#ifdef SO_BINDTODEVICE	/* Linux: man 7 socket */
const struct optdesc opt_so_bindtodevice={"so-bindtodevice","if",OPT_SO_BINDTODEVICE,GROUP_SOCKET,PH_PASTSOCKET,TYPE_NAME,OFUNC_SOCKOPT,SOL_SOCKET,SO_BINDTODEVICE};
#endif
#ifdef SO_BSDCOMPAT
const struct optdesc opt_so_bsdcompat= { "so-bsdcompat","bsdcompat",OPT_SO_BSDCOMPAT,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_BSDCOMPAT };
#endif
#ifdef SO_CKSUMRECV
const struct optdesc opt_so_cksumrecv= { "so-cksumrecv","cksumrecv",OPT_SO_CKSUMRECV,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_CKSUMRECV };
#endif /* SO_CKSUMRECV */
#ifdef SO_KERNACCEPT	/* AIX 4.3.3 */
const struct optdesc opt_so_kernaccept={ "so-kernaccept","kernaccept",OPT_SO_KERNACCEPT,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_KERNACCEPT};
#endif /* SO_KERNACCEPT */
#ifdef SO_NO_CHECK
const struct optdesc opt_so_no_check = { "so-no-check", "nocheck",OPT_SO_NO_CHECK, GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_NO_CHECK };
#endif
#ifdef SO_NOREUSEADDR	/* AIX 4.3.3 */
const struct optdesc opt_so_noreuseaddr={"so-noreuseaddr","noreuseaddr",OPT_SO_NOREUSEADDR,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET, SO_NOREUSEADDR};
#endif /* SO_NOREUSEADDR */
#ifdef SO_PASSCRED
const struct optdesc opt_so_passcred = { "so-passcred", "passcred", OPT_SO_PASSCRED, GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_PASSCRED};
#endif
#ifdef SO_PEERCRED
const struct optdesc opt_so_peercred = { "so-peercred", "peercred", OPT_SO_PEERCRED, GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT3,OFUNC_SOCKOPT, SOL_SOCKET, SO_PEERCRED};
#endif
#ifdef SO_PRIORITY
const struct optdesc opt_so_priority = { "so-priority", "priority", OPT_SO_PRIORITY, GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_PRIORITY};
#endif
#ifdef SO_REUSEPORT	/* AIX 4.3.3, BSD, HP-UX */
const struct optdesc opt_so_reuseport= { "so-reuseport","reuseport",OPT_SO_REUSEPORT,GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT, OFUNC_SOCKOPT, SOL_SOCKET, SO_REUSEPORT };
#endif /* defined(SO_REUSEPORT) */
#ifdef SO_SECURITY_AUTHENTICATION
const struct optdesc opt_so_security_authentication={"so-security-authentication","securityauthentication",OPT_SO_SECURITY_AUTHENTICATION,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_SECURITY_AUTHENTICATION};
#endif
#ifdef SO_SECURITY_ENCRYPTION_NETWORK
const struct optdesc opt_so_security_encryption_network={"so-security-encryption-network","securityencryptionnetwork",OPT_SO_SECURITY_ENCRYPTION_NETWORK,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_SECURITY_ENCRYPTION_NETWORK};
#endif
#ifdef SO_SECURITY_ENCRYPTION_TRANSPORT
const struct optdesc opt_so_security_encryption_transport={"so-security-encryption-transport","securityencryptiontransport",OPT_SO_SECURITY_ENCRYPTION_TRANSPORT,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_SECURITY_ENCRYPTION_TRANSPORT};
#endif
#ifdef SO_USE_IFBUFS
const struct optdesc opt_so_use_ifbufs={ "so-use-ifbufs","useifbufs",OPT_SO_USE_IFBUFS,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,  OFUNC_SOCKOPT, SOL_SOCKET, SO_USE_IFBUFS};
#endif /* SO_USE_IFBUFS */
#ifdef SO_USELOOPBACK /* AIX433, Solaris, HP-UX */
const struct optdesc opt_so_useloopback={"so-useloopback","useloopback",OPT_SO_USELOOPBACK,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT, SOL_SOCKET, SO_USELOOPBACK};
#endif /* SO_USELOOPBACK */
#ifdef SO_DGRAM_ERRIND	/* Solaris */
const struct optdesc opt_so_dgram_errind={"so-dgram-errind","dgramerrind",OPT_SO_DGRAM_ERRIND,GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_DGRAM_ERRIND};
#endif /* SO_DGRAM_ERRIND */
#ifdef SO_DONTLINGER	/* Solaris */
const struct optdesc opt_so_dontlinger = {"so-dontlinger", "dontlinger",  OPT_SO_DONTLINGER,  GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_DONTLINGER };
#endif
#ifdef SO_PROTOTYPE	/* Solaris, HP-UX */
const struct optdesc opt_so_prototype  = {"so-prototype",  "prototype",   OPT_SO_PROTOTYPE,   GROUP_SOCKET,PH_PASTSOCKET,TYPE_INT,OFUNC_SOCKOPT,SOL_SOCKET,SO_PROTOTYPE };
#endif
#ifdef FIOSETOWN
const struct optdesc opt_fiosetown   = { "fiosetown", NULL, OPT_FIOSETOWN,   GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_IOCTL,  FIOSETOWN };
#endif
#ifdef SIOCSPGRP
const struct optdesc opt_siocspgrp   = { "siocspgrp", NULL, OPT_SIOCSPGRP,   GROUP_SOCKET, PH_PASTSOCKET, TYPE_INT,  OFUNC_IOCTL,  SIOCSPGRP };
#endif
const struct optdesc opt_bind        = { "bind",      NULL, OPT_BIND,        GROUP_SOCKET, PH_BIND, TYPE_STRING,OFUNC_SPEC };
const struct optdesc opt_connect_timeout = { "connect-timeout", NULL, OPT_CONNECT_TIMEOUT, GROUP_SOCKET, PH_PASTSOCKET, TYPE_TIMEVAL, OFUNC_OFFSET, (int)&((xiofile_t *)0)->stream.para.socket.connect_timeout };
const struct optdesc opt_protocol_family = { "protocol-family", "pf", OPT_PROTOCOL_FAMILY, GROUP_SOCKET, PH_PRESOCKET,  TYPE_STRING,  OFUNC_SPEC };

/* a subroutine that is common to all socket addresses that want to connect
   to a peer address.
   might fork.
   returns 0 on success.
*/
int _xioopen_connect(struct single *xfd, struct sockaddr *us, size_t uslen,
		     struct sockaddr *them, size_t themlen,
		     struct opt *opts, int pf, int stype, int proto,
		     bool alt, int level) {
   int fcntl_flags = 0;
   char infobuff[256];
   union sockaddr_union la;
   socklen_t lalen = themlen;
   int _errno;
   int result;

   if ((xfd->fd = Socket(pf, stype, proto)) < 0) {
      Msg4(level,
	   "socket(%d, %d, %d): %s", pf, stype, proto, strerror(errno));
      return STAT_RETRYLATER;	    
   }

   applyopts_offset(xfd, opts);
   applyopts(xfd->fd, opts, PH_PASTSOCKET);
   applyopts(xfd->fd, opts, PH_FD);

   applyopts_cloexec(xfd->fd, opts);

   applyopts(xfd->fd, opts, PH_PREBIND);
   applyopts(xfd->fd, opts, PH_BIND);
#if WITH_TCP || WITH_UDP
   if (alt) {
      union sockaddr_union sin, *sinp;
      unsigned short *port, i, N;
      div_t dv;
      bool problem;

      /* prepare sockaddr for bind probing */
      if (us) {
	 sinp = (union sockaddr_union *)us;
      } else {
	 if (them->sa_family == AF_INET) {
	    socket_in_init(&sin.ip4);
#if WITH_IP6
	 } else {
	    socket_in6_init(&sin.ip6);
#endif
	 }
	 sinp = &sin;
      }
      if (them->sa_family == AF_INET) {
	 port = &sin.ip4.sin_port;
#if WITH_IP6
      } else if (them->sa_family == AF_INET6) {
	 port = &sin.ip6.sin6_port;
#endif
      } else {
	 port = 0;	/* just to make compiler happy */
      }
      /* combine random+step variant to quickly find a free port when only
	 few are in use, and certainly find a free port in defined time even
	 if there are almost all in use */
      /* dirt 1: having tcp/udp code in socket function */
      /* dirt 2: using a time related system call for init of random */
      {
	 /* generate a random port, with millisecond random init */
#if 0
	 struct timeb tb;
	 ftime(&tb);
	 srandom(tb.time*1000+tb.millitm);
#else
	 struct timeval tv;
	 struct timezone tz;
	 tz.tz_minuteswest = 0;
	 tz.tz_dsttime = 0;
	 if ((result = Gettimeofday(&tv, &tz)) < 0) {
	    Warn2("gettimeofday(%p, {0,0}): %s", &tv, strerror(errno));
	 }
	 srandom(tv.tv_sec*1000000+tv.tv_usec);
#endif
      }
      dv = div(random(), IPPORT_RESERVED-XIO_IPPORT_LOWER);
      i = N = XIO_IPPORT_LOWER + dv.rem;
      problem = false;
      do {	/* loop over lowport bind() attempts */
	 *port = htons(i);
	 if (Bind(xfd->fd, (struct sockaddr *)sinp, sizeof(*sinp)) < 0) {
	    Msg4(errno==EADDRINUSE?E_INFO:level,
		 "bind(%d, {%s}, "F_Zd"): %s", xfd->fd,
		 sockaddr_info(&sinp->soa, sizeof(*sinp), infobuff, sizeof(infobuff)),
		 sizeof(*sinp), strerror(errno));
	    if (errno != EADDRINUSE) {
	       Close(xfd->fd);
	       return STAT_RETRYLATER;
	    }
	 } else {
	    break;	/* could bind to port, good, continue past loop */
	 }
	 --i;  if (i < XIO_IPPORT_LOWER)  i = IPPORT_RESERVED-1;
	 if (i == N) {
	    Msg(level, "no low port available");
	    /*errno = EADDRINUSE; still assigned */
	    Close(xfd->fd);
	    return STAT_RETRYLATER;
	 }
      } while (i != N);
   } else
#endif /* WITH_TCP || WITH_UDP */

   if (us) {
      if (Bind(xfd->fd, us, uslen) < 0) {
	 Msg4(level, "bind(%d, {%s}, "F_Zd"): %s",
	      xfd->fd, sockaddr_info(us, uslen, infobuff, sizeof(infobuff)),
	      uslen, strerror(errno));
	 Close(xfd->fd);
	 return STAT_RETRYLATER;
      }
   }

   applyopts(xfd->fd, opts, PH_PASTBIND);

   applyopts(xfd->fd, opts, PH_CONNECT);

   if (xfd->para.socket.connect_timeout.tv_sec  != 0 ||
       xfd->para.socket.connect_timeout.tv_usec != 0) {
      fcntl_flags = Fcntl(xfd->fd, F_GETFL);
      Fcntl_l(xfd->fd, F_SETFL, fcntl_flags|O_NONBLOCK);
   }

   result = Connect(xfd->fd, (struct sockaddr *)them, themlen);
   _errno = errno;
   la.soa.sa_family = them->sa_family;  lalen = sizeof(la);
   if (Getsockname(xfd->fd, &la.soa, &lalen) < 0) {
      Msg4(level-1, "getsockname(%d, %p, {%d}): %s",
	    xfd->fd, &la.soa, lalen, strerror(errno));
   }
   errno = _errno;
   if (result < 0) {
      if (errno == EINPROGRESS) {
	 if (xfd->para.socket.connect_timeout.tv_sec  != 0 ||
	     xfd->para.socket.connect_timeout.tv_usec != 0) {
	    struct timeval timeout;
	    fd_set readfds, writefds, exceptfds;
	    int result;
	    Info4("connect(%d, %s, "F_Zd"): %s",
		  xfd->fd, sockaddr_info(them, themlen, infobuff, sizeof(infobuff)),
		  themlen, strerror(errno));
	    timeout = xfd->para.socket.connect_timeout;
	    FD_ZERO(&readfds);  FD_ZERO(&writefds);  FD_ZERO(&exceptfds);
	    FD_SET(xfd->fd, &readfds);  FD_SET(xfd->fd, &writefds);
	    result =
	       Select(xfd->fd+1, &readfds, &writefds, &exceptfds, &timeout);
	    if (result < 0) {
	       Msg2(level, "select(%d,,,,): %s", xfd->fd+1, strerror(errno));
	       return STAT_RETRYLATER;
	    }
	    if (result == 0) {
	       Msg2(level, "connecting to %s: %s",
		    sockaddr_info(them, themlen, infobuff, sizeof(infobuff)),
		    strerror(ETIMEDOUT));
	       return STAT_RETRYLATER;
	    }
	    if (FD_ISSET(xfd->fd, &readfds)) {
#if 0
	       unsigned char dummy[1];
	       Read(xfd->fd, &dummy, 1);	/* get error message */
	       Msg2(level, "connecting to %s: %s",
		    sockaddr_info(them, infobuff, sizeof(infobuff)),
		    strerror(errno));
#else
	       Connect(xfd->fd, them, themlen);	/* get error message */
	       Msg4(level, "connect(%d, %s, "F_Zd"): %s",
		     xfd->fd, sockaddr_info(them, themlen, infobuff, sizeof(infobuff)),
		     themlen, strerror(errno));
#endif
	       return STAT_RETRYLATER;
	    }
	    /* otherwise OK */
	    Fcntl_l(xfd->fd, F_SETFL, fcntl_flags);
	 } else {
	    Warn4("connect(%d, %s, "F_Zd"): %s",
		  xfd->fd, sockaddr_info(them, themlen, infobuff, sizeof(infobuff)),
		  themlen, strerror(errno));
	 }
      } else if (pf == PF_UNIX && errno == EPROTOTYPE) {
	 /* this is for UNIX domain sockets: a connect attempt seems to be
	    the only way to distinguish stream and datagram sockets */
	 int _errno = errno;
	 Info4("connect(%d, %s, "F_Zd"): %s",
	       xfd->fd, sockaddr_info(them, themlen, infobuff, sizeof(infobuff)),
	       themlen, strerror(errno));
#if 0
	 Info("assuming datagram socket");
	 xfd->dtype = DATA_RECVFROM;
	 xfd->salen = themlen;
	 memcpy(&xfd->peersa.soa, them, xfd->salen);
#endif
	 /*!!! and remove bind socket */
	 Close(xfd->fd);  xfd->fd = -1;
	 errno = _errno;
	 return -1;
      } else {
	 Msg4(level, "connect(%d, %s, "F_Zd"): %s",
	      xfd->fd, sockaddr_info(them, themlen, infobuff, sizeof(infobuff)),
	      themlen, strerror(errno));
	 Close(xfd->fd);
	 return STAT_RETRYLATER;
      }
   }

   applyopts_fchown(xfd->fd, opts);
   applyopts(xfd->fd, opts, PH_CONNECTED);
   applyopts(xfd->fd, opts, PH_LATE);

   Notice1("successfully connected from local address %s",
	   sockaddr_info(&la.soa, themlen, infobuff, sizeof(infobuff)));

   return STAT_OK;
}


/* a subroutine that is common to all socket addresses that want to connect
   to a peer address.
   might fork.
   returns 0 on success.
*/
int xioopen_connect(struct single *xfd, struct sockaddr *us, size_t uslen,
		    struct sockaddr *them, size_t themlen,
		    struct opt *opts, int pf, int stype, int proto,
		    bool alt) {
   bool dofork = false;
   struct opt *opts0;
   char infobuff[256];
   int level;
   int result;

   retropt_bool(opts, OPT_FORK, &dofork);
   retropt_int(opts, OPT_SO_TYPE, &stype);

   opts0 = copyopts(opts, GROUP_ALL);

   Notice1("opening connection to %s",
	   sockaddr_info(them, themlen, infobuff, sizeof(infobuff)));

   do {	/* loop over retries and forks */

#if WITH_RETRY
      if (xfd->forever || xfd->retry) {
	 level = E_INFO;
      } else
#endif /* WITH_RETRY */
	 level = E_ERROR;
      result =
	 _xioopen_connect(xfd, us, uslen, them, themlen, opts,
			  pf, stype, proto, alt, level);
      switch (result) {
      case STAT_OK: break;
#if WITH_RETRY
      case STAT_RETRYLATER:
	 if (xfd->forever || xfd->retry) {
	    --xfd->retry;
	    if (result == STAT_RETRYLATER) {
	       Nanosleep(&xfd->intervall, NULL);
	    }
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    continue;
	 }
	 return STAT_NORETRY;
#endif /* WITH_RETRY */
      default:
	 return result;
      }

      if (dofork) {
	 xiosetchilddied();	/* set SIGCHLD handler */
      }

#if WITH_RETRY
      if (dofork) {
	 pid_t pid;
	 while ((pid = Fork()) < 0) {
	    int level = E_ERROR;
	    if (xfd->forever || --xfd->retry) {
	       level = E_WARN;	/* most users won't expect a problem here,
				   so Notice is too weak */
	    }
	    Msg1(level, "fork(): %s", strerror(errno));
	    if (xfd->forever || xfd->retry) {
	       dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	       Nanosleep(&xfd->intervall, NULL); continue;
	    }
	    return STAT_RETRYLATER;
	 }
	 if (pid == 0) {	/* child process */
	    Info1("just born: TCP client process "F_pid, Getpid());

	    /* drop parents locks, reset FIPS... */
	    if (xio_forked_inchild() != 0) {
	       Exit(1);
	    }
	    break;
	 }
	 /* parent process */
	 Notice1("forked off child process "F_pid, pid);
	 Close(xfd->fd);
	 /* with and without retry */
	 Nanosleep(&xfd->intervall, NULL);
	 dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	 continue;	/* with next socket() bind() connect() */
      } else
#endif /* WITH_RETRY */
      {
	 break;
      }
#if 0
      if ((result = _xio_openlate(fd, opts)) < 0)
	 return result;
#endif
   } while (true);

   return 0;
}


/* common to xioopen_udp_sendto, ..unix_sendto, ..rawip */
int _xioopen_dgram_sendto(/* them is already in xfd->peersa */
			union sockaddr_union *us, socklen_t uslen,
			struct opt *opts,
			int xioflags, xiosingle_t *xfd, unsigned groups,
			int pf, int socktype, int ipproto) {
   int level = E_ERROR;
   union sockaddr_union la; socklen_t lalen = sizeof(la);
   char infobuff[256];

   if ((xfd->fd = Socket(pf, socktype, ipproto)) < 0) {
      Msg4(level,
	   "socket(%d, %d, %d): %s", pf, socktype, ipproto, strerror(errno));
      return STAT_RETRYLATER;	    
   }

   applyopts_offset(xfd, opts);
   applyopts_single(xfd, opts, PH_PASTSOCKET);
   applyopts(xfd->fd, opts, PH_PASTSOCKET);
   applyopts(xfd->fd, opts, PH_FD);

   applyopts_cloexec(xfd->fd, opts);

   applyopts(xfd->fd, opts, PH_PREBIND);
   applyopts(xfd->fd, opts, PH_BIND);

   if (us) {
      if (Bind(xfd->fd, (struct sockaddr *)us, uslen) < 0) {
	 Msg4(level, "bind(%d, {%s}, "F_Zd"): %s",
	      xfd->fd, sockaddr_info((struct sockaddr *)us, uslen, infobuff, sizeof(infobuff)),
	      uslen, strerror(errno));
	 Close(xfd->fd);
	 return STAT_RETRYLATER;
      }
   }

   applyopts(xfd->fd, opts, PH_PASTBIND);

   /*applyopts(xfd->fd, opts, PH_CONNECT);*/

   if (Getsockname(xfd->fd, &la.soa, &lalen) < 0) {
      Warn4("getsockname(%d, %p, {%d}): %s",
	    xfd->fd, &la.soa, lalen, strerror(errno));
   }

   applyopts_fchown(xfd->fd, opts);
   applyopts(xfd->fd, opts, PH_CONNECTED);
   applyopts(xfd->fd, opts, PH_LATE);

   /* xfd->dtype = DATA_RECVFROM; *//* no, the caller must set this (ev _SKIPIP) */
   Notice1("successfully prepared local socket %s",
	   sockaddr_info(&la.soa, lalen, infobuff, sizeof(infobuff)));

   return STAT_OK;
}


static pid_t xio_waitingfor;
static bool xio_hashappened;
void xiosigaction_hasread(int signum, siginfo_t *siginfo, void *ucontext) {
   Debug5("xiosigaction_hasread(%d, {%d,%d,%d,"F_pid"}, )",
	  signum, siginfo->si_signo, siginfo->si_errno, siginfo->si_code,
	  siginfo->si_pid);
   if (xio_waitingfor == siginfo->si_pid) {
      xio_hashappened = true;
   }
   Debug("xiosigaction_hasread() ->");
   return;
}


/* waits for incoming packet, checks its source address and port. Depending
   on fork option, it may fork a subprocess.
   Returns STAT_OK if a the packet was accepted; with fork option, this is already in
   a new subprocess!
   Other return values indicate a problem; this can happen in the master
   process or in a subprocess.
   This function does not retry. If you need retries, handle this is a
   loop in the calling function.
   after fork, we set the forever/retry of the child process to 0
 */
int _xioopen_dgram_recvfrom(struct single *xfd, int xioflags,
			  struct sockaddr *us, socklen_t uslen,
			  struct opt *opts,
			  int pf, int socktype, int proto, int level) {
   char *rangename;
   socklen_t salen;
   bool dofork = false;
   pid_t pid;	/* mostly int; only used with fork */
   char infobuff[256];
   char lisname[256];
   bool drop = false;	/* true if current packet must be dropped */
   int result;

   retropt_bool(opts, OPT_FORK, &dofork);

   if (dofork) {
      if (!(xioflags & XIO_MAYFORK)) {
	 Error("option fork not allowed here");
	 return STAT_NORETRY;
      }
      xfd->flags |= XIO_DOESFORK;
   }

   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return STAT_NORETRY;

   if ((xfd->fd = Socket(pf, socktype, proto)) < 0) {
      Msg4(level,
	   "socket(%d, %d, %d): %s", pf, socktype, proto, strerror(errno));
      return STAT_RETRYLATER;
   }

   applyopts_single(xfd, opts, PH_PASTSOCKET);
   applyopts(xfd->fd, opts, PH_PASTSOCKET);

   applyopts_cloexec(xfd->fd, opts);

   applyopts(xfd->fd, opts, PH_PREBIND);
   applyopts(xfd->fd, opts, PH_BIND);
   if ((us != NULL) && Bind(xfd->fd, (struct sockaddr *)us, uslen) < 0) {
      Msg4(level, "bind(%d, {%s}, "F_Zd"): %s", xfd->fd,
	   sockaddr_info(us, uslen, infobuff, sizeof(infobuff)), uslen,
	   strerror(errno));
      Close(xfd->fd);
      return STAT_RETRYLATER;
   }

#if WITH_UNIX
   if (pf == AF_UNIX && us != NULL) {
      applyopts_named(((struct sockaddr_un *)us)->sun_path, opts, PH_FD);
   }
#endif

   applyopts(xfd->fd, opts, PH_PASTBIND);
#if WITH_UNIX
   if (pf == AF_UNIX && us != NULL) {
      /*applyopts_early(((struct sockaddr_un *)us)->sun_path, opts);*/
      applyopts_named(((struct sockaddr_un *)us)->sun_path, opts, PH_EARLY);
      applyopts_named(((struct sockaddr_un *)us)->sun_path, opts, PH_PREOPEN);
   }
#endif /* WITH_UNIX */

#if WITH_IP4 /*|| WITH_IP6*/
   if (retropt_string(opts, OPT_RANGE, &rangename) >= 0) {
      if (parserange(rangename, pf, &xfd->para.socket.range)
	  < 0) {
	 free(rangename);
	 return STAT_NORETRY;
      }
      free(rangename);
      xfd->para.socket.dorange = true;
   }
#endif

#if (WITH_TCP || WITH_UDP) && WITH_LIBWRAP
   xio_retropt_tcpwrap(xfd, opts);
#endif /* && (WITH_TCP || WITH_UDP) && WITH_LIBWRAP */

   if (xioopts.logopt == 'm') {
      Info("starting recvfrom loop, switching to syslog");
      diag_set('y', xioopts.syslogfac);  xioopts.logopt = 'y';
   } else {
      Info("starting recvfrom loop");
   }

   if (dofork) {
#if HAVE_SIGACTION
   {
      struct sigaction act;
      memset(&act, 0, sizeof(struct sigaction));
      act.sa_flags   = SA_NOCLDSTOP|SA_RESTART
#ifdef SA_SIGINFO /* not on Linux 2.0(.33) */
	 |SA_SIGINFO
#endif
#ifdef SA_NOMASK
         |SA_NOMASK
#endif
         ;
#if 1 || HAVE_SIGACTION_SASIGACTION
      act.sa_sigaction = xiosigaction_hasread;
#else /* Linux 2.0(.33) does not have sigaction.sa_sigaction */
      act.sa_handler = xiosighandler_hasread;
#endif
      if (Sigaction(SIGUSR1, &act, NULL) < 0) {
         /*! Linux man does not explicitely say that errno is defined */
         Warn1("sigaction(SIGUSR1, {&xiosigaction_subaddr_ok}, NULL): %s", strerror(errno));
      }
      if (Sigaction(SIGCHLD, &act, NULL) < 0) {
         /*! Linux man does not explicitely say that errno is defined */
         Warn1("sigaction(SIGCHLD, {&xiosigaction_subaddr_ok}, NULL): %s", strerror(errno));
      }
   }
#else /* !HAVE_SIGACTION */
   /*!!!*/
      if (Signal(SIGUSR1, xiosigaction_hasread) == SIG_ERR) {
	 Warn1("signal(SIGUSR1, xiosigaction_hasread): %s", strerror(errno));
      }
      if (Signal(SIGCHLD, xiosigaction_hasread) == SIG_ERR) {
	 Warn1("signal(SIGCHLD, xiosigaction_hasread): %s", strerror(errno));
      }
#endif /* !HAVE_SIGACTION */
   }

   while (true) {	/* but we only loop if fork option is set */
      char peername[256];
      union sockaddr_union _peername;
      union sockaddr_union _sockname;
      union sockaddr_union *pa = &_peername;	/* peer address */
      union sockaddr_union *la = &_sockname;	/* local address */
      socklen_t palen = sizeof(_peername);	/* peer address size */

      socket_init(pf, pa);
      salen = sizeof(struct sockaddr);

      if (drop) {
	 char *dummy[2];

	 Recv(xfd->fd, dummy, sizeof(dummy), 0);
	 drop = true;
      }

      /* loop until select() returns valid */
      do {
	 fd_set in, out, expt;
	 /*? int level = E_ERROR;*/
	 if (us != NULL) {
	    Notice1("receiving on %s", sockaddr_info(us, uslen, lisname, sizeof(lisname)));
	 } else {
	    Notice1("receiving IP protocol %u", proto);
	 }
	 FD_ZERO(&in); FD_ZERO(&out); FD_ZERO(&expt);
	 FD_SET(xfd->fd, &in);
	 if (Select(xfd->fd+1, &in, &out, &expt, NULL) > 0) {
	    break;
	 }

	 if (errno == EINTR) {
	    continue;
	 }

	 Msg2(level, "select(, {%d}): %s", xfd->fd, strerror(errno));
	 Close(xfd->fd);
	 return STAT_RETRYLATER;
      } while (true);

      if (xiogetpacketsrc(xfd->fd, pa, &palen) < 0) {
	 return STAT_RETRYLATER;
      }

      Notice1("receiving packet from %s"/*"src"*/,
	      sockaddr_info((struct sockaddr *)pa, palen, peername, sizeof(peername))/*,
							     sockaddr_info(&la->soa, sockname, sizeof(sockname))*/);

      if (xiocheckpeer(xfd, pa, la) < 0) {
	 /* drop packet */
	 char buff[512];
	 Recv(xfd->fd, buff, sizeof(buff), 0);
	 continue;
      }
      Info1("permitting packet from %s",
	    sockaddr_info((struct sockaddr *)pa, palen,
			  infobuff, sizeof(infobuff)));

      applyopts(xfd->fd, opts, PH_FD);

      applyopts(xfd->fd, opts, PH_CONNECTED);

      xfd->peersa = *(union sockaddr_union *)pa;
      xfd->salen = palen;

      if (dofork) {
	 sigset_t mask_sigchldusr1;
	 const char *forkwaitstring;
	 int forkwaitsecs = 0;

	 /* we must prevent that the current packet triggers another fork;
	    therefore we wait for a signal from the recent child: USR1
	    indicates that is has consumed the last packet; CHLD means it has
	    terminated */
	 /* block SIGCHLD and SIGUSR1 until parent is ready to react */
	 sigemptyset(&mask_sigchldusr1);
	 sigaddset(&mask_sigchldusr1, SIGCHLD);
	 sigaddset(&mask_sigchldusr1, SIGUSR1);
	 Sigprocmask(SIG_BLOCK, &mask_sigchldusr1, NULL);

	 if ((pid = Fork()) < 0) {
	    Msg1(level, "fork(): %s", strerror(errno));
	    Close(xfd->fd);
	    Sigprocmask(SIG_UNBLOCK, &mask_sigchldusr1, NULL);
	    return STAT_RETRYLATER;
	 }
	 /* gdb recommends to have env controlled sleep after fork */
	 if (forkwaitstring = getenv("SOCAT_FORK_WAIT")) {
	    forkwaitsecs = atoi(forkwaitstring);
	    Sleep(forkwaitsecs);
	 }

	 if (pid == 0) {	/* child */
	    /* no reason to block SIGCHLD in child process */
	    Sigprocmask(SIG_UNBLOCK, &mask_sigchldusr1, NULL);
	    xfd->ppid = Getppid();	/* send parent a signal when packet has
					   been consumed */

#if WITH_RETRY
	    /* !? */
	    xfd->retry = 0;
	    xfd->forever = 0;
	    level = E_ERROR;
#endif /* WITH_RETRY */

	    /* drop parents locks, reset FIPS... */
	    if (xio_forked_inchild() != 0) {
	       Exit(1);
	    }

#if WITH_UNIX
	    /* with UNIX sockets: only listening parent is allowed to remove
	       the socket file */
	    xfd->opt_unlink_close = false;
#endif /* WITH_UNIX */

	    break;
	 }

	 /* server: continue loop with listen */
	 Notice1("forked off child process "F_pid, pid);

	 xio_waitingfor = pid;
	 /* now we are ready to handle signals */
	 Sigprocmask(SIG_UNBLOCK, &mask_sigchldusr1, NULL);

	 while (!xio_hashappened) {
	    Sleep(UINT_MAX);	/* any signal lets us continue */
	 }
	 xio_waitingfor = 0;	/* so this child will not set hashappened again */
	 xio_hashappened = false;

	 Info("continue listening");
      } else {
	break;
      }
   }
   if ((result = _xio_openlate(xfd, opts)) != 0)
      return STAT_NORETRY;

   return STAT_OK;
}


/* returns STAT_* */
int _xioopen_dgram_recv(struct single *xfd, int xioflags,
			struct sockaddr *us, socklen_t uslen,
			struct opt *opts, int pf, int socktype, int proto,
			int level) {
   char *rangename;
   char infobuff[256];

   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return STAT_NORETRY;

   if ((xfd->fd = Socket(pf, socktype, proto)) < 0) {
      Msg4(level,
	   "socket(%d, %d, %d): %s", pf, socktype, proto, strerror(errno));
      return STAT_RETRYLATER;
   }

   applyopts_single(xfd, opts, PH_PASTSOCKET);
   applyopts(xfd->fd, opts, PH_PASTSOCKET);

   applyopts_cloexec(xfd->fd, opts);

   applyopts(xfd->fd, opts, PH_PREBIND);
   applyopts(xfd->fd, opts, PH_BIND);
   if ((us != NULL) && Bind(xfd->fd, (struct sockaddr *)us, uslen) < 0) {
      Msg4(level, "bind(%d, {%s}, "F_Zd"): %s", xfd->fd,
	   sockaddr_info(us, uslen, infobuff, sizeof(infobuff)), uslen,
	   strerror(errno));
      Close(xfd->fd);
      return STAT_RETRYLATER;
   }

#if WITH_UNIX
   if (pf == AF_UNIX && us != NULL) {
      applyopts_named(((struct sockaddr_un *)us)->sun_path, opts, PH_FD);
   }
#endif

   applyopts(xfd->fd, opts, PH_PASTBIND);
#if WITH_UNIX
   if (pf == AF_UNIX && us != NULL) {
      /*applyopts_early(((struct sockaddr_un *)us)->sun_path, opts);*/
      applyopts_named(((struct sockaddr_un *)us)->sun_path, opts, PH_EARLY);
      applyopts_named(((struct sockaddr_un *)us)->sun_path, opts, PH_PREOPEN);
   }
#endif /* WITH_UNIX */

#if WITH_IP4 /*|| WITH_IP6*/
   if (retropt_string(opts, OPT_RANGE, &rangename) >= 0) {
      if (parserange(rangename, pf, &xfd->para.socket.range)
	  < 0) {
	 free(rangename);
	 return STAT_NORETRY;
      }
      free(rangename);
      xfd->para.socket.dorange = true;
   }
#endif

#if (WITH_TCP || WITH_UDP) && WITH_LIBWRAP
   xio_retropt_tcpwrap(xfd, opts);
#endif /* && (WITH_TCP || WITH_UDP) && WITH_LIBWRAP */

   if (xioopts.logopt == 'm') {
      Info("starting recvfrom loop, switching to syslog");
      diag_set('y', xioopts.syslogfac);  xioopts.logopt = 'y';
   } else {
      Info("starting recvfrom loop");
   }

   return STAT_OK;
}


int retropt_socket_pf(struct opt *opts, int *pf) {
   char *pfname;

   if (retropt_string(opts, OPT_PROTOCOL_FAMILY, &pfname) >= 0) {
      if (false) {
	 ;
#if WITH_IP4
      } else if (!strcasecmp("inet", pfname) ||
	  !strcasecmp("inet4", pfname) ||
	  !strcasecmp("ip4", pfname) ||
	  !strcasecmp("ipv4", pfname) ||
	  !strcasecmp("2", pfname)) {
	 *pf = PF_INET;
#endif /* WITH_IP4 */
#if WITH_IP6
      } else if (!strcasecmp("inet6", pfname) ||
		 !strcasecmp("ip6", pfname) ||
		 !strcasecmp("ipv6", pfname) ||
		 !strcasecmp("10", pfname)) {
	 *pf = PF_INET6;
#endif /* WITH_IP6 */
      } else {
	 Error1("unknown protocol family \"%s\"", pfname);
	 /*! Warn("falling back to INET");*/
      }
      free(pfname);
      return 0;
   }
   return -1;
}



int xiogetpacketsrc(int fd, union sockaddr_union *pa, socklen_t *palen) {
   char infobuff[256];
   char peekbuff[1];

#if 0

   struct msghdr msgh = {0};
#if HAVE_STRUCT_IOVEC
   struct iovec iovec;
#endif
   char ctrlbuff[5120];

   msgh.msg_name = pa;
   msgh.msg_namelen = *palen;
#if HAVE_STRUCT_IOVEC
   iovec.iov_base = peekbuff;
   iovec.iov_len  = sizeof(peekbuff);
   msgh.msg_iov = &iovec;
   msgh.msg_iovlen = 1;
#endif
#if HAVE_STRUCT_MSGHDR_MSGCONTROL
   msgh.msg_control = ctrlbuff;
#endif
#if HAVE_STRUCT_MSGHDR_MSGCONTROLLEN
   msgh.msg_controllen = sizeof(ctrlbuff);
#endif
#if HAVE_STRUCT_MSGHDR_MSGFLAGS
   msgh.msg_flags = 0;
#endif
   if (Recvmsg(fd, &msgh, MSG_PEEK
#ifdef MSG_TRUNC
	       |MSG_TRUNC
#endif
	       ) < 0) {
      Notice1("packet from %s",
	      sockaddr_info(&pa->soa, infobuff, sizeof(infobuff)));
      Warn1("recvmsg(): %s", strerror(errno));
      return STAT_RETRYLATER;
   }
   *palen = msgh.msg_namelen;
   return STAT_OK;

#else 

   if (Recvfrom(fd, peekbuff, sizeof(peekbuff), MSG_PEEK
#ifdef MSG_TRUNC
		|MSG_TRUNC
#endif
		,
	       &pa->soa, palen) < 0) {
      Notice1("packet from %s",
	      sockaddr_info(&pa->soa, *palen, infobuff, sizeof(infobuff)));
      Warn1("recvfrom(): %s", strerror(errno));
      return STAT_RETRYLATER;
   }
   return STAT_OK;

#endif
}


int xiocheckrange(union sockaddr_union *sa, union xiorange_union *range) {
   switch (sa->soa.sa_family) {
#if WITH_IP4
   case PF_INET:
      return
	 xiocheckrange_ip4(&sa->ip4, &range->ip4);
#endif /* WITH_IP4 */
#if WITH_IP6
   case PF_INET6:
      return
	 xiocheckrange_ip6(&sa->ip6, &range->ip6);
#endif /* WITH_IP6 */
   }
   return -1;
}

int xiocheckpeer(xiosingle_t *xfd,
		 union sockaddr_union *pa, union sockaddr_union *la) {
   char infobuff[256];
   int result;

#if WITH_IP4
   if (xfd->para.socket.dorange) {
      if (xiocheckrange(pa, &xfd->para.socket.range) < 0) {
	 char infobuff[256];
	 Warn1("refusing connection from %s due to range option",
	       sockaddr_info((struct sockaddr *)pa, 0,
			     infobuff, sizeof(infobuff)));
	 return -1;
      }
      Info1("permitting connection from %s due to range option",
	    sockaddr_info((struct sockaddr *)pa, 0,
			  infobuff, sizeof(infobuff)));
   }
#endif /* WITH_IP4 */

#if WITH_TCP || WITH_UDP
   if (xfd->para.socket.ip.dosourceport) {
#if WITH_IP4
      if (pa->soa.sa_family == AF_INET &&
	  ntohs(((struct sockaddr_in *)pa)->sin_port) != xfd->para.socket.ip.sourceport) {
	 Warn1("refusing connection from %s due to wrong sourceport",
	       sockaddr_info((struct sockaddr *)pa, 0,
			     infobuff, sizeof(infobuff)));
	 return -1;
      }
#endif /* WITH_IP4 */
#if WITH_IP6
      if (pa->soa.sa_family == AF_INET6 &&
	  ntohs(((struct sockaddr_in6 *)pa)->sin6_port) != xfd->para.socket.ip.sourceport) {
	 Warn1("refusing connection from %s due to sourceport option",
	       sockaddr_info((struct sockaddr *)pa, 0,
			     infobuff, sizeof(infobuff)));
	 return -1;
      }
#endif /* WITH_IP6 */
      Info1("permitting connection from %s due to sourceport option",
	    sockaddr_info((struct sockaddr *)pa, 0,
			  infobuff, sizeof(infobuff)));
   } else if (xfd->para.socket.ip.lowport) {
      if (pa->soa.sa_family == AF_INET &&
	  ntohs(((struct sockaddr_in *)pa)->sin_port) >= IPPORT_RESERVED) {
	 Warn1("refusing connection from %s due to lowport option",
	       sockaddr_info((struct sockaddr *)pa, 0,
			     infobuff, sizeof(infobuff)));
	 return -1;
      }
#if WITH_IP6
      else if (pa->soa.sa_family == AF_INET6 &&
	       ntohs(((struct sockaddr_in6 *)pa)->sin6_port) >=
	       IPPORT_RESERVED) {
	 Warn1("refusing connection from %s due to lowport option",
	       sockaddr_info((struct sockaddr *)pa, 0,
			     infobuff, sizeof(infobuff)));
	 return -1;
      }
#endif /* WITH_IP6 */
      Info1("permitting connection from %s due to lowport option",
	    sockaddr_info((struct sockaddr *)pa, 0,
			  infobuff, sizeof(infobuff)));
   }
#endif /* WITH_TCP || WITH_UDP */

#if (WITH_TCP || WITH_UDP) && WITH_LIBWRAP
   result = xio_tcpwrap_check(xfd, la, pa);
   if (result < 0) {
      char infobuff[256];
      Warn1("refusing connection from %s due to tcpwrapper option",
	    sockaddr_info((struct sockaddr *)pa, 0,
			  infobuff, sizeof(infobuff)));
      return -1;
   } else if (result > 0) {
      Info1("permitting connection from %s due to tcpwrapper option",
	    sockaddr_info((struct sockaddr *)pa, 0,
			  infobuff, sizeof(infobuff)));
   }
#endif /* (WITH_TCP || WITH_UDP) && WITH_LIBWRAP */

   return 0;	/* permitted */
}

#endif /* _WITH_SOCKET */
