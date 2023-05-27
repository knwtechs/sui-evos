/* Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Module details:
 *  Description: All game logic such as devolution and evolution mechs are handled by this module.
 *  Features:
 *          - (GameAdminCap) Create a new `Stage`
 */
module knw_evos::evoscore {

    use knw_evos::evos::{Self, Evos};
    use knw_evos::traits::{Self, TraitSettings};
    use knw_evos::history::{Self, EvosHistory};

    use std::string::{Self, String};
    use std::vector;

    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID, ID};
    use sui::url;

    use sui::dynamic_object_field as dof;
    use sui::tx_context::{Self, TxContext};

    use ob_kiosk::ob_kiosk;
    //use ob_permissions::witness;
    //use ob_request::request;
    //use ob_request::borrow_request;

    struct Witness has drop {}
    struct EVOSCORE has drop {}

    struct GameAdminCap has key, store { id: UID }
    struct GameThreadCap has key, store { id: UID }

    struct EvosGame has key, store {
        id: UID,
        settings: GameSettings,
        delegations: u64
    }  

    // Stores all the GameSettings
    struct GameSettings has store {
        gems_mine: GemsMine,
        xp_per_frame: u64,
        xp_timeframe: u64,
        xp_var_factor: u64,
        stages: vector<Stage>
    }

    // Keeps track of gems emission rate, supply emitted & burned
    struct GemsMine has store {
        emitted: u64,
        burned: u64,
        gems_per_frame: u64,
        timeframe: u64
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
        last_thread_check: u64,
        nft_id: ID
    }

    // A Stage represents:
    // N levels where the upgrade to the (N+1)th level costs the same xp amount than
    // the upgrade to the Nth level of the same Stage
    struct Stage has store, copy {
        name: String,
        base: u32,
        levels: u32,
        rewards: vector<u32>
    }

    // Constant values
    const MAX_U32: u32 = 4294967295;
    const MAX_U64: u64 = (2^64) - 1;
    const DEFAULT_GEMS_TIME_FRAME: u64 = 1000 * 60 * 30; // DEFAULT_GEMS_PER_FRAME gem every 30 minutes
    const DEFAULT_GEMS_PER_FRAME: u64 = 1;
    const DEFAULT_XP_TIME_FRAME: u64 = 1000; // DEFAULT_XP_PER_SECOND every second
    const DEFAULT_XP_PER_FRAME: u64 = 1;
    const DEFAULT_XP_VAR_FAC: u64 = 115;
    const GEMSXP_RATE: u32 = 2;

    // Errors Code
    const EStageNotFound: u64 = 0;
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

    fun init(otw: EVOSCORE, ctx: &mut TxContext) {

        let sender = tx_context::sender(ctx);
        let publisher = sui::package::claim(otw, ctx);

        // Gems Mine
        let gems_mine = create_gems_mine(DEFAULT_GEMS_PER_FRAME, DEFAULT_GEMS_TIME_FRAME);

        // Stages
        let stages = vector::empty<Stage>();

        // Box rewards
        let rewards = vector::empty<u32>();
        vector::push_back(&mut rewards, 2);
        vector::push_back(&mut rewards, 3);
        vector::push_back(&mut rewards, 5);

        // Stage 0: Egg
        vector::push_back<Stage>(&mut stages, create_stage(b"Egg", 0, 1,  vector::empty<u32>()));
        // Stage 1: Baby
        vector::push_back<Stage>(&mut stages, create_stage(b"Baby", 20, 5, rewards));
        // Stage 2: Juvenile
        vector::push_back<Stage>(&mut stages, create_stage(b"Juvenile", 343, 5, rewards));
        // Stage 3: Adult
        vector::push_back<Stage>(&mut stages, create_stage(b"Adult", 992, 5, rewards));

        // Game Settings
        let game_settings = create_settings(
            gems_mine,
            DEFAULT_XP_PER_FRAME, // xp per frame
            DEFAULT_XP_TIME_FRAME, // frame
            DEFAULT_XP_VAR_FAC,
            stages
        );

        // Game
        let evos_game = create_game(game_settings, ctx);

        // Traits Settings
        let traits_settings = traits::create_trait_settings(ctx);
        dof::add(&mut evos_game.id, b"traits", traits_settings);

        transfer::public_share_object(evos_game);

        transfer::public_transfer(publisher, sender);
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
    fun create_settings(
        gems_mine: GemsMine,
        xp_per_frame: u64,
        xp_timeframe: u64,
        xp_var_factor: u64,
        stages: vector<Stage>,
    ): GameSettings {
        GameSettings{ gems_mine, xp_per_frame, xp_timeframe, xp_var_factor, stages }
    }
    fun create_gems_mine(
        gems_per_frame: u64,
        timeframe: u64
    ): GemsMine {
        GemsMine {
            emitted: 0u64,
            burned: 0u64,
            gems_per_frame,
            timeframe
        }
    }
    fun create_stage(
        name: vector<u8>,
        base: u32,
        levels: u32,
        rewards: vector<u32>
    ): Stage {
        Stage {
            name: string::utf8(name),
            base,
            levels,
            rewards
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
            last_thread_check: now
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
    fun get_game_info(game: &EvosGame): (u64, u64, &vector<Stage>) {
        (xp_frame(settings(game)), xp_per_frame(settings(game)), stages(settings(game)))
    }
    public fun xp_info_from_game(game: &EvosGame): (u64,u64) /* (frame, rate) */{
        (xp_frame(settings(game)), xp_per_frame(settings(game)))
    }
    public fun gems_info_from_game(game: &EvosGame): (u64, u64) /* (frame, rate) */{
        (gems_frame(gems_mine(settings(game))),  gems_per_frame(gems_mine(settings(game))))
    }
    public fun gems_emitted_from_game(game: &EvosGame): u64 {
        gems_emitted(gems_mine(settings(game)))
    }
    public fun gems_burned_from_game(game: &EvosGame): u64 {
        gems_burned(gems_mine(settings(game)))
    }
    public fun stages_from_game(game: &EvosGame): &vector<Stage> {
        stages(settings(game))
    }
    public fun traits_settings(game: &EvosGame): &TraitSettings {
        dof::borrow<vector<u8>, TraitSettings>(&game.id, b"traits")
    }
    fun settings_mut(game: &mut EvosGame): &mut GameSettings {
        &mut game.settings
    }
    fun set_xp_per_frame_from_game(game: &mut EvosGame, value: u64) {
        set_xp_per_frame(&mut game.settings, value)
    }
    fun set_xp_frame_from_game(game: &mut EvosGame, value: u64) {
        set_xp_frame(&mut game.settings, value)
    }
    fun set_gems_frame_from_game(game: &mut EvosGame, value: u64) {
        set_gems_frame(gems_mine_mut(game), value)
    }

    // Settings
    public fun gems_mine(settings: &GameSettings): &GemsMine {
        &settings.gems_mine
    }
    public fun xp_frame(settings: &GameSettings): u64 {
        settings.xp_timeframe
    }
    public fun xp_per_frame(settings: &GameSettings): u64 {
        settings.xp_per_frame
    }
    public fun stages(settings: &GameSettings): &vector<Stage> {
        &settings.stages
    }
    public fun get_stage_index_by_name(name: String, stages: &vector<Stage>): u64 {
        let i: u64 = 0;
        let l: u64 = vector::length(stages);
        while(l > i){
            let stage: &Stage = vector::borrow<Stage>(stages, i);
            if(string::index_of(&stage.name, &name) != string::length(&stage.name)){
                break
            };
            i = i+1;
        };
        assert!(l > i, EStageNotFound);
        i
    }
    public fun xp_var_fac(settings: &GameSettings): u64 {
        settings.xp_var_factor
    }
    fun set_xp_frame(settings: &mut GameSettings, value: u64) {
        settings.xp_timeframe = value
    }
    fun set_xp_per_frame(settings: &mut GameSettings, value: u64) {
        settings.xp_per_frame = value
    }
    fun set_xp_var_fac(settings: &mut GameSettings, value: u64) {
        settings.xp_var_factor = value
    }
    fun set_gems_per_frame_from_settings(settings: &mut GameSettings, value: u64) {
        set_gems_per_frame(&mut settings.gems_mine, value)
    }
    fun set_gems_frame_from_settings(settings: &mut GameSettings, value: u64) {
        set_gems_frame(&mut settings.gems_mine, value)
    }
    // Settings | Accessors
    fun add_stage_(
        settings: &mut GameSettings,
        name: vector<u8>,
        base: u32,
        levels: u32,
        rewards: vector<u32>
    ) {
        let stage = create_stage(name, base, levels, rewards);
        vector::push_back<Stage>(&mut settings.stages, stage);
    }
    fun gems_mine_mut(game: &mut EvosGame): &mut GemsMine {
        &mut settings_mut(game).gems_mine
    }

    // Gems
    public fun gems_emitted(mine: &GemsMine): u64 {
        mine.emitted
    }
    public fun gems_burned(mine: &GemsMine): u64 {
        mine.burned
    }
    public fun gems_per_frame(mine: &GemsMine): u64 {
        mine.gems_per_frame
    }
    public fun gems_frame(mine: &GemsMine): u64 {
        mine.timeframe
    }
    fun set_gems_per_frame(mine: &mut GemsMine, value: u64) {
        mine.gems_per_frame = value
    }
    fun set_gems_frame(mine: &mut GemsMine, value: u64) {
        mine.timeframe = value
    }
    fun burn_gems(mine: &mut GemsMine, value: u32) {
        mine.burned =  mine.burned + (value as u64)
    }
    fun emit_gems(mine: &mut GemsMine, value: u32) {
        mine.emitted =  mine.emitted + (value as u64)
    }

    // Stage
    public fun stage_name(stage: &Stage): String {
        stage.name
    }
    public fun stage_base_xp(stage: &Stage): u32 {
        stage.base
    }
    public fun stage_levels(stage: &Stage): u32 {
        stage.levels
    }
    public fun stage_rewards(stage: &Stage): vector<u32> {
        stage.rewards
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

    // TraitsSettings

    public entry fun create_traitbox(
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

    // ==== AdminOnly ====
    public fun add_stage(
        _: &GameAdminCap,
        game: &mut EvosGame,
        name: vector<u8>,
        base: u32,
        levels: u32,
        rewards: vector<u32>,
        _ctx: &mut TxContext
    ) {
        let stage = create_stage(name, base, levels, rewards);
        vector::push_back<Stage>(&mut settings_mut(game).stages, stage);
    }

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

        if(!(dof::exists_<ID>(&game.id, nft_id))){
            init_history_for_evos(game, nft_id, ctx);
        };

        ob_kiosk::auth_exclusive_transfer(kiosk, nft_id, &game.id, ctx);
        game.delegations = game.delegations+1;

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
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender: address = tx_context::sender(ctx);
        assert!(dof::exists_(&game.id, sender), ENoDelegationsFound);

        // Retrieve UserInfo
        let user_info: &mut UserInfo = dof::borrow_mut(&mut game.id, sender);
        let slots: vector<ID> = user_info.slots;
        assert!(dof::exists_(&user_info.id, nft_id), EItemNotFound);

        // Remove the Slot and update ev0s if necessary (xp and gems)
        let slot: UserSlot = dof::remove(&mut user_info.id, nft_id);

        // Remove the ID from slots array
        let index: u64 = 0;
        while(vector::length(&slots) > index) {
            if(*vector::borrow<ID>(&user_info.slots, index) == object::id(&slot)){
                vector::remove(&mut slots, index);
                break
            };
            index = index + 1;
        };
        
        let evos = withdraw_evos(kiosk, nft_id, policy, ctx);
        sync_delegated(game, &mut evos, &mut slot, clock::timestamp_ms(clock), ctx);
        deposit_evos(kiosk, evos, ctx);
        
        // Delete the Slot
        let UserSlot {id, nft_id: _, owner: _, last_claim_gems: _, last_claim_xp: _, last_thread_check: _} = slot;
        object::delete(id);

        // Update EvosGame
        game.delegations = game.delegations-1;
    }

    // Upgrade Stage
    // It upgrades [uri, stage]
    public entry fun to_next_stage(
        game: &mut EvosGame,
        user_info: &mut UserInfo,
        kiosk: &mut sui::kiosk::Kiosk,
        nft_id: ID,
        url: vector<u8>,
        // borrow_policy: &ob_request::request::Policy<request::WithNft<Evos, borrow_request::BORROW_REQ>>,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender: address = tx_context::sender(ctx);
        assert!(dof::exists_(&game.id, sender), ENoDelegationsFound);

        // Retrieve UserInfo
        //let user_info: &mut UserInfo = dof::borrow_mut(&mut game.id, sender);
        assert!(dof::exists_(&user_info.id, nft_id), EItemNotFound);

        // Get the UserSlot for this Ev0s
        let slot: &mut UserSlot = dof::borrow_mut(&mut user_info.id, nft_id);        

        // Get nft from kiosk
        let nft = withdraw_evos(kiosk, nft_id, policy, ctx);
        let now: u64 = clock::timestamp_ms(clock);

        sync_delegated(game, &mut nft, slot, now, ctx);

        // Get nft attributes
        let stage: String = evos::stage(&mut nft);
        let xp: u32 = evos::xp(&mut nft);
        let level: u32 = evos::level(&mut nft);

        // Check that 'next stage' exists
        let stages = stages(settings(game));
        let stage_index: u64 = get_stage_index(stages, &stage);
        assert!((stage_index + 1) < vector::length(stages), ENextStageNotFound);

        let current_stage: &Stage = vector::borrow(stages, stage_index);
        assert!(current_stage.levels == level, ELevelTooLow);

        let next_stage: &Stage = vector::borrow(stages, stage_index+1);
        let next_stage_xp: u32 = next_stage.base;
        
        // Asserts for upgrade stage conditions
        assert!(xp >= next_stage_xp, EInsufficientXp);

        // Update Ev0s
        evos::set_level(&mut nft, 1, ctx);
        evos::set_stage(&mut nft, *string::bytes(&next_stage.name), url, xp, ctx);

        deposit_evos(kiosk, nft, ctx);
        lock_nft(game, kiosk, nft_id, ctx);
    }

    // Upgrade Level
    // It upgrades [level]
    // public entry fun to_next_level(
    //     game: &mut EvosGame,
    //     user_info: &mut UserInfo,
    //     kiosk: &mut sui::kiosk::Kiosk,
    //     nft_id: ID,
    //     policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     let sender: address = tx_context::sender(ctx);
    //     assert!(dof::exists_(&game.id, sender), ENoDelegationsFound);

    //     // Retrieve UserInfo
    //     assert!(dof::exists_(&user_info.id, nft_id), EItemNotFound);

    //     // Get the UserSlot for this Ev0s
    //     let slot: &mut UserSlot = dof::borrow_mut(&mut user_info.id, nft_id);        

    //     // Get nft from kiosk
    //     let nft: Evos = withdraw_evos(kiosk, nft_id, policy, ctx);
    //     let now: u64 = clock::timestamp_ms(clock);

    //     sync_delegated(game, &mut nft, slot, now, ctx);

    //     // Get nft attributes
    //     let stage: String = evos::stage(&nft);
    //     let xp: u32 = evos::xp(&nft);
    //     let level: u32 = evos::level(&nft);

    //     let stages = stages(settings(game));
    //     let stage_index: u64 = get_stage_index(stages, &stage);
    //     let current_stage: &Stage = vector::borrow(stages, stage_index);
    //     assert!(current_stage.levels < level, EMaxLevelForStage);

    //     let next_level_xp = current_stage.base;

    //     let i: u32 = 1;
    //     while(i <= level){
    //         next_level_xp = calc_xp_for_next_level(next_level_xp);
    //         i = i+1;
    //     };
        
    //     // Asserts for upgrade level requirements
    //     assert!(xp >= next_level_xp, EInsufficientXp);

    //     // Update Ev0s
    //     evos::set_level(&mut nft, level + 1, ctx);

    //     deposit_evos(kiosk, nft, ctx);
    //     lock_nft(game, kiosk, nft_id, ctx);
    // }

    public entry fun open_box(
        game: &mut EvosGame,
        settings: &TraitSettings,
        box_index: u16,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        ctx: &mut TxContext
    ){
        let history = dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id);
        let box = traits::box_by_index(settings, box_index);
        let price = traits::traitbox_price(box);
        let evos = withdraw_evos(kiosk, nft_id, policy, ctx);
        let gems = evos::gems(&evos);
        let url = evos::url(&evos);

        assert!(string::index_of(&evos::stage(&evos), &traits::traitbox_stage(box)) != string::length(&traits::traitbox_stage(box)), EWrongTraitBox);
        assert!(!history::box_already_open(history, nft_id, box_index), EBoxAlreadyOpened);
        assert!(!history::has_pending(history, ctx), EHasReceiptPending);
        assert!(gems >= traits::traitbox_price(box), EInsufficientGems);

        let receipt = traits::new_receipt(
            *traits::get_random_trait(box, ctx),
            nft_id,
            url,
            ctx
        );
        history::push_pending(history, receipt, ctx);
        
        evos::set_gems(&mut evos, gems - price, ctx);

        deposit_evos(kiosk, evos, ctx);
        lock_nft(game, kiosk, nft_id, ctx);
    }

    public entry fun confirm_box_receipt(
        _: &GameThreadCap,
        game: &mut EvosGame,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        trait_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let history = dof::borrow_mut<ID, EvosHistory>(&mut game.id, nft_id);
        assert!(history::has_pending(history, ctx), ENotPendingReceipts);
        let receipt = history::pop_pending(history, ctx);
        let trait = traits::receipt_trait(&receipt);
        let trait_name = traits::trait_name(trait);
        let trait_value = traits::trait_value(trait);
        let k = string::from_ascii(trait_name);
        let v = string::from_ascii(trait_value);
        
        history::push_state(history, nft_id, traits::receipt_prev_url(&receipt), trait_name, trait_value);
        
        let evos = withdraw_evos(kiosk, nft_id, policy, ctx);
        evos::set_attribute(&mut evos, *string::bytes(&k), *string::bytes(&v), ctx);
        evos::update_url(&mut evos, trait_url, ctx);
        deposit_evos(kiosk, evos, ctx);
        lock_nft(game, kiosk, nft_id, ctx);

        traits::burn_receipt(receipt);
    }

    public fun openable_trait_boxes(
        history: &EvosHistory,
        nft_id: ID,
        settings: &TraitSettings,
        _ctx: &mut TxContext
    ): vector<u16> {
        let r = vector::empty<u16>();
        let boxes = traits::trait_boxes(settings);
        let i: u64 = 0;
        while(i < vector::length(boxes)){
            let b = vector::borrow(boxes, i);
            if(!history::box_already_open(history, nft_id, traits::traitbox_index(b))){
                vector::push_back(&mut r, traits::traitbox_index(b));
            };
            i = i+1;
        };
        r
    }

    // This can be called periodically by an off-chain automated script.
    public fun on_undelegated_evos(
        game: &mut EvosGame,
        settings: &TraitSettings,
        history: &mut EvosHistory,
        user_info: &mut UserInfo,
        nft_id: ID,
        kiosk: &mut sui::kiosk::Kiosk,
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender: address = tx_context::sender(ctx);
        assert!(dof::exists_(&game.id, sender), ENoDelegationsFound);
        assert!(dof::exists_(&user_info.id, nft_id), EItemNotFound);

        // Get the UserSlot for this Ev0s
        let now: u64 = clock::timestamp_ms(clock);
        let slot: &mut UserSlot = dof::borrow_mut(&mut user_info.id, nft_id);
        
        let evos = withdraw_evos(kiosk, nft_id, policy, ctx);

        sync_undelegated(
            game,
            &mut evos,
            slot,
            now,
            ctx
        );

        let xp = evos::xp(&evos);
        let stage = evos::stage(&evos);
        let level = evos::level(&evos);

        let stages = stages(settings(game));
        let stage_index: u64 = get_stage_index(stages, &stage);
        assert!((stage_index + 1) < vector::length(stages), ENextStageNotFound);

        let current_stage: &Stage = vector::borrow(stages, stage_index);
        let stage_level_xp: u32 = calc_xp_for_level(current_stage.base, level);

        // here we need to understand if we need to downgrade the stage or only the level. 
        if(xp < stage_level_xp){
            while(stage_index > 0){

                let opened_boxes = history::opened_boxes(history);

                while(xp <= stage_level_xp && level > 0) {
                    let j: u64 = vector::length(&opened_boxes);
                    while(j > 0){
                        let box_index = *vector::borrow(&opened_boxes, j);
                        let b = traits::box_by_index(settings, box_index);
                        if(traits::traitbox_level(b) == level){
                            // Here we downgrade the ev0s
                            history::remove_box_from_opened(history, nft_id, box_index);
                            let (url, key, value) = history::pop_state(history, nft_id);
                            evos::set_attribute(&mut evos, *std::ascii::as_bytes(&key), *std::ascii::as_bytes(&value), ctx);
                            evos::update_url(&mut evos, *std::ascii::as_bytes(&url::inner_url(&url)), ctx);
                            break
                        };
                    };
                    level = level - 1;
                    stage_level_xp = calc_xp_for_level(current_stage.base, level);
                    evos::set_level(&mut evos, level, ctx);
                };

                if(level > 0){
                    break
                };

                let (url, _ , _) = history::pop_state(history, nft_id);
                evos::set_stage(
                    &mut evos,
                    *string::bytes(&current_stage.name),
                    *std::ascii::as_bytes(&url::inner_url(&url)),
                    xp,
                    ctx
                );
                current_stage = vector::borrow(stages, stage_index - 1);
                stage_index = stage_index - 1;
            };
        };

        deposit_evos(kiosk, evos, ctx);
        slot.last_thread_check = now;
    }
    // public fun on_delegated_evos(){}
    fun sync_delegated(
        game: &mut EvosGame,
        nft: &mut Evos,
        slot: &mut UserSlot,
        now: u64,
        ctx: &mut TxContext
    ) {
        let (gems_frame, gems_rate) = gems_info_from_game(game);
        let (xp_frame, xp_rate) = xp_info_from_game(game);

        // Get earned xp that isn't claimed yet
        let uxp: u32 = xp_earned_since_last_update(xp_rate, xp_frame, slot.last_claim_xp, now);
        if(uxp > 0){
            add_xp(nft, uxp, ctx);
            slot.last_claim_xp = now;
        };
        let ugems: u32 = gems_earned_since_last_update(gems_rate, gems_frame, slot.last_claim_gems, now);
        if(ugems > 0){
            add_gems(game, nft, ugems, ctx);
            slot.last_claim_gems = now;
        };

        // Get nft attributes
        let stage: String = evos::stage(nft);
        let xp: u32 = evos::xp(nft);
        let level: u32 = evos::level(nft);

        let stages = stages(settings(game));
        let stage_index: u64 = get_stage_index(stages, &stage);
        let current_stage: &Stage = vector::borrow(stages, stage_index);
        if(level >= current_stage.levels){
            return
        };

        let next_level_xp = calc_xp_for_level(calc_xp_for_next_level(current_stage.base), level + 1);
        if(xp >= next_level_xp){
            // Increment level
            evos::set_level(nft, level + 1, ctx);
        };
    }
    fun sync_undelegated(
        game: &mut EvosGame,
        nft: &mut Evos,
        slot: &mut UserSlot,
        now: u64,
        ctx: &mut TxContext
    ) {
        let (gems_frame, gems_rate) = gems_info_from_game(game);
        let (xp_frame, xp_rate) = xp_info_from_game(game);
        let gems = evos::gems(nft);
        let xp = evos::xp(nft);

        // Get earned xp that isn't claimed yet
        let uxp: u32 = xp_lost_since_last_update(xp_rate, xp_frame, slot.last_claim_xp, now);
        if(uxp > 0){
            sub_xp(nft, uxp, ctx);
            slot.last_claim_xp = now;
        };
        let ugems: u32 = gems_lost_since_last_update(gems_rate, gems_frame, slot.last_claim_gems, now);
        if(ugems <= gems){
            sub_gems(game, nft, ugems, ctx);
        }else{
            let s = (ugems - gems) * GEMSXP_RATE;
            sub_gems(game, nft, gems, ctx);
            if(xp > s){
                sub_xp(nft, s, ctx);
            }else{
                sub_xp(nft, xp, ctx);
            };
        };
        slot.last_claim_gems = now;
    }

    fun init_history_for_evos(
        game: &mut EvosGame,
        nft_id: ID,
        ctx: &mut TxContext
    ) {
        let history = history::create_history(nft_id, ctx);
        dof::add(&mut game.id, nft_id, history);
    }

    fun withdraw_evos( 
        kiosk: &mut sui::kiosk::Kiosk, 
        nft_id: ID, 
        policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        ctx: &mut TxContext, 
    ): Evos { 
        let (nft, withdraw_request) = ob_kiosk::withdraw_nft_signed(kiosk, nft_id, ctx); 
        evos::confirm_withdrawal(&mut withdraw_request); 
        ob_request::withdraw_request::confirm(withdraw_request, policy);
        nft
    }
    fun deposit_evos( 
        kiosk: &mut sui::kiosk::Kiosk, 
        nft: Evos, 
        //policy: &ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>, 
        ctx: &mut TxContext, 
    ) { 
        ob_kiosk::ob_kiosk::deposit<Evos>(kiosk, nft, ctx)
    }
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

    // ==== HELPERS ====
    fun calc_xp_for_next_level(prev: u32): u32 {
        let fixed: u32 = 39;
        let variable: u32 = 115; // to div by 100
        ((prev * fixed) * variable) / 100
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
        // let rate: u64 = gems_per_frame_from_game(game);
        // let frame: u64 = gems_frame_from_game(game);
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
    fun get_stage_index(vec: &vector<Stage>, stage: &String): u64 {
        let i: u64 = 0;
        while(vector::length(vec) > i){
            let s = vector::borrow(vec, i);
            if(string::index_of(&s.name, stage) != string::length(&s.name)){         
                break
            };
            i = i+1;
        };
        i
    }

    // ==== PRIVATE ====
    fun add_gems(
        game: &mut EvosGame,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ) {
        assert!(gems_emitted_from_game(game) + (amount as u64) < MAX_U64, EU64Overflow);
        let gems = evos::gems(evos);
        evos::set_gems(evos, gems + amount, ctx);
        emit_gems(gems_mine_mut(game), amount);
    }
    fun sub_gems(
        game: &mut EvosGame,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ) {
        assert!(evos::gems(evos) >= amount, EInsufficientGems);
        assert!(gems_burned_from_game(game) + (amount as u64) < MAX_U64, EU64Overflow);
        let gems = evos::gems(evos);
        evos::set_gems(evos, gems - amount, ctx);
        burn_gems(gems_mine_mut(game), amount)
    }
    fun add_xp(
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ) {
        let xp = evos::xp(evos);
        evos::set_xp(evos, xp + amount, ctx);
    }
    fun sub_xp(
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ) {
        assert!(evos::xp(evos) >= amount, EInsufficientXp);
        let xp = evos::xp(evos);
        evos::set_xp(evos, xp - amount, ctx);
    }

    #[test_only]
    use sui::test_scenario::{Self, ctx};

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
        let gems_mine = gems_mine(settings);
        let stages = stages(settings);

        assert!(xp_per_frame(settings) == DEFAULT_XP_PER_FRAME, 3);
        assert!(xp_frame(settings) == DEFAULT_XP_TIME_FRAME, 4);
        assert!(xp_var_fac(settings) == DEFAULT_XP_VAR_FAC, 5);

        assert!(gems_per_frame(gems_mine) == DEFAULT_GEMS_PER_FRAME, 6);
        assert!(gems_frame(gems_mine) == DEFAULT_GEMS_TIME_FRAME, 7);

        let egg = std::vector::borrow(stages, 0);
        assert!(string::length(&stage_name(egg)) == 3, 8);
        assert!(stage_base_xp(egg) == 0, 9);
        assert!(stage_levels(egg) == 1, 10);
        assert!(vector::length(&stage_rewards(egg)) == 0, 11);
        
        let baby = std::vector::borrow(stages, 1);
        assert!(string::length(&stage_name(baby)) == 4, 12);
        assert!(stage_base_xp(baby) == 20, 13);
        assert!(stage_levels(baby) == 5, 14);
        assert!(vector::length(&stage_rewards(baby)) == 3, 15);

        let juvenile = std::vector::borrow(stages, 2);
        assert!(string::length(&stage_name(juvenile)) == 8, 16);
        assert!(stage_base_xp(juvenile) == 343, 17);
        assert!(stage_levels(juvenile) == 5, 18);
        assert!(vector::length(&stage_rewards(juvenile)) == 3, 19);

        let adult = std::vector::borrow(stages, 3);
        assert!(string::length(&stage_name(adult)) == 5, 20);
        assert!(stage_base_xp(adult) == 992, 21);
        assert!(stage_levels(adult) == 5, 22);
        assert!(vector::length(&stage_rewards(adult)) == 3, 23);

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
                assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                fo = true;
                break
            };
        };
        assert!(fo, 10);

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
        evos::create_transfer_policy(&evos_pub, ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, user);

        let policy = test_scenario::take_shared<ob_request::request::Policy<ob_request::request::WithNft<Evos, ob_request::withdraw_request::WITHDRAW_REQ>>>(&mut scenario);
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
                assert!(slot.last_thread_check == 1000, 8);
                assert!(slot.nft_id == nft_id, 9);
                break
            };
        };
        assert!(std::option::is_some(&sid), 10);

        cancel_delegation(
            &mut game,
            &mut kiosk,
            std::option::extract(&mut sid),
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
}