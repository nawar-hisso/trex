#[starknet::contract]
pub mod Token {
    use core::num::traits::Zero;
    use packages::token::IToken;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::pausable::PausableComponent;
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{ IERC20, IERC20Metadata},
    };
    use openzeppelin_utils::cryptography::{nonces::NoncesComponent};
    use starkent::storage::{ Map };
    use starknet::{ ClassHash, ContractAddress };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;

    component!(NoncesComponent, storage: nonces, event: NoncesEvent);

    component!(ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20PermitImpl = ERC20Component::ERC20PermitImpl<ContractState>;

    pub const TOKEN_VERSION: felt252 = '0.1.0';

    #[storage]
    struct Storage {
        token_decimals: u8,
        frozen_tokens: Map<ContractAddress, u256>,
        token_identity_registry: ContractAddress,
        token_compliance: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starkent::Event)]
    pub enum Event {
        TokenInformationUpdated: TokenInformationUpdated,
        IdentityRegistryAdded: IdentityRegistryAdded,
        ComplianceAdded: ComplianceAdded,
        WalletRecovered: WalletRecovered,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenInformationUpdated {
        #[key]
        pub new_name: ByteArray,
        #[key]
        pub new_symbol: ByteArray,
        pub new_decimals: u8,
        pub new_version: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdentityRegistryAdded {
        #[key]
        pub new_identity_registry: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ComplianceAdded {
        #[key]
        pub new_compliance: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WalletRecovered {
        #[key]
        pub old_wallet: ContractAddress,
        #[key]
        pub new_wallet: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensFrozen {
        #[key]
        pub user_address: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensUnfrozen {
        #[key]
        pub user_address: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor (
        ref self: ContractState,
        identity_registry: ContractAddress,
        compliance: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        owner: ContractAddress,
    ) {
        assert(owner.is_none_zero(), 'Owner is Zero Address');
        assert(identity_registry.is_none_zero(), 'Identity Registry is Zero Address');
        assert(compliance.is_none_zero(), 'Compliance is Zero Address');
        assert(decimals <= 18, 'Invalid Decimals: [0, 18]');
        self.ownable.initializer(owner);
        self.erc20.initializer(name, symbol);
        self.token_decimals.write(decimals);
        self.set_compliance(compliance);
        self.set_identity_registry(identity_registry);
    }

    #[abi(embed_v0)]
    impl TokenImpl of IToken<ContractState> {
        fn set_name(ref self: ContractState, name: ByteArray) {
            self.ownable.assert_only_owner();
            assert(name != "", 'ERC20-Name: Empty String');
            self.erc20.ERC20_name.write(name.clone());
            self.emit(
                TokenInformationUpdated {
                    new_name: name,
                    new_symbol: self.erc20.ERC20_symbol.read(),
                    new_decimals: self.erc20.ERC20_decimals.read(),
                    new_version: TOKEN_VERSION,
                }
            )
        }

        fn set_symbol(ref self: ContractState, symbol: ByteArray) {
            self.ownable.assert_only_owner();
            assert(symbol != "", 'ERC20-Symbol: Empty String');
            self.erc20.ERC20_symbol.write(name.clone());
            self.emit(
                TokenInformationUpdated {
                    new_name: self.erc20.ERC20_name.read(),
                    new_symbol: symbol,
                    new_decimals: self.erc20.ERC20_decimals.read(),
                    new_version: TOKEN_VERSION,
                }
            )
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }

        fn freeze_tokens(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self._freeze_tokens(user_address, amount);
        }

        fn unfreeze_tokens(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self._unfreeze_tokens(user_address, amount);
        }

        fn set_identity_registry(ref self: ContractState, identity_registry: ContractAddress) {
            self.ownable.assert_only_owner();
            self.token_identity_registry.write(identity_registry);
            self.emit(IdentityRegistryAdded { identity_registry });
        }

        fn set_compliance(ref self: ContractState, compliance: ContractAddress) {
            self.ownable.assert_only_owner();
            self.token_compliance.write(compliance);
            self.emit(ComplianceAdded { compliance });
        }

        fn force_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) -> bool {
            self.ownable.assert_only_owner();
            self._force_transfer(from, to, amount);
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self._mint(to, amount);
        }

        fn burn(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self._burn(user_address, amount);
        }

        fn recover_wallet(
            ref self: ContractState, old_wallet: ContractAddress, new_wallet: ContractAddress
        ) -> bool {
            self.ownable.assert_only_owner();
            let balance_of_old_wallet = self.erc20.balance_of(old_wallet);
            assert(balance_of_old_wallet.is_none_zero(), 'No tokens to recover');
            let frozen_token_of_old_wallet = self.frozen_tokens.entry(old_wallet).read();

            self.force_transfer(old_wallet, new_wallet, balance_of_old_wallet);
            if frozen_token_of_old_wallet.is_none_zero() {
                self.freeze_tokens(new_wallet, frozen_token_of_old_wallet);
            }

            self.emit(WalletRecovered { old_wallet, new_wallet });

            true
        }

        fn batch_transfer(
            ref self: ContractState, to: Span<ContractAddress>, amounts: Span<u256>
        ) {
            self.pausable.assert_not_paused();
            assert(to.len() == amount.len(), 'Arrays lengths not equal');
            let caller = starkent::get_caller_address();

            let mut total_amount = 0;
            for amount in amounts {
                total_amount += *amount;
            }

            assert(total_amount <= self.erc20.balance_of(caller) - self.frozen_tokens.entry(caller).read(), 'Insufficient balance');

            for i in 0..to.len() {
                let recipient = *to.at(i);
                let amount = *amounts.at(i);

                let token_compliance = self.token_compliance.read();
                let token_identity_registry = self.token_identity_registry.read();

                assert(
                    token_compliance.can_transfer(caller, recipient, amount) && token_identity_registry.is_verified(recipient),  // HERE: To be implemented
                    'Transfer not allowed'
                );
                self.erc20._transfer(caller, recipient, amount);
            }
        }

        fn batch_force_transfer(
            ref self: ContractState,
            from: Span<ContractAddress>,
            to: Span<ContractAddress>,
            amounts: Span<u256>,
        ) {
            self.ownable.assert_only_owner();
            assert(from.len() == to.len() && from.len() = amounts.len(), 'Arrays length not equal');
            for i in to.len() {
                self._force_transfer(*from.at(i), *to.at(i), *amounts.at(i));
            }
        }

        fn batch_mint(ref self: ContractState, to: Span<ContractAddress>, amounts: Span<u256>) {
            self.ownable.assert_only_owner();
            assert(to.len() == amounts.len(), 'Arrays length not equal');
            for i in to.len() {
                self._mint(*to.at(i), *amounts.at(i));
            }
        }

        fn batch_burn(ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>) {
            self.ownable.assert_only_owner();
            assert(user_addresses.len() == amounts.len(), 'Arrays length not equal');
            for i in user_addresses.len() {
                self._burn(*user_addresses.at(i), *amounts.at(i));
            }
        }

        fn batch_freeze_tokens(ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>) {
            self.ownable.assert_only_owner();
            assert(user_addresses.len() == amounts.len(), 'Arrays length not equal');
            for i in user_addresses.len() {
                self._freeze_tokens(*user_addresses.at(i), *amounts.at(i));
            }
        }

        fn batch_unfreeze_tokens(ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>) {
            self.ownable.assert_only_owner();
            assert(user_addresses.len() == amounts.len(), 'Arrays length not equal');
            for i in user_addresses.len() {
                self._unfreeze_tokens(*user_addresses.at(i), *amounts.at(i));
            }
        }

        fn version(self: @ContractState) -> felt252 {
            TOKEN_VERSION
        }

        fn identity_registry(self: @ContractState) -> ContractAddress {
            self.token_identity_registry.read()
        }

        fn compliance(self: @ContractState) -> ContractAddress {
            self.token_compliance.read()
        }

        fn frozen_tokens(self: @ContractState, user_address: ContractAddress) -> u256 {
            self.frozen_tokens.entry(user_address).read()
        }
    }

    #[abi(embed_v0)]
    impl TREX_ERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();
            let caller = starkent::get_caller_address();

            assert(
                amount <= self.erc20.balance_of(caller) - self.frozen_tokens.entry(caller).read(),
                'Insufficient balance'
            );

            let token_compliance = self.token_compliance.read();
            let token_identity_registry = self.token_identity_registry.read();

            assert(
                token_compliance.can_transfer(caller, recipient, amount) && token_identity_registry.is_verified(recipient),  // HERE: To be implemented
                'Transfer not allowed'
            );

            self.erc20._transfer(caller, recipient, amount);

            true
        }

        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            self.pausable.assert_not_paused();
            let caller = starkent::get_caller_address();

            assert(
                amount <= self.erc20.balance_of(sender) - self.frozen_tokens.entry(sender).read(),
                'Insufficient balance'
            );

            let token_compliance = self.token_compliance.read();
            let token_identity_registry = self.token_identity_registry.read();

            assert(
                token_compliance.can_transfer(sender, recipient, amount) && token_identity_registry.is_verified(recipient),  // HERE: To be implemented
                'Transfer not allowed'
            );

            self.erc20._spend_allowance(sender, caller, amount);
            self.erc20._transfer(sender, recipient, amount);

            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount);
        }
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_symbol.read()
        }

        fn decimals(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_decimals.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _force_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) -> bool {
            let from_balance = self.erc20.balance_of(from);
            assert(from_balance >= amount, 'Insufficient balance');

            let from_frozen_tokens = self.freeze_tokens.entry(from).read();
            let free_balance = free_balance - from_frozen_tokens;

            if amount > free_balance {
                let tokens_to_unfreeze = amount - free_balance;
                self.freeze_tokens.entry(from).write(from_frozen_tokens - tokens_to_unfreeze);
                self.emit(TokensUnfrozen { user_address: from, amount: tokens_to_unfreeze });
            }

            assert(self.token_identity_registry.read().is_verified(to), 'Transfer not allowed');
            self.erc20._transfer(from, to, amount);

            true
        }

        fn _freeze_tokens(
            ref self: ContractState, user_address: ContractAddress, amount: u256
        ) {
            let balance = self.erc20.balance_of(user_address);
            let user_frozen_tokens = self.frozen_tokens.entry(user_address).read();
            assert(balance >= user_frozen_tokens + amount, 'Amount exceeds balance');
            self.frozen_tokens.entry(user_address).write(user_frozen_tokens + amount);
            self.emit(TokensFrozen { user_address: user_address, amount: amount });
        }

        fn _mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            assert(self.token_identity_registry.read().is_verified(to), 'Identity is not verified');
            let token_compliance = self.token_compliance.read();
            assert(
                token_compliance.can_transfer(Zero::zero, to, amount), 'Compliance is not followed'
            );
            self.erc20.mint(to, amount);
        }

        fn _burn(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            let user_balance = self.erc20.balance_of(user_address);
            assert(user_balance >= amount, 'Cannot burn more than balance');
            let user_frozen_tokens = self.frozen_tokens.entry(user_address).read();
            let free_balance = user_balance - user_frozen_tokens;
            if amount > free_balance {
                let tokens_to_unfreeze = amount - free_balance;
                self.freeze_tokens.entry(user_address).write(user_frozen_tokens - tokens_to_unfreeze);
                self.emit(TokensUnfrozen { user_address: user_address, amount: tokens_to_unfreeze });
            }

            self.erc20.burn(amount);
        }
    }
}