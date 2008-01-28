/* source: xio-unix.c */
/* Copyright Gerhard Rieger 2001-2007 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for opening addresses of UNIX socket type */

#include "xiosysincludes.h"
#include "xioopen.h"

#include "xio-socket.h"
#include "xio-listen.h"
#include "xio-unix.h"
#include "xio-named.h"


#if WITH_UNIX

static int xioopen_unix_connect(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *fd, unsigned groups, int dummy1, int dummy2, int dummy3);
static int xioopen_unix_listen(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *fd, unsigned groups, int dummy1, int dummy2, int dummy3);
static int xioopen_unix_sendto(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int dummy2, int dummy3);
static int xioopen_unix_recvfrom(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xfd, unsigned groups, int dummy1, int dummy2, int dummy3);
static
int xioopen_unix_recv(int argc, const char *argv[], struct opt *opts,
		      int xioflags, xiofile_t *xfd, unsigned groups,
		      int pf, int socktype, int ipproto);
static
int xioopen_unix_client(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xfd, unsigned groups, int dummy1, int dummy2, int dummy3);

#if WITH_ABSTRACT_UNIXSOCKET
static int xioopen_abstract_connect(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *fd, unsigned groups, int dummy1, int dummy2, int dummy3);
static int xioopen_abstract_listen(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *fd, unsigned groups, int dummy1, int dummy2, int dummy3);
static int xioopen_abstract_sendto(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int dummy2, int dummy3);
static int xioopen_abstract_recvfrom(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xfd, unsigned groups, int dummy1, int dummy2, int dummy3);
static
int xioopen_abstract_recv(int argc, const char *argv[], struct opt *opts,
		      int xioflags, xiofile_t *xfd, unsigned groups,
		      int pf, int socktype, int ipproto);
static
int xioopen_abstract_client(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xfd, unsigned groups, int dummy1, int dummy2, int dummy3);
#endif /* WITH_ABSTRACT_UNIXSOCKET */

const struct addrdesc addr_unix_connect = { "unix-connect",   3, xioopen_unix_connect, GROUP_FD|GROUP_NAMED|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY, 0, SOCK_STREAM, 0 HELP(":<filename>") };
#if WITH_LISTEN
const struct addrdesc addr_unix_listen  = { "unix-listen", 3, xioopen_unix_listen, GROUP_FD|GROUP_NAMED|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_LISTEN|GROUP_CHILD|GROUP_RETRY, 0, SOCK_STREAM, 0 HELP(":<filename>") };
#endif /* WITH_LISTEN */
const struct addrdesc addr_unix_sendto  = { "unix-sendto",  3, xioopen_unix_sendto, GROUP_FD|GROUP_NAMED|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY, 0, SOCK_DGRAM, 0 HELP(":<filename>") };
const struct addrdesc addr_unix_recvfrom= { "unix-recvfrom", 3, xioopen_unix_recvfrom, GROUP_FD|GROUP_NAMED|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY|GROUP_CHILD, PF_UNIX, SOCK_DGRAM, 0 HELP(":<filename>") };
const struct addrdesc addr_unix_recv    = { "unix-recv",     1, xioopen_unix_recv,     GROUP_FD|GROUP_NAMED|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY,             PF_UNIX, SOCK_DGRAM, 0 HELP(":<filename>") };
const struct addrdesc addr_unix_client  = { "unix-client",   3, xioopen_unix_client,   GROUP_FD|GROUP_NAMED|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY,             PF_UNIX, 0,          0 HELP(":<filename>") };
#if WITH_ABSTRACT_UNIXSOCKET
const struct addrdesc xioaddr_abstract_connect = { "abstract-connect",  3, xioopen_abstract_connect,  GROUP_FD|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY, 0, SOCK_STREAM, 0 HELP(":<filename>") };
#if WITH_LISTEN
const struct addrdesc xioaddr_abstract_listen  = { "abstract-listen",   3, xioopen_abstract_listen,   GROUP_FD|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_LISTEN|GROUP_CHILD|GROUP_RETRY, 0, SOCK_STREAM, 0 HELP(":<filename>") };
#endif /* WITH_LISTEN */
const struct addrdesc xioaddr_abstract_sendto  = { "abstract-sendto",   3, xioopen_abstract_sendto,   GROUP_FD|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY, 0, SOCK_DGRAM, 0 HELP(":<filename>") };
const struct addrdesc xioaddr_abstract_recvfrom= { "abstract-recvfrom", 3, xioopen_abstract_recvfrom, GROUP_FD|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY|GROUP_CHILD, PF_UNIX, SOCK_DGRAM, 0 HELP(":<filename>") };
const struct addrdesc xioaddr_abstract_recv    = { "abstract-recv",     1, xioopen_abstract_recv,     GROUP_FD|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY,             PF_UNIX, SOCK_DGRAM, 0 HELP(":<filename>") };
const struct addrdesc xioaddr_abstract_client  = { "abstract-client",   3, xioopen_abstract_client,   GROUP_FD|GROUP_SOCKET|GROUP_SOCK_UNIX|GROUP_RETRY,             PF_UNIX, 0,          0 HELP(":<filename>") };
#endif /* WITH_ABSTRACT_UNIXSOCKET */

