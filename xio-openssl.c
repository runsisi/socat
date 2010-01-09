/* source: xio-openssl.c */
/* Copyright Gerhard Rieger 2002-2009 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the implementation of the openssl addresses */

#include "xiosysincludes.h"
#if WITH_OPENSSL	/* make this address configure dependend */
#include "xioopen.h"

#include "xio-fd.h"
#include "xio-socket.h"	/* _xioopen_connect() */
#include "xio-listen.h"
#include "xio-ipapp.h"
#include "xio-openssl.h"

/* the openssl library requires a file descriptor for external communications.
   so our best effort is to provide any possible kind of un*x file descriptor 
   (not only tcp, but also pipes, stdin, files...)
   for tcp we want to provide support for socks and proxy.
   read and write functions must use the openssl crypt versions.
   but currently only plain tcp4 is implemented.
*/

/* Linux: "man 3 ssl" */

/* generate a simple openssl server for testing:
   1) generate a private key
   openssl genrsa -out server.key 1024
   2) generate a self signed cert
   openssl req -new -key server.key -x509 -days 3653 -out server.crt
      enter fields...
   3) generate the pem file
   cat server.key server.crt >server.pem
   openssl s_server  (listens on 4433/tcp)
 */

/* static declaration of ssl's open function */
static int xioopen_openssl_connect(int argc, const char *argv[], struct opt *opts,
				   int xioflags, xiofile_t *fd, unsigned groups,
			   int dummy1, int dummy2, int dummy3);

/* static declaration of ssl's open function */
static int xioopen_openssl_listen(int argc, const char *argv[], struct opt *opts,
				  int xioflags, xiofile_t *fd, unsigned groups,
			   int dummy1, int dummy2, int dummy3);
static int openssl_SSL_ERROR_SSL(int level, const char *funcname);
static int openssl_handle_peer_certificate(struct single *xfd, bool opt_ver,
					   int level);
static int xioSSL_set_fd(struct single *xfd, int level);
static int xioSSL_connect(struct single *xfd, bool opt_ver, int level);


/* description record for ssl connect */
const struct addrdesc addr_openssl = {
   "openssl",	/* keyword for selecting this address type in xioopen calls
		   (canonical or main name) */
   3,		/* data flow directions this address supports on API layer:
		   1..read, 2..write, 3..both */
   xioopen_openssl_connect,	/* a function pointer used to "open" these addresses.*/
   GROUP_FD|GROUP_SOCKET|GROUP_SOCK_IP4|GROUP_SOCK_IP6|GROUP_IP_TCP|GROUP_CHILD|GROUP_OPENSSL|GROUP_RETRY,	/* bitwise OR of address groups this address belongs to.
		   You might have to specify a new group in xioopts.h */
   0,		/* an integer passed to xioopen_openssl; makes it possible to
		   use the same xioopen_openssl function for slightly different
		   address types. */
   0,		/* like previous argument */
   0		/* like previous arguments, but pointer type.
		   No trailing comma or semicolon! */
   HELP(":<host>:<port>")	/* a text displayed from xio help function.
			   No trailing comma or semicolon!
			   only generates this text if WITH_HELP is != 0 */
} ;

#if WITH_LISTEN
/* description record for ssl listen */
const struct addrdesc addr_openssl_listen = {
   "openssl-listen",	/* keyword for selecting this address type in xioopen calls
		   (canonical or main name) */
   3,		/* data flow directions this address supports on API layer:
		   1..read, 2..write, 3..both */
   xioopen_openssl_listen,	/* a function pointer used to "open" these addresses.*/
   GROUP_FD|GROUP_SOCKET|GROUP_SOCK_IP4|GROUP_SOCK_IP6|GROUP_IP_TCP|GROUP_LISTEN|GROUP_CHILD|GROUP_RANGE|GROUP_OPENSSL|GROUP_RETRY,	/* bitwise OR of address groups this address belongs to.
		   You might have to specify a new group in xioopts.h */
   0,		/* an integer passed to xioopen_openssl_listen; makes it possible to
		   use the same xioopen_openssl_listen function for slightly different
		   address types. */
   0,		/* like previous argument */
   0		/* like previous arguments, but pointer type.
		   No trailing comma or semicolon! */
   HELP(":<port>")	/* a text displayed from xio help function.
			   No trailing comma or semicolon!
			   only generates this text if WITH_HELP is != 0 */
} ;
#endif /* WITH_LISTEN */

