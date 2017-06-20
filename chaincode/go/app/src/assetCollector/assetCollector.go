package main

import (
	"fmt"
	"strconv"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

type assetCollectorChaincode struct {
}

//Init assetCollector
func (t *assetCollectorChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response{
	fmt.Println("assetCollector Init....")
	return shim.Success(nil)
}

func (t *assetCollectorChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response{
	fmt.Println("assetCollector Invoke")
	f, args := stub.GetFunctionAndParameters()
	if f == "userLendAsset"{
		return t.userLendAsset(stub, args)
	}

	return shim.Error("Invalid invoke function name.")
}

//user lend its asset to others
//args[0]: the one would lend the asset
//args[1]: the one(generally a trusted org or "public") would receive this asset. default "public"
//args[2]: the amount of the asset that would be lend
func (t *assetCollectorChaincode) userLendAsset(stub shim.ChaincodeStubInterface, args []string) pb.Response{
	var err error
	var recvUser string
	var lendUser string
	var asset int

	if len(args) == 2{
		lendUser = args[0]
		recvUser = "public"
		asset, err = strconv.Atoi(args[1])
		if err != nil{
			return shim.Error("Invalid asset amount, expecting a integer value")
		}
	}else if len(args) == 3{
		lendUser = args[0]
		recvUser = args[1]
		asset, err = strconv.Atoi(args[1])
		if err != nil{
			return shim.Error("Invalid asset amount, expecting a integer value")
		}
	}else{
		return shim.Error("Incorrect number of arguments. Expecting 1 or 2")
	}

	recvUserOriginAsset, err := stub.GetState(recvUser)
	if err != nil{
		return shim.Error("Failed to get state")
	}
	lendUserOriginAsset, err := stub.GetState(lendUser)
	if err != nil{
		return shim.Error("Failed to get state")
	}

	lendUserNewAsset := strconv.Atoi(string(lendUserOriginAsset)) - asset
	recvUserNewAsset := strconv.Atoi(string(recvUserOriginAsset)) + asset
	fmt.Printf("lendUserNewAsset = %d, recvUserNewAsset = %d\n", lendUserNewAsset, recvUserNewAsset)

	err = stub.PutState(recvUser, []byte(strconv.Itoa(recvUserNewAsset)))
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(lendUser, []byte(strconv.Itoa(lendUserNewAsset)))
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success(nil)
}

func main() {
	err := shim.Start(new(assetCollectorChaincode))
	if err != nil {
		fmt.Printf("Error starting assetCollectorChaincode chaincode: %s", err)
	}
}