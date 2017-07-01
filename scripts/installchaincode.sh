#!/usr/bin/env bash

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="AssetAtom"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/cacerts/ca.example.com-cert.pem

echo "install chaincode ...."

setGlobals () {
    #sine now, default install chaincode on peer0 or peer1 on assetManagerOrg
    ORG="$1"
    : ${ORG:="assetManagerOrg"}
    PEER="$2"
    : ${PEER:="peer0"}
    if [ "$ORG" = "assetManagerOrg" ];then
        CORE_PEER_LOCALMSPID="AssetManagerOrgMSP"
    elif [ "$ORG" = "assetCollectorOrg" ];then
        CORE_PEER_LOCALMSPID="AssetCollectorOrgMSP"
    else
        CORE_PEER_LOCALMSPID="AssetProviderOrgMSP"
    fi
    CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG}.example.com/peers/${PEER}.${ORG}.example.com/tls/ca.crt
    CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp
    CORE_PEER_ADDRESS=${PEER}.${ORG}.example.com:7051

	env |grep CORE
    echo "set globals at ${PEER}.${ORG} sucessfully" >>log.txt 2>&1
}

#installChaincode <org> <peer> <ccname> <path>
installChaincode () {
	setGlobals $1 $2

	ccname="$3"
    : ${ccname:="$2-$1-chaincode"}
    ccpath="$4"
    : ${ccpath:="github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02"}

	peer chaincode install -n $ccname -v 1.0 -p  $ccpath >>log.txt 2>&1
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer $2.$1 has Failed"
	echo "===================== Chaincode is installed on remote peer $2.$1 ===================== " >>log.txt 2>&1
	echo
}