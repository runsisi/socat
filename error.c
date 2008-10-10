/* source: error.c */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* the logging subsystem */

#include "config.h"

#include <stdarg.h>
#include <stdlib.h>
#include <errno.h>
#if HAVE_SYSLOG_H
#include <syslog.h>
#endif
#include <sys/utsname.h>
#include <time.h>	/* time_t, strftime() */
#include <sys/time.h>	/* gettimeofday() */
#include <stdio.h>
#include <string.h>
#if HAVE_UNISTD_H
#include <unistd.h>
#endif
#include "mytypes.h"
#include "compat.h"
#include "utils.h"

#include "error.h"

/* translate MSG level to SYSLOG level */
int syslevel[] = {
   LOG_DEBUG,
   LOG_INFO,
   LOG_NOTICE,
   LOG_WARNING,
   LOG_ERR,
   LOG_CRIT };

struct diag_opts {
   const char *progname;
   int msglevel;
   int exitlevel;
   int syslog;
   FILE *logfile;
   int logfacility;
   bool micros;
   int exitstatus;	/* pass signal number to error exit */
   bool withhostname;	/* in custom logs add hostname */
   char *hostname;
} ;


struct diag_opts diagopts =
  { NULL, E_ERROR, E_ERROR, 0, NULL, LOG_DAEMON, false, 0 } ;

static void _msg(int level, const char *buff, const char *syslp);

static struct wordent facilitynames[] = {
   {"auth",     (void *)LOG_AUTH},
#ifdef LOG_AUTHPRIV
   {"authpriv", (void *)LOG_AUTHPRIV},
#endif
#ifdef LOG_CONSOLE
   {"console",	(void *)LOG_CONSOLE},
#endif
   {"cron",     (void *)LOG_CRON},
   {"daemon",   (void *)LOG_DAEMON},
#ifdef LOG_FTP
   {"ftp",      (void *)LOG_FTP},
#endif
   {"kern",     (void *)LOG_KERN},
   {"local0",   (void *)LOG_LOCAL0},
   {"local1",   (void *)LOG_LOCAL1},
   {"local2",   (void *)LOG_LOCAL2},
   {"local3",   (void *)LOG_LOCAL3},
   {"local4",   (void *)LOG_LOCAL4},
   {"local5",   (void *)LOG_LOCAL5},
   {"local6",   (void *)LOG_LOCAL6},
   {"local7",   (void *)LOG_LOCAL7},
   {"lpr",      (void *)LOG_LPR},
   {"mail",     (void *)LOG_MAIL},
   {"news",     (void *)LOG_NEWS},
#ifdef LOG_SECURITY
   {"security",	(void *)LOG_SECURITY},
#endif
   {"syslog",   (void *)LOG_SYSLOG},
   {"user",     (void *)LOG_USER},
   {"uucp",     (void *)LOG_UUCP}
} ;


static int diaginitialized;
static int diag_init(void) {
   if (diaginitialized) {
      return 0;
   }
   diaginitialized = 1;
   /* gcc with GNU libc refuses to set this in the initializer */
   diagopts.logfile = stderr;
   return 0;
}
#define DIAG_INIT ((void)(diaginitialized || diag_init()))


void diag_set(char what, const char *arg) {
   DIAG_INIT;
   switch (what) {
      const struct wordent *keywd;

   case 'y': diagopts.syslog = true;
      if (arg && arg[0]) {
	 if ((keywd =
	      keyw(facilitynames, arg,
		   sizeof(facilitynames)/sizeof(struct wordent))) == NULL) {
	    Error1("unknown syslog facility \"%s\"", arg);
	 } else {
	    diagopts.logfacility = (int)(size_t)keywd->desc;
	 }
      }
      openlog(diagopts.progname, LOG_PID, diagopts.logfacility);
      if (diagopts.logfile != NULL && diagopts.logfile != stderr) {
	 fclose(diagopts.logfile);
      }
      diagopts.logfile = NULL;
      break;
   case 'f':
      if (diagopts.logfile != NULL && diagopts.logfile != stderr) {
	 fclose(diagopts.logfile);
      }
      if ((diagopts.logfile = fopen(arg, "a")) == NULL) {
	  Error2("cannot open log file \"%s\": %s", arg, strerror(errno));
      }
      break;
   case 's':
      if (diagopts.logfile != NULL && diagopts.logfile != stderr) {
	 fclose(diagopts.logfile);
      }
      diagopts.logfile = stderr; break;	/* logging to stderr is default */
   case 'p': diagopts.progname = arg;
      openlog(diagopts.progname, LOG_PID, diagopts.logfacility);
      break;
   case 'd': --diagopts.msglevel; break;
   case 'u': diagopts.micros = true; break;
   default: msg(E_ERROR, "unknown diagnostic option %c", what);
   }
}

