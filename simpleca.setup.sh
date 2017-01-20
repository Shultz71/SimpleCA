#!/bin/bash
# vim: nu ts=4 sw=4 expandtab ignorecase nowrap
MYDEBUG=1   # debug ON  to disable comment out the line

SIMPLECACONF="/etc/simpleca.conf"
OPENSSLCONFTEMPLATE="openssl.cnf.TEMPLATE"
OPENSSLCONFTEMPLATEIM="openssl_im.cnf.TEMPLATE"
INMSUBDIR="intermediate"

#------------------------------------------------
usage() {
    cat <<EOF

  Usage:  $PRGNAME [options] [arguments]

  Options:
     -a or --arga - parameter A
     -b or --argb - parameter B
     -c or --argc - parameter C

  Example:
EOF

}

#------------------------------------------------
echoerr () {
    echo "$*" >&2
}
#------------------------------------------------
echodebug () {
    if [ $MYDEBUG ] ; then  echo "$*"; fi
}

if [ ! `id -u` -eq 0 ] ; then
    echoerr "You are not root - exiting"
    exit 1
fi

if [ -f $SIMPLECACONF ] ; then
    echoerr "Configuration file $SIMPLECACONF already exists ... exiting"
    exit 1
fi

if [ ! -f $OPENSSLCONFTEMPLATE ] ; then
    echoerr "Cannot found $OPENSSLCONFTEMPLATE ... exiting"
    exit 1
fi

if [ ! -f $OPENSSLCONFTEMPLATEIM ] ; then
    echoerr "Cannot found $OPENSSLCONFTEMPLATEIM ... exiting"
    exit 1
fi

# read the options
# ~~CA-NAME~~           --ca-name           -a
# ~~COMMONNAME~~        --commonname        -n
# ~~COUNTRY~~           --country           -c
# ~~COUNTRYCODE~~       --countrycode       -d
# ~~LOCALITY~~          --locality          -l
# ~~ORGANIZATION~~      --organization      -o
# ~~ORGANIZATIONUNIT~~  --organizationunit  -u
#                       --password          -p
#                       --configpassword    -g
#                       --cafolder          -f

PRGNAME=`basename $0`
#OPTIONS=`getopt -o a::bc:h --long arga::,argb,argc:,help -n $PRGNAME -- "$@"`
OPTIONS=`getopt -o a:n:c:d:l:o:u:p:g:f: --long ca-name:,commonname:,country:,countrycode:,locality:,organization:,organizationunit:password:,configpassword:,cafolder:,help -n $PRGNAME -- "$@"`
if [ $? -ne 0 ] ; then
    usage
    exit 1
fi
eval set -- "$OPTIONS"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -a|--ca-name)
            case "$2" in
                "") shift 2 ;;
                *) CANAME="$2" ; shift 2 ;;
            esac ;;
        -n|--commonname)
            case "$2" in
                "") shift 2 ;;
                *) COMMONNAME="$2" ; shift 2 ;;
            esac ;;
        -c|--country)
            case "$2" in
                "") shift 2 ;;
                *) COUNTRY="$2" ; shift 2 ;;
            esac ;;
        -d|--countrycode)
            case "$2" in
                "") shift 2 ;;
                *) COUNTRYCODE="$2" ; shift 2 ;;
            esac ;;
        -l|--locality)
            case "$2" in
                "") shift 2 ;;
                *) LOCALITY="$2" ; shift 2 ;;
            esac ;;
        -o|--organization)
            case "$2" in
                "") shift 2 ;;
                *) ORGANIZATION="$2" ; shift 2 ;;
            esac ;;
        -u|--organizationunit)
            case "$2" in
                "") shift 2 ;;
                *) ORGANIZATIONUNIT="$2" ; shift 2 ;;
            esac ;;
        -p|--password)
            case "$2" in
                "") shift 2 ;;
                *) PASSWORD="$2" ; shift 2 ;;
            esac ;;
        -g|--configpassword)
            case "$2" in
                "") shift 2 ;;
                *) CFGPASSWORD="$2" ; shift 2 ;;
            esac ;;
        -f|--cafolder)
            case "$2" in
                "") shift 2 ;;
                *) CADIR="$2" ; shift 2 ;;
            esac ;;
        -h|--help)
            usage
            exit 0
            ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

