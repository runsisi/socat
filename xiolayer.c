/* $Id: xiolayer.c,v 1.7 2005/08/18 19:56:05 gerhard Exp $ */
/* Copyright Gerhard Rieger 2001-2005 */
/* Published under the GNU General Public License V.2, see file COPYING */

/* this file contains the source for common options */

#include "xiosysincludes.h"
#include "xioopen.h"

#include "xiolayer.h"

/****** for ALL addresses - by application ******/
const struct optdesc opt_ignoreeof = { "ignoreeof", NULL, OPT_IGNOREEOF, GROUP_APPL, PH_LATE, TYPE_BOOL,  OFUNC_EXT, (int)(&((struct single *)0)->ignoreeof),   sizeof(((struct single *)0)->ignoreeof) };
const struct optdesc opt_cr        = { "cr",        NULL, OPT_CR,        GROUP_APPL, PH_LATE, TYPE_CONST, OFUNC_EXT, (int)(&((struct single *)0)->lineterm),   sizeof(((struct single *)0)->lineterm), LINETERM_CR };
const struct optdesc opt_crnl      = { "crnl",      NULL, OPT_CRNL,      GROUP_APPL, PH_LATE, TYPE_CONST, OFUNC_EXT, (int)(&((struct single *)0)->lineterm),   sizeof(((struct single *)0)->lineterm), LINETERM_CRNL };
const struct optdesc opt_readbytes = { "readbytes", "bytes", OPT_READBYTES, GROUP_APPL, PH_LATE, TYPE_SIZE_T, OFUNC_EXT, (int)(&((struct single *)0)->readbytes),   sizeof(((struct single *)0)->readbytes) };
const struct optdesc opt_lockfile  = { "lockfile",  NULL, OPT_LOCKFILE,  GROUP_APPL, PH_INIT, TYPE_FILENAME, OFUNC_EXT, 0, 0 };
const struct optdesc opt_waitlock  = { "waitlock",  NULL, OPT_WAITLOCK,  GROUP_APPL, PH_INIT,  TYPE_FILENAME, OFUNC_EXT, 0, 0 };
/****** APPL addresses ******/
#if WITH_RETRY
const struct optdesc opt_forever   = { "forever",   NULL, OPT_FOREVER,   GROUP_RETRY, PH_INIT, TYPE_BOOL, OFUNC_EXT, (int)(&((struct single *)0)->forever),   sizeof(((struct single *)0)->forever) };
const struct optdesc opt_intervall = { "intervall", NULL, OPT_INTERVALL, GROUP_RETRY, PH_INIT, TYPE_TIMESPEC, OFUNC_EXT, (int)(&((struct single *)0)->intervall), sizeof(((struct single *)0)->intervall) };
const struct optdesc opt_retry     = { "retry",     NULL, OPT_RETRY,     GROUP_RETRY, PH_INIT, TYPE_UINT, OFUNC_EXT, (int)(&((struct single *)0)->retry),     sizeof(((struct single *)0)->retry) };
#endif

