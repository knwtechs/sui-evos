/* 
 * Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Module details:
 *  Friend: knw_evos::core
 *  Features:
 *      - Deposit an EvosGenesisEgg
 *      - Withdraw an EvosGenesisEgg
 *      - Reveal a deposited EvosGenesisEgg into an Evos:
 *          . The EvosGenesisEgg get burned
 *          . The Evos is deposited into a kiosk created for the user
 *      - (AdminCap) Add a new `Specie`
 *      - (friend) add_exp, sub_exp, add_gems, sub_gems
*/
#[lint_allow(share_owned)]
module knw_evos::evos {
    
    // UPDATE V4
    // friend knw_evos::evoscore;
    // END UPDATE V4

    use std::ascii;
    use std::option;
    use std::string::{Self, String};
    use std::vector;

    use sui::vec_map;
    use sui::sui::{SUI};
    use sui::url::{Self, Url};
    use sui::display;
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::dynamic_object_field as ofield;
    use sui::package::{Publisher};

    use nft_protocol::tags;
    use nft_protocol::royalty;
    use nft_protocol::creators;
    use nft_protocol::transfer_allowlist;
    use nft_protocol::p2p_list;
    use nft_protocol::collection;
    use nft_protocol::royalty_strategy_bps;
    use nft_protocol::attributes::{Self, Attributes};
    use nft_protocol::display_info;
    use nft_protocol::mint_event;
    use nft_protocol::mint_cap::{Self, MintCap};

    use ob_pseudorandom::pseudorandom;

    use ob_utils::utils;
    use ob_utils::display as ob_display;

    use ob_permissions::witness;

    use ob_request::transfer_request;
    use ob_request::borrow_request::{Self, BorrowRequest, ReturnPromise};

    use ob_kiosk::ob_kiosk;

    use liquidity_layer_v1::orderbook;

    use knw_genesis::evosgenesisegg::{Self, EvosGenesisEgg, MintTracker};

    const REVEAL_TIME: u64 = 432000000; // 5d * 24h * 60m * 60s * 1000ms
    #[allow(unused_const)]
    const MAX_U32: u32 = 4294967295;
    #[allow(unused_const)]
    const MAX_U64: u64 = (2^64) - 1;
    const VERSION: u64 = 3;
    const COLLECTION_CREATOR: address = @0x74a54d924aca2040b6c9800123ad9232105ea5796b8d5fc23af14dd3ce0f193f;
    #[allow(unused_const)]
    const COLLECTION_ADMIN: address = @0x1dae98dcae53909f23184b273923184aa451986c4b71da1950d749def37f8ea0;
    #[allow(unused_const)]
    const COLLECTION_DEPLOYER: address = @0x34f23af8106ecb5ada0c4ff956333ab234534a0060350f40b6e9518f861f7e02;

    struct EVOS has drop {}
    struct Witness has drop {}
    struct AdminCap has key, store { id: UID }
    /* Update V3 */
    struct UpdateCap has key, store { id: UID }

    struct Evos has key, store {
        id: UID,
        index: u64,
        name: String,
        stage: String,
        level: u32,
        species: String,
        xp: u32,
        gems: u32,
        url: Url,
        attributes: Attributes
    }

    struct Incubator has key {
        id: UID,
        inhold: u64,
        specs: vector<Specie>,
        specs_tot_weight: u8,
        index: u64,
        slots: vector<ID>,
        version: u64,
        mint_cap: MintCap<Evos>,
        evos_created: vector<ID>,
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
    #[allow(unused_const)]
    const EInsufficientGems: u64 = 3;
    #[allow(unused_const)]
    const EInsufficientXp: u64 = 3;
    #[allow(unused_const)]
    const EMaxGemsExceeded: u64 = 4;
    #[allow(unused_const)]
    const EMaxXpExceeded: u64 = 5;
    #[allow(unused_const)]
    const ENotAdmin: u64 = 6;
    const EWrongVersion: u64 = 7;
    const ENotUpgrade: u64 = 8;
    #[allow(unused_const)]
    const EU64Overflow: u64 = 9;
    const EEmptyStage: u64 = 10;
    #[allow(unused_const)]
    const ESpeciesInvalidIndex: u64 = 11;
    const ESpecsMaxWeightExceeded: u64 = 12;

