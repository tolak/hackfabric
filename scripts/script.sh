#!/bin/bash

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="AssetAtom"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/cacerts/ca.example.com-cert.pem

echo "Channel name : "$CHANNEL_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute AssetAtom Scenario ==================" >&log.txt
		echo
   		exit 1
	fi
}

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
}

createChannel() {
	setGlobals "assetManagerOrg" "peer0"

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
	else
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

#updateAnchorPeers <org> <peer>: update <peer> as anchor peer of <org>
updateAnchorPeers() {
    setGlobals $1 $2

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	echo
}

#joinWithRetry <peer>: <peer> join the channel.
## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$2.$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1 $2
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

#joinWithRetry <org> <peer>: <peer>.<org> join the channel.
joinChannel () {
    setGlobals $1 $2
    joinWithRetry $1 $2
    echo "===================== PEER$2.$1 joined on the channel \"$CHANNEL_NAME\" ===================== "
    sleep 2
    echo
}

#installChaincode <org> <peer> <ccname> <path>
installChaincode () {
	setGlobals $1 $2

	ccname="$3"
    : ${ccname:="$2-$1-chaincode"}
    ccpath="$4"
    : ${ccpath:="github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02"}

	peer chaincode install -n $ccname -v 1.0 -p  $ccpath >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$2.$1 has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$2.$1 ===================== "
	echo
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
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n $ccname -v 1.0 -c $ccorgs -P "OR	('AssetManagerOrg.member','AssetProviderOrg.member','AssetProviderOrg.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $ccname -v 1.0 -c $ccorgs -P "OR	('AssetManagerOrg.member','AssetCollectorOrg.member','AssetProviderOrg.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$2.$1 on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$2.$1 on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

#chaincodeQuery <org> <peer> <ccname> <orgs>
chaincodeQuery () {
    echo "===================== Querying on PEER$2.$1 on channel '$CHANNEL_NAME'... ===================== "
    setGlobals $1 $2

    ccname="$3"
    : ${ccname:="$2-$1-chaincode"}
    ccorgs="$4"
    : ${ccorgs:='{"Args":["query","a"]}'} #by default, we always run chaincode_example02.go

    local starttime=$(date +%s)

    # continue to poll
    # we either get a successful response, or reach TIMEOUT
    while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
    do
        sleep 3
        echo "Attempting to Query PEER$2.$1 ...$(($(date +%s)-starttime)) secs"
        peer chaincode query -C $CHANNEL_NAME -n $ccname -c $ccorgs >&log.txt
        test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
        echo "Query Result: "
        echo "==> $VALUE"
        echo "======================Querying on PEER$2.$1 on channel '$CHANNEL_NAME' end ======================"
    done

}

#chaincodeInvoke <org> <peer> <ccname> <orgs>
chaincodeInvoke () {
	setGlobals $1 $2

	ccname="$3"
    : ${ccname:="$2-$1-chaincode"}
    ccorgs="$4"
    : ${ccorgs:='{"Args":["invoke","a","b","10"]}'} #by default, we always run chaincode_example02.go

	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n $ccname -c $ccorgs >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $ccname -c $ccorgs >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$2.$1 failed "
	echo "===================== Invoke transaction on PEER$2.$1 on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

## Create channel
echo "Creating channel...as default"
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel "assetManagerOrg" "peer0"
joinChannel "assetManagerOrg" "peer1"
joinChannel "assetCollectorOrg" "peer0"
joinChannel "assetCollectorOrg" "peer1"
joinChannel "assetProviderOrg" "peer0"
joinChannel "assetProviderOrg" "peer1"

## Set the peer0 as anchor peers for its Org in the channel
updateAnchorPeers "assetManagerOrg" "peer0"
updateAnchorPeers "assetCollectorOrg" "peer0"
updateAnchorPeers "assetProviderOrg" "peer0"

## Install chaincode on peer1 within all Org in the channel
installChaincode "assetManagerOrg" "peer1" "peer0-assetmanager-cc" "github.com/hyperledger/fabric/examples/chaincode/go/app/src/assetManager"
installChaincode "assetCollectorOrg" "peer1" "peer1-assetcollector-cc" "github.com/hyperledger/fabric/examples/chaincode/go/app/src/assetCollector"
installChaincode "assetProviderOrg" "peer1" "peer1-assetprovider-cc" "github.com/hyperledger/fabric/examples/chaincode/go/app/src/assetProvider"


#Instantiate chaincode on Peer1 within all Org in the channel
instantiateChaincode "assetManagerOrg" "peer1" "peer0-assetmanager-cc" ""
instantiateChaincode "assetCollectorOrg" "peer1" "peer1-assetcollector-cc" ""
instantiateChaincode "assetProviderOrg" "peer1" "peer1-assetprovider-cc" ""

echo
echo "===================== All GOOD, AssetAtom config completed ===================== " >&log.txt
echo


exit 0
