module knw_evos::evos {
    
    use std::ascii;
    use std::option;
    use std::string::{Self, String};
    use std::vector;
    
    use sui::url::{Self, Url};
    use sui::display;
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::dynamic_object_field as ofield;

    use nft_protocol::tags;
    use nft_protocol::royalty;
    use nft_protocol::creators;
    use nft_protocol::transfer_allowlist;
    use nft_protocol::p2p_list;
    use nft_protocol::collection;
    use nft_protocol::royalty_strategy_bps;
    use nft_protocol::attributes::{Self, Attributes};
    use nft_protocol::display_info;

    use ob_pseudorandom::pseudorandom;
    use ob_utils::utils;
    use ob_utils::display as ob_display;
    use ob_permissions::witness;
    use ob_request::transfer_request;
    use ob_request::borrow_request::{Self, BorrowRequest, ReturnPromise};

    use knw_genesis::evosgenesisegg::{Self, EvosGenesisEgg};


    // ============== Constant parameters. These cannot be modified by anyone. ==============
    const REVEAL_TIME: u64 = 432000000; // 5d * 24h * 60h * 60m * 1000ms
    const EVOS_SUPPLY: u64 = 5000;
    const MAX_U32: u32 = 4294967295;
    const VERSION: u64 = 1;
    const COLLECTION_CREATOR: address = @0x74a54d924aca2040b6c9800123ad9232105ea5796b8d5fc23af14dd3ce0f193f;

    /// One time witness is only instantiated in the init method
    struct EVOS has drop {}
    struct Witness has drop {}
    struct AdminCap has key, store { id: UID }
    struct Evos has key, store {
        id: UID,
        index: u64,
        name: String,
        stage: String,
        specis: String,
        xp: u32,
        gems: u32,
        url: Url,
        attributes: Attributes
    }

    // struct EvosGenesisEgg has key, store {
    //     id: UID,
    //     name: String,
    //     url: Url
    // }

    struct Incubator has key {
        id: UID,
        inhold: u64,
        admin: address,
        specs: vector<Specie>,
        index: u64,
        slots: vector<ID>,
        version: u64
    }

    struct Slot has key, store {
        id: UID,
        deposit_at: u64,
        owner: address,
    }

    struct Specie has store {
        name: String,
        weight: u8,
        url: vector<u8>,
    }

    // ============== Errors ==============
    const ENotOwner: u64 = 1;
    const ENotReady: u64 = 2;
    const EInsufficientGems: u64 = 3;
    const EInsufficientXp: u64 = 3;
    const EMaxGemsExceeded: u64 = 4;
    const EMaxXpExceeded: u64 = 5;
    const ENotAdmin: u64 = 6;
    const EWrongVersion: u64 = 7;
    const ENotUpgrade: u64 = 8;


