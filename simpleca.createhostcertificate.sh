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
echoerr () {
    echo "$*" >&2
}
#-----------------------------------------------------------------
echodebug () {
    if [ $MYDEBUG ] ; then  echo "$*"; fi
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
    echoerr "Incorrect password"
    exit 1
fi
PASSWORD=${TMP}

echodebug "# = $#"
if [ $# -gt 2 ] ; then
    echodebug "SAN mon ON"
    SANMODE=1
    ALTNAMES="DNS:${FQDN},"
    COMMA=""
    for I in ${@} ; do
        echo $I
        ALTNAMES="${ALTNAMES}${COMMA}DNS:${I}"
        COMMA=","
    done
    #echo "ALTNAMES=$ALTNAMES"
else
    #echo "SAN mon off"
    SANMODE=0
fi

echodebug "PASSWORD = $PASSWORD"
echodebug "FQDN     = $FQDN"

#.............................................................................
cd $CA_ROOT_DIR

echo "------------------------------------------------ key"
#openssl genrsa -out intermediate/private/host2.example.com.key.pem 2048
 openssl genrsa -out ${CA_KEY_DIR}/${FQDN}.key.pem ${KEYBITS}

echo "------------------------------------------------ CSR"
# openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${FQDN}"
SUBJ="/C=${COUNTRYCODE}/ST=${COUNTRY}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONUNIT}/CN=${FQDN}"
echo "SUBJ - ${SUBJ} "
if [ $SANMODE -eq 0 ] ; then
    #openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${FQDN}"
    #set -x
    eval openssl req -config ${OPENSSLCONF} -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj \"${SUBJ}\"
    set +x
else
    #echo "SAN mode !!!!!"
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
    #set -x
    openssl req  -key ${CA_KEY_DIR}/${FQDN}.key.pem -new -sha256 -out ${CA_CSR_DIR}/${FQDN}.csr.pem -subj "${SUBJ}" -config ${CUSTOMOPENSSLCONF}
    set +x
fi

echo "------------------------------------------------ signing"

#exit
if [ $SANMODE -eq 0 ] ; then
    #openssl ca -config intermediate/openssl.cnf -extensions server_cert -days 3650 -notext -md sha256 -in intermediate/csr/host2.example.com.csr.pem -out intermediate/certs/host2.example.com.cert.pem
    openssl ca -batch -config ${OPENSSLCONF}       -extensions server_cert -days ${DAYS} -notext -md sha256 -in ${CA_CSR_DIR}/${FQDN}.csr.pem -out ${CA_CRT_DIR}/${FQDN}.cert.pem -passin pass:${PASSWORD}
else
    echo "Echo signing SAN"
    #openssl ca -batch -config san-openssl.conf/MODIFIKOVANY.openssl.conf -extensions server_cert -days 3650 -notext -md sha256 -in /root/ca/intermediate/csr/aa-020.firma.cz.csr.pem -out /root/ca/intermediate/certs/aa-020.firma.cz.cert.pem -passin pass:TietoDynamicLandscape2016
    openssl ca -batch -config ${CUSTOMOPENSSLCONF} -extensions server_cert -days ${DAYS} -notext -md sha256 -in ${CA_CSR_DIR}/${FQDN}.csr.pem -out ${CA_CRT_DIR}/${FQDN}.cert.pem -passin pass:${PASSWORD}
fi

cp ${CA_CRT_DIR}/${FQDN}.cert.pem ${WEB_CRT_DIR}
chmod 644 ${WEB_CRT_DIR}/*.cert.pem

echo "------------------------------------------------ verification"
#openssl verify -CAfile intermediate/certs/ca-chain.cert.pem intermediate/certs/host2.example.com.cert.pem
 openssl verify -CAfile ${CA_CRT_DIR}/ca-chain.cert.pem ${CA_CRT_DIR}/${FQDN}.cert.pem

#echo "------------------------------------------------ verification"
#openssl x509 -noout -text -in intermediate/certs/aa-031.firma.cz.cert.pem

echo "------------------------------------------------ pkcs12"
mkdir -p $CA_PKCS12_DIR
#openssl pkcs12 -export -in intermediate/certs/virtsrv1.example.com.cert.pem -inkey intermediate/private/virtsrv1.example.com.key.pem -out virtsrv1.example.com.pkcs12
 openssl pkcs12 -export -in ${CA_CRT_DIR}/${FQDN}.cert.pem -inkey ${CA_KEY_DIR}/${FQDN}.key.pem -out ${CA_PKCS12_DIR}/${FQDN}.pkcs12 -password pass:${PKCS12PASS}
 cp ${CA_PKCS12_DIR}/${FQDN}.pkcs12 ${WEB_PKCS12_DIR}
 chmod 644 ${WEB_PKCS12_DIR}/*.pkcs12 >> $SIMPLECALOG 2>&1

exit # real end
"
bin/ca_createhostcertificate.sh aa-040.firma.cz tajne aa-040.example.com aa-040.priklad.cz

 TODO:
        - web srv config (https, allowfrom, password)
        - publis certs on websrv
        - vsechno logovat
