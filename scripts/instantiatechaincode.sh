#!/bin/bash

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="AssetAtom"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/cacerts/ca.example.com-cert.pem

echo "Instantiate chaincode ...."

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

#instantiateChaincode <org> <peer> <ccname> <orgs>
instantiateChaincode () {
	setGlobals $1 $2
	ccname="$3"
    : ${ccname:="$2-$1-chaincode"}
    ccorgs="$4"
    : ${ccorgs:='{"Args":["init","a","0","b","0"]}'} #by default, we always run chaincode_example02.go

	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n $ccname -v 1.0 -c $ccorgs -P "OR	('AssetManagerOrg.member','AssetProviderOrg.member','AssetProviderOrg.member')" >>log.txt 2>&1
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $ccname -v 1.0 -c $ccorgs -P "OR	('AssetManagerOrg.member','AssetCollectorOrg.member','AssetProviderOrg.member')" >>log.txt 2>&1
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on $2.$1 on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on $2.$1 on channel '$CHANNEL_NAME' is successful ===================== " >>log.txt 2>&1
	echo
}