#[starknet::interface]
trait ISimpleTestContract<TState> {
    fn is_cold(self: @TState) -> bool;
    fn set_cold(ref self: TState, value: bool) -> bool;

    fn is_hot(self: @TState) -> bool;
    fn set_hot(ref self: TState, value: bool) -> bool;
}


#[starknet::contract]
mod simple_test_contract {
    #[storage]
    struct Storage {
        cold: bool,
        hot: bool
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[external(v0)]
    impl SimpleTestContractImpl of super::ISimpleTestContract<ContractState> {
        fn is_cold(self: @ContractState) -> bool {
            self.cold.read()
        }
        fn set_cold(ref self: ContractState, value: bool) -> bool {
            self.cold.write(value);
            true
        }

        fn is_hot(self: @ContractState) -> bool {
            self.hot.read()
        }
        fn set_hot(ref self: ContractState, value: bool) -> bool {
            self.hot.write(value);
            true
        }
    }

    #[generate_trait]
    impl SelectorImpl of SelectorTrait {
        fn set_cold_selector() -> felt252 {
            0x14a24dde590d15d7b2badc175b57ed320ecd5aeedeecdbf37bb416468a803f4
        }

        fn set_hot_selector() -> felt252 {
            0x2c81efed6fafcf729db2ebb634696da33f728c89b173d15f1f74c71a632da58
        }
    }
}
