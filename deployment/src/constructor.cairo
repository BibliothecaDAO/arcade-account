use debug::PrintTrait;
use serde::Serde;
use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address::{contract_address_const};

/// This script is used to generate the calldata for the constructor of the
/// arcade contract contract for deployment. The logs of the serialized calldata
/// are printed then used to deploy the contract. see `../scripts/deploy.sh` for more info.
fn main() {
    let mut calldata = array![];

    // set constructor parameters
    let public_key = 0x888;
    let master_account = 0x777;
    let whitelisted_contracts: Array<(ContractAddress, bool)> = array![];
    let whitelisted_calls: Array<(ContractAddress, felt252, bool)> = array![];

    // add constructor parameters to calldata
    Serde::serialize(@public_key, ref calldata);
    Serde::serialize(@master_account, ref calldata);
    Serde::serialize(@whitelisted_contracts, ref calldata);
    Serde::serialize(@whitelisted_calls, ref calldata);

    loop {
        match calldata.pop_front() {
            Option::Some(item) => {
                item.print();
            },
            Option::None(_) => {
                break;
            }
        };
    };
}