const struct optdesc opt_unix_tightsocklen = { "unix-tightsocklen",    "tightsocklen",  OPT_UNIX_TIGHTSOCKLEN,  GROUP_SOCK_UNIX, PH_INIT, TYPE_BOOL, OFUNC_SPEC, 0, 0 };


socklen_t
xiosetunix(struct sockaddr_un *saun,
	   const char *path,
	   bool abstract,
	   bool tight) {
   size_t pathlen;
   socklen_t len;

   if (!abstract) {
      if ((pathlen = strlen(path)) > sizeof(saun->sun_path)) {
	 Warn2("unix socket address "F_Zu" characters long, truncating to "F_Zu"",
	       pathlen, sizeof(saun->sun_path));
      }
      strncpy(saun->sun_path, path, sizeof(saun->sun_path));
      if (tight) {
	 len = sizeof(struct sockaddr_un)-sizeof(saun->sun_path)+
	    MIN(pathlen, sizeof(saun->sun_path));
      } else {
	 len = sizeof(struct sockaddr_un);
      }
   } else {
      if ((pathlen = strlen(path)) >= sizeof(saun->sun_path)) {
	 Warn2("socket address "F_Zu" characters long, truncating to "F_Zu"",
	       pathlen+1, sizeof(saun->sun_path));
      }
      saun->sun_path[0] = '\0';	/* so it's abstract */
      strncpy(saun->sun_path+1, path, sizeof(saun->sun_path)-1);
      if (tight) {
	 len = sizeof(struct sockaddr_un)-sizeof(saun->sun_path)+
	    MIN(pathlen+1, sizeof(saun->sun_path));
      } else {
	 len = sizeof(struct sockaddr_un);
      }
   }
   return len;
}

#if WITH_LISTEN
static int xioopen_unix_listen(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   /* we expect the form: filename */
   const char *name;
   xiosingle_t *xfd = &xxfd->stream;
   struct sockaddr_un us;
   socklen_t uslen;
   bool tight = true;
   struct opt *opts0 = NULL;
   bool opt_unlink_early = false;
   bool opt_unlink_close = true;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   socket_un_init(&us);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   uslen = xiosetunix(&us, name, false, tight);

   retropt_bool(opts, OPT_UNLINK_EARLY, &opt_unlink_early);
   retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);

   if (opt_unlink_close) {
      if ((xfd->unlink_close = strdup(name)) == NULL) {
	 Error1("strdup(\"%s\"): out of memory", name);
      }
      xfd->opt_unlink_close = true;
   }

   xfd->howtoend = END_SHUTDOWN;

   applyopts(-1, opts, PH_INIT);
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;
   applyopts(-1, opts, PH_EARLY);

   if (opt_unlink_early) {
      if (Unlink(name) < 0) {
	 if (errno == ENOENT) {
	    Warn2("unlink(\"%s\"): %s", name, strerror(errno));
	 } else {
	    Error2("unlink(\"%s\"): %s", name, strerror(errno));
	 }
      }
   }

   /* trying to set user-early, perm-early etc. here is useless because
      file system entry is available only past bind() call. */
   applyopts_named(name, opts, PH_EARLY);	/* umask! */

   retropt_int(opts, OPT_SO_TYPE, &socktype);

   opts0 = copyopts(opts, GROUP_ALL);

   if ((result =
	xioopen_listen(xfd, xioflags,
		       (struct sockaddr *)&us, uslen,
		     opts, opts0, PF_UNIX, socktype, 0))
       != 0)
      return result;
   return 0;
}
#endif /* WITH_LISTEN */