#-------------------------------------------------------------------------- Main()
#set -x
#check missing paramaters:
PARAMETERSERR=0
if [ "${CANAME:-NULL}" = "NULL" ] ;           then  PARAMETERSERR=1; echoerr "... missing CA name"; fi
if [ "${COMMONNAME:-NULL}" = "NULL" ] ;       then  PARAMETERSERR=1; echoerr "... missing Common name"; fi
if [ "${COUNTRY:-NULL}" = "NULL" ] ;          then  PARAMETERSERR=1; echoerr "... missing Country"; fi
if [ "${COUNTRYCODE:-NULL}" = "NULL" ] ;      then  PARAMETERSERR=1; echoerr "... missing Country code"; fi
if [ "${LOCALITY:-NULL}" = "NULL" ] ;         then  PARAMETERSERR=1; echoerr "... missing Locality"; fi
if [ "${ORGANIZATION:-NULL}" = "NULL" ] ;     then  PARAMETERSERR=1; echoerr "... missing Organization"; fi
if [ "${ORGANIZATIONUNIT:-NULL}" = "NULL" ] ; then  PARAMETERSERR=1; echoerr "... missing Organization unit"; fi
if [ "${PASSWORD:-NULL}" = "NULL" ] ;         then  PARAMETERSERR=1; echoerr "... missing password"; fi
if [ "${CFGPASSWORD:-NULL}" = "NULL" ] ;      then  PARAMETERSERR=1; echoerr "... missing cfg. file password"; fi
if [ "${CADIR:-NULL}" = "NULL" ] ;            then  PARAMETERSERR=1; echoerr "... missing CA directory"; fi

if [ $PARAMETERSERR -ne 0 ] ; then
    echoerr "cannot continue ... exiting"
    exit 1
fi

if [ -d "${CADIR}" ] ; then
    echoerr "... CA directory ${CADIR} already exists"
    exit 1
fi

if [ "$MYDEBUG" ] ; then
    echo "CANAME           = $CANAME"
    echo "COMMONNAME       = $COMMONNAME"
    echo "COUNTRY          = $COUNTRY"
    echo "COUNTRYCODE      = $COUNTRYCODE"
    echo "LOCALITY         = $LOCALITY"
    echo "ORGANIZATION     = $ORGANIZATION"
    echo "ORGANIZATIONUNIT = $ORGANIZATIONUNIT"
    echo "PASSWORD         = $PASSWORD"
    echo "CFGPASSWORD      = $CFGPASSWORD"
    echo "CADIR            = $CADIR"
fi

> $SIMPLECACONF
echo "CADIR=\"${CADIR}\"" >> $SIMPLECACONF
TMP=`echo "${PASSWORD}" | openssl enc -aes-128-cbc -a -salt -pass pass:${CFGPASSWORD}`
echo "PASSWORD=\"${TMP}\"" >> $SIMPLECACONF
#echo "" >> $SIMPLECACONF

WORKDIR=`pwd`

#----------------------------------------------------------
#   Create the root pair
#----------------------------------------------------------

# Prepare the directory ----------------------------------------------------
mkdir ${CADIR}
chmod 700 ${CADIR}
cd ${CADIR}
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

# Prepare the configuration file ---------------------------------------------
OPENSSLCONF="${CADIR}/openssl.cnf"
cat ${WORKDIR}/${OPENSSLCONFTEMPLATE} > $OPENSSLCONF
sed -i -e "s:~~CADIR~~:${CADIR}:" $OPENSSLCONF
sed -i -e "s/~~CA-NAME~~/${CANAME}/" $OPENSSLCONF
sed -i -e "s/~~COUNTRY~~/${COUNTRY}/" $OPENSSLCONF
sed -i -e "s/~~COUNTRYCODE~~/${COUNTRYCODE}/" $OPENSSLCONF
sed -i -e "s/~~LOCALITY~~/${LOCALITY}/" $OPENSSLCONF
sed -i -e "s/~~ORGANIZATION~~/${ORGANIZATION}/" $OPENSSLCONF
sed -i -e "s/~~ORGANIZATIONUNIT~~/${ORGANIZATIONUNIT}/" $OPENSSLCONF
sed -i -e "s/~~COMMONNAME~~/${COMMONNAME}/" $OPENSSLCONF

# Create the root key --------------------------------------------------------
cd ${CADIR}
openssl genrsa -aes256 -out private/ca.key.pem -passout pass:${PASSWORD} 4096
chmod 400 private/ca.key.pem