/* both client and server */
const struct optdesc opt_openssl_cipherlist = { "openssl-cipherlist", "ciphers", OPT_OPENSSL_CIPHERLIST, GROUP_OPENSSL, PH_SPEC, TYPE_STRING, OFUNC_SPEC };
const struct optdesc opt_openssl_method     = { "openssl-method",     "method",  OPT_OPENSSL_METHOD,     GROUP_OPENSSL, PH_SPEC, TYPE_STRING, OFUNC_SPEC };
const struct optdesc opt_openssl_verify     = { "openssl-verify",     "verify",  OPT_OPENSSL_VERIFY,     GROUP_OPENSSL, PH_SPEC, TYPE_BOOL,   OFUNC_SPEC };
const struct optdesc opt_openssl_certificate = { "openssl-certificate", "cert",  OPT_OPENSSL_CERTIFICATE, GROUP_OPENSSL, PH_SPEC, TYPE_FILENAME, OFUNC_SPEC };
const struct optdesc opt_openssl_key         = { "openssl-key",         "key",   OPT_OPENSSL_KEY,         GROUP_OPENSSL, PH_SPEC, TYPE_FILENAME, OFUNC_SPEC };
const struct optdesc opt_openssl_dhparam     = { "openssl-dhparam",     "dh",    OPT_OPENSSL_DHPARAM,     GROUP_OPENSSL, PH_SPEC, TYPE_FILENAME, OFUNC_SPEC };
const struct optdesc opt_openssl_cafile      = { "openssl-cafile",     "cafile", OPT_OPENSSL_CAFILE,      GROUP_OPENSSL, PH_SPEC, TYPE_FILENAME, OFUNC_SPEC };
const struct optdesc opt_openssl_capath      = { "openssl-capath",     "capath", OPT_OPENSSL_CAPATH,      GROUP_OPENSSL, PH_SPEC, TYPE_FILENAME, OFUNC_SPEC };
const struct optdesc opt_openssl_egd         = { "openssl-egd",        "egd",    OPT_OPENSSL_EGD,         GROUP_OPENSSL, PH_SPEC, TYPE_FILENAME, OFUNC_SPEC };
const struct optdesc opt_openssl_pseudo      = { "openssl-pseudo",     "pseudo", OPT_OPENSSL_PSEUDO,      GROUP_OPENSSL, PH_SPEC, TYPE_BOOL,     OFUNC_SPEC };
#if WITH_FIPS
const struct optdesc opt_openssl_fips        = { "openssl-fips",       "fips",   OPT_OPENSSL_FIPS,        GROUP_OPENSSL, PH_SPEC, TYPE_BOOL,     OFUNC_SPEC };
#endif


/* If FIPS is compiled in, we need to track if the user asked for FIPS mode.
 * On forks, the FIPS mode must be reset by a disable, then enable since
 * FIPS tracks the process ID that initializes things.
 * If FIPS is not compiled in, no tracking variable is needed
 * and we make the reset code compile out.  This keeps the
 * rest of the code below free of FIPS related #ifs
 */
#if WITH_FIPS
static bool xio_openssl_fips = false;
int xio_reset_fips_mode(void) {
   if (xio_openssl_fips) {
      if(!sycFIPS_mode_set(0) || !sycFIPS_mode_set(1)) {
	 ERR_load_crypto_strings();
	 ERR_print_errors(BIO_new_fp(stderr,BIO_NOCLOSE));
	 Error("Failed to reset OpenSSL FIPS mode");
	 xio_openssl_fips = false;
         return -1;
      }
   }
   return 0;
}
#else
#define xio_reset_fips_mode() 0
#endif

/* the open function for OpenSSL client */
static int
   xioopen_openssl_connect(int argc,
		   const char *argv[],	/* the arguments in the address string */
		   struct opt *opts,
		   int xioflags,	/* is the open meant for reading (0),
				   writing (1), or both (2) ? */
		   xiofile_t *xxfd,	/* a xio file descriptor structure,
				   already allocated */
		   unsigned groups,	/* the matching address groups... */
		   int dummy1,	/* first transparent integer value from
				   addr_openssl */
		   int dummy2,	/* second transparent integer value from
				   addr_openssl */
		   int dummy3)	/* transparent pointer value from
					   addr_openssl */
{
   struct single *xfd = &xxfd->stream;
   struct opt *opts0 = NULL;
   const char *hostname, *portname;
   int pf = PF_UNSPEC;
   int ipproto = IPPROTO_TCP;
   int socktype = SOCK_STREAM;
   bool dofork = false;
   union sockaddr_union us_sa,  *us = &us_sa;
   union sockaddr_union them_sa, *them = &them_sa;
   socklen_t uslen = sizeof(us_sa);
   socklen_t themlen = sizeof(them_sa);
   bool needbind = false;
   bool lowport = false;
   int level;
   SSL_CTX* ctx;
   bool opt_ver = true;	/* verify peer certificate */
   char *opt_cert = NULL;	/* file name of client certificate */
   int result;

   if (!(xioflags & XIO_MAYCONVERT)) {
      Error("address with data processing not allowed here");
      return STAT_NORETRY;
   }
   xfd->flags |= XIO_DOESCONVERT;

   if (argc != 3) {
      Error1("%s: 2 parameters required", argv[0]);
      return STAT_NORETRY;
   }
   hostname = argv[1];
   portname = argv[2];

   xfd->howtoend = END_SHUTDOWN;
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;
   applyopts(-1, opts, PH_INIT);

   retropt_bool(opts, OPT_FORK, &dofork);

   retropt_string(opts, OPT_OPENSSL_CERTIFICATE, &opt_cert);

   result =
      _xioopen_openssl_prepare(opts, xfd, false, &opt_ver, opt_cert, &ctx);
   if (result != STAT_OK)  return STAT_NORETRY;

   result =
      _xioopen_ipapp_prepare(opts, &opts0, hostname, portname, &pf, ipproto,
			     xfd->para.socket.ip.res_opts[1],
			     xfd->para.socket.ip.res_opts[0],
			     them, &themlen, us, &uslen,
			     &needbind, &lowport, socktype);
   if (result != STAT_OK)  return STAT_NORETRY;

   if (xioopts.logopt == 'm') {
      Info("starting connect loop, switching to syslog");
      diag_set('y', xioopts.syslogfac);  xioopts.logopt = 'y';
   } else {
      Info("starting connect loop");
   }

   do {	/* loop over failed connect and SSL handshake attempts */

#if WITH_RETRY
      if (xfd->forever || xfd->retry) {
	 level = E_INFO;
      } else
#endif /* WITH_RETRY */
	 level = E_ERROR;

      /* this cannot fork because we retrieved fork option above */
      result =
	 _xioopen_connect(xfd,
			  needbind?(struct sockaddr *)us:NULL, sizeof(*us),
			  (struct sockaddr *)them, themlen,
			  opts, pf, socktype, ipproto, lowport, level);
      switch (result) {
      case STAT_OK: break;
#if WITH_RETRY
      case STAT_RETRYLATER:
      case STAT_RETRYNOW:
	 if (xfd->forever || xfd->retry) {
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    if (result == STAT_RETRYLATER) {
	       Nanosleep(&xfd->intervall, NULL);
	    }
	    --xfd->retry;
	    continue;
	 }
	 return STAT_NORETRY;
#endif /* WITH_RETRY */
      default:
	 return result;
      }

      /*! isn't this too early? */
      if ((result = _xio_openlate(xfd, opts)) < 0) {
	 return result;
      }

      result = _xioopen_openssl_connect(xfd, opt_ver, ctx, level);
      switch (result) {
      case STAT_OK: break;
#if WITH_RETRY
      case STAT_RETRYLATER:
      case STAT_RETRYNOW:
	 if (xfd->forever || xfd->retry) {
	    Close(xfd->fd);
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    if (result == STAT_RETRYLATER) {
	       Nanosleep(&xfd->intervall, NULL);
	    }
	    --xfd->retry;
	    continue;
	 }
#endif /* WITH_RETRY */
      default: return STAT_NORETRY;
      }

      if (dofork) {
	 xiosetchilddied();	/* set SIGCHLD handler */
      }

#if WITH_RETRY
      if (dofork) {
	 pid_t pid;
	 int level = E_ERROR;
	 if (xfd->forever || xfd->retry) {
	    level = E_WARN;
	 }
	 while ((pid = xio_fork(false, level)) < 0) {
	    if (xfd->forever || --xfd->retry) {
	       Nanosleep(&xfd->intervall, NULL); continue;
	    }
	    return STAT_RETRYLATER;
	 }

	 if (pid == 0) {	/* child process */
	    xfd->forever = false;  xfd->retry = 0;
	    break;
	 }

	 /* parent process */
	 Close(xfd->fd);
	 sycSSL_free(xfd->para.openssl.ssl);
	 xfd->para.openssl.ssl = NULL;
	 /* with and without retry */
	 Nanosleep(&xfd->intervall, NULL);
	 dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	 continue;	/* with next socket() bind() connect() */
      }
#endif /* WITH_RETRY */
      break;
   } while (true);	/* drop out on success */

   Notice1("SSL connection using %s", SSL_get_cipher(xfd->para.openssl.ssl));

   /* fill in the fd structure */
   return STAT_OK;
}


