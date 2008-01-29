#! /bin/bash
# source: test.sh
# Copyright Gerhard Rieger 2001-2008
# Published under the GNU General Public License V.2, see file COPYING

# perform lots of tests on socat

# this script uses functions; you need a shell that supports them

# you can pass general options to socat via $OPTS

#set -vx

withroot=0	# perform privileged tests even if not run by root
#PATH=$PATH:/opt/freeware/bin
#PATH=$PATH:/usr/local/ssl/bin
#OPENSSL_RAND="-rand /dev/egd-pool"
#SOCAT_EGD="egd=/dev/egd-pool"
MISCDELAY=1
[ -z "$SOCAT" ] && SOCAT="./socat"
[ -z "$PROCAN" ] && PROCAN="./procan"
[ -z "$FILAN" ] && FILAN="./filan"
opts="-t0.1 $OPTS"
export SOCAT_OPTS="$opts"
#debug="1"
debug=
TESTS="$@"
INTERFACE=eth0;	# not used for function tests
MCINTERFACE=lo	# !!! Linux only
#LOCALHOST=192.168.58.1
#LOCALHOST=localhost
LOCALHOST=127.0.0.1
LOCALHOST6=[::1]
PROTO=$((192+RANDOM/1024))
PORT=12002
SOURCEPORT=2002
CAT=cat
OD_C="od -c"
# time in microseconds to wait in some situations
MICROS=100000
if ! type usleep >/dev/null 2>&1; then
    usleep () {
	local n="$1"
	# older bashes do not accept $1 here:
	sleep $(((n+999999)/1000000))
    }
fi
#USLEEP=usleep
F_n="%3d"	# format string for test numbers
LANG=C
LANGUAGE=C	# knoppix
UNAME=`uname`
case "$UNAME" in
HP-UX|OSF1)
    echo "$SOCAT -u stdin stdout" >cat.sh
    chmod a+x cat.sh
    CAT=./cat.sh
    ;;
*)
    CAT=cat
    ;;
esac

case "$UNAME" in
#HP-UX)
#    # on HP-UX, the default options (below) hang some tests (former 14, 15)
#    PTYOPTS=
#    PTYOPTS2=
#    ;;
*)
    PTYOPTS="echo=0,opost=0"
    PTYOPTS2="raw,echo=0"
    ;;
esac

# non-root users might miss ifconfig in their path
case "$UNAME" in
AIX)   IFCONFIG=/usr/sbin/ifconfig ;;
FreeBSD) IFCONFIG=/sbin/ifconfig ;;
HP-UX) IFCONFIG=/usr/sbin/ifconfig ;;
Linux) IFCONFIG=/sbin/ifconfig ;;
NetBSD)IFCONFIG=/sbin/ifconfig ;;
OpenBSD)IFCONFIG=/sbin/ifconfig ;;
OSF1)  IFCONFIG=/sbin/ifconfig ;;
SunOS) IFCONFIG=/sbin/ifconfig ;;
#*)     IFCONFIG=/sbin/ifconfig ;;
esac

# for some tests we need a second local IPv4 address
case "$UNAME" in
Linux)
    BROADCASTIF=eth0
    SECONDADDR=127.0.0.2
    BCADDR=127.255.255.255
    BCIFADDR=$($IFCONFIG $BROADCASTIF |grep 'inet ' |awk '{print($2);}' |cut -d: -f2) ;;
FreeBSD|NetBSD|OpenBSD)
    MAINIF=$($IFCONFIG -a |grep '^[a-z]' |head -1 |cut -d: -f1)
    BROADCASTIF="$MAINIF"
    SECONDADDR=$($IFCONFIG $BROADCASTIF |grep 'inet ' |awk '{print($2);}')
    BCIFADDR="$SECONDADDR"
    BCADDR=$($IFCONFIG $BROADCASTIF |grep 'broadcast ' |sed 's/.*broadcast/broadcast/' |awk '{print($2);}') ;;
HP-UX)
    MAINIF=lan0	# might use "netstat -ni" for this
    BROADCASTIF="$MAINIF"
    SECONDADDR=$($IFCONFIG $MAINIF |tail -n 1 |awk '{print($2);}')
    BCADDR=$($IFCONFIG $BROADCASTIF |grep 'broadcast ' |sed 's/.*broadcast/broadcast/' |awk '{print($2);}') ;;
SunOS)
    #BROADCASTIF=hme0
    BROADCASTIF=eri0
    SECONDADDR=$($IFCONFIG $BROADCASTIF |grep 'inet ' |awk '{print($2);}')
    BCIFADDR="$SECONDADDR"
    BCADDR=$($IFCONFIG $BROADCASTIF |grep 'broadcast ' |sed 's/.*broadcast/broadcast/' |awk '{print($2);}') ;;
#AIX|FreeBSD|Solaris)
*)
    SECONDADDR=$(expr "$($IFCONFIG -a |grep 'inet ' |fgrep -v ' 127.0.0.1 '| head -n 1)" : '.*inet \([0-9.]*\) .*') 
    ;;
esac

# for some tests we need a second local IPv6 address
case "$UNAME" in
*)
    SECONDIP6ADDR=$(expr "$($IFCONFIG -a |grep 'inet6 ' |fgrep -v ' ::1/128 '| head -n 1)" : '.*inet \([0-9.]*\) .*') 
    ;;
esac
if [ -z "$SECONDIP6ADDR" ]; then
    case "$TESTS" in
	*%root2%*) $IFCONFIG eth0 ::2/128
    esac
fi

TRUE=$(which true)
#E=-e	# Linux
if   [ $(echo "x\c") = "x" ]; then E=""
elif [ $(echo -e "x\c") = "x" ]; then E="-e"
else
    echo "cannot suppress trailing newline on echo" >&2
    exit 1
fi
ECHO="echo $E"
PRINTF="printf"

case "$TERM" in
vt100|vt320|linux|xterm|cons25|dtterm|aixterm|sun-color)
	# there are different behaviours of printf (and echo)
	# on some systems, echo behaves different than printf...
	if [ $($PRINTF "\0101") = "A" ]; then
		RED="\0033[31m"
		GREEN="\0033[32m"
		YELLOW="\0033[33m"
		if [ "$UNAME" = SunOS ]; then
		    NORMAL="\0033[30m"
		else
		    NORMAL="\0033[39m"
		fi
	else
		RED="\033[31m"
		GREEN="\033[32m"
		YELLOW="\033[33m"
		if [ "$UNAME" = SunOS ]; then
		    NORMAL="\033[30m"
		else
		    NORMAL="\033[39m"
		fi
	fi
	OK="${GREEN}OK${NORMAL}"
	FAILED="${RED}FAILED${NORMAL}"
	NO_RESULT="${YELLOW}NO RESULT${NORMAL}"
	;;
*)	OK="OK"
	FAILED="FAILED"
	NO_RESULT="NO RESULT"
	;;
esac


if [ -x /usr/xpg4/bin/id ]; then
    # SunOS has rather useless tools in its default path
    PATH="/usr/xpg4/bin:$PATH"
fi

[ -z "$TESTS" ] && TESTS="consistency functions filan"
# use '%' as separation char
TESTS="%$(echo "$TESTS" |tr ' ' '%')%"

[ -z "$USER" ] && USER="$LOGNAME"	# HP-UX
if [ -z "$TMPDIR" ]; then
    if [ -z "$TMP" ]; then
	TMP=/tmp
    fi
    TMPDIR="$TMP"
fi
TD="$TMPDIR/$USER/$$"; td="$TD"
rm -rf "$TD" || (echo "cannot rm $TD" >&2; exit 1)
mkdir -p "$TD"
#trap "rm -r $TD" 0 3

echo "using temp directory $TD"

case "$TESTS" in
*%consistency%*)
# test if addresses are sorted alphabetically:
$ECHO "testing if address array is sorted...\c"
TF="$TD/socat-q"
IFS="$($ECHO ' \n\t')"
$SOCAT -? |sed '1,/address-head:/ d' |egrep 'groups=' |while IFS="$IFS:" read x y; do echo "$x"; done >"$TF"
$SOCAT -? |sed '1,/address-head:/ d' |egrep 'groups=' |while IFS="$IFS:" read x y; do echo "$x"; done |LC_ALL=C sort |diff "$TF" - >"$TF-diff"
if [ -s "$TF-diff" ]; then
    $ECHO "\n*** address array is not sorted. Wrong entries:" >&2
    cat "$TD/socat-q-diff" >&2
else
    echo " ok"
fi
#/bin/rm "$TF"
#/bin/rm "$TF-diff"
esac

case "$TESTS" in
*%consistency%*)
# test if address options array ("optionnames") is sorted alphabetically:
$ECHO "testing if address options are sorted...\c"
TF="$TD/socat-qq"
$SOCAT -??? |sed '1,/opt:/ d' |egrep 'groups=' |awk '{print($1);}' >"$TF"
$SOCAT -??? |sed '1,/opt:/ d' |egrep 'groups=' |awk '{print($1);}' |LC_ALL=C sort |diff "$TF" - >"$TF-diff"
if [ -s "$TF-diff" ]; then
    $ECHO "\n*** option array is not sorted. Wrong entries:" >&2
    cat "$TD/socat-qq-diff" >&2
else
    echo " ok"
fi
/bin/rm "$TF"
/bin/rm "$TF-diff"
esac

#==============================================================================
case "$TESTS" in
*%options%*)

# inquire which options are available
OPTS_ANY=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*ANY' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_BLK=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*BLK' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_CHILD=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*CHILD' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_CHR=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*CHR' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_DEVICE=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*DEVICE' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_EXEC=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*EXEC' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_FD=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*FD' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_FIFO=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*FIFO' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_FORK=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*FORK' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_LISTEN=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*LISTEN' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_NAMED=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*NAMED' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_OPEN=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*OPEN[^S]' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_PARENT=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*PARENT' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_READLINE=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*READLINE' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_RETRY=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*RETRY' |awk '{print($1);}' |grep -v forever|xargs echo |tr ' ' ',')
OPTS_RANGE=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*RANGE' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_FILE=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*REG' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_UNIX=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*UNIX' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_SOCKET=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*SOCKET' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_TERMIOS=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*TERMIOS' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_IP4=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*IP4' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_IP6=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*IP6' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_TCP=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*TCP' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_UDP=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*UDP' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_SOCKS4=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*SOCKS4' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_PROCESS=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*PROCESS' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_OPENSSL=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*OPENSSL' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_PTY=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*PTY' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_HTTP=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*HTTP' |awk '{print($1);}' |xargs echo |tr ' ' ',')
OPTS_APPL=$($SOCAT -?? |sed '1,/opt:/ d' |egrep 'groups=([A-Z]+,)*APPL' |awk '{print($1);}' |xargs echo |tr ' ' ',')

# find user ids to setown to; non-root only can setown to itself
if [ $(id -u) = 0 ]; then
  # up to now, it is not a big problem when these do not exist
  _UID=nobody
  _GID=staff
else
  _UID=$(id -u)
  _GID=$(id -g)
fi

# some options require values; here we try to replace these bare options with
#    valid forms.
filloptionvalues() {
    local OPTS=",$1,"
    #
    case "$OPTS" in
    *,umask,*) OPTS=$(echo "$OPTS" |sed "s/,umask,/,umask=0026,/g");;
    esac
    case "$OPTS" in
    *,user,*) OPTS=$(echo "$OPTS" |sed "s/,user,/,user=$_UID,/g");;
    esac
    case "$OPTS" in
    *,user-early,*) OPTS=$(echo "$OPTS" |sed "s/,user-early,/,user-early=$_UID,/g");;
    esac
    case "$OPTS" in
    *,user-late,*) OPTS=$(echo "$OPTS" |sed "s/,user-late,/,user-late=$_UID,/g");;
    esac
    case "$OPTS" in
    *,owner,*) OPTS=$(echo "$OPTS" |sed "s/,owner,/,owner=$_UID,/g");;
    esac
    case "$OPTS" in
    *,uid,*) OPTS=$(echo "$OPTS" |sed "s/,uid,/,uid=$_UID,/g");;
    esac
    case "$OPTS" in
    *,uid-l,*) OPTS=$(echo "$OPTS" |sed "s/,uid-l,/,uid-l=$_UID,/g");;
    esac
    case "$OPTS" in
    *,setuid,*) OPTS=$(echo "$OPTS" |sed "s/,setuid,/,setuid=$_UID,/g");;
    esac
    case "$OPTS" in
    *,group,*) OPTS=$(echo "$OPTS" |sed "s/,group,/,group=$_GID,/g");;
    esac
    case "$OPTS" in
    *,group-early,*) OPTS=$(echo "$OPTS" |sed "s/,group-early,/,group-early=$_GID,/g");;
    esac
    case "$OPTS" in
    *,group-late,*) OPTS=$(echo "$OPTS" |sed "s/,group-late,/,group-late=$_GID,/g");;
    esac
    case "$OPTS" in
    *,gid,*) OPTS=$(echo "$OPTS" |sed "s/,gid,/,gid=$_GID,/g");;
    esac
    case "$OPTS" in
    *,gid-l,*) OPTS=$(echo "$OPTS" |sed "s/,gid-l,/,gid-l=$_GID,/g");;
    esac
    case "$OPTS" in
    *,setgid,*) OPTS=$(echo "$OPTS" |sed "s/,setgid,/,setgid=$_GID,/g");;
    esac
    case "$OPTS" in
    *,mode,*) OPTS=$(echo "$OPTS" |sed "s/,mode,/,mode=0700,/g");;
    esac
    case "$OPTS" in
    *,perm,*) OPTS=$(echo "$OPTS" |sed "s/,perm,/,perm=0700,/g");;
    esac
    case "$OPTS" in
    *,perm-early,*) OPTS=$(echo "$OPTS" |sed "s/,perm-early,/,perm-early=0700,/g");;
    esac
    case "$OPTS" in
    *,perm-late,*) OPTS=$(echo "$OPTS" |sed "s/,perm-late,/,perm-late=0700,/g");;
    esac
    case "$OPTS" in
    *,path,*) OPTS=$(echo "$OPTS" |sed "s/,path,/,path=.,/g");;
    esac
    # SOCKET
    case "$OPTS" in
    *,bind,*) OPTS=$(echo "$OPTS" |sed "s/,bind,/,bind=:,/g");;
    esac
    case "$OPTS" in
    *,linger,*) OPTS=$(echo "$OPTS" |sed "s/,linger,/,linger=2,/g");;
    esac
    case "$OPTS" in
    *,rcvtimeo,*) OPTS=$(echo "$OPTS" |sed "s/,rcvtimeo,/,rcvtimeo=1,/g");;
    esac
    case "$OPTS" in
    *,sndtimeo,*) OPTS=$(echo "$OPTS" |sed "s/,sndtimeo,/,sndtimeo=1,/g");;
    esac
    case "$OPTS" in
    *,connect-timeout,*) OPTS=$(echo "$OPTS" |sed "s/,connect-timeout,/,connect-timeout=1,/g");;
    esac
    # IP
    case "$OPTS" in
    *,ipoptions,*) OPTS=$(echo "$OPTS" |sed "s|,ipoptions,|,ipoptions=x01,|g");;
    esac
    case "$OPTS" in
    *,pf,*) OPTS=$(echo "$OPTS" |sed "s|,pf,|,pf=ip4,|g");;
    esac
    case "$OPTS" in
    *,range,*) OPTS=$(echo "$OPTS" |sed "s|,range,|,range=127.0.0.1/32,|g");;
    esac
    case "$OPTS" in
    *,if,*) OPTS=$(echo "$OPTS" |sed "s/,if,/,if=$INTERFACE,/g");;
    esac
    # PTY
    case "$OPTS" in
    *,pty-intervall,*) OPTS=$(echo "$OPTS" |sed "s/,pty-intervall,/,pty-intervall=$INTERFACE,/g");;
    esac
    # RETRY
    case "$OPTS" in
    *,intervall,*) OPTS=$(echo "$OPTS" |sed "s/,intervall,/,intervall=1,/g");;
    esac
    # READLINE
    case "$OPTS" in
    *,history,*) OPTS=$(echo "$OPTS" |sed "s/,history,/,history=.history,/g");;
    esac
    case "$OPTS" in
    *,noecho,*) OPTS=$(echo "$OPTS" |sed "s/,noecho,/,noecho=password,/g");;
    esac
    case "$OPTS" in
    *,prompt,*) OPTS=$(echo "$OPTS" |sed "s/,prompt,/,prompt=CMD,/g");;
    esac
    # IPAPP
    case "$OPTS" in
    *,sp,*) OPTS=$(echo "$OPTS" |sed "s/,sp,/,sp=$SOURCEPORT,/g");;
    esac
    # OPENSSL
    case "$OPTS" in
    *,ciphers,*) OPTS=$(echo "$OPTS" |sed "s/,ciphers,/,ciphers=NULL,/g");;
    esac
    case "$OPTS" in
    *,method,*) OPTS=$(echo "$OPTS" |sed "s/,method,/,method=SSLv3,/g");;
    esac
    case "$OPTS" in
    *,cafile,*) OPTS=$(echo "$OPTS" |sed "s/,cafile,/,cafile=/tmp/hugo,/g");;
    esac
    case "$OPTS" in
    *,capath,*) OPTS=$(echo "$OPTS" |sed "s/,capath,/,capath=/tmp/hugo,/g");;
    esac
    case "$OPTS" in
    *,cert,*) OPTS=$(echo "$OPTS" |sed "s/,cert,/,cert=/tmp/hugo,/g");;
    esac
    case "$OPTS" in
    *,key,*) OPTS=$(echo "$OPTS" |sed "s/,key,/,key=/tmp/hugo,/g");;
    esac
    case "$OPTS" in
    *,dh,*) OPTS=$(echo "$OPTS" |sed "s/,dh,/,dh=/tmp/hugo,/g");;
    esac
    case "$OPTS" in
    *,egd,*) OPTS=$(echo "$OPTS" |sed "s/,egd,/,egd=/tmp/hugo,/g");;
    esac
    # PROXY
    case "$OPTS" in
    *,proxyauth,*) OPTS=$(echo "$OPTS" |sed "s/,proxyauth,/,proxyauth=user:pass,/g");;
    esac
    case "$OPTS" in
    *,proxyport,*) OPTS=$(echo "$OPTS" |sed "s/,proxyport,/,proxyport=3128,/g");;
    esac
    case "$OPTS" in
    *,link,*) OPTS=$(echo "$OPTS" |sed "s/,link,/,link=testlink,/g");;
    esac
    # TCP-WRAPPERS
    case "$OPTS" in
    *,allow-table,*) OPTS=$(echo "$OPTS" |sed "s|,allow-table,|,allow-table=/tmp/hugo,|g");;
    esac
    case "$OPTS" in
    *,deny-table,*) OPTS=$(echo "$OPTS" |sed "s|,deny-table,|,deny-table=/tmp/hugo,|g");;
    esac
    case "$OPTS" in
    *,tcpwrap-dir,*) OPTS=$(echo "$OPTS" |sed "s|,tcpwrap-dir,|,tcpwrap-dir=/tmp,|g");;
    esac
    echo $OPTS >&2
    expr "$OPTS" : ',\(.*\),'
}
# OPTS_FIFO: nothing yet

# OPTS_CHR: nothing yet

# OPTS_BLK: nothing yet

# OPTS_REG: nothing yet

OPTS_SOCKET=",$OPTS_SOCKET,"
OPTS_SOCKET=$(expr "$OPTS_SOCKET" : ',\(.*\),')

N=1
#------------------------------------------------------------------------------

#method=open
#METHOD=$(echo "$method" |tr a-z A-Z)
#TEST="$METHOD on file accepts all its options"
#    echo "### $TEST"
#TF=$TD/file$N
#DA="$(date)"
#OPTGROUPS=$($SOCAT -? |fgrep " $method:" |sed 's/.*=//')
#for g in $(echo $OPTGROUPS |tr ',' ' '); do
#    eval "OPTG=\$OPTS_$(echo $g |tr a-z- A-Z_)";
#    OPTS="$OPTS,$OPTG";
#done
##echo $OPTS
#
#for o in $(filloptionvalues $OPTS|tr ',' ' '); do
#    echo testing if $METHOD accepts option $o
#    touch $TF
#    $SOCAT $opts -!!$method:$TF,$o /dev/null,ignoreof </dev/null
#    rm -f $TF
#done

#------------------------------------------------------------------------------

# test openssl connect

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
pid=$!
for addr in openssl; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
	openssl s_server -www -accept $PORT || echo "cannot start s_server" >&2 &
	pid=$!
	sleep 1
	#waittcp4port $PORT
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
#	echo $SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
	$SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
    done
	kill $pid
done
kill $pid 2>/dev/null
opts=
	PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test proxy connect

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
pid=$!
for addr in proxy; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    # prepare dummy server
    $SOCAT tcp-l:$PORT,reuseaddr,crlf exec:"/bin/bash proxyecho.sh" || echo "cannot start proxyecho.sh" >&2 &
	pid=$!
	sleep 1
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
#	echo $SOCAT $opts /dev/null $addr:$LOCALHOST:127.0.0.1:$PORT,$o
	$SOCAT $opts /dev/null $addr:$LOCALHOST:127.0.0.1:$((PORT+1)),proxyport=$PORT,$o
    done
	kill $pid 2>/dev/null
done
kill $pid 2>/dev/null
opts=
PORT=$((PORT+2))
fi

#------------------------------------------------------------------------------

# test tcp4

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
$SOCAT $opts tcp4-listen:$PORT,reuseaddr,fork,$o echo </dev/null &
pid=$!
for addr in tcp4; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
    done
done
kill $pid 2>/dev/null
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test udp4-connect

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
$SOCAT $opts udp4-listen:$PORT,fork,$o echo </dev/null &
pid=$!
for addr in udp4-connect; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
    done
done
kill $pid 2>/dev/null
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test tcp4-listen

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in tcp4-listen; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $ADDR:$PORT,reuseaddr,$o echo </dev/null &
	pid=$!
	$SOCAT /dev/null tcp4:$LOCALHOST:$PORT 2>/dev/null
	kill $pid 2>/dev/null
    done
done
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test udp4-listen

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in udp4-listen; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $ADDR:$PORT,reuseaddr,$o echo </dev/null &
	pid=$!
	$SOCAT /dev/null udp4:$LOCALHOST:$PORT 2>/dev/null
	kill $pid 2>/dev/null
    done
done
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test udp4-sendto

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
$SOCAT $opts udp4-recv:$PORT,fork,$o echo </dev/null &
pid=$!
for addr in udp4-sendto; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
    done
done
kill $pid 2>/dev/null
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test udp4-datagram

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
#$SOCAT $opts udp4-recvfrom:$PORT,fork,$o echo </dev/null &
#pid=$!
for addr in udp4-datagram; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
    done
done
#kill $pid 2>/dev/null
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test udp4-recv

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in udp4-recv; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $ADDR:$PORT,reuseaddr,$o echo </dev/null &
	pid=$!
	$SOCAT /dev/null udp4:$LOCALHOST:$PORT 2>/dev/null
	kill $pid 2>/dev/null
    done
done
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test udp4-recvfrom

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in udp4-recvfrom; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $ADDR:$PORT,reuseaddr,$o echo </dev/null &
	pid=$!
	$SOCAT /dev/null udp4:$LOCALHOST:$PORT 2>/dev/null
	kill $pid 2>/dev/null
    done
done
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test ip4-sendto

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
$SOCAT $opts ip4-recv:$PORT,fork,$o echo </dev/null &
pid=$!
for addr in ip4-sendto; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
#    echo OPTGROUPS=$OPTGROUPS
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts /dev/null $addr:$LOCALHOST:$PORT,$o
    done