static int xioopen_unix_connect(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   /* we expect the form: filename */
   const char *name;
   struct single *xfd = &xxfd->stream;
   struct sockaddr_un them, us;
   socklen_t themlen, uslen;
   bool tight = true;
   bool needbind = false;
   bool opt_unlink_close = false;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   socket_un_init(&us);
   socket_un_init(&them);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   themlen = xiosetunix(&them, name, false, tight);
   retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);

   if (retropt_bind(opts, AF_UNIX, socktype, 0, (struct sockaddr *)&us, &uslen, 0, 0, 0)
       != STAT_NOACTION) {
      needbind = true;
   }

   if (opt_unlink_close) {
      if ((xfd->unlink_close = strdup(name)) == NULL) {
	 Error1("strdup(\"%s\"): out of memory", name);
      }
      xfd->opt_unlink_close = true;
   }

   applyopts(-1, opts, PH_INIT);
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;
   applyopts(-1, opts, PH_EARLY);

   if ((result =
	xioopen_connect(xfd,
			needbind?(struct sockaddr *)&us:NULL, uslen,
			(struct sockaddr *)&them, themlen,
			opts, PF_UNIX, socktype, 0, false)) != 0) {
      return result;
   }
   if ((result = _xio_openlate(xfd, opts)) < 0) {
      return result;
   }
   return 0;
}


static int xioopen_unix_sendto(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   const char *name;
   xiosingle_t *xfd = &xxfd->stream;
   union sockaddr_union us;
   socklen_t uslen;
   bool tight = true;
   int pf = PF_UNIX;
   bool needbind = false;
   bool opt_unlink_close = false;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   uslen = socket_init(pf, &us);
   xfd->salen = socket_init(pf, &xfd->peersa);

   xfd->howtoend = END_SHUTDOWN;

   retropt_int(opts, OPT_SO_TYPE, &socktype);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   xfd->salen = xiosetunix(&xfd->peersa.un, name, false, tight);

   retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);

   xfd->dtype = XIODATA_RECVFROM;

   if (retropt_bind(opts, pf, socktype, 0, &us.soa, &uslen, 0, 0, 0)
       != STAT_NOACTION) {
      needbind = true;
   }

   if (opt_unlink_close) {
      if ((xfd->unlink_close = strdup(name)) == NULL) {
	 Error1("strdup(\"%s\"): out of memory", name);
      }
      xfd->opt_unlink_close = true;
   }

   applyopts(-1, opts, PH_INIT);
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;

   return
      _xioopen_dgram_sendto(needbind?&us:NULL, uslen,
			  opts, xioflags, xfd, groups, pf, socktype, 0);
}


