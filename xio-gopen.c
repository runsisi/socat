/* $Id: xio-gopen.c,v 1.32 2007/02/08 18:36:44 gerhard Exp $ */
/* Copyright Gerhard Rieger 2001-2007 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for opening addresses of generic open type */

#include "xiosysincludes.h"
#include "xioopen.h"

#include "xio-named.h"
#include "xio-unix.h"
#include "xio-gopen.h"


#if WITH_GOPEN

static int xioopen_gopen(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *fd, unsigned groups, int dummy1, int dummy2, int dummy3);


const struct addrdesc addr_gopen  = { "gopen",  3, xioopen_gopen, GROUP_FD|GROUP_FIFO|GROUP_CHR|GROUP_BLK|GROUP_REG|GROUP_NAMED|GROUP_OPEN|GROUP_FILE|GROUP_TERMIOS|GROUP_SOCKET|GROUP_SOCK_UNIX, 0, 0, 0 HELP(":<filename>") };

static int xioopen_gopen(int argc, const char *argv[], struct opt *opts, int xioflags, xiofile_t *fd, unsigned groups, int dummy1, int dummy2, int dummy3) {
   const char *filename = argv[1];
   flags_t openflags = (xioflags & XIO_ACCMODE);
   mode_t st_mode;
   bool exists;
   bool opt_unlink_close = false;
   int result;

   if ((result =
	  _xioopen_named_early(argc, argv, fd, GROUP_NAMED|groups, &exists, opts)) < 0) {
      return result;
   }
   st_mode = result;

   if (exists) {
      /* file (or at least named entry) exists */
      if ((xioflags&XIO_ACCMODE) != XIO_RDONLY) {
	 openflags |= O_APPEND;
      }
   } else {
      openflags |= O_CREAT;
   }

   /* note: when S_ISSOCK was undefined, it always gives 0 */
   if (exists && S_ISSOCK(st_mode)) {
#if WITH_UNIX
      int socktype = SOCK_STREAM;
      int optsotype = -1;
      struct sockaddr_un sa, us;
      socklen_t salen, uslen = sizeof(us);
      bool needbind = false;
      char infobuff[256];
      struct opt *opts2;

      socket_un_init(&sa);
      socket_un_init(&us);

      Info1("\"%s\" is a socket, connecting to it", filename);
      if (retropt_int(opts, OPT_SO_TYPE, &optsotype) == 0) {
	 socktype = optsotype;
      }

      if (retropt_bind(opts, AF_UNIX, socktype, 0, (struct sockaddr *)&us, &uslen, 0, 0, 0) != STAT_NOACTION) {
	 needbind = true;
      }

      retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);
      if (opt_unlink_close) {
	 if ((fd->stream.unlink_close = strdup(filename)) == NULL) {
	    Error1("strdup(\"%s\"): out of memory", filename);
	 }
	 fd->stream.opt_unlink_close = true;
      }

      /* save options, because we might have to start again with Socket() */
      opts2 = copyopts(opts, GROUP_ALL);

      if ((fd->stream.fd = Socket(PF_UNIX, socktype, 0)) < 0) {
	 Error2("socket(PF_UNIX, %d, 0): %s", socktype, strerror(errno));
	 return STAT_RETRYLATER;
      }
      /*0 Info2("socket(PF_UNIX, %d, 0) -> %d", socktype, fd->stream.fd);*/
      applyopts(fd->stream.fd, opts, PH_PASTSOCKET);
      applyopts(fd->stream.fd, opts, PH_FD);

      applyopts_cloexec(fd->stream.fd, opts);

      sa.sun_family = AF_UNIX;
      salen = xiosetunix(&sa, filename, false, false);

#if 0
      applyopts(fd->stream.fd, opts, PH_PREBIND);
      applyopts(fd->stream.fd, opts, PH_BIND);
      if (us) {
	 if (Bind(fd->stream.fd, us, uslen) < 0) {
	    Error4("bind(%d, {%s}, "F_Zd"): %s",
		   fd->fd, sockaddr_info(us, infobuff, sizeof(infobuff)),
		   uslen, strerror(errno));
	    if (fd->forever || --fd->retry) {
	       Nanosleep(&fd->intervall, NULL);
	       continue;
	    } else
	       return STAT_RETRYLATER;
	 }
      }
      applyopts(fd->stream.fd, opts, PH_PASTBIND);
#endif /* 0 */

      applyopts(fd->stream.fd, opts, PH_CONNECT);
      if ((result = Connect(fd->stream.fd, (struct sockaddr *)&sa, salen)) < 0) {
	 if (errno == EINPROGRESS) {
	    Warn4("connect(%d, %s, "F_Zd"): %s",
		  fd->stream.fd, sockaddr_unix_info(&sa, salen, infobuff, sizeof(infobuff)),
		  sizeof(sa), strerror(errno));
	 } else if (errno == EPROTOTYPE && optsotype != SOCK_STREAM) {
	    Warn4("connect(%d, %s, "F_Zd"): %s",
		  fd->stream.fd, sockaddr_unix_info(&sa, salen, infobuff, sizeof(infobuff)),
		  sizeof(sa), strerror(errno));
	    Info("assuming datagram socket");
	    Close(fd->stream.fd);

	    opts = opts2;
	    if ((fd->stream.fd = Socket(PF_UNIX, SOCK_DGRAM, 0)) < 0) {
	       Error1("socket(PF_UNIX, SOCK_DGRAM, 0): %s", strerror(errno));
	       return STAT_RETRYLATER;
	    }
	    /*0 Info1("socket(PF_UNIX, SOCK_DGRAM, 0) -> %d", fd->stream.fd);*/

	    applyopts(fd->stream.fd, opts, PH_PASTSOCKET);
	    applyopts(fd->stream.fd, opts, PH_FD);

	    applyopts_cloexec(fd->stream.fd, opts);

	    sa.sun_family = AF_UNIX;
	    strncpy(sa.sun_path, filename, sizeof(sa.sun_path));
	    
	    fd->stream.dtype = XIODATA_RECVFROM;
	    fd->stream.salen = sizeof(sa);
	    memcpy(&fd->stream.peersa.soa, &sa, fd->stream.salen);
	 } else {
	    Error4("connect(%d, %s, "F_Zd"): %s",
		   fd->stream.fd, sockaddr_unix_info(&sa, fd->stream.salen, infobuff, sizeof(infobuff)),
		   sizeof(sa), strerror(errno));
	    return STAT_RETRYLATER;
	 }
      }
      if (fd->stream.howtoend == END_UNSPEC) {
	 fd->stream.howtoend = END_SHUTDOWN;
      }

      applyopts_fchown(fd->stream.fd, opts);
      applyopts(fd->stream.fd, opts, PH_CONNECTED);
      applyopts(fd->stream.fd, opts, PH_LATE);
      applyopts_named(filename, opts, PH_PASTOPEN);	/* unlink-late */

      if (Getsockname(fd->stream.fd, (struct sockaddr *)&us, &uslen) < 0) {
	 Warn4("getsockname(%d, %p, {%d}): %s",
	       fd->stream.fd, &us, uslen, strerror(errno));
      } else {
	 Notice1("successfully connected via %s",
		 sockaddr_unix_info(&us, uslen, infobuff, sizeof(infobuff)));
      }
#else
      Error("\"%s\" is a socket, but UNIX socket support is not compiled in");
      return -1;
#endif /* WITH_UNIX */

   } else {
      /* a file name */

      Info1("\"%s\" is not a socket, open()'ing it", filename);

      retropt_bool(opts, OPT_UNLINK_CLOSE, &opt_unlink_close);
      if (opt_unlink_close) {
	 if ((fd->stream.unlink_close = strdup(filename)) == NULL) {
	    Error1("strdup(\"%s\"): out of memory", filename);
	 }
	 fd->stream.opt_unlink_close = true;
      }

      Notice3("opening %s \"%s\" for %s",
	      filetypenames[(st_mode&S_IFMT)>>12], filename, ddirection[(xioflags&XIO_ACCMODE)]);
      if ((result = _xioopen_open(filename, openflags, opts)) < 0)
	 return result;
#ifdef I_PUSH
      if (S_ISCHR(st_mode)) {
	 Ioctl(result, I_PUSH, "ptem");
	 Ioctl(result, I_PUSH, "ldterm");
	 Ioctl(result, I_PUSH, "ttcompat");
      }
#endif
      fd->stream.fd = result;

#if WITH_TERMIOS
      if (Isatty(fd->stream.fd)) {
	 if (Tcgetattr(fd->stream.fd, &fd->stream.savetty) < 0) {
	    Warn2("cannot query current terminal settings on fd %d: %s",
		  fd->stream.fd, strerror(errno));
	 } else {
	    fd->stream.ttyvalid = true;
	 }
      }
#endif /* WITH_TERMIOS */
      applyopts_named(filename, opts, PH_FD);
      applyopts(fd->stream.fd, opts, PH_FD);
      applyopts_cloexec(fd->stream.fd, opts);
   }

   if ((result = applyopts2(fd->stream.fd, opts, PH_PASTSOCKET, PH_CONNECTED)) < 0) 
      return result;

   if ((result = _xio_openlate(&fd->stream, opts)) < 0)
      return result;
   return 0;
}

#endif /* WITH_GOPEN */