/* this function is typically called within the OpenSSL client fork/retry loop.
   xfd must be of type DATA_OPENSSL, and its fd must be set with a valid file
   descriptor. this function then performs all SSL related step to make a valid
   SSL connection from an FD and a CTX. */
int _xioopen_openssl_connect(struct single *xfd,
			     bool opt_ver,
			     SSL_CTX *ctx,
			     int level) {
   SSL *ssl;
   unsigned long err;
   int result;

   /* create a SSL object */
   if ((ssl = sycSSL_new(ctx)) == NULL) {
      if (ERR_peek_error() == 0)  Msg(level, "SSL_new() failed");
      while (err = ERR_get_error()) {
	 Msg1(level, "SSL_new(): %s", ERR_error_string(err, NULL));
      }
      /*Error("SSL_new()");*/
      return STAT_RETRYLATER;
   }
   xfd->para.openssl.ssl = ssl;

   result = xioSSL_set_fd(xfd, level);
   if (result != STAT_OK) {
      sycSSL_free(xfd->para.openssl.ssl);
      xfd->para.openssl.ssl = NULL;
      return result;
   }

   result = xioSSL_connect(xfd, opt_ver, level);
   if (result != STAT_OK) {
      sycSSL_free(xfd->para.openssl.ssl);
      xfd->para.openssl.ssl = NULL;
      return result;
   }

   result = openssl_handle_peer_certificate(xfd, opt_ver, level);
   if (result != STAT_OK) {
      sycSSL_free(xfd->para.openssl.ssl);
      xfd->para.openssl.ssl = NULL;
      return result;
   }

   return STAT_OK;
}


#if WITH_LISTEN