void diag_set_int(char what, int arg) {
   DIAG_INIT;
   switch (what) {
   case 'D': diagopts.msglevel = arg; break;
   case 'e': diagopts.exitlevel = arg; break;
   case 'x': diagopts.exitstatus = arg; break;
   case 'h': diagopts.withhostname = arg;
      if ((diagopts.hostname = getenv("HOSTNAME")) == NULL) {
	 struct utsname ubuf;
	 uname(&ubuf);
	 diagopts.hostname = strdup(ubuf.nodename);
      }
      break;
   default: msg(E_ERROR, "unknown diagnostic option %c", what);
   }
}

int diag_get_int(char what) {
   DIAG_INIT;
   switch (what) {
   case 'y': return diagopts.syslog;
   case 's': return diagopts.logfile == stderr;
   case 'd': case 'D': return diagopts.msglevel;
   case 'e': return diagopts.exitlevel;
   }
   return -1;
}

const char *diag_get_string(char what) {
   DIAG_INIT;
   switch (what) {
   case 'p': return diagopts.progname;
   }
   return NULL;
}

/* Linux and AIX syslog format:
Oct  4 17:10:37 hostname socat[52798]: D signal(13, 1)
*/
void msg(int level, const char *format, ...) {
#if HAVE_GETTIMEOFDAY || 1
   struct timeval now;
   int result;
   time_t nowt;
#else /* !HAVE_GETTIMEOFDAY */
   time_t now;
#endif /* !HAVE_GETTIMEOFDAY */
#define BUFLEN 512
   char buff[BUFLEN], *bufp, *syslp;
   size_t bytes;
   va_list ap;

   DIAG_INIT;
   if (level < diagopts.msglevel)  return;
   va_start(ap, format);
#if HAVE_GETTIMEOFDAY || 1
   result = gettimeofday(&now, NULL);
   if (result < 0) {
      /* invoking msg() might create endless recursion; by hand instead */
      sprintf(buff, "cannot read time:   %s["F_pid"] E %s",
	      diagopts.progname, getpid(), strerror(errno));
      _msg(LOG_ERR, buff, strstr(buff, " E "+1));
      strcpy(buff, "unknown time        ");  bytes = 20;
   } else {
      nowt = now.tv_sec;
#if HAVE_STRFTIME
      if (diagopts.micros) {
	 bytes = strftime(buff, 20, "%Y/%m/%d %H:%M:%S", localtime(&nowt));
	 bytes += sprintf(buff+19, "."F_tv_usec" ", now.tv_usec);
      } else {
	 bytes =
	    strftime(buff, 21, "%Y/%m/%d %H:%M:%S ", localtime(&nowt));
      }
#else
      strcpy(buff, ctime(&nowt));
      bytes = strlen(buff);
#endif
   }
#else /* !HAVE_GETTIMEOFDAY */
   now = time(NULL);  if (now == (time_t)-1) {
      /* invoking msg() might create endless recursion; by hand instead */
      sprintf(buff, "cannot read time:   %s["F_pid"] E %s",
	      diagopts.progname, getpid(), strerror(errno));
      _msg(LOG_ERR, buff, strstr(buff, " E "+1));
      strcpy(buff, "unknown time        ");  bytes = 20;
   } else {
#if HAVE_STRFTIME
      bytes = strftime(buff, 21, "%Y/%m/%d %H:%M:%S ", localtime(&now));
#else
      strcpy(buff, ctime(&now));
      bytes = strlen(buff);
#endif
   }
#endif /* !HAVE_GETTIMEOFDAY */
   bufp = buff + bytes;
   if (diagopts.withhostname) {
      bytes = sprintf(bufp, "%s ", diagopts.hostname), bufp+=bytes;
   }
   bytes = sprintf(bufp, "%s["F_pid"] ", diagopts.progname, getpid());
   bufp += bytes;
   syslp = bufp;
   *bufp++ = "DINWEF"[level];
   *bufp++ = ' ';
   vsnprintf(bufp, BUFLEN-(bufp-buff)-1, format, ap);
   strcat(bufp, "\n");
   _msg(level, buff, syslp);
   if (level >= diagopts.exitlevel) {
      va_end(ap);
      if (E_NOTICE >= diagopts.msglevel) {
	 sprintf(syslp, "N exit(1)\n");
	 _msg(E_NOTICE, buff, syslp);
      }
      exit(diagopts.exitstatus ? diagopts.exitstatus : 1);
   }
   va_end(ap);
}


static void _msg(int level, const char *buff, const char *syslp) {
   if (diagopts.syslog) {
      /* prevent format string attacks (thanks to CoKi) */
      syslog(syslevel[level], "%s", syslp);
   }
   if (diagopts.logfile) {
      fputs(buff, diagopts.logfile); fflush(diagopts.logfile);
   }
}


/* use a new log output file descriptor that is dup'ed from the current one.
   this is useful when socat logs to stderr but fd 2 should be redirected to
   serve other purposes */
int diag_dup(void) {
   int newfd;

   DIAG_INIT;
   if (diagopts.logfile == NULL) {
      return -1;
   }
   newfd = dup(fileno(diagopts.logfile));
   if (diagopts.logfile != stderr) {
      fclose(diagopts.logfile);
   }
   if (newfd >= 0) {
      diagopts.logfile = fdopen(newfd, "w");
   }
   return newfd;
}
