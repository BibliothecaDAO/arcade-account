use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use serde::Serde;
use starknet::account::Call;


mod account;
mod introspection;
mod utils;
mod tests;

const TRANSACTION_VERSION: felt252 = 1;

// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;

trait PublicKeyTrait<TState> {
    fn set_public_key(ref self: TState, new_public_key: felt252);
    fn get_public_key(self: @TState) -> felt252;
}

trait PublicKeyCamelTrait<TState> {
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
    fn getPublicKey(self: @TState) -> felt252;
}

#[starknet::contract]
mod Account {
    use traits::TryInto;
    use traits::Into;
    use array::SpanTrait;
    use array::ArrayTrait;
    use box::BoxTrait;
    use ecdsa::check_ecdsa_signature;
    use option::OptionTrait;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use starknet::contract_address::contract_address_const;

    use arcade_account::account::interface;
    use arcade_account::introspection::interface::ISRC5;
    use arcade_account::introspection::interface::ISRC5Camel;
    use arcade_account::introspection::src5::SRC5;

    use super::Call;
    use super::QUERY_VERSION;
    use super::TRANSACTION_VERSION;

    use arcade_account::utils::{selectors, contracts};


    #[storage]
    struct Storage {
        public_key: felt252,
        master_account: ContractAddress,
        whitelisted_contracts: LegacyMap::<ContractAddress, bool>,
        whitelisted_calls: LegacyMap::<(ContractAddress, felt252), bool>
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        _public_key: felt252, 
        _master_account: ContractAddress,
        _whitelisted_contracts: Array<(ContractAddress, bool)>,
        _whitelisted_calls: Array<(ContractAddress, felt252, bool)>

    ) {
        self.initializer(_public_key);
        self.master_account.write(_master_account);

        _update_whitelisted_contracts(ref self, _whitelisted_contracts);
        _update_whitelisted_calls(ref self, _whitelisted_calls);

    }

    #[external(v0)]
    impl MasterControlImpl of interface::IMasterControl<ContractState> {
        fn update_whitelisted_contracts(ref self: ContractState, data: Array<(ContractAddress, bool)>) {
            assert_only_master(@self);
            _update_whitelisted_contracts(ref self, data);
        }

        fn update_whitelisted_calls(ref self: ContractState, data: Array<(ContractAddress, felt252, bool)>) {
            assert_only_master(@self);
            _update_whitelisted_calls(ref self, data);
        }

        fn function_call(ref self: ContractState, data: Array<Call>) -> Array<Span<felt252>> {
            assert_only_master(@self);
            _execute_master_calls(@self, data)
        }
    }

    //
    // External
    //

    #[external(v0)]
    impl SRC6Impl of interface::ISRC6<ContractState> {
        fn __execute__(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            // Avoid calls from other contracts
            // https://github.com/OpenZeppelin/cairo-contracts/issues/344
            let sender = get_caller_address();
            assert(sender.is_zero(), 'Account: invalid caller');

            // Check tx version
            let tx_info = get_tx_info().unbox();
            let version = tx_info.version;
            if version != TRANSACTION_VERSION {
                assert(version == QUERY_VERSION, 'Account: invalid tx version');
            }

            _execute_calls(self, calls)
        }

