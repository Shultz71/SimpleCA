#!/bin/bash
# vim: nu ts=4 sw=4 expandtab ignorecase nowrap
MYDEBUG=1   # debug ON  to disable comment out the line 

SIMPLECACONF="/etc/simpleca.conf"

if [ -f ${SIMPLECACONF} ] ; then
    source ${SIMPLECACONF}
else
    echoerr "Configuration file ${SIMPLECACONF} not found"
    exit 1
fi

CA_ROOT_DIR="${CADIR}"
CA_CSR_DIR="${CA_ROOT_DIR}/intermediate/csr"
CA_CRT_DIR="${CA_ROOT_DIR}/intermediate/certs"
CA_KEY_DIR="${CA_ROOT_DIR}/intermediate/private"
CA_PKCS12_DIR="${CA_ROOT_DIR}/intermediate/pkcs12"
OPENSSLCONF="${CA_ROOT_DIR}/intermediate/openssl.cnf"
SANDIR="${CA_ROOT_DIR}/san-openssl.conf"

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
    echo "$TDL_NAME usage:"
    echo
    echo -e "\t`basename $0` ca_password fqdn [alternativename1 alternativename2 ...]"
    echo -e "\t\tpassword - CA's key password"
    echo -e "\t\tfqdn     - Fully Qualified Domain Name"
    echo -e "\t\talternativename - SAN SubjectAlName (alternative hostname) "
    echo
    echo -e "Example:"
    echo -e "\t`basename $0` myPa\$\$w0rd myhost.example.com"
    echo -e "\t`basename $0` myPa\$\$w0rd myhost.example.com www.example.com"
    echo
}
#----------------------------------------------------------------- main()

