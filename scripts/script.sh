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
    CORE_PEER_LOCALMSPID=${ORG}
    CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt
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

#installChaincode <org> <peer>
installChaincode () {
	setGlobals $1 $2
	peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$2.$1 has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$2.$1 ===================== "
	echo
}

#instantiateChaincode <org> <peer>
instantiateChaincode () {
	setGlobals $1 $2
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('AssetProviderOrg.member','AssetProviderOrg.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('AssetCollectorOrg.member','AssetProviderOrg.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$2.$1 on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$2.$1 on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

#chaincodeQuery <org> <peer> <value>
chaincodeQuery () {
  echo "===================== Querying on PEER$2.$1 on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $1 $2
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$2.$1 ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$3" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$2.$1 on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$2.$1 is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute AssetAtom Scenario =================="
	echo
	exit 1
  fi
}

#chaincodeInvoke <org> <peer>
chaincodeInvoke () {
	setGlobals $1 $2
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
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
echo "Having peer0.assetManagerOrg join the channel..."
joinChannel "assetManagerOrg" "peer0"
joinChannel "assetManagerOrg" "peer1"

## Set the peer0 as anchor peers for assetManagerOrg in the channel
updateAnchorPeers "assetManagerOrg" "peer0"

## Install chaincode on peer0.assetManagerOrg and peer1.assetManagerOrg
installChaincode "assetManagerOrg" "peer0"
installChaincode "assetManagerOrg" "peer1"

#
##Instantiate chaincode on Peer2/Org2
#echo "Instantiating chaincode on org2/peer2..."
#instantiateChaincode 2
#
##Query on chaincode on Peer0/Org1
#echo "Querying chaincode on org1/peer0..."
#chaincodeQuery 0 100
#
##Invoke on chaincode on Peer0/Org1
#echo "Sending invoke transaction on org1/peer0..."
#chaincodeInvoke 0
#
### Install chaincode on Peer3/Org2
#echo "Installing chaincode on org2/peer3..."
#installChaincode 3
#
##Query on chaincode on Peer3/Org2, check if the result is 90
#echo "Querying chaincode on org2/peer3..."
#chaincodeQuery 3 90

echo
echo "===================== All GOOD, AssetAtom execution completed ===================== " >&log.txt
echo


exit 0