static
int xioopen_unix_recvfrom(int argc, const char *argv[], struct opt *opts,
		     int xioflags, xiofile_t *xfd, unsigned groups,
		     int pf, int socktype, int dummy3) {
   const char *name;
   struct sockaddr_un us;
   socklen_t uslen;
   bool tight = true;
   bool needbind = true;
   bool opt_unlink_early = false;
   bool opt_unlink_close = true;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   socket_un_init(&us);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   uslen = xiosetunix(&us, name, false, tight);

   xfd->stream.howtoend = END_NONE;
   retropt_int(opts, OPT_SO_TYPE, &socktype);
   retropt_bind(opts, pf, socktype, 0, (struct sockaddr *)&us, &uslen, 1, 0, 0);
   retropt_bool(opts, OPT_UNLINK_EARLY, &opt_unlink_early);
   retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);

   if (opt_unlink_close) {
      if ((xfd->stream.unlink_close = strdup(name)) == NULL) {
	 Error1("strdup(\"%s\"): out of memory", name);
      }
      xfd->stream.opt_unlink_close = true;
   }

   if (opt_unlink_early) {
      if (Unlink(name) < 0) {
	 if (errno == ENOENT) {
	    Warn2("unlink(\"%s\"): %s", name, strerror(errno));
	 } else {
	    Error2("unlink(\"%s\"): %s", name, strerror(errno));
	 }
      }
   }

   xfd->stream.para.socket.la.soa.sa_family = pf;

   xfd->stream.dtype = XIODATA_RECVFROM_ONE;
   return _xioopen_dgram_recvfrom(&xfd->stream, xioflags,
				needbind?(struct sockaddr *)&us:NULL, uslen,
				opts, pf, socktype, 0, E_ERROR);
}


static
int xioopen_unix_recv(int argc, const char *argv[], struct opt *opts,
		      int xioflags, xiofile_t *xfd, unsigned groups,
		      int pf, int socktype, int ipproto) {
   const char *name;
   union sockaddr_union us;
   socklen_t uslen;
   bool tight = true;
   bool opt_unlink_early = false;
   bool opt_unlink_close = true;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   retropt_int(opts, OPT_SO_TYPE, &socktype);

   socket_un_init(&us.un);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   uslen = xiosetunix(&us.un, name, false, tight);

#if 1	/*!!! why bind option? */
   retropt_bind(opts, pf, socktype, ipproto, &us.soa, &uslen, 1, 0, 0);
#endif

   retropt_bool(opts, OPT_UNLINK_EARLY, &opt_unlink_early);
   if (opt_unlink_early) {
      if (Unlink(name) < 0) {
	 if (errno == ENOENT) {
	    Warn2("unlink(\"%s\"): %s", name, strerror(errno));
	 } else {
	    Error2("unlink(\"%s\"): %s", name, strerror(errno));
	 }
      }
   }

   retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);

   if (opt_unlink_close) {
      if ((xfd->stream.unlink_close = strdup(name)) == NULL) {
	 Error1("strdup(\"%s\"): out of memory", name);
      }
      xfd->stream.opt_unlink_close = true;
   }

   xfd->stream.para.socket.la.soa.sa_family = pf;

   xfd->stream.dtype = XIODATA_RECV;
   result = _xioopen_dgram_recv(&xfd->stream, xioflags, &us.soa, uslen,
				opts, pf, socktype, ipproto, E_ERROR);
   return result;
}


static int xioopen_unix_client(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   const char *name;
   xiosingle_t *xfd = &xxfd->stream;
   bool tight = true;
   int pf = PF_UNIX;
   union sockaddr_union them, us;
   socklen_t themlen;
   socklen_t uslen;
   bool needbind = false;
   bool opt_unlink_close = false;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)", argv[0], argc-1);
   }

   xfd->howtoend = END_SHUTDOWN;
   retropt_int(opts, OPT_SO_TYPE, &socktype);

   uslen = socket_init(pf, &us);
   themlen = socket_init(pf, &them);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   themlen = xiosetunix(&them.un, name, false, tight);

   retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);

   if (retropt_bind(opts, pf, socktype, 0, &us.soa, &uslen, 0, 0, 0)
       != STAT_NOACTION) {
      needbind = true;
   }

   if (opt_unlink_close) {
      if ((xfd->unlink_close = strdup(name)) == NULL) {
	 Error1("strdup(\"%s\"): out of memory", name);
      }
      xfd->opt_unlink_close = true;
   }

   /* xfd->dtype = DATA_STREAM; // is default */
   if ((result =
	xioopen_connect(xfd,
		      needbind?(struct sockaddr *)&us:NULL, uslen,
			(struct sockaddr *)&them, themlen,
		      opts, PF_UNIX, socktype?socktype:SOCK_STREAM, 0, false)) != 0) {
      if (errno == EPROTOTYPE) {
	 if (needbind) {
	    Unlink(us.un.sun_path);
	 }

	 applyopts(-1, opts, PH_INIT);
	 if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;

	 xfd->peersa = them;
	 xfd->salen = sizeof(struct sockaddr_un);
	 if ((result =
	      _xioopen_dgram_sendto(needbind?&us:NULL, uslen,
				    opts, xioflags, xfd, groups, pf,
				    socktype?socktype:SOCK_DGRAM, 0))
	     != 0) {
	    return result;
	 }
	 xfd->dtype = XIODATA_RECVFROM;
      }
   }
   if ((result = _xio_openlate(xfd, opts)) < 0) {
      return result;
   }
   return 0;
}