done
kill $pid 2>/dev/null
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test ip4-recv

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in ip4-recv; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $ADDR:$PORT,reuseaddr,$o echo </dev/null &
	pid=$!
	$SOCAT /dev/null ip4-sendto:$LOCALHOST:$PORT 2>/dev/null
	kill $pid 2>/dev/null
    done
done
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test ip4-recvfrom

#set -vx
if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in ip4-recvfrom; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $ADDR:$PORT,reuseaddr,$o echo </dev/null &
	pid=$!
	$SOCAT /dev/null ip4-sendto:$LOCALHOST:$PORT 2>/dev/null
	kill $pid 2>/dev/null
    done
done
opts=
PORT=$((PORT+1))
fi

#------------------------------------------------------------------------------

# test READLINE

if true; then
#if false; then
#opts="-s -d -d -d -d"
for addr in readline; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    TS=$TD/script$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr	" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
#    for o in bs0; do
	echo "testing if $ADDR accepts option $o"
	echo "$SOCAT $opts readline,$o /dev/null" >$TS
	chmod u+x $TS
	$SOCAT /dev/null,ignoreeof exec:$TS,pty
	#stty sane
    done
    #reset 1>&0 2>&0
done
opts=
fi

#------------------------------------------------------------------------------

# unnamed pipe
#if false; then
if true; then
for addr in pipe; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="unnamed $ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |egrep " $addr[^:]" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS

    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if unnamed $ADDR accepts option $o
	$SOCAT $opts $addr,$o /dev/null </dev/null
    done
done
fi

#------------------------------------------------------------------------------

# test addresses on files

N=1
#if false; then
if true; then
for addr in create; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR on new file accepts all its options"
    echo "### $TEST"
    TF=$TD/file$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS

    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR accepts option $o
	rm -f $TF
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
	rm -f $TF
    done
done
fi
#------------------------------------------------------------------------------

#if false; then
if true; then
for addr in exec system; do
    ADDR=$(echo "$addr" |tr a-z A-Z)

    TEST="$ADDR with socketpair accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,FIFO,/,/g' -e 's/,TERMIOS,/,/g' -e 's/,PTY,/,/g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    OPTS=$(echo $OPTS|sed -e 's/,pipes,/,/g' -e 's/,pty,/,/g' -e 's/,openpty,/,/g' -e 's/,ptmx,/,/g' -e 's/,nofork,/,/g')
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR with socketpair accepts option $o
	$SOCAT $opts $addr:$TRUE,$o /dev/null,ignoreof </dev/null
    done

    TEST="$ADDR with pipes accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,TERMIOS,/,/g' -e 's/,PTY,/,/g' -e 's/,SOCKET,/,/g' -e 's/,UNIX//g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    # flock tends to hang, so dont test it
    OPTS=$(echo $OPTS|sed -e 's/,pipes,/,/g' -e 's/,pty,/,/g' -e 's/,openpty,/,/g' -e 's/,ptmx,/,/g' -e 's/,nofork,/,/g' -e 's/,flock,/,/g')
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR with pipes accepts option $o
	$SOCAT $opts $addr:$TRUE,pipes,$o /dev/null,ignoreof </dev/null
    done

    TEST="$ADDR with pty accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,FIFO,/,/g' -e 's/,SOCKET,/,/g' -e 's/,UNIX//g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    OPTS=$(echo $OPTS|sed -e 's/,pipes,/,/g' -e 's/,pty,/,/g' -e 's/,openpty,/,/g' -e 's/,ptmx,/,/g' -e 's/,nofork,/,/g')
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR with pty accepts option $o
	$SOCAT $opts $addr:$TRUE,pty,$o /dev/null,ignoreof </dev/null
    done

    TEST="$ADDR with nofork accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,FIFO,/,/g' -e 's/,PTY,/,/g' -e 's/,TERMIOS,/,/g' -e 's/,SOCKET,/,/g' -e 's/,UNIX//g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    OPTS=$(echo $OPTS|sed -e 's/,pipes,/,/g' -e 's/,pty,/,/g' -e 's/,openpty,/,/g' -e 's/,ptmx,/,/g' -e 's/,nofork,/,/g')
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR with nofork accepts option $o
	$SOCAT /dev/null $opts $addr:$TRUE,nofork,$o </dev/null
    done

done
fi

#------------------------------------------------------------------------------

#if false; then
if true; then
for addr in fd; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    TF=$TD/file$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR (to file) accepts option $o"
	rm -f $TF
	$SOCAT $opts -u /dev/null $addr:3,$o 3>$TF
    done
done
fi

#------------------------------------------------------------------------------

# test OPEN address

#! test it on pipe, device, new file

N=1
#if false; then
if true; then
for addr in open; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR on file accepts all its options"
    echo "### $TEST"
    TF=$TD/file$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on file accepts option $o
	touch $TF
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
	rm -f $TF
    done
done
fi

#------------------------------------------------------------------------------

# test GOPEN address on files, sockets, pipes, devices

N=1
#if false; then
if true; then
for addr in gopen; do
    ADDR=$(echo "$addr" |tr a-z A-Z)

    TEST="$ADDR on new file accepts all its options"
    echo "### $TEST"
    TF=$TD/file$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,SOCKET,/,/g' -e 's/,UNIX//g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on new file accepts option $o
	rm -f $TF
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
	rm -f $TF
    done

    TEST="$ADDR on existing file accepts all its options"
    echo "### $TEST"
    TF=$TD/file$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,SOCKET,/,/g' -e 's/,UNIX//g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on existing file accepts option $o
	rm -f $TF; touch $TF
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
	rm -f $TF
    done

    TEST="$ADDR on existing pipe accepts all its options"
    echo "### $TEST"
    TF=$TD/pipe$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,REG,/,/g' -e 's/,SOCKET,/,/g' -e 's/,UNIX//g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on named pipe accepts option $o
	rm -f $TF; mkfifo $TF
	$SOCAT $opts $addr:$TF,$o,nonblock /dev/null </dev/null
	rm -f $TF
    done

    TEST="$ADDR on existing socket accepts all its options"
    echo "### $TEST"
    TF=$TD/sock$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,REG,/,/g' -e 's/,OPEN,/,/g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on socket accepts option $o
	rm -f $TF; $SOCAT - UNIX-L:$TF & pid=$!
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
	kill $pid 2>/dev/null
	rm -f $TF
    done

  if [ $(id -u) -eq 0 ]; then
    TEST="$ADDR on existing device accepts all its options"
    echo "### $TEST"
    TF=$TD/null
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,REG,/,/g' -e 's/,OPEN,/,/g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on existing device accepts option $o
	rm -f $TF; mknod $TF c 1 3
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
    done
  else
    TEST="$ADDR on existing device accepts all its options"
    echo "### $TEST"
    TF=/dev/null
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTGROUPS=$(echo $OPTGROUPS |sed -e 's/,REG,/,/g' -e 's/,OPEN,/,/g')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if $ADDR on existing device accepts option $o
	$SOCAT $opts -!!$addr:$TF,$o /dev/null,ignoreof </dev/null
    done
  fi

done
fi

#------------------------------------------------------------------------------

# test named pipe

N=1
#if false; then
if true; then
for addr in pipe; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR on file accepts all its options"
    echo "### $TEST"
    TF=$TD/pipe$N
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS

    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo testing if named $ADDR accepts option $o
	rm -f $TF
	# blocks with rdonly, wronly
	case "$o" in rdonly|wronly) o="$o,nonblock" ;; esac
	$SOCAT $opts $addr:$TF,$o /dev/null </dev/null
	rm -f $TF
    done
done
fi
#------------------------------------------------------------------------------

# test STDIO

#! test different stream types

#if false; then
if true; then
for addr in stdio; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS

    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR (/dev/null, stdout) accepts option $o"
	$SOCAT $opts $addr,$o /dev/null,ignoreof </dev/null
    done
done
fi

#------------------------------------------------------------------------------

# test STDIN

#if false; then
if true; then
for addr in stdin; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr	" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS

    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR (/dev/null) accepts option $o"
	$SOCAT $opts -u $addr,$o /dev/null </dev/null
    done
done
fi

#------------------------------------------------------------------------------

# test STDOUT, STDERR

if true; then
#if false; then
for addr in stdout stderr; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr	" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts -u /dev/null $addr,$o
    done
done
fi

#------------------------------------------------------------------------------
# REQUIRES ROOT

if [ "$withroot" ]; then
for addr in ip4; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $addr:127.0.0.1:200 /dev/null,ignoreof </dev/null
    done
done
fi

#------------------------------------------------------------------------------
# REQUIRES ROOT

if [ "$withroot" ]; then
for addr in ip6; do
    ADDR=$(echo "$addr" |tr a-z A-Z)
    TEST="$ADDR accepts all its options"
    echo "### $TEST"
    OPTGROUPS=$($SOCAT -? |fgrep " $addr:" |sed 's/.*=//')
    OPTS=
    for g in $(echo $OPTGROUPS |tr ',' ' '); do
	eval "OPTG=\$OPTS_$(echo $g |tr a-z A-Z)";
	OPTS="$OPTS,$OPTG";
    done
    #echo $OPTS
    for o in $(filloptionvalues $OPTS|tr ',' ' '); do
	echo "testing if $ADDR accepts option $o"
	$SOCAT $opts $addr:[::1]:200 /dev/null,ignoreof </dev/null
    done
done
fi

#==============================================================================

#TEST="stdio accepts all options of GROUP_ANY"
#echo "### $TEST"
#CMD="$SOCAT $opts -,$OPTS_ANY /dev/null"
#$CMD
#if [ $? = 0 ]; then
#    echo "... test $N ($TEST) succeeded"
##    echo "CMD=$CMD"
#else
#    echo "*** test $N ($TEST) FAILED"
#    echo "CMD=$CMD"
#fi
#
#N=$((N+1))
##------------------------------------------------------------------------------
#
#TEST="exec accepts all options of GROUP_ANY and GROUP_SOCKET"
#echo "### $TEST"
#CMD="$SOCAT $opts exec:$TRUE,$OPTS_ANY,$OPTS_SOCKET /dev/null"
#$CMD
#if [ $? = 0 ]; then
#    echo "... test $N ($TEST) succeeded"
##    echo "CMD=$CMD"
#else
#    echo "*** test $N ($TEST) FAILED"
#    echo "CMD=$CMD"
#fi

#------------------------------------------------------------------------------

esac

#==============================================================================

N=1
numOK=0
numFAIL=0
numCANT=0

#==============================================================================
# test if selected socat features work ("FUNCTIONS")

testecho () {
    local num="$1"
    local title="$2"
    local arg1="$3";	[ -z "$arg1" ] && arg1="-"
    local arg2="$4";	[ -z "$arg2" ] && arg2="echo"
    local opts="$5"
    local T="$6";	[ -z "$T" ] && T=0
    local tf="$td/test$N.stdout"
    local te="$td/test$N.stderr"
    local tdiff="$td/test$N.diff"
    local da="$(date)"
    #local cmd="$SOCAT $opts $arg1 $arg2"
    #$ECHO "testing $title (test $num)... \c"
    $PRINTF "test $F_n %s... " $num "$title"
    #echo "$da" |$cmd >"$tf" 2>"$te"
    (echo "$da"; sleep $T) |($SOCAT $opts "$arg1" "$arg2" >"$tf" 2>"$te"; echo $? >"$td/test$N.rc") &
    export rc1=$!
    #sleep 5 && kill $rc1 2>/dev/null &
#    rc2=$!
    wait $rc1
#    kill $rc2 2>/dev/null
    if [ "$(cat "$td/test$N.rc")" != 0 ]; then
	$PRINTF "$FAILED: $SOCAT:\n"
	echo "$SOCAT $opts $arg1 $arg2"
	cat "$te"
	numFAIL=$((numFAIL+1))
    elif echo "$da" |diff - "$tf" >"$tdiff" 2>&1; then
	$PRINTF "$OK\n"
	if [ -n "$debug" ]; then cat $te; fi
	numOK=$((numOK+1))
    else
	$PRINTF "$FAILED:\n"
	echo "$SOCAT $opts $arg1 $arg2"
	cat "$te"
	echo diff:
	cat "$tdiff"
	numFAIL=$((numFAIL+1))
    fi
}

# test if call to od and throughput of data works - with graceful shutdown and
# flush of od buffers
testod () {
    local num="$1"
    local title="$2"
    local arg1="$3";	[ -z "$arg1" ] && arg1="-"
    local arg2="$4";	[ -z "$arg2" ] && arg2="echo"
    local opts="$5"
    local T="$6";	[ -z "$T" ] && T=0
    local tf="$td/test$N.stdout"
    local te="$td/test$N.stderr"
    local tdiff="$td/test$N.diff"
    local dain="$(date)"
    local daout="$(echo "$dain" |$OD_C)"
    $PRINTF "test $F_n %s... " $num "$title"
    (echo "$dain"; sleep $T) |$SOCAT $opts "$arg1" "$arg2" >"$tf" 2>"$te"
    if [ "$?" != 0 ]; then
	$PRINTF "$FAILED: $SOCAT:\n"
	echo "$SOCAT $opts $arg1 $arg2"
	cat "$te"
	numFAIL=$((numFAIL+1))
    elif echo "$daout" |diff - "$tf" >"$tdiff" 2>&1; then
	$PRINTF "$OK\n"
	if [ -n "$debug" ]; then cat $te; fi
	numOK=$((numOK+1))
    else
	$PRINTF "$FAILED: diff:\n"
	echo "$SOCAT $opts $arg1 $arg2"
	cat "$te"
	cat "$tdiff"
	numFAIL=$((numFAIL+1))
    fi
}

# test if the socat executable has these address types compiled in
# print the first missing address type
testaddrs () {
    local a A;
    for a in $@; do
	A=$(echo "$a" |tr 'a-z-' 'A-Z_')
	if $SOCAT -V |grep "#define WITH_$A 1\$" >/dev/null; then
	    shift
	    continue
	fi
	echo "$a"
	return 1
    done
    return 0
}

# test if the socat executable has these options compiled in
# print the first missing option
testoptions () {
    local a A;
    for a in $@; do
	A=$(echo "$a" |tr 'a-z' 'A-Z')
	if $SOCAT -??? |grep "[^a-z0-9-]$a[^a-z0-9-]" >/dev/null; then
	    shift
	    continue
	fi
	echo "$a"
	return 1
    done
    return 0
}

unset HAVENOT_IP4
# check if an IP4 loopback interface exists
runsip4 () {
    [ -n "$HAVENOT_IP4" ] && return $HAVENOT_IP4
    local l
    case "$UNAME" in
    AIX)   l=$($IFCONFIG lo0 |fgrep 'inet 127.0.0.1 ') ;;
    FreeBSD) l=$($IFCONFIG lo0 |fgrep 'inet 127.0.0.1 ') ;;
    HP-UX) l=$($IFCONFIG lo0 |fgrep 'inet 127.0.0.1 ') ;;
    Linux) l=$($IFCONFIG |fgrep 'inet addr:127.0.0.1 ') ;;
    NetBSD)l=$($IFCONFIG -a |fgrep 'inet 127.0.0.1 ');;
    OpenBSD)l=$($IFCONFIG -a |fgrep 'inet 127.0.0.1 ');;
    OSF1)  l=$($IFCONFIG -a |grep ' inet ') ;;
    SunOS) l=$($IFCONFIG -a |grep 'inet ') ;;
#    *)     l=$($IFCONFIG -a |grep ' ::1[^:0-9A-Fa-f]') ;;
    esac
    [ -z "$l" ] && return 1    
    # existence of interface might not suffice, check for routeability:
    case "$UNAME" in
    Darwin) ping -c 1 127.0.0.1; l="$?" ;;
    Linux)  ping -c 1 127.0.0.1; l="$?" ;;
    *) if [ -n "$l" ]; then l=0; else l=1; fi ;;
    esac
    HAVENOT_IP4=$l
    return $l;
}

unset HAVENOT_IP6
# check if an IP6 loopback interface exists
runsip6 () {
    [ -n "$HAVENOT_IP6" ] && return $HAVENOT_IP6
    local l
    case "$UNAME" in
    AIX)   l=$(/usr/sbin/ifconfig lo0 |grep 'inet6 ::1/0') ;;
    HP-UX) l=$(/usr/sbin/ifconfig lo0 |grep ' inet6 ') ;;
    Linux) l=$(/sbin/ifconfig |grep 'inet6 addr: ::1/') ;;
    NetBSD)l=$(/sbin/ifconfig -a |grep 'inet6 ::1 ');;
    OSF1)  l=$(/sbin/ifconfig -a |grep ' inet6 ') ;;
    SunOS) l=$(/sbin/ifconfig -a |grep 'inet6 ') ;;
    *)     l=$(/sbin/ifconfig -a |grep ' ::1[^:0-9A-Fa-f]') ;;
    esac
    [ -z "$l" ] && return 1    
    # existence of interface might not suffice, check for routeability:
    case "$UNAME" in
    Darwin) ping -c 1 ::1; l="$?" ;;
    Linux)  ping6 -c 1 ::1; l="$?" ;;
    *) if [ -n "$l" ]; then l=0; else l=1; fi ;;
    esac
    HAVENOT_IP6=$l
    return $l;
}

# wait until an IP4 protocol is ready
waitip4proto () {
    local proto="$1"
    local logic="$2"	# 0..wait until free; 1..wait until listening
    local timeout="$3"
    local l
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	case "$UNAME" in
	Linux)   l=$(netstat -n -w -l |grep '^raw .* .*[0-9*]:'$proto' [ ]*0\.0\.0\.0:\*') ;;
#	FreeBSD) l=$(netstat -an |grep '^raw4[6 ] .*[0-9*]\.'$proto' .* \*\.\*') ;;
#	NetBSD)  l=$(netstat -an |grep '^raw .*[0-9*]\.'$proto' [ ]* \*\.\*') ;;
#	OpenBSD) l=$(netstat -an |grep '^raw .*[0-9*]\.'$proto' [ ]* \*\.\*') ;;
#	Darwin) case "$(uname -r)" in
#		[1-5]*) l=$(netstat -an |grep '^raw.* .*[0-9*]\.'$proto' .* \*\.\*') ;;
#		*) l=$(netstat -an |grep '^raw4.* .*[0-9*]\.'$proto' .* \*\.\* .*') ;;
#		esac ;;
	AIX)	 # does not seem to show raw sockets in netstat
		 sleep 1;  return 0 ;;
#	SunOS)   l=$(netstat -an -f inet -P raw |grep '.*[1-9*]\.'$proto' [ ]*Idle') ;;
#	HP-UX)   l=$(netstat -an |grep '^raw        0      0  .*[0-9*]\.'$proto' .* \*\.\* ') ;;
#	OSF1)    l=$(/usr/sbin/netstat -an |grep '^raw        0      0  .*[0-9*]\.'$proto' [ ]*\*\.\*') ;;
 	*)       #l=$(netstat -an |grep -i 'raw .*[0-9*][:.]'$proto' ') ;;
		 sleep 1;  return 0 ;;
	esac
	[ \( \( $logic -ne 0 \) -a -n "$l" \) -o \
	  \( \( $logic -eq 0 \) -a -z "$l" \) ] && return 0
	sleep 1
	timeout=$((timeout-1))
    done

    $ECHO "!protocol $proto timed out! \c" >&2
    return 1
}

# we need this misleading function name for canonical reasons
waitip4port () {
    waitip4proto "$1" "$2" "$3"
}

# wait until an IP6 protocol is ready
waitip6proto () {
    local proto="$1"
    local logic="$2"	# 0..wait until free; 1..wait until listening
    local timeout="$3"
    local l
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	case "$UNAME" in
	Linux)   l=$(netstat -n -w -l |grep '^raw .* .*:[0-9*]*:'$proto' [ ]*:::\*') ;;
#	FreeBSD) l=$(netstat -an |grep '^raw4[6 ] .*[0-9*]\.'$proto' .* \*\.\*') ;;
#	NetBSD)  l=$(netstat -an |grep '^raw .*[0-9*]\.'$proto' [ ]* \*\.\*') ;;
#	OpenBSD) l=$(netstat -an |grep '^raw .*[0-9*]\.'$proto' [ ]* \*\.\*') ;;
#	Darwin) case "$(uname -r)" in
#		[1-5]*) l=$(netstat -an |grep '^raw.* .*[0-9*]\.'$proto' .* \*\.\*') ;;
#		*) l=$(netstat -an |grep '^raw4.* .*[0-9*]\.'$proto' .* \*\.\* .*') ;;
#		esac ;;
	AIX)	 # does not seem to show raw sockets in netstat
		 sleep 1;  return 0 ;;
#	SunOS)   l=$(netstat -an -f inet -P raw |grep '.*[1-9*]\.'$proto' [ ]*Idle') ;;
#	HP-UX)   l=$(netstat -an |grep '^raw        0      0  .*[0-9*]\.'$proto' .* \*\.\* ') ;;
#	OSF1)    l=$(/usr/sbin/netstat -an |grep '^raw        0      0  .*[0-9*]\.'$proto' [ ]*\*\.\*') ;;
 	*)       #l=$(netstat -an |grep -i 'raw .*[0-9*][:.]'$proto' ') ;;
		 sleep 1;  return 0 ;;
	esac
	[ \( \( $logic -ne 0 \) -a -n "$l" \) -o \
	  \( \( $logic -eq 0 \) -a -z "$l" \) ] && return 0
	sleep 1
	timeout=$((timeout-1))
    done

    $ECHO "!protocol $proto timed out! \c" >&2
    return 1
}

# we need this misleading function name for canonical reasons
waitip6port () {
    waitip6proto "$1" "$2" "$3"
}

# wait until a TCP4 listen port is ready
waittcp4port () {
    local port="$1"
    local logic="$2"	# 0..wait until free; 1..wait until listening
    local timeout="$3"
    local l
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	case "$UNAME" in
	Linux)   l=$(netstat -n -t -l |grep '^tcp .* .*[0-9*]:'$port' .* LISTEN') ;;
	FreeBSD) l=$(netstat -an |grep '^tcp4.* .*[0-9*]\.'$port' .* \*\.\* .* LISTEN') ;;
	NetBSD)  l=$(netstat -an |grep '^tcp .* .*[0-9*]\.'$port' [ ]* \*\.\* [ ]* LISTEN.*') ;;
	Darwin) case "$(uname -r)" in
		[1-5]*) l=$(netstat -an |grep '^tcp.* .*[0-9*]\.'$port' .* \*\.\* .* LISTEN') ;;
		*) l=$(netstat -an |grep '^tcp4.* .*[0-9*]\.'$port' .* \*\.\* .* LISTEN') ;;
		esac ;;
	AIX)	 l=$(netstat -an |grep '^tcp[^6]       0      0 .*[*0-9]\.'$port' .* LISTEN$') ;;
	SunOS)   l=$(netstat -an -f inet -P tcp |grep '.*[1-9*]\.'$port' .*\*                0 .* LISTEN') ;;
	HP-UX)   l=$(netstat -an |grep '^tcp        0      0  .*[0-9*]\.'$port' .* LISTEN$') ;;
	OSF1)    l=$(/usr/sbin/netstat -an |grep '^tcp        0      0  .*[0-9*]\.'$port' [ ]*\*\.\* [ ]*LISTEN') ;;
	CYGWIN*) l=$(netstat -an -p TCP |grep '^  TCP    [0-9.]*:'$port' .* LISTENING') ;;
 	*)       l=$(netstat -an |grep -i 'tcp .*[0-9*][:.]'$port' .* listen') ;;
	esac
	[ \( \( $logic -ne 0 \) -a -n "$l" \) -o \
	  \( \( $logic -eq 0 \) -a -z "$l" \) ] && return 0
	sleep 1
	timeout=$((timeout-1))
    done

    $ECHO "!port $port timed out! \c" >&2
    return 1
}

