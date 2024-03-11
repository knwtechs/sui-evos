// Author: kunnow
// Company: KNW Technologies FZCO
// License: MIT

module knw_genesis::evosgenesisegg {

    use std::option;
    use std::vector;
    use std::string::{Self, String};

    use sui::url::{Self, Url};
    use sui::display;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as ofield;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::clock::{Self, Clock};
    //use sui::package::{Publisher};
    
    // use liquidity_layer_v1::orderbook;

    // use ob_kiosk::ob_kiosk;
    use ob_utils::utils;
    use ob_permissions::witness;
    use ob_request::transfer_request;
    use ob_request::borrow_request::{Self, BorrowRequest, ReturnPromise};


    use nft_protocol::tags;
    use nft_protocol::mint_event;
    use nft_protocol::royalty;
    use nft_protocol::creators;
    use nft_protocol::transfer_allowlist;
    use nft_protocol::p2p_list;
    use ob_utils::display as ob_display;
    use nft_protocol::collection;
    use nft_protocol::mint_cap::{Self, MintCap};
    use nft_protocol::royalty_strategy_bps;
    use nft_protocol::display_info;

    /// One time witness is only instantiated in the init method
    struct EVOSGENESISEGG has drop {}

    /// Can be used for authorization of other actions post-creation. It is
    /// vital that this struct is not freely given to any contract, because it
    /// serves as an auth token.
    struct Witness has drop {}

    const EMaxSupplyExceed: u64 = 0;
    const EPositionNotExists: u64 = 1;
    const EEntryIndexOutOfBounds: u64 = 2;
    const ENotEnoughSui: u64 = 3;
    const ETooManyItems: u64 = 4;
    const EEntryInsufficentAllowance: u64 = 5;
    const EOutOfBounds: u64 = 6;
    const EOwnerMismatch: u64 = 7;
    const EMathError: u64 = 8;
    const EPositionAlreadyExists: u64 = 9;
    const ENoWL: u64 = 10;
    const EPublicSaleClosed: u64 = 11;
    const EWhitelistSaleClosed: u64 = 12;
    const EZeroAmount: u64 = 13;
    const ETestDisabled: u64 = 14;
    // const EWrongBatchSize: u64 = 14;

    const COLLECTION_CREATOR: address = @0x74a54d924aca2040b6c9800123ad9232105ea5796b8d5fc23af14dd3ce0f193f;
    const MAX_SUPPLY: u64 = 6000;
    const MAX_PUBLIC_BULK_SIZE: u64 = 10;
    const MAX_WL_BULK_SIZE: u64 = 2;
    const SUI_WL_PRICE: u64 = 35000000000;
    const SUI_FULL_PRICE: u64 = 40000000000; // 100 SUI
    const WL_START: u64 = 1683820800000;
    const PUBLIC_START: u64 = 1683822600000;
    
    struct EvosGenesisEgg has key, store {
        id: UID,
        name: String,
        url: Url,
        sample: u64
    }

    struct MintTrackerCap has key, store { id: UID }
    struct MintTracker has key, store {
        id: UID,
        index: u64,
        max_supply: u64,
        sui_full_price: u64,
        sui_wl_price: u64,
        creator: address,
        mint_cap: MintCap<EvosGenesisEgg>,
        balance: Balance<SUI>,
        wl_start: u64,
        public_start: u64,
        wl_alloc: u64
    }

    struct Position has key, store {
        id: UID,
        owner: address,
        amount: u64
    }

