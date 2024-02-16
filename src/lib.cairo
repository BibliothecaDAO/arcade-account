use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use serde::Serde;
use starknet::account::Call;
use starknet::ContractAddress;

mod account;
mod utils;
mod tests;

const TRANSACTION_VERSION: felt252 = 1;

// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;

const ARCADE_ACCOUNT_ID: felt252 = 22227699753170493970302265346292000442692;


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
    use starknet::account::Call;
    use starknet::ContractAddress;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_contract_address;

    use arcade_account::account::interface::{IMasterControl};
    const ARCADE_ACCOUNT_ID: felt252 = 22227699753170493970302265346292000442692;

    use openzeppelin::account::AccountComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account
    #[abi(embed_v0)]
    impl SRC6Impl = AccountComponent::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = AccountComponent::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyImpl = AccountComponent::PublicKeyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyCamelImpl = AccountComponent::PublicKeyCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeclarerImpl = AccountComponent::DeclarerImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeployableImpl = AccountComponent::DeployableImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        master_account: ContractAddress,
        whitelisted_contracts: LegacyMap::<ContractAddress, bool>,
        whitelisted_calls: LegacyMap::<(ContractAddress, felt252), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252, _master_account: ContractAddress) {
        self.account.initializer(public_key);
        self.master_account.write(_master_account);

        self.src5.SRC5_supported_interfaces.write(ARCADE_ACCOUNT_ID, true);
    }


    #[abi(embed_v0)]
    impl MasterControlImpl of IMasterControl<ContractState> {
        fn update_whitelisted_contracts(
            ref self: ContractState, data: Array<(ContractAddress, bool)>
        ) {
            assert_only_master(@self);
            _update_whitelisted_contracts(ref self, data);
        }

        fn update_whitelisted_calls(
            ref self: ContractState, data: Array<(ContractAddress, felt252, bool)>
        ) {
            assert_only_master(@self);
            _update_whitelisted_calls(ref self, data);
        }

        fn function_call(ref self: ContractState, data: Array<Call>) -> Array<Span<felt252>> {
            assert_only_master(@self);
            _execute_master_calls(@self, data)
        }

        fn get_master_account(self: @ContractState) -> ContractAddress {
            self.master_account.read()
        }
    }


    fn assert_only_master(self: @ContractState) {
        let caller = get_caller_address();
        assert(self.master_account.read() == caller, 'Account: unauthorized');
    }


    fn _update_whitelisted_calls(
        ref self: ContractState, mut data: Array<(ContractAddress, felt252, bool)>
    ) {
        loop {
            match data.pop_front() {
                Option::Some((
                    addr, selector, value
                )) => { _update_whitelisted_call(ref self, addr, selector, value); },
                Option::None(_) => { break (); }
            };
        };
    }


    fn _update_whitelisted_contracts(
        ref self: ContractState, mut data: Array<(ContractAddress, bool)>
    ) {
        loop {
            match data.pop_front() {
                Option::Some((
                    addr, value
                )) => { _update_whitelisted_contract(ref self, addr, value); },
                Option::None(_) => { break (); }
            };
        };
    }


    fn _update_whitelisted_contract(ref self: ContractState, addr: ContractAddress, value: bool) {
        self.whitelisted_contracts.write(addr, value);
    }


    fn _update_whitelisted_call(
        ref self: ContractState, addr: ContractAddress, selector: felt252, value: bool
    ) {
        self.whitelisted_calls.write((addr, selector), value);
    }


    fn _is_whitelisted_contract(self: @ContractState, addr: ContractAddress) -> bool {
        let mut hard_whitelist: Array::<ContractAddress> = array![ //
        ///////////////////////////////////////////////////////
        // hardcoded whitelists should be added here for gas
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
                Option::Some(_addr) => { if _addr == addr {
                    break true;
                } },
                Option::None(_) => { break false; }
            };
        };

        if is_hard_whitelisted {
            return true;
        }

        self.whitelisted_contracts.read(addr)
    }


    fn _is_whitelisted_call(
        self: @ContractState, addr: ContractAddress, selector: felt252
    ) -> bool {
        let mut hard_whitelist: Array::<(ContractAddress, felt252)> = array![ //
        //////////////////////////////////////////////////////
        // hardcoded whitelists should be added here for gas 
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
                Option::Some((
                    _addr, _selector
                )) => { if _addr == addr && _selector == selector {
                    break true;
                } },
                Option::None(_) => { break false; }
            };
        };

        if is_hard_whitelisted {
            return true;
        }
        self.whitelisted_calls.read((addr, selector))
    }


    fn _execute_calls(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_call(self, call);
                    res.append(_res);
                },
                Option::None(_) => { break (); },
            };
        };
        res
    }


    fn _execute_single_call(self: @ContractState, call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;

        if !(_is_whitelisted_contract(self, to) || _is_whitelisted_call(self, to, selector)) {
            assert(false, 'Account: Permission denied');
        }

        starknet::call_contract_syscall(to, selector, calldata).unwrap()
    }


    fn _execute_master_calls(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
        let mut res = ArrayTrait::new();
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    let _res = _execute_single_master_call(self, call);
                    res.append(_res);
                },
                Option::None(_) => { break (); },
            };
        };
        res
    }


    fn _execute_single_master_call(self: @ContractState, call: Call) -> Span<felt252> {
        let Call{to, selector, calldata } = call;
        starknet::call_contract_syscall(to, selector, calldata).unwrap()
    }
}
