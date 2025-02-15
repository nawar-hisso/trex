use starknet::ContractAddress;

#[starknet::interface]
pub trait IToken<TContractState> {
    fn set_name(ref self: TContractState, name: ByteArray);
    fn set_symbol(ref self: TContractState, symbol: ByteArray);

    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn freeze_tokens(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn unfreeze_tokens(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn batch_freeze_tokens(ref self: TContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>);
    fn batch_unfreeze_tokens(ref self: TContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>);
    fn set_identity_registry(ref self: TContractState, identity_registry: ContractAddress);
    fn set_compliance(ref self: TContractState, compliance: ContractAddress);
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn force_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    fn batch_transfer(ref self: TContractState, to: Span<ContractAddress>, amounts: Span<u256>) -> bool;
    fn batch_force_transfer(ref self: TContractState, from: Span<ContractAddress>, to: Span<ContractAddress>, amounts: Span<u256>) -> bool;

    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn recover_wallet(ref self: TContractState, old_wallet: ContractAddress, new_wallet: ContractAddress) -> bool;
    fn batch_mint(ref self: TContractState, to: Span<ContractAddress>, amounts: Span<u256>);
    fn batch_burn(ref self: TContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>);
    fn identity_registry(self: @TContractState) -> ContractAddress;
    fn compliance(self: @TContractState) -> ContractAddress;
    fn frozen_tokens(self: @TContractState, user_address: ContractAddress) -> u256;
}