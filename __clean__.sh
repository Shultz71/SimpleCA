#!/bin/bash
# vim: nu ts=4 sw=4 expandtab ignorecase nowrap 

. /etc/simpleca.conf 2>/dev/null

/bin/rm /etc/simpleca.conf 2>/dev/null

MYDIR="${CADIR-xxx}"

if [ -d "${MYDIR}" ] ; then
    echo " MYDIR = ${MYDIR- }"
    echo -n "To delete ${MYDIR} press [ENTER] ..."; read
    /bin/rm -rf ${MYDIR}
fi

