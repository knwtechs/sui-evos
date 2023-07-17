/* 
 * Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Description: All game settings are handled by this module.
 * Features:
 *      - (GameSettings) It's the main wrapper for all the settings
 *      - (GemsMine) It contains all the gems settings
 *      - (Stage) It represent a stage
 */
module knw_evos::settings {

    friend knw_evos::evoscore;

    use std::string::{Self, String};
    use std::vector;

    const EStageNotFound: u64 = 0;

    // Stores all the GameSettings
    struct GameSettings has store {
        gems_mine: GemsMine,
        xp_per_frame: u64,
        xp_timeframe: u64,
        xp_var_factor: u64,
        xp_dec_k: u64,
        stages: vector<Stage>,
        max_gems: u32,
        max_xp: u32
    }

    // Keeps track of gems emission rate, supply emitted & burned
    struct GemsMine has store {
        emitted: u64,
        burned: u64,
        gems_per_frame: u64,
        gems_dec_k: u64,
        timeframe: u64
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

    public(friend) fun create_settings(
        gems_mine: GemsMine,
        xp_per_frame: u64,
        xp_timeframe: u64,
        xp_var_factor: u64,
        stages: vector<Stage>,
        max_gems: u32,
        max_xp: u32,
        xp_dec_k: u64,
    ): GameSettings {
        GameSettings{ gems_mine, xp_per_frame, xp_timeframe, xp_var_factor, stages, max_gems, max_xp, xp_dec_k }
    }

    public(friend) fun create_gems_mine(
        gems_per_frame: u64,
        timeframe: u64,
        gems_dec_k: u64
    ): GemsMine {
        GemsMine {
            emitted: 0u64,
            burned: 0u64,
            gems_per_frame,
            timeframe,
            gems_dec_k
        }
    }

    public(friend) fun create_stage(
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

    // GameSettings
    public fun gems_mine(settings: &GameSettings): &GemsMine {
        &settings.gems_mine
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

    public fun xp_frame(settings: &GameSettings): u64 {
        settings.xp_timeframe
    }
    public fun xp_per_frame(settings: &GameSettings): u64 {
        settings.xp_per_frame
    }
    public fun xp_var_fac(settings: &GameSettings): u64 {
        settings.xp_var_factor
    }
    public fun max_xp(settings: &GameSettings): u32 {
        settings.max_xp
    }
    public fun xp_dec_k(settings: &GameSettings): u64 {
        settings.xp_dec_k
    }
    public fun xp_info(settings: &GameSettings): (u64, u64) {
         (xp_frame(settings), xp_per_frame(settings))
    }

    public fun max_gems(settings: &GameSettings): u32 {
        settings.max_gems
    }
    public fun gems_info(settings: &GameSettings): (u64, u64) {
        (gems_frame(gems_mine(settings)),  gems_per_frame(gems_mine(settings)))
    }
    public fun gems_emitted_from_settings(settings: &GameSettings): u64 {
        gems_emitted(gems_mine(settings))
    }
    public fun gems_burned_from_settings(settings: &GameSettings): u64 {
        gems_burned(gems_mine(settings))
    }

    // GameSettings | Accessors
    public(friend) fun set_xp_frame(settings: &mut GameSettings, value: u64) {
        settings.xp_timeframe = value
    }
    public(friend) fun set_xp_per_frame(settings: &mut GameSettings, value: u64) {
        settings.xp_per_frame = value
    }
    public(friend) fun set_xp_var_fac(settings: &mut GameSettings, value: u64) {
        settings.xp_var_factor = value
    }
    public(friend) fun set_max_xp(settings: &mut GameSettings, value: u32) {
        settings.max_xp = value;
    }
    public(friend) fun set_xp_dec_k(settings: &mut GameSettings, value: u64) {
        settings.xp_dec_k = value;
    }

    public(friend) fun set_gems_per_frame_from_settings(settings: &mut GameSettings, value: u64) {
        set_gems_per_frame(&mut settings.gems_mine, value)
    }
    public(friend) fun set_gems_frame_from_settings(settings: &mut GameSettings, value: u64) {
        set_gems_frame(&mut settings.gems_mine, value)
    }
    public(friend) fun set_max_gems(settings: &mut GameSettings, value: u32) {
        settings.max_gems = value;
    }

    public(friend) fun add_stage_(
        settings: &mut GameSettings,
        name: vector<u8>,
        base: u32,
        levels: u32,
        rewards: vector<u32>
    ) {
        let stage = create_stage(name, base, levels, rewards);
        vector::push_back<Stage>(&mut settings.stages, stage);
    }
    public(friend) fun stages_mut(settings: &mut GameSettings): &mut vector<Stage> {
        &mut settings.stages
    }

    public(friend) fun gems_mine_mut(settings: &mut GameSettings): &mut GemsMine {
       &mut settings.gems_mine
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
    public fun gems_dec_k(mine: &GemsMine): u64 {
        mine.gems_dec_k
    }
    // Settings | Accessors
    public(friend) fun set_gems_per_frame(mine: &mut GemsMine, value: u64) {
        mine.gems_per_frame = value
    }
    public(friend) fun set_gems_frame(mine: &mut GemsMine, value: u64) {
        mine.timeframe = value
    }
    public(friend) fun set_gems_dec_k(mine: &mut GemsMine, value: u64) {
        mine.gems_dec_k = value;
    }
    public(friend) fun burn_gems(mine: &mut GemsMine, value: u32) {
        mine.burned =  mine.burned + (value as u64)
    }
    public(friend) fun emit_gems(mine: &mut GemsMine, value: u32) {
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
    public(friend) fun get_stage_index(vec: &vector<Stage>, stage: &String): u64 {
        let i: u64 = 0;
        while(vector::length(vec) > i){
            let s = vector::borrow(vec, i);
            if(string::index_of(&stage_name(s), stage) != string::length(&stage_name(s))){         
                break
            };
            i = i+1;
        };
        i
    }
}