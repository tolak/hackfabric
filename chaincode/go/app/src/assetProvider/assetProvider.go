package main

import (
	"fmt"
	"strconv"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

type assetProviderChaincode struct {
}

//Init assetProvider
func (t *assetProviderChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response{
	fmt.Println("assetProvider Init....")
	return shim.Success(nil)
}

func (t *assetProviderChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response{
	fmt.Println("assetProvider Invoke")
	f, args := stub.GetFunctionAndParameters()
	if f == "userBorrowAsset"{
		return t.userBorrowAsset(stub, args)
	}

	return shim.Error("Invalid invoke function name.")
}

//user borrow asset from others
//args[0]: the one wanna borrow asset.
//args[1]: the one would lend the asset. default "public"
//args[3]: the amount of asset would be borrowed
func (t *assetProviderChaincode) userBorrowAsset(stub shim.ChaincodeStubInterface, args []string) pb.Response{
	var err error
	var lendUser string
	var borrowUser string
	var asset int

	if len(args) == 2{
		borrowUser = args[0]
		lendUser = "public"
		asset, err = strconv.Atoi(args[1])
		if err != nil{
			return shim.Error("Invalid asset amount, expecting a integer value")
		}
	}else if len(args) == 3{
		borrowUser = args[0]
		lendUser = args[1]
		asset, err = strconv.Atoi(args[1])
		if err != nil{
			return shim.Error("Invalid asset amount, expecting a integer value")
		}
	}else{
		return shim.Error("Incorrect number of arguments. Expecting 1 or 2")
	}

	lendUserOriginAsset, err := stub.GetState(lendUser)
	if err != nil{
		return shim.Error("Failed to get state")
	}
	borrowUserOriginAsset, err := stub.GetState(borrowUser)
	if err != nil{
		return shim.Error("Failed to get state")
	}

	borrowUserNewAsset := strconv.Atoi(string(borrowUserOriginAsset)) + asset
	lendUserNewAsset := strconv.Atoi(string(lendUserOriginAsset)) - asset
	fmt.Printf("lendUserNewAsset = %d, borrowUserNewAsset = %d\n", lendUserNewAsset, borrowUserNewAsset)

	err = stub.PutState(lendUser, []byte(strconv.Itoa(lendUserNewAsset)))
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(borrowUser, []byte(strconv.Itoa(borrowUserNewAsset)))
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success(nil)
}