# wait until a UDP4 port is ready
waitudp4port () {
    local port="$1"
    local logic="$2"	# 0..wait until free; 1..wait until listening
    local timeout="$3"
    local l
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	case "$UNAME" in
	Linux)   l=$(netstat -n -u -l |grep '^udp .* .*[0-9*]:'$port' [ ]*0\.0\.0\.0:\*') ;;
	FreeBSD) l=$(netstat -an |grep '^udp4[6 ] .*[0-9*]\.'$port' .* \*\.\*') ;;
	NetBSD)  l=$(netstat -an |grep '^udp .*[0-9*]\.'$port' [ ]* \*\.\*') ;;
	OpenBSD) l=$(netstat -an |grep '^udp .*[0-9*]\.'$port' [ ]* \*\.\*') ;;
	Darwin) case "$(uname -r)" in
		[1-5]*) l=$(netstat -an |grep '^udp.* .*[0-9*]\.'$port' .* \*\.\*') ;;
		*) l=$(netstat -an |grep '^udp4.* .*[0-9*]\.'$port' .* \*\.\* .*') ;;
		esac ;;
	AIX)	 l=$(netstat -an |grep '^udp[4 ]       0      0 .*[*0-9]\.'$port' .* \*\.\*[ ]*$') ;;
	SunOS)   l=$(netstat -an -f inet -P udp |grep '.*[1-9*]\.'$port' [ ]*Idle') ;;
	HP-UX)   l=$(netstat -an |grep '^udp        0      0  .*[0-9*]\.'$port' .* \*\.\* ') ;;
	OSF1)    l=$(/usr/sbin/netstat -an |grep '^udp        0      0  .*[0-9*]\.'$port' [ ]*\*\.\*') ;;
 	*)       l=$(netstat -an |grep -i 'udp .*[0-9*][:.]'$port' ') ;;
	esac
	[ \( \( $logic -ne 0 \) -a -n "$l" \) -o \
	  \( \( $logic -eq 0 \) -a -z "$l" \) ] && return 0
	sleep 1
	timeout=$((timeout-1))
    done

    $ECHO "!port $port timed out! \c" >&2
    return 1
}

# wait until a tcp6 listen port is ready
waittcp6port () {
    local port="$1"
    local logic="$2"	# 0..wait until free; 1..wait until listening
    local timeout="$3"
    local l
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	case "$UNAME" in
	Linux)   l=$(netstat -an |grep '^tcp[6 ] .* [0-9a-f:]*:'$port' .* LISTEN') ;;
	FreeBSD) l=$(netstat -an |grep -i 'tcp[46][6 ] .*[0-9*][:.]'$port' .* listen') ;;
	NetBSD)  l=$(netstat -an |grep '^tcp6 .*[0-9*]\.'$port' [ ]* \*\.\*') ;;
	OpenBSD) l=$(netstat -an |grep -i 'tcp6 .*[0-9*][:.]'$port' .* listen') ;;
	AIX)	 l=$(netstat -an |grep '^tcp[6 ]       0      0 .*[*0-9]\.'$port' .* LISTEN$') ;;
	SunOS)   l=$(netstat -an -f inet6 -P tcp |grep '.*[1-9*]\.'$port' .*\* [ ]* 0 .* LISTEN') ;;
	#OSF1)    l=$(/usr/sbin/netstat -an |grep '^tcp6       0      0  .*[0-9*]\.'$port' [ ]*\*\.\* [ ]*LISTEN') /*?*/;;
 	*)       l=$(netstat -an |grep -i 'tcp6 .*:'$port' .* listen') ;;
	esac
	[ \( \( $logic -ne 0 \) -a -n "$l" \) -o \
	  \( \( $logic -eq 0 \) -a -z "$l" \) ] && return 0
	sleep 1
	timeout=$((timeout-1))
    done

    $ECHO "!port $port timed out! \c" >&2
    return 1
}

# wait until a UDP6 port is ready
waitudp6port () {
    local port="$1"
    local logic="$2"	# 0..wait until free; 1..wait until listening
    local timeout="$3"
    local l
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	case "$UNAME" in
	Linux)   l=$(netstat -an |grep '^udp[6 ] .* .*[0-9*:]:'$port' [ ]*:::\*') ;;
	FreeBSD) l=$(netstat -an |egrep '^udp(6|46) .*[0-9*]\.'$port' .* \*\.\*') ;;
	NetBSD)  l=$(netstat -an |grep '^udp6 .* \*\.'$port' [ ]* \*\.\*') ;;
    	OpenBSD) l=$(netstat -an |grep '^udp6 .*[0-9*]\.'$port' [ ]* \*\.\*') ;;
	#Darwin)  l=$(netstat -an |grep '^udp6.* .*[0-9*]\.'$port' .* \*\.\* ') ;;
	AIX)	 l=$(netstat -an |grep '^udp[6 ]       0      0 .*[*0-9]\.'$port' .* \*\.\*[ ]*$') ;;
	SunOS)   l=$(netstat -an -f inet6 -P udp |grep '.*[1-9*]\.'$port' [ ]*Idle') ;;
	#HP-UX)   l=$(netstat -an |grep '^udp        0      0  .*[0-9*]\.'$port' ') ;;
	#OSF1)    l=$(/usr/sbin/netstat -an |grep '^udp6       0      0  .*[0-9*]\.'$port' [ ]*\*\.\*') ;;
 	*)       l=$(netstat -an |grep -i 'udp .*[0-9*][:.]'$port' ') ;;
	esac
	[ \( \( $logic -ne 0 \) -a -n "$l" \) -o \
	  \( \( $logic -eq 0 \) -a -z "$l" \) ] && return 0
	sleep 1
	timeout=$((timeout-1))
    done

    $ECHO "!port $port timed out! \c" >&2
    return 1
}

# wait until a filesystem entry exists
waitfile () {
    local crit=-e
    case "X$1" in X-*) crit="$1"; shift ;; esac
    local file="$1"
    local logic="$2"	# 0..wait until gone; 1..wait until exists (default)
    local timeout="$3"
    [ "$logic" ] || logic=1
    [ "$timeout" ] || timeout=5
    while [ $timeout -gt 0 ]; do
	if [ \( \( $logic -ne 0 \) -a $crit "$file" \) -o \
	    \( \( $logic -eq 0 \) -a ! $crit "$file" \) ]; then
	    return 0
	fi
	sleep 1
	timeout=$((timeout-1))
    done

    echo "file $file timed out" >&2
    return 1
}

# generate a test certificate and key
gentestcert () {
    local name="$1"
    if [ -f $name.key -a -f $name.crt -a -f $name.pem ]; then return; fi
    openssl genrsa $OPENSSL_RAND -out $name.key 768 >/dev/null 2>&1
    openssl req -new -config testcert.conf -key $name.key -x509 -out $name.crt -days 3653 >/dev/null 2>&1
    cat $name.key $name.crt >$name.pem
}

# generate a test DSA key and certificate
gentestdsacert () {
    local name="$1"
    if [ -f $name.key -a -f $name.crt -a -f $name.pem ]; then return; fi
    openssl dsaparam -out $name-dsa.pem 512 >/dev/null 2>&1
    openssl dhparam -dsaparam -out $name-dh.pem 512 >/dev/null 2>&1
    openssl req -newkey dsa:$name-dsa.pem -keyout $name.key -nodes -x509 -config testcert.conf -out $name.crt -days 3653 >/dev/null 2>&1
    cat $name-dsa.pem $name-dh.pem $name.key $name.crt >$name.pem
}


NAME=UNISTDIO
case "$TESTS " in
*%functions%*|*%stdio%*|*%$NAME%*)
TEST="$NAME: unidirectional throughput from stdin to stdout"
testecho "$N" "$TEST" "stdin" "stdout" "$opts -u"
esac
N=$((N+1))


NAME=UNPIPESTDIO
case "$TESTS" in
*%functions%*|*%stdio%*|*%$NAME%*)
TEST="$NAME: stdio with simple echo via internal pipe"
testecho "$N" "$TEST" "stdio" "pipe" "$opts"
esac
N=$((N+1))


NAME=UNPIPESHORT
case "$TESTS" in
*%functions%*|*%stdio%*|*%$NAME%*)
TEST="$NAME: short form of stdio ('-') with simple echo via internal pipe"
testecho "$N" "$TEST" "-" "pipe" "$opts"
esac
N=$((N+1))


NAME=DUALSTDIO
case "$TESTS" in
*%functions%*|*%stdio%*|*%$NAME%*)
TEST="$NAME: splitted form of stdio ('stdin!!stdout') with simple echo via internal pipe"
testecho "$N" "$TEST" "stdin!!stdout" "pipe" "$opts"
esac
N=$((N+1))


NAME=DUALSHORTSTDIO
case "$TESTS" in
*%functions%*|*%stdio%*|*%$NAME%*)
TEST="$NAME: short splitted form of stdio ('-!!-') with simple echo via internal pipe"
testecho "$N" "$TEST" "-!!-" "pipe" "$opts"
esac
N=$((N+1))


NAME=DUALFDS
case "$TESTS" in
*%functions%*|*%fd%*|*%$NAME%*)
TEST="$NAME: file descriptors with simple echo via internal pipe"
testecho "$N" "$TEST" "0!!1" "pipe" "$opts"
esac
N=$((N+1))


NAME=NAMEDPIPE
case "$TESTS" in
*%functions%*|*%pipe%*|*%$NAME%*)
TEST="$NAME: simple echo via named pipe"
# with MacOS, this test hangs if nonblock is not used. Is an OS bug.
tp="$td/pipe$N"
# note: the nonblock is required by MacOS 10.1(?), otherwise it hangs (OS bug?)
testecho "$N" "$TEST" "" "pipe:$tp,nonblock" "$opts"
esac
N=$((N+1))


NAME=DUALPIPE
case "$TESTS" in
*%functions%*|*%pipe%*|*%$NAME%*)
TEST="$NAME: simple echo via named pipe, specified twice"
tp="$td/pipe$N"
testecho "$N" "$TEST" "" "pipe:$tp,nonblock!!pipe:$tp" "$opts"
esac
N=$((N+1))


NAME=FILE
case "$TESTS" in
*%functions%*|*%file%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: simple echo via file"
tf="$td/file$N"
testecho "$N" "$TEST" "" "$tf,ignoreeof!!$tf" "$opts"
esac
N=$((N+1))


NAME=EXECSOCKET
case "$TESTS" in
*%functions%*|*%exec%*|*%$NAME%*)
TEST="$NAME: simple echo via exec of cat with socketpair"
testecho "$N" "$TEST" "" "exec:$CAT" "$opts"
esac
N=$((N+1))


NAME=SYSTEMSOCKET
case "$TESTS" in
*%functions%*|*%system%*|*%$NAME%*)
TEST="$NAME: simple echo via system() of cat with socketpair"
testecho "$N" "$TEST" "" "system:$CAT" "$opts"
esac
N=$((N+1))


NAME=EXECPIPES
case "$TESTS" in
*%functions%*|*%pipe%*|*%$NAME%*)
TEST="$NAME: simple echo via exec of cat with pipes"
testecho "$N" "$TEST" "" "exec:$CAT,pipes" "$opts"
esac
N=$((N+1))


NAME=SYSTEMPIPES
case "$TESTS" in
*%functions%*|*%pipes%*|*%$NAME%*)
TEST="$NAME: simple echo via system() of cat with pipes"
testecho "$N" "$TEST" "" "system:$CAT,pipes" "$opts"
esac
N=$((N+1))


NAME=EXECPTY
case "$TESTS" in
*%functions%*|*%exec%*|*%pty%*|*%$NAME%*)
TEST="$NAME: simple echo via exec of cat with pseudo terminal"
if ! testaddrs pty >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testecho "$N" "$TEST" "" "exec:$CAT,pty,$PTYOPTS" "$opts"
fi
esac
N=$((N+1))


NAME=SYSTEMPTY
case "$TESTS" in
*%functions%*|*%system%*|*%pty%*|*%$NAME%*)
TEST="$NAME: simple echo via system() of cat with pseudo terminal"
if ! testaddrs pty >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testecho "$N" "$TEST" "" "system:$CAT,pty,$PTYOPTS" "$opts"
fi
esac
N=$((N+1))


NAME=SYSTEMPIPESFDS
case "$TESTS" in
*%functions%*|*%system%*|*%$NAME%*)
TEST="$NAME: simple echo via system() of cat with pipes, non stdio"
testecho "$N" "$TEST" "" "system:$CAT>&9 <&8,pipes,fdin=8,fdout=9" "$opts"
esac
N=$((N+1))


NAME=DUALSYSTEMFDS
case "$TESTS" in
*%functions%*|*%system%*|*%$NAME%*)
TEST="$NAME: echo via dual system() of cat"
testecho "$N" "$TEST" "system:$CAT>&6,fdout=6!!system:$CAT<&7,fdin=7" "" "$opts"
esac
N=$((N+1))


# test: send EOF to exec'ed sub process, let it finished its operation, and 
# check if the sub process returns its data before terminating.
NAME=EXECSOCKETFLUSH
# idea: have socat exec'ing od; send data and EOF, and check if the od'ed data
# arrives.
case "$TESTS" in
*%functions%*|*%exec%*|*%$NAME%*)
TEST="$NAME: call to od via exec with socketpair"
testod "$N" "$TEST" "" "exec:$OD_C" "$opts"
esac
N=$((N+1))


NAME=SYSTEMSOCKETFLUSH
case "$TESTS" in
*%functions%*|*%system%*|*%$NAME%*)
TEST="$NAME: call to od via system() with socketpair"
testod "$N" "$TEST" "" "system:$OD_C" "$opts"
esac
N=$((N+1))


NAME=EXECPIPESFLUSH
case "$TESTS" in
*%functions%*|*%exec%*|*%$NAME%*)
TEST="$NAME: call to od via exec with pipes"
testod "$N" "$TEST" "" "exec:$OD_C,pipes" "$opts"
esac
N=$((N+1))


## LATER:
#NAME=SYSTEMPIPESFLUSH
#case "$TESTS" in
#*%functions%*|*%system%*|*%$NAME%*)
#TEST="$NAME: call to od via system() with pipes"
#testod "$N" "$TEST" "" "system:$OD_C,pipes" "$opts"
#esac
#N=$((N+1))


## LATER:
#NAME=EXECPTYFLUSH
#case "$TESTS" in
#*%functions%*|*%exec%*|*%pty%*|*%$NAME%*)
#TEST="$NAME: call to od via exec with pseudo terminal"
#if ! testaddrs pty >/dev/null; then
#    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
#    numCANT=$((numCANT+1))
#else
#testod "$N" "$TEST" "" "exec:$OD_C,pty,$PTYOPTS" "$opts"
#fi
#esac
#N=$((N+1))


## LATER:
#NAME=SYSTEMPTYFLUSH
#case "$TESTS" in
#*%functions%*|*%system%*|*%pty%*|*%$NAME%*)
#TEST="$NAME: call to od via system() with pseudo terminal"
#if ! testaddrs pty >/dev/null; then
#    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
#    numCANT=$((numCANT+1))
#else
#testod "$N" "$TEST" "" "system:$OD_C,pty,$PTYOPTS" "$opts"
#fi
#esac
#N=$((N+1))


## LATER:
#NAME=SYSTEMPIPESFDSFLUSH
#case "$TESTS" in
#*%functions%*|*%system%*|*%$NAME%*)
#TEST="$NAME: call to od via system() with pipes, non stdio"
#testod "$N" "$TEST" "" "system:$OD_C>&9 <&8,pipes,fdin=8,fdout=9" "$opts"
#esac
#N=$((N+1))


## LATER:
#NAME=DUALSYSTEMFDSFLUSH
#case "$TESTS" in
#*%functions%*|*%system%*|*%$NAME%*)
#TEST="$NAME: call to od via dual system()"
#testecho "$N" "$TEST" "system:$OD_C>&6,fdout=6!!system:$CAT<&7,fdin=7" "" "$opts"
#esac
#N=$((N+1))


case "$UNAME" in
Linux)  IPPROTO=254 ;;
Darwin) IPPROTO=255 ;;
*)      IPPROTO=254 ;;	# just a guess
esac

NAME=RAWIP4SELF
case "$TESTS" in
*%functions%*|*%ip4%*|*%rawip%*|*%root%*|*%$NAME%*)
TEST="$NAME: simple echo via self receiving raw IPv4 protocol"
if ! feat=$(testaddrs ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs rawip) >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}RAWIP not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
    testecho "$N" "$TEST" "" "ip4:127.0.0.1:$IPPROTO" "$opts"
fi
esac
N=$((N+1))

NAME=RAWIPX4SELF
case "$TESTS" in
*%functions%*|*%ip4%*|*%rawip%*|*%root%*|*%$NAME%*)
TEST="$NAME: simple echo via self receiving raw IP protocol, v4 by target"
if ! feat=$(testaddrs ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs rawip) >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}RAWIP not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
    testecho "$N" "$TEST" "" "ip:127.0.0.1:$IPPROTO" "$opts"
fi
esac
N=$((N+1))

NAME=RAWIP6SELF
case "$TESTS" in
*%functions%*|*%ip6%*|*%rawip%*|*%root%*|*%$NAME%*)
TEST="$NAME: simple echo via self receiving raw IPv6 protocol"
if ! feat=$(testaddrs ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs rawip) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}RAWIP not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
    testecho "$N" "$TEST" "" "ip6:[::1]:$IPPROTO" "$opts"
fi
esac
N=$((N+1))

NAME=RAWIPX6SELF
case "$TESTS" in
*%functions%*|*%ip%*|*%ip6%*|*%rawip%*|*%rawip6%*|*%root%*|*%$NAME%*)
TEST="$NAME: simple echo via self receiving raw IP protocol, v6 by target"
if ! feat=$(testaddrs ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs rawip) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}RAWIP not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
    testecho "$N" "$TEST" "" "ip:[::1]:$IPPROTO" "$opts"
fi
esac
N=$((N+1))


NAME=TCPSELF
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: echo via self connection of TCP IPv4 socket"
if [ "$UNAME" != Linux ]; then
    #printf "test $F_n $TEST... ${YELLOW}only on Linux${NORMAL}\n" $N
    $PRINTF "test $F_n $TEST... ${YELLOW}only on Linux$NORMAL\n" $N
    numCANT=$((numCANT+1))
else
    #ts="127.0.0.1:$tsl"
    testecho "$N" "$TEST" "" "tcp:127.100.0.1:$PORT,sp=$PORT,bind=127.100.0.1,reuseaddr" "$opts"
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDPSELF
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: echo via self connection of UDP IPv4 socket"
if [ "$UNAME" != Linux ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}only on Linux$NORMAL\n" $N
    numCANT=$((numCANT+1))