    fun init(otw: EVOSGENESISEGG, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Init Collection & MintCap with unlimited supply
        let (collection, mint_cap) = collection::create_with_mint_cap<EVOSGENESISEGG, EvosGenesisEgg>(
            &otw, option::some(MAX_SUPPLY), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let dw = witness::from_witness(Witness {});

        // Init Display
        let tags = vector[tags::art(), tags::game_asset()];

        let display = display::new<EvosGenesisEgg>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name}"));
        display::add(&mut display, string::utf8(b"image_url"), string::utf8(b"{url}"));
        display::add(&mut display, string::utf8(b"tags"), ob_display::from_vec(tags));
        display::update_version(&mut display);

        transfer::public_transfer(display, tx_context::sender(ctx));

        let creators = vector[COLLECTION_CREATOR];
        let shares = vector[10_000];

        // Creators domain
        collection::add_domain(
            dw,
            &mut collection,
            creators::new(utils::vec_set_from_vec(&creators)),
        );

        collection::add_domain(
            dw,
            &mut collection,
            display_info::new(
                string::utf8(b"ev0s Genesis Eggs"),
                string::utf8(b"Your ev0s Genesis Egg is your pass to reveal your ev0s and start your adventure on the planet of S.U.I.\n\nChoose wisely WHEN to reveal your Ev0s Genesis Egg! The Journey Begins"),
            ),
        );

        // 5. Setup royalty basis points
        // 2_000 BPS == 20%
        let shares = utils::from_vec_to_map(creators, shares);
        royalty_strategy_bps::create_domain_and_add_strategy(
            dw, &mut collection, royalty::from_shares(shares, ctx), 500, ctx,
        );

        // === TRANSFER POLICIES ===

        // 6. Creates a new policy and registers an allowlist rule to it.
        // Therefore now to finish a transfer, the allowlist must be included
        // in the chain.
        let (transfer_policy, transfer_policy_cap) =
            transfer_request::init_policy<EvosGenesisEgg>(&publisher, ctx);

        royalty_strategy_bps::enforce(&mut transfer_policy, &transfer_policy_cap);
        transfer_allowlist::enforce(&mut transfer_policy, &transfer_policy_cap);

        // 7. P2P Transfers are a separate transfer workflow and therefore require a
        // separate policy
        let (p2p_policy, p2p_policy_cap) =
            transfer_request::init_policy<EvosGenesisEgg>(&publisher, ctx);

        p2p_list::enforce(&mut p2p_policy, &p2p_policy_cap);

        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(transfer_policy_cap, sender);
        transfer::public_transfer(p2p_policy_cap, sender);
        transfer::public_share_object(collection);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(p2p_policy);

        let tracker = create_tracker(
            mint_cap,
            MAX_SUPPLY,
            SUI_FULL_PRICE,
            SUI_WL_PRICE,
            PUBLIC_START,
            WL_START,
            sender,
            ctx
        );

        transfer::share_object(tracker);
        transfer::public_transfer(MintTrackerCap {
            id: object::new(ctx)
        }, sender);

    }

    // GETTERS
    public fun index(tracker: &MintTracker): u64 {
        tracker.index
    }
    public fun max_supply(tracker: &MintTracker): u64 {
        tracker.max_supply
    }
    public fun wl_alloc(tracker: &MintTracker): u64 {
        tracker.wl_alloc
    }
    public fun balance_value(_: &MintTrackerCap, tracker: &MintTracker): u64 {
        balance::value(&tracker.balance)
    }
    public fun sample(ege: &EvosGenesisEgg): u64 {
        ege.sample
    }
    public fun url(ege: &EvosGenesisEgg): Url {
        ege.url
    }
    public fun get_position(
        tracker: &MintTracker,
        account: address,
        _ctx: &mut TxContext
    ): &Position {
        ofield::borrow<address, Position>(&tracker.id, account)
    }
    public entry fun get_wl_spot_count(
        tracker: &MintTracker,
        account: address,
        _ctx: &mut TxContext
    ): u64 {
        if(!ofield::exists_<address>(&tracker.id, account)){
            0
        }else{
            ofield::borrow<address, Position>(&tracker.id, account).amount
        }
    }
    public entry fun is_whitelisted(
        tracker: &MintTracker,
        account: address,
        _ctx: &mut TxContext
    ): bool {
        if(ofield::exists_<address>(&tracker.id, account)){
            return ofield::borrow<address, Position>(&tracker.id, account).amount > 0
        };
        false
    }
    public fun public_start(tracker: &MintTracker): u64 {
        tracker.public_start
    }
    public fun wl_start(tracker: &MintTracker): u64 {
        tracker.wl_start
    }
    public fun wl_price(tracker: &MintTracker): u64 {
        tracker.sui_wl_price
    }
    public fun public_price(tracker: &MintTracker): u64 {
        tracker.sui_full_price
    }
    /* All the stats in one function, safe reqs for RPCs */
    public fun general_data(tracker: &MintTracker): vector<u64> {
        let data = vector::empty<u64>();
        vector::push_back<u64>(&mut data, tracker.wl_start);
        vector::push_back<u64>(&mut data, tracker.sui_wl_price);
        vector::push_back<u64>(&mut data, tracker.public_start);
        vector::push_back<u64>(&mut data, tracker.sui_full_price);
        vector::push_back<u64>(&mut data, tracker.max_supply);
        vector::push_back<u64>(&mut data, tracker.index);
        data
    }

