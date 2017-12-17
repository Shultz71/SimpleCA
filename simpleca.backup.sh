#!/bin/bash
# vim: nu ts=4 sw=4 expandtab ignorecase nowrap
MYDEBUG=1   # debug ON  to disable comment out the line
SIMPLECACONF="/etc/simpleca.conf"
BACDIR="backup"

#-----------------------------------------------------------------
echolog () {
    echo "`date '+%Y%m%d-%H:%M.%S'` $*" >> $SIMPLECALOG
}
#-----------------------------------------------------------------
echoerr () {
    echo "$*" >&2
}
#-----------------------------------------------------------------
echodebug () {
    if [ $MYDEBUG -ne 0 ] ; then  echo "$*"; fi
}

#-----------------------------------------------------------------
opensslresultlog () {
    echolog "OpenSSL result: $*"
}
#-----------------------------------------------------------------
printhelp () {
    echo "To be done ....:w"
}
#----------------------------------------------------------------- main()

if [ -f ${SIMPLECACONF} ] ; then
    source ${SIMPLECACONF}
else
    echoerr "Configuration file ${SIMPLECACONF} not found"
    exit 1
fi

source $SIMPLECACONF

CADIRSHORT=$(basename $CADIR)

cd $CADIR
mkdir -p ${BACDIR}
cd ..

TARFILE="${CADIRSHORT}/${BACDIR}/${CADIRSHORT}.tar"
tar cf ${TARFILE} --exclude=${CADIRSHORT}/${BACDIR} $CADIRSHORT

LASTFILE="${TARFILE}.last"

if [ -f ${LASTFILE} ] ; then
    OLDMD5SUM=$(md5sum ${LASTFILE} | awk '{print $1}')
else
    OLDMD5SUM=""
fi
NEWMD5SUM=$(md5sum $TARFILE | awk '{print $1}')

if [ "$OLDMD5SUM" != "$NEWMD5SUM" ] ; then
    DATE=$(date "+%Y%m%d-%H:%M.%S")
    NEWFILE="${CADIRSHORT}/${BACDIR}/${CADIRSHORT}.${DATE}.tar"
    cp $TARFILE $NEWFILE
    gzip $NEWFILE
else
    :
fi

mv $TARFILE ${LASTFILE}