    // ============== INIT ==============
    #[allow(unused_function)]
    fun init(otw: EVOS, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Init Collection & MintCap with unlimited supply
        let (collection, mint_cap) = collection::create_with_mint_cap<EVOS, Evos>(
            &otw, option::none(), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let dw = witness::from_witness(Witness {});

        // Init Display
        let tags = vector[tags::art(), tags::collectible()];
        let display = display::new<Evos>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name} #{index}"));
        display::add(&mut display, string::utf8(b"species"), string::utf8(b"{species}"));
        display::add(&mut display, string::utf8(b"stage"), string::utf8(b"{stage}"));
        display::add(&mut display, string::utf8(b"level"), string::utf8(b"{level}"));
        display::add(&mut display, string::utf8(b"xp"), string::utf8(b"{xp}"));
        display::add(&mut display, string::utf8(b"gems"), string::utf8(b"{gems}"));
        display::add(&mut display, string::utf8(b"attributes"), std::string::utf8(b"{attributes}"));
        display::add(&mut display, string::utf8(b"image_url"), std::string::utf8(b"{url}"));
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
        let shares = vector[10_000]; // 10_000 BPS == 100%

        // Creators domain
        collection::add_domain(
            dw,
            &mut collection,
            creators::new(utils::vec_set_from_vec(&creators)),
        );

        let shares = utils::from_vec_to_map(creators, shares);
        royalty_strategy_bps::create_domain_and_add_strategy(
            dw, &mut collection, royalty::from_shares(shares, ctx), 500, ctx,
        );

        // === TRANSFER POLICIES ===

        // Creates a new policy and registers an allowlist rule to it.
        // Therefore now to finish a transfer, the allowlist must be included
        // in the chain.
        let (transfer_policy, transfer_policy_cap) = transfer_request::init_policy<Evos>(&publisher, ctx);

        royalty_strategy_bps::enforce(&mut transfer_policy, &transfer_policy_cap);
        transfer_allowlist::enforce(&mut transfer_policy, &transfer_policy_cap);

        // P2P Transfers are a separate transfer workflow and therefore require a
        // separate policy
        let (p2p_policy, p2p_policy_cap) = transfer_request::init_policy<Evos>(&publisher, ctx);

        p2p_list::enforce(&mut p2p_policy, &p2p_policy_cap);

        // Species
        let specs: vector<Specie> = vector<Specie>[
            Specie {name: string::utf8(b"Gold"), weight: 5u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/gold.png"},
            Specie {name: string::utf8(b"Forest"), weight: 20u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/forest.png"},
            Specie {name: string::utf8(b"Water"), weight: 24u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/water.png"},
            Specie {name: string::utf8(b"Rock"), weight: 25u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/rock.png"},
            Specie {name: string::utf8(b"Fire"), weight: 26u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/fire.png"},
        ];

        let incubator = Incubator {
            id: object::new(ctx),
            inhold: 0,
            index: 0,
            specs,
            specs_tot_weight: 100,
            slots: vector::empty<ID>(),
            version: VERSION,
            mint_cap: mint_cap,
            evos_created: vector::empty<ID>()
        };

        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));

        transfer::share_object(incubator);
        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(transfer_policy_cap, sender);
        transfer::public_transfer(p2p_policy_cap, sender);
        transfer::public_share_object(collection);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(p2p_policy);
    }

    // ============== PUBLIC ==============

    /*  Deposit an evos egg into the incubator.
    **  It adds a Slot object to the Incubator.
    */
    // entry public deposit(Arg0: &mut Incubator, Arg1: EvosGenesisEgg, Arg2: &Clock, Arg3: &mut TxContext)
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
    // entry public withdraw(Arg0: &mut Incubator, Arg1: ID, Arg2: &mut TxContext)
    #[lint_allow(self_transfer)]
    public entry fun withdraw(
        incubator: &mut Incubator,
        slot_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(VERSION == incubator.version, EWrongVersion);

        let Slot {
            id,
            owner,
            deposit_at: _,
        } = ofield::remove(&mut incubator.id, slot_id);
        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        let egg: EvosGenesisEgg = ofield::remove(&mut id, true);
        object::delete(id);

        let slot_count = vector::length(&incubator.slots);
        let slot_index = 0;
        while (slot_count > slot_index) {
            let sid = vector::borrow(&incubator.slots, slot_index);
            if (*sid == slot_id) {
                break
            };
            slot_index = slot_index + 1;
        };
        vector::remove(&mut incubator.slots, slot_index);

        transfer::public_transfer(egg, tx_context::sender(ctx))
    }
    /*  Reveal the incubated egg.
    **  It mints a Evos.
    **  It panics if REVEAL_TIME isnt elapsed since the incubation time.
    */
    // entry public reveal(Arg0: &mut Incubator, Arg1: &mut MintTracker, Arg2: ID, Arg3: &Clock, Arg4: &mut TxContext)
    public entry fun reveal(
        incubator: &mut Incubator,
        tracker: &mut MintTracker,
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

        // Burn the Evos Genesis Egg
        let egg: EvosGenesisEgg = ofield::remove(&mut id, true);
        object::delete(id);
        evosgenesisegg::burn_nft(tracker, egg, ctx);

        // Mint Ev0s
        let dw = witness::from_witness(Witness {});
        new_kiosk_with_evos(dw, incubator, owner, ctx);

        // Update incubator
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
    }

    // public burn_evos(Arg0: Evos)
    public fun burn_evos(evos: Evos) {
        let Evos {
            id,
            name: _,
            species: _,
            index: _,
            gems: _,
            xp: _,
            stage: _,
            level: _,
            url: _,
            attributes: _
        } = evos;
        object::delete(id);
    }

    // entry public migrate(Arg0: &AdminCap, Arg1: &mut Incubator, Arg2: &mut TxContext)
    public entry fun migrate(
        _: &AdminCap,
        incubator: &mut Incubator,
        _ctx: &mut TxContext
    ) {
        assert!(incubator.version < VERSION, ENotUpgrade);
        incubator.version = VERSION;
    }
    
    //  Add a new species. This must be called from an authorized party.
    //  It create a new Specie and adds it to the incubator supported species.
    // entry public add_specie(Arg0: &AdminCap, Arg1: &mut Incubator, Arg2: String, Arg3: u8, Arg4: vector<u8>, Arg5: &mut TxContext)
    public entry fun add_specie(
        _: &AdminCap,
        incubator: &mut Incubator,
        name: String,
        weight: u8,
        url: vector<u8>,
        _ctx: &mut TxContext
    ) {
        assert!(incubator.specs_tot_weight + weight < 255, ESpecsMaxWeightExceeded);
        let i: u64 = 0;
        while(vector::length(&incubator.specs) > i){
            if(vector::borrow<Specie>(&incubator.specs, i).weight > weight){
                vector::insert(&mut incubator.specs, create_specie(name, weight, url), i);
                incubator.specs_tot_weight = incubator.specs_tot_weight + weight;
                break
            };
            i = i+1;
        }
    }
    // entry public give_admin_cap(Arg0: &AdminCap, Arg1: address, Arg2: &mut TxContext)
    public entry fun give_admin_cap(
        _: &AdminCap,
        recipient: address,
        ctx: &mut TxContext
    ){
        let cap = AdminCap {id: object::new(ctx)};
        transfer::public_transfer(cap, recipient)
    }

    // ==== GETTERS ====

    // Incubator
    public fun index(incubator: &Incubator): u64 {
        incubator.index
    }
    public fun specs(incubator: &Incubator): &vector<Specie> {
        &incubator.specs
    }
    public fun inhold(incubator: &Incubator): u64 {
        incubator.inhold
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
    public fun species(evos: &Evos): String {
        evos.species
    }
    public fun xp(evos: &Evos): u32 {
        evos.xp
    }
    public fun gems(evos: &Evos): u32 {
        evos.gems
    }
    public fun level(evos: &Evos): u32 {
        evos.level
    }

    // Accessors
    public fun revealable_in(
        deposit_ms: u64,
        clock: &Clock
    ): u64 {
        let now_ms: u64 = clock::timestamp_ms(clock);
        let elapsed_ms: u64 = now_ms - deposit_ms;
        if(elapsed_ms > REVEAL_TIME){0}
        else{REVEAL_TIME - elapsed_ms}
    }
    public fun all_evos_ids(
        incubator: &Incubator
    ): vector<ID> {
        incubator.evos_created
    }
    public fun get_evos_id_at(
        incubator: &Incubator,
        index: u64
    ): ID {
        assert!(vector::length(&incubator.evos_created) > index, 0);
        *vector::borrow(&incubator.evos_created, index)
    }
    public fun get_slots_id(
        incubator: &Incubator,
        _ctx: &mut TxContext
    ): vector<ID> {
        incubator.slots
    }
    public entry fun get_slot_revealable_at(
        nft_id: ID,
        incubator: &Incubator,
        _ctx: &mut TxContext
    ): u64 {
        revealable_at(ofield::borrow(&incubator.id, nft_id))
    }
    public entry fun get_slot_owner(
        nft_id: ID,
        incubator: &Incubator,
        _ctx: &mut TxContext
    ): address {
        owner(ofield::borrow(&incubator.id, nft_id))
    }

    // ==== TRANSFER REQUEST ====

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

    // SETTERS
    public(friend) fun set_gems(
        evos: &mut Evos,
        amount: u32,
        _ctx: &mut TxContext
    ): u32 {
        //assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        //assert!(evos.gems >= amount, EInsufficientGems);
        evos.gems = amount;
        evos.gems
    }
    public(friend) fun set_xp(
        evos: &mut Evos,
        amount: u32,
        _ctx: &mut TxContext
    ): u32 {
        //assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        //assert!(amount < MAX_U32, EMaxXpExceeded);
        evos.xp = amount;
        evos.xp
    }
    public(friend) fun update_url(
        evos: &mut Evos,
        new_url: vector<u8>,
        _ctx: &mut TxContext
    ) {
        evos.url = url::new_unsafe_from_bytes(new_url);
    }
    public(friend) fun set_stage(
        evos: &mut Evos,
        stage: vector<u8>,
        uri: vector<u8>,
        _xp: u32,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&stage) > 0, EEmptyStage);
        evos.stage = string::utf8(stage);
        update_url(evos, uri, ctx);
    }
    public(friend) fun set_level(
        evos: &mut Evos,
        level: u32,
        _ctx: &mut TxContext
    ) {
        evos.level = level
    }

    // It add an attribute with name=name and value=value ( update if already exists an attribute with key=name )
    // It removes an existings attribute if value=[0u8]
    public(friend) fun set_attribute(
        evos: &mut Evos,
        name: vector<u8>,
        value: vector<u8>,
        ctx: &mut TxContext
    ) {
        let attributes = attributes::get_attributes_mut(&mut evos.attributes);
        let key = ascii::string(name);
        if(vec_map::contains(attributes, &key)){
            if(vector::length(&value) == 1 && *vector::borrow(&value, 0) == 0u8){
                remove_attribute(evos, name, ctx);
            }else{
                *vec_map::get_mut(attributes, &key) = ascii::string(value);
            }
        }else{
            attributes::insert_attribute<Witness, Evos>(&mut evos.attributes, key, ascii::string(value));
        }
    }

    public fun has_attribute(
        evos: &mut Evos,
        name: vector<u8>,
        _ctx: &mut TxContext
    ): bool {
        vec_map::contains(
            attributes::get_attributes(&evos.attributes),
            &ascii::string(name)
        )
    }
    
    /* Update V3 */
    public fun get_attribute(
        evos: &Evos,
        name: vector<u8>
    ): ascii::String {
        let attributes = attributes::get_attributes(&evos.attributes);
        let name = &ascii::string(name);
        let x = vec_map::get(
            attributes,
            name
        );
        *x
    }

    /* Update V3 */
    public entry fun give_update_cap(
        _: &AdminCap,
        recipient: address,
        ctx: &mut TxContext
    ){
        let cap = UpdateCap {id: object::new(ctx)};
        transfer::public_transfer(cap, recipient)
    }

    // ==== ORDERBOOK ====
    public entry fun init_protected_orderbook(
        publisher: &Publisher,
        transfer_policy: &sui::transfer_policy::TransferPolicy<Evos>,
        ctx: &mut TxContext,
    ) {
        let delegated_witness = witness::from_publisher(publisher);
        let orderbook = orderbook::new_with_protected_actions<Evos, SUI>(
            delegated_witness, transfer_policy, orderbook::custom_protection(true, true, true), ctx,
        );
        orderbook::share(orderbook);
    }
    public entry fun enable_orderbook(
        publisher: &Publisher,
        orderbook: &mut orderbook::Orderbook<Evos, SUI>,
    ) {
        let delegated_witness = witness::from_publisher(publisher);

        orderbook::set_protection(
            delegated_witness, orderbook, orderbook::custom_protection(false, false, false),
        );
    }
    public entry fun disable_orderbook(
        publisher: &Publisher,
        orderbook: &mut orderbook::Orderbook<Evos, SUI>,
    ) {
        let delegated_witness = witness::from_publisher(publisher);

        orderbook::set_protection(
            delegated_witness, orderbook, orderbook::custom_protection(true, true, true),
        );
    }

    // ==== PRIVATE ====
    fun create_evos(
        delegated_witness: witness::Witness<Evos>,
        incubator: &mut Incubator,
        ctx: &mut TxContext
    ): Evos {

        incubator.index = incubator.index + 1;

        // Get random specie
        let nonce = vector::empty();
        vector::append(&mut nonce, sui::bcs::to_bytes(&incubator.index));
        let contract_commitment = pseudorandom::rand_no_counter(nonce, ctx);
        let rng = select((incubator.specs_tot_weight as u64), &contract_commitment);
        
        let specie = draw_specie(&incubator.specs, rng);

        // Create Evos
        let evos = Evos {
            id: object::new(ctx),
            index: incubator.index,
            name: string::utf8(b"Evos"),
            url: url::new_unsafe_from_bytes(specie.url),
            stage: string::utf8(b"Egg"),
            level: 1,
            species: specie.name,
            gems: 0,
            xp: 0,
            attributes: attributes::from_vec(
                vector[ascii::string(b"gems"), ascii::string(b"xp"), ascii::string(b"species"), ascii::string(b"stage"), ascii::string(b"level")],
                vector[ascii::string(b"0"), ascii::string(b"0"), string::to_ascii(specie.name), ascii::string(b"Egg"), ascii::string(b"1")]
            )
        };

        // Emit Mint Event
        mint_event::emit_mint(
            delegated_witness,
            mint_cap::collection_id(&incubator.mint_cap),
            &evos,
        );

        mint_cap::increment_supply(&mut incubator.mint_cap, 1);

        evos
    }
    fun new_kiosk_with_evos(
        delegated_witness: witness::Witness<Evos>,
        incubator: &mut Incubator,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let nft = create_evos(delegated_witness, incubator, ctx);
        let nft_id = object::id(&nft);
        let (kiosk, _) = ob_kiosk::new_for_address(receiver, ctx);
        ob_kiosk::deposit(&mut kiosk, nft, ctx);
        // ob_kiosk::auth_transfer(&mut kiosk, nft_id, COLLECTION_ADMIN, ctx);
        // ob_kiosk::auth_transfer(&mut kiosk, nft_id, COLLECTION_DEPLOYER, ctx);
        transfer::public_share_object(kiosk);
        register_new_evos(incubator, nft_id);
    }
    fun create_specie(name: String, weight: u8, url: vector<u8>): Specie {
        Specie { name, weight, url}
    }
    fun select(bound: u64, random: &vector<u8>): u64 {
        let random = pseudorandom::u256_from_bytes(random);
        // debug::print(&bound);
        let mod  = random % (bound as u256);
        (mod as u64)
    }
    fun draw_specie(species: &vector<Specie>, rng: u64): &Specie {
        let cumulativeWeight: u8 = 0;
        let i: u64 = 0;
        while (vector::length(species) > i) {
            let specie = vector::borrow<Specie>(species, i);
            cumulativeWeight = cumulativeWeight + specie.weight;
            if (rng <= (cumulativeWeight as u64)) {
                return specie
            };
            i = i+1;
        };
        vector::borrow<Specie>(species, vector::length(species) - 1)
    }
    fun register_new_evos(incubator: &mut Incubator, id: ID) {
        vector::push_back<ID>(&mut incubator.evos_created, id);
    }
    fun remove_attribute(
        evos: &mut Evos,
        name: vector<u8>,
        _ctx: &mut TxContext
    ) {
        let key = ascii::string(name);
        let attributes = attributes::get_attributes(&evos.attributes);
        if(vec_map::contains(attributes, &key)){
            attributes::remove_attribute<Witness, Evos>(&mut evos.attributes, &key);
        };
    }

    // ==== ADMINCAP PROTECTED ====

    /* UPDATE V4

    #[lint_allow(self_transfer)]
    public fun create_transfer_policy(
        publisher: &Publisher,
        ctx: &mut TxContext
    ) {
        let (transfer_policy, transfer_policy_cap) = ob_request::withdraw_request::init_policy<Evos>(publisher, ctx);
        enforce_contract(&mut transfer_policy, &transfer_policy_cap);
        transfer::public_share_object(transfer_policy);
        transfer::public_transfer(transfer_policy_cap, tx_context::sender(ctx))
    }
    public(friend) fun confirm_withdrawal( 
        request: &mut ob_request::withdraw_request::WithdrawRequest<Evos>,
    ) {
        ob_request::withdraw_request::add_receipt(request, &Witness {}); 
    }
    fun enforce_contract<T>( 
        policy: &mut ob_request::request::Policy<T>, 
        cap: &ob_request::request::PolicyCap, 
    ) { 
        ob_request::request::enforce_rule_no_state<T, Witness>(policy, cap); 
    }

    #[lint_allow(self_transfer)]
    public fun create_borrow_policy(
        publisher: &Publisher,
        ctx: &mut TxContext
    ) {
        let (borrow_policy, borrow_policy_cap) = ob_request::borrow_request::init_policy<Evos>(publisher, ctx);
        transfer::public_share_object(borrow_policy);
        transfer::public_transfer(borrow_policy_cap, tx_context::sender(ctx))
    }
    public(friend) fun add_gems_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        let gems = gems(nft);
        set_gems(nft, gems + amount, ctx);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun sub_gems_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        let gems = gems(nft);
        assert!(gems >= amount, EInsufficientGems);
        set_gems(nft, gems - amount, ctx);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun add_xp_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        let xp = xp(nft);
        set_xp(nft, xp + amount, ctx);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun sub_xp_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        let xp = xp(nft);
        assert!(xp >= amount, EInsufficientXp);
        set_xp(nft, xp - amount, ctx);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun update_url_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        new_url: vector<u8>,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        update_url(nft, new_url, ctx);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun set_stage_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        stage: vector<u8>,
        uri: vector<u8>,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&stage) > 0, EEmptyStage);
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        set_stage(nft, stage, uri, ctx);
        //update_url(nft, uri);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun set_level_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        level: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        set_level(nft, level, ctx);
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }
    public(friend) fun set_attribute_kiosk(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        name: vector<u8>,
        value: vector<u8>,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let dw = witness::from_witness(Witness {});
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);
        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);
        let attributes = attributes::get_attributes_mut(&mut nft.attributes);
        let key = ascii::string(name);
        if(vec_map::contains(attributes, &key)){
            if(vector::length(&value) == 1 && *vector::borrow(&value, 0) == 0u8){
                remove_attribute(nft, name, ctx);
            }else{
                *vec_map::get_mut(attributes, &key) = ascii::string(value);
            }
        }else{
            attributes::insert_attribute<Witness, Evos>(&mut nft.attributes, key, ascii::string(value));
        };
        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy)
    }

    END UPDATE V4 */

    #[test_only]
    #[lint_allow(self_transfer)]
    public(friend) fun init_for_test(
        ctx: &mut TxContext
    ){
        let otw = EVOS {};
        let sender = tx_context::sender(ctx);

        // Init Collection & MintCap with unlimited supply
        let (collection, mint_cap) = collection::create_with_mint_cap<EVOS, Evos>(
            &otw, option::none(), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let dw = witness::from_witness(Witness {});

        // Init Display
        let tags = vector[tags::art(), tags::collectible()];
        let display = display::new<Evos>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name} #{index}"));
        display::add(&mut display, string::utf8(b"species"), string::utf8(b"{species}"));
        display::add(&mut display, string::utf8(b"stage"), string::utf8(b"{stage}"));
        display::add(&mut display, string::utf8(b"level"), string::utf8(b"{level}"));
        display::add(&mut display, string::utf8(b"xp"), string::utf8(b"{xp}"));
        display::add(&mut display, string::utf8(b"gems"), string::utf8(b"{gems}"));
        display::add(&mut display, string::utf8(b"attributes"), std::string::utf8(b"{attributes}"));
        display::add(&mut display, string::utf8(b"image_url"), std::string::utf8(b"{url}"));
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
        let shares = vector[10_000]; // 10_000 BPS == 100%

        // Creators domain
        collection::add_domain(
            dw,
            &mut collection,
            creators::new(utils::vec_set_from_vec(&creators)),
        );

        let shares = utils::from_vec_to_map(creators, shares);
        royalty_strategy_bps::create_domain_and_add_strategy(
            dw, &mut collection, royalty::from_shares(shares, ctx), 500, ctx,
        );

        // === TRANSFER POLICIES ===

        // Creates a new policy and registers an allowlist rule to it.
        // Therefore now to finish a transfer, the allowlist must be included
        // in the chain.
        let (transfer_policy, transfer_policy_cap) = transfer_request::init_policy<Evos>(&publisher, ctx);

        royalty_strategy_bps::enforce(&mut transfer_policy, &transfer_policy_cap);
        transfer_allowlist::enforce(&mut transfer_policy, &transfer_policy_cap);

        // P2P Transfers are a separate transfer workflow and therefore require a
        // separate policy
        let (p2p_policy, p2p_policy_cap) = transfer_request::init_policy<Evos>(&publisher, ctx);

        p2p_list::enforce(&mut p2p_policy, &p2p_policy_cap);

        // Species
        let specs: vector<Specie> = vector<Specie>[
            Specie {name: string::utf8(b"Gold"), weight: 5u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/gold.png"},
            Specie {name: string::utf8(b"Forest"), weight: 20u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/forest.png"},
            Specie {name: string::utf8(b"Water"), weight: 24u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/water.png"},
            Specie {name: string::utf8(b"Rock"), weight: 25u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/rock.png"},
            Specie {name: string::utf8(b"Fire"), weight: 26u8, url: b"https://knw-gp.s3.eu-north-1.amazonaws.com/species/fire.png"},
        ];

        let incubator = Incubator {
            id: object::new(ctx),
            inhold: 0,
            index: 0,
            specs,
            specs_tot_weight: 100,
            slots: vector::empty<ID>(),
            version: VERSION,
            mint_cap: mint_cap,
            evos_created: vector::empty<ID>()
        };

        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));

        transfer::share_object(incubator);
        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(transfer_policy_cap, sender);
        transfer::public_transfer(p2p_policy_cap, sender);
        transfer::public_share_object(collection);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(p2p_policy);
    }

    #[test_only]
    #[lint_allow(share_owned)]
    public(friend) fun create_kiosk_with_evos_for_test(
        incubator: &mut Incubator,
        receiver: address,
        ctx: &mut TxContext
    ){
        let dw = witness::from_witness(Witness {});
        let nft = create_evos(dw, incubator, ctx);
        let nft_id = object::id(&nft);
        let (kiosk, _) = ob_kiosk::new_for_address(receiver, ctx);
        ob_kiosk::deposit(&mut kiosk, nft, ctx);
        transfer::public_share_object(kiosk);
        register_new_evos(incubator, nft_id);
    }

    #[test_only]
    use sui::test_scenario::{Self, ctx};
    #[test_only]
    use nft_protocol::collection::Collection;
    #[test_only]
    use sui::kiosk::{Kiosk};

    #[test_only]
    const CREATOR: address = @0xA1C04;

    #[test_only]
    fun create_clock(ctx: &mut TxContext) {
        let clock = clock::create_for_testing(ctx);
        clock::share_for_testing(clock);
    }

    #[test_only]
    public entry fun mint_egg_to_recipient(
        tracker: &mut MintTracker,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let egg = evosgenesisegg::mint_for_test(tracker, ctx);
        transfer::public_transfer(egg, recipient)
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
    fun it_inits() {
        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<Incubator>(), 1);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        assert!(vector::length<Specie>(&incubator.specs) == 5, 6);

        assert!(test_scenario::has_most_recent_shared<Collection<Evos>>(), 0);

        test_scenario::return_shared(incubator);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_deposit() {

        let scenario = test_scenario::begin(CREATOR);
        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);
        mint_egg_to_recipient(&mut tracker, CREATOR, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::return_shared(tracker);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let egg = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            CREATOR,
        );

        deposit(
            &mut incubator,
            egg,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        assert!(vector::length(&incubator.slots) == 1, 10);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);

        // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
        // test_scenario::return_to_sender(scenario, bag);
    }

    #[test]
    fun it_withdraw() {

        let scenario = test_scenario::begin(CREATOR);
        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        init(EVOS {}, ctx(&mut scenario)); // it mints 1 Egg to sender
        evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);
        mint_egg_to_recipient(&mut tracker, CREATOR, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::return_shared(tracker);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let egg = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            CREATOR,
        );

        deposit(
            &mut incubator,
            egg,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);

        clock::increment_for_testing(&mut clock, 5000);
        let slots_uids = &incubator.slots;

        withdraw(
            &mut incubator,
            *vector::borrow<ID>(slots_uids, 0),
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);

        let egg = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            CREATOR,
        );
        
        test_scenario::return_to_address(CREATOR, egg);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);

        // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
        // test_scenario::return_to_sender(scenario, bag);
    }

    #[test]
    fun it_reveal() {

        let scenario = test_scenario::begin(CREATOR);
        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);
        mint_egg_to_recipient(&mut tracker, CREATOR, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let egg = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            CREATOR,
        );
        //let egg_id = object::id(&egg);

        deposit(
            &mut incubator,
            egg,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);

        clock::increment_for_testing(&mut clock, REVEAL_TIME);

        let slots_uids = &incubator.slots;
        reveal(
            &mut incubator,
            &mut tracker,
            *vector::borrow<ID>(slots_uids, 0),
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);

        let evos = test_scenario::take_shared<Kiosk>(
            &scenario
        );
        test_scenario::return_shared(evos);
        assert!(index(&incubator) == 1, 5);


        test_scenario::return_shared(incubator);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(tracker);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);

        // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
        // test_scenario::return_to_sender(scenario, bag);
    }

    #[test]
    fun it_add_specis() {

        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, CREATOR);

        add_specie(
            &admin_cap,
            &mut incubator,
            string::utf8(b"TEST"),
            1,
            b"https://test-specie.jpg",
            ctx(&mut scenario)
        );
        assert!(vector::length(&incubator.specs) == 6, 11);

        test_scenario::return_shared(incubator);

        test_scenario::return_to_address(CREATOR, admin_cap);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_sort_specis() {

        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, CREATOR);

        add_specie(
            &admin_cap,
            &mut incubator,
            string::utf8(b"TEST"),
            5,
            b"https://test-specie.jpg",
            ctx(&mut scenario)
        );
        assert!(vector::length(&incubator.specs) == 6, 11);
        test_scenario::next_tx(&mut scenario, CREATOR);

        add_specie(
            &admin_cap,
            &mut incubator,
            string::utf8(b"TEST"),
            3,
            b"https://test-specie.jpg",
            ctx(&mut scenario)
        );
        assert!(vector::length(&incubator.specs) == 7, 12);
        test_scenario::next_tx(&mut scenario, CREATOR);

        add_specie(
            &admin_cap,
            &mut incubator,
            string::utf8(b"TEST"),
            4,
            b"https://test-specie.jpg",
            ctx(&mut scenario)
        );
        assert!(vector::length(&incubator.specs) == 8, 13);