    // ==== TRANSFER REQUESTS ====
    public fun get_nft_field<Auth: drop, Field: store>(
        request: &mut BorrowRequest<Auth, EvosGenesisEgg>,
    ): (Field, ReturnPromise<EvosGenesisEgg, Field>) {
        let dw = witness::from_witness(Witness {});
        let nft = borrow_request::borrow_nft_ref_mut(dw, request);

        borrow_request::borrow_field(dw, &mut nft.id)
    }
    public fun return_nft_field<Auth: drop, Field: store>(
        request: &mut BorrowRequest<Auth, EvosGenesisEgg>,
        field: Field,
        promise: ReturnPromise<EvosGenesisEgg, Field>,
    ) {
        let dw = witness::from_witness(Witness {});
        let nft = borrow_request::borrow_nft_ref_mut(dw, request);

        borrow_request::return_field(dw, &mut nft.id, promise, field)
    }
    public fun get_nft<Auth: drop>(
        request: &mut BorrowRequest<Auth, EvosGenesisEgg>,
    ): EvosGenesisEgg {
        let dw = witness::from_witness(Witness {});
        borrow_request::borrow_nft(dw, request)
    }
    public fun return_nft<Auth: drop>(
        request: &mut BorrowRequest<Auth, EvosGenesisEgg>,
        nft: EvosGenesisEgg,
    ) {
        let dw = witness::from_witness(Witness {});
        borrow_request::return_nft(dw, request, nft);
    }

    // ==== SETTERS ====
    public fun set_price(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        price: u64,
        _ctx: &mut TxContext
    ) {
        tracker.sui_full_price = price;
    }
    public fun set_wl_price(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        price: u64,
        _ctx: &mut TxContext
    ) {
        tracker.sui_wl_price = price;
    }
    public fun fix_supply(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        fixed: u64,
        _ctx: &mut TxContext
    ) {
        tracker.max_supply = fixed;
    }
    // use `burn_and_emit_event` instea
    public fun burn(
        evos: EvosGenesisEgg
    ) {
        let EvosGenesisEgg {id, name: _, url: _, sample: _} = evos;
        object::delete(id)
    }
    public fun burn_and_emit_event(
        tracker: &MintTracker,
        evos: EvosGenesisEgg
    ) {
        let dw = witness::from_witness(Witness{});
        let guard = mint_event::start_burn(dw, &evos);
        let EvosGenesisEgg {id, name: _, url: _, sample: _} = evos;
        mint_event::emit_burn(
            guard,
            mint_cap::collection_id(&tracker.mint_cap),
            id
        );
        //object::delete(id)
    }

    // ==== PRIVATE ====

    fun create_position(account: address, ctx: &mut TxContext): Position {
        Position {
            id: object::new(ctx),
            owner: account,
            amount: 2
            // entries: vector::empty<PositionEntry>()
        }
    }
    fun create_tracker(
        mint_cap: MintCap<EvosGenesisEgg>,
        max_supply: u64,
        sui_full_price: u64,
        sui_wl_price: u64,
        public_start: u64,
        wl_start: u64,
        creator: address,
        ctx: &mut TxContext
    ): MintTracker {
        MintTracker {
            id: object::new(ctx),
            index: 0,
            max_supply,
            sui_full_price,
            sui_wl_price,
            creator,
            balance: balance::zero<SUI>(),
            mint_cap,
            wl_start,
            public_start,
            wl_alloc: 0
        }
    }
    fun create_nft(
        delegated_witness: witness::Witness<EvosGenesisEgg>,
        tracker: &mut MintTracker,
        ctx: &mut TxContext,
    ): EvosGenesisEgg {

        let name = string::utf8(b"Ev0s Genesis Egg");
        tracker.index = tracker.index + 1;
        let nft = EvosGenesisEgg {
            id: object::new(ctx),
            name,
            url: url::new_unsafe_from_bytes(b"https://knw-gp.s3.eu-north-1.amazonaws.com/genesis.webp"),
            sample: tracker.index
        };

        mint_event::emit_mint(
            delegated_witness,
            mint_cap::collection_id(&tracker.mint_cap),
            &nft,
        );

        nft
    }
    // fun new_kiosk_with_nft(
    //     delegated_witness: witness::Witness<EvosGenesisEgg>,
    //     tracker: &mut MintTracker,
    //     receiver: address,
    //     ctx: &mut TxContext,
    // ) {
    //     let nft = create_nft(delegated_witness, tracker, ctx);
    //     let (kiosk, _) = ob_kiosk::new_for_address(receiver, ctx);
    //     ob_kiosk::deposit(&mut kiosk, nft, ctx);
    //     transfer::public_share_object(kiosk);
    // }
    fun add_whitelist_spot(
        tracker: &mut MintTracker,
        account: address,
        ctx: &mut TxContext
    ) {
        if(!ofield::exists_<address>(&tracker.id, account)){
            ofield::add(&mut tracker.id, account, create_position(account, ctx));
            tracker.wl_alloc = tracker.wl_alloc + 1;
        }
    }