static int
   xioopen_openssl_listen(int argc,
		   const char *argv[],	/* the arguments in the address string */
		   struct opt *opts,
		   int xioflags,	/* is the open meant for reading (0),
				   writing (1), or both (2) ? */
		   xiofile_t *xxfd,	/* a xio file descriptor structure,
				   already allocated */
		   unsigned groups,	/* the matching address groups... */
		   int dummy1,	/* first transparent integer value from
				   addr_openssl */
		   int dummy2,	/* second transparent integer value from
				   addr_openssl */
		   int dummy3)	/* transparent pointer value from
					   addr_openssl */
{
   struct single *xfd = &xxfd->stream;
   const char *portname;
   struct opt *opts0 = NULL;
   union sockaddr_union us_sa, *us = &us_sa;
   socklen_t uslen = sizeof(us_sa);
   int pf;
   int socktype = SOCK_STREAM;
   int ipproto = IPPROTO_TCP;
   /*! lowport? */
   int level;
   SSL_CTX* ctx;
   bool opt_ver = true;	/* verify peer certificate - changed with 1.6.0 */
   char *opt_cert = NULL;	/* file name of server certificate */
   int result;

   if (!(xioflags & XIO_MAYCONVERT)) {
      Error("address with data processing not allowed here");
      return STAT_NORETRY;
   }
   xfd->flags |= XIO_DOESCONVERT;

   if (argc != 2) {
      Error1("%s: 1 parameter required", argv[0]);
      return STAT_NORETRY;
   }

#if WITH_IP4 && WITH_IP6
   pf = xioopts.default_ip=='6'?PF_INET6:PF_INET;
#elif WITH_IP6
   pf = PF_INET6;
#else
   pf = PF_INET;
#endif
   
   portname = argv[1];

   xfd->howtoend = END_SHUTDOWN;
   if (applyopts_single(xfd, opts, PH_INIT) < 0)  return -1;
   applyopts(-1, opts, PH_INIT);

   retropt_string(opts, OPT_OPENSSL_CERTIFICATE, &opt_cert);
   if (opt_cert == NULL) {
      Warn("no certificate given; consider option \"cert\"");
   }

   applyopts(-1, opts, PH_EARLY);

   result =
      _xioopen_openssl_prepare(opts, xfd, true, &opt_ver, opt_cert, &ctx);
   if (result != STAT_OK)  return STAT_NORETRY;

   if (_xioopen_ipapp_listen_prepare(opts, &opts0, portname, &pf, ipproto,
				     xfd->para.socket.ip.res_opts[1],
				     xfd->para.socket.ip.res_opts[0],
				     us, &uslen, socktype)
       != STAT_OK) {
      return STAT_NORETRY;
   }

   xfd->addr  = &addr_openssl_listen;
   xfd->dtype = XIODATA_OPENSSL;

   while (true) {	/* loop over failed attempts */

#if WITH_RETRY
      if (xfd->forever || xfd->retry) {
	 level = E_INFO;
      } else
#endif /* WITH_RETRY */
	 level = E_ERROR;

      /* tcp listen; this can fork() for us; it only returns on error or on
	 successful establishment of tcp connection */
      result = _xioopen_listen(xfd, xioflags,
			       (struct sockaddr *)us, uslen,
			       opts, pf, socktype, IPPROTO_TCP,
#if WITH_RETRY
			       (xfd->retry||xfd->forever)?E_INFO:E_ERROR
#else
			       E_ERROR
#endif /* WITH_RETRY */
			       );
	 /*! not sure if we should try again on retry/forever */
      switch (result) {
      case STAT_OK: break;
#if WITH_RETRY
      case STAT_RETRYLATER:
      case STAT_RETRYNOW:
	 if (xfd->forever || xfd->retry) {
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    if (result == STAT_RETRYLATER) {
	       Nanosleep(&xfd->intervall, NULL);
	    }
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    --xfd->retry;
	    continue;
	 }
	 return STAT_NORETRY;
#endif /* WITH_RETRY */
      default:
	 return result;
      }

      result = _xioopen_openssl_listen(xfd, opt_ver, ctx, level);
      switch (result) {
      case STAT_OK: break;
#if WITH_RETRY
      case STAT_RETRYLATER:
      case STAT_RETRYNOW:
	 if (xfd->forever || xfd->retry) {
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    if (result == STAT_RETRYLATER) {
	       Nanosleep(&xfd->intervall, NULL);
	    }
	    dropopts(opts, PH_ALL); opts = copyopts(opts0, GROUP_ALL);
	    --xfd->retry;
	    continue;
	 }
	 return STAT_NORETRY;
#endif /* WITH_RETRY */
      default:
	 return result;
      }

      Notice1("SSL connection using %s",
	      SSL_get_cipher(xfd->para.openssl.ssl));
      break;

   }	/* drop out on success */

   /* fill in the fd structure */

   return STAT_OK;
}


int _xioopen_openssl_listen(struct single *xfd,
			     bool opt_ver,
			     SSL_CTX *ctx,
			     int level) {
   char error_string[120];
   unsigned long err;
   int errint, ret;

   /* create an SSL object */
   if ((xfd->para.openssl.ssl = sycSSL_new(ctx)) == NULL) {
      if (ERR_peek_error() == 0)  Msg(level, "SSL_new() failed");
      while (err = ERR_get_error()) {
	 Msg1(level, "SSL_new(): %s", ERR_error_string(err, NULL));
      }
      /*Error("SSL_new()");*/
      return STAT_NORETRY;
   }

   /* assign the network connection to the SSL object */
   if (sycSSL_set_fd(xfd->para.openssl.ssl, xfd->fd) <= 0) {
      if (ERR_peek_error() == 0) Msg(level, "SSL_set_fd() failed");
      while (err = ERR_get_error()) {
	 Msg2(level, "SSL_set_fd(, %d): %s",
	      xfd->fd, ERR_error_string(err, NULL));
      }
   }

#if WITH_DEBUG
   {
      int i = 0;
      const char *ciphers = NULL;
      Debug("available ciphers:");
      do {
	 ciphers = SSL_get_cipher_list(xfd->para.openssl.ssl, i);
	 if (ciphers == NULL)  break;
	 Debug2("CIPHERS pri=%d: %s", i, ciphers);
	 ++i;
      } while (1);
   }
#endif /* WITH_DEBUG */

   /* connect via SSL by performing handshake */
   if ((ret = sycSSL_accept(xfd->para.openssl.ssl)) <= 0) {
      /*if (ERR_peek_error() == 0) Msg(level, "SSL_accept() failed");*/
      errint = SSL_get_error(xfd->para.openssl.ssl, ret);
      switch (errint) {
      case SSL_ERROR_NONE:
	 Msg(level, "ok"); break;
      case SSL_ERROR_ZERO_RETURN:
	 Msg(level, "connection closed (wrong version number?)"); break;
      case SSL_ERROR_WANT_READ: case SSL_ERROR_WANT_WRITE:
      case SSL_ERROR_WANT_CONNECT:
      case SSL_ERROR_WANT_X509_LOOKUP:
	 Msg(level, "nonblocking operation did not complete"); break;	/*!*/
      case SSL_ERROR_SYSCALL:
	 if (ERR_peek_error() == 0) {
	    if (ret == 0) {
	       Msg(level, "SSL_accept(): socket closed by peer");
	    } else if (ret == -1) {
	       Msg1(level, "SSL_accept(): %s", strerror(errno));
	    }
	 } else {
	    Msg(level, "I/O error");	/*!*/
	    while (err = ERR_get_error()) {
	       ERR_error_string_n(err, error_string, sizeof(error_string));
	       Msg4(level, "SSL_accept(): %s / %s / %s / %s", error_string,
		    ERR_lib_error_string(err), ERR_func_error_string(err),
		    ERR_reason_error_string(err));
	    }
	    /* Msg1(level, "SSL_connect(): %s", ERR_error_string(e, buf));*/
	 }
	 break;
      case SSL_ERROR_SSL:
	 /*ERR_print_errors_fp(stderr);*/
	 openssl_SSL_ERROR_SSL(level, "SSL_accept");
	 break;
      default:
	 Msg(level, "unknown error");
      }

      return STAT_RETRYLATER;
   }

   if (openssl_handle_peer_certificate(xfd, opt_ver, E_ERROR/*!*/) < 0) {
      return STAT_NORETRY;
   }

   return STAT_OK;
}

