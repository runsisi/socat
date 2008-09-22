/* source: xio-unix.h */
/* Copyright Gerhard Rieger 2001-2008 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __xio_unix_h_included
#define __xio_unix_h_included 1

extern const struct addrdesc addr_unix_connect;
extern const struct addrdesc addr_unix_listen;
extern const struct addrdesc addr_unix_sendto;
extern const struct addrdesc addr_unix_recvfrom;
extern const struct addrdesc addr_unix_recv;
extern const struct addrdesc addr_unix_client;
extern const struct addrdesc xioaddr_abstract_connect;
extern const struct addrdesc xioaddr_abstract_listen;
extern const struct addrdesc xioaddr_abstract_sendto;
extern const struct addrdesc xioaddr_abstract_recvfrom;
extern const struct addrdesc xioaddr_abstract_recv;
extern const struct addrdesc xioaddr_abstract_client;

extern const struct optdesc opt_unix_tightsocklen;

extern socklen_t
xiosetunix(struct sockaddr_un *saun,
	   const char *path,
	   bool abstract,
	   bool tight);
extern int
xiosetsockaddrenv_unix(int idx, char *namebuff, size_t namelen,
		       char *valuebuff, size_t valuelen,
		       struct sockaddr_un *sa, socklen_t salen, int ipproto);

#endif /* !defined(__xio_unix_h_included) */
