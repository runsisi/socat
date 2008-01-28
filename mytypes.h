/* source: mytypes.h */
/* Copyright Gerhard Rieger 2001-2006 */
/* Published under the GNU General Public License V.2, see file COPYING */

#ifndef __mytypes_h_included
#define __mytypes_h_included 1

/* some types and macros I miss in C89 */

typedef enum { false, true } bool;

#define Min(x,y) ((x)<=(y)?(x):(y))
#define Max(x,y) ((x)>=(y)?(x):(y))

#define SOCKADDR_MAX UNIX_PATH_MAX

#endif /* __mytypes_h_included */