    // ==== ORDERBOOK ====
    // public entry fun init_protected_orderbook(
    //     publisher: &Publisher,
    //     transfer_policy: &sui::transfer_policy::TransferPolicy<EvosGenesisEgg>,
    //     ctx: &mut TxContext,
    // ) {
    //     let delegated_witness = witness::from_publisher(publisher);
    //     let orderbook = orderbook::new_with_protected_actions<EvosGenesisEgg, SUI>(
    //         delegated_witness, transfer_policy, orderbook::custom_protection(true, true, true), ctx,
    //     );
    //     orderbook::share(orderbook);
    // }
    // public entry fun enable_orderbook(
    //     publisher: &Publisher,
    //     orderbook: &mut orderbook::Orderbook<EvosGenesisEgg, SUI>,
    // ) {
    //     let delegated_witness = witness::from_publisher(publisher);

    //     orderbook::set_protection(
    //         delegated_witness, orderbook, orderbook::custom_protection(false, false, false),
    //     );
    // }
    // public entry fun disable_orderbook(
    //     publisher: &Publisher,
    //     orderbook: &mut orderbook::Orderbook<EvosGenesisEgg, SUI>,
    // ) {
    //     let delegated_witness = witness::from_publisher(publisher);

    //     orderbook::set_protection(
    //         delegated_witness, orderbook, orderbook::custom_protection(true, true, true),
    //     );
    // }

    // ==== MINTS ====
    public entry fun mint_wl_enabled(
        tracker: &mut MintTracker,
        paid: Coin<SUI>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(tracker.index + amount <= MAX_SUPPLY, EMaxSupplyExceed);
        assert!(tracker.wl_start <= clock::timestamp_ms(clock), EWhitelistSaleClosed);
        assert!(tracker.public_start > clock::timestamp_ms(clock), EWhitelistSaleClosed);
        assert!(amount > 0, EZeroAmount);

        assert!(amount <= MAX_WL_BULK_SIZE, ETooManyItems);
        let sender = tx_context::sender(ctx);
        assert!(is_whitelisted(tracker, sender, ctx), ENoWL);

        let full_price: u64 = tracker.sui_wl_price * amount;
        assert!(coin::value(&paid) >= full_price, ENotEnoughSui);

        let position = ofield::borrow_mut<address, Position>(&mut tracker.id, sender);
        assert!(amount <= position.amount, ETooManyItems);
        position.amount = position.amount - amount;

        let sBal: u64 = balance::value(&tracker.balance);
        coin::put(
            &mut tracker.balance,
            coin::take(coin::balance_mut(&mut paid), full_price, ctx)
        );
        assert!(balance::value(&tracker.balance) == sBal + full_price, EMathError);

        let delegated_witness = witness::from_witness(Witness {});

        let _current = 0;
        let sender = tx_context::sender(ctx);
        while(amount > _current){
            // new_kiosk_with_nft(delegated_witness, tracker, sender, ctx);
            transfer::public_transfer(
                create_nft(delegated_witness, tracker, ctx),
                sender
            );
            _current = _current + 1;
        };
        //assert!(_current = amount, EWrongBatchSize);
        transfer::public_transfer(paid, sender);
    }
    public entry fun public_mint(
        tracker: &mut MintTracker,
        paid: Coin<SUI>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(tracker.index + amount <= MAX_SUPPLY, EMaxSupplyExceed);
        assert!(amount <= MAX_PUBLIC_BULK_SIZE, ETooManyItems);
        assert!(tracker.public_start <= clock::timestamp_ms(clock), EPublicSaleClosed);

        let full_price = tracker.sui_full_price * amount;
        assert!(coin::value(&paid) >= full_price, ENotEnoughSui);

        let delegated_witness = witness::from_witness(Witness {});

        let current = 0;
        let sender = tx_context::sender(ctx);
        while(amount > current){
            //new_kiosk_with_nft(delegated_witness, tracker, sender, ctx);
            transfer::public_transfer(
                create_nft(delegated_witness, tracker, ctx),
                sender
            );
            current = current + 1;
        };

        let sbal: u64 = balance::value(&tracker.balance);
        if(coin::value(&paid) > full_price){
            let p = coin::split(&mut paid, full_price, ctx);
            coin::put(
                &mut tracker.balance,
                p
            );
            transfer::public_transfer(paid, tx_context::sender(ctx));
        }else{
            coin::put(
                &mut tracker.balance,
                paid
            );
        };
        
        assert!(balance::value(&tracker.balance) == sbal + full_price, EMathError);
    }
    public entry fun presale_mint(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(tracker.index + amount <= MAX_SUPPLY, EMaxSupplyExceed);
        
        let delegated_witness = witness::from_witness(Witness {});

        let _current = 0;
        while(amount > _current){
            // new_kiosk_with_nft(delegated_witness, tracker, recipient, ctx);
            transfer::public_transfer(
                create_nft(delegated_witness, tracker, ctx),
                recipient
            );
            _current = _current + 1;
        }
    }