echodebug "# = $#"
if [ $# -lt 2 ] ; then
    printhelp
    exit 1
fi

CFGPASSWORD=$1
FQDN=$2
shift
shift

TMP=`echo "${PASSWORD}" | openssl enc -aes-128-cbc -a -d -salt -pass pass:${CFGPASSWORD} 2>/dev/null`
if [ $? -gt 0 ] ; then
    echoerr "Incorrect password ... cannot decrypt PASSWORD"
    exit 1
fi
PASSWORD=${TMP}

TMP=`echo "${PKCS12PASS}" | openssl enc -aes-128-cbc -a -d -salt -pass pass:${CFGPASSWORD} 2>/dev/null`
if [ $? -gt 0 ] ; then
    echoerr "Incorrect password ... cannot decrypt PKCS12PASS"
    exit 1
fi
PKCS12PASS=${TMP}

echolog ""
echolog "$0 <password> $FQDN $*"
if [ $# -gt 0 ] ; then
    SANMODE=1
    ALTNAMES="DNS:${FQDN},"
    COMMA=""
    for I in ${@} ; do
        echo $I
        ALTNAMES="${ALTNAMES}${COMMA}DNS:${I}"
        COMMA=","
    done
    echolog   "SAN mode, ALTNAMES=$ALTNAMES"
else
    SANMODE=0
    echolog "SAN off"
fi

echodebug "PASSWORD   = $PASSWORD"
echodebug "PKCS12PASS = $PKCS12PASS"
echodebug "FQDN       = $FQDN"
# Main part
cd $CA_ROOT_DIR

# Create a key
# openssl genrsa -out intermediate/private/hostr1.example.com.key.pem 2048
echolog "Create a key:"
echolog "openssl genrsa -out ${CA_KEY_DIR}/${FQDN}.key.pem ${KEYBITS}"
openssl genrsa -out ${CA_KEY_DIR}/${FQDN}.key.pem ${KEYBITS} 2>&1 >> $SIMPLECALOG
opensslresultlog $?
chmod 400 ${CA_KEY_DIR}/${FQDN}.key.pem

# Create a certificate
echolog "Create a certificate:"
# openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${FQDN}"
SUBJ="/C=${COUNTRYCODE}/ST=${COUNTRY}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONUNIT}/CN=${FQDN}"
echo "SUBJ - ${SUBJ} "
if [ $SANMODE -eq 0 ] ; then
    #openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${FQDN}"
    #set -x
    echolog "openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj \"${SUBJ}\" "
    eval openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj \"${SUBJ}\"
    opensslresultlog $?
else
    echolog "SAN mode"
    mkdir -p ${SANDIR}

    CUSTOMOPENSSLCONF="${SANDIR}/${FQDN}-SAN.openssl.conf"
    ALTNAMESTR1="[ req_ext ]\nsubjectAltName = ${ALTNAMES}"
    ALTNAMESTR2="subjectAltName = ${ALTNAMES}"

    > ${CUSTOMOPENSSLCONF}
    while read SSLCONFLINE ; do
        if [[ ${SSLCONFLINE} == *"__REQ_EXTENSIONS__"* ]] ; then
            SSLCONFLINE="req_extensions = req_ext"
        elif [[ ${SSLCONFLINE} == *"__REQ_EXT-SUBJECTALTNAME__"* ]] ; then
            SSLCONFLINE=${ALTNAMESTR1}
        elif [[ ${SSLCONFLINE} == *"__SUBJECTALTNAME__"* ]] ; then
            SSLCONFLINE=${ALTNAMESTR2}
        fi
        echo -e "${SSLCONFLINE}" >> ${CUSTOMOPENSSLCONF}
    done < ${OPENSSLCONF}
    echolog "openssl req  -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj \"${SUBJ}\" -config ${CUSTOMOPENSSLCONF}"
    openssl req  -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj "${SUBJ}" -config ${CUSTOMOPENSSLCONF}
    opensslresultlog $?
fi

# CSR:
echolog "CSR:"
if [ $SANMODE -eq 0 ] ; then
    echolog "openssl ca -batch -config ${OPENSSLCONF} -extensions server_cert -days ${DAYS} -notext -md sha256 -in ${CA_CSR_DIR}/${FQDN}.csr.pem -out ${CA_CRT_DIR}/${FQDN}.cert.pem -passin pass:{PASSWORD}"
    openssl ca -batch -config ${OPENSSLCONF} -extensions server_cert -days ${DAYS} -notext -md sha256 -in ${CA_CSR_DIR}/${FQDN}.csr.pem -out ${CA_CRT_DIR}/${FQDN}.cert.pem -passin pass:${PASSWORD}
    opensslresultlog $?
else
    echolog "openssl ca -batch -config ${CUSTOMOPENSSLCONF} -extensions server_cert -days ${DAYS} -notext -md sha256 -in ${CA_CSR_DIR}/${FQDN}.csr.pem -out ${CA_CRT_DIR}/${FQDN}.cert.pem -passin pass:{PASSWORD}"
    openssl ca -batch -config ${CUSTOMOPENSSLCONF} -extensions server_cert -days ${DAYS} -notext -md sha256 -in ${CA_CSR_DIR}/${FQDN}.csr.pem -out ${CA_CRT_DIR}/${FQDN}.cert.pem -passin pass:${PASSWORD}
    opensslresultlog $?
fi
echolog "intermediate/index.txt:"
tail -n 1 ${CADIR}/intermediate/index.txt >> $SIMPLECALOG

if [ -d "${WEB_CRT_DIR}" ] ; then
    echolog "Copying: ${CA_CRT_DIR}/${FQDN}.cert.pem to ${WEB_CRT_DIR}"
    cp ${CA_CRT_DIR}/${FQDN}.cert.pem ${WEB_CRT_DIR}
    chmod 644 ${WEB_CRT_DIR}/*.cert.pem
else
    echolog "WEB_CRT_DIR: ${WEB_CRT_DIR} folder doesn't exists"
fi

# Verify the certificate
echolog "Verify the certificate:"
#openssl verify -CAfile /root/CertAuth/intermediate/certs/ca-chain.cert.pem  /root/CertAuth/intermediate/certs/host.aaa.cz.cert.pem
echolog "openssl verify -CAfile ${CA_CRT_DIR}/ca-chain.cert.pem ${CA_CRT_DIR}/${FQDN}.cert.pem"
openssl verify -CAfile ${CA_CRT_DIR}/ca-chain.cert.pem ${CA_CRT_DIR}/${FQDN}.cert.pem 2>&1 >> $SIMPLECALOG
opensslresultlog $?
#openssl x509 -noout -text -in /root/CertAuth/intermediate/certs/host3.aaa.cz.cert.pem  | grep -v "^ \+[0-9,a-f][0-9,a-f][0-9,a-f,:]*"
echolog "openssl x509 -noout -text -in ${CA_CRT_DIR}/${FQDN}.cert.pem"
openssl x509 -noout -text -in ${CA_CRT_DIR}/${FQDN}.cert.pem | grep -v "^ \+[0-9,a-f][0-9,a-f][0-9,a-f,:]*" >> $SIMPLECALOG


# pkcs12
echolog "pkcs12:"
#openssl pkcs12 -export -in intermediate/certs/virtsrv1.example.com.cert.pem -inkey intermediate/private/virtsrv1.example.com.key.pem -out virtsrv1.example.com.pkcs12
echolog "openssl pkcs12 -export -in ${CA_CRT_DIR}/${FQDN}.cert.pem -inkey ${CA_KEY_DIR}/${FQDN}.key.pem -out ${CA_PKCS12_DIR}/${FQDN}.pkcs12 -password pass:PKCS12PASS"
openssl pkcs12 -export -in ${CA_CRT_DIR}/${FQDN}.cert.pem -inkey ${CA_KEY_DIR}/${FQDN}.key.pem -out ${CA_PKCS12_DIR}/${FQDN}.pkcs12 -password pass:${PKCS12PASS}

if [ -d ${WEB_PKCS12_DIR} ] ; then
    echolog "Copying ${CA_PKCS12_DIR}/${FQDN}.pkcs12 to ${WEB_PKCS12_DIR}"
    cp ${CA_PKCS12_DIR}/${FQDN}.pkcs12 ${WEB_PKCS12_DIR}
    chmod 644 ${WEB_PKCS12_DIR}/*.pkcs12 >> $SIMPLECALOG 2>&1
else
    echolog "WEB_PKCS12_DIR: ${WEB_PKCS12_DIR} folder doesn't exists"
fi

echolog "$FQDN - end"

exit

# simpleca.createhostcertificate.sh Hesloconfig host.aaa.cz www.aaa.cz