# Create the root certificate -------------------------------------------------
cd ${CADIR}

SUBJ="/C=${COUNTRYCODE}/ST=${COUNTRY}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONUNIT}/CN=${COMMONNAME}"
echo "SUBJ - ${SUBJ}"
eval openssl req -new -passin pass:${PASSWORD} -config openssl.cnf -key private/ca.key.pem -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem -subj \"${SUBJ}\"
chmod 444 certs/ca.cert.pem

# Verify the root certificate ------------------------------------------------
openssl x509 -noout -text -in certs/ca.cert.pem > ${CADIR}/rootkey.verification.txt

#----------------------------------------------------------
#   Create the intermediate pair
#----------------------------------------------------------

# Prepare the directory ------------------------------------------------------

CADIRINM="${CADIR}/${INMSUBDIR}"
mkdir ${CADIRINM}
chmod 700 ${CADIRINM}
cd ${CADIRINM}
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > crlnumber

OPENSSLCONFINM="${CADIRINM}/openssl.cnf"
cat ${WORKDIR}/${OPENSSLCONFTEMPLATEIM} > $OPENSSLCONFINM
sed -i -e "s:~~CADIRINM~~:${CADIRINM}:" $OPENSSLCONFINM
sed -i -e "s/~~CA-NAME~~/${CANAME}/" $OPENSSLCONFINM
sed -i -e "s/~~COUNTRY~~/${COUNTRY}/" $OPENSSLCONFINM
sed -i -e "s/~~COUNTRYCODE~~/${COUNTRYCODE}/" $OPENSSLCONFINM
sed -i -e "s/~~LOCALITY~~/${LOCALITY}/" $OPENSSLCONFINM
sed -i -e "s/~~ORGANIZATION~~/${ORGANIZATION}/" $OPENSSLCONFINM
sed -i -e "s/~~ORGANIZATIONUNIT~~/${ORGANIZATIONUNIT}/" $OPENSSLCONFINM
sed -i -e "s/~~COMMONNAME~~/${COMMONNAME}/" $OPENSSLCONFINM

# Create the intermediate key ------------------------------------------------
cd ${CADIR}
openssl genrsa -aes256  -out ${INMSUBDIR}/private/intermediate.key.pem -passout pass:${PASSWORD} 4096
chmod 400 ${INMSUBDIR}/private/intermediate.key.pem

# Create the intermediate certificate ----------------------------------------
cd ${CADIR}
SUBJ="/C=${COUNTRYCODE}/ST=${COUNTRY}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONUNIT}/CN=${COMMONNAME}"
eval openssl req -new -passin pass:${PASSWORD} -config ${INMSUBDIR}/openssl.cnf -sha256 -key ${INMSUBDIR}/private/intermediate.key.pem -out ${INMSUBDIR}/csr/intermediate.csr.pem -subj \"${SUBJ}\"
openssl ca -config openssl.cnf -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in ${INMSUBDIR}/csr/intermediate.csr.pem -out ${INMSUBDIR}/certs/intermediate.cert.pem -batch -passin pass:${PASSWORD}
chmod 444 ${INMSUBDIR}/certs/intermediate.cert.pem

# Verify the intermediate certificate ----------------------------------------
openssl x509 -noout -text -in ${INMSUBDIR}/certs/intermediate.cert.pem > ${CADIRINM}/intermediate_certificate.txt
echo -ne "\n" >> ${CADIRINM}/intermediate_certificate.txt
openssl verify -CAfile certs/ca.cert.pem ${INMSUBDIR}/certs/intermediate.cert.pem >> ${CADIRINM}/intermediate_certificate.txt

# Create the certificate chain file
cat ${INMSUBDIR}/certs/intermediate.cert.pem certs/ca.cert.pem > ${INMSUBDIR}/certs/ca-chain.cert.pem
chmod 444 ${INMSUBDIR}/certs/ca-chain.cert.pem

exit
#
#./simpleca.setup.sh -a abc -n `hostname` -c "Czech Republic" -d CZ -l Ostrava -o "Shultz ltd." -u "IT dept." -p heslo -g heslo2 -f /root/myCA


todo:
 - Check OK at the last line of intermediate_certificate.txt
 - copy binary to /bin
 - use depasswording