    // ============== INIT ==============
    fun init(otw: EVOS, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let admin = AdminCap {
            id: object::new(ctx),
        };

        // Init Collection & MintCap with unlimited supply
        let (collection, mint_cap) = collection::create_with_mint_cap<EVOS, Evos>(
            &otw, option::some(EVOS_SUPPLY), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let dw = witness::from_witness(Witness {});

        // Init Display
        let tags = vector[tags::art(), tags::collectible()];
        let display = display::new<Evos>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name} #{index}"));
        display::add(&mut display, string::utf8(b"tags"), ob_display::from_vec(tags));
        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));

        collection::add_domain(
            dw,
            &mut collection,
            display_info::new(
                string::utf8(b"ev0s"),
                string::utf8(b"ev0s is an evolutionary NFT adventure that pushes Dynamic NFTs to their fullest potential on Sui"),
            ),
        );

        let creators = vector[COLLECTION_CREATOR];
        let shares = vector[10_000]; // 2_000 BPS == 20%
        // Creators domain
        collection::add_domain(
            dw,
            &mut collection,
            creators::new(utils::vec_set_from_vec(&creators)),
        );

        let shares = utils::from_vec_to_map(creators, shares);
        royalty_strategy_bps::create_domain_and_add_strategy(
            dw, &mut collection, royalty::from_shares(shares, ctx), 100, ctx,
        );

        // === TRANSFER POLICIES ===

        // Creates a new policy and registers an allowlist rule to it.
        // Therefore now to finish a transfer, the allowlist must be included
        // in the chain.
        let (transfer_policy, transfer_policy_cap) =
            transfer_request::init_policy<Evos>(&publisher, ctx);

        royalty_strategy_bps::enforce(&mut transfer_policy, &transfer_policy_cap);
        transfer_allowlist::enforce(&mut transfer_policy, &transfer_policy_cap);

        // P2P Transfers are a separate transfer workflow and therefore require a
        // separate policy
        let (p2p_policy, p2p_policy_cap) =
            transfer_request::init_policy<Evos>(&publisher, ctx);

        p2p_list::enforce(&mut p2p_policy, &p2p_policy_cap);

        // Species
        let specs: vector<Specie> = vector<Specie>[
            Specie {name: string::utf8(b"Fire"), weight: 1u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/fire.jpeg"},
            Specie {name: string::utf8(b"Rock"), weight: 1u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/rock.jpeg"},
            Specie {name: string::utf8(b"Water"), weight: 1u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/water.jpeg"},
            Specie {name: string::utf8(b"Forest"), weight: 1u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/forest.jpeg"},
            Specie {name: string::utf8(b"Gold"), weight: 1u8, url: b"ipfs://baseeagle"},
        ];

        let incubator = Incubator {
            id: object::new(ctx),
            inhold: 0,
            index: 0,
            admin: sender,
            specs,
            slots: vector::empty<ID>(),
            version: VERSION
        };

        transfer::share_object(incubator);
        transfer::transfer(admin, tx_context::sender(ctx));
        transfer::public_transfer(mint_cap, sender);
        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(transfer_policy_cap, sender);
        transfer::public_transfer(p2p_policy_cap, sender);
        transfer::public_share_object(collection);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(p2p_policy);
        //transfer::public_transfer(mint_egg(ctx), sender);
    }

    // ============== Module entries ==============

    /*  Deposit an evos egg into the incubator.
    **  It adds a Slot object to the Incubator.
    */
    public entry fun deposit(
        incubator: &mut Incubator,
        nft: EvosGenesisEgg,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(VERSION == incubator.version, EWrongVersion);
        let sender = tx_context::sender(ctx);
        let slot = Slot {
            id: object::new(ctx),
            deposit_at: clock::timestamp_ms(clock),
            owner: sender
        };
        vector::push_back<ID>(&mut incubator.slots, object::id(&slot));

        ofield::add(&mut slot.id, true, nft);
        ofield::add(&mut incubator.id, object::id(&slot), slot);
        incubator.inhold = incubator.inhold + 1;
    }

    /*  Withdraw an evos egg from the incubator.
    **  It destroy the Slot.
    */
    public entry fun withdraw(
        incubator: &mut Incubator,
        nft_id: ID,
        ctx: &mut TxContext
    ) {
        // assert(VERSION == incubator.version, EWrongVersion);

        let Slot {
            id,
            owner,
            deposit_at: _,
        } = ofield::remove(&mut incubator.id, nft_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        let egg: EvosGenesisEgg = ofield::remove(&mut id, true);
        object::delete(id);
        transfer::public_transfer(egg, tx_context::sender(ctx))
    }

    /*  Reveal the incubated egg.
    **  It mints a Evos.
    **  It panics if REVEAL_TIME isnt elapsed since the incubation time.
    */
    public entry fun reveal(
        incubator: &mut Incubator,
        slot_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(VERSION == incubator.version, EWrongVersion);

        let Slot {
            id,
            owner,
            deposit_at,
        } = ofield::remove(&mut incubator.id, slot_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);
        assert!(revealable_in(deposit_at, clock) == 0, ENotReady);

        let egg: EvosGenesisEgg = ofield::remove(&mut id, true);
        object::delete(id);
        evosgenesisegg::burn(egg);
        transfer::public_transfer(
            mint_evos(incubator, ctx),
            owner
        );
        incubator.inhold = incubator.inhold - 1;

        let slot_index = 0;
        let slot_count = vector::length(&incubator.slots);
        while (slot_count > slot_index) {
            let sid = vector::borrow(&incubator.slots, slot_index);
            if (*sid == slot_id) {
                break
            };

            slot_index = slot_index + 1;
        };

        vector::remove(&mut incubator.slots, slot_index);
        // mint_event::emit_mint(
        //     witness::from_witness(Witness {}),
        //     mint_cap::collection_id(incubator.mint_cap),
        //     &evos,
        // );
    }

    public entry fun migrate(incubator: &mut Incubator, _: &AdminCap, ctx: &mut TxContext) {
        assert!(incubator.admin == tx_context::sender(ctx), ENotAdmin);
        assert!(incubator.version < VERSION, ENotUpgrade);
        incubator.version = VERSION;
    }

    /*  Add a new specis.
    **  This must be called from an authorized party.
    **  It create a new Specie and adds it to the incubator supported species.
    */
    public entry fun add_specie(
        _: &AdminCap,
        incubator: &mut Incubator,
        name: String,
        weight: u8,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == incubator.admin, ENotOwner);
        vector::push_back(&mut incubator.specs, create_specie(name, weight, url));
    }

    // ============= Getters =============

    // Incubator
    public fun index(incubator: &Incubator): u64 {
        incubator.index
    }
    public fun species(incubator: &Incubator): &vector<Specie> {
        &incubator.specs
    }
    public fun inhold(incubator: &Incubator): u64 {
        incubator.inhold
    }
    public fun admin(incubator: &Incubator): address {
        incubator.admin
    }

    // Slot
    public fun revealable_at(slot: &Slot): u64 {
        slot.deposit_at + REVEAL_TIME
    }
    public fun owner(slot: &Slot): address {
        slot.owner
    }

    // Specie
    public fun name(specie: &Specie): String {
        specie.name
    }
    public fun weight(specie: &Specie): u8 {
        specie.weight
    }

    // Evos
    public fun url(evos: &Evos): Url {
        evos.url
    }
    public fun stage(evos: &Evos): String {
        evos.stage
    }
    public fun specis(evos: &Evos): String {
        evos.specis
    }
    public fun xp(evos: &Evos): u32 {
        evos.xp
    }
    public fun gems(evos: &Evos): u32 {
        evos.gems
    }
    public fun get_nft_field<Auth: drop, Field: store>(
        request: &mut BorrowRequest<Auth, Evos>,
    ): (Field, ReturnPromise<Evos, Field>) {
        let dw = witness::from_witness(Witness {});
        let nft = borrow_request::borrow_nft_ref_mut(dw, request);
        borrow_request::borrow_field(dw, &mut nft.id)
    }
    public fun return_nft_field<Auth: drop, Field: store>(
        request: &mut BorrowRequest<Auth, Evos>,
        field: Field,
        promise: ReturnPromise<Evos, Field>,
    ) {
        let dw = witness::from_witness(Witness {});
        let nft = borrow_request::borrow_nft_ref_mut(dw, request);

        borrow_request::return_field(dw, &mut nft.id, promise, field)
    }
    public fun get_nft<Auth: drop>(
        request: &mut BorrowRequest<Auth, Evos>,
    ): Evos {
        let dw = witness::from_witness(Witness {});
        borrow_request::borrow_nft(dw, request)
    }
    public fun return_nft<Auth: drop>(
        request: &mut BorrowRequest<Auth, Evos>,
        nft: Evos,
    ) {
        let dw = witness::from_witness(Witness {});
        borrow_request::return_nft(dw, request, nft);
    }

    // Setters
    // Evos
    public fun add_gems(incubator: &Incubator, evos: &mut Evos, amount: u32, ctx: &mut TxContext): u32 {
        assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        assert!(evos.gems+amount <= MAX_U32, EMaxGemsExceeded);
        evos.gems = evos.gems + amount;
        evos.gems
    }
    public fun sub_gems(incubator: &Incubator, evos: &mut Evos, amount: u32, ctx: &mut TxContext): u32 {
        assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        assert!(evos.gems >= amount, EInsufficientGems);
        evos.gems = evos.gems - amount;
        evos.gems
    }
    public fun add_xp(incubator: &Incubator, evos: &mut Evos, amount: u32, ctx: &mut TxContext): u32 {
        assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        assert!(evos.xp+amount <= MAX_U32, EMaxXpExceeded);
        evos.xp = evos.xp + amount;
        evos.xp
    }
    public fun sub_xp(
        incubator: &Incubator,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ): u32 {
        assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        assert!(evos.xp >= amount, EInsufficientXp);
        evos.xp = evos.xp - amount;
        evos.xp
    }
    public fun update_url(
        incubator: &Incubator,
        evos: &mut Evos,
        new_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        evos.url = url::new_unsafe_from_bytes(new_url);
    }

    // Incubator


    // ============== Constructors. These create new Sui objects. ==============

    /*  
    ** Create an Evos.
    */
    fun mint_evos(
        incubator: &mut Incubator,
        ctx: &mut TxContext
    ): Evos {

        //let mint_cap = ofield::borrow_mut<ascii::String,MintCap>(&mut incubator.id, string::utf8(b"mint_authority"));
        //let collection_id: ID = mint_cap::collection_id(mint_cap);
        incubator.index = incubator.index + 1;

        let nonce = vector::empty();
        vector::append(&mut nonce, sui::bcs::to_bytes(&incubator.index));
        let contract_commitment = pseudorandom::rand_no_counter(nonce, ctx);
        let index = select(incubator.index, &contract_commitment);

        let specie: &Specie = vector::borrow<Specie>(&incubator.specs, index);

        let evos = Evos {
            id: object::new(ctx),
            index: incubator.index,
            name: string::utf8(b"Evos"),
            url: url::new_unsafe_from_bytes(specie.url),
            stage: string::utf8(b"Egg"),
            specis: specie.name,
            gems: 0,
            xp: 0,
            attributes: attributes::from_vec(
                vector[ascii::string(b"gems"), ascii::string(b"xp"), ascii::string(b"specis"), ascii::string(b"stage")],
                vector[ascii::string(b"0"), ascii::string(b"0"), string::to_ascii(specie.name), ascii::string(b"Egg")]
            )
        };

        evos
    }

    /*  
    ** Burn an Evos.
    */
    fun burn_evos(evos: Evos) {
        let Evos {
            id,
            name: _,
            specis: _,
            index: _,
            gems: _,
            xp: _,
            stage: _,
            url: _,
            attributes: _
        } = evos;
        object::delete(id);
    }

    /*  
    ** Create a new Specie.
    */
    fun create_specie(
        name: String,
        weight: u8,
        url: vector<u8>
    ): Specie {
        Specie { name, weight, url}
    }

    // ============= UTILS =============
    fun select(bound: u64, random: &vector<u8>): u64 {
        let random = pseudorandom::u256_from_bytes(random);
        // debug::print(&bound);
        let mod  = random % (bound as u256);
        (mod as u64)
    }

    // Returns ms left to revealability.
    // it's public because of it can be safely combined with revealable_at(Slot) (revealable_in(revealable_at(slot)))
    public fun revealable_in(
        deposit_ms: u64,
        clock: &Clock
    ): u64 {
        let now_ms: u64 = clock::timestamp_ms(clock);
        let elapsed_ms: u64 = now_ms - deposit_ms;
        if(elapsed_ms > REVEAL_TIME){0}
        else{REVEAL_TIME - elapsed_ms}
    }

    #[test_only]
    use sui::test_scenario::{Self, ctx};
    #[test_only]
    use nft_protocol::collection::Collection;

    // #[test_only]
    // use std::debug;

    #[test_only]
    const CREATOR: address = @0xA1C04;
    const CLOCK: address = @0x6;

    #[test_only]
    fun create_clock(ctx: &mut TxContext) {
        let clock = clock::create_for_testing(ctx);
        clock::share_for_testing(clock);
    }

    // #[test_only]
    // public entry fun mint_egg_to_recipient(
    //     recipient: address,
    //     ctx: &mut TxContext
    // ) {
    //     let egg = mint_egg(ctx);
    //     transfer::public_transfer(egg, recipient)
    // }

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
    fun it_inits() {
        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<Incubator>(), 1);

        let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
        assert!(vector::length<Specie>(&incubator.specs) == 5, 6);

        assert!(test_scenario::has_most_recent_shared<Collection<Evos>>(), 0);

        test_scenario::return_shared(incubator);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    // #[test]
    // fun it_deposit() {

    //     let scenario = test_scenario::begin(CREATOR);
    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         CREATOR,
    //     );

    //     deposit(
    //         &mut incubator,
    //         egg,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);
        
    //     assert!(vector::length(&incubator.slots) == 1, 10);
    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);
    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // fun it_withdraw() {

    //     let scenario = test_scenario::begin(CREATOR);
    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to sender
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         CREATOR,
    //     );

    //     deposit(
    //         &mut incubator,
    //         egg,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     clock::increment_for_testing(&mut clock, 5000);
    //     let slots_uids = &incubator.slots;

    //     withdraw(
    //         &mut incubator,
    //         *vector::borrow<ID>(slots_uids, 0),
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         CREATOR,
    //     );
        
    //     test_scenario::return_to_address(CREATOR, egg);
    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);
    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // fun it_reveal() {

    //     let scenario = test_scenario::begin(CREATOR);
    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to sender
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         CREATOR,
    //     );
    //     //let egg_id = object::id(&egg);

    //     deposit(
    //         &mut incubator,
    //         egg,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     clock::increment_for_testing(&mut clock, REVEAL_TIME);

    //     let slots_uids = &incubator.slots;
    //     reveal(
    //         &mut incubator,
    //         *vector::borrow<ID>(slots_uids, 0),
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let evos = test_scenario::take_from_address<Evos>(
    //         &scenario,
    //         CREATOR,
    //     );
    //     test_scenario::return_to_address(CREATOR, evos);
    //     assert!(index(&incubator) == 1, 5);


    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);

    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // fun it_add_specis() {

    //     let scenario = test_scenario::begin(CREATOR);
    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to sender
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, CREATOR);

    //     add_specie(
    //         &admin_cap,
    //         &mut incubator,
    //         string::utf8(b"TEST"),
    //         1,
    //         b"https://test-specie.jpg",
    //         ctx(&mut scenario)
    //     );
    //     assert!(vector::length(&incubator.specs) == 6, 11);

    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);

    //     test_scenario::return_to_address(CREATOR, admin_cap);

    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // #[expected_failure(abort_code = ENotOwner)]

    // fun deny_add_specis() {
    //     let unauth_user: address = @0xA2F; 
    //     let scenario = test_scenario::begin(CREATOR);
    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to sender
    //     test_scenario::next_tx(&mut scenario, unauth_user);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, CREATOR);

    //     add_specie(
    //         &admin_cap,
    //         &mut incubator,
    //         string::utf8(b"TEST"),
    //         1,
    //         b"https://test-specie.jpg",
    //         ctx(&mut scenario)
    //     );
    //     assert!(vector::length(&incubator.specs) == 6, 11);

    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);
    //     test_scenario::return_to_address(CREATOR, admin_cap);

    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // fun incubator_stats_are_correct() {

    //     let scenario = test_scenario::begin(CREATOR);
    //     let user_a: address = @0xA;
    //     let user_b: address = @0xB;

    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to sender
    //     test_scenario::next_tx(&mut scenario, CREATOR);


    //     mint_egg_to_recipient(user_a, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     mint_egg_to_recipient(user_b, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, user_a);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);

    //     let egg_a = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         user_a,
    //     );

    //     deposit(
    //         &mut incubator,
    //         egg_a,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, user_b);

    //     let egg_b = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         user_b,
    //     );
    //     deposit(
    //         &mut incubator,
    //         egg_b,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, user_a);

    //     clock::increment_for_testing(&mut clock, REVEAL_TIME);
    //     let slots_uids = &incubator.slots;

    //     reveal(
    //         &mut incubator,
    //         *vector::borrow<ID>(slots_uids, 0),
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);
        
    //     //debug::print(&string::utf8(b"Revealed"));

    //     let evos = test_scenario::take_from_address<Evos>(
    //         &scenario,
    //         user_a,
    //     );
    //     test_scenario::return_to_address<Evos>(user_a, evos);

    //     assert!(index(&incubator) == 1, 5);
    //     assert!(inhold(&incubator) == 1, 7);
    //     assert!(admin(&incubator) == CREATOR, 8);

    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);

    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // #[expected_failure(abort_code = ENotOwner)]
    // fun xp_can_be_updated_only_by_admin_failcase() {

    //     let depositer: address = @0xAA;
    //     let unauth_user: address = @0xBB;
    //     let scenario = test_scenario::begin(CREATOR);

    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to CREATOR
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     mint_egg_to_recipient(depositer, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, depositer);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         depositer,
    //     );
        
    //     //let egg_id = object::id(&egg);

    //     deposit(
    //         &mut incubator,
    //         egg,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, depositer);

    //     clock::increment_for_testing(&mut clock, REVEAL_TIME);

    //     let slots_uids = &incubator.slots;
    //     reveal(
    //         &mut incubator,
    //         *vector::borrow<ID>(slots_uids, 0),
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, unauth_user);

    //     let evos = test_scenario::take_from_address<Evos>(
    //         &scenario,
    //         depositer,
    //     );
    //     add_xp(&incubator, &mut evos, 20u32, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     assert!(xp(&evos) == 20u32, 15);

    //     test_scenario::return_to_address(depositer, evos);
    //     assert!(index(&incubator) == 1, 5);

    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);

    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

    // #[test]
    // fun xp_can_be_updated_only_by_admin() {

    //     let depositer: address = @0xAA;
    //     let scenario = test_scenario::begin(CREATOR);

    //     create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to CREATOR
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     mint_egg_to_recipient(depositer, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, depositer);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         depositer,
    //     );
        
    //     //let egg_id = object::id(&egg);

    //     deposit(
    //         &mut incubator,
    //         egg,
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, depositer);

    //     clock::increment_for_testing(&mut clock, REVEAL_TIME);

    //     let slots_uids = &incubator.slots;
    //     reveal(
    //         &mut incubator,
    //         *vector::borrow<ID>(slots_uids, 0),
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let evos = test_scenario::take_from_address<Evos>(
    //         &scenario,
    //         depositer,
    //     );
    //     add_xp(&incubator, &mut evos, 20u32, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     assert!(xp(&evos) == 20u32, 15);

    //     test_scenario::return_to_address(depositer, evos);
    //     assert!(index(&incubator) == 1, 5);

    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);

    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);

    //     // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
    //     // test_scenario::return_to_sender(scenario, bag);
    // }

}