use array::ArrayTrait;
use option::OptionTrait;
use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing;

use arcade_account::Account;
use arcade_account::TRANSACTION_VERSION;
use arcade_account::tests::utils::helper_contracts::{
    ISimpleTestContractDispatcher, ISimpleTestContractDispatcherTrait,
    simple_test_contract, 
};
use arcade_account::tests::utils;


//
// Constants
//

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBKEY: felt252 = 0x789789;
const SALT: felt252 = 123;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
}

fn AA_CLASS_HASH() -> felt252 {
    Account::TEST_CLASS_HASH
}

fn AA_ADDRESS() -> ContractAddress {
    contract_address_const::<0x111111>()
}

fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: 883045738439352841478194533192765345509759306772397516907181243450667673002,
        transaction_hash: 2717105892474786771566982177444710571376803476229898722748888396642649184538,
        r: 3068558690657879390136740086327753007413919701043650133111397282816679110801,
        s: 3355728545224320878895493649495491771252432631648740019139167265522817576501
    }
}

//
// Helpers
//



fn deploy_simple_test_contract() -> ISimpleTestContractDispatcher {
    let mut calldata = array![];
    let address = utils::deploy(simple_test_contract::TEST_CLASS_HASH, calldata);
    ISimpleTestContractDispatcher { contract_address: address}
}


fn deploy_arcade_account(data: Option<@SignedTransactionData>) -> ContractAddress {
    // Set the transaction version
    testing::set_version(TRANSACTION_VERSION);

    let mut calldata = array![];
    let mut public_key = PUBLIC_KEY;
    
    if data.is_some() {
        // set public key
        let _data = data.unwrap();
        public_key = *_data.public_key; 
                    
        // Set the signature and transaction hash
        let mut signature = array![];
        signature.append(*_data.r);
        signature.append(*_data.s);
        testing::set_signature(signature.span());
        testing::set_transaction_hash(*_data.transaction_hash);
    }
  

    // add constructor parameters to calldata
    Serde::serialize(@public_key, ref calldata);
    Serde::serialize(@starknet::get_contract_address(), ref calldata);
    Serde::serialize(@array![(0x99, true)], ref calldata);
    Serde::serialize(@array![(0x99,0x99, true)], ref calldata);
   
    // Deploy the account contract
    utils::deploy(AA_CLASS_HASH(), calldata)
   
}


#[cfg(test)]
mod account_generic_tests {
    // Mostly inspired by https://github.com/OpenZeppelin/cairo-contracts/blob/cairo-1/src/openzeppelin/tests/account/test_account.cairo

    use array::ArrayTrait;
    use core::traits::Into;
    use option::OptionTrait;
    use starknet::contract_address_const;
    use starknet::testing;

    use arcade_account::Account;
    use arcade_account::account::interface::{
        AccountABIDispatcher,AccountABIDispatcherTrait,
        AccountCamelABIDispatcher, AccountCamelABIDispatcherTrait,
        IMasterControlDispatcher, IMasterControlDispatcherTrait,
    };
    use arcade_account::account::interface::Call;
    use arcade_account::account::interface::ISRC6_ID;
    use arcade_account::QUERY_VERSION;
    use arcade_account::TRANSACTION_VERSION;
    use arcade_account::tests::utils::helper_contracts::{
        ISimpleTestContractDispatcher, ISimpleTestContractDispatcherTrait,
        simple_test_contract, 
    };
    use arcade_account::introspection::interface::ISRC5_ID;
    use super::{deploy_arcade_account, deploy_simple_test_contract};
    use super::{PUBLIC_KEY, NEW_PUBKEY, SALT, AA_CLASS_HASH, AA_ADDRESS, SIGNED_TX_DATA};