#if WITH_ABSTRACT_UNIXSOCKET
#if WITH_LISTEN
static int xioopen_abstract_listen(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   /* we expect the form: filename */
   const char *name;
   xiosingle_t *xfd = &xxfd->stream;
   bool tight = true;
   struct sockaddr_un us;
   socklen_t uslen;
   struct opt *opts0 = NULL;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   socket_un_init(&us);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   uslen = xiosetunix(&us, name, true, tight);

   xfd->howtoend = END_SHUTDOWN;

   applyopts(-1, opts, PH_INIT);
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;
   applyopts(-1, opts, PH_EARLY);

   /* trying to set user-early, perm-early etc. here is useless because
      file system entry is available only past bind() call. */

   retropt_int(opts, OPT_SO_TYPE, &socktype);

   opts0 = copyopts(opts, GROUP_ALL);

   if ((result =
	xioopen_listen(xfd, xioflags,
		       (struct sockaddr *)&us, uslen,
		     opts, opts0, PF_UNIX, socktype, 0))
       != 0)
      return result;
   return 0;
}
#endif /* WITH_LISTEN */

static int xioopen_abstract_connect(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   /* we expect the form: filename */
   const char *name;
   struct single *xfd = &xxfd->stream;
   bool tight = true;
   struct sockaddr_un them, us;
   socklen_t themlen, uslen;
   bool needbind = false;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   socket_un_init(&us);
   socket_un_init(&them);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   themlen = xiosetunix(&them, name, true, tight);

   if (retropt_bind(opts, AF_UNIX, socktype, 0, (struct sockaddr *)&us, &uslen, 0, 0, 0)
       != STAT_NOACTION) {
      needbind = true;
   }

   applyopts(-1, opts, PH_INIT);
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;
   applyopts(-1, opts, PH_EARLY);

   if ((result =
	xioopen_connect(xfd,
			needbind?(struct sockaddr *)&us:NULL, uslen,
			(struct sockaddr *)&them, themlen,
			opts, PF_UNIX, socktype, 0, false)) != 0) {
      return result;
   }
   if ((result = _xio_openlate(xfd, opts)) < 0) {
      return result;
   }
   return 0;
}


static int xioopen_abstract_sendto(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   const char *name;
   xiosingle_t *xfd = &xxfd->stream;
   union sockaddr_union us;
   socklen_t uslen;
   bool tight = true;
   int pf = PF_UNIX;
   bool needbind = false;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   uslen = socket_init(pf, &us);
   xfd->salen = socket_init(pf, &xfd->peersa);

   xfd->howtoend = END_SHUTDOWN;

   retropt_int(opts, OPT_SO_TYPE, &socktype);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   xfd->salen = xiosetunix(&xfd->peersa.un, name, true, tight);

   xfd->dtype = XIODATA_RECVFROM;

   if (retropt_bind(opts, pf, socktype, 0, &us.soa, &uslen, 0, 0, 0)
       != STAT_NOACTION) {
      needbind = true;
   }

   applyopts(-1, opts, PH_INIT);
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;

   return
      _xioopen_dgram_sendto(needbind?&us:NULL, uslen,
			  opts, xioflags, xfd, groups, pf, socktype, 0);
}


