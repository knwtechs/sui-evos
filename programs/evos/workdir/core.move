/* Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Module details:
 *  Description: All game logic such as devolution and evolution mechs are handled by this module.
 *  Features:
 *          - (GameAdminCap) Create a new `Stage`
 */
module knw_evos::evoscore {

    // friend knw_evos::evosstaking;

    use knw_evos::evos::{Self, Evos};

    use std::string::{Self, String};
    use std::vector;

    use sui::transfer;
    use sui::object::{Self, UID};
    // use sui::package::{Publisher};
    // use sui::dynamic_object_field as dof;
    use sui::tx_context::{Self, TxContext};

    struct Witness has drop {}
    struct EVOSCORE has drop {}

    struct GameAdminCap has key, store { id: UID }

    struct EvosGame has key, store {
        id: UID,
        gems_mine: GemsMine,
        xp_per_second: u64,
        stages: vector<Stage>
    }

    // Keeps track of gems emission rate, supply emitted & burned
    struct GemsMine has store {
        emitted: u64,
        burned: u64,
        gems_per_second: u64
    }

    // A Stage represents:
    // N levels where the upgrade to the (N+1)th level costs the same xp amount than
    // the upgrade to the Nth level of the same Stage
    struct Stage has store, copy {
        name: String,
        level: u64, // ?
        levels: u64,
        xp_for_level: u64,
        xp_for_next: u64
    }

    // Constant values
    const MAX_U32: u32 = 4294967295;
    const MAX_U64: u64 = (2^64) - 1;

    // Errors Code
    const EStageNotFound: u64 = 0;
    const EInsufficientGems: u64 = 1;
    const EInsufficientXp: u64 = 2;
    const EMaxGemsExceeded: u64 = 3;
    const EMaxXpExceeded: u64 = 4;
    const EU64Overflow: u64 = 5;
    const EPublisherAlreadyLoaded: u64 = 6;


    // struct NFTData has key, store {
    //     id: UID,
    //     deposit_at_ms: u64,
    //     last_refresh_ms: u64,
    //     nft_id: ID,
    //     owner: address
    // }

    fun init(otw: EVOSCORE, ctx: &mut TxContext) {

        let sender = tx_context::sender(ctx);
        let publisher = sui::package::claim(otw, ctx);

        let evos_game = EvosGame {
            id: object::new(ctx),
            gems_mine: GemsMine{
                emitted: 0u64,
                burned: 0u64,
                gems_per_second: 0u64
            },
            xp_per_second: 0u64,
            stages: vector::empty<Stage>()
        };

        transfer::public_share_object(evos_game);
        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(
            GameAdminCap {
                id: object::new(ctx)
            },
            sender
        );

    }

    public fun xp_per_second(game: &EvosGame): u64 {
        game.xp_per_second
    }
    public fun gems_per_second(game: &EvosGame): u64 {
        game.gems_mine.gems_per_second
    }
    public fun gems_emitted(game: &EvosGame): u64 {
        game.gems_mine.emitted
    }
    public fun gems_burned(game: &EvosGame): u64 {
        game.gems_mine.burned
    }
    public fun stages(game: &EvosGame): vector<Stage> {
        game.stages
    }

    // ==== SETTERS ====
    public fun add_stage(
        _: &GameAdminCap,
        game: &mut EvosGame,
        name: vector<u8>,
        levels: u64,
        xp_for_level: u64,
        xp_for_next: u64,
        _ctx: &mut TxContext
    ) {
        let stage = create_stage(name, levels, xp_for_level, xp_for_next);
        vector::push_back<Stage>(&mut game.stages, stage);
    }

    // ==== CONSTRUCTORS ====
    fun create_stage(
        name: vector<u8>,
        levels: u64,
        xp_for_level: u64,
        xp_for_next: u64,
    ): Stage {
        Stage {
            name: string::utf8(name),
            levels,
            xp_for_level,
            xp_for_next,
            level: 0u64
        }
    }

    public fun add_gems(
        _: &GameAdminCap,
        game: &mut EvosGame,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ): u32 {
        assert!(gems_emitted(game) + (amount as u64) < MAX_U64, EU64Overflow);
        let gems = evos::gems(evos);
        evos::set_gems(evos, gems + amount, ctx);
        game.gems_mine.emitted = game.gems_mine.emitted + (amount as u64);
        evos::gems(evos)
    }
    public fun sub_gems(
        _: &GameAdminCap,
        game: &mut EvosGame,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ): u32 {
        assert!(evos::gems(evos) >= amount, EInsufficientGems);
        assert!(gems_burned(game) + (amount as u64) < MAX_U64, EU64Overflow);
        game.gems_mine.burned = game.gems_mine.burned + (amount as u64);
        let gems = evos::gems(evos);
        evos::set_gems(evos, gems - amount, ctx);
        evos::gems(evos)
    }
    public fun add_xp(
        _: &GameAdminCap,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ): u32 {
        //assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        let xp = evos::xp(evos);
        assert!(xp + amount <= MAX_U32, EMaxXpExceeded);
        evos::set_xp(evos, xp + amount, ctx);
        evos::xp(evos)
    }
    public fun sub_xp(
        _: &GameAdminCap,
        evos: &mut Evos,
        amount: u32,
        ctx: &mut TxContext
    ): u32 {
        //assert!(tx_context::sender(ctx) == incubator.admin, ENotOwner);
        let xp = evos::xp(evos);
        assert!(xp >= amount, EInsufficientXp);
        evos::set_xp(evos, xp - amount, ctx);
        evos::xp(evos)
    }

