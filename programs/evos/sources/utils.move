/* Author: kunnow
 * Company: KNW Technologies FZCO
 * License: MIT
 * Description: Utilities.
 * Features:
 *      - Get a random number in [0, bound);
 */
module knw_evos::utils {

    public fun select(bound: u64, random: &vector<u8>): u64 {
        let random = ob_pseudorandom::pseudorandom::u256_from_bytes(random);
        let mod  = random % (bound as u256);
        (mod as u64)
    }

    #[test_only]
    const CLOCK: address = @0x6;

    #[test_only]
    public fun create_clock(ctx: &mut sui::tx_context::TxContext) {
        let clock = sui::clock::create_for_testing(ctx);
        sui::clock::share_for_testing(clock);
    }

}