    // public entry fun protect_with_kiosk(
    //     processor: &mut MintProcessorTracker,
    //     evos: EvosGenesisEgg,
    //     ctx: &mut TxContext
    // ) {
    //     let (kiosk, _) = ob_kiosk::new_for_address(tx_context::sender(ctx), ctx);
    //     ob_kiosk::deposit(&mut kiosk, evos, ctx);
    //     processor.processed = processor.processed + 1;
    //     transfer::public_share_object(kiosk);
    // }

    // ==== ADMIN ACTIONS ====
    public entry fun withdraw(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        recipient: address,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer(
            coin::from_balance<SUI>(
                balance::withdraw_all(&mut tracker.balance),
                ctx
            ),
            recipient
        );
    }
    public entry fun whitelist_user(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        account: address,
        ctx: &mut TxContext
    ) {
        assert!(!ofield::exists_<address>(&tracker.id, account), EPositionAlreadyExists);
        add_whitelist_spot(tracker, account, ctx);
    }
    public entry fun set_public_start(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        start_ms: u64,
        _ctx: &mut TxContext
    ) {
        tracker.public_start = start_ms;
    }
    public entry fun set_wl_start(
        _: &MintTrackerCap,
        tracker: &mut MintTracker,
        start_ms: u64,
        _ctx: &mut TxContext
    ) {
        tracker.wl_start = start_ms;
    }
    public entry fun new_admin(
        _: &MintTrackerCap,
        recipient: address,
        ctx: &mut TxContext
    ){
        let cap = MintTrackerCap {id: object::new(ctx)};
        transfer::public_transfer(cap, recipient)
    }

    // PUBLIC
    public entry fun burn_nft(
        tracker: &mut MintTracker,
        egg: EvosGenesisEgg,
        _ctx: &mut TxContext
    ) {
        //burn(egg);
        burn_and_emit_event(tracker, egg);
        tracker.index = tracker.index - 1;
    }

    /*************************************************/
    /*** REMOVE WHEN DEPLOYING OFFICIAL COLLECTION ***/
    /*************************************************/
    
    // #[test_only]
    public fun mint_for_test(
        tracker: &mut MintTracker,
        ctx: &mut TxContext
    ): EvosGenesisEgg {
        //assert!(false, ETestDisabled);
        let dw = witness::from_witness(Witness {});
        create_nft(dw, tracker, ctx)
    }

    #[test_only]
    public fun init_for_test(otw: EVOSGENESISEGG, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Init Collection & MintCap with unlimited supply
        let (collection, mint_cap) = collection::create_with_mint_cap<EVOSGENESISEGG, EvosGenesisEgg>(
            &otw, option::some(MAX_SUPPLY), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let dw = witness::from_witness(Witness {});

        // Init Display
        let tags = vector[tags::art(), tags::game_asset()];

        let display = display::new<EvosGenesisEgg>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name}"));
        display::add(&mut display, string::utf8(b"image_url"), string::utf8(b"{url}"));
        display::add(&mut display, string::utf8(b"tags"), ob_display::from_vec(tags));
        display::update_version(&mut display);

        transfer::public_transfer(display, tx_context::sender(ctx));

        let creators = vector[COLLECTION_CREATOR];
        let shares = vector[10_000];

        // Creators domain
        collection::add_domain(
            dw,
            &mut collection,
            creators::new(utils::vec_set_from_vec(&creators)),
        );

        collection::add_domain(
            dw,
            &mut collection,
            display_info::new(
                string::utf8(b"ev0s Genesis Eggs"),
                string::utf8(b"Your ev0s Genesis Egg is your pass to reveal your ev0s and start your adventure on the planet of S.U.I.\n\nChoose wisely WHEN to reveal your Ev0s Genesis Egg! The Journey Begins"),
            ),
        );

        // 5. Setup royalty basis points
        // 2_000 BPS == 20%
        let shares = utils::from_vec_to_map(creators, shares);
        royalty_strategy_bps::create_domain_and_add_strategy(
            dw, &mut collection, royalty::from_shares(shares, ctx), 500, ctx,
        );

        // === TRANSFER POLICIES ===

        // 6. Creates a new policy and registers an allowlist rule to it.
        // Therefore now to finish a transfer, the allowlist must be included
        // in the chain.
        let (transfer_policy, transfer_policy_cap) =
            transfer_request::init_policy<EvosGenesisEgg>(&publisher, ctx);

        royalty_strategy_bps::enforce(&mut transfer_policy, &transfer_policy_cap);
        transfer_allowlist::enforce(&mut transfer_policy, &transfer_policy_cap);

        // 7. P2P Transfers are a separate transfer workflow and therefore require a
        // separate policy
        let (p2p_policy, p2p_policy_cap) =
            transfer_request::init_policy<EvosGenesisEgg>(&publisher, ctx);

        p2p_list::enforce(&mut p2p_policy, &p2p_policy_cap);

        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(transfer_policy_cap, sender);
        transfer::public_transfer(p2p_policy_cap, sender);
        transfer::public_share_object(collection);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(p2p_policy);

        let tracker = create_tracker(
            mint_cap,
            MAX_SUPPLY,
            SUI_FULL_PRICE,
            SUI_WL_PRICE,
            PUBLIC_START,
            WL_START,
            sender,
            ctx
        );

        transfer::share_object(tracker);
        transfer::public_transfer(MintTrackerCap {
            id: object::new(ctx)
        }, sender);

    }

