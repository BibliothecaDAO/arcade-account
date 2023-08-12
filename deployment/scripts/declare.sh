#!/bin/bash
source ./env
if [ $? != 0 ]; then
    echo $?
    exit 1
fi

cd .. && scarb build
if [ $? != 0 ]; then
    echo $?
    exit 1
fi

starkli declare ./target/dev/arcade_account_Account.sierra.json
if [ $? != 0 ]; then
    echo $?
    exit 1
fi

echo """
    
        Remember to add this class hash to the env file 
        so that the deployment script uses the updated class hash

"""