else
    testecho "$N" "$TEST" "" "udp:127.100.0.1:$PORT,sp=$PORT,bind=127.100.0.1" "$opts"
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6SELF
case "$TESTS" in
*%functions%*|*%udp%*|*%udp6%*|*%ip6%*|*%$NAME%*)
TEST="$NAME: echo via self connection of UDP IPv6 socket"
if [ "$UNAME" != Linux ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}only on Linux${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs udp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
    tf="$td/file$N"
    testecho "$N" "$TEST" "" "udp6:[::1]:$PORT,sp=$PORT,bind=[::1]" "$opts"
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=DUALUDPSELF
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: echo via two unidirectional UDP IPv4 sockets"
tf="$td/file$N"
p1=$PORT
p2=$((PORT+1))
testecho "$N" "$TEST" "" "udp:127.0.0.1:$p2,sp=$p1!!udp:127.0.0.1:$p1,sp=$p2" "$opts"
esac
PORT=$((PORT+2))
N=$((N+1))


#function testdual {
#    local
#}


NAME=UNIXSOCKET
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: echo via connection to UNIX domain socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
ts="$td/test$N.socket"
tdiff="$td/test$N.diff"
da=$(date)
CMD1="$SOCAT $opts UNIX-LISTEN:$ts PIPE"
CMD2="$SOCAT $opts -!!- UNIX:$ts"
printf "test $F_n $TEST... " $N
$CMD1 </dev/null >$tf 2>"${te}1" &
bg=$!	# background process id
waitfile "$ts"
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "$te"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $bg 2>/dev/null
esac
N=$((N+1))


NAME=TCP4
case "$TESTS" in
*%functions%*|*%ip4%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: echo via connection to TCP V4 socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP4-LISTEN:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1=$!
waittcp4port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   cat "${te}1"
   echo "$CMD2"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid1 2>/dev/null
wait ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCP6
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: echo via connection to TCP V6 socket"
if ! testaddrs tcp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="[::1]:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP6-listen:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP6:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "$te"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCPX4
case "$TESTS" in
*%functions%*|*%ip4%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: echo via connection to TCP socket, v4 by target"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP-listen:$tsl,pf=ip4,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp4port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "$te"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCPX6
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: echo via connection to TCP socket, v6 by target"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="[::1]:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP-listen:$tsl,pf=ip6,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "$te"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=IPV6ONLY0
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: option ipv6-v6only=0 listens on IPv4"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions ipv6-v6only); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP6-listen:$tsl,ipv6-v6only=0,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=IPV6ONLY1
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: option ipv6-v6only=1 does not listen on IPv4"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions ipv6-v6only); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP6-listen:$tsl,ipv6-v6only=1,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -eq 0 ]; then
   $PRINTF "$FAILED:\n"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED:\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=ENV_LISTEN_4
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: env SOCAT_DEFAULT_LISTEN_IP for IPv4 preference on listen"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions ipv6-v6only); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP-listen:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
SOCAT_DEFAULT_LISTEN_IP=4 $CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp4port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=ENV_LISTEN_6
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: env SOCAT_DEFAULT_LISTEN_IP for IPv6 preference on listen"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="[::1]:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP-listen:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP6:$ts"
printf "test $F_n $TEST... " $N
SOCAT_DEFAULT_LISTEN_IP=6 $CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=LISTEN_OPTION_4
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: option -4 for IPv4 preference on listen"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions ipv6-v6only); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts -4 TCP-listen:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
SOCAT_DEFAULT_LISTEN_IP=6 $CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp4port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=LISTEN_OPTION_6
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: option -6 for IPv6 preference on listen"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="[::1]:$tsl"
da=$(date)
CMD1="$SOCAT $opts -6 TCP-listen:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP6:$ts"
printf "test $F_n $TEST... " $N
SOCAT_DEFAULT_LISTEN_IP=4 $CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=LISTEN_PF_IP4
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: pf=4 overrides option -6 on listen"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions ipv6-v6only); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts -6 TCP-listen:$tsl,pf=ip4,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
SOCAT_DEFAULT_LISTEN_IP=6 $CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp4port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=LISTEN_PF_IP6
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: pf=6 overrides option -4 on listen"
if ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="[::1]:$tsl"
da=$(date)
CMD1="$SOCAT $opts -4 TCP-listen:$tsl,pf=ip6,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP6:$ts"
printf "test $F_n $TEST... " $N
SOCAT_DEFAULT_LISTEN_IP=4 $CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4STREAM
case "$TESTS" in
*%functions%*|*%ip4%*|*%ipapp%*|*%udp%*|*%$NAME%*)
TEST="$NAME: echo via connection to UDP V4 socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="$LOCALHOST:$tsl"
da=$(date)
CMD1="$SOCAT $opts UDP4-LISTEN:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts - UDP4:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1=$!
waitudp4port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2=$?
kill $pid1 2>/dev/null; wait
if [ $rc2 -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   echo "$CMD1 &"
   cat "${te}1"
   echo "$CMD2"
   cat "${te}2"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6STREAM
case "$TESTS" in
*%functions%*|*%ip6%*|*%ipapp%*|*%udp%*|*%$NAME%*)
TEST="$NAME: echo via connection to UDP V6 socket"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="$LOCALHOST6:$tsl"
da=$(date)
CMD1="$SOCAT $opts UDP6-LISTEN:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts - UDP6:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1=$!
waitudp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2=$?
kill $pid1 2>/dev/null; wait
if [ $rc2 -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
fi ;; # ! testaddrs
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=GOPENFILE
case "$TESTS" in
*%functions%*|*%gopen%*|*%file%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: file opening with gopen"
tf1="$td/test$N.1.stdout"
tf2="$td/test$N.2.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
echo "$da" >$tf1
CMD="$SOCAT $opts $tf1!!/dev/null /dev/null,ignoreeof!!-"
printf "test $F_n $TEST... " $N
$CMD >"$tf2" 2>"$te"
if [ $? -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
   numFAIL=$((numFAIL+1))
elif ! diff "$tf1" "$tf2" >"$tdiff"; then
    $PRINTF "$FAILED: diff:\n"
    cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=GOPENPIPE
case "$TESTS" in
*%functions%*|*%gopen%*|*%pipe%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: pipe opening with gopen for reading"
tp="$td/pipe$N"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD="$SOCAT $opts $tp!!/dev/null /dev/null,ignoreeof!!$tf"
printf "test $F_n $TEST... " $N
#mknod $tp p	# no mknod p on FreeBSD
mkfifo $tp
$CMD >$tf 2>"$te" &
#($CMD >$tf 2>"$te" || rm -f "$tp") 2>/dev/null &
bg=$!	# background process id
usleep $MICROS
if [ ! -p "$tp" ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
#echo "$da" >"$tp"	# might hang forever
echo "$da" >"$tp" & export pid=$!; (sleep 1; kill $pid 2>/dev/null) &
# Solaris needs more time:
sleep 1
kill "$bg" 2>/dev/null
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    if [ -s "$te" ]; then
	$PRINTF "$FAILED: $SOCAT:\n"
	echo "$CMD"
	cat "$te"
    else
	$PRINTF "$FAILED: diff:\n"
	cat "$tdiff"
    fi
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi
wait
esac
N=$((N+1))


NAME=GOPENUNIXSTREAM
case "$TESTS" in
*%functions%*|*%gopen%*|*%unix%*|*%listen%*|*%$NAME%*)
TEST="$NAME: GOPEN on UNIX stream socket"
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N $(date) $RANDOM"
#establish a listening unix socket in background
SRV="$SOCAT $opts -lpserver UNIX-LISTEN:\"$ts\" PIPE"
#make a connection
CMD="$SOCAT $opts - $ts"
$PRINTF "test $F_n $TEST... " $N
eval "$SRV 2>${te}s &"
pids=$!
waitfile "$ts"
echo "$da1" |eval "$CMD" >"${tf}1" 2>"${te}1"
if [ $? -ne 0 ]; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CMD"
    cat "${te}1"
    numFAIL=$((numFAIL+1))
elif ! echo "$da1" |diff - "${tf}1" >"$tdiff"; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CMD"
    cat "${te}1"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi # !(rc -ne 0)
wait
esac
N=$((N+1))


NAME=GOPENUNIXDGRAM
case "$TESTS" in
*%functions%*|*%gopen%*|*%unix%*|*%dgram%*|*%$NAME%*)
TEST="$NAME: GOPEN on UNIX datagram socket"
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N $(date) $RANDOM"
#establish a receiving unix socket in background
SRV="$SOCAT $opts -u -lpserver UNIX-RECV:\"$ts\" file:\"$tf\",create"
#make a connection
CMD="$SOCAT $opts -u - $ts"
$PRINTF "test $F_n $TEST... " $N
eval "$SRV 2>${te}s &"
pids=$!
waitfile "$ts"
echo "$da1" |eval "$CMD" 2>"${te}1"
waitfile -s "$tf"
if [ $? -ne 0 ]; then
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CMD"
    cat "${te}1"
    numFAIL=$((numFAIL+1))
elif ! echo "$da1" |diff - "${tf}" >"$tdiff"; then
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CMD"
    cat "${te}1"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi # !(rc -ne 0)
kill "$pids" 2>/dev/null
wait
esac
N=$((N+1))


#set -vx
NAME=IGNOREEOF
case "$TESTS" in
*%functions%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: ignoreeof on file"
ti="$td/test$N.file"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date) $RANDOM"
CMD="$SOCAT $opts -u file:\"$ti\",ignoreeof -"
printf "test $F_n $TEST... " $N
touch "$ti"
$CMD >"$tf" 2>"$te" &
bg=$!
sleep 1
echo "$da" >>"$ti"
sleep 1
kill $bg 2>/dev/null
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    if [ -s "$te" ]; then
	$PRINTF "$FAILED: $SOCAT:\n"
	echo "$CMD"
	cat "$te"
    else
	$PRINTF "$FAILED: diff:\n"
	cat "$tdiff"
    fi
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
wait
esac
N=$((N+1))
#set +vx