#endif /* WITH_LISTEN */


int
   _xioopen_openssl_prepare(struct opt *opts,
			    struct single *xfd,/* a xio file descriptor
						  structure, already allocated
					       */
			    bool server,	/* SSL client: false */
			    bool *opt_ver,
			    const char *opt_cert,
			    SSL_CTX **ctx)
{
   bool opt_fips = false;
   SSL_METHOD *method;
   char *me_str = NULL;	/* method string */
   char *ci_str = NULL;	/* cipher string */
   char *opt_key  = NULL;	/* file name of client private key */
   char *opt_dhparam = NULL;	/* file name of DH params */
   char *opt_cafile = NULL;	/* certificate authority file */
   char *opt_capath = NULL;	/* certificate authority directory */
   char *opt_egd = NULL;	/* entropy gathering daemon socket path */
   bool opt_pseudo = false;	/* use pseudo entropy if nothing else */
   unsigned long err;
   int result;

   xfd->addr  = &addr_openssl;
   xfd->dtype = XIODATA_OPENSSL;

   retropt_bool(opts, OPT_OPENSSL_FIPS, &opt_fips);
   retropt_string(opts, OPT_OPENSSL_METHOD, &me_str);
   retropt_string(opts, OPT_OPENSSL_CIPHERLIST, &ci_str);
   retropt_bool(opts, OPT_OPENSSL_VERIFY, opt_ver);
   retropt_string(opts, OPT_OPENSSL_CAFILE, &opt_cafile);
   retropt_string(opts, OPT_OPENSSL_CAPATH, &opt_capath);
   retropt_string(opts, OPT_OPENSSL_KEY, &opt_key);
   retropt_string(opts, OPT_OPENSSL_DHPARAM, &opt_dhparam);
   retropt_string(opts, OPT_OPENSSL_EGD, &opt_egd);
   retropt_bool(opts,OPT_OPENSSL_PSEUDO, &opt_pseudo);

#if WITH_FIPS
   if (opt_fips) {
      if (!sycFIPS_mode_set(1)) {
	 ERR_load_crypto_strings();
	 ERR_print_errors(BIO_new_fp(stderr,BIO_NOCLOSE));
	 Error("Failed to set FIPS mode");
      } else {
	 xio_openssl_fips = true;
      }
   }
#endif

   OpenSSL_add_all_algorithms();
   OpenSSL_add_all_ciphers();
   OpenSSL_add_all_digests();
   sycSSL_load_error_strings();

   /* OpenSSL preparation */
   sycSSL_library_init();
   
   /*! actions_to_seed_PRNG();*/

   if (!server) {
      if (me_str != 0) {
	 if (!strcasecmp(me_str, "SSLv2") || !strcasecmp(me_str, "SSL2")) {
	    method = sycSSLv2_client_method();
	 } else if (!strcasecmp(me_str, "SSLv3") || !strcasecmp(me_str, "SSL3")) {
	    method = sycSSLv3_client_method();
	 } else if (!strcasecmp(me_str, "SSLv23") || !strcasecmp(me_str, "SSL23") ||
		    !strcasecmp(me_str, "SSL")) {
	    method = sycSSLv23_client_method();
	 } else if (!strcasecmp(me_str, "TLSv1") || !strcasecmp(me_str, "TLS1") ||
		    !strcasecmp(me_str, "TLS")) {
	    method = sycTLSv1_client_method();
	 } else {
	    Error1("openssl-method=\"%s\": unknown method", me_str);
	    method = sycSSLv23_client_method()/*!*/;
	 }
      } else {
	 method = sycSSLv23_client_method()/*!*/;
      }
   } else /* server */ {
      if (me_str != 0) {
	 if (!strcasecmp(me_str, "SSLv2") || !strcasecmp(me_str, "SSL2")) {
	    method = sycSSLv2_server_method();
	 } else if (!strcasecmp(me_str, "SSLv3") || !strcasecmp(me_str, "SSL3")) {
	    method = sycSSLv3_server_method();
	 } else if (!strcasecmp(me_str, "SSLv23") || !strcasecmp(me_str, "SSL23") ||
		    !strcasecmp(me_str, "SSL")) {
	    method = sycSSLv23_server_method();
	 } else if (!strcasecmp(me_str, "TLSv1") || !strcasecmp(me_str, "TLS1") ||
		    !strcasecmp(me_str, "TLS")) {
	    method = sycTLSv1_server_method();
	 } else {
	    Error1("openssl-method=\"%s\": unknown method", me_str);
	    method = sycSSLv23_server_method()/*!*/;
	 }
      } else {
	 method = sycSSLv23_server_method()/*!*/;
      }
   }

   if (opt_egd) {
      sycRAND_egd(opt_egd);
   }

   if (opt_pseudo) {
      long int randdata;
      /* initialize libc random from actual microseconds */
      struct timeval tv;
      struct timezone tz;
      tz.tz_minuteswest = 0;
      tz.tz_dsttime = 0;
      if ((result = Gettimeofday(&tv, &tz)) < 0) {
	 Warn2("gettimeofday(%p, {0,0}): %s", &tv, strerror(errno));
      }
      srandom(tv.tv_sec*1000000+tv.tv_usec);

      while (!RAND_status()) {
	 randdata = random();
	 Debug2("RAND_seed(0x{%lx}, "F_Zu")",
		randdata, sizeof(randdata));
	 RAND_seed(&randdata, sizeof(randdata));
      }
   }

   if ((*ctx = sycSSL_CTX_new(method)) == NULL) {
      if (ERR_peek_error() == 0) Error("SSL_CTX_new()");
      while (err = ERR_get_error()) {
	 Error1("SSL_CTX_new(): %s", ERR_error_string(err, NULL));
      }

      /*ERR_clear_error;*/
      return STAT_RETRYLATER;
   }

   if (opt_cafile != NULL || opt_capath != NULL) {
      if (sycSSL_CTX_load_verify_locations(*ctx, opt_cafile, opt_capath) != 1) {
	 int result;

	 if ((result =
	      openssl_SSL_ERROR_SSL(E_ERROR, "SSL_CTX_load_verify_locations"))
	     != STAT_OK) {
	    /*! free ctx */
	    return STAT_RETRYLATER;
	 }
      }
   }

   if (opt_cert) {
      BIO *bio;
      DH *dh;

      if (sycSSL_CTX_use_certificate_chain_file(*ctx, opt_cert) <= 0) {
	 /*! trace functions */
	 /*0 ERR_print_errors_fp(stderr);*/
	 if (ERR_peek_error() == 0)
	    Error2("SSL_CTX_use_certificate_file(%p, \"%s\", SSL_FILETYPE_PEM) failed",
		 *ctx, opt_cert);
	 while (err = ERR_get_error()) {
	    Error1("SSL_CTX_use_certificate_file(): %s",
		   ERR_error_string(err, NULL));
	 }
	 return STAT_RETRYLATER;
      }

      if (sycSSL_CTX_use_PrivateKey_file(*ctx, opt_key?opt_key:opt_cert, SSL_FILETYPE_PEM) <= 0) {
	 /*ERR_print_errors_fp(stderr);*/
	 openssl_SSL_ERROR_SSL(E_ERROR/*!*/, "SSL_CTX_use_PrivateKey_file");
	 return STAT_RETRYLATER;
      }

      if (opt_dhparam == NULL) {
	 opt_dhparam = (char *)opt_cert;
      }
      if ((bio = sycBIO_new_file(opt_dhparam, "r")) == NULL) {
	 Warn2("BIO_new_file(\"%s\", \"r\"): %s",
	       opt_dhparam, strerror(errno));
      } else {
	 if ((dh = sycPEM_read_bio_DHparams(bio, NULL, NULL, NULL)) == NULL) {
	    Info1("PEM_read_bio_DHparams(%p, NULL, NULL, NULL): error", bio);
	 } else {
	    BIO_free(bio);
	    if (sycSSL_CTX_set_tmp_dh(*ctx, dh) == 0) {
	       Error2("SSL_CTX_set_tmp_dh(%p, %p): error", ctx, dh);
	    }
	 }
      }
   }

   /* set pre ssl-connect options */
   /* SSL_CIPHERS */
   if (ci_str != NULL) {
      if (sycSSL_CTX_set_cipher_list(*ctx, ci_str) <= 0) {
	 if (ERR_peek_error() == 0)
	    Error1("SSL_set_cipher_list(, \"%s\") failed", ci_str);
	 while (err = ERR_get_error()) {
	    Error2("SSL_set_cipher_list(, \"%s\"): %s",
		   ci_str, ERR_error_string(err, NULL));
	 }
	 /*Error("SSL_new()");*/
	 return STAT_RETRYLATER;
      }
   }

   if (*opt_ver) {
      sycSSL_CTX_set_verify(*ctx,
			    SSL_VERIFY_PEER| SSL_VERIFY_FAIL_IF_NO_PEER_CERT,
			    NULL);
   } else {
      sycSSL_CTX_set_verify(*ctx,
			    SSL_VERIFY_NONE,
			    NULL);
   }

   return STAT_OK;
}


