/* 
 * Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Description: All game logic such as devolution and evolution mechs are handled by this module.
 * Features:
 *      - (GameAdminCap) Create a new `Stage`
 */
module knw_evos::evoscore {

    use knw_evos::evos::{Self, Evos};
    use knw_evos::traits::{Self, TraitSettings};
    use knw_evos::history::{Self, EvosHistory};
    use knw_evos::settings::{Self, GameSettings, Stage};

    use std::string::{Self, String};
    use std::vector;

    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID, ID};
    use sui::url;

    use sui::dynamic_object_field as dof;
    use sui::tx_context::{Self, TxContext};

    use ob_kiosk::ob_kiosk;

    struct Witness has drop {}
    struct EVOSCORE has drop {}

    struct GameAdminCap has key, store { id: UID }
    struct GameThreadCap has key, store { id: UID }

    struct EvosGame has key, store {
        id: UID,
        settings: GameSettings,
        delegations: u64
    }

    // It holds all the info for a specific user
    // It's added to EvosGame as dynamic object field
    struct UserInfo has key, store {
        id: UID,
        owner: address,
        tot_gems_earned: u64,
        slots: vector<ID>
    }

    // It will register a deposit of kiosk caps for a user's nft.
    // the NFT_ID it's saved for future use
    struct UserSlot has key, store {
        id: UID,
        owner: address,
        last_claim_xp: u64,
        last_claim_gems: u64,
        // last_thread_check: u64,
        nft_id: ID
    }

    // Constant values
    const MAX_U32: u32 = 4294967295;

    // const MAX_U64: u64 = (264) - 1;
    const DEFAULT_GEMS_TIME_FRAME: u64 = 1000 * 60 * 30; // 30 minutes
    const DEFAULT_GEMS_PER_FRAME: u64 = 1;
    const DEFAULT_XP_TIME_FRAME: u64 = 1000 * 60 * 60 * 2; //  2 hours
    const DEFAULT_XP_PER_FRAME: u64 = 1;
    const DEFAULT_XP_VAR_FAC: u64 = 115;
    const XP_BOOST: u32 = 1;
    const DEFAULT_MAX_GEMS: u32 = 2000;
    const DEFAULT_MAX_XP: u32 = 240;
    const DEFAULT_XP_DEC_K: u64 = 2;
    const DEFAULT_GEMS_DEC_K: u64 = 2;

    // Errors Code
    const EInsufficientGems: u64 = 1;
    const EInsufficientXp: u64 = 2;
    const EMaxGemsExceeded: u64 = 3;
    const EMaxXpExceeded: u64 = 4;
    const EU64Overflow: u64 = 5;
    const EPublisherAlreadyLoaded: u64 = 6;
    const ENoDelegationsFound: u64 = 7;
    const EItemNotFound: u64 = 8;
    const ENextStageNotFound: u64 = 9;
    const ELevelTooLow: u64 = 10;
    const EMaxLevelForStage: u64 = 11;
    const ETraitsSettingsNotExists: u64 = 12;
    const EWrongTraitBox: u64 = 13;
    const EBoxAlreadyOpened: u64 = 14;
    const EHasReceiptPending: u64 = 15;
    const ENotPendingReceipts: u64 = 16;
    const EUserNotExists: u64 = 17;
    const EBoundToLow: u64 = 18;
    const EPrevStageNotFound: u64 = 19;

    fun init(otw: EVOSCORE, ctx: &mut TxContext) {

        let sender = tx_context::sender(ctx);
        let publisher = sui::package::claim(otw, ctx);

        // Gems Mine
        let gems_mine = settings::create_gems_mine(DEFAULT_GEMS_PER_FRAME, DEFAULT_GEMS_TIME_FRAME, DEFAULT_GEMS_DEC_K);

        // Stages
        let stages = vector::empty<Stage>();

        // Box rewards
        let rewards = vector::empty<u32>();
        vector::push_back(&mut rewards, 2);
        vector::push_back(&mut rewards, 3);
        vector::push_back(&mut rewards, 5);

        // Stage 0: Egg
        vector::push_back<Stage>(&mut stages, settings::create_stage(b"Egg", 0, 1,  vector::empty<u32>()));
        // Stage 1: Baby
        vector::push_back<Stage>(&mut stages, settings::create_stage(b"Baby", 20, 5, rewards));
        // Stage 2: Juvenile
        vector::push_back<Stage>(&mut stages, settings::create_stage(b"Juvenile", 343, 5, rewards));
        // Stage 3: Adult
        vector::push_back<Stage>(&mut stages, settings::create_stage(b"Adult", 992, 5, rewards));

        // Game Settings
        let game_settings = settings::create_settings(
            gems_mine,
            DEFAULT_XP_PER_FRAME, // xp per frame
            DEFAULT_XP_TIME_FRAME, // frame
            DEFAULT_XP_VAR_FAC,
            stages,
            DEFAULT_MAX_GEMS,
            DEFAULT_MAX_XP,
            DEFAULT_XP_DEC_K
        );

        // Game
        let evos_game = create_game(game_settings, ctx);

        // Traits Settings
        let traits_settings = traits::create_trait_settings(ctx);
        dof::add(&mut evos_game.id, b"traits", traits_settings);

        // Share
        transfer::public_share_object(evos_game);

        // Transfer
        transfer::public_transfer(publisher, sender);
        
        // Caps
        transfer::public_transfer(create_admin_cap(ctx), sender);
        transfer::public_transfer(create_thread_cap(ctx), sender);
    }

    // ==== CONSTRUCTORS ====
    fun create_game(
        settings: GameSettings,
        ctx: &mut TxContext
    ): EvosGame {
        EvosGame {
            id: object::new(ctx),
            settings,
            delegations: 0
        }
    }
    fun create_user_info(
        owner: address,
        ctx: &mut TxContext
    ): UserInfo {
        UserInfo {
            id: object::new(ctx),
            owner,
            tot_gems_earned: 0,
            slots: vector::empty<ID>()
        }
    }
    fun create_user_slot(
        owner: address,
        nft_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ): UserSlot {
        let now: u64 = clock::timestamp_ms(clock);
        UserSlot {
            id: object::new(ctx),
            owner,
            last_claim_xp: now,
            last_claim_gems: now,
            nft_id,
            // last_thread_check: now
        }
    }
    fun create_admin_cap(
        ctx: &mut TxContext
    ): GameAdminCap {
        GameAdminCap{ id: object::new(ctx)}
    }
    fun create_thread_cap(
        ctx: &mut TxContext
    ): GameThreadCap {
        GameThreadCap{ id: object::new(ctx)}
    }

    // EvosGame
    public fun settings(game: &EvosGame): &GameSettings {
        &game.settings
    }
    public fun delegations(game: &EvosGame): u64 {
        game.delegations
    }
    public fun user_info(game: &EvosGame, user: address): &UserInfo {
        assert!(dof::exists_(&game.id, user), EUserNotExists);
        dof::borrow<address, UserInfo>(&game.id, user)
    }
    // Accessors | EvosGame
    fun user_info_mut(game: &mut EvosGame, user: address): &mut UserInfo {
        assert!(dof::exists_(&game.id, user), EUserNotExists);
        dof::borrow_mut<address, UserInfo>(&mut game.id, user)
    }
    fun get_game_info(game: &EvosGame): (u64, u64, &vector<Stage>) {
        (settings::xp_frame(settings(game)), settings::xp_per_frame(settings(game)), settings::stages(settings(game)))
    }
    public fun xp_info_from_game(game: &EvosGame): (u64,u64) /* (frame, rate) */{
        settings::xp_info(settings(game))
    }
    public fun gems_info_from_game(game: &EvosGame): (u64, u64) /* (frame, rate) */{
        settings::gems_info(settings(game))
    }
    public fun gems_emitted_from_game(game: &EvosGame): u64 {
        settings::gems_emitted_from_settings(settings(game))
    }
    public fun gems_burned_from_game(game: &EvosGame): u64 {
        settings::gems_burned_from_settings(settings(game))
    }
    public fun stages_from_game(game: &EvosGame): &vector<Stage> {
        settings::stages(settings(game))
    }
    public fun traits_settings(game: &EvosGame): &TraitSettings {
        dof::borrow<vector<u8>, TraitSettings>(&game.id, b"traits")
    }
    fun settings_mut(game: &mut EvosGame): &mut GameSettings {
        &mut game.settings
    }

    // UserInfo
    public fun owner(user_: &UserInfo): address {
        user_.owner
    }
    public fun tot_gems_earned(user: &UserInfo): u64 {
        user.tot_gems_earned
    }
    public fun slots(user: &UserInfo): vector<ID> {
        user.slots
    }
    public fun get_slot(info: &UserInfo, nft_id: ID): &UserSlot {
        assert!(dof::exists_(&info.id, nft_id), EItemNotFound);
        dof::borrow<ID, UserSlot>(&info.id, nft_id)
    }
    // Accessors | UserInfo
    fun get_slot_mut(info: &mut UserInfo, nft_id: ID): &mut UserSlot {
        assert!(dof::exists_(&info.id, nft_id), EItemNotFound);
        dof::borrow_mut<ID, UserSlot>(&mut info.id, nft_id)
    }
    fun register_gems(user: &mut UserInfo, value: u64) {
        user.tot_gems_earned = user.tot_gems_earned + value;
    }
    fun add_slot(user: &mut UserInfo, slot: ID) {
        vector::push_back<ID>(&mut user.slots, slot)
    }
    fun remove_slot(user: &mut UserInfo, slot: ID) {
        let i: u64 = 0;
        while(vector::length(&user.slots) > i){
            if(*vector::borrow<ID>(&user.slots, i) == slot){
                vector::remove(&mut user.slots, i);
            };
            i = i + 1;
        };
    }

    // ==== GameAdminCap Only ====
    public entry fun add_stage(
        _: &GameAdminCap,
        game: &mut EvosGame,
        name: vector<u8>,
        base: u32,
        levels: u32,
        rewards: vector<u32>,
        _ctx: &mut TxContext
    ) {
        let stage = settings::create_stage(name, base, levels, rewards);
        vector::push_back<Stage>(settings::stages_mut(settings_mut(game)), stage);
    }
    public entry fun add_new_traitbox(
        _: &GameAdminCap,
        game: &mut EvosGame,
        level: u32,
        stage: vector<u8>,
        names: vector<vector<u8>>,
        values: vector<vector<u8>>,
        urls: vector<vector<u8>>,
        weights: vector<u8>,
        price: u32,
        _ctx: &mut TxContext
    ) {
        assert!(dof::exists_(&game.id, b"traits"), ETraitsSettingsNotExists);
        let settings = dof::borrow_mut<vector<u8>, TraitSettings>(&mut game.id, b"traits");
        let box = traits::new_trait_box(traits::new_box_index(settings), level, stage, names, values, urls, weights, price);
        traits::register_box(settings, box);
    }
    public entry fun set_xp_var_fac_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_xp_var_fac(settings_mut(game), value)
    }
    public entry fun set_xp_per_frame_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_xp_per_frame(settings_mut(game), value)
    }
    public entry fun set_xp_frame_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_xp_frame(settings_mut(game), value)
    }
    public entry fun set_gems_frame_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_gems_frame_from_settings(settings_mut(game), value)
    }
    public entry fun set_gems_per_frame_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_gems_per_frame_from_settings(settings_mut(game), value)
    }
    public entry fun set_max_gems_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u32) {
        assert!(value > settings::max_gems(settings(game)), EBoundToLow);
        settings::set_max_gems(settings_mut(game), value);
    }
    public entry fun set_max_xp_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u32) {
        assert!(value > settings::max_xp(settings(game)), EBoundToLow);
        settings::set_max_xp(settings_mut(game), value);
    }
    public entry fun set_xp_dec_k_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_xp_dec_k(settings_mut(game), value);
    }
    public entry fun set_gems_dec_k_from_game(_: &GameAdminCap, game: &mut EvosGame, value: u64) {
        settings::set_gems_dec_k(settings::gems_mine_mut(settings_mut(game)), value);
    }

    // ==== For Users ====

    // Delegate the transfer right on the kiosk to the game object only.
    // The user can undelegate whenever he prefers.
    // A new UserInfo is created if necessary
    // A new UserSlot is created
    public entry fun delegate(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // sync_delegated();

        if(!(dof::exists_<ID>(&game.id, nft_id))){
            init_history_for_evos(game, nft_id, ctx);
        };

        lock_nft(game, kiosk, nft_id, ctx);
        game.delegations = game.delegations + 1;

        let sender: address = tx_context::sender(ctx);
        let slot: UserSlot = create_user_slot(sender, nft_id, clock, ctx);

        if(dof::exists_(&game.id, sender)){
            let user_info: &mut UserInfo = dof::borrow_mut(&mut game.id, sender);
            dof::add(&mut user_info.id, nft_id, slot);
            add_slot(user_info, nft_id);
        }else{
            let user_info: UserInfo = create_user_info(sender, ctx);
            dof::add(&mut user_info.id, nft_id, slot);
            add_slot(&mut user_info, nft_id);
            dof::add(&mut game.id, sender, user_info);
        }
    }

    // Cancel the delegation.
    // The lock from the kiosk is removed.
    // The ev0s gets updates if necessary [gems;xp]
    // Delete the UserSlot
    public entry fun cancel_delegation(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender: address = tx_context::sender(ctx);
        assert!(dof::exists_(&game.id, sender), ENoDelegationsFound);

        // Retrieve UserInfo
        //let user_info: &mut UserInfo = dof::borrow_mut(&mut game.id, sender);
        assert!(dof::exists_(&dof::borrow<address, UserInfo>(&game.id, sender).id, nft_id), EItemNotFound);
        sync_delegated(game, kiosk, nft_id, sender, clock::timestamp_ms(clock), policy, ctx);
        unlock_nft(game, kiosk, nft_id);

        // Remove the Slot from UserInfo
        let user_info: &mut UserInfo = dof::borrow_mut(&mut game.id, sender);
        let slots: vector<ID> = user_info.slots;
        let slot: UserSlot = dof::remove(&mut user_info.id, nft_id);

        // Remove the ID from UserInfo.slots array
        let index: u64 = 0;
        while(vector::length(&slots) > index) {
            if(*vector::borrow<ID>(&user_info.slots, index) == object::id(&slot)){
                vector::remove(&mut slots, index);
                break
            };
            index = index + 1;
        };

        // Delete the Slot
        let UserSlot {id, nft_id: _, owner: _, last_claim_gems: _, last_claim_xp: _, /*last_thread_check: _*/} = slot;
        object::delete(id);

        // Update EvosGame
        game.delegations = game.delegations-1;

        history::register_devolution_check_for_id(dof::borrow_mut(&mut game.id, nft_id), nft_id, clock::timestamp_ms(clock));
    }

    // Upgrade Stage
    // It upgrades [uri, stage]
    public entry fun to_next_stage(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        url: vector<u8>,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,      
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender: address = tx_context::sender(ctx);
        assert!(dof::exists_(&game.id, sender), ENoDelegationsFound);

        // Retrieve UserInfo
        let user_info: &mut UserInfo = dof::borrow_mut(&mut game.id, sender);
        assert!(dof::exists_(&user_info.id, nft_id), EItemNotFound);

        // Get nft from kiosk
        let now: u64 = clock::timestamp_ms(clock);

        //sync_delegated(game, nft, nft_id, sender, now, ctx);
        sync_delegated(game, kiosk, nft_id, sender, now, policy, ctx);

        let nft = ob_kiosk::ob_kiosk::borrow_nft(kiosk, nft_id);

        // Get nft attributes
        let stage: String = evos::stage(nft);
        let xp: u32 = evos::xp(nft);
        let level: u32 = evos::level(nft);

        // Check that 'next stage' exists
        let stages = settings::stages(settings(game));
        let stage_index: u64 = settings::get_stage_index(stages, &stage);
        assert!((stage_index + 1) < vector::length(stages), ENextStageNotFound);

        let current_stage: &Stage = vector::borrow(stages, stage_index);
        assert!(settings::stage_levels(current_stage) == level, ELevelTooLow);

        let next_stage: &Stage = vector::borrow(stages, stage_index+1);
        let next_stage_xp: u32 = settings::stage_base_xp(next_stage);
        
        // Asserts for upgrade stage conditions
        assert!(xp >= next_stage_xp, EInsufficientXp);

        // Update Ev0s
        evos::set_level_kiosk(kiosk, nft_id, 1, policy, ctx);
        evos::set_stage_kiosk(kiosk, nft_id, *string::bytes(&settings::stage_name(next_stage)), url, policy, ctx);
        sync_delegated(game, kiosk, nft_id, sender, now, policy, ctx);

        history::push_state(dof::borrow_mut(&mut game.id, nft_id), nft_id, sui::url::new_unsafe_from_bytes(b"test"), std::ascii::string(b""), std::ascii::string(b""));
    }

    // Pick a random Trait from the box and apply it to the Ev0s.
    public entry fun open_box(
        game: &mut EvosGame,
        box_index: u16,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>, 
        ctx: &mut TxContext
    ){
        let settings = dof::borrow<vector<u8>, TraitSettings>(&mut game.id, b"traits");
        let box = traits::box_by_index(settings, box_index);
        let price = traits::traitbox_price(box);
        
        let evos = ob_kiosk::ob_kiosk::borrow_nft(kiosk, nft_id);
        let gems = evos::gems(evos);
        let url = evos::url(evos);

        assert!(gems >= traits::traitbox_price(box), EInsufficientGems);
        assert!(string::index_of(&evos::stage(evos), &traits::traitbox_stage(box)) != string::length(&traits::traitbox_stage(box)), EWrongTraitBox);
        assert!(!history::box_already_open(dof::borrow<ID, EvosHistory>(&game.id, nft_id), nft_id, box_index), EBoxAlreadyOpened);
        assert!(!history::has_pending(dof::borrow<ID, EvosHistory>(&game.id, nft_id), ctx), EHasReceiptPending);

        let receipt = traits::new_receipt(
            *traits::get_random_trait(box, ctx),
            nft_id,
            url,
            ctx
        );
        history::push_pending(dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id), receipt, ctx);
        evos::sub_gems_kiosk(kiosk, nft_id, price, policy, ctx);
    }

    // GameThreadCap Only
    public entry fun confirm_box_receipt(
        _: &GameThreadCap,
        game: &mut EvosGame,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        trait_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let history = dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id);
        assert!(history::has_pending(history, ctx), ENotPendingReceipts);
        let receipt = history::pop_pending(history, ctx);
        traits::confirm_receipt(&mut receipt);

        let trait = traits::receipt_trait(&receipt);
        let trait_name = traits::trait_name(trait);
        let trait_value = traits::trait_value(trait);
        let k = string::from_ascii(trait_name);
        let v = string::from_ascii(trait_value);
        
        history::push_state(history, nft_id, traits::receipt_prev_url(&receipt), trait_name, trait_value);
        
        evos::set_attribute_kiosk(kiosk, nft_id, *string::bytes(&k), *string::bytes(&v), policy, ctx);
        evos::update_url_kiosk(kiosk, nft_id, trait_url, policy, ctx);

        traits::burn_receipt(receipt);
    }

    // get a box that user can open if present 
    public fun find_eligible_trait_box(
        history: &EvosHistory,
        nft_id: ID,
        settings: &TraitSettings,
        _ctx: &mut TxContext
    ): std::option::Option<u16> {
        let r: std::option::Option<u16> = std::option::none();
        let boxes = traits::trait_boxes(settings);
        let i: u64 = 0;
        while(i < vector::length(boxes)){
            let b = vector::borrow(boxes, i);
            if(!history::box_already_open(history, nft_id, traits::traitbox_index(b))){
                std::option::fill(&mut r, traits::traitbox_index(b));
                break
            };
            i = i+1;
        };
        r
    }

    // This can be called periodically by an off-chain automated script.
    public fun on_undelegated_evos(
        game: &mut EvosGame,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>, 
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        //let sender: address = tx_context::sender(ctx);
        assert!(dof::exists_<address>(&game.id, sui::kiosk::owner(kiosk)), ENoDelegationsFound);
        // assert!(dof::exists_<ID>(&dof::borrow<address, UserInfo>(&game.id, sender).id, nft_id), EItemNotFound);

        // Get the UserSlot for this Ev0s
        let now: u64 = clock::timestamp_ms(clock);

        sync_undelegated(
            game,
            kiosk,
            nft_id,
            now,
            policy,
            ctx
        );

        let evos = ob_kiosk::ob_kiosk::borrow_nft(kiosk, nft_id);
        let xp = evos::xp(evos);
        let stage = evos::stage(evos);
        let level = evos::level(evos);
        
        let stage_index: u64 = settings::get_stage_index(settings::stages(settings(game)), &stage);
        assert!(stage_index < vector::length(settings::stages(settings(game))), EPrevStageNotFound);

        // here we need to understand if we need to downgrade the stage or only the level. 
        if(xp < calc_xp_for_level(settings::stage_base_xp(vector::borrow(settings::stages(settings(game)), stage_index)), level)){
            
            let opened_boxes = history::opened_boxes(dof::borrow<ID, EvosHistory>(&game.id, nft_id));
            let current_stage: &Stage = vector::borrow(settings::stages(&game.settings), stage_index);

            while(stage_index > 0){
                
                // let history = dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id);
                let stage_level_xp: u32 = calc_xp_for_level(settings::stage_base_xp(current_stage), level);
                while(xp <= stage_level_xp && level > 1) {
                    let j: u64 = vector::length(&opened_boxes);
                    while(j > 0){
                        let box_index = *vector::borrow(&opened_boxes, j);
                        let b = traits::box_by_index(dof::borrow<vector<u8>, TraitSettings>(&game.id, b"traits"), box_index);
                        if(traits::traitbox_level(b) == level){
                            // Here we downgrade the ev0s
                            history::remove_box_from_opened(dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id), nft_id, box_index);
                            let (url, key, _) = history::pop_state(dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id), nft_id);
                            //evos::set_attribute(&mut evos, *std::ascii::as_bytes(&key), b"", ctx);
                            //evos::update_url(&mut evos, *std::ascii::as_bytes(&url::inner_url(&url)), ctx);
                            evos::set_attribute_kiosk(kiosk, nft_id, *std::ascii::as_bytes(&key), b"", policy, ctx);
                            evos::update_url_kiosk(kiosk, nft_id, *std::ascii::as_bytes(&url::inner_url(&url)), policy, ctx);
                            break
                        };
                    };
                    level = level - 1;
                    stage_level_xp = calc_xp_for_level(settings::stage_base_xp(current_stage), level);
                    evos::set_level_kiosk(kiosk, nft_id, level, policy, ctx);
                };

                if(level > 1){
                    break
                };
                
                let (url, _ , _) = history::pop_state(dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id), nft_id);
                current_stage = vector::borrow(settings::stages(&game.settings), stage_index - 1);

                evos::set_stage_kiosk(
                    kiosk,
                    nft_id,
                    *string::bytes(&settings::stage_name(current_stage)),
                    *std::ascii::as_bytes(&url::inner_url(&url)),
                    policy,
                    ctx
                );

                stage_index = stage_index - 1;
            };
        };

        //dof::borrow_mut<ID, UserSlot>(&mut dof::borrow_mut<address, UserInfo>(&mut game.id, sender).id, nft_id).last_thread_check = now;
    }

    public fun on_delegated_evos(
        game: &mut EvosGame,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        sync_delegated(
            game,
            kiosk,
            nft_id,
            tx_context::sender(ctx),
            clock::timestamp_ms(clock),
            policy,
            ctx
        );
    }

    // ==== PRIVATE ====
    
    // Sync
    fun sync_delegated(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        user: address,
        now: u64,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let (gems_frame, gems_rate) = gems_info_from_game(game);
        let (xp_frame, xp_rate) = xp_info_from_game(game);
        let max_gems = settings::max_gems(settings(game));
        let max_xp = settings::max_xp(settings(game));
        
        let nft = ob_kiosk::ob_kiosk::borrow_nft(kiosk, nft_id);
        let xp: u32 = evos::xp(nft);
        let gems: u32 = evos::gems(nft);

        // Get earned xp that isn't claimed yet
        let user_info = dof::borrow_mut<address, UserInfo>(&mut game.id, user);
        if(xp < max_xp){
            assert!(vector::length(&user_info.slots) > 0, 1);
            let slot = get_slot(user_info, nft_id);
            let uxp: u32 = xp_earned_since_last_update(xp_rate, xp_frame, slot.last_claim_xp, now);
            if(uxp > 0){
                if(uxp <= (max_xp - xp)){
                    evos::add_xp_kiosk(kiosk, nft_id, uxp, policy, ctx);
                }else{
                    evos::add_xp_kiosk(kiosk, nft_id, max_xp - xp, policy, ctx);
                };
                let slot = get_slot_mut(user_info, nft_id);
                slot.last_claim_xp = now;
            };
        };
        let amount = 0;
        if(gems < max_gems){
            let slot = get_slot(user_info, nft_id);
            let ugems: u32 = gems_earned_since_last_update(gems_rate, gems_frame, slot.last_claim_gems, now);
            if(ugems > 0){
                if(ugems <= (max_gems - gems)){
                    amount = ugems;
                }else{
                    amount = max_gems - gems;
                };
                let slot = get_slot_mut(user_info, nft_id);
                slot.last_claim_gems = now;
            };
        };

        add_gems(game, kiosk, nft_id, amount, policy, ctx);

        // Get nft attributes
        let nft = ob_kiosk::ob_kiosk::borrow_nft(kiosk, nft_id);
        let stage: String = evos::stage(nft);
        let xp: u32 = evos::xp(nft);
        let level: u32 = evos::level(nft);

        let stages = settings::stages(settings(game));
        let stage_index: u64 = settings::get_stage_index(stages, &stage);
        let current_stage: &Stage = vector::borrow(stages, stage_index);
        if(level >= settings::stage_levels(current_stage)){
            return
        };

        let l = evos::level(nft);
        while(xp >= calc_xp_for_level(settings::stage_base_xp(current_stage), l + 1)){
            l = l + 1;
        };
        evos::set_level_kiosk(kiosk, nft_id, l, policy, ctx);
    }
    fun sync_undelegated(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        now: u64,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        let (gems_frame, gems_rate) = gems_info_from_game(game);
        let (xp_frame, xp_rate) = xp_info_from_game(game);
        let gems_dec_k = settings::gems_dec_k(settings::gems_mine(settings(game)));
        let xp_dec_k = settings::xp_dec_k(settings(game));

        let nft = ob_kiosk::ob_kiosk::borrow_nft(kiosk, nft_id);
        let gems = evos::gems(nft);
        let xp = evos::xp(nft);

        let last_check = history::last_devolution_check_for_id(dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id), nft_id);
        if(last_check == 0){
            last_check = now;
        };
        let amount = 0;
        let chxp = true;
        if(gems > 0){
            let ugems: u32 = gems_lost_since_last_update(gems_rate * gems_dec_k, gems_frame, last_check, now);
            if(gems > ugems){
                amount = ugems;
                chxp = false;
                //sub_gems(game, nft, ugems, ctx);
            }else{
                amount = gems;
                if(gems == ugems){
                    chxp = false;
                };
            };
        };
        if(xp > 0 && chxp){
            let uxp: u32 = xp_lost_since_last_update(xp_rate * xp_dec_k, xp_frame, last_check, now);
            if(xp > uxp){
                //sub_xp(nft, uxp, ctx);
                sub_xp(kiosk, nft_id, uxp, policy, ctx);
            }else{
                sub_xp(kiosk, nft_id, xp, policy, ctx);
            };
        };

        history::register_devolution_check_for_id(
            dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id),
            nft_id,
            now
        );


        if(amount > 0){
            sub_gems(game, kiosk, nft_id, amount, policy, ctx)
        };


    }

    // EvosHistory
    fun init_history_for_evos(
        game: &mut EvosGame,
        nft_id: ID,
        ctx: &mut TxContext
    ) {
        let history = history::create_history(nft_id, ctx);
        dof::add(&mut game.id, nft_id, history);
    }

    // Kiosk related
    // fun withdraw_evos(
    //     _game: &EvosGame,
    //     kiosk: &mut sui::kiosk::Kiosk, 
    //     nft_id: ID, 
    //     policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
    //     ctx: &mut TxContext, 
    // ): Evos {
    //     let (nft, withdraw_request) = ob_kiosk::withdraw_nft_signed(kiosk, nft_id, ctx); 
    //     evos::confirm_withdrawal(&mut withdraw_request); 
    //     ob_request::withdraw_request::confirm(withdraw_request, policy);
    //     nft
    // }

    // fun deposit_evos(
    //     game: &EvosGame,
    //     kiosk: &mut sui::kiosk::Kiosk, 
    //     nft: Evos,
    //     ctx: &mut TxContext, 
    // ) {
    //     let evos_id = sui::object::id(&nft);
    //     ob_kiosk::ob_kiosk::deposit<Evos>(kiosk, nft, ctx);
    //     lock_nft(game, kiosk, evos_id, ctx);
    // }
    fun lock_nft(
        game: &EvosGame,
        kiosk: &mut sui::kiosk::Kiosk, 
        nft_id: ID,
        ctx: &mut TxContext
    ) {
        ob_kiosk::auth_exclusive_transfer(kiosk, nft_id, &game.id, ctx);
    }
    fun unlock_nft(
        game: &EvosGame,
        kiosk: &mut sui::kiosk::Kiosk, 
        nft_id: ID,
    ) {
        ob_kiosk::remove_auth_transfer(kiosk, nft_id, &game.id);
    }

    // ==== XP, Gems & Stage related ====
    fun calc_xp_for_next_level(prev: u32): u32 {
        let fixed: u32 = 39;
        let variable: u32 = 115; // to div by 100
        (sui::math::divide_and_round_up(((prev + fixed) * variable as u64), 100) as u32)
    }
    fun calc_xp_for_level(base: u32, level: u32): u32 {
        let i: u32 = 1;
        let xp: u32 = base;
        while(i < level){
            xp = calc_xp_for_next_level(xp);
            i = i + 1
        };
        xp
    }
    fun gems_earned_since_last_update(
        rate: u64,
        frame: u64,
        last_claim: u64,
        now: u64
    ): u32 {
        let elapsed: u64 = now - last_claim;
        if(elapsed > frame){
            let earnings: u64 = ((elapsed - (elapsed % frame)) / frame) * rate;
            (earnings as u32)
        }else{
            0
        }
    }
    fun xp_earned_since_last_update(
        rate: u64,
        frame: u64,
        last_claim: u64,
        now: u64
    ): u32 {
        let elapsed: u64 = now - last_claim;
        if(elapsed > frame){
            let earnings: u64 = ((elapsed - (elapsed % frame)) / frame) * rate;
            (earnings as u32)
        }else{
            0
        }
    }
    fun gems_lost_since_last_update(
        rate: u64,
        frame: u64,
        last_update: u64,
        now: u64
    ): u32 {
        let elapsed: u64 = now - last_update;
        if(elapsed > frame){
            let earnings: u64 = ((elapsed - (elapsed % frame)) / frame) * rate;
            (earnings as u32)
        }else{
            0
        }
    }
    fun xp_lost_since_last_update(
        rate: u64,
        frame: u64,
        last_update: u64,
        now: u64
    ): u32 {
        let elapsed: u64 = now - last_update;
        if(elapsed > frame){
            let earnings: u64 = ((elapsed - (elapsed % frame)) / frame) * rate;
            (earnings as u32)
        }else{
            0
        }
    }

    fun add_gems(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        evos_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        evos::add_gems_kiosk(kiosk, evos_id, amount, policy, ctx);
        settings::emit_gems(settings::gems_mine_mut(settings_mut(game)), amount);
    }
    fun sub_gems(
        game: &mut EvosGame,
        kiosk: &mut sui::kiosk::Kiosk,
        evos_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        evos::sub_gems_kiosk(kiosk, evos_id, amount, policy, ctx);
        settings::burn_gems(settings::gems_mine_mut(settings_mut(game)), amount)
    }
    fun add_xp(
        kiosk: &mut sui::kiosk::Kiosk,
        evos_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        evos::add_xp_kiosk(kiosk, evos_id, amount, policy, ctx);
    }
    fun sub_xp(
        kiosk: &mut sui::kiosk::Kiosk,
        evos_id: ID,
        amount: u32,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>,
        ctx: &mut TxContext
    ) {
        evos::sub_xp_kiosk(kiosk, evos_id, amount, policy, ctx);
    }

    #[test_only]
    use sui::test_scenario::{Self, ctx};

    #[test_only]
    use std::ascii;

    #[test_only]
    const CREATOR: address = @0xABBA;


    #[test]
    fun core_init_success(){
        let scenario = test_scenario::begin(CREATOR);

        init(EVOSCORE {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 0, 2);

        let settings = settings(&game);
        let gems_mine = settings::gems_mine(settings);
        let stages = settings::stages(settings);

        assert!(settings::xp_per_frame(settings) == DEFAULT_XP_PER_FRAME, 3);
        assert!(settings::xp_frame(settings) == DEFAULT_XP_TIME_FRAME, 4);
        assert!(settings::xp_var_fac(settings) == DEFAULT_XP_VAR_FAC, 5);

        assert!(settings::gems_per_frame(gems_mine) == DEFAULT_GEMS_PER_FRAME, 6);
        assert!(settings::gems_frame(gems_mine) == DEFAULT_GEMS_TIME_FRAME, 7);

        let egg = std::vector::borrow(stages, 0);
        assert!(string::length(&settings::stage_name(egg)) == 3, 8);
        assert!(settings::stage_base_xp(egg) == 0, 9);
        assert!(settings::stage_levels(egg) == 1, 10);
        assert!(vector::length(&settings::stage_rewards(egg)) == 0, 11);
        
        let baby = std::vector::borrow(stages, 1);
        assert!(string::length(&settings::stage_name(baby)) == 4, 12);
        assert!(settings::stage_base_xp(baby) == 20, 13);
        assert!(settings::stage_levels(baby) == 5, 14);
        assert!(vector::length(&settings::stage_rewards(baby)) == 3, 15);

        let juvenile = std::vector::borrow(stages, 2);
        assert!(string::length(&settings::stage_name(juvenile)) == 8, 16);
        assert!(settings::stage_base_xp(juvenile) == 343, 17);
        assert!(settings::stage_levels(juvenile) == 5, 18);
        assert!(vector::length(&settings::stage_rewards(juvenile)) == 3, 19);

        let adult = std::vector::borrow(stages, 3);
        assert!(string::length(&settings::stage_name(adult)) == 5, 20);
        assert!(settings::stage_base_xp(adult) == 992, 21);
        assert!(settings::stage_levels(adult) == 5, 22);
        assert!(vector::length(&settings::stage_rewards(adult)) == 3, 23);

        assert!(dof::exists_(&game.id, b"traits"), 24);

        let traits_settings = dof::borrow(&game.id, b"traits");
        assert!(vector::length(traits::trait_boxes(traits_settings)) == 0, 25);

        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, CREATOR);

        test_scenario::end(scenario);

    }

    #[test]
    fun core_delegate_evos(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);
        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info(&game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let fo = false;
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                fo = true;
                break
            };
        };
        assert!(fo, 10);

        test_scenario::next_tx(&mut scenario, user);
        assert!(dof::exists_(&user_info.id, evos_id), 11);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_cancel_delegation_evos(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        assert!(delegations(&game) == 1, 3);
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info(&game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };

        assert!(std::option::is_some(&sid), 10);
        assert!(dof::exists_(&user_info.id, evos_id), 11);
        
        cancel_delegation(
            &mut game,
            &mut kiosk,
            evos_id,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ob_kiosk::ob_kiosk::ENftAlreadyExclusivelyListed)]
    fun core_lock_evos_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_transfer_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        //test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        //let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info(&game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);

        ob_kiosk::ob_kiosk::assert_not_exclusively_listed(&mut kiosk, evos_id);

        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_unlock_evos_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info(&game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);

        let sid = std::option::extract(&mut sid);
        assert!(sid == evos_id, 11);
        cancel_delegation(
            &mut game,
            &mut kiosk,
            sid,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        ob_kiosk::ob_kiosk::assert_not_exclusively_listed(&mut kiosk, evos_id);

        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_sync_delegated_when_cancel_delegation_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info(&game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);
        
        // should earn 4 gems & 1 xp
        let time_elapsed: u64 = (DEFAULT_GEMS_TIME_FRAME * 4) + (DEFAULT_GEMS_TIME_FRAME / 2);
        sui::clock::increment_for_testing(&mut clock, time_elapsed);
        test_scenario::next_tx(&mut scenario, user);

        cancel_delegation(
            &mut game,
            &mut kiosk,
            std::option::extract(&mut sid),
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        ob_kiosk::ob_kiosk::assert_not_exclusively_listed(&mut kiosk, evos_id);
        evos::create_transfer_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let nft = ob_kiosk::ob_kiosk::borrow_nft(&kiosk, evos_id);

        assert!(evos::gems(nft) == 4, 11);
        assert!(evos::xp(nft) == 1, 12);
        
        test_scenario::return_to_address(CREATOR, evos_pub);

        //test_scenario::return_shared(tx_policy);
        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_to_next_stage_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info_mut(&mut game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);
        
        // should earn 48 gems & 192 xp
        let time_elapsed: u64 = (DEFAULT_XP_TIME_FRAME * 48);
        sui::clock::increment_for_testing(&mut clock, time_elapsed);
        test_scenario::next_tx(&mut scenario, user);
        
        on_delegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        let evos = ob_kiosk::ob_kiosk::borrow_nft(&kiosk, evos_id);
        assert!(evos::xp(evos) == 48, 5);
        assert!(evos::gems(evos) == 192, 6);
        
        test_scenario::next_tx(&mut scenario, user);

        to_next_stage(
            &mut game,
            &mut kiosk,
            evos_id,
            b"http://test-trait.org",
            &policy,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);
        
        let evos = ob_kiosk::ob_kiosk::borrow_nft(&kiosk, evos_id);
        assert!(evos::stage(evos) == string::utf8(b"Baby"), 6);
        assert!(evos::xp(evos) == 48, 6);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"http://test-trait.org"), 6);

        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_to_next_stage_and_next_1_level_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info_mut(&mut game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);
        
        // should earn 48 gems & 192 xp
        sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 68);
        test_scenario::next_tx(&mut scenario, user);
        
        on_delegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        let evos = ob_kiosk::ob_kiosk::borrow_nft(&kiosk, evos_id);
        assert!(evos::xp(evos) == 68, 5);
        assert!(evos::gems(evos) == 272, 6);
        test_scenario::next_tx(&mut scenario, user);

        to_next_stage(
            &mut game,
            &mut kiosk,
            evos_id,
            b"http://test-trait.org",
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        on_delegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&mut kiosk, evos_id);

        assert!(evos::stage(evos) == string::utf8(b"Baby"), 6);
        assert!(evos::xp(evos) == 68, 7);
        assert!(evos::level(evos) == 2, 8);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"http://test-trait.org"), 9);

        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_to_next_stage_and_next_2_level_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);        
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info_mut(&mut game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);
        
        // should earn 20 gems & 80 xp
        sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 20);
        test_scenario::next_tx(&mut scenario, user);
        
        on_delegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&mut kiosk, evos_id);
        assert!(evos::xp(evos) == 20, 5);
        assert!(evos::gems(evos) == 80, 6);
        test_scenario::next_tx(&mut scenario, user);

        to_next_stage(
            &mut game,
            &mut kiosk,
            evos_id,
            b"http://test-trait.org",
            &policy,
            &clock,
            ctx(&mut scenario)
        );
        sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 104);
        test_scenario::next_tx(&mut scenario, user);


        on_delegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::stage(evos) == string::utf8(b"Baby"), 6);
        assert!(evos::xp(evos) == 124, 7);
        assert!(evos::level(evos) == 3, 8);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"http://test-trait.org"), 9);

        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_on_undelegated_evos_works_correctly(){

        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
            test_scenario::return_shared(game);
            test_scenario::next_tx(&mut scenario, user);

            let game = test_scenario::take_shared<EvosGame>(&mut scenario);
            assert!(delegations(&game) == 1, 3);
            
            assert!(dof::exists_(&game.id, user), 4);
            let user_info = user_info(&game, user);
            let slots = slots(user_info);
            let i: u64 = 0;
            let sid: std::option::Option<ID> = std::option::none();
            while(i < vector::length(&slots)){
                let nft_id = *vector::borrow<ID>(&slots, i);
                if(nft_id == evos_id){
                    std::option::fill(&mut sid, nft_id);
                    let slot = get_slot(user_info, nft_id);
                    assert!(slot.owner == user, 5);
                    assert!(slot.last_claim_xp == 1000, 6);
                    assert!(slot.last_claim_gems == 1000, 7);
                    // assert!(slot.last_thread_check == 1000, 8);
                    assert!(slot.nft_id == nft_id, 9);
                    break
                };
            };
            assert!(std::option::is_some(&sid), 10);
            
            // should earn 12 gems & 3 xp
            let time_elapsed: u64 = (DEFAULT_GEMS_TIME_FRAME * 12);
            sui::clock::increment_for_testing(&mut clock, time_elapsed);
            test_scenario::next_tx(&mut scenario, user);

        cancel_delegation(
            &mut game,
            &mut kiosk,
            std::option::extract(&mut sid),
            &policy,
            &clock,
            ctx(&mut scenario)
        );

            ob_kiosk::ob_kiosk::assert_not_exclusively_listed(&mut kiosk, evos_id);
            test_scenario::next_tx(&mut scenario, user);

            let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&mut kiosk, evos_id);
            assert!(evos::gems(evos) == 12, 11);
            assert!(evos::xp(evos) == 3, 12);
            
            // loose the gems first
            sui::clock::increment_for_testing(&mut clock, DEFAULT_GEMS_TIME_FRAME * 6);
            test_scenario::next_tx(&mut scenario, CREATOR);

            assert!(dof::exists_(&game.id, evos_id), 13);
            assert!(dof::exists_(&game.id, b"traits"), 14);


        evos::create_transfer_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);
        
        on_undelegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

            let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
            assert!(evos::gems(evos) == 0, 13);
            assert!(evos::xp(evos) == 3, 14);

            // then loose the xp
            sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 2);
            test_scenario::next_tx(&mut scenario, user);

            assert!(dof::exists_(&game.id, evos_id), 13);
            assert!(dof::exists_(&game.id, b"traits"), 14);

        on_undelegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &policy,
            &clock,
            ctx(&mut scenario)
        );

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::gems(evos) == 0, 13);
        assert!(evos::xp(evos) == 0, 14);
        
        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_on_undelegated_evos_devolve_stage_works_correctly(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let borrow_policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);        
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        sui::clock::increment_for_testing(&mut clock, 1000);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);

        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, user);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        assert!(delegations(&game) == 1, 3);
        
        assert!(dof::exists_(&game.id, user), 4);
        let user_info = user_info(&game, user);
        let slots = slots(user_info);
        let i: u64 = 0;
        let sid: std::option::Option<ID> = std::option::none();
        while(i < vector::length(&slots)){
            let nft_id = *vector::borrow<ID>(&slots, i);
            if(nft_id == evos_id){
                std::option::fill(&mut sid, nft_id);
                let slot = get_slot(user_info, nft_id);
                assert!(slot.owner == user, 5);
                assert!(slot.last_claim_xp == 1000, 6);
                assert!(slot.last_claim_gems == 1000, 7);
                // assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);
        
        // should earn 68 gems & 272 xp
        let time_elapsed: u64 = (DEFAULT_XP_TIME_FRAME * 68);
        sui::clock::increment_for_testing(&mut clock, time_elapsed);
        test_scenario::next_tx(&mut scenario, user);

        to_next_stage(
            &mut game,
            &mut kiosk,
            evos_id,
            b"http://test-trait.org",
            &borrow_policy,
            &clock,
            ctx(&mut scenario)
        );

        test_scenario::next_tx(&mut scenario, user);

        cancel_delegation(
            &mut game,
            &mut kiosk,
            std::option::extract(&mut sid),
            &borrow_policy,
            &clock,
            ctx(&mut scenario)
        );

        ob_kiosk::ob_kiosk::assert_not_exclusively_listed(&mut kiosk, evos_id);
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::gems(evos) == 272, 11);
        assert!(evos::xp(evos) == 68, 12);
        
        // back to 0 xp
        sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 60);
        test_scenario::next_tx(&mut scenario, user);

        assert!(dof::exists_(&game.id, evos_id), 13);
        assert!(dof::exists_(&game.id, b"traits"), 14);

        on_undelegated_evos(
            &mut game,
            evos_id,
            &mut kiosk,
            &borrow_policy,
            &clock,
            ctx(&mut scenario)
        );

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::gems(evos) == 0, 13);
        assert!(evos::xp(evos) == 0, 14);
        assert!(evos::level(evos) == 1, 15);
        assert!(evos::stage(evos) == string::utf8(b"Egg"), 16);
        
        test_scenario::return_to_address(CREATOR, evos_pub);

        test_scenario::return_shared(borrow_policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_set_admin_variables(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        test_scenario::next_tx(&mut scenario, user);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let admin_cap = test_scenario::take_from_address<GameAdminCap>(&mut scenario, CREATOR);
        
        set_xp_var_fac_from_game(&admin_cap, &mut game, 0);
        set_xp_per_frame_from_game(&admin_cap, &mut game, 0);
        set_xp_frame_from_game(&admin_cap, &mut game, 0);
        set_gems_frame_from_game(&admin_cap, &mut game, 0);
        set_gems_per_frame_from_game(&admin_cap, &mut game, 0);
        set_max_gems_from_game(&admin_cap, &mut game, 2500);
        set_max_xp_from_game(&admin_cap, &mut game, 250);
        set_xp_dec_k_from_game(&admin_cap, &mut game, 0);
        set_gems_dec_k_from_game(&admin_cap, &mut game, 0);

        test_scenario::next_tx(&mut scenario, user);

        assert!(settings::xp_var_fac(settings(&game)) == 0, 0);
        assert!(settings::xp_per_frame(settings(&game)) == 0, 0);
        assert!(settings::xp_frame(settings(&game)) == 0, 0);
        assert!(settings::gems_per_frame(settings::gems_mine(settings(&game))) == 0, 0);
        assert!(settings::gems_frame(settings::gems_mine(settings(&game))) == 0, 0);
        assert!(settings::max_gems(settings(&game)) == 2500, 0);
        assert!(settings::max_xp(settings(&game)) == 250, 0);
        assert!(settings::xp_dec_k(settings(&game)) == 0, 0);
        assert!(settings::gems_dec_k(settings::gems_mine(settings(&game))) == 0, 0);

        test_scenario::return_to_address(CREATOR, admin_cap);
        test_scenario::return_to_address(CREATOR, evos_pub);
        test_scenario::return_shared(game);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_admin_add_trait_box(){
        let scenario = test_scenario::begin(CREATOR);

        init(EVOSCORE {}, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);

        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let admin_cap = test_scenario::take_from_address<GameAdminCap>(&mut scenario, CREATOR);
        assert!(delegations(&game) == 0, 2);

        assert!(dof::exists_(&game.id, b"traits"), 3);

        let names = vector::empty<vector<u8>>();
        vector::push_back(&mut names, b"test_attr_1");
        vector::push_back(&mut names, b"test_attr_2");

        let values = vector::empty<vector<u8>>();
        vector::push_back(&mut values, b"test_1");
        vector::push_back(&mut values, b"test_2");
        let urls = vector::empty<vector<u8>>();
        vector::push_back(&mut urls, b"http://test_1");
        vector::push_back(&mut urls, b"http://test_2");
        let weights = vector::empty<u8>();
        vector::push_back(&mut weights, 50);
        vector::push_back(&mut weights, 50);

        add_new_traitbox(
            &admin_cap,
            &mut game,
            2,
            b"Baby",
            names,
            values,
            urls,
            weights,
            10,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        let settings = dof::borrow<vector<u8>, TraitSettings>(&game.id, b"traits");
        let boxes = traits::box_by_stage(settings, &string::utf8(b"Baby"));
        assert!(vector::length(&boxes) == 1, 4);

        let box_index = *vector::borrow<u16>(&boxes, 0);
        let box = traits::box_by_index(settings, box_index);

        assert!(traits::traitbox_stage(box) == string::utf8(b"Baby"), 5);
        assert!(traits::traitbox_level(box) == 2, 6);
        assert!(traits::traitbox_price(box) == 10, 7);

        let box_traits = traits::traitbox_traits(box);
        assert!(vector::length(box_traits) == 2, 8);

        let trait_1 = vector::borrow(box_traits, 0);
        let trait_2 = vector::borrow(box_traits, 1);

        assert!(traits::trait_name(trait_1) == std::ascii::string(b"test_attr_1"), 9);
        assert!(traits::trait_name(trait_2) == std::ascii::string(b"test_attr_2"), 10);

        assert!(traits::trait_value(trait_1) == std::ascii::string(b"test_1"), 11);
        assert!(traits::trait_value(trait_2) == std::ascii::string(b"test_2"), 12);

        assert!(traits::trait_url(trait_1) == url::new_unsafe_from_bytes(b"http://test_1"), 13);
        assert!(traits::trait_url(trait_2) == url::new_unsafe_from_bytes(b"http://test_2"), 14);

        assert!(traits::trait_weight(trait_1) == 50, 15);
        assert!(traits::trait_weight(trait_2) == 50, 16);

        test_scenario::return_to_address(CREATOR, admin_cap);
        test_scenario::return_shared(game);
        test_scenario::next_tx(&mut scenario, CREATOR);

        test_scenario::end(scenario);
    }

    #[test]
    fun core_admin_create_box_and_user_opens_it(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let borrow_policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let admin_cap = test_scenario::take_from_address<GameAdminCap>(&mut scenario, CREATOR);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        
        assert!(delegations(&game) == 0, 2);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(dof::exists_(&game.id, b"traits"), 3);

        let names = vector::empty<vector<u8>>();
        vector::push_back(&mut names, b"test_attr_1");
        vector::push_back(&mut names, b"test_attr_2");

        let values = vector::empty<vector<u8>>();
        vector::push_back(&mut values, b"test_1");
        vector::push_back(&mut values, b"test_2");
        let urls = vector::empty<vector<u8>>();
        vector::push_back(&mut urls, b"http://test_1");
        vector::push_back(&mut urls, b"http://test_2");
        let weights = vector::empty<u8>();
        vector::push_back(&mut weights, 50);
        vector::push_back(&mut weights, 50);

        add_new_traitbox(
            &admin_cap,
            &mut game,
            2,
            b"Baby",
            names,
            values,
            urls,
            weights,
            10,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);
        
        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);
        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);
        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);
        assert!(delegations(&game) == 1, 3);

        // should earn 272 gems & 68 xp
        sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 68);
        test_scenario::next_tx(&mut scenario, user);

        to_next_stage(
            &mut game,
            &mut kiosk,
            evos_id,
            b"http://test-trait.org",
            &borrow_policy,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::stage(evos) == string::utf8(b"Baby"), 6);
        assert!(evos::xp(evos) == 68, 7);
        assert!(evos::gems(evos) == 272, 7);
        assert!(evos::level(evos) == 2, 8);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"http://test-trait.org"), 9);
        test_scenario::next_tx(&mut scenario, user);

        assert!(dof::exists_(&game.id, evos_id), 11);

        let box_index = find_eligible_trait_box(
            dof::borrow(&game.id, evos_id),
            evos_id,
            dof::borrow(&game.id, b"traits"),
            ctx(&mut scenario)
        );

        assert!(std::option::is_some(&box_index), 10);

        open_box(
            &mut game,
            std::option::extract(&mut box_index),
            evos_id,
            &mut kiosk,
            &borrow_policy,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);

        let thread_cap = test_scenario::take_from_address<GameThreadCap>(&mut scenario, CREATOR);
        
        confirm_box_receipt(
            &thread_cap,
            &mut game,
            evos_id,
            &mut kiosk,
            &borrow_policy,
            b"box_trait",
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"box_trait"), 13);

        test_scenario::return_to_address(CREATOR, evos_pub);
        test_scenario::return_to_address(CREATOR, admin_cap);
        test_scenario::return_to_address(CREATOR, thread_cap);

        test_scenario::return_shared(borrow_policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    #[test]
    fun core_admin_create_box_and_user_opens_it_and_check_evos_trait(){
        let scenario = test_scenario::begin(CREATOR);
        let user: address = @0xBABBA;
        knw_evos::utils::create_clock(ctx(&mut scenario));

        init(EVOSCORE {}, ctx(&mut scenario));
        evos::init_for_test(ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(test_scenario::has_most_recent_shared<EvosGame>(), 1);
        assert!(test_scenario::has_most_recent_shared<evos::Incubator>(), 2);

        let evos_pub = test_scenario::take_from_address<sui::package::Publisher>(&mut scenario, CREATOR);
        evos::create_borrow_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let borrow_policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::borrow_request::BORROW_REQ>>>(&mut scenario);
        let game = test_scenario::take_shared<EvosGame>(&mut scenario);
        let admin_cap = test_scenario::take_from_address<GameAdminCap>(&mut scenario, CREATOR);
        let incubator = test_scenario::take_shared<evos::Incubator>(&mut scenario);
        let clock = test_scenario::take_shared<sui::clock::Clock>(&mut scenario);
        
        assert!(delegations(&game) == 0, 2);

        evos::create_kiosk_with_evos_for_test(&mut incubator, user, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, CREATOR);

        assert!(dof::exists_(&game.id, b"traits"), 3);

        let names = vector::empty<vector<u8>>();
        vector::push_back(&mut names, b"test_attr_1");

        let values = vector::empty<vector<u8>>();
        vector::push_back(&mut values, b"test_1");
        let urls = vector::empty<vector<u8>>();
        vector::push_back(&mut urls, b"http://test_1");
        let weights = vector::empty<u8>();
        vector::push_back(&mut weights, 255);

        add_new_traitbox(
            &admin_cap,
            &mut game,
            2,
            b"Baby",
            names,
            values,
            urls,
            weights,
            10,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);
        
        let evos_id = *vector::borrow<ID>(&evos::all_evos_ids(&incubator), 0);
        let kiosk = test_scenario::take_shared<sui::kiosk::Kiosk>(&mut scenario);
        delegate(&mut game, &mut kiosk, evos_id, &clock, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);
        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);
        assert!(delegations(&game) == 1, 3);

        // should earn 272 gems & 68 xp
        sui::clock::increment_for_testing(&mut clock, DEFAULT_XP_TIME_FRAME * 68);
        test_scenario::next_tx(&mut scenario, user);

        to_next_stage(
            &mut game,
            &mut kiosk,
            evos_id,
            b"http://test-trait.org",
            &borrow_policy,
            &clock,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::stage(evos) == string::utf8(b"Baby"), 6);
        assert!(evos::xp(evos) == 68, 7);
        assert!(evos::gems(evos) == 272, 7);
        assert!(evos::level(evos) == 2, 8);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"http://test-trait.org"), 9);
        test_scenario::next_tx(&mut scenario, user);

        assert!(dof::exists_(&game.id, evos_id), 11);

        let box_index = find_eligible_trait_box(
            dof::borrow(&game.id, evos_id),
            evos_id,
            dof::borrow(&game.id, b"traits"),
            ctx(&mut scenario)
        );

        assert!(std::option::is_some(&box_index), 10);

        open_box(
            &mut game,
            std::option::extract(&mut box_index),
            evos_id,
            &mut kiosk,
            &borrow_policy,
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, CREATOR);
        
        ob_kiosk::ob_kiosk::assert_exclusively_listed(&mut kiosk, evos_id);

        let thread_cap = test_scenario::take_from_address<GameThreadCap>(&mut scenario, CREATOR);
        
        confirm_box_receipt(
            &thread_cap,
            &mut game,
            evos_id,
            &mut kiosk,
            &borrow_policy,
            b"box_trait",
            ctx(&mut scenario)
        );
        test_scenario::next_tx(&mut scenario, user);

        let evos = ob_kiosk::ob_kiosk::borrow_nft<Evos>(&kiosk, evos_id);
        assert!(evos::url(evos) == url::new_unsafe_from_bytes(b"box_trait"), 13);
        assert!(evos::has_attribute(evos, b"test_attr_1"), 14);
        assert!(evos::get_attribute(evos, b"test_attr_1") == ascii::string(b"test_1"), 15);

        test_scenario::return_to_address(CREATOR, evos_pub);
        test_scenario::return_to_address(CREATOR, admin_cap);
        test_scenario::return_to_address(CREATOR, thread_cap);

        test_scenario::return_shared(borrow_policy);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(game);
        test_scenario::return_shared(incubator);
        test_scenario::return_shared(kiosk);

        test_scenario::next_tx(&mut scenario, CREATOR);
        test_scenario::end(scenario);
    }

    // TODO: test history_
    // TODO: test boxes_
    
}