    #[test_only]
    public fun get_otw_for_test(): EVOSGENESISEGG {
        EVOSGENESISEGG {}
    }

    #[test_only]
    use sui::test_scenario::{Self, ctx};
    #[test_only]
    use nft_protocol::collection::Collection;
    // #[test_only]
    // use sui::kiosk::{Kiosk};


    #[test_only]
    const CREATOR: address = @0xA1C04;

    #[test_only]
    fun create_clock(ctx: &mut TxContext) {
        let clock = clock::create_for_testing(ctx);
        clock::share_for_testing(clock);
    }

    #[test_only]
    fun set_max_supply(tracker: &mut MintTracker, supply: u64, _ctx: &mut TxContext){
        tracker.max_supply = supply;
    }

    #[test]
    fun creating_a_clock_and_incrementing_it() {
        let ts = test_scenario::begin(@0x1);
        let ctx = test_scenario::ctx(&mut ts);

        create_clock(ctx);
        test_scenario::next_tx(&mut ts, CREATOR);

        let clock = test_scenario::take_shared<Clock>(&ts);

        clock::increment_for_testing(&mut clock, 20);
        clock::increment_for_testing(&mut clock, 22);
        assert!(clock::timestamp_ms(&clock) == 42, 0);

        test_scenario::return_shared(clock);
        test_scenario::end(ts);
    }