    //
    // constructor
    //
    #[test]
    #[available_gas(2000000)]
    fn test_deploy() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };
        assert(arcade_account.get_public_key() == PUBLIC_KEY, 'Should return public key');
    }

    //
    // supports_interface & supportsInterface
    //

    #[test]
    #[available_gas(2000000)]
    fn test_supports_interface() {

        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let supports_default_interface = arcade_account.supports_interface(ISRC5_ID);
        assert(supports_default_interface, 'Should support base interface');

        let supports_account_interface = arcade_account.supports_interface(ISRC6_ID);
        assert(supports_account_interface, 'Should support account id');
    }


    #[test]
    #[available_gas(2000000)]
    fn test_supportsInterface() {

        let arcade_account = AccountCamelABIDispatcher { contract_address: deploy_arcade_account(Option::None(())) };
        let supports_default_interface = arcade_account.supportsInterface(ISRC5_ID);
        assert(supports_default_interface, 'Should support base interface');

        let supports_account_interface = arcade_account.supportsInterface(ISRC6_ID);
        assert(supports_account_interface, 'Should support account id');
    }

    //
    // is_valid_signature & isValidSignature
    //

    #[test]
    #[available_gas(2000000)]
    fn test_is_valid_signature() {
        let data = SIGNED_TX_DATA();
        let hash = data.transaction_hash;

        let mut good_signature = array![];
        good_signature.append(data.r);
        good_signature.append(data.s);

        let mut bad_signature = array![];
        bad_signature.append(0x987);
        bad_signature.append(0x564);

        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        arcade_account.set_public_key(data.public_key);

        let is_valid = arcade_account.is_valid_signature(hash, good_signature);
        assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');

        let is_valid = arcade_account.is_valid_signature(hash, bad_signature);
        assert(is_valid == 0, 'Should reject invalid signature');
    }



    #[test]
    #[available_gas(2000000)]
    fn test_isValidSignature() {
        let data = SIGNED_TX_DATA();
        let hash = data.transaction_hash;

        let mut good_signature = array![];
        good_signature.append(data.r);
        good_signature.append(data.s);

        let mut bad_signature = array![];
        bad_signature.append(0x987);
        bad_signature.append(0x564);

        let arcade_account = AccountCamelABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(())) 
        };
        arcade_account.setPublicKey(data.public_key);

        let is_valid = arcade_account.isValidSignature(hash, good_signature);
        assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');

        let is_valid = arcade_account.isValidSignature(hash, bad_signature);
        assert(is_valid == 0, 'Should reject invalid signature');
    }

    //
    // Entry points
    //

    #[test]
    #[available_gas(2000000)]
    fn test_validate_deploy() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };

        // `__validate_deploy__` does not directly use the passed arguments. Their
        // values are already integrated in the tx hash. The passed arguments in this
        // testing context are decoupled from the signature and have no effect on the test.
        assert(
            arcade_account.__validate_deploy__(AA_CLASS_HASH(), SALT, PUBLIC_KEY) == starknet::VALIDATED,
            'Should validate correctly'
        );
    }


    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_deploy_invalid_signature_data() {
        let mut data = SIGNED_TX_DATA();
        data.transaction_hash += 1;

        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@data))
        };

        arcade_account.__validate_deploy__(AA_CLASS_HASH(), SALT, PUBLIC_KEY);
    }


    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_deploy_invalid_signature_length() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };
        let mut signature = array![];

        signature.append(0x1);
        testing::set_signature(signature.span());

        arcade_account.__validate_deploy__(AA_CLASS_HASH(), SALT, PUBLIC_KEY);
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_deploy_empty_signature() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };
        let empty_sig = array![];

        testing::set_signature(empty_sig.span());
        arcade_account.__validate_deploy__(AA_CLASS_HASH(), SALT, PUBLIC_KEY);
    }


    #[test]
    #[available_gas(2000000)]
    fn test_validate_declare() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };

        // `__validate_declare__` does not directly use the class_hash argument. Its
        // value is already integrated in the tx hash. The class_hash argument in this
        // testing context is decoupled from the signature and has no effect on the test.
        assert(
            arcade_account.__validate_declare__(AA_CLASS_HASH()) == starknet::VALIDATED,
            'Should validate correctly'
        );
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_declare_invalid_signature_data() {
        let mut data = SIGNED_TX_DATA();
        data.transaction_hash += 1;
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@data))
        };

        arcade_account.__validate_declare__(AA_CLASS_HASH());
    }


    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_declare_invalid_signature_length() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };
        let mut signature = array![];

        signature.append(0x1);
        testing::set_signature(signature.span());

        arcade_account.__validate_declare__(AA_CLASS_HASH());
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_declare_empty_signature() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };
        let empty_sig = array![];

        testing::set_signature(empty_sig.span());

        arcade_account.__validate_declare__(AA_CLASS_HASH());
    }

    fn _execute_with_version(version: Option<felt252>) {
        let data = SIGNED_TX_DATA();
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@data))
        };

        let simple_test_contract = deploy_simple_test_contract();
        // whitelist simple_test_contract
        let master_control_dispatcher =IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_contracts(
            array![(simple_test_contract.contract_address, true)]
        );


        // Craft call and add to calls array
        let mut calldata = array![true.into()];
        let call = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_cold_selector(), 
            calldata: calldata
        };
        let calls = array![call];

        // Handle version for test
        if version.is_some() {
            testing::set_version(version.unwrap());
        }

        // Execute
        let ret = arcade_account.__execute__(calls);

        // Assert that the transfer was successful
        assert(simple_test_contract.is_cold() == true, 'Should be cold');

        // Test return value
        let mut call_serialized_retval = *ret.at(0);
        let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
        assert(call_retval.unwrap(), 'Should have succeeded');

    }

    #[test]
    #[available_gas(2000000)]
    fn test_execute() {
        _execute_with_version(Option::None(()));
    }

    #[test]
    #[available_gas(2000000)]
    fn test_execute_query_version() {
        _execute_with_version(Option::Some(QUERY_VERSION));
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
    fn test_execute_invalid_version() {
        _execute_with_version(Option::Some(TRANSACTION_VERSION - 1));
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: Permission denied', 'ENTRYPOINT_FAILED'))]
    fn test_execute_no_whitelist() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();
        
        // Craft call and add to calls array
        let mut calldata = array![true.into()];
        let call = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_cold_selector(), 
            calldata: calldata
        };
        let calls = array![call];

        arcade_account.__execute__(calls);
    }



    #[test]
    #[available_gas(2000000)]
    fn test_validate() {
        let calls = array![];
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@SIGNED_TX_DATA()))
        };

        assert(arcade_account.__validate__(calls) == starknet::VALIDATED, 'Should validate correctly');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
    fn test_validate_invalid() {
        let calls = array![];
        let mut data = SIGNED_TX_DATA();
        data.transaction_hash += 1;
        
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::Some(@data))
        };
        arcade_account.__validate__(calls);
    }

    #[test]
    #[available_gas(2000000)]
    fn test_multicall() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();
        // whitelist simple_test_contract
        let master_control_dispatcher =IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_contracts(
            array![(simple_test_contract.contract_address, true)]
        );

        let mut calls = array![];

        // Craft call1
        let mut calldata1 = array![];
        Serde::serialize(@true, ref calldata1);

        let call1 = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_cold_selector(), 
            calldata: calldata1
        };

        // Craft call2
        let mut calldata2= array![];
        Serde::serialize(@true, ref calldata2);

        let call2 = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_hot_selector(), 
            calldata: calldata2
        };

        // Bundle calls and exeute
        calls.append(call1);
        calls.append(call2);
        let ret = arcade_account.__execute__(calls);

        // Assert that call was successful
        assert(simple_test_contract.is_cold() == true, 'Should be true');
        assert(simple_test_contract.is_hot() == true, 'Should be true');
        

        // Test return value
        let mut call1_serialized_retval = *ret.at(0);
        let mut call2_serialized_retval = *ret.at(1);
        let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
        let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
        assert(call1_retval.unwrap(), 'Should have succeeded');
        assert(call2_retval.unwrap(), 'Should have succeeded');
    }


    #[test]
    #[available_gas(2000000)]
    fn test_multicall_zero_calls() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };
        let mut calls = array![];
        let ret = arcade_account.__execute__(calls);
        // Test return value
        assert(ret.len() == 0, 'Should have an empty response');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: invalid caller', ))]
    fn test_account_called_from_contract() {
        let calls = array![];
        let caller = contract_address_const::<0x123>();
        testing::set_caller_address(caller);
        let arcade_state = Account::contract_state_for_testing();
        Account::SRC6Impl::__execute__(@arcade_state, calls);

    }

    //
    // set_public_key & get_public_key
    //

    #[test]
    #[available_gas(2000000)]
    fn test_public_key_setter_and_getter() {

        testing::set_contract_address(AA_ADDRESS());

        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };
        arcade_account.set_public_key(NEW_PUBKEY);

        let public_key = arcade_account.get_public_key();
        assert(public_key == NEW_PUBKEY, 'Should update key');
    }

    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED' ))]
    fn test_public_key_setter_different_account() {
        let arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        testing::set_contract_address(AA_ADDRESS());
        arcade_account.set_public_key(NEW_PUBKEY);
    }


    //
    // setPublicKey & getPublicKey
    //

    #[test]
    #[available_gas(2000000)]
    fn test_public_key_setter_and_getter_camel() {

        testing::set_contract_address(AA_ADDRESS());

        let arcade_account = AccountCamelABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };
        arcade_account.setPublicKey(NEW_PUBKEY);

        let public_key = arcade_account.getPublicKey();
        assert(public_key == NEW_PUBKEY, 'Should update key');
    }


    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED' ))]
    fn test_public_key_setter_different_account_camel() {
        let arcade_account = AccountCamelABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        testing::set_contract_address(AA_ADDRESS());
        arcade_account.setPublicKey(NEW_PUBKEY);
    }



    //
    // Test internals
    //

    #[test]
    #[available_gas(2000000)]
    fn test_initializer() {
        let mut arcade_state = Account::contract_state_for_testing();
        Account::InternalImpl::initializer(ref arcade_state, PUBLIC_KEY);
        assert(Account::PublicKeyImpl::get_public_key(@arcade_state) == PUBLIC_KEY, 'Should return public key');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_assert_only_master_true() {
        let mut arcade_state = Account::contract_state_for_testing();
        Account::assert_only_master(@arcade_state);
    }


    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: unauthorized', ))]
    fn test_assert_only_master_false() {

        let other = contract_address_const::<0x4567>();
        testing::set_caller_address(other);

        let mut arcade_state = Account::contract_state_for_testing();
        Account::assert_only_master(@arcade_state);
    }

    #[test]
    #[available_gas(2000000)]
    fn test__is_valid_signature() {
        let data = SIGNED_TX_DATA();
        let hash = data.transaction_hash;

        let mut good_signature = array![];
        good_signature.append(data.r);
        good_signature.append(data.s);

        let mut bad_signature = array![];
        bad_signature.append(0x987);
        bad_signature.append(0x564);

        let mut invalid_length_signature = array![];
        invalid_length_signature.append(0x987);

        let mut arcade_state = Account::contract_state_for_testing();
    
        Account::PublicKeyImpl::set_public_key(ref arcade_state, data.public_key);

        let is_valid = Account::InternalImpl::_is_valid_signature(@arcade_state,hash, good_signature.span());
        assert(is_valid, 'Should accept valid signature');

        let is_valid = Account::InternalImpl::_is_valid_signature(@arcade_state, hash, bad_signature.span());
        assert(!is_valid, 'Should reject invalid signature');

        let is_valid = Account::InternalImpl::_is_valid_signature(@arcade_state, hash, invalid_length_signature.span());
        assert(!is_valid, 'Should reject invalid length');
    }
}





