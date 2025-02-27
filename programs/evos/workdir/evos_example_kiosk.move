module evos::evos {
    /// One time witness is only instantiated in the init method
    struct EVOS has drop {}

    /// Can be used for authorization of other actions post-creation. It is
    /// vital that this struct is not freely given to any contract, because it
    /// serves as an auth token.
    struct Witness has drop {}

    struct Evos has key, store {
        id: sui::object::UID,
        name: std::string::String,
        description: std::string::String,
        url: sui::url::Url,
        attributes: nft_protocol::attributes::Attributes,
    }

    fun init(witness: EVOS, ctx: &mut sui::tx_context::TxContext) {
        let (collection, mint_cap) = nft_protocol::collection::create_with_mint_cap<EVOS, Evos>(
            &witness, std::option::some(600), ctx
        );

        // Init Publisher
        let publisher = sui::package::claim(witness, ctx);

        // Init Tags
        let tags: vector<std::string::String> = std::vector::empty();

        // Init Display
        let display = sui::display::new<Evos>(&publisher, ctx);
        sui::display::add(&mut display, std::string::utf8(b"name"), std::string::utf8(b"{name}"));
        sui::display::add(&mut display, std::string::utf8(b"description"), std::string::utf8(b"{description}"));
        sui::display::add(&mut display, std::string::utf8(b"image_url"), std::string::utf8(b"{url}"));
        sui::display::add(&mut display, std::string::utf8(b"attributes"), std::string::utf8(b"{attributes}"));
        sui::display::add(&mut display, std::string::utf8(b"tags"), ob_utils::display::from_vec(tags));
        sui::display::update_version(&mut display);
        sui::transfer::public_transfer(display, sui::tx_context::sender(ctx));

        let delegated_witness = ob_permissions::witness::from_witness(Witness {});

        let creators = sui::vec_set::empty();
        sui::vec_set::insert(&mut creators, @0x0);

        nft_protocol::collection::add_domain(
            delegated_witness,
            &mut collection,
            nft_protocol::creators::new(creators),
        );

        nft_protocol::collection::add_domain(
            delegated_witness,
            &mut collection,
            nft_protocol::display_info::new(
                std::string::utf8(b""),
                std::string::utf8(b""),
            ),
        );

        nft_protocol::collection::add_domain(
            delegated_witness,
            &mut collection,
            nft_protocol::symbol::new(std::string::utf8(b"")),
        );

        nft_protocol::collection::add_domain(
            delegated_witness,
            &mut collection,
            sui::url::new_unsafe_from_bytes(b""),
        );

        let royalty_map = sui::vec_map::empty();
        sui::vec_map::insert(&mut royalty_map, @0x1, 500);
        sui::vec_map::insert(&mut royalty_map, @0x0, 9500);

        nft_protocol::royalty_strategy_bps::create_domain_and_add_strategy(
            delegated_witness,
            &mut collection,
            nft_protocol::royalty::from_shares(royalty_map, ctx),
            700,
            ctx,
        );

        let (transfer_policy, transfer_policy_cap) =
            ob_request::transfer_request::init_policy<Evos>(&publisher, ctx);

        nft_protocol::royalty_strategy_bps::enforce(
            &mut transfer_policy, &transfer_policy_cap,
        );
        nft_protocol::transfer_allowlist::enforce(
            &mut transfer_policy, &transfer_policy_cap,
        );

        let (withdraw_policy, withdraw_policy_cap) =
            ob_request::withdraw_request::init_policy<Evos>(&publisher, ctx);

        let (borrow_policy, borrow_policy_cap) =
            ob_request::borrow_request::init_policy<Evos>(&publisher, ctx);

        // Protected orderbook such that trading is not initially possible
        let orderbook = liquidity_layer_v1::orderbook::new_with_protected_actions<Evos, sui::sui::SUI>(
            delegated_witness, &transfer_policy, liquidity_layer_v1::orderbook::custom_protection(true, true, true), ctx,
        );
        liquidity_layer_v1::orderbook::share(orderbook);

        // Setup Transfers
        sui::transfer::public_transfer(publisher, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer(mint_cap, sui::tx_context::sender(ctx));
        sui::transfer::public_share_object(collection);

        sui::transfer::public_transfer(transfer_policy_cap, sui::tx_context::sender(ctx));
        sui::transfer::public_share_object(transfer_policy);

        sui::transfer::public_transfer(borrow_policy_cap, sui::tx_context::sender(ctx));
        sui::transfer::public_share_object(borrow_policy);

        sui::transfer::public_transfer(withdraw_policy_cap, sui::tx_context::sender(ctx));
        sui::transfer::public_share_object(withdraw_policy);
    }

    public entry fun mint_nft(
        name: std::string::String,
        description: std::string::String,
        url: vector<u8>,
        attribute_keys: vector<std::ascii::String>,
        attribute_values: vector<std::ascii::String>,
        mint_cap: &mut nft_protocol::mint_cap::MintCap<Evos>,
        warehouse: &mut ob_launchpad::warehouse::Warehouse<Evos>,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let nft = mint(
            name,
            description,
            url,
            attribute_keys,
            attribute_values,
            mint_cap,
            ctx,
        );

        ob_launchpad::warehouse::deposit_nft(warehouse, nft);
    }

    public entry fun airdrop_nft(
        name: std::string::String,
        description: std::string::String,
        url: vector<u8>,
        attribute_keys: vector<std::ascii::String>,
        attribute_values: vector<std::ascii::String>,
        mint_cap: &mut nft_protocol::mint_cap::MintCap<Evos>,
        receiver: &mut sui::kiosk::Kiosk,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let nft = mint(
            name,
            description,
            url,
            attribute_keys,
            attribute_values,
            mint_cap,
            ctx,
        );

        ob_kiosk::ob_kiosk::deposit(receiver, nft, ctx);
    }

    public entry fun airdrop_nft_into_new_kiosk(
        name: std::string::String,
        description: std::string::String,
        url: vector<u8>,
        attribute_keys: vector<std::ascii::String>,
        attribute_values: vector<std::ascii::String>,
        mint_cap: &mut nft_protocol::mint_cap::MintCap<Evos>,
        receiver: address,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let nft = mint(
            name,
            description,
            url,
            attribute_keys,
            attribute_values,
            mint_cap,
            ctx,
        );

        let (kiosk, _) = ob_kiosk::ob_kiosk::new_for_address(receiver, ctx);
        ob_kiosk::ob_kiosk::deposit(&mut kiosk, nft, ctx);
        sui::transfer::public_share_object(kiosk);
    }

    fun mint(
        name: std::string::String,
        description: std::string::String,
        url: vector<u8>,
        attribute_keys: vector<std::ascii::String>,
        attribute_values: vector<std::ascii::String>,
        mint_cap: &mut nft_protocol::mint_cap::MintCap<Evos>,
        ctx: &mut sui::tx_context::TxContext,
    ): Evos {
        let nft = Evos {
            id: sui::object::new(ctx),
            name,
            description,
            url: sui::url::new_unsafe_from_bytes(url),
            attributes: nft_protocol::attributes::from_vec(attribute_keys, attribute_values)
        };

        nft_protocol::mint_event::emit_mint(
            ob_permissions::witness::from_witness(Witness {}),
            nft_protocol::mint_cap::collection_id(mint_cap),
            &nft,
        );

        nft_protocol::mint_cap::increment_supply(mint_cap, 1);

        nft
    }

    // Protected orderbook functions
    public entry fun enable_orderbook(
        publisher: &sui::package::Publisher,
        orderbook: &mut liquidity_layer_v1::orderbook::Orderbook<Evos, sui::sui::SUI>,
    ) {
        let delegated_witness = ob_permissions::witness::from_publisher(publisher);

        liquidity_layer_v1::orderbook::set_protection(
            delegated_witness, orderbook, liquidity_layer_v1::orderbook::custom_protection(false, false, false),
        );
    }

    public entry fun disable_orderbook(
        publisher: &sui::package::Publisher,
        orderbook: &mut liquidity_layer_v1::orderbook::Orderbook<Evos, sui::sui::SUI>,
    ) {
        let delegated_witness = ob_permissions::witness::from_publisher(publisher);

        liquidity_layer_v1::orderbook::set_protection(
            delegated_witness, orderbook, liquidity_layer_v1::orderbook::custom_protection(true, true, true),
        );
    }

    // Burn functions
    public fun burn_nft(
        delegated_witness: ob_permissions::witness::Witness<Evos>,
        collection: &nft_protocol::collection::Collection<Evos>,
        nft: Evos,
    ) {
        let guard = nft_protocol::mint_event::start_burn(delegated_witness, &nft);

        let Evos { id, name: _, description: _, url: _, attributes: _ } = nft;

        nft_protocol::mint_event::emit_burn(guard, sui::object::id(collection), id);
    }

    public entry fun burn_nft_in_listing(
        publisher: &sui::package::Publisher,
        collection: &nft_protocol::collection::Collection<Evos>,
        listing: &mut ob_launchpad::listing::Listing,
        inventory_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let delegated_witness = ob_permissions::witness::from_publisher(publisher);
        let nft = ob_launchpad::listing::admin_redeem_nft(listing, inventory_id, ctx);
        burn_nft(delegated_witness, collection, nft);
    }

    public entry fun burn_nft_in_listing_with_id(
        publisher: &sui::package::Publisher,
        collection: &nft_protocol::collection::Collection<Evos>,
        listing: &mut ob_launchpad::listing::Listing,
        inventory_id: sui::object::ID,
        nft_id: sui::object::ID,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let delegated_witness = ob_permissions::witness::from_publisher(publisher);
        let nft = ob_launchpad::listing::admin_redeem_nft_with_id(listing, inventory_id, nft_id, ctx);
        burn_nft(delegated_witness, collection, nft);
    }

    public entry fun burn_own_nft(
        collection: &nft_protocol::collection::Collection<Evos>,
        nft: Evos,
    ) {
        let delegated_witness = ob_permissions::witness::from_witness(Witness {});
        burn_nft(delegated_witness, collection, nft);
    }

    public entry fun burn_own_nft_in_kiosk(
        collection: &nft_protocol::collection::Collection<Evos>,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: sui::object::ID,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let (nft, withdraw_request) = ob_kiosk::ob_kiosk::withdraw_nft_signed(kiosk, nft_id, ctx);
        ob_request::withdraw_request::confirm(withdraw_request, policy);

        burn_own_nft(collection, nft);
    }

    public entry fun reveal_nft(
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: sui::object::ID,
        url: vector<u8>,
        attribute_keys: vector<std::ascii::String>,
        attribute_values: vector<std::ascii::String>,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        publisher: &sui::package::Publisher,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let dw = ob_permissions::witness::from_publisher(publisher);
        let borrow = ob_kiosk::ob_kiosk::borrow_nft_mut<Evos>(kiosk, nft_id, std::option::none(), ctx);

        let nft: &mut Evos = ob_request::borrow_request::borrow_nft_ref_mut(dw, &mut borrow);

        nft.url = sui::url::new_unsafe_from_bytes(url);
        nft.attributes = nft_protocol::attributes::from_vec(attribute_keys, attribute_values);

        ob_kiosk::ob_kiosk::return_nft<Witness, Evos>(kiosk, borrow, policy);
    }

    #[test_only]
    const CREATOR: address = @0xA1C04;

    #[test]
    fun it_inits_collection() {
        let scenario = sui::test_scenario::begin(CREATOR);

        init(EVOS {}, sui::test_scenario::ctx(&mut scenario));
        sui::test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(sui::test_scenario::has_most_recent_shared<nft_protocol::collection::Collection<Evos>>(), 0);

        let mint_cap = sui::test_scenario::take_from_address<nft_protocol::mint_cap::MintCap<Evos>>(
            &scenario, CREATOR,
        );

        sui::test_scenario::return_to_address(CREATOR, mint_cap);
        sui::test_scenario::next_tx(&mut scenario, CREATOR);

        sui::test_scenario::end(scenario);
    }

    #[test]
    fun it_mints_nft() {
        let scenario = sui::test_scenario::begin(CREATOR);
        init(EVOS {}, sui::test_scenario::ctx(&mut scenario));

        sui::test_scenario::next_tx(&mut scenario, CREATOR);

        let mint_cap = sui::test_scenario::take_from_address<nft_protocol::mint_cap::MintCap<Evos>>(
            &scenario,
            CREATOR,
        );

        let warehouse = ob_launchpad::warehouse::new<Evos>(sui::test_scenario::ctx(&mut scenario));

        mint_nft(
            std::string::utf8(b"TEST NAME"),
            std::string::utf8(b"TEST DESCRIPTION"),
            b"https://originbyte.io/",
            vector[std::ascii::string(b"avg_return")],
            vector[std::ascii::string(b"24%")],
            &mut mint_cap,
            &mut warehouse,
            sui::test_scenario::ctx(&mut scenario)
        );

        sui::transfer::public_transfer(warehouse, CREATOR);
        sui::test_scenario::return_to_address(CREATOR, mint_cap);
        sui::test_scenario::end(scenario);
    }

    #[test]
    fun it_burns_own_nft() {
        let scenario = sui::test_scenario::begin(CREATOR);
        init(EVOS {}, sui::test_scenario::ctx(&mut scenario));

        sui::test_scenario::next_tx(&mut scenario, CREATOR);

        let mint_cap = sui::test_scenario::take_from_address<nft_protocol::mint_cap::MintCap<Evos>>(
            &scenario,
            CREATOR,
        );

        let publisher = sui::test_scenario::take_from_address<sui::package::Publisher>(
            &scenario,
            CREATOR,
        );

        let collection = sui::test_scenario::take_shared<
            nft_protocol::collection::Collection<Evos>
        >(&scenario);

        let borrow_policy = sui::test_scenario::take_shared<
            ob_request::request::Policy<
                ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>
            >
        >(&scenario);

        let nft = mint(
            std::string::utf8(b"TEST NAME"),
            std::string::utf8(b"TEST DESCRIPTION"),
            b"https://originbyte.io/",
            vector[std::ascii::string(b"avg_return")],
            vector[std::ascii::string(b"24%")],
            &mut mint_cap,
            sui::test_scenario::ctx(&mut scenario)
        );
        let nft_id = sui::object::id(&nft);

        let (kiosk, _) = ob_kiosk::ob_kiosk::new(sui::test_scenario::ctx(&mut scenario));
        ob_kiosk::ob_kiosk::deposit(&mut kiosk, nft, sui::test_scenario::ctx(&mut scenario));

        burn_own_nft_in_kiosk(
            &collection,
            &mut kiosk,
            nft_id,
            &borrow_policy,
            sui::test_scenario::ctx(&mut scenario)
        );

        sui::test_scenario::return_to_address(CREATOR, mint_cap);
        sui::test_scenario::return_to_address(CREATOR, publisher);
        sui::test_scenario::return_shared(collection);
        sui::test_scenario::return_shared(borrow_policy);
        sui::transfer::public_share_object(kiosk);
        sui::test_scenario::end(scenario);
    }

    #[test]
    fun it_reveals() {
        let scenario = sui::test_scenario::begin(CREATOR);
        init(EVOS {}, sui::test_scenario::ctx(&mut scenario));

        sui::test_scenario::next_tx(&mut scenario, CREATOR);

        let mint_cap = sui::test_scenario::take_from_address<nft_protocol::mint_cap::MintCap<Evos>>(
            &scenario,
            CREATOR,
        );

        let publisher = sui::test_scenario::take_from_address<sui::package::Publisher>(
            &scenario,
            CREATOR,
        );

        let borrow_policy = sui::test_scenario::take_shared<
            ob_request::request::Policy<
                ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>
            >
        >(
            &mut scenario
        );

        let nft = mint(
            std::string::utf8(b"TEST NAME"),
            std::string::utf8(b"TEST DESCRIPTION"),
            b"https://originbyte.io/",
            vector[std::ascii::string(b"avg_return")],
            vector[std::ascii::string(b"24%")],
            &mut mint_cap,
            sui::test_scenario::ctx(&mut scenario)
        );
        let nft_id = sui::object::id(&nft);

        let (kiosk, _) = ob_kiosk::ob_kiosk::new(sui::test_scenario::ctx(&mut scenario));
        ob_kiosk::ob_kiosk::deposit(&mut kiosk, nft, sui::test_scenario::ctx(&mut scenario));

        reveal_nft(
            &mut kiosk,
            nft_id,
            b"https://docs.originbyte.io/",
            vector[std::ascii::string(b"reveal")],
            vector[std::ascii::string(b"revealed")],
            &borrow_policy,
            &publisher,
            sui::test_scenario::ctx(&mut scenario)
        );

        sui::test_scenario::return_to_address(CREATOR, mint_cap);
        sui::test_scenario::return_to_address(CREATOR, publisher);
        sui::test_scenario::return_shared(borrow_policy);
        sui::transfer::public_share_object(kiosk);
        sui::test_scenario::end(scenario);
    }
}
