use array::ArrayTrait;
use array::SpanTrait;
use starknet::account::Call;
use starknet::ContractAddress;

#[starknet::interface]
trait IMasterControl<TState> {
    fn update_whitelisted_contracts(ref self: TState, data: Array<(ContractAddress, bool)>);
    fn update_whitelisted_calls(ref self: TState, data: Array<(ContractAddress, felt252, bool)>);
    fn function_call(ref self: TState, data: Array<Call>) -> Array<Span<felt252>>;
}