    #[test]
    fun it_inits_collection_and_tracker() {
        let scenario = test_scenario::begin(CREATOR);

        init(EVOSGENESISEGG {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<Collection<EvosGenesisEgg>>(), 0);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);
        assert!(tracker.sui_full_price == SUI_FULL_PRICE, 0);
        assert!(tracker.max_supply == MAX_SUPPLY, 1);
        assert!(balance::value(&tracker.balance) == 0, 2);

        test_scenario::return_shared(tracker);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_add_a_whitelist_spot() {
        let scenario = test_scenario::begin(CREATOR);
        let user = @0xAA;

        init(EVOSGENESISEGG {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<Collection<EvosGenesisEgg>>(), 0);

        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(
            &scenario,
            CREATOR
        );

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        whitelist_user(
            &tracker_cap,
            &mut tracker,
            user,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        test_scenario::return_shared(tracker);
        test_scenario::next_tx(&mut scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        // Check that position has been created
        let position = get_position(&tracker, user, ctx(&mut scenario));
        assert!(position.owner == user, 0);

        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::return_shared(tracker);
        test_scenario::next_tx(&mut scenario, CREATOR);

        test_scenario::end(scenario);
    }

    #[test]
    fun it_mints_whitelist_2_times() {

        let buyer: address = @0xBB;
        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, WL_START);
        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_wl_price(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        whitelist_user(&tracker_cap, &mut tracker, buyer, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, buyer);

        //let sui_coin = test_scenario::take_from_address<Coin<SUI>>(&scenario, CREATOR);
        let value = balance::create_for_testing<SUI>(0);

        assert!(is_whitelisted(&tracker, buyer, ctx(&mut scenario)), 0);
        mint_wl_enabled(
            &mut tracker,
            coin::from_balance(value, ctx(&mut scenario)),
            1u64,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, buyer);

        assert!(is_whitelisted(&tracker, buyer, ctx(&mut scenario)), 0);
        let value = balance::zero<SUI>();
        mint_wl_enabled(
            &mut tracker,
            coin::from_balance(value, ctx(&mut scenario)),
            1u64,
            &clock,
            ctx(&mut scenario)
        );

        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(!is_whitelisted(&tracker, buyer, ctx(&mut scenario)), 0);
        assert!(get_position(&tracker, buyer, ctx(&mut scenario)).amount == 0, 0);

        test_scenario::return_shared(tracker);
        test_scenario::return_shared(clock);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EWhitelistSaleClosed)]
    fun whitelist_is_closed() {

        let buyer: address = @0xBB;
        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let clock = test_scenario::take_shared<Clock>(&scenario);
        // clock::increment_for_testing(&mut clock, WL_START);
        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        whitelist_user(&tracker_cap, &mut tracker, buyer, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, buyer);

        //let sui_coin = test_scenario::take_from_address<Coin<SUI>>(&scenario, CREATOR);
        let value = balance::zero<SUI>();

        assert!(is_whitelisted(&tracker, buyer, ctx(&mut scenario)), 0);
        mint_wl_enabled(
            &mut tracker,
            coin::from_balance(value, ctx(&mut scenario)),
            1u64,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, buyer);

        assert!(is_whitelisted(&tracker, buyer, ctx(&mut scenario)), 0);
        let value = balance::zero<SUI>();
        mint_wl_enabled(
            &mut tracker,
            coin::from_balance(value, ctx(&mut scenario)),
            1u64,
            &clock,
            ctx(&mut scenario)
        );

        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(!is_whitelisted(&tracker, buyer, ctx(&mut scenario)), 0);
        assert!(get_position(&tracker, buyer, ctx(&mut scenario)).amount == 0, 0);

        test_scenario::return_shared(tracker);
        test_scenario::return_shared(clock);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_mints_presale_5_nfts() {
        
        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(tracker.index == 0, 0);
        presale_mint(
            &tracker_cap,
            &mut tracker,
            3u64,
            CREATOR,
            ctx(&mut scenario),
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        assert!(tracker.index == 3, 0);
        presale_mint(
            &tracker_cap,
            &mut tracker,
            2u64,
            CREATOR,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        assert!(tracker.index == 5, 0);

        // let kiosk = test_scenario::take_shared<Kiosk>(&scenario);
        // assert!(sui::kiosk::item_count(&mut kiosk) == 1u32, 0);

        let nft = test_scenario::take_from_address<EvosGenesisEgg>(&scenario, CREATOR);
        assert!(sample(&nft) == 5u64, 0);

        // test_scenario::return_shared(kiosk);
        test_scenario::return_to_address(CREATOR, nft);
        test_scenario::return_shared(tracker);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_timeout]
    fun it_mints_200_in_presale() {
        
        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(tracker.index == 0, 0);
        presale_mint(
            &tracker_cap,
            &mut tracker,
            200,
            CREATOR,
            ctx(&mut scenario)
        );
        assert!(tracker.index == 200, 0);
        test_scenario::next_tx(&mut scenario, CREATOR);

        // let kiosk = test_scenario::take_shared<Kiosk>(&scenario);
        // assert!(sui::kiosk::item_count(&mut kiosk) == 1u32, 0);
        let nft = test_scenario::take_from_address<EvosGenesisEgg>(&scenario, CREATOR);
        assert!(sample(&nft) == 200u64, 0);

        test_scenario::return_shared(tracker);
        // test_scenario::return_shared(kiosk);
        test_scenario::return_to_address(CREATOR, nft);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_mints_50_in_presale() {
        
        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(tracker.index == 0, 0);
        presale_mint(
            &tracker_cap,
            &mut tracker,
            50,
            CREATOR,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        assert!(tracker.index == 50, 0);

        // let kiosk = test_scenario::take_shared<Kiosk>(&scenario);
        // assert!(sui::kiosk::item_count(&mut kiosk) == 1u32, 0);
        let nft = test_scenario::take_from_address<EvosGenesisEgg>(&scenario, CREATOR);
        assert!(sample(&nft) == 50u64, 0);

        test_scenario::return_shared(tracker);
        // test_scenario::return_shared(kiosk);
        test_scenario::return_to_address(CREATOR, nft);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ENotEnoughSui)]
    fun it_mints_public_not_enough_sui() {

        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, PUBLIC_START);

        set_public_start(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        //let sui_coin = test_scenario::take_from_address<Coin<SUI>>(&scenario, CREATOR);
        let value = balance::zero<SUI>();
        public_mint(
            &mut tracker,
            coin::from_balance(value, ctx(&mut scenario)),
            3u64,
            &clock,
            ctx(&mut scenario)
        );

        test_scenario::return_shared(tracker);
        test_scenario::return_shared(clock);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_add_many_wl_spots() {

        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        whitelist_user(&tracker_cap, &mut tracker, @0xAA, ctx(&mut scenario));
        whitelist_user(&tracker_cap, &mut tracker, @0xAB, ctx(&mut scenario));
        whitelist_user(&tracker_cap, &mut tracker, @0xAC, ctx(&mut scenario));
        whitelist_user(&tracker_cap, &mut tracker, @0xAD, ctx(&mut scenario));
        whitelist_user(&tracker_cap, &mut tracker, @0xAE, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR); 

        assert!(tracker.wl_alloc == 5, 0);
        assert!(tracker.index == 0, 0);

        test_scenario::return_shared(tracker);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_checks_from_balance_change_after_mint() {

        let scenario = test_scenario::begin(CREATOR);
        let test_price: u64 = 100;
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);
        
        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let clock = test_scenario::take_shared<Clock>(&scenario);
        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, test_price, ctx(&mut scenario));
        set_public_start(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(balance::value(&tracker.balance) == 0, 0);
        assert!(tracker.sui_full_price == test_price, 0);
        public_mint(
            &mut tracker,
            coin::from_balance(balance::create_for_testing<SUI>(test_price*2), ctx(&mut scenario)),
            2u64,
            &clock,
            ctx(&mut scenario)
        );
        assert!(balance::value(&tracker.balance) == test_price*2, 0);

        test_scenario::return_shared(tracker);
        test_scenario::return_shared(clock);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_test_withdraw() {

        let scenario = test_scenario::begin(CREATOR);
        let buyer = @0xAB123;
        let treasury = @0xBB123;
        let test_price: u64 = 100;
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);
        
        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);


        let clock = test_scenario::take_shared<Clock>(&scenario);
        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_price(&tracker_cap, &mut tracker, test_price, ctx(&mut scenario));
        set_public_start(&tracker_cap, &mut tracker, 0, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, buyer);

        assert!(balance::value(&tracker.balance) == 0, 0);
        // debug::print(&value);
        public_mint(
            &mut tracker,
            coin::from_balance(balance::create_for_testing<SUI>(test_price*2), ctx(&mut scenario)),
            2u64,
            &clock,
            ctx(&mut scenario)
        );
        assert!(balance::value(&tracker.balance) == test_price*2, 0);

        test_scenario::next_tx(&mut scenario, CREATOR);
        withdraw(
            &tracker_cap,
            &mut tracker,
            treasury,
            ctx(&mut scenario)
        );
        assert!(balance::value(&tracker.balance) == 0, 0);
        test_scenario::next_tx(&mut scenario, CREATOR);

        let amount = test_scenario::take_from_address<Coin<SUI>>(&scenario, treasury);
        assert!(coin::value(&amount) == test_price*2, 0);

        test_scenario::return_shared(tracker);
        test_scenario::return_shared(clock);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::return_to_address(treasury, amount);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_burn() {
        
        let scenario = test_scenario::begin(CREATOR);
        init(EVOSGENESISEGG {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, CREATOR);
        let tracker_cap = test_scenario::take_from_address<MintTrackerCap>(&scenario, CREATOR);
        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        set_max_supply(&mut tracker, 50, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(tracker.index == 0, 0);
        presale_mint(
            &tracker_cap,
            &mut tracker,
            50,
            CREATOR,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        assert!(tracker.index == 50, 0);

        // let kiosks = ids_for_address<Kiosk>(CREATOR)
        // let kiosk = test_scenario::take_from_address<Kiosk>(&scenario, CREATOR);
        // let publisher = test_utils::get_publisher(ctx(&mut scenario));
        // let (tx_policy, policy_cap) = test_utils::init_withdrawable_policy(&publisher, ctx(&mut scenario));

        // let (nft, request) = ob_kiosk::withdraw_nft_signed<EvosGenesisEgg>(
        //     &mut kiosk,
        //     &object::id(nft),
        //     ctx(&mut scenario)
        // );
        // withdraw_request::confirm<EvosGenesisEgg>(request, &tx_policy);

        let nft = test_scenario::take_from_address<EvosGenesisEgg>(&scenario, CREATOR);
        burn_nft(
            &mut tracker,
            nft,
            ctx(&mut scenario)
        );
        assert!(tracker.index == 49, 0);
        test_scenario::return_shared(tracker);
        test_scenario::return_to_address(CREATOR, tracker_cap);
        test_scenario::end(scenario);
    }
}