        test_scenario::next_tx(&mut scenario, CREATOR);

        let specs: &vector<Specie> = specs(&incubator);
        let i: u64 = 0;
        let _prev: u8 = 0;
        while(i < vector::length(specs)){
            let s = vector::borrow<Specie>(specs, i);
            assert!(s.weight >= _prev, 14);
            _prev = s.weight;
            i = i+1;
        };

        test_scenario::return_shared(incubator);

        test_scenario::return_to_address(CREATOR, admin_cap);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun it_draw_specie() {

        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);

        // Get random specie
        let nonce = vector::empty();
        vector::append(&mut nonce, sui::bcs::to_bytes(&incubator.index)); 
        vector::append(&mut nonce, sui::bcs::to_bytes(&CREATOR));

        let i: u64 = 0;
        while(i < 100){
            let contract_commitment = pseudorandom::rand_no_counter(nonce, ctx(&mut scenario));
            let rng = select(100u64, &contract_commitment);
            let specs: &vector<Specie> = specs(&incubator);
            let _specie: &Specie = draw_specie(specs, rng);
            // std::debug::print(&specie.name);
            i = i+1;
        };

        test_scenario::return_shared(incubator);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun deny_add_specis() {
        
        let unauth_user: address = @0xABC; 
        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        // evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, unauth_user);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, CREATOR);

        test_scenario::next_tx(&mut scenario, unauth_user);

        add_specie(
            &admin_cap,
            &mut incubator,
            string::utf8(b"TEST"),
            1,
            b"https://test-specie.jpg",
            ctx(&mut scenario)
        );
        assert!(vector::length(&incubator.specs) == 6, 11);

        test_scenario::return_shared(incubator);
        test_scenario::return_to_address(CREATOR, admin_cap);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun incubator_stats_are_correct() {

        let scenario = test_scenario::begin(CREATOR);
        let user_a: address = @0xA;
        let user_b: address = @0xB;

        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        //evosgenesisegg::init(EVOSGENESISEGG, ctx(&mut scenario));
        init(EVOS {}, ctx(&mut scenario));
        evosgenesisegg::init_for_test(knw_genesis::evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);

        mint_egg_to_recipient(&mut tracker, CREATOR, ctx(&mut scenario));
        mint_egg_to_recipient(&mut tracker, user_a, ctx(&mut scenario));
        mint_egg_to_recipient(&mut tracker, user_b, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user_a);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);

        let egg_a = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            user_a,
        );