        fn __validate__(self: @ContractState, mut calls: Array<Call>) -> felt252 {
            self.validate_transaction()
        }

        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            if self._is_valid_signature(hash, signature.span()) {
                starknet::VALIDATED
            } else {
                0
            }
        }
    }

    #[external(v0)]
    impl SRC6CamelOnlyImpl of interface::ISRC6CamelOnly<ContractState> {
        fn isValidSignature(
            self: @ContractState, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            SRC6Impl::is_valid_signature(self, hash, signature)
        }
    }

    #[external(v0)]
    impl DeclarerImpl of interface::IDeclarer<ContractState> {
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            self.validate_transaction()
        }
    }

    #[external(v0)]
    impl SRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            let unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::SRC5Impl::supports_interface(@unsafe_state, interface_id)
        }
    }

    #[external(v0)]
    impl SRC5CamelImpl of ISRC5Camel<ContractState> {
        fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
            let unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
        }
    }

    #[external(v0)]
    impl PublicKeyImpl of super::PublicKeyTrait<ContractState> {
        fn get_public_key(self: @ContractState) -> felt252 {
            self.public_key.read()
        }

        fn set_public_key(ref self: ContractState, new_public_key: felt252) {
            // Since the private key isn't considered secure,
            // only the master account should be able to change the 
            // public key as opposed to self
            assert_only_master(@self);
            self.public_key.write(new_public_key);
        }
    }

    #[external(v0)]
    impl PublicKeyCamelImpl of super::PublicKeyCamelTrait<ContractState> {
        fn getPublicKey(self: @ContractState) -> felt252 {
            self.public_key.read()
        }

        fn setPublicKey(ref self: ContractState, newPublicKey: felt252) {
            // Since the private key isn't considered secure,
            // only the master account should be able to change the 
            // public key as opposed to self
            assert_only_master(@self);
            self.public_key.write(newPublicKey);
        }
    }

    #[external(v0)]
    fn __validate_deploy__(
        self: @ContractState,
        class_hash: felt252,
        contract_address_salt: felt252,
        _public_key: felt252
    ) -> felt252 {
        self.validate_transaction()
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, _public_key: felt252) {
            let mut unsafe_state = SRC5::unsafe_new_contract_state();
            SRC5::InternalImpl::register_interface(ref unsafe_state, interface::ISRC6_ID);
            self.public_key.write(_public_key);
        }

        fn validate_transaction(self: @ContractState) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self._is_valid_signature(tx_hash, signature), 'Account: invalid signature');
            starknet::VALIDATED
        }

        fn _is_valid_signature(
            self: @ContractState, hash: felt252, signature: Span<felt252>
        ) -> bool {
            let valid_length = signature.len() == 2_u32;

            if valid_length {
                check_ecdsa_signature(
                    hash, self.public_key.read(), *signature.at(0_u32), *signature.at(1_u32)
                )
            } else {
                false
            }
        }
    }

    #[internal]
    fn assert_only_master(self: @ContractState) {
        let caller = get_caller_address();
        assert(self.master_account.read() == caller, 'Account: unauthorized');
    }



    #[internal]
    fn _update_whitelisted_calls(ref self: ContractState, mut data: Array<(ContractAddress, felt252, bool)>) {
        loop {
            match data.pop_front() {
                Option::Some((addr, selector, value)) => {
                    _update_whitelisted_call(ref self, addr, selector, value);
                },
                Option::None(_) => {
                    break ();
                }
            };
        };
    }


    #[internal]
    fn _update_whitelisted_contracts(ref self: ContractState, mut data: Array<(ContractAddress, bool)>) {
        loop {
            match data.pop_front() {
                Option::Some((addr,value)) => {
                    _update_whitelisted_contract(ref self, addr, value);
                },
                Option::None(_) => {
                    break ();
                }
            };
        };
    }


    #[internal]
    #[inline(always)]
    fn _update_whitelisted_contract(ref self: ContractState, addr: ContractAddress, value: bool) {
        self.whitelisted_contracts.write(addr, value);
    }


    #[internal]
    #[inline(always)]
    fn _update_whitelisted_call(ref self: ContractState, addr: ContractAddress, selector: felt252, value: bool) {
        self.whitelisted_calls.write((addr, selector), value);
    }


    #[internal]
    fn _is_whitelisted_contract(self: @ContractState, addr: ContractAddress) -> bool {
        let mut hard_whitelist: Array::<ContractAddress> = array![
            
            //////////////////////////////////////////////////////
            // hardccoded whitelists should be added here for gas
            // efficiency. Note that this cannot be overriden by
            // the master account so careful consideration should
            // be taken when adding items to this list.
            //
            // The addresses that will be called most frequently
            // should be included at the top of the list.
            //////////////////////////////////////////////////////
            
        ];
        let is_hard_whitelisted = loop {
            match hard_whitelist.pop_front() {
                Option::Some(_addr) => {
                    if _addr == addr {
                        break true;
                    }
                },
                Option::None(_) => {
                    break false;
                }
            };
        };

        if is_hard_whitelisted {
            return true;
        }

        self.whitelisted_contracts.read(addr)
    }


    #[internal]
    fn _is_whitelisted_call(self: @ContractState, addr: ContractAddress, selector: felt252) -> bool {

        let mut hard_whitelist: Array::<(ContractAddress, felt252)> = array![

            //////////////////////////////////////////////////////
            // hardccoded whitelists should be added here for gas 
            // efficiency. Note that this cannot be overriden by
            // the master account so careful consideration should
            // be taken when adding items to this list.
            //
            // The items that will be called most frequently should
            // be included at the top of the list.
            // 
            //////////////////////////////////////////////////////
            
        ];
        let is_hard_whitelisted = loop {
            match hard_whitelist.pop_front() {
                Option::Some((_addr, _selector)) => {
                    if _addr == addr && _selector == selector {
                        break true;
                    }
                },
                Option::None(_) => {
                    break false;
                }
            };
        };

        if is_hard_whitelisted {
            return true;
        }
        self.whitelisted_calls.read((addr, selector))
    }



    #[internal]
    fn _execute_calls(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(self, call);
                    res.append(_res);
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
        res
    }

    #[internal]
    fn _execute_single_call(self: @ContractState, call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;

        if !(_is_whitelisted_contract(self, to) || _is_whitelisted_call(self, to, selector)) {
            assert(false, 'Account: Permission denied');
        } 

        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall()
    }


    #[internal]
    fn _execute_master_calls(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_master_call(self, call);
                    res.append(_res);
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
        res
    }


    #[internal]
    fn _execute_single_master_call(self: @ContractState, call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall()
    }
}