#[cfg(test)]
mod account_master_control_tests {
    use super::{deploy_arcade_account, deploy_simple_test_contract};
    use array::ArrayTrait;
    use option::OptionTrait;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use starknet::testing;

    use arcade_account::Account;
    use arcade_account::account::interface::{
        AccountABIDispatcher,AccountABIDispatcherTrait,
        IMasterControlDispatcher, IMasterControlDispatcherTrait,
    };
    use arcade_account::account::interface::Call;
    use arcade_account::tests::utils::helper_contracts::{
        ISimpleTestContractDispatcher, ISimpleTestContractDispatcherTrait,
        simple_test_contract, 
    };


    
    #[test]
    #[available_gas(2000000)] 
    fn test_update_whitelisted_contracts() {
        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_contracts(
            array![(simple_test_contract.contract_address, true)]
        );


        // Craft call    
        let mut calldata= array![];
        Serde::serialize(@true, ref calldata);
        let call = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_hot_selector(), 
            calldata: calldata
        };

        // execute call
        let ret = arcade_account.__execute__(array![call]);

        // Assert that call was successful
        assert(simple_test_contract.is_hot() == true, 'Should be true');

        // Test return value
        let mut call_serialized_retval = *ret.at(0);
        let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
        assert(call_retval.unwrap(), 'Should have succeeded');
    }


    #[test]
    #[available_gas(2000000)] 
    #[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED' ))]
    fn test_update_whitelisted_contracts_unauthorized() {

        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // change caller address
        testing::set_contract_address(contract_address_const::<0x123>());
        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_contracts(
            array![(simple_test_contract.contract_address, true)]
        );
    }


    #[test]
    #[available_gas(2000000)] 
    fn test_update_whitelisted_calls() {
        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_calls(
            array![(
                simple_test_contract.contract_address, 
                simple_test_contract::SelectorImpl::set_hot_selector(),
                true
            )]
        );

        // Craft call    
        let mut calldata= array![];
        Serde::serialize(@true, ref calldata);
        let call = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_hot_selector(), 
            calldata: calldata
        };

        // execute call
        let ret = arcade_account.__execute__(array![call]);

        // Assert that call was successful
        assert(simple_test_contract.is_hot() == true, 'Should be true');


        // Test return value
        let mut call_serialized_retval = *ret.at(0);
        let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
        assert(call_retval.unwrap(), 'Should have succeeded');
    }


    #[test]
    #[available_gas(2000000)] 
    #[should_panic(expected: ('Account: Permission denied', 'ENTRYPOINT_FAILED' ))]
    fn test_update_whitelisted_calls_only_whitelists_call() {
        // Ensure that the update_whitelisted_calls function doesn't
        // whitelist the entire contract
        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_calls(
            array![(
                simple_test_contract.contract_address, 
                // set_hot selector is whitelisted but set_cold is called below
                simple_test_contract::SelectorImpl::set_hot_selector(),
                true
            )]
        );

        // Craft call    
        let mut calldata= array![];
        Serde::serialize(@true, ref calldata);
        let call = Call {
            to: simple_test_contract.contract_address, 
            //set_hot selector was whitelisted but set_cold is being called
            selector: simple_test_contract::SelectorImpl::set_cold_selector(), 
            calldata: calldata
        };

        // execute call
        arcade_account.__execute__(array![call]);

    }



    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED' ))]
    fn test_update_whitelisted_calls_unauthorized() {

        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // change caller address
        testing::set_contract_address(contract_address_const::<0x123>());
        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        master_control_dispatcher.update_whitelisted_calls(
            array![(
                simple_test_contract.contract_address, 
                simple_test_contract::SelectorImpl::set_hot_selector(),
                true
            )]
        );
    }



    #[test]
    #[available_gas(2000000)] 
    fn test_function_call() {
        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        
        // Craft call    
        let mut calldata= array![];
        Serde::serialize(@true, ref calldata);
        let call = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_hot_selector(), 
            calldata: calldata
        };
        let ret = master_control_dispatcher.function_call(
            array![call]
        );

        // Assert that call was successful
        assert(simple_test_contract.is_hot() == true, 'Should be true');

        // Test return value
        let mut call_serialized_retval = *ret.at(0);
        let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
        assert(call_retval.unwrap(), 'Should have succeeded');
    }



    #[test]
    #[available_gas(2000000)] 
    #[should_panic(expected: ('Account: unauthorized', 'ENTRYPOINT_FAILED' ))]
    fn test_function_call_unauthorized() {
        let mut arcade_account = AccountABIDispatcher { 
            contract_address: deploy_arcade_account(Option::None(()))
        };

        let simple_test_contract = deploy_simple_test_contract();

        // whitelist simple_test_contract
        let master_control_dispatcher = IMasterControlDispatcher { 
            contract_address: arcade_account.contract_address
        };
        
        // Craft call    
        let mut calldata= array![];
        Serde::serialize(@true, ref calldata);
        let call = Call {
            to: simple_test_contract.contract_address, 
            selector: simple_test_contract::SelectorImpl::set_hot_selector(), 
            calldata: calldata
        };

        // change caller address
        testing::set_contract_address(contract_address_const::<0x123>());
        let ret = master_control_dispatcher.function_call(
            array![call]
        );
    }
}