        deposit(
            &mut incubator,
            egg_a,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user_b);

        let egg_b = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            user_b,
        );
        deposit(
            &mut incubator,
            egg_b,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user_a);

        clock::increment_for_testing(&mut clock, REVEAL_TIME);
        let slots_uids = &incubator.slots;

        reveal(
            &mut incubator,
            &mut tracker,
            *vector::borrow<ID>(slots_uids, 0),
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        //debug::print(&string::utf8(b"Revealed"));

        let evos = test_scenario::take_shared<Kiosk>(
            &scenario
        );
        test_scenario::return_shared<Kiosk>(evos);

        assert!(index(&incubator) == 1, 5);
        assert!(inhold(&incubator) == 1, 7);

        test_scenario::return_shared(tracker);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(clock);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);

        // let bag = test_scenario::take_child_object<Marketplace, Bag>(scenario, mkp);
        // test_scenario::return_to_sender(scenario, bag);
    }

    
    /* #[test]
    fun test_kiosk_update_evos_xp() {

        let scenario = test_scenario::begin(CREATOR);
        let depositer = @0xBBB0AF;

        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        // evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);
        mint_egg_to_recipient(&mut tracker, depositer, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, depositer);

        let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let egg = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            depositer,
        );
        deposit(
            &mut incubator,
            egg,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, depositer);

        clock::increment_for_testing(&mut clock, REVEAL_TIME);

        let slots_uids = &incubator.slots;

        reveal(
            &mut incubator,
            &mut tracker,
            *vector::borrow<ID>(slots_uids, 0),
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);

        // Withdraw evos from kiosk
        assert!(test_scenario::has_most_recent_shared<Kiosk>(), 0);
        let kiosk = test_scenario::take_shared<Kiosk>(
            &scenario,
        );

        let publisher = sui::package::claim(EVOS {}, ctx(&mut scenario));
        let (tx_policy, policy_cap) = withdraw_request::init_policy<Evos>(&publisher, ctx(&mut scenario));

        let evos_array = all_evos_ids(&incubator);
        assert!(vector::length(&evos_array) > 0, 0);
        let nft_id: ID = get_evos_id_at(&incubator, 0);
        let (nft, request) = ob_kiosk::withdraw_nft_signed<Evos>(
            &mut kiosk,
            nft_id,
            ctx(&mut scenario)
        );
        withdraw_request::confirm<Evos>(request, &tx_policy);

        transfer::public_share_object(tx_policy);
        transfer::public_transfer(policy_cap, depositer);
        transfer::public_transfer(publisher, depositer);

        test_scenario::next_tx(&mut scenario, CREATOR);

        // Deposit evos back into the kiosk
        let update_cap = test_scenario::take_from_address<UpdateCap>(&mut scenario, CREATOR);
        set_xp(&mut nft, 20u32, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(xp(&nft) == 20u32, 15);
        //ob_kiosk::assert_listed(&mut kiosk, nft_id);

        //test_scenario::next_tx(&mut scenario, CREATOR);

        ob_kiosk::deposit(&mut kiosk, nft, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        ob_kiosk::assert_not_listed(&mut kiosk, nft_id);
        ob_kiosk::assert_not_exclusively_listed(&mut kiosk, nft_id);

        assert!(index(&incubator) == 1, 5);
        
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(kiosk);
        test_scenario::return_shared(tracker);
        
        test_scenario::return_to_address(CREATOR, update_cap);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    } */

    #[test]
    fun test_species_rarity() {

        let scenario = test_scenario::begin(CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        //evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);

        let i: u64 = 0;
        let dw = witness::from_witness(Witness {});
        while(i < 10u64){
            let egg = create_evos(dw, &mut incubator, ctx(&mut scenario));
            // std::debug::print<String>(&species(&egg));
            transfer::public_share_object(egg);
            i = i+1;
        };

        test_scenario::next_tx(&mut scenario, CREATOR);

        test_scenario::return_shared(incubator);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_slot(){

        let scenario = test_scenario::begin(CREATOR);
        create_clock(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        init(EVOS {}, ctx(&mut scenario));
        evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        let tracker = test_scenario::take_shared<MintTracker>(&scenario);
        mint_egg_to_recipient(&mut tracker, CREATOR, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::return_shared(tracker);

        let incubator = test_scenario::take_shared<Incubator>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let egg = test_scenario::take_from_address<EvosGenesisEgg>(
            &scenario,
            CREATOR,
        );

        deposit(
            &mut incubator,
            egg,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        assert!(vector::length(&incubator.slots) == 1, 10);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(clock);
        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

}