/* analyses an OpenSSL error condition, prints the appropriate messages with
   severity 'level' and returns one of STAT_OK, STAT_RETRYLATER, or
   STAT_NORETRY */
static int openssl_SSL_ERROR_SSL(int level, const char *funcname) {
   unsigned long e;
   char buf[120];	/* this value demanded by "man ERR_error_string" */

   e = ERR_get_error();
   Debug1("ERR_get_error(): %lx", e);
   if (e == ((ERR_LIB_RAND<<24)|
	     (RAND_F_SSLEAY_RAND_BYTES<<12)|
	     (RAND_R_PRNG_NOT_SEEDED)) /*0x24064064*/) {
      Error("too few entropy; use options \"egd\" or \"pseudo\"");
      return STAT_NORETRY;
   } else {
      Msg2(level, "%s(): %s", funcname, ERR_error_string(e, buf));
      return level==E_ERROR ? STAT_NORETRY : STAT_RETRYLATER;
   }
   return STAT_OK;
}

static const char *openssl_verify_messages[] = {
   /*  0 */ "ok",
   /*  1 */ NULL,
   /*  2 */ "unable to get issuer certificate",
   /*  3 */ "unable to get certificate CRL",
   /*  4 */ "unable to decrypt certificate's signature",
   /*  5 */ "unable to decrypt CRL's signature",
   /*  6 */ "unable to decode issuer public key",
   /*  7 */ "certificate signature failure",
   /*  8 */ "CRL signature failure",
   /*  9 */ "certificate is not yet valid",
   /* 10 */ "certificate has expired",
   /* 11 */ "CRL is not yet valid",
   /* 12 */ "CRL has expired",
   /* 13 */ "format error in certificate's notBefore field",
   /* 14 */ "format error in certificate's notAfter field",
   /* 15 */ "format error in CRL's lastUpdate field",
   /* 16 */ "format error in CRL's nextUpdate field",
   /* 17 */ "out of memory",
   /* 18 */ "self signed certificate",
   /* 19 */ "self signed certificate in certificate chain",
   /* 20 */ "unable to get local issuer certificate",
   /* 21 */ "unable to verify the first certificate",
   /* 22 */ "certificate chain too long",
   /* 23 */ "certificate revoked",
   /* 24 */ "invalid CA certificate",
   /* 25 */ "path length constraint exceeded",
   /* 26 */ "unsupported certificate purpose",
   /* 27 */ "certificate not trusted",
   /* 28 */ "certificate rejected",
   /* 29 */ "subject issuer mismatch",
   /* 30 */ "authority and subject key identifier mismatch",
   /* 31 */ "authority and issuer serial number mismatch",
   /* 32 */ "key usage does not include certificate signing",
   /* 33 */ NULL,
   /* 34 */ NULL,
   /* 35 */ NULL,
   /* 36 */ NULL,
   /* 37 */ NULL,
   /* 38 */ NULL,
   /* 39 */ NULL,
   /* 40 */ NULL,
   /* 41 */ NULL,
   /* 42 */ NULL,
   /* 43 */ NULL,
   /* 44 */ NULL,
   /* 45 */ NULL,
   /* 46 */ NULL,
   /* 47 */ NULL,
   /* 48 */ NULL,
   /* 49 */ NULL,
   /* 50 */ "application verification failure",
} ;