    // This can be called by the nft owner
    // public fun to_next_stage(
    //     game: &EvosGame,
    //     nft_id: ID,
    //     ctx: &mut TxContext
    // ){ 
    //     let dw = evos::create_witness(ctx);

    //     // 1. Get evos from kiosk
    //     // 2. Get current stage evos 
    //     // 3. Get next possible stage and calculate eligibility
    //     // 4. If eligible, then:
    //     //  4a. evos.xp = evos.xp - initial_stage.xp_for_next
    //     //  4b. evos.stage = stage.name
    //     // 5. Deposit the evos back to kiosk
    // }

    // This can be called only by BOT
    // public fun to_next_level(
    //     _: &GameAdminCap,
    //     game: &EvosGame,
    //     nft_id: ID,
    //     ctx: &mut TxContext
    // ){
    //     // 1. Get evos from kiosk
    //     // 2. Get current stage 
    //     // 3. assert!(evos.level < stage.levels, EMaxStageLevel)
    //     // 4. assert!(calc_unclaimed_xp_for_nft(evos) + evos.xp)
    //     // 4. If eligible, then:
    //     //  4a. evos.xp = evos.xp - stage.xp_for_level
    //     //  4b. update the stage with the next stage data
    //     // 5. Deposit the evos back to kiosk
    // }


    // ==== PRIVATE ====
    public fun get_stage_index(name: String, stages: &vector<Stage>): u64 {
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

    // #[test_only]
    // use sui::test_scenario::{Self, ctx};
    // #[test_only]
    // const CREATOR: address = @0xA1C04;

    // #[test_only]
    // const CLOCK: address = @0x6;
    // #[test]
    // fun test_kiosk_update_evos_xp() {

    //     let scenario = test_scenario::begin(CREATOR);
    //     let depositer = @0xBBB0AF;

    //     evos::create_clock(ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     init(EVOSCORE {}, ctx(&mut scenario));
    //     evosgenesisegg::init_for_test(evosgenesisegg::get_otw_for_test(), ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     let tracker = test_scenario::take_shared<MintTracker>(&scenario);
    //     mint_egg_to_recipient(&mut tracker, depositer, ctx(&mut scenario));

    //     test_scenario::next_tx(&mut scenario, depositer);

    //     let incubator = test_scenario::take_shared<Incubator>(&mut scenario);
    //     let clock = test_scenario::take_shared<Clock>(&scenario);
    //     let egg = test_scenario::take_from_address<EvosGenesisEgg>(
    //         &scenario,
    //         depositer,
    //     );
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
    //         &mut tracker,
    //         *vector::borrow<ID>(slots_uids, 0),
    //         &clock,
    //         ctx(&mut scenario)
    //     );
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     // Withdraw evos from kiosk
    //     assert!(test_scenario::has_most_recent_shared<Kiosk>(), 0);
    //     let kiosk = test_scenario::take_shared<Kiosk>(
    //         &scenario,
    //     );

    //     let publisher = sui::package::claim(EVOS {}, ctx(&mut scenario));
    //     let (tx_policy, policy_cap) = withdraw_request::init_policy<Evos>(&publisher, ctx(&mut scenario));

    //     let evos_array = all_evos_ids(&incubator);
    //     assert!(vector::length(&evos_array) > 0, 0);
    //     let nft_id: ID = get_evos_id_at(&incubator, 0);
    //     let (nft, request) = ob_kiosk::withdraw_nft_signed<Evos>(
    //         &mut kiosk,
    //         nft_id,
    //         ctx(&mut scenario)
    //     );
    //     withdraw_request::confirm<Evos>(request, &tx_policy);

    //     transfer::public_share_object(tx_policy);
    //     transfer::public_transfer(policy_cap, depositer);
    //     transfer::public_transfer(publisher, depositer);

    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     // Deposit evos back into the kiosk
    //     let update_cap = test_scenario::take_from_address<UpdateCap>(&mut scenario, CREATOR);
    //     add_xp(&update_cap, &mut nft, 20u32, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     assert!(xp(&nft) == 20u32, 15);
    //     //ob_kiosk::assert_listed(&mut kiosk, nft_id);

    //     //test_scenario::next_tx(&mut scenario, CREATOR);

    //     ob_kiosk::deposit(&mut kiosk, nft, ctx(&mut scenario));
    //     test_scenario::next_tx(&mut scenario, CREATOR);

    //     ob_kiosk::assert_not_listed(&mut kiosk, nft_id);
    //     ob_kiosk::assert_not_exclusively_listed(&mut kiosk, nft_id);

    //     assert!(index(&incubator) == 1, 5);
        
    //     test_scenario::return_shared(incubator);
    //     test_scenario::return_shared(clock);
    //     test_scenario::return_shared(kiosk);
    //     test_scenario::return_shared(tracker);
        
    //     test_scenario::return_to_address(CREATOR, update_cap);
    //     test_scenario::next_tx(&mut scenario, CREATOR);
    //     test_scenario::end(scenario);
    // }

}