static
int xioopen_abstract_recvfrom(int argc, const char *argv[], struct opt *opts,
		     int xioflags, xiofile_t *xfd, unsigned groups,
		     int pf, int socktype, int dummy3) {
   const char *name;
   struct sockaddr_un us;
   socklen_t uslen;
   bool tight = true;
   bool needbind = true;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   socket_un_init(&us);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   uslen = xiosetunix(&us, name, true, tight);

   xfd->stream.howtoend = END_NONE;
   retropt_int(opts, OPT_SO_TYPE, &socktype);
   retropt_bind(opts, pf, socktype, 0, (struct sockaddr *)&us, &uslen, 1, 0, 0);

   xfd->stream.para.socket.la.soa.sa_family = pf;

   xfd->stream.dtype = XIODATA_RECVFROM_ONE;
   return _xioopen_dgram_recvfrom(&xfd->stream, xioflags,
				needbind?(struct sockaddr *)&us:NULL, uslen,
				opts, pf, socktype, 0, E_ERROR);
}


static
int xioopen_abstract_recv(int argc, const char *argv[], struct opt *opts,
		      int xioflags, xiofile_t *xfd, unsigned groups,
		      int pf, int socktype, int ipproto) {
   const char *name;
   union sockaddr_union us;
   socklen_t uslen;
   bool tight = true;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)",
	     argv[0], argc-1);
      return STAT_NORETRY;
   }

   retropt_int(opts, OPT_SO_TYPE, &socktype);

   socket_un_init(&us.un);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   uslen = xiosetunix(&us.un, name, true, tight);

#if 1	/*!!! why bind option? */
   retropt_bind(opts, pf, socktype, ipproto, &us.soa, &uslen, 1, 0, 0);
#endif

   xfd->stream.para.socket.la.soa.sa_family = pf;

   xfd->stream.dtype = XIODATA_RECV;
   result = _xioopen_dgram_recv(&xfd->stream, xioflags, &us.soa, uslen,
				opts, pf, socktype, ipproto, E_ERROR);
   return result;
}


static int xioopen_abstract_client(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *xxfd, unsigned groups, int dummy1, int socktype, int dummy3) {
   const char *name;
   xiosingle_t *xfd = &xxfd->stream;
   bool tight = true;
   int pf = PF_UNIX;
   union sockaddr_union them, us;
   socklen_t themlen;
   socklen_t uslen;
   bool needbind = false;
   int result;

   if (argc != 2) {
      Error2("%s: wrong number of parameters (%d instead of 1)", argv[0], argc-1);
   }

   xfd->howtoend = END_SHUTDOWN;
   retropt_int(opts, OPT_SO_TYPE, &socktype);

   uslen = socket_init(pf, &us);
   themlen = socket_init(pf, &them);

   retropt_bool(opts, OPT_UNIX_TIGHTSOCKLEN, &tight);
   name = argv[1];
   themlen = xiosetunix(&them.un, name, true, tight);

   if (retropt_bind(opts, pf, socktype, 0, &us.soa, &uslen, 0, 0, 0)
       != STAT_NOACTION) {
      needbind = true;
   }

   /* xfd->dtype = DATA_STREAM; // is default */
   if ((result =
	xioopen_connect(xfd,
		      needbind?(struct sockaddr *)&us:NULL, uslen,
			(struct sockaddr *)&them, themlen,
		      opts, PF_UNIX, socktype?socktype:SOCK_STREAM, 0, false)) != 0) {
      if (errno == EPROTOTYPE) {
	 if (needbind) {
	    Unlink(us.un.sun_path);
	 }

	 /* ...res_opts[] */
	 applyopts(-1, opts, PH_INIT);
	 if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;

	 xfd->peersa = them;
	 xfd->salen = themlen;
	 if ((result =
	      _xioopen_dgram_sendto(needbind?&us:NULL, uslen,
				    opts, xioflags, xfd, groups, pf,
				    socktype?socktype:SOCK_DGRAM, 0))
	     != 0) {
	    return result;
	 }
	 xfd->dtype = XIODATA_RECVFROM;
      }
   }
   if ((result = _xio_openlate(xfd, opts)) < 0) {
      return result;
   }
   return 0;
}

#endif /* WITH_ABSTRACT_UNIXSOCKET */

#endif /* WITH_UNIX */