static int openssl_handle_peer_certificate(struct single *xfd,
					   bool opt_ver, int level) {
   X509 *peer_cert;
   char *str;
   char buff[2048];	/* hold peer certificate */
   int status;

   /* SSL_CTX_add_extra_chain_cert
      SSL_get_verify_result
   */
   if ((peer_cert = SSL_get_peer_certificate(xfd->para.openssl.ssl)) != NULL) {
      Debug("peer certificate:");
      if ((str = X509_NAME_oneline(X509_get_subject_name(peer_cert), buff, sizeof(buff))) != NULL)
	 Debug1("\tsubject: %s", str);  /*free (str); SIGSEGV*/
      if ((str = X509_NAME_oneline(X509_get_issuer_name(peer_cert), buff, sizeof(buff))) != NULL)
	 Debug1("\tissuer: %s", str);  /*free (str); SIGSEGV*/
   }

   if (peer_cert) {
      if (opt_ver) {
	 long verify_result;
	 if ((verify_result = sycSSL_get_verify_result(xfd->para.openssl.ssl)) == X509_V_OK) {
	    Info("accepted peer certificate");
	    status = STAT_OK;
	 } else {
	    const char *message = NULL;
	    if (verify_result >= 0 &&
		(size_t)verify_result <
		   sizeof(openssl_verify_messages)/sizeof(char*))
	    {
	       message = openssl_verify_messages[verify_result];
	    }
	    if (message) {
	       Msg1(level, "%s", message);
	    } else {
	       Msg1(level, "rejected peer certificate with error %ld", verify_result);
	    }
	    status = STAT_RETRYLATER;
	 }
      } else {
	 Notice("no check of certificate");
	 status = STAT_OK;
      }
   } else {
      if (opt_ver) {
	 Msg(level, "no peer certificate");
	 status = STAT_RETRYLATER;
      } else {
	 Notice("no peer certificate and no check");
	 status = STAT_OK;
      }
   }

   X509_free(peer_cert);
   return status;
}

static int xioSSL_set_fd(struct single *xfd, int level) {
   unsigned long err;

   /* assign a network connection to the SSL object */
   if (sycSSL_set_fd(xfd->para.openssl.ssl, xfd->fd) <= 0) {
      Msg(level, "SSL_set_fd() failed");
      while (err = ERR_get_error()) {
	 Msg2(level, "SSL_set_fd(, %d): %s",
	      xfd->fd, ERR_error_string(err, NULL));
      }
      return STAT_RETRYLATER;
   }
   return STAT_OK;
}


/* ...
   in case of an error condition, this function check forever and retry
   options and ev. sleeps an interval. It returns NORETRY when the caller
   should not retry for any reason. */