NAME=EXECIGNOREEOF
case "$TESTS" in
*%functions%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: exec against address with ignoreeof"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
CMD="$SOCAT $opts -lf /dev/null EXEC:$TRUE /dev/null,ignoreeof"
printf "test $F_n $TEST... " $N
$CMD >"$tf" 2>"$te"
if [ -s "$te" ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=FAKEPTY
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: generation of pty for other processes"
if ! testaddrs pty >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tt="$td/pty$N"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD1="$SOCAT $opts pty,link=$tt pipe"
CMD2="$SOCAT $opts - $tt,$PTYOPTS2"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid=$!	# background process id
waitfile "$tt"
# this hangs on HP-UX, so we use a timeout
(echo "$da"; sleep 1) |$CMD2 >$tf 2>"${te}2" &
rc2=$!
#sleep 5 && kill $rc2 2>/dev/null &
wait $rc2
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    sleep 1
    echo "$CMD2"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi
esac
N=$((N+1))


NAME=O_TRUNC
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: option o-trunc"
ff="$td/test$N.file"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD="$SOCAT -u $opts - open:$ff,append,o-trunc"
printf "test $F_n $TEST... " $N
rm -f $ff; $ECHO "prefix-\c" >$ff
if ! echo "$da" |$CMD >$tf 2>"$te" ||
    ! echo "$da" |diff - $ff >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=FTRUNCATE
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: option ftruncate"
ff="$td/test$N.file"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD="$SOCAT -u $opts - open:$ff,append,ftruncate=0"
printf "test $F_n $TEST... " $N
rm -f $ff; $ECHO "prefix-\c" >$ff
if ! echo "$da" |$CMD >$tf 2>"$te" ||
    ! echo "$da" |diff - $ff >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=RIGHTTOLEFT
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: unidirectional throughput from stdin to stdout, right to left"
testecho "$N" "$TEST" "stdout" "stdin" "$opts -U"
esac
N=$((N+1))


NAME=CHILDDEFAULT
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: child process default properties"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
CMD="$SOCAT $opts -u exec:$PROCAN -"
printf "test $F_n $TEST... " $N
$CMD >$tf 2>$te
MYPID=`expr "\`grep "process id =" $tf\`" : '[^0-9]*\([0-9]*\).*'`
MYPPID=`expr "\`grep "process parent id =" $tf\`" : '[^0-9]*\([0-9]*\).*'`
MYPGID=`expr "\`grep "process group id =" $tf\`" : '[^0-9]*\([0-9]*\).*'`
MYSID=`expr "\`grep "process session id =" $tf\`" : '[^0-9]*\([0-9]*\).*'`
#echo "PID=$MYPID, PPID=$MYPPID, PGID=$MYPGID, SID=$MYSID"
if [ "$MYPID" = "$MYPPID" -o "$MYPID" = "$MYPGID" -o "$MYPID" = "$MYSID" -o \
     "$MYPPID" = "$MYPGID" -o "$MYPPID" = "$MYSID" -o "$MYPGID" = "$MYSID" ];
then
    $PRINTF "$FAILED:\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
   numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=CHILDSETSID
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: child process with setsid"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
CMD="$SOCAT $opts -u exec:$PROCAN,setsid -"
printf "test $F_n $TEST... " $N
$CMD >$tf 2>$te
MYPID=`grep "process id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
MYPPID=`grep "process parent id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
MYPGID=`grep "process group id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
MYSID=`grep "process session id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
#$ECHO "\nPID=$MYPID, PPID=$MYPPID, PGID=$MYPGID, SID=$MYSID"
# PID, PGID, and  SID must be the same
if [ "$MYPID" = "$MYPPID" -o \
     "$MYPID" != "$MYPGID" -o "$MYPID" != "$MYSID" ];
then
    $PRINTF "$FAILED\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=MAINSETSID
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: main process with setsid"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
CMD="$SOCAT $opts -U -,setsid exec:$PROCAN"
printf "test $F_n $TEST... " $N
$CMD >$tf 2>$te
MYPID=`grep "process id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
MYPPID=`grep "process parent id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
MYPGID=`grep "process group id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
MYSID=`grep "process session id =" $tf |(expr "\`cat\`" : '[^0-9]*\([0-9]*\).*')`
#$ECHO "\nPID=$MYPID, PPID=$MYPPID, PGID=$MYPGID, SID=$MYSID"
# PPID, PGID, and  SID must be the same
if [ "$MYPID" = "$MYPPID" -o \
     "$MYPPID" != "$MYPGID" -o "$MYPPID" != "$MYSID" ];
then
    $PRINTF "$FAILED\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    numOK=$((numOK+1))
fi
esac
N=$((N+1))


NAME=OPENSSL_TCP4
case "$TESTS" in
*%functions%*|*%openssl%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: openssl connect"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! type openssl >/dev/null 2>&1; then
    $PRINTF "test $F_n $TEST... ${YELLOW}openssl executable not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts exec:'openssl s_server -accept "$PORT" -quiet -cert testsrv.pem' pipe"
#! CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,pf=ip4,verify=0,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=OPENSSLLISTEN_TCP4
case "$TESTS" in
*%functions%*|*%openssl%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: openssl listen"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,pf=ip4,reuseaddr,$SOCAT_EGD,cert=testsrv.crt,key=testsrv.key,verify=0 pipe"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,pf=ip4,verify=0,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLLISTEN_TCP6
case "$TESTS" in
*%functions%*|*%openssl%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%$NAME%*)
TEST="$NAME: openssl listen"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,pf=ip6,reuseaddr,$SOCAT_EGD,cert=testsrv.crt,key=testsrv.key,verify=0 pipe"
CMD="$SOCAT $opts - openssl:$LOCALHOST6:$PORT,verify=0,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp6port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi
esac
PORT=$((PORT+1))
N=$((N+1))

# does our OpenSSL implementation support halfclose?
NAME=OPENSSLEOF
case "$TESTS" in
*%functions%*|*%openssl%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: openssl half close"
# have an SSL server that executes "$OD_C" and see if EOF on the SSL client
# brings the result of od to the client
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,pf=ip4,reuseaddr,$SOCAT_EGD,cert=testsrv.crt,key=testsrv.key,verify=0 exec:'$OD_C'"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,verify=0,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |$OD_C |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=OPENSSL_SERVERAUTH
case "$TESTS" in
*%functions%*|*%openssl%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: openssl server authentication"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,reuseaddr,$SOCAT_EGD,cert=testsrv.crt,key=testsrv.key,verify=0 pipe"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,verify=1,cafile=testsrv.crt,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSL_CLIENTAUTH
case "$TESTS" in
*%functions%*|*%openssl%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: openssl client authentication"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,reuseaddr,verify=1,cert=testsrv.crt,key=testsrv.key,cafile=testcli.crt,$SOCAT_EGD pipe"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,verify=0,cert=testcli.crt,key=testcli.key,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSL_FIPS_BOTHAUTH
case "$TESTS" in
*%functions%*|*%openssl%*|*%fips%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: OpenSSL+FIPS client and server authentication"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testoptions fips >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL/FIPS not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
OPENSSL_FIPS=1 gentestcert testsrvfips
OPENSSL_FIPS=1 gentestcert testclifips
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,reuseaddr,fips,$SOCAT_EGD,cert=testsrvfips.crt,key=testsrvfips.key,cafile=testclifips.crt pipe"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,fips,verify=1,cert=testclifips.crt,key=testclifips.key,cafile=testsrvfips.crt,$SOCAT_EGD"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=SOCKS4CONNECT_TCP4
case "$TESTS" in
*%functions%*|*%socks%*|*%socks4%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: socks4 connect over TCP/IPv4"
if ! testaddrs socks4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}SOCKS4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
# we have a normal tcp echo listening - so the socks header must appear in answer
CMD2="$SOCAT tcp4-l:$PORT,reuseaddr exec:\"./socks4echo.sh\""
CMD="$SOCAT $opts - socks4:$LOCALHOST:32.98.76.54:32109,pf=ip4,socksport=$PORT",socksuser="nobody"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT 1
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=SOCKS4CONNECT_TCP6
case "$TESTS" in
*%functions%*|*%socks%*|*%socks4%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%$NAME%*)
TEST="$NAME: socks4 connect over TCP/IPv6"
if ! testaddrs socks4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}SOCKS4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
# we have a normal tcp echo listening - so the socks header must appear in answer
CMD2="$SOCAT tcp6-l:$PORT,reuseaddr exec:\"./socks4echo.sh\""
CMD="$SOCAT $opts - socks4:$LOCALHOST6:32.98.76.54:32109,socksport=$PORT",socksuser="nobody"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp6port $PORT 1
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=SOCKS4ACONNECT_TCP4
case "$TESTS" in
*%functions%*|*%socks%*|*%socks4a%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: socks4a connect over TCP/IPv4"
if ! testaddrs socks4a >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}SOCKS4A not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
# we have a normal tcp echo listening - so the socks header must appear in answer
CMD2="$SOCAT tcp4-l:$PORT,reuseaddr exec:\"./socks4a-echo.sh\""
CMD="$SOCAT $opts - socks4a:$LOCALHOST:localhost:32109,pf=ip4,socksport=$PORT",socksuser="nobody"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT 1
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=SOCKS4ACONNECT_TCP6
case "$TESTS" in
*%functions%*|*%socks%*|*%socks4a%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%$NAME%*)
TEST="$NAME: socks4a connect over TCP/IPv6"
if ! testaddrs socks4a >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}SOCKS4A not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
# we have a normal tcp echo listening - so the socks header must appear in answer
CMD2="$SOCAT tcp6-l:$PORT,reuseaddr exec:\"./socks4a-echo.sh\""
CMD="$SOCAT $opts - socks4a:$LOCALHOST6:localhost:32109,socksport=$PORT",socksuser="nobody"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp6port $PORT 1
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=PROXYCONNECT_TCP4
case "$TESTS" in
*%functions%*|*%proxyconnect%*|*%proxy%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: proxy connect over TCP/IPv4"
if ! testaddrs proxy >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PROXY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ts="$td/test$N.sh"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
#CMD2="$SOCAT tcp4-l:$PORT,crlf system:\"read; read; $ECHO \\\"HTTP/1.0 200 OK\n\\\"; cat\""
CMD2="$SOCAT tcp4-l:$PORT,reuseaddr,crlf exec:\"/bin/bash proxyecho.sh\""
CMD="$SOCAT $opts - proxy:$LOCALHOST:127.0.0.1:1000,pf=ip4,proxyport=$PORT"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}2\" &"
pid=$!	# background process id
waittcp4port $PORT 1
echo "$da" |$CMD >"$tf" 2>"${te}1"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=PROXYCONNECT_TCP6
case "$TESTS" in
*%functions%*|*%proxyconnect%*|*%proxy%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%$NAME%*)
TEST="$NAME: proxy connect over TCP/IPv6"
if ! testaddrs proxy >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PROXY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ts="$td/test$N.sh"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
#CMD2="$SOCAT tcp6-l:$PORT,crlf system:\"read; read; $ECHO \\\"HTTP/1.0 200 OK\n\\\"; cat\""
CMD2="$SOCAT tcp6-l:$PORT,reuseaddr,crlf exec:\"/bin/bash proxyecho.sh\""
CMD="$SOCAT $opts - proxy:$LOCALHOST6:127.0.0.1:1000,proxyport=$PORT"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}2\" &"
pid=$!	# background process id
waittcp6port $PORT 1
echo "$da" |$CMD >"$tf" 2>"${te}1"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCP4NOFORK
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: echo via connection to TCP V4 socket with nofork'ed exec"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP4-LISTEN:$tsl,reuseaddr exec:$CAT,nofork"
CMD2="$SOCAT $opts stdin!!stdout TCP4:$ts"
printf "test $F_n $TEST... " $N
#$CMD1 >"$tf" 2>"${te}1" &
$CMD1 >/dev/null 2>"${te}1" &
waittcp4port $tsl
#usleep $MICROS
echo "$da" |$CMD2 >"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=EXECCATNOFORK
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: simple echo via exec of cat with nofork"
testecho "$N" "$TEST" "" "exec:$CAT,nofork" "$opts"
esac
N=$((N+1))


NAME=SYSTEMCATNOFORK
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: simple echo via system() of cat with nofork"
testecho "$N" "$TEST" "" "system:$CAT,nofork" "$opts"
esac
N=$((N+1))


NAME=NOFORKSETSID
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: simple echo via exec() of cat with nofork and setsid"
testecho "$N" "$TEST" "" "system:$CAT,nofork,setsid" "$opts"
esac
N=$((N+1))

#==============================================================================
#TEST="$NAME: echo via 'connection' to UDP V4 socket"
#tf="$td/file$N"
#tsl=65534
#ts="127.0.0.1:$tsl"
#da=$(date)
#$SOCAT UDP-listen:$tsl PIPE &
#sleep 2
#echo "$da" |$SOCAT stdin!!stdout UDP:$ts >"$tf"
#if [ $? -eq 0 ] && echo "$da" |diff "$tf" -; then
#   $ECHO "... test $N succeeded"
#   numOK=$((numOK+1))
#else
#   $ECHO "*** test $N $FAILED"
#    numFAIL=$((numFAIL+1))
#fi
#N=$((N+1))
#==============================================================================
# TEST 4 - simple echo via new file
#N=4
#tf="$td/file$N"
#tp="$td/pipe$N"
#da=$(date)
#rm -f "$tf.tmp"
#echo "$da" |$SOCAT - FILE:$tf.tmp,ignoreeof >"$tf"
#if [ $? -eq 0 ] && echo "$da" |diff "$tf" -; then
#   $ECHO "... test $N succeeded"
#   numOK=$((numOK+1))
#else
#   $ECHO "*** test $N $FAILED"
#   numFAIL=$((numFAIL+1))
#fi

#==============================================================================

NAME=TOTALTIMEOUT
case "$TESTS" in
*%functions%*|*%timeout%*|*%$NAME%*)
TEST="$NAME: socat inactivity timeout"
if ! true; then
    :
else
#set -vx
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
CMD2="$SOCAT $opts -T 1 tcp4-listen:$PORT,reuseaddr pipe"
CMD="$SOCAT $opts - tcp4-connect:$LOCALHOST:$PORT"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>${te}1 &"
pid=$!	# background process id
waittcp4port $PORT 1
(echo "$da"; sleep 2; echo X) |$CMD >"$tf" 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
#set +vx
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=IGNOREEOF+TOTALTIMEOUT
case "$TESTS" in
*%functions%*|*%timeout%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: ignoreeof and inactivity timeout"
if ! true; then
    :
else
#set -vx
ti="$td/test$N.file"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date) $RANDOM"
CMD="$SOCAT $opts -T 2 -u file:\"$ti\",ignoreeof -"
printf "test $F_n $TEST... " $N
touch "$ti"
$CMD >"$tf" 2>"$te" &
bg=$!	# background process id
sleep 1
echo "$da" >>"$ti"
sleep 4
echo X >>"$ti"
sleep 1
kill $bg 2>/dev/null
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD &"
    cat "$te"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "$te"; fi
   numOK=$((numOK+1))
fi
wait
fi # feats
esac
N=$((N+1))


NAME=PROXY2SPACES
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: proxy connect accepts status with multiple spaces"
if ! testaddrs proxy >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PROXY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ts="$td/test$N.sh"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
#CMD2="$SOCAT tcp-l:$PORT,crlf system:\"read; read; $ECHO \\\"HTTP/1.0 200 OK\n\\\"; cat\""
CMD2="$SOCAT tcp4-l:$PORT,reuseaddr,crlf exec:\"/bin/bash proxyecho.sh -w 2\""
CMD="$SOCAT $opts - proxy:$LOCALHOST:127.0.0.1:1000,pf=ip4,proxyport=$PORT"
printf "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT 1
echo "$da" |$CMD >"$tf" 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=BUG-UNISTDIO
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: for bug with address options on both stdin/out in unidirectional mode"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
ff="$td/file$N"
printf "test $F_n $TEST... " $N
>"$ff"
#$SOCAT $opts -u /dev/null -,setlk <"$ff"  2>"$te"
CMD="$SOCAT $opts -u /dev/null -,setlk"
$CMD <"$ff"  2>"$te"
if [ "$?" -eq 0 ]; then
    $PRINTF "$OK\n"
   numOK=$((numOK+1))
else
    if [ "$UNAME" = "Linux" ]; then
	$PRINTF "$FAILED\n"
	echo "$CMD"
	cat "$te"
	numFAIL=$((numFAIL+1))
    else
	$PRINTF "${YELLOW}failed (don't care)${NORMAL}\n"
	numCANT=$((numCANT+1))
    fi
fi
esac
N=$((N+1))


NAME=SINGLEEXECOUTSOCKETPAIR
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: inheritance of stdout to single exec with socketpair"
testecho "$N" "$TEST" "-!!exec:cat" "" "$opts" 1
esac
N=$((N+1))

NAME=SINGLEEXECOUTPIPE
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: inheritance of stdout to single exec with pipe"
testecho "$N" "$TEST" "-!!exec:cat,pipes" "" "$opts" 1
esac
N=$((N+1))

NAME=SINGLEEXECOUTPTY
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: inheritance of stdout to single exec with pty"
if ! testaddrs pty >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testecho "$N" "$TEST" "-!!exec:cat,pty,raw" "" "$opts" 1
fi
esac
N=$((N+1))

NAME=SINGLEEXECINSOCKETPAIR
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: inheritance of stdin to single exec with socketpair"
testecho "$N" "$TEST" "exec:cat!!-" "" "$opts"
esac
N=$((N+1))

NAME=SINGLEEXECINPIPE
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: inheritance of stdin to single exec with pipe"
testecho "$N" "$TEST" "exec:cat,pipes!!-" "" "$opts"
esac
N=$((N+1))

NAME=SINGLEEXECINPTYDELAY
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: inheritance of stdin to single exec with pty, with delay"
if ! testaddrs pty >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testecho "$N" "$TEST" "exec:cat,pty,raw!!-" "" "$opts" $MISCDELAY
fi
esac
N=$((N+1))

NAME=SINGLEEXECINPTY
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: inheritance of stdin to single exec with pty"
if ! testaddrs pty >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}PTY not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testecho "$N" "$TEST" "exec:cat,pty,raw!!-" "" "$opts"
fi
esac
N=$((N+1))


NAME=READLINE
#set -vx
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: readline with password and sigint"
if ! feat=$(testaddrs readline pty); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
SAVEMICS=$MICROS
#MICROS=2000000
ts="$td/test$N.sh"
to="$td/test$N.stdout"
tpi="$td/test$N.inpipe"
tpo="$td/test$N.outpipe"
te="$td/test$N.stderr"
tr="$td/test$N.ref"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
# the feature that we really want to test is in the readline.sh script:
CMD="$SOCAT $opts open:$tpi,nonblock!!open:$tpo exec:\"./readline.sh -nh ./readline-test.sh\",pty,ctty,setsid,raw,echo=0,isig"
#echo "$CMD" >"$ts"
#chmod a+x "$ts"
printf "test $F_n $TEST... " $N
rm -f "$tpi" "$tpo"
mkfifo "$tpi"
touch "$tpo"
#
# during development of this test, the following command line succeeded:
# (sleep 1; $ECHO "user\n\c"; sleep 1; $ECHO "password\c"; sleep 1; $ECHO "\n\c"; sleep 1; $ECHO "test 1\n\c"; sleep 1; $ECHO "\003\c"; sleep 1; $ECHO "test 2\n\c"; sleep 1; $ECHO "exit\n\c"; sleep 1) |$SOCAT -d -d -d -d -lf/tmp/gerhard/debug1 -v -x - exec:'./readline.sh ./readline-test.sh',pty,ctty,setsid,raw,echo=0,isig
#
PATH=${SOCAT%socat}:$PATH eval "$CMD 2>$te &"
pid=$!	# background process id
usleep $MICROS

(
usleep $((3*MICROS))
$ECHO "user\n\c"
usleep $MICROS
$ECHO "password\c"
usleep $MICROS
$ECHO "\n\c"
usleep $MICROS
$ECHO "test 1\n\c"
usleep $MICROS
$ECHO "\003\c"
usleep $MICROS
$ECHO "test 2\n\c"
usleep $MICROS
$ECHO "exit\n\c"
usleep $MICROS
) >"$tpi"

#cat >$tr <<EOF
#readline feature test program
#Authentication required
#Username: Username: user
#Password: 
#prog> prog> test 1
#executing test 1
#prog> ./readline-test.sh got SIGINT
#test 2
#executing test 2
#prog> prog> exit
#EOF
cat >$tr <<EOF
readline feature test program
Authentication required
Username: user
Password: 
prog> test 1
executing test 1
prog> ./readline-test.sh got SIGINT
test 2
executing test 2
prog> exit
EOF

#0 if ! sed 's/.*\r//g' "$tpo" |diff -q "$tr" - >/dev/null 2>&1; then
#0 if ! sed 's/.*'"$($ECHO '\r\c')"'/</g' "$tpo" |diff -q "$tr" - >/dev/null 2>&1; then
if ! tr "$($ECHO '\r \c')" "% " <$tpo |sed 's/%$//g' |sed 's/.*%//g' |diff "$tr" - >"$tdiff" 2>&1; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
#kill $pid 2>/dev/null
MICROS=$SAVEMICS
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=GENDERCHANGER
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: TCP4 \"gender changer\""
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
# this is the server in the protected network that we want to reach
CMD1="$SOCAT -lpserver $opts tcp4-l:$PORT,reuseaddr,bind=$LOCALHOST echo"
# this is the double client in the protected network
CMD2="$SOCAT -lp2client $opts tcp4:$LOCALHOST:$((PORT+1)),retry=10,intervall=1 tcp4:$LOCALHOST:$PORT"
# this is the double server in the outside network
CMD3="$SOCAT -lp2server $opts tcp4-l:$((PORT+2)),reuseaddr,bind=$LOCALHOST tcp4-l:$((PORT+1)),reuseaddr,bind=$LOCALHOST"
# this is the outside client that wants to use the protected server
CMD4="$SOCAT -lpclient $opts -t1 - tcp4:$LOCALHOST:$((PORT+2))"
printf "test $F_n $TEST... " $N
eval "$CMD1 2>${te}1 &"
pid1=$!
eval "$CMD2 2>${te}2 &"
pid2=$!
eval "$CMD3 2>${te}3 &"
pid3=$!
waittcp4port $PORT 1 &&
waittcp4port $((PORT+2)) 1
sleep 1
echo "$da" |$CMD4 >$tf 2>"${te}4"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    echo "$CMD2 &"
    echo "$CMD3 &"
    echo "$CMD4"
    cat "${te}1" "${te}2" "${te}3" "${te}4"
    echo "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$debug" ]; then cat "${te}1" "${te}2" "${te}3" "${te}4"; fi
   numOK=$((numOK+1))
fi
kill $pid1 $pid2 $pid3 $pid4 2>/dev/null
wait
esac
PORT=$((PORT+3))
N=$((N+1))


#!
#PORT=10000
#!
NAME=OUTBOUNDIN
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: gender changer via SSL through HTTP proxy, oneshot"
if ! feat=$(testaddrs openssl proxy); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat |tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
# this is the server in the protected network that we want to reach
CMD1="$SOCAT $opts -lpserver tcp4-l:$PORT,reuseaddr,bind=$LOCALHOST echo"
# this is the proxy in the protected network that provides a way out
CMD2="$SOCAT $opts -lpproxy tcp4-l:$((PORT+1)),reuseaddr,bind=$LOCALHOST,fork exec:./proxy.sh"
# this is our proxy connect wrapper in the protected network
CMD3="$SOCAT $opts -lpwrapper tcp4-l:$((PORT+2)),reuseaddr,bind=$LOCALHOST,fork proxy:$LOCALHOST:$LOCALHOST:$((PORT+3)),pf=ip4,proxyport=$((PORT+1)),resolve"
# this is our double client in the protected network using SSL
#CMD4="$SOCAT $opts -lp2client ssl:$LOCALHOST:$((PORT+2)),pf=ip4,retry=10,intervall=1,cert=testcli.pem,cafile=testsrv.crt,$SOCAT_EGD tcp4:$LOCALHOST:$PORT"
CMD4="$SOCAT $opts -lp2client ssl:$LOCALHOST:$((PORT+2)),pf=ip4,cert=testcli.pem,cafile=testsrv.crt,$SOCAT_EGD tcp4:$LOCALHOST:$PORT"
# this is the double server in the outside network
CMD5="$SOCAT $opts -lp2server -t1 tcp4-l:$((PORT+4)),reuseaddr,bind=$LOCALHOST ssl-l:$((PORT+3)),pf=ip4,reuseaddr,bind=$LOCALHOST,$SOCAT_EGD,cert=testsrv.pem,cafile=testcli.crt"
# this is the outside client that wants to use the protected server
CMD6="$SOCAT $opts -lpclient -t5 - tcp4:$LOCALHOST:$((PORT+4))"
printf "test $F_n $TEST... " $N
eval "$CMD1 2>${te}1 &"
pid1=$!
eval "$CMD2 2>${te}2 &"
pid2=$!
eval "$CMD3 2>${te}3 &"
pid3=$!
waittcp4port $PORT 1       || $PRINTF "$FAILED: port $PORT\n" >&2 </dev/null
waittcp4port $((PORT+1)) 1 || $PRINTF "$FAILED: port $((PORT+1))\n" >&2 </dev/null
waittcp4port $((PORT+2)) 1 || $PRINTF "$FAILED: port $((PORT+2))\n" >&2 </dev/null
eval "$CMD5 2>${te}5 &"
pid5=$!
waittcp4port $((PORT+4)) 1 || $PRINTF "$FAILED: port $((PORT+4))\n" >&2 </dev/null
echo "$da" |$CMD6 >$tf 2>"${te}6" &
pid6=$!
waittcp4port $((PORT+3)) 1 || $PRINTF "$FAILED: port $((PORT+3))\n" >&2 </dev/null
eval "$CMD4 2>${te}4 &"
pid4=$!
wait $pid6
if ! (echo "$da"; sleep 2) |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    cat "${te}1"
    echo "$CMD2 &"
    cat "${te}2"
    echo "$CMD3 &"
    cat "${te}3"
    echo "$CMD5 &"
    cat "${te}5"
    echo "$CMD6"
    cat "${te}6"
    echo "$CMD4 &"
    cat "${te}4"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$debug" ]; then cat "${te}1" "${te}2" "${te}3" "${te}4" "${te}5" "${te}6"; fi
   numOK=$((numOK+1))
fi
kill $pid1 $pid2 $pid3 $pid4 $pid5 2>/dev/null
wait
fi # feats
esac
PORT=$((PORT+5))
N=$((N+1))


#!
PORT=$((RANDOM+16184))
#!
NAME=INTRANETRIPPER
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: gender changer via SSL through HTTP proxy, daemons"
if ! feat=$(testaddrs openssl proxy); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N.1 $(date) $RANDOM"
da2="test$N.2 $(date) $RANDOM"
da3="test$N.3 $(date) $RANDOM"
# this is the server in the protected network that we want to reach
CMD1="$SOCAT $opts -lpserver -t1 tcp4-l:$PORT,reuseaddr,bind=$LOCALHOST,fork echo"
# this is the proxy in the protected network that provides a way out
CMD2="$SOCAT $opts -lpproxy -t1 tcp4-l:$((PORT+1)),reuseaddr,bind=$LOCALHOST,fork exec:./proxy.sh"
# this is our proxy connect wrapper in the protected network
CMD3="$SOCAT $opts -lpwrapper -t3 tcp4-l:$((PORT+2)),reuseaddr,bind=$LOCALHOST,fork proxy:$LOCALHOST:$LOCALHOST:$((PORT+3)),pf=ip4,proxyport=$((PORT+1)),resolve"
# this is our double client in the protected network using SSL
CMD4="$SOCAT $opts -lp2client -t3 ssl:$LOCALHOST:$((PORT+2)),retry=10,intervall=1,cert=testcli.pem,cafile=testsrv.crt,verify,fork,$SOCAT_EGD tcp4:$LOCALHOST:$PORT"
# this is the double server in the outside network
CMD5="$SOCAT $opts -lp2server -t4 tcp4-l:$((PORT+4)),reuseaddr,bind=$LOCALHOST,fork ssl-l:$((PORT+3)),pf=ip4,reuseaddr,bind=$LOCALHOST,$SOCAT_EGD,cert=testsrv.pem,cafile=testcli.crt,retry=10"
# this is the outside client that wants to use the protected server
CMD6="$SOCAT $opts -lpclient -t5 - tcp4:$LOCALHOST:$((PORT+4)),retry=3"
printf "test $F_n $TEST... " $N
# start the intranet infrastructure
eval "$CMD1 2>\"${te}1\" &"
pid1=$!
eval "$CMD2 2>\"${te}2\" &"
pid2=$!
waittcp4port $PORT 1       || $PRINTF "$FAILED: port $PORT\n" >&2 </dev/null
waittcp4port $((PORT+1)) 1 || $PRINTF "$FAILED: port $((PORT+1))\n" >&2 </dev/null
# initiate our internal measures
eval "$CMD3 2>\"${te}3\" &"
pid3=$!
eval "$CMD4 2>\"${te}4\" &"
pid4=$!
waittcp4port $((PORT+2)) 1 || $PRINTF "$FAILED: port $((PORT+2))\n" >&2 </dev/null
# now we start the external daemon
eval "$CMD5 2>\"${te}5\" &"
pid5=$!
waittcp4port $((PORT+4)) 1 || $PRINTF "$FAILED: port $((PORT+4))\n" >&2 </dev/null
# and this is the outside client:
echo "$da1" |$CMD6 >${tf}_1 2>"${te}6_1" &
pid6_1=$!
echo "$da2" |$CMD6 >${tf}_2 2>"${te}6_2" &
pid6_2=$!
echo "$da3" |$CMD6 >${tf}_3 2>"${te}6_3" &
pid6_3=$!
wait $pid6_1 $pid6_2 $pid6_3
#
(echo "$da1"; sleep 2) |diff - "${tf}_1" >"${tdiff}1"
(echo "$da2"; sleep 2) |diff - "${tf}_2" >"${tdiff}2"
(echo "$da3"; sleep 2) |diff - "${tf}_3" >"${tdiff}3"
if test -s "${tdiff}1" -o -s "${tdiff}2" -o -s "${tdiff}3"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    cat "${te}1"
    echo "$CMD2 &"
    cat "${te}2"
    echo "$CMD3 &"
    cat "${te}3"
    echo "$CMD4 &"
    cat "${te}4"
    echo "$CMD5 &"
    cat "${te}5"
    echo "$CMD6 &"
    cat "${te}6_1"
    cat "${tdiff}1"
    echo "$CMD6 &"
    cat "${te}6_2"
    cat "${tdiff}2"
    echo "$CMD6 &"
    cat "${te}6_3"
    cat "${tdiff}3"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$debug" ]; then cat "${te}1" "${te}2" "${te}3" "${te}4" "${te}5" ${te}6*; fi
   numOK=$((numOK+1))
fi
kill $pid1 $pid2 $pid3 $pid4 $pid5 2>/dev/null
wait
fi
esac
PORT=$((PORT+5))
N=$((N+1))


# let us test the security features with -s, retry, and fork
# method: first test without security feature if it works
#   then try with security feature, must fail

# test the security features of a server address
testserversec () {
    local num="$1"
    local title="$2"
    local opts="$3"
    local arg1="$4"	# the server address
    local secopt0="$5"	# option without security for server, mostly empty
    local secopt1="$6"	# the security option for server, to be tested
    local arg2="$7"	# the client address
    local ipvers="$8"	# IP version, for check of listen port
    local proto="$9"	# protocol, for check of listen port
    local port="${10}"	# start client when this port is listening
    local expect="${11}"	# expected behaviour of client: 0..empty output; -1..error
    local T="${12}";	[ -z "$T" ] && T=0
    local tf="$td/test$N.stdout"
    local te="$td/test$N.stderr"
    local tdiff1="$td/test$N.diff1"
    local tdiff2="$td/test$N.diff2"
    local da="$(date)"
    local stat result

    $PRINTF "test $F_n %s... " $num "$title"
#set -vx
    # first: without security
    # start server
    $SOCAT $opts "$arg1,$secopt0" echo 2>"${te}1" &
    spid=$!
    if [ "$port" ] && ! wait${proto}${ipvers}port $port 1; then
	kill $spid 2>/dev/null
	$PRINTF "$NO_RESULT (ph.1 server not working):\n"
	echo "$SOCAT $opts \"$arg1,$secopt0\" echo &"
	cat "${te}1"
	numCANT=$((numCANT+1))
	wait; return
    fi
    # now use client
    (echo "$da"; sleep $T) |$SOCAT $opts - "$arg2" >"$tf" 2>"${te}2"
    stat="$?"
    kill $spid 2>/dev/null
    #killall $SOCAT 2>/dev/null
    if [ "$stat" != 0 ]; then
	$PRINTF "$NO_RESULT (ph.1 function fails): $SOCAT:\n"
	echo "$SOCAT $opts \"$arg1,$secopt0\" echo &"
	cat "${te}1"
	echo "$SOCAT $opts - \"$arg2\""
	cat "${te}2"
	numCANT=$((numCANT+1))
	wait; return
    elif echo "$da" |diff - "$tf" >"$tdiff1" 2>&1; then
	:	# function without security is ok, go on
    else
	$PRINTF "$NO_RESULT (ph.1 function fails): diff:\n"
	echo "$SOCAT $opts $arg1,$secopt0 echo &"
	cat "${te}1"
	echo "$SOCAT $opts - $arg2"
	cat "${te}2"
	cat "$tdiff1"
	numCANT=$((numCANT+1))
	wait; return
    fi

    # then: with security
    if [ "$port" ] && ! wait${proto}${ipvers}port $port 0; then
	$PRINTF "$NO_RESULT (ph.1 port remains in use)\n"
	numCANT=$((numCANT+1))
	wait; return
    fi
    wait

#set -vx
    # assemble address w/ security option; on dual, take read part:
    case "$arg1" in
    *!!*) arg="${arg1%!!*},$secopt1!!${arg1#*!!}" ;;
    *)    arg="$arg1,$secopt1" ;;
    esac
    # start server
    CMD3="$SOCAT $opts $arg echo"
    $CMD3 2>"${te}3" &
    spid=$!
    if [ "$port" ] && ! wait${proto}${ipvers}port $port 1; then
	kill $spid 2>/dev/null
	$PRINTF "$NO_RESULT (ph.2 server not working)\n"
	wait
	echo "$CMD3"
	cat "${te}3"
	numCANT=$((numCANT+1))
	return
    fi
    # now use client
    (echo "$da"; sleep $T) |$SOCAT $opts - "$arg2" >"$tf" 2>"${te}4"
    stat=$?
    kill $spid 2>/dev/null
#set +vx
    #killall $SOCAT 2>/dev/null
    if [ "$stat" != 0 ]; then
	result=-1;	# socat had error
    elif [ ! -s "$tf" ]; then
	result=0;	# empty output
    elif echo "$da" |diff - "$tf" >"$tdiff2" 2>&1; then
	result=1;	# output is copy of input
    else
	result=2;	# output differs from input
    fi
    if [ X$result != X$expect ]; then
	case X$result in
	X-1) $PRINTF "$NO_RESULT (ph.2 client error): $SOCAT:\n"
	    echo "$SOCAT $opts $arg echo"
	    cat "${te}3"
	    echo "$SOCAT $opts - $arg2"
	    cat "${te}4"
	    numCANT=$((numCANT+1)) ;;
	X0) $PRINTF "$NO_RESULT (ph.2 diff failed): diff:\n"
	    echo "$SOCAT $opts $arg echo"
	    cat "${te}3"
	    echo "$SOCAT $opts - $arg2"
	    cat "${te}4"
	    cat "$tdiff2"
	    numCANT=$((numCANT+1)) ;;
	X1) $PRINTF "$FAILED: SECURITY BROKEN\n"
	    echo "$SOCAT $opts $arg echo"
	    cat "${te}3"
	    echo "$SOCAT $opts - $arg2"
	    cat "${te}4"
	    cat "$tdiff2"
	    numFAIL=$((numFAIL+1)) ;;
	X2) $PRINTF "$FAILED: diff:\n"
	    echo "$SOCAT $opts $arg echo"
	    cat "${te}3"
	    echo "$SOCAT $opts - $arg2"
	    cat "${te}4"
	    cat "$tdiff2"
	    numFAIL=$((numFAIL+1)) ;;
	esac
    else
	$PRINTF "$OK\n"
	if [ -n "$debug" ]; then cat $te; fi
	numOK=$((numOK+1))
    fi
    wait
#set +vx
}


NAME=TCP4RANGEBITS
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with RANGE option"
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "range=$SECONDADDR/32" "tcp4:127.0.0.1:$PORT" 4 tcp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP4RANGEMASK
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with RANGE option"
if [ "$UNAME" != Linux ]; then
    # we need access to more loopback addresses
    $PRINTF "test $F_n $TEST... ${YELLOW}only on Linux${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "range=127.0.0.0:255.255.0.0" "tcp4:127.1.0.0:$PORT" 4 tcp $PORT 0
fi ;; # Linux
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCP4SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with SOURCEPORT option"
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "sp=$PORT" "tcp4:127.0.0.1:$PORT" 4 tcp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP4LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with LOWPORT option"
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "lowport" "tcp4:127.0.0.1:$PORT" 4 tcp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP4WRAPPERS_ADDR
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with TCPWRAP option"
if ! feat=$(testaddrs tcp ip4 libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "hosts-allow=$ha,hosts-deny=$hd" "tcp4:127.0.0.1:$PORT" 4 tcp $PORT 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP4WRAPPERS_NAME
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with TCPWRAP option"
if ! feat=$(testaddrs tcp ip4 libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $LOCALHOST" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "hosts-allow=$ha,hosts-deny=$hd" "tcp4:$SECONDADDR:$PORT" 4 tcp $PORT 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCP6RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of TCP6-L with RANGE option"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "tcp6-l:$PORT,reuseaddr,fork,retry=1" "" "range=[::2/128]" "tcp6:[::1]:$PORT" 6 tcp $PORT 0
fi # feat
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP6SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of TCP6-L with SOURCEPORT option"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "tcp6-l:$PORT,reuseaddr,fork,retry=1" "" "sp=$PORT" "tcp6:[::1]:$PORT" 6 tcp $PORT 0
fi # ! feat
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP6LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of TCP6-L with LOWPORT option"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "tcp6-l:$PORT,reuseaddr,fork,retry=1" "" "lowport" "tcp6:[::1]:$PORT" 6 tcp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=TCP6TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of TCP6-L with TCPWRAP option"
if ! feat=$(testaddrs tcp ip6 libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "tcp6-l:$PORT,reuseaddr,fork,retry=1" "" "hosts-allow=$ha,hosts-deny=$hd" "tcp6:[::1]:$PORT" 6 tcp $PORT 0
fi # ! feat
;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of UDP4-L with RANGE option"
#testserversec "$N" "$TEST" "$opts -s" "udp4-l:$PORT,reuseaddr,fork" "" "range=$SECONDADDR/32" "udp4:127.0.0.1:$PORT" 4 udp $PORT 0
testserversec "$N" "$TEST" "$opts -s" "udp4-l:$PORT,reuseaddr" "" "range=$SECONDADDR/32" "udp4:127.0.0.1:$PORT" 4 udp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of UDP4-L with SOURCEPORT option"
testserversec "$N" "$TEST" "$opts -s" "udp4-l:$PORT,reuseaddr" "" "sp=$PORT" "udp4:127.0.0.1:$PORT" 4 udp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of UDP4-L with LOWPORT option"
testserversec "$N" "$TEST" "$opts -s" "udp4-l:$PORT,reuseaddr" "" "lowport" "udp4:127.0.0.1:$PORT" 4 udp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of UDP4-L with TCPWRAP option"
if ! feat=$(testaddrs udp ip4 libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "udp4-l:$PORT,reuseaddr,retry=1" "" "tcpwrap-etc=$td" "udp4:127.0.0.1:$PORT" 4 udp $PORT 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of UDP6-L with RANGE option"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
#testserversec "$N" "$TEST" "$opts -s" "udp6-l:$PORT,reuseaddr,fork" "" "range=[::2/128]" "udp6:[::1]:$PORT" 6 udp $PORT 0
testserversec "$N" "$TEST" "$opts -s" "udp6-l:$PORT,reuseaddr" "" "range=[::2/128]" "udp6:[::1]:$PORT" 6 udp $PORT 0
fi # ! feat
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of UDP6-L with SOURCEPORT option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "udp6-l:$PORT,reuseaddr" "" "sp=$PORT" "udp6:[::1]:$PORT" 6 udp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of UDP6-L with LOWPORT option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "udp6-l:$PORT,reuseaddr" "" "lowport" "udp6:[::1]:$PORT" 6 udp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of UDP6-L with TCPWRAP option"
if ! feat=$(testaddrs tcp ip6 libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "udp6-l:$PORT,reuseaddr" "" "lowport" "udp6:[::1]:$PORT" 6 udp $PORT 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=OPENSSLTCP4_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%openssl%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of SSL-L over TCP/IPv4 with RANGE option"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip4,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "range=$SECONDADDR/32" "ssl:127.0.0.1:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 4 tcp $PORT -1
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLTCP4_SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%openssl%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of SSL-L with SOURCEPORT option"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip4,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "sp=$PORT" "ssl:127.0.0.1:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 4 tcp $PORT -1
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLTCP4_LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%openssl%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of SSL-L with LOWPORT option"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip4,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "lowport" "ssl:127.0.0.1:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 4 tcp $PORT -1
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLTCP4_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%openssl%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of SSL-L with TCPWRAP option"
if ! feat=$(testaddrs ip4 tcp libwrap openssl); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip4,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "tcpwrap-etc=$td" "ssl:127.0.0.1:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 4 tcp $PORT -1
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLCERTSERVER
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%openssl%*|*%$NAME%*)
TEST="$NAME: security of SSL-L with client certificate"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip4,reuseaddr,fork,retry=1,$SOCAT_EGD,verify,cert=testsrv.crt,key=testsrv.key" "cafile=testcli.crt" "cafile=testsrv.crt" "ssl:127.0.0.1:$PORT,cafile=testsrv.crt,cert=testcli.pem,$SOCAT_EGD" 4 tcp $PORT -1
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLCERTCLIENT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%openssl%*|*%$NAME%*)
TEST="$NAME: security of SSL with server certificate"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
testserversec "$N" "$TEST" "$opts -s -lu -d" "ssl:$LOCALHOST:$PORT,pf=ip4,fork,retry=2,verify,cert=testcli.pem,$SOCAT_EGD" "cafile=testsrv.crt" "cafile=testcli.crt" "ssl-l:$PORT,pf=ip4,reuseaddr,$SOCAT_EGD,cafile=testcli.crt,cert=testsrv.crt,key=testsrv.key" 4 tcp "" -1
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=OPENSSLTCP6_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%openssl%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of SSL-L over TCP/IPv6 with RANGE option"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip6,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "range=[::2/128]" "ssl:[::1]:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 6 tcp $PORT -1
fi # ! feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLTCP6_SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%openssl%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of SSL-L over TCP/IPv6 with SOURCEPORT option"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip6,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "sp=$PORT" "ssl:[::1]:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 6 tcp $PORT -1
fi # ! feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLTCP6_LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%openssl%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of SSL-L over TCP/IPv6 with LOWPORT option"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip6,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "lowport" "ssl:[::1]:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 6 tcp $PORT -1
fi # ! feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=OPENSSLTCP6_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%openssl%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of SSL-L over TCP/IPv6 with TCPWRAP option"
if ! feat=$(testaddrs ip6 tcp libwrap openssl) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "ssl-l:$PORT,pf=ip6,reuseaddr,fork,retry=1,$SOCAT_EGD,verify=0,cert=testsrv.crt,key=testsrv.key" "" "tcpwrap-etc=$td" "ssl:[::1]:$PORT,cafile=testsrv.crt,$SOCAT_EGD" 6 tcp $PORT -1
fi # ! feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=OPENSSL_FIPS_SECURITY
case "$TESTS" in
*%functions%*|*%security%*|*%openssl%*|*%fips%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%$NAME%*)
TEST="$NAME: OpenSSL restrictions by FIPS"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testaddrs listen tcp ip4 >/dev/null || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP/IPv4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! testoptions fips >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL/FIPS not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
gentestcert testsrv
gentestcert testcli
# openssl client accepts a "normal" certificate only when not in fips mode
testserversec "$N" "$TEST" "$opts -s" "ssl:$LOCALHOST:$PORT,fork,retry=2,verify,cafile=testsrv.crt" "" "fips" "ssl-l:$PORT,pf=ip4,reuseaddr,cert=testsrv.crt,key=testsrv.key" 4 tcp "" -1
fi ;; # testaddrs
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UNIEXECEOF
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: give exec'd write-only process a chance to flush (-u)"
testod "$N" "$TEST" "" exec:"$OD_C" "$opts -u"
esac
N=$((N+1))


NAME=REVEXECEOF
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: give exec'd write-only process a chance to flush (-U)"
testod "$N" "$TEST" exec:"$OD_C" "-" "$opts -U"
esac
N=$((N+1))


NAME=FILANDIR
case "$TESTS" in
*%filan%*|*%$NAME%*)
TEST="$NAME: check type printed for directories"
te="$td/test$N.stderr"
printf "test $F_n $TEST... " $N
type=$($FILAN -f . 2>$te |tail -n 1 |awk '{print($2);}')
if [ "$type" = "dir" ]; then
    $PRINTF "$OK\n"
   numOK=$((numOK+1))
else
    $PRINTF "$FAILED\n"
    cat "$te"
    numFAIL=$((numFAIL+1))
fi
esac
N=$((N+1))


NAME=FILANSOCKET
case "$TESTS" in
*%filan%*|*%$NAME%*)
TEST="$NAME: capability to analyze named unix socket"
ts="$td/test$N.socket"
te1="$td/test$N.stderr1"	# socat
te2="$td/test$N.stderr2"	# filan
printf "test $F_n $TEST... " $N
$SOCAT unix-l:"$ts" /dev/null </dev/null 2>"$te1" &
spid=$!
waitfile "$ts" 1
type=$($FILAN -f "$ts" 2>$te2 |tail -n 1 |awk '{print($2);}')
if [ "$type" = "socket" ]; then
    $PRINTF "$OK\n"
   numOK=$((numOK+1))
else
    $PRINTF "$FAILED\n"
    cat "$te1"
    cat "$te2"
    numFAIL=$((numFAIL+1))
fi
kill $spid 2>/dev/null
wait
;;
esac
N=$((N+1))


testptywaitslave () {
    local N="$1"
    local TEST="$2"
    local PTYTYPE="$3"	# ptmx or openpty
    local opts="$4"

tp="$td/test$N.pty"
ts="$td/test$N.socket"
tf="$td/test$N.file"
tdiff="$td/test$N.diff"
te1="$td/test$N.stderr1"
te2="$td/test$N.stderr2"
te3="$td/test$N.stderr3"
te4="$td/test$N.stderr4"
da="test$N.1 $(date) $RANDOM"
printf "test $F_n $TEST... " $N
# first generate a pty, then a socket
($SOCAT $opts -lpsocat1 pty,$PTYTYPE,pty-wait-slave,link="$tp" unix-listen:"$ts" 2>"$te1"; rm -f "$tp") 2>/dev/null &
pid=$!
waitfile "$tp"
# if pty was non-blocking, the socket is active, and socat1 will term
$SOCAT $opts -T 10 -lpsocat2 file:/dev/null unix-connect:"$ts" 2>"$te2"
# if pty is blocking, first socat is still active and we get a connection now
#((echo "$da"; sleep 2) |$SOCAT -lpsocat3 $opts - file:"$tp",$PTYOPTS2 >"$tf" 2>"$te3") &
( (waitfile "$ts"; echo "$da"; sleep 1) |$SOCAT -lpsocat3 $opts - file:"$tp",$PTYOPTS2 >"$tf" 2>"$te3") &
waitfile "$ts"
# but we need an echoer on the socket
$SOCAT $opts -lpsocat4 unix:"$ts" echo 2>"$te4"
# now $tf file should contain $da
#kill $pid 2>/dev/null
wait
#
if echo "$da" |diff - "$tf"> "$tdiff"; then
    $PRINTF "$OK\n"
    numOK=$((numOK+1))
else
    $PRINTF "${YELLOW}FAILED${NORMAL}\n"
    cat "$te1"
    #cat "$te2"	# not of interest
    cat "$te3"
    cat "$te4"
    cat "$tdiff"
    numCANT=$((numCANT+1))
fi
}

NAME=PTMXWAITSLAVE
PTYTYPE=ptmx
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: test if master pty ($PTYTYPE) waits for slave connection"
if ! feat=$(testaddrs pty); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions "$PTYTYPE" pty-wait-slave); then
    $PRINTF "test $F_n $TEST... ${YELLOW}option $(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
   testptywaitslave "$N" "$TEST" "$PTYTYPE" "$opts"
fi
esac
N=$((N+1))

NAME=OPENPTYWAITSLAVE
PTYTYPE=openpty
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: test if master pty ($PTYTYPE) waits for slave connection"
if ! feat=$(testaddrs pty); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions "$PTYTYPE" pty-wait-slave); then
    $PRINTF "test $F_n $TEST... ${YELLOW}option $(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
   testptywaitslave "$N" "$TEST" "$PTYTYPE" "$opts"
fi
esac
N=$((N+1))


NAME=CONNECTTIMEOUT
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: test the connect-timeout option"
if ! feat=$(testaddrs tcp); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif ! feat=$(testoptions connect-timeout); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
# we need a hanging connection attempt, guess an address for this
case "$UNAME" in
Linux) HANGIP=1.0.0.1 ;;
*) HANGIP=255.255.255.254 ;;
esac
te1="$td/test$N.stderr1"
tk1="$td/test$N.kill1"
te2="$td/test$N.stderr2"
tk2="$td/test$N.kill2"
$PRINTF "test $F_n $TEST... " $N
# first, try to make socat hang and see if it can be killed
#$SOCAT $opts - tcp:$HANGIP:1 >"$te1" 2>&1 </dev/null &
CMD="$SOCAT $opts - tcp:$HANGIP:1"
$CMD >"$te1" 2>&1 </dev/null &
pid1=$!
sleep 2
if ! kill $pid1 2>"$tk1"; then
    $PRINTF "${YELLOW}does not hang${NORMAL}\n"
    numCANT=$((numCANT+1))
else
# second, set connect-timeout and see if socat exits before kill
$SOCAT $opts - tcp:$HANGIP:1,connect-timeout=1.0 >"$te2" 2>&1 </dev/null &
pid2=$!
sleep 2
if kill $pid2 2>"$tk2"; then
    $PRINTF "$FAILED\n"
    echo "$CMD"
    cat "$te1"
    cat "$te2"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
   numOK=$((numOK+1))
fi
fi
wait
fi ;; # testaddrs
esac
N=$((N+1))


NAME=OPENSSLLISTENDSA
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: openssl listen with DSA certificate"
if ! testaddrs openssl >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}OPENSSL not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
SRVCERT=testsrvdsa
gentestdsacert $SRVCERT
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
CMD2="$SOCAT $opts OPENSSL-LISTEN:$PORT,pf=ip4,reuseaddr,$SOCAT_EGD,cert=$SRVCERT.pem,key=$SRVCERT.key,verify=0 pipe"
CMD="$SOCAT $opts - openssl:$LOCALHOST:$PORT,pf=ip4,verify=0,$SOCAT_EGD"
$PRINTF "test $F_n $TEST... " $N
eval "$CMD2 2>\"${te}1\" &"
pid=$!	# background process id
waittcp4port $PORT
echo "$da" |$CMD >$tf 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED\n"
    echo "$CMD2 &"
    echo "$CMD"
    cat "${te}1"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat ${te}1 ${te}2; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null
wait
fi ;; # testaddrs
esac
PORT=$((PORT+1))
N=$((N+1))


# derive signal number from signal name
# kill -l should provide the info
signum () {
  if [ ! "$BASH_VERSION" ]; then
    # we expect:
    for i in $(kill -l); do echo $i; done |grep -n -i $1 |cut -d: -f1
  else
    # expect:
    # " 1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL"
    signam="$1"
    kill -l </dev/null |
    while read l; do printf "%s %s\n%s %s\n%s %s\n%s %s\n" $l; done |
    grep -e "SIG$signam\$" |
    cut -d ')' -f 1
  fi
}

# problems with QUIT, INT (are blocked in system() )
for signam in TERM ILL; do
NAME=EXITCODESIG$signam
case "$TESTS" in
*%functions%*|*%pty%*|*%$NAME%*)
TEST="$NAME: exit status when dying on SIG$signam"
if ! feat=$(testaddrs pty); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat |tr a-z A-Z) not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
SIG=$(signum $signam)
te="$td/test$N.stderr"
tpp="$td/test$N.ppid"
tp="$td/test$N.pid"
$PRINTF "test $F_n $TEST... " $N
(sleep 1; kill -$SIG $(cat "$tpp")) &
# a simple "system:echo $PPID..." does not work on NetBSD, OpenBSD
#$SOCAT $opts echo system:'exec /bin/bash -c "echo \$PPID '">$tpp"'; echo \$$ '">$tp; read x\"",nofork 2>"$te"; stat=$?
tsh="$td/test$N.sh"
cat <<EOF >"$tsh"
#! /bin/bash
echo \$PPID >"$tpp"
echo \$\$ >"$tp"
read x
EOF
chmod a+x "$tsh"
$SOCAT $opts echo system:"exec \"$tsh\"",pty,setsid,nofork 2>"$te"; stat=$?
sleep 1; kill -INT $(cat $tp)
wait
if [ "$stat" -eq $((128+$SIG)) ]; then
    $PRINTF "$OK\n"
   numOK=$((numOK+1))
else
    $PRINTF "$FAILED\n"
    cat "$te"
    numFAIL=$((numFAIL+1))
fi
wait
fi ;; # feat
esac
N=$((N+1))
done


NAME=READBYTES
#set -vx
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: restrict reading from file with bytes option"
if false; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tr="$td/test$N.ref"
ti="$td/test$N.in"
to="$td/test$N.out"
te="$td/test$N.err"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
# the feature that we really want to test is in the readline.sh script:
CMD="$SOCAT $opts -u open:$ti,readbytes=100 -"
printf "test $F_n $TEST... " $N
rm -f "$tf" "$ti" "$to"
#
echo "AAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAA" >"$tr"	# 100 bytes
cat "$tr" "$tr" >"$ti"			# 200 bytes
$CMD >"$to" 2>"$te"
if ! diff "$tr" "$to" >"$tdiff" 2>&1; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    cat "$te"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi
esac
N=$((N+1))


NAME=UNIXLISTENFORK
case "$TESTS" in
*%functions%*|*%unix%*|*%listen%*|*%fork%*|*%$NAME%*)
TEST="$NAME: UNIX socket keeps listening after child died"
if false; then
    :
else
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N $(date) $RANDOM"
da2="test$N $(date) $RANDOM"
#establish a listening and forking unix socket in background
SRV="$SOCAT $opts -lpserver UNIX-LISTEN:\"$ts\",fork PIPE"
#make a first and a second connection
CLI="$SOCAT $opts -lpclient - UNIX-CONNECT:\"$ts\""
$PRINTF "test $F_n $TEST... " $N
eval "$SRV 2>${te}s &"
pids=$!
waitfile "$ts"
echo "$da1" |eval "$CLI" >"${tf}1" 2>"${te}1"
if [ $? -ne 0 ]; then
    kill "$pids" 2>/dev/null
    $PRINTF "$NO_RESULT (first conn failed):\n"
    echo "$SRV &"
    echo "$CLI"
    cat "${te}s" "${te}1"
    numCANT=$((numCANT+1))
elif ! echo "$da1" |diff - "${tf}1" >"$tdiff"; then
    kill "$pids" 2>/dev/null
    $PRINTF "$NO_RESULT (first conn failed); diff:\n"
    cat "$tdiff"
    numCANT=$((numCANT+1))
else
echo "$da2" |eval "$CLI" >"${tf}2" 2>"${te}2"
rc="$?"; kill "$pids" 2>/dev/null
if [ $rc -ne 0 ]; then
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    echo "$CLI"
    cat "${te}s" "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da2" |diff - "${tf}2" >"$tdiff"; then
    $PRINTF "$FAILED: diff\n"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    numOK=$((numOK+1))
fi # !( $? -ne 0)
fi # !(rc -ne 0)
wait
fi # true
esac
N=$((N+1))


NAME=UNIXTOSTREAM
case "$TESTS" in
*%functions%*|*%unix%*|*%listen%*|*%$NAME%*)
TEST="$NAME: generic UNIX client connects to stream socket"
if false; then
    :
else
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N $(date) $RANDOM"
#establish a listening unix socket in background
SRV="$SOCAT $opts -lpserver UNIX-LISTEN:\"$ts\" PIPE"
#make a connection
CLI="$SOCAT $opts -lpclient - UNIX:\"$ts\""
$PRINTF "test $F_n $TEST... " $N
eval "$SRV 2>${te}s &"
pids=$!
waitfile "$ts"
echo "$da1" |eval "$CLI" >"${tf}1" 2>"${te}1"
if [ $? -ne 0 ]; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    echo "$CLI"
    cat "${te}s" "${te}1"
    numFAIL=$((numFAIL+1))
elif ! echo "$da1" |diff - "${tf}1" >"$tdiff"; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED; diff:\n"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    numOK=$((numOK+1))
fi # !(rc -ne 0)
wait
fi # true
wait
esac
N=$((N+1))


NAME=UNIXTODGRAM
case "$TESTS" in
*%functions%*|*%unix%*|*%recv%*|*%$NAME%*)
TEST="$NAME: generic UNIX client connects to datagram socket"
if false; then
    :
else
ts1="$td/test$N.socket1"
ts2="$td/test$N.socket2"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N $(date) $RANDOM"
#establish a receiving unix datagram socket in background
SRV="$SOCAT $opts -lpserver UNIX-RECVFROM:\"$ts1\" PIPE"
#make a connection
CLI="$SOCAT $opts -lpclient - UNIX:\"$ts1\",bind=\"$ts2\""
#CLI="$SOCAT $opts -lpclient - UNIX:\"$ts1\""
$PRINTF "test $F_n $TEST... " $N
eval "$SRV 2>${te}s &"
pids=$!
waitfile "$ts1"
echo "$da1" |eval "$CLI" >"${tf}1" 2>"${te}1"
if [ $? -ne 0 ]; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CLI"
    cat "${te}1" "${te}1"
    numFAIL=$((numFAIL+1))
elif ! echo "$da1" |diff - "${tf}1" >"$tdiff"; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CLI"
    cat "${te}1"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    numOK=$((numOK+1))
fi # !(rc -ne 0)
wait
fi # true
esac
N=$((N+1))


NAME=EXECPIPESSTDERR
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: simple echo via exec of cat with pipes,stderr"
testecho "$N" "$TEST" "" "exec:$CAT,pipes,stderr" "$opts"
esac
N=$((N+1))


NAME=SIMPLEPARSE
case "$TESTS" in
*%functions%*|*%PARSE%*|*%$NAME%*)
TEST="$NAME: invoke socat from socat"
testecho "$N" "$TEST" "" exec:"$SOCAT - exec\:$CAT,pipes" "$opts"
esac
N=$((N+1))


NAME=FULLPARSE
case "$TESTS" in
*%functions%*|*%parse%*|*%$NAME%*)
TEST="$NAME: correctly parse special chars"
$PRINTF "test $F_n $TEST... " $N
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
# a string where commas are hidden in nesting lexical constructs
# if they are scanned incorrectly, socat will see an "unknown option"
dain='(,)[,]{,}","([),])hugo'
daout='(,)[,]{,},([),])hugo'
"$SOCAT" $opts -u "exec:echo $dain" - >"$tf" 2>"$te"
rc=$?
echo "$daout" |diff "$tf" - >"$tdiff"
if [ "$rc" -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$SOCAT" -u "exec:echo $da" -
    cat "$te"
    numFAIL=$((numFAIL+1))
elif [ -s "$tdiff" ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo diff:
    cat "$tdiff"
    if [ -n "$debug" ]; then cat $te; fi
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$debug" ]; then cat $te; fi
    numOK=$((numOK+1))
fi
esac
N=$((N+1))

NAME=NESTEDSOCATEXEC
case "$TESTS" in
*%parse%*|*%functions%*|*%$NAME%*)
TEST="$NAME: does lexical analysis work sensibly (exec)"
testecho "$N" "$TEST" "" "exec:'$SOCAT - exec:$CAT,pipes'" "$opts" 1
esac
N=$((N+1))

NAME=NESTEDSOCATSYSTEM
case "$TESTS" in
*%parse%*|*%functions%*|*%$NAME%*)
TEST="$NAME: does lexical analysis work sensibly (system)"
testecho "$N" "$TEST" "" "system:\"$SOCAT - exec:$CAT,pipes\"" "$opts" 1
esac
N=$((N+1))


NAME=TCP6BYTCP4
case "$TESTS" in
*%functions%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%$NAME%*)
TEST="$NAME: TCP4 mapped into TCP6 address space"
if ! testaddrs tcp ip6 >/dev/null || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="127.0.0.1:$tsl"
da=$(date)
CMD1="$SOCAT $opts TCP6-listen:$tsl,reuseaddr PIPE"
CMD2="$SOCAT $opts stdin!!stdout TCP6:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid=$!	# background process id
waittcp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED: diff:\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
kill $pid 2>/dev/null; wait
fi
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4DGRAM
case "$TESTS" in
*%functions%*|*%udp%*|*%udp4%*|*%ip4%*|*%dgram%*|*%$NAME%*)
TEST="$NAME: UDP/IPv4 datagram"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
ts1a="127.0.0.1"
ts1="$ts1a:$ts1p"
ts2p=$PORT; PORT=$((PORT+1))
ts2="127.0.0.1:$ts2p"
da=$(date)
CMD1="$SOCAT $opts UDP4-RECVFROM:$ts1p,reuseaddr,bind=$ts1a PIPE"
CMD2="$SOCAT $opts - UDP4-SENDTO:$ts1,bind=$ts2"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1="$!"
waitudp4port $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2="$?"
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6DGRAM
case "$TESTS" in
*%functions%*|*%udp%*|*%udp6%*|*%ip6%*|*%dgram%*|*%$NAME%*)
TEST="$NAME: UDP/IPv6 datagram"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
tsa="[::1]"
ts1="$tsa:$ts1p"
ts2p=$PORT; PORT=$((PORT+1))
ts2="$tsa:$ts2p"
da=$(date)
CMD1="$SOCAT $opts UDP6-RECVFROM:$ts1p,reuseaddr,bind=$tsa PIPE"
CMD2="$SOCAT $opts - UDP6-SENDTO:$ts1,bind=$ts2"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
waitudp6port $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat ${te}1 ${te}2; fi
   numOK=$((numOK+1))
fi
fi ;; # ! feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=RAWIP4RECVFROM
case "$TESTS" in
*%functions%*|*%ip%*|*%ip4%*|*%rawip%*|*%rawip4%*|*%dgram%*|*%root%*|*%$NAME%*)
TEST="$NAME: raw IPv4 datagram"
if [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO; PROTO=$((PROTO+1))
ts1a="127.0.0.1"
ts1="$ts1a:$ts1p"
ts2a="$SECONDADDR"
ts2="$ts2a:$ts2p"
da=$(date)
CMD1="$SOCAT $opts IP4-RECVFROM:$ts1p,reuseaddr,bind=$ts1a PIPE"
CMD2="$SOCAT $opts - IP4-SENDTO:$ts1,bind=$ts2a"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1=$!
waitip4proto $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2=$?
kill $pid1 2>/dev/null;  wait
if [ $rc2 -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi # must be root;;
esac
PORT=$((PORT+1))
N=$((N+1))


if false; then
NAME=RAWIP6RECVFROM
case "$TESTS" in
*%functions%*|*%ip%*|*%ip6%*|*%rawip%*|*%rawip6%*|*%dgram%*|*%root%*|*%$NAME%*)
TEST="$NAME: raw IPv6 datagram by self addressing"
if ! feat=$(testaddrs ip6 rawip) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO; PROTO=$((PROTO+1))
tsa="[::1]"
ts1="$tsa:$ts1p"
ts2="$tsa"
da=$(date)
#CMD1="$SOCAT $opts IP6-RECVFROM:$ts1p,reuseaddr,bind=$tsa PIPE"
CMD2="$SOCAT $opts - IP6-SENDTO:$ts1,bind=$ts2"
printf "test $F_n $TEST... " $N
#$CMD1 2>"${te}1" &
waitip6proto $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
#   echo "$CMD1 &"
#   cat "${te}1"
   echo "$CMD2"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "$te"; fi
   numOK=$((numOK+1))
fi
fi # must be root ;;
esac
PORT=$((PORT+1))
N=$((N+1))
fi #false


NAME=UNIXDGRAM
case "$TESTS" in
*%functions%*|*%unix%*|*%dgram%*|*%$NAME%*)
TEST="$NAME: UNIX datagram"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1="$td/test$N.socket1"
ts2="$td/test$N.socket2"
da=$(date)
CMD1="$SOCAT $opts UNIX-RECVFROM:$ts1,reuseaddr PIPE"
CMD2="$SOCAT $opts - UNIX-SENDTO:$ts1,bind=$ts2"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1="$!"
waitfile $ts1 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2=$?
kill "$pid1" 2>/dev/null; wait
if [ $rc2 -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   cat "${te}1"
   echo "$CMD2"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4RECV
case "$TESTS" in
*%functions%*|*%ip4%*|*%dgram%*|*%udp%*|*%udp4%*|*%recv%*|*%$NAME%*)
TEST="$NAME: UDP/IPv4 receive"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
ts1a="127.0.0.1"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT $opts -u UDP4-RECV:$ts1p,reuseaddr -"
CMD2="$SOCAT $opts -u - UDP4-SENDTO:$ts1"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1="$!"
waitudp4port $ts1p 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
#ls -l $tf
i=0; while [ ! -s "$tf" -a "$i" -lt 10 ]; do  usleep 100000; i=$((i+1));  done
kill "$pid1" 2>/dev/null; wait
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6RECV
case "$TESTS" in
*%functions%*|*%ip6%*|*%dgram%*|*%udp%*|*%udp6%*|*%recv%*|*%$NAME%*)
TEST="$NAME: UDP/IPv6 receive"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
ts1a="[::1]"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT $opts -u UDP6-RECV:$ts1p,reuseaddr -"
CMD2="$SOCAT $opts -u - UDP6-SENDTO:$ts1"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1="$!"
waitudp6port $ts1p 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
#ls -l $tf
i=0; while [ ! -s "$tf" -a "$i" -lt 10 ]; do  usleep 100000; i=$((i+1));  done
kill "$pid1" 2>/dev/null; wait
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi ;; # ! feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=RAWIP4RECV
case "$TESTS" in
*%functions%*|*%ip4%*|*%dgram%*|*%rawip%*|*%rawip4%*|*%recv%*|*%root%*|*%$NAME%*)
TEST="$NAME: raw IPv4 receive"
if [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO; PROTO=$((PROTO+1))
ts1a="127.0.0.1"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT $opts -u IP4-RECV:$ts1p,reuseaddr -"
CMD2="$SOCAT $opts -u - IP4-SENDTO:$ts1"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1="$!"
waitip4proto $ts1p 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
#ls -l $tf
i=0; while [ ! -s "$tf" -a "$i" -lt 10 ]; do  usleep 100000; i=$((i+1));  done
kill "$pid1" 2>/dev/null; wait
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi # must be root ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=RAWIP6RECV
case "$TESTS" in
*%functions%*|*%ip6%*|*%dgram%*|*%rawip%*|*%rawip6%*|*%recv%*|*%root%*|*%$NAME%*)
TEST="$NAME: raw IPv6 receive"
if ! feat=$(testaddrs ip6 rawip) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO; PROTO=$((PROTO+1))
ts1a="[::1]"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT $opts -u IP6-RECV:$ts1p,reuseaddr -"
CMD2="$SOCAT $opts -u - IP6-SENDTO:$ts1"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1="$!"
waitip6proto $ts1p 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
i=0; while [ ! -s "$tf" -a "$i" -lt 10 ]; do  usleep 100000; i=$((i+1));  done
kill "$pid1" 2>/dev/null; wait
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi # must be root ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UNIXRECV
case "$TESTS" in
*%functions%*|*%unix%*|*%dgram%*|*%recv%*|*%$NAME%*)
TEST="$NAME: UNIX receive"
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1="$ts"
da=$(date)
CMD1="$SOCAT $opts -u UNIX-RECV:$ts1,reuseaddr -"
CMD2="$SOCAT $opts -u - UNIX-SENDTO:$ts1"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1="$!"
waitfile $ts1 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
i=0; while [ ! -s "$tf" -a "$i" -lt 10 ]; do  usleep 100000; i=$((i+1));  done
kill "$pid1" 2>/dev/null; wait
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4RECVFROM_SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECVFROM with SOURCEPORT option"
if ! feat=$(testaddrs udp ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "udp4-recvfrom:$PORT,reuseaddr" "" "sp=$PORT" "udp4-sendto:127.0.0.1:$PORT" 4 udp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4RECVFROM_LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECVFROM with LOWPORT option"
if ! feat=$(testaddrs udp ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "udp4-recvfrom:$PORT,reuseaddr" "" "lowport" "udp4-sendto:127.0.0.1:$PORT" 4 udp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4RECVFROM_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECVFROM with RANGE option"
#testserversec "$N" "$TEST" "$opts -s" "udp4-recvfrom:$PORT,reuseaddr,fork" "" "range=$SECONDADDR/32" "udp4-sendto:127.0.0.1:$PORT" 4 udp $PORT 0
testserversec "$N" "$TEST" "$opts -s" "udp4-recvfrom:$PORT,reuseaddr" "" "range=$SECONDADDR/32" "udp4-sendto:127.0.0.1:$PORT" 4 udp $PORT 0
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4RECVFROM_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECVFROM with TCPWRAP option"
if ! feat=$(testaddrs ip4 udp libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
#testserversec "$N" "$TEST" "$opts -s" "udp4-recvfrom:$PORT,reuseaddr,fork" "" "tcpwrap=$d" "udp4-sendto:127.0.0.1:$PORT" 4 udp $PORT 0
testserversec "$N" "$TEST" "$opts -s" "udp4-recvfrom:$PORT,reuseaddr" "" "tcpwrap-etc=$td" "udp4-sendto:127.0.0.1:$PORT" 4 udp $PORT 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4RECV_SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECV with SOURCEPORT option"
if ! feat=$(testaddrs udp ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT; PORT=$((PORT+1))
PORT3=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp4-recv:$PORT1,reuseaddr!!udp4-sendto:127.0.0.1:$PORT2" "" "sp=$PORT3" "udp4-recv:$PORT2!!udp4-sendto:127.0.0.1:$PORT1" 4 udp $PORT1 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4RECV_LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECV with LOWPORT option"
if ! feat=$(testaddrs udp ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp4-recv:$PORT1,reuseaddr!!udp4-sendto:127.0.0.1:$PORT2" "" "lowport" "udp4-recv:$PORT2!!udp4-sendto:127.0.0.1:$PORT1" 4 udp $PORT1 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4RECV_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECV with RANGE option"
if ! feat=$(testaddrs udp ip4) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp4-recv:$PORT1,reuseaddr!!udp4-sendto:127.0.0.1:$PORT2" "" "range=$SECONDADDR/32" "udp4-recv:$PORT2!!udp4-sendto:127.0.0.1:$PORT1" 4 udp $PORT1 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP4RECV_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of UDP4-RECV with TCPWRAP option"
if ! feat=$(testaddrs udp ip4 libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp4-recv:$PORT1,reuseaddr!!udp4-sendto:127.0.0.1:$PORT2" "" "tcpwrap-etc=$td" "udp4-recv:$PORT2!!udp4-sendto:127.0.0.1:$PORT1" 4 udp $PORT1 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6RECVFROM_SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECVFROM with SOURCEPORT option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "udp6-recvfrom:$PORT,reuseaddr" "" "sp=$PORT" "udp6-sendto:[::1]:$PORT" 6 udp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6RECVFROM_LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECVFROM with LOWPORT option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "udp6-recvfrom:$PORT,reuseaddr" "" "lowport" "udp6-sendto:[::1]:$PORT" 6 udp $PORT 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6RECVFROM_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECVFROM with RANGE option"
if ! feat=$(testaddrs tcp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}TCP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
#testserversec "$N" "$TEST" "$opts -s" "udp6-recvfrom:$PORT,reuseaddr,fork" "" "range=[::2/128]" "udp6-sendto:[::1]:$PORT" 6 udp $PORT 0
testserversec "$N" "$TEST" "$opts -s" "udp6-recvfrom:$PORT,reuseaddr" "" "range=[::2/128]" "udp6-sendto:[::1]:$PORT" 6 udp $PORT 0
fi # ! feat
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6RECVFROM_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECVFROM with TCPWRAP option"
if ! feat=$(testaddrs udp ip6 libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
testserversec "$N" "$TEST" "$opts -s" "udp6-recvfrom:$PORT,reuseaddr" "" "tcpwrap-etc=$td" "udp6-sendto:[::1]:$PORT" 6 udp $PORT 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6RECV_SOURCEPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%sourceport%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECV with SOURCEPORT option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT; PORT=$((PORT+1))
PORT3=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp6-recv:$PORT1,reuseaddr!!udp6-sendto:[::1]:$PORT2" "" "sp=$PORT3" "udp6-recv:$PORT2!!udp6-sendto:[::1]:$PORT1" 6 udp $PORT1 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6RECV_LOWPORT
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%lowport%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECV with LOWPORT option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp6-recv:$PORT1,reuseaddr!!udp6-sendto:[::1]:$PORT2" "" "lowport" "udp6-recv:$PORT2!!udp6-sendto:[::1]:$PORT1" 6 udp $PORT1 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6RECV_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECV with RANGE option"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp6-recv:$PORT1,reuseaddr!!udp6-sendto:[::1]:$PORT2" "" "range=[::2/128]" "udp6-recv:$PORT2!!udp6-sendto:[::1]:$PORT1" 6 udp $PORT1 0
fi
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=UDP6RECV_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%udp%*|*%udp6%*|*%ip6%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: security of UDP6-RECV with TCPWRAP option"
if ! feat=$(testaddrs udp ip6 libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
PORT1=$PORT; PORT=$((PORT+1))
PORT2=$PORT
# we use the forward channel (PORT1) for testing, and have a backward channel
# (PORT2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "udp6-recv:$PORT1,reuseaddr!!udp6-sendto:[::1]:$PORT2" "" "tcpwrap-etc=$td" "udp6-recv:$PORT2!!udp6-sendto:[::1]:$PORT1" 6 udp $PORT1 0
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=IP4RECVFROM_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip4%*|*%range%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP4-RECVFROM with RANGE option"
if ! feat=$(testaddrs ip4 rawip) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
#testserversec "$N" "$TEST" "$opts -s" "ip4-recvfrom:$PROTO,reuseaddr,fork" "" "range=$SECONDADDR/32" "ip4-sendto:127.0.0.1:$PROTO" 4 ip $PROTO 0
testserversec "$N" "$TEST" "$opts -s" "ip4-recvfrom:$PROTO,reuseaddr!!udp4-sendto:127.0.0.1:$PORT" "" "range=$SECONDADDR/32" "udp4-recv:$PORT!!ip4-sendto:127.0.0.1:$PROTO" 4 ip $PROTO 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
PORT=$((PORT+1))
N=$((N+1))

NAME=IP4RECVFROM_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip4%*|*%tcpwrap%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP4-RECVFROM with TCPWRAP option"
if ! feat=$(testaddrs ip4 rawip libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
#testserversec "$N" "$TEST" "$opts -s" "ip4-recvfrom:$PROTO,reuseaddr,fork" "" "tcpwrap-etc=$td" "ip4-sendto:127.0.0.1:$PROTO" 4 ip $PROTO 0
testserversec "$N" "$TEST" "$opts -s" "ip4-recvfrom:$PROTO,reuseaddr!!udp4-sendto:127.0.0.1:$PORT" "" "tcpwrap-etc=$td" "udp4-recv:$PORT!!ip4-sendto:127.0.0.1:$PROTO" 4 ip $PROTO 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
PORT=$((PORT+1))
N=$((N+1))


NAME=IP4RECV_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip4%*|*%range%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP4-RECV with RANGE option"
if ! feat=$(testaddrs ip4 rawip) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}IP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PROTO1=$PROTO; PROTO=$((PROTO+1))
PROTO2=$PROTO
# we use the forward channel (PROTO1) for testing, and have a backward channel
# (PROTO2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "ip4-recv:$PROTO1,reuseaddr!!ip4-sendto:127.0.0.1:$PROTO2" "" "range=$SECONDADDR/32" "ip4-recv:$PROTO2!!ip4-sendto:127.0.0.1:$PROTO1" 4 ip $PROTO1 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))



NAME=IP4RECV_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip4%*|*%tcpwrap%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP4-RECV with TCPWRAP option"
if ! feat=$(testaddrs ip4 rawip libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PROTO1=$PROTO; PROTO=$((PROTO+1))
PROTO2=$PROTO
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: $SECONDADDR" >"$ha"
$ECHO "ALL: ALL" >"$hd"
# we use the forward channel (PROTO1) for testing, and have a backward channel
# (PROTO2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "ip4-recv:$PROTO1,reuseaddr!!ip4-sendto:127.0.0.1:$PROTO2" "" "tcpwrap-etc=$td" "ip4-recv:$PROTO2!!ip4-sendto:127.0.0.1:$PROTO1" 4 ip $PROTO1 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))


NAME=IP6RECVFROM_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip6%*|*%range%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP6-RECVFROM with RANGE option"
if ! feat=$(testaddrs ip6 rawip) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
#testserversec "$N" "$TEST" "$opts -s" "ip6-recvfrom:$PROTO,reuseaddr,fork" "" "range=[::2/128]" "ip6-sendto:[::1]:$PROTO" 6 ip $PROTO 0
testserversec "$N" "$TEST" "$opts -s" "ip6-recvfrom:$PROTO,reuseaddr!!udp6-sendto:[::1]:$PORT" "" "range=[::2/128]" "udp6-recv:$PORT!!ip6-sendto:[::1]:$PROTO" 6 ip $PROTO 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
PORT=$((PORT+1))
N=$((N+1))

NAME=IP6RECVFROM_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip6%*|*%tcpwrap%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP6-RECVFROM with TCPWRAP option"
if ! feat=$(testaddrs ip6 rawip libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
#testserversec "$N" "$TEST" "$opts -s" "ip6-recvfrom:$PROTO,reuseaddr,fork" "" "tcpwrap-etc=$td" "ip6-sendto:[::1]:$PROTO" 6 ip $PROTO 0
testserversec "$N" "$TEST" "$opts -s" "ip6-recvfrom:$PROTO,reuseaddr!!udp6-sendto:[::1]:$PORT" "" "tcpwrap-etc=$td" "udp6-recv:$PORT!!ip6-sendto:[::1]:$PROTO" 6 ip $PROTO 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
PORT=$((PORT+1))
N=$((N+1))


NAME=IP6RECV_RANGE
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip6%*|*%range%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP6-RECV with RANGE option"
if ! feat=$(testaddrs ip6 rawip) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}raw IP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PROTO1=$PROTO; PROTO=$((PROTO+1))
PROTO2=$PROTO
# we use the forward channel (PROTO1) for testing, and have a backward channel
# (PROTO2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "ip6-recv:$PROTO1,reuseaddr!!ip6-sendto:[::1]:$PROTO2" "" "range=[::2/128]" "ip6-recv:$PROTO2!!ip6-sendto:[::1]:$PROTO1" 6 ip $PROTO1 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))

NAME=IP6RECV_TCPWRAP
case "$TESTS" in
*%functions%*|*%security%*|*%ip%*|*%ip6%*|*%tcpwrap%*|*%root%*|*%$NAME%*)
TEST="$NAME: security of IP6-RECV with TCPWRAP option"
if ! feat=$(testaddrs ip6 rawip libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
PROTO1=$PROTO; PROTO=$((PROTO+1))
PROTO2=$PROTO
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat: [::2]" >"$ha"
$ECHO "ALL: ALL" >"$hd"
# we use the forward channel (PROTO1) for testing, and have a backward channel
# (PROTO2) to get the data back, so we get the classical echo behaviour
testserversec "$N" "$TEST" "$opts -s" "ip6-recv:$PROTO1,reuseaddr!!ip6-sendto:[::1]:$PROTO2" "" "tcpwrap-etc=$td" "ip6-recv:$PROTO2!!ip6-sendto:[::1]:$PROTO1" 6 ip $PROTO1 0
fi # not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))


NAME=O_NOATIME_FILE
case "$TESTS" in
*%functions%*|*%open%*|*%noatime%*|*%$NAME%*)
TEST="$NAME: option O_NOATIME on file"
# idea: create a file with o-noatime option; one second later create a file
# without this option (using touch); one second later read from the first file.
# Then we check which file has the later ATIME stamp. For this check we use
# "ls -ltu" because it is more portable than "test ... -nt ..."
if ! testoptions o-noatime >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}o-noatime not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.file"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
$PRINTF "test $F_n $TEST... " $N
CMD="$SOCAT $opts -u open:\"${tf}1\",o-noatime /dev/null"
# generate a file
touch "${tf}1"
sleep 1
# generate a reference file
touch "${tf}2"
sleep 1
# read from the first file
$CMD 2>"$te"
if [ $? -ne 0 ]; then # command failed
    $PRINTF "${FAILED}:\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
# check which file has a later atime stamp
if [ $(ls -ltu "${tf}1" "${tf}2" |head -1 |sed 's/.* //') != "${tf}2" ];
then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD"
   cat "$te"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "$te"; fi
   numOK=$((numOK+1))
fi # wrong time stamps
fi # command ok
fi ;; # not feats
esac
N=$((N+1))

NAME=O_NOATIME_FD
case "$TESTS" in
*%functions%*|*%noatime%*|*%$NAME%*)
TEST="$NAME: option O_NOATIME on file descriptor"
# idea: use a fd of a file with o-noatime option; one second later create a file
# without this option (using touch); one second later read from the first file.
# Then we check which file has the later ATIME stamp. For this check we use
# "ls -ltu" because it is more portable than "test ... -nt ..."
if ! testoptions o-noatime >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}o-noatime not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.file"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da=$(date)
$PRINTF "test $F_n $TEST... " $N
touch ${tf}1
CMD="$SOCAT $opts -u -,o-noatime /dev/null <${tf}1"
# generate a file, len >= 1
touch "${tf}1"
sleep 1
# generate a reference file
touch "${tf}2"
sleep 1
# read from the first file
sh -c "$CMD" 2>"$te"
if [ $? -ne 0 ]; then # command failed
    $PRINTF "${FAILED}:\n"
    echo "$CMD"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
# check which file has a later atime stamp
if [ $(ls -ltu "${tf}1" "${tf}2" |head -1 |sed 's/.* //') != "${tf}2" ];
then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD"
   cat "$te"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "$te"; fi
   numOK=$((numOK+1))
fi # wrong time stamps
fi # command ok
fi ;; # not feats
esac
N=$((N+1))

NAME=EXT2_NOATIME
case "$TESTS" in
*%functions%*|*%ext2%*|*%noatime%*|*%$NAME%*)
TEST="$NAME: extended file system options using ext2fs noatime option"
# idea: create a file with ext2-noatime option; one second later create a file
# without this option (using touch); one second later read from the first file.
# Then we check which file has the later ATIME stamp. For this check we use
# "ls -ltu" because it is more portable than "test ... -nt ..."
if ! testoptions ext2-noatime >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}ext2-noatime not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ts="$td/test$N.socket"
tf="$td/test$N.file"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1="$ts"
da=$(date)
$PRINTF "test $F_n $TEST... " $N
CMD0="$SOCAT $opts -u /dev/null create:\"${tf}1\""
CMD="$SOCAT $opts -u /dev/null create:\"${tf}1\",ext2-noatime"
# check if this is a capable FS; lsattr does other things on AIX, thus socat
$CMD0 2>"${te}0"
if [ $? -ne 0 ]; then
    $PRINTF "${YELLOW} cannot test${NORMAL}\n"
    numCANT=$((numCANT+1))
else
# generate a file with noatime, len >= 1
$CMD 2>"$te"
if [ $? -ne 0 ]; then # command failed
    $PRINTF "${YELLOW}impotent file system?${NORMAL}\n"
    echo "$CMD"
    cat "$te"
    numCANT=$((numCANT+1))
else
sleep 1
# generate a reference file
touch "${tf}2"
sleep 1
# read from the first file
cat "${tf}1" >/dev/null
# check which file has a later atime stamp
#if [ $(ls -ltu "${tf}1" "${tf}2" |head -n 1 |awk '{print($8);}') != "${tf}2" ];
if [ $(ls -ltu "${tf}1" "${tf}2" |head -n 1 |sed "s|.*\\($td.*\\)|\1|g") != "${tf}2" ];
then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD"
   cat "$te"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "$te"; fi
   numOK=$((numOK+1))
fi
fi # not impotent
fi # can test
fi ;; # not feats
esac
N=$((N+1))


NAME=COOLWRITE
case "$TESTS" in
*%functions%*|*%timeout%*|*%ignoreeof%*|*%$NAME%*)
TEST="$NAME: option cool-write"
if ! testoptions cool-write >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}option cool-write not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
#set -vx
ti="$td/test$N.pipe"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date) $RANDOM"
# a reader that will terminate after 1 byte
CMD1="$SOCAT $opts -u pipe:\"$ti\",readbytes=1 /dev/null"
CMD="$SOCAT $opts -u - file:\"$ti\",cool-write"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
bg=$!	# background process id
sleep 1
(echo .; sleep 1; echo) |$CMD 2>"$te"
rc=$?
kill $bg 2>/dev/null; wait
if [ $rc -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD &"
    cat "$te"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "$te"; fi
   numOK=$((numOK+1))
fi
fi # testoptions
esac
N=$((N+1))


NAME=TCP4ENDCLOSE
case "$TESTS" in
*%functions%*|*%ip4%*|*%ipapp%*|*%tcp%*|*%$NAME%*)
TEST="$NAME: end-close keeps TCP V4 socket open"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
p1=$PORT; PORT=$((PORT+1))
p2=$PORT
da1a="$(date) $RANDOM"
da1b="$(date) $RANDOM"
CMD1="$SOCAT $opts -u - TCP4-CONNECT:$LOCALHOST:$p1"
CMD="$SOCAT $opts -U TCP4:$LOCALHOST:$p2,end-close TCP4-LISTEN:$p1,bind=$LOCALHOST,reuseaddr,fork"
CMD3="$SOCAT $opts -u TCP4-LISTEN:$p2,reuseaddr,bind=$LOCALHOST -"
printf "test $F_n $TEST... " $N
$CMD3 >"$tf" 2>"${te}3" &
pid3=$!
waittcp4port $p2 1
$CMD 2>"${te}2" &
pid2=$!
waittcp4port $p1 1
echo "$da1a" |$CMD1 2>>"${te}1a"
echo "$da1b" |$CMD1 2>>"${te}1b"
sleep 1
kill "$pid3" "$pid2" 2>/dev/null
wait
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1a" "${te}1b" "${te}2" "${te}3"
    numFAIL=$((numFAIL+1))
elif ! echo -e "$da1a\n$da1b" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   cat "${te}1a" "${te}1b" "${te}2" "${te}3"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1a" "${te}1b" "${te}2" "${te}3"; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=EXECENDCLOSE
case "$TESTS" in
*%functions%*|*%exec%*|*%$NAME%*)
TEST="$NAME: end-close keeps EXEC child running"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
ts="$td/test$N.sock"
tdiff="$td/test$N.diff"
da1a="$(date) $RANDOM"
da1b="$(date) $RANDOM"
CMD1="$SOCAT $opts - UNIX-CONNECT:$ts"
CMD="$SOCAT -t0.1 $opts EXEC:"$CAT",end-close UNIX-LISTEN:$ts,fork"
printf "test $F_n $TEST... " $N
$CMD 2>"${te}2" &
pid2=$!
waitfile $ts 1
echo "$da1a" |$CMD1 2>>"${te}1a" >"$tf"
usleep 100000
echo "$da1b" |$CMD1 2>>"${te}1b" >>"$tf"
usleep 100000
kill "$pid2" 2>/dev/null
wait
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1a" "${te}1b" "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo -e "$da1a\n$da1b" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   cat "${te}1a" "${te}1b" "${te}2"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1a" "${te}1b" "${te}2"; fi
   numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCP4RANGEMASK
case "$TESTS" in
*%functions%*|*%security%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%range%*|*%$NAME%*)
TEST="$NAME: security of TCP4-L with RANGE option"
if [ "$UNAME" != Linux ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}only on Linux${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
testserversec "$N" "$TEST" "$opts -s" "tcp4-l:$PORT,reuseaddr,fork,retry=1" "" "range=127.0.0.0:255.255.0.0" "tcp4:127.1.0.0:$PORT" 4 tcp $PORT 0
fi ;; # Linux
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP6LISTENBIND
# this tests for a bug in (up to) 1.5.0.0:
#    with upd*-listen, the bind option supported only IPv4
case "$TESTS" in
*%functions%*|*%bugs%*|*%ip6%*|*%ipapp%*|*%udp%*|*%$NAME%*)
TEST="$NAME: UDP6-LISTEN with bind"
if ! feat=$(testaddrs udp ip6) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}UDP6 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tsl=$PORT
ts="$LOCALHOST6:$tsl"
da=$(date)
CMD1="$SOCAT $opts UDP6-LISTEN:$tsl,reuseaddr,bind=$LOCALHOST6 PIPE"
CMD2="$SOCAT $opts - UDP6:$ts"
printf "test $F_n $TEST... " $N
$CMD1 >"$tf" 2>"${te}1" &
pid1=$!
waitudp6port $tsl 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2=$?
kill $pid1 2>/dev/null; wait
if [ $rc2 -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1" "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
fi ;; # ! testaddrs
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCPWRAPPERS_MULTIOPTS
# this tests for a bug in 1.5.0.0 that let socat fail when more than one 
# tcp-wrappers related option was specified in one address
case "$TESTS" in
*%functions%*|*%bugs%*|*%tcp%*|*%tcp4%*|*%ip4%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: use of multiple tcpwrapper enabling options"
if ! feat=$(testaddrs tcp ip4 libwrap) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date) $RANDOM"
ha="$td/hosts.allow"
$ECHO "test : ALL : allow" >"$ha"
CMD1="$SOCAT $opts TCP4-LISTEN:$PORT,reuseaddr,hosts-allow=$a,tcpwrap=test pipe"
CMD2="$SOCAT $opts - TCP:$LOCALHOST:$PORT"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
waittcp4port $PORT
echo "$da" |$CMD2 >"$tf" 2>"${te}2"
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=TCPWRAPPERS_TCP6ADDR
# this tests for a bug in 1.5.0.0 that brought false results with tcp-wrappers
# and IPv6 when 
case "$TESTS" in
*%functions%*|*%bugs%*|*%tcp%*|*%tcp6%*|*%ip6%*|*%tcpwrap%*|*%$NAME%*)
TEST="$NAME: specification of TCP6 address in hosts.allow"
if ! feat=$(testaddrs tcp ip6 libwrap) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da="$(date) $RANDOM"
ha="$td/hosts.allow"
hd="$td/hosts.deny"
$ECHO "socat : [::1] : allow" >"$ha"
$ECHO "ALL : ALL : deny" >"$hd"
CMD1="$SOCAT $opts TCP6-LISTEN:$PORT,reuseaddr,tcpwrap-etc=$td pipe"
CMD2="$SOCAT $opts - TCP6:[::1]:$PORT"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1=$!
waittcp6port $PORT
echo "$da" |$CMD2 >"$tf" 2>"${te}2"
kill $pid1 2>/dev/null; wait
if [ $? -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat "${te}1" "${te}2"; fi
   numOK=$((numOK+1))
fi
fi ;; # feat
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=UDP4BROADCAST
case "$TESTS" in
*%functions%*|*%udp%*|*%udp4%*|*%ip4%*|*%dgram%*|*%broadcast%*|*%$NAME%*)
TEST="$NAME: UDP/IPv4 broadcast"
if [ -z "$BCADDR" ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}dont know a broadcast address${NORMAL}\n" $N
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
#ts1="$BCADDR/8:$ts1p"
ts1="$BCADDR:$ts1p"
ts2p=$PORT; PORT=$((PORT+1))
ts2="$BCIFADDR:$ts2p"
da=$(date)
CMD1="$SOCAT $opts UDP4-RECVFROM:$ts1p,reuseaddr,broadcast PIPE"
#CMD2="$SOCAT $opts - UDP4-BROADCAST:$ts1"
CMD2="$SOCAT $opts - UDP4-DATAGRAM:$ts1,broadcast"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1="$!"
waitudp4port $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2="$?"
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    echo "$CMD2"
    cat "${te}1"
    cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED\n"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$tut" ]; then
	echo "$CMD1 &"
	echo "$CMD2"
    fi
    if [ -n "$debug" ]; then cat $te; fi
    numOK=$((numOK+1))
fi
fi ;; # feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=IP4BROADCAST
# test a local broadcast of a raw IPv4 protocol.
# because we receive - in addition to the regular reply - our own broadcast,
# we use a token XXXX that is changed to YYYY in the regular reply packet.
case "$TESTS" in
*%functions%*|*%rawip%*|*%rawip4%*|*%ip4%*|*%dgram%*|*%broadcast%*|*%root%*|*%$NAME%*)
TEST="$NAME: raw IPv4 broadcast"
if ! feat=$(testaddrs ip4 rawip) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}raw IP4 not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ -z "$BCADDR" ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}dont know a broadcast address${NORMAL}\n" $N
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO
#ts1="$BCADDR/8:$ts1p"
ts1="$BCADDR:$ts1p"
ts2p=$ts1p
ts2="$BCIFADDR"
da="$(date) $RANDOM XXXX"
sh="$td/test$N-sed.sh"
echo 'sed s/XXXX/YYYY/' >"$sh"
chmod a+x "$sh"
CMD1="$SOCAT $opts IP4-RECVFROM:$ts1p,reuseaddr,broadcast exec:$sh"
#CMD2="$SOCAT $opts - IP4-BROADCAST:$ts1"
CMD2="$SOCAT $opts - IP4-DATAGRAM:$ts1,broadcast"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1="$!"
waitip4port $ts1p 1
echo "$da" |$CMD2 2>>"${te}2" |grep -v XXXX >>"$tf"
rc2="$?"
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    echo "$CMD2"
    cat "${te}1"
    cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" | sed 's/XXXX/YYYY/'|diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED\n"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$debug" ]; then cat $te; fi
    numOK=$((numOK+1))
fi
fi ;; # not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))


#NAME=UDP4BROADCAST_RANGE
#case "$TESTS" in
#*%functions%*|*%security%*|*%udp%*|*%udp4%*|*%ip4%*|*%dgram%*|*%broadcast%*|*%range%*|*%$NAME%*)
#TEST="$NAME: security of UDP4-BROADCAST with RANGE option"
#if [ -z "$BCADDR" ]; then
#    $PRINTF "test $F_n $TEST... ${YELLOW}dont know a broadcast address${NORMAL}\n" $N
#else
#testserversec "$N" "$TEST" "$opts -s" "UDP4-BROADCAST:$BCADDR/8:$PORT" "" "range=127.1.0.0:255.255.0.0" "udp4:127.1.0.0:$PORT" 4 udp $PORT 0
#fi ;; # feats
#esac
#PORT=$((PORT+1))
#N=$((N+1))


NAME=UDP4MULTICAST_UNIDIR
case "$TESTS" in
*%functions%*|*%udp%*|*%udp4%*|*%ip4%*|*%dgram%*|*%multicast%*|*%$NAME%*)
TEST="$NAME: UDP/IPv4 multicast, send only"
if ! feat=$(testaddrs ip4 udp) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
ts1a="$SECONDADDR"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT -u $opts UDP4-RECV:$ts1p,reuseaddr,ip-add-membership=224.255.255.254:$ts1a -"
CMD2="$SOCAT -u $opts - UDP4-SENDTO:224.255.255.254:$ts1p,bind=$ts1a"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1"  >"${tf}" &
pid1="$!"
waitudp4port $ts1p 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
usleep $MICROS
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi ;;  # not feats
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=IP4MULTICAST_UNIDIR
case "$TESTS" in
*%functions%*|*%rawip%*|*%ip4%*|*%dgram%*|*%multicast%*|*%root%*|*%$NAME%*)
TEST="$NAME: IPv4 multicast"
if ! feat=$(testaddrs ip4 rawip) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO
ts1a="$SECONDADDR"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT -u $opts IP4-RECV:$ts1p,reuseaddr,ip-add-membership=224.255.255.254:$ts1a -"
CMD2="$SOCAT -u $opts - IP4-SENDTO:224.255.255.254:$ts1p,bind=$ts1a"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1"  >"${tf}" &
pid1="$!"
waitip4proto $ts1p 1
usleep $MICROS
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
usleep $MICROS
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi ;;  # not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))

if false; then
NAME=UDP6MULTICAST_UNIDIR
case "$TESTS" in
*%functions%*|*%udp%*|*%udp6%*|*%ip6%*|*%dgram%*|*%multicast%*|*%$NAME%*)
TEST="$NAME: UDP/IPv6 multicast"
if ! feat=$(testaddrs ip6 udp) || ! runsip6 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
if1="$MCINTERFACE"
ts1a="[::1]"
da=$(date)
CMD1="$SOCAT -u $opts UDP6-RECV:$ts1p,reuseaddr,ipv6-join-group=[ff02::2]:$if1 -"
CMD2="$SOCAT -u $opts - UDP6-SENDTO:[ff02::2]:$ts1p,bind=$ts1a"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1"  >"${tf}" &
pid1="$!"
waitudp6port $ts1p 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
usleep $MICROS
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
   numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
   numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi ;; # not feats
esac
PORT=$((PORT+1))
N=$((N+1))
fi # false

NAME=UDP4MULTICAST_BIDIR
case "$TESTS" in
*%functions%*|*%udp%*|*%udp4%*|*%ip4%*|*%dgram%*|*%multicast%*|*%$NAME%*)
TEST="$NAME: UDP/IPv4 multicast, with reply"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PORT; PORT=$((PORT+1))
ts1a="$SECONDADDR"
ts1="$ts1a:$ts1p"
ts2p=$PORT; PORT=$((PORT+1))
ts2="$BCIFADDR:$ts2p"
da=$(date)
CMD1="$SOCAT $opts UDP4-RECVFROM:$ts1p,reuseaddr,ip-add-membership=224.255.255.254:$ts1a PIPE"
#CMD2="$SOCAT $opts - UDP4-MULTICAST:224.255.255.254:$ts1p,bind=$ts1a"
CMD2="$SOCAT $opts - UDP4-DATAGRAM:224.255.255.254:$ts1p,bind=$ts1a"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1="$!"
waitudp4port $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2="$?"
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    echo "$CMD2"
    cat "${te}1"
    cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED\n"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$tut" ]; then
	echo "$CMD1 &"
	echo "$CMD2"
    fi
    if [ -n "$debug" ]; then cat $te; fi
    numOK=$((numOK+1))
fi ;;
esac
PORT=$((PORT+1))
N=$((N+1))

NAME=IP4MULTICAST_BIDIR
case "$TESTS" in
*%functions%*|*%rawip%*|*%ip4%*|*%dgram%*|*%multicast%*|*%root%*|*%$NAME%*)
TEST="$NAME: IPv4 multicast, with reply"
if ! feat=$(testaddrs ip4 rawip) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1p=$PROTO
ts1a="$SECONDADDR"
ts1="$ts1a:$ts1p"
da=$(date)
CMD1="$SOCAT $opts IP4-RECVFROM:$ts1p,reuseaddr,ip-add-membership=224.255.255.254:$ts1a PIPE"
#CMD2="$SOCAT $opts - IP4-MULTICAST:224.255.255.254:$ts1p,bind=$ts1a"
CMD2="$SOCAT $opts - IP4-DATAGRAM:224.255.255.254:$ts1p,bind=$ts1a"
printf "test $F_n $TEST... " $N
$CMD1 2>"${te}1" &
pid1="$!"
waitip4port $ts1p 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2="$?"
kill "$pid1" 2>/dev/null; wait;
if [ "$rc2" -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1 &"
    echo "$CMD2"
    cat "${te}1"
    cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED\n"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$tut" ]; then
	echo "$CMD1 &"
	echo "$CMD2"
    fi
    if [ -n "$debug" ]; then cat $te; fi
    numOK=$((numOK+1))
fi
fi ;;	# not feats, not root
esac
PROTO=$((PROTO+1))
N=$((N+1))


NAME=TUNREAD
case "$TESTS" in
*%functions%*|*%tun%*|*%root%*|*%$NAME%*)
TEST="$NAME: reading data sent through tun interface"
#idea: create a TUN interface and send a datagram to one of the addresses of
# its virtual network. On the tunnel side, read the packet and compare its last
# bytes with the datagram payload
if ! feat=$(testaddrs ip4 tun) || ! runsip4 >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
elif [ $(id -u) -ne 0 -a "$withroot" -eq 0 ]; then
    $PRINTF "test $F_n $TEST... ${YELLOW}must be root${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
tl="$td/test$N.lock"
da="$(date) $RANDOM"
dalen=$((${#da}+1))
TUNNET=10.255.255
CMD1="$SOCAT $opts -u - UDP4-SENDTO:$TUNNET.2:$PORT"
#CMD="$SOCAT $opts -u -L $tl TUN,ifaddr=$TUNNET.1,netmask=255.255.255.0,iff-up=1 -"
CMD="$SOCAT $opts -u -L $tl TUN:$TUNNET.1/24,iff-up=1 -"
printf "test $F_n $TEST... " $N
$CMD 2>"${te}" |tail --bytes=$dalen >"${tf}" &
sleep 1
echo "$da" |$CMD1 2>"${te}1"
sleep 1
kill "$(cat $tl)" 2>/dev/null
wait
if [ $? -ne 0 ]; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD &"
    echo "$CMD1"
    cat "${te}" "${te}1"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED\n"
    cat "$tdiff"
    cat "${te}" "${te}1"
    numFAIL=$((numFAIL+1))
else
    $PRINTF "$OK\n"
    if [ -n "$debug" ]; then cat "${te}" "${te}1"; fi
    numOK=$((numOK+1))
fi
fi ;; # not feats, not root
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=ABSTRACTSTREAM
case "$TESTS" in
*%functions%*|*%unix%*|*%abstract%*|*%connect%*|*%listen%*|*%$NAME%*)
TEST="$NAME: abstract UNIX stream socket, listen and connect"
if ! feat=$(testaddrs abstract-unixsocket); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
da1="test$N $(date) $RANDOM"
#establish a listening abstract unix socket
SRV="$SOCAT $opts -lpserver ABSTRACT-LISTEN:\"$ts\" PIPE"
#make a connection
CMD="$SOCAT $opts - ABSTRACT-CONNECT:$ts"
$PRINTF "test $F_n $TEST... " $N
touch "$ts"	# make a file with same name, so non-abstract fails
eval "$SRV 2>${te}s &"
pids=$!
#waitfile "$ts"
sleep 1
echo "$da1" |eval "$CMD" >"${tf}1" 2>"${te}1"
if [ $? -ne 0 ]; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CMD"
    cat "${te}1"
    numFAIL=$((numFAIL+1))
elif ! echo "$da1" |diff - "${tf}1" >"$tdiff"; then
    kill "$pids" 2>/dev/null
    $PRINTF "$FAILED:\n"
    echo "$SRV &"
    cat "${te}s"
    echo "$CMD"
    cat "${te}1"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi # !(rc -ne 0)
wait
fi ;; # not feats
esac
N=$((N+1))


NAME=ABSTRACTDGRAM
case "$TESTS" in
*%functions%*|*%unix%*|*%abstract%*|*%dgram%*|*%$NAME%*)
TEST="$NAME: abstract UNIX datagram"
if ! feat=$(testaddrs abstract-unixsocket); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1="$td/test$N.socket1"
ts2="$td/test$N.socket2"
da=$(date)
CMD1="$SOCAT $opts ABSTRACT-RECVFROM:$ts1,reuseaddr PIPE"
#CMD2="$SOCAT $opts - ABSTRACT-SENDTO:$ts1,bind=$ts2"
CMD2="$SOCAT $opts - ABSTRACT-SENDTO:$ts1,bind=$ts2"
printf "test $F_n $TEST... " $N
touch "$ts1"	# make a file with same name, so non-abstract fails
$CMD1 2>"${te}1" &
pid1="$!"
sleep 1
echo "$da" |$CMD2 >>"$tf" 2>>"${te}2"
rc2=$?
kill "$pid1" 2>/dev/null; wait
if [ $rc2 -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   cat "${te}1"
   echo "$CMD2"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi ;; # not feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=ABSTRACTRECV
case "$TESTS" in
*%functions%*|*%unix%*|*%abstract%*|*%dgram%*|*%recv%*|*%$NAME%*)
TEST="$NAME: abstract UNIX datagram receive"
if ! feat=$(testaddrs abstract-unixsocket); then
    $PRINTF "test $F_n $TEST... ${YELLOW}$feat not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
ts="$td/test$N.socket"
tf="$td/test$N.stdout"
te="$td/test$N.stderr"
tdiff="$td/test$N.diff"
ts1="$ts"
da=$(date)
CMD1="$SOCAT $opts -u ABSTRACT-RECV:$ts1,reuseaddr -"
CMD2="$SOCAT $opts -u - ABSTRACT-SENDTO:$ts1"
printf "test $F_n $TEST... " $N
touch "$ts1"	# make a file with same name, so non-abstract fails
$CMD1 >"$tf" 2>"${te}1" &
pid1="$!"
#waitfile $ts1 1
sleep 1
echo "$da" |$CMD2 2>>"${te}2"
rc2="$?"
i=0; while [ ! -s "$tf" -a "$i" -lt 10 ]; do  usleep 100000; i=$((i+1));  done
kill "$pid1" 2>/dev/null; wait
if [ "$rc2" -ne 0 ]; then
   $PRINTF "$FAILED: $SOCAT:\n"
   echo "$CMD1 &"
   echo "$CMD2"
   cat "${te}1"
   cat "${te}2"
    numFAIL=$((numFAIL+1))
elif ! echo "$da" |diff - "$tf" >"$tdiff"; then
   $PRINTF "$FAILED\n"
   cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi ;; # not feats
esac
PORT=$((PORT+1))
N=$((N+1))


NAME=OPENSSLREAD
# socat determined availability of data using select(). With openssl, the
# following situation might occur:
# a SSL data block with more than 8192 bytes (socats default blocksize) 
# arrives; socat calls SSL_read, and the SSL routine reads the complete block.
# socat then reads 8192 bytes from the SSL layer, the rest remains buffered.
# If the TCP connection stays idle for some time, the data in the SSL layer
# keeps there and is not transferred by socat until the socket indicates more
# data or EOF.
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: socat handles data buffered by openssl"
#idea: have a socat process (server) that gets an SSL block that is larger than
# socat transfer block size; keep the socket connection open and kill the
# server process after a short time; if not the whole data block has been
# transferred, the test has failed.
if ! feat=$(testaddrs openssl) >/dev/null; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tf="$td/test$N.out"
te="$td/test$N.err"
tdiff="$td/test$N.diff"
da="$(date) $RANDOM"
SRVCERT=testsrv
gentestcert "$SRVCERT"
CMD1="$SOCAT $opts -u -T 1 -b $($ECHO "$da\c" |wc -c) OPENSSL-LISTEN:$PORT,reuseaddr,cert=$SRVCERT.pem,verify=0 -"
CMD2="$SOCAT $opts -u - OPENSSL-CONNECT:$LOCALHOST:$PORT,verify=0"
printf "test $F_n $TEST... " $N
#
$CMD1 2>"${te}1" >"$tf" &
pid=$!	# background process id
waittcp4port $PORT
(echo "$da"; sleep 2) |$CMD2 2>"${te}2"
if ! echo "$da" |diff - "$tf" >"$tdiff"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD1"
    cat "${te}1"
    echo "$CMD2"
    cat "${te}2"
    cat "$tdiff"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi
wait ;;
esac
N=$((N+1))


# test: there is a bug with the readbytes option: when the socket delivered
# exacly that many bytes as specified with readbytes and the stays idle (no
# more data, no EOF), socat waits for more data instead of generating EOF on
# this in put stream.
NAME=READBYTES_EOF
#set -vx
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: trigger EOF after that many bytes, even when socket idle"
#idea: we deliver that many bytes to socat; the process should terminate then.
# we try to transfer data in the other direction then; if transfer succeeds,
# the process did not terminate and the bug is still there.
if false; then
    $PRINTF "test $F_n $TEST... ${YELLOW}$(echo $feat| tr 'a-z' 'A-Z') not available${NORMAL}\n" $N
    numCANT=$((numCANT+1))
else
tr="$td/test$N.ref"
ti="$td/test$N.in"
to="$td/test$N.out"
te="$td/test$N.err"
tdiff="$td/test$N.diff"
da="$(date)" da="$da$($ECHO '\r')"
CMD="$SOCAT $opts system:\"echo A; sleep 2\",readbytes=2!!- -!!/dev/null"
printf "test $F_n $TEST... " $N
(sleep 1; echo) |eval "$CMD" >"$to" 2>"$te"
if test -s "$to"; then
    $PRINTF "$FAILED: $SOCAT:\n"
    echo "$CMD"
    numFAIL=$((numFAIL+1))
else
   $PRINTF "$OK\n"
   if [ -n "$debug" ]; then cat $te; fi
   numOK=$((numOK+1))
fi
fi
esac
N=$((N+1))

echo "summary: $((N-1)) tests; $numOK ok, $numFAIL failed, $numCANT could not be performed"

if [ "$numFAIL" -gt 0 ]; then
    exit 1
fi
exit 0

#==============================================================================

rm -f testsrv.* testcli.* testsrvdsa* testsrvfips* testclifips*

# end

# too dangerous - run as root and having a shell problem, it might purge your
# file systems 
#rm -r "$td"

# sometimes subprocesses hang; we want to see this
wait

exit

# template
NAME=!!!
case "$TESTS" in
*%functions%*|*%$NAME%*)
TEST="$NAME: !!!"
printf "test $F_n $TEST... " $N
!!!
if [ !!! ]; then
    $PRINTF "$OK\n"
else
    $PRINTF "$FAILED\n"
    cat "$te"
fi
esac
N=$((N+1))


TEST="$NAME: transferring from one file to another with echo"
tf1="$td/file$N.input"
tf2="$td/file$N.output"
testecho "$N" "$TEST" "" "echo" "$opts"


# MANUAL TESTS

# ZOMBIES
#   have httpd on PORT/tcp
#   nice -20 $SOCAT -d tcp-l:24080,fork tcp:$LOCALHOST:PORT
#   i=0; while [ $i -lt 100 ]; do $ECHO 'GET / HTTP/1.0\n' |$SOCAT -t -,ignoreeof tcp:$LOCALHOST:24080 >/dev/null& i=$((i+1)); done