static int xioSSL_connect(struct single *xfd, bool opt_ver, int level) {
   char error_string[120];
   int errint, status, ret;
   unsigned long err;

   /* connect via SSL by performing handshake */
   if ((ret = sycSSL_connect(xfd->para.openssl.ssl)) <= 0) {
      /*if (ERR_peek_error() == 0) Msg(level, "SSL_connect() failed");*/
      errint = SSL_get_error(xfd->para.openssl.ssl, ret);
      switch (errint) {
      case SSL_ERROR_NONE:
	 /* this is not an error, but I dare not continue for security reasons*/
	 Msg(level, "ok");
	 status = STAT_RETRYLATER;
      case SSL_ERROR_ZERO_RETURN:
	 Msg(level, "connection closed (wrong version number?)");
	 status = STAT_RETRYLATER;
	 break;
      case SSL_ERROR_WANT_READ:
      case SSL_ERROR_WANT_WRITE:
      case SSL_ERROR_WANT_CONNECT:
      case SSL_ERROR_WANT_X509_LOOKUP:
	 Msg(level, "nonblocking operation did not complete");
	 status = STAT_RETRYLATER;
	 break;	/*!*/
      case SSL_ERROR_SYSCALL:
	 if (ERR_peek_error() == 0) {
	    if (ret == 0) {
	       Msg(level, "SSL_connect(): socket closed by peer");
	    } else if (ret == -1) {
	       Msg1(level, "SSL_connect(): %s", strerror(errno));
	    }
	 } else {
	    Msg(level, "I/O error");	/*!*/
	    while (err = ERR_get_error()) {
	       ERR_error_string_n(err, error_string, sizeof(error_string));
	       Msg4(level, "SSL_connect(): %s / %s / %s / %s", error_string,
		    ERR_lib_error_string(err), ERR_func_error_string(err),
		    ERR_reason_error_string(err));
	    }
	 }
	 status = STAT_RETRYLATER;
	 break;
      case SSL_ERROR_SSL:
	 status = openssl_SSL_ERROR_SSL(level, "SSL_connect");
	 if (openssl_handle_peer_certificate(xfd, opt_ver, level/*!*/) < 0) {
	    return STAT_RETRYLATER;
	 }
	 break;
      default:
	 Msg(level, "unknown error");
	 status = STAT_RETRYLATER;
	 break;
      }
      return status;
   }
   return STAT_OK;
}

/* on result < 0: errno is set (at least to EIO) */
ssize_t xioread_openssl(struct single *pipe, void *buff, size_t bufsiz) {
   unsigned long err;
   char error_string[120];
   int _errno = EIO;	/* if we have no better idea about nature of error */
   int errint, ret;

   ret = sycSSL_read(pipe->para.openssl.ssl, buff, bufsiz);
   if (ret < 0) {
      errint = SSL_get_error(pipe->para.openssl.ssl, ret);
      switch (errint) {
      case SSL_ERROR_NONE:
	 /* this is not an error, but I dare not continue for security reasons*/
	 Error("ok");
      case SSL_ERROR_ZERO_RETURN:
	 Error("connection closed by peer");
	 break;
      case SSL_ERROR_WANT_READ:
      case SSL_ERROR_WANT_WRITE:
      case SSL_ERROR_WANT_CONNECT:
      case SSL_ERROR_WANT_X509_LOOKUP:
	 Info("nonblocking operation did not complete");
	 errno = EAGAIN;
	 return -1;
      case SSL_ERROR_SYSCALL:
	 if (ERR_peek_error() == 0) {
	    if (ret == 0) {
	       Error("SSL_read(): socket closed by peer");
	    } else if (ret == -1) {
	       _errno = errno;
	       Error1("SSL_read(): %s", strerror(errno));
	    }
	 } else {
	    Error("I/O error");	/*!*/
	    while (err = ERR_get_error()) {
	       ERR_error_string_n(err, error_string, sizeof(error_string));
	       Error4("SSL_read(): %s / %s / %s / %s", error_string,
		      ERR_lib_error_string(err), ERR_func_error_string(err),
		      ERR_reason_error_string(err));
	    }
	 }
	 break;
      case SSL_ERROR_SSL:
	 openssl_SSL_ERROR_SSL(E_ERROR, "SSL_connect");
	 break;
      default:
	 Error("unknown error");
	 break;
      }
      errno = _errno;
      return -1;
   }
   return ret;
}

ssize_t xiopending_openssl(struct single *pipe) {
   int bytes = sycSSL_pending(pipe->para.openssl.ssl);
   return bytes;
}

/* on result < 0: errno is set (at least to EIO) */
ssize_t xiowrite_openssl(struct single *pipe, const void *buff, size_t bufsiz) {
   unsigned long err;
   char error_string[120];
   int _errno = EIO;	/* if we have no better idea about nature of error */
   int errint, ret;

   ret = sycSSL_write(pipe->para.openssl.ssl, buff, bufsiz);
   if (ret < 0) {
      errint = SSL_get_error(pipe->para.openssl.ssl, ret);
      switch (errint) {
      case SSL_ERROR_NONE:
	 /* this is not an error, but I dare not continue for security reasons*/
	 Error("ok");
      case SSL_ERROR_ZERO_RETURN:
	 Error("connection closed by peer");
	 break;
      case SSL_ERROR_WANT_READ:
      case SSL_ERROR_WANT_WRITE:
      case SSL_ERROR_WANT_CONNECT:
      case SSL_ERROR_WANT_X509_LOOKUP:
	 Error("nonblocking operation did not complete");
	 break;	/*!*/
      case SSL_ERROR_SYSCALL:
	 if (ERR_peek_error() == 0) {
	    if (ret == 0) {
	       Error("SSL_write(): socket closed by peer");
	    } else if (ret == -1) {
	       _errno = errno;
	       Error1("SSL_write(): %s", strerror(errno));
	    }
	 } else {
	    Error("I/O error");	/*!*/
	    while (err = ERR_get_error()) {
	       ERR_error_string_n(err, error_string, sizeof(error_string));
	       Error4("SSL_write(): %s / %s / %s / %s", error_string,
		      ERR_lib_error_string(err), ERR_func_error_string(err),
		      ERR_reason_error_string(err));
	    }
	 }
	 break;
      case SSL_ERROR_SSL:
	 openssl_SSL_ERROR_SSL(E_ERROR, "SSL_connect");
	 break;
      default:
	 Error("unknown error");
	 break;
      }
      errno = _errno;
      return -1;
   }
   return ret;
}


#endif /* WITH_OPENSSL */
