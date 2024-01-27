module 169664f0f62bec3d59bb621d84df69927b3377a1f32ff16c862d28c158480065.evos {
	// genesis
	use cca18faec0dbe4b35ffc8e95308aa008c7b3eba38c2a9ddedf861b96cbc74ee2::evosgenesisegg;
	// liquidity_layer_v1
	use 4e0629fa51a62b0c1d7c7b9fc89237ec5b6f630d7798ad3f06d820afb93a995a::orderbook;
	// nft_protocol
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::attributes;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::collection;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::creators;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::display_info;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::mint_cap;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::mint_event;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::p2p_list;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::royalty;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::royalty_strategy_bps;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::tags;
	use bc3df36be17f27ac98e3c839b2589db8475fa07b20657b08e8891e3aaf5ee5f9::transfer_allowlist;
	// ob_kiosk
	use 95a441d389b07437d00dd07e0b6f05f513d7659b13fd7c5d3923c7d9d847199b::ob_kiosk;
	// ob_permissions
	use 16c5f17f2d55584a6e6daa442ccf83b4530d10546a8e7dedda9ba324e012fc40::witness;
	// ob_pseudorandom
	use 9e5962d5183664be8a7762fbe94eee6e3457c0cc701750c94c17f7f8ac5a32fb::pseudorandom;
	// ob_request
	use e2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43::borrow_request;
	use e2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43::transfer_request;
	// ob_utils
	use 859eb18bd5b5e8cc32deb6dfb1c39941008ab3c6e27f0b8ce2364be7102bb7cb::display;
	use 859eb18bd5b5e8cc32deb6dfb1c39941008ab3c6e27f0b8ce2364be7102bb7cb::utils;
	// STD
	use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
	use 0000000000000000000000000000000000000000000000000000000000000001::option;
	use 0000000000000000000000000000000000000000000000000000000000000001::string;
	use 0000000000000000000000000000000000000000000000000000000000000001::vector;
	// SUI
	use 0000000000000000000000000000000000000000000000000000000000000002::bcs; // missing
	use 0000000000000000000000000000000000000000000000000000000000000002::clock;
	use 0000000000000000000000000000000000000000000000000000000000000002::display as 0display;
	use 0000000000000000000000000000000000000000000000000000000000000002::dynamic_object_field;
	use 0000000000000000000000000000000000000000000000000000000000000002::kiosk; // missing
	use 0000000000000000000000000000000000000000000000000000000000000002::object; 
	use 0000000000000000000000000000000000000000000000000000000000000002::package;
	use 0000000000000000000000000000000000000000000000000000000000000002::sui;
	use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
	use 0000000000000000000000000000000000000000000000000000000000000002::transfer_policy; // missing
	use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
	use 0000000000000000000000000000000000000000000000000000000000000002::url;
	use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
	use 0000000000000000000000000000000000000000000000000000000000000002::vec_set; // missing


	struct EVOS has drop {
		dummy_field: bool
	}
	struct Witness has drop {
		dummy_field: bool
	}
	struct AdminCap has store, key {
		id: UID
	}
	struct Evos has store, key {
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
		evos_created: vector<ID>
	}
	struct Slot has store, key {
		id: UID,
		deposit_at: u64,
		owner: address
	}
	struct Specie has store {
		name: String,
		weight: u8,
		url: vector<u8>
	}

	init(Arg0: EVOS, Arg1: &mut TxContext)

	entry public deposit(Arg0: &mut Incubator, Arg1: EvosGenesisEgg, Arg2: &Clock, Arg3: &mut TxContext)
	entry public withdraw(Arg0: &mut Incubator, Arg1: ID, Arg2: &mut TxContext)
	entry public reveal(Arg0: &mut Incubator, Arg1: &mut MintTracker, Arg2: ID, Arg3: &Clock, Arg4: &mut TxContext)
	public burn_evos(Arg0: Evos)
	entry public migrate(Arg0: &AdminCap, Arg1: &mut Incubator, Arg2: &mut TxContext)
	entry public add_specie(Arg0: &AdminCap, Arg1: &mut Incubator, Arg2: String, Arg3: u8, Arg4: vector<u8>, Arg5: &mut TxContext)
	entry public give_admin_cap(Arg0: &AdminCap, Arg1: address, Arg2: &mut TxContext)
	
	public index(Arg0: &Incubator): u64
	public specs(Arg0: &Incubator): &vector<Specie>
	public inhold(Arg0: &Incubator): u64
	
	public revealable_at(Arg0: &Slot): u64
	public owner(Arg0: &Slot): address
	
	public name(Arg0: &Specie): String
	public weight(Arg0: &Specie): u8
	
	public url(Arg0: &Evos): Url
	public stage(Arg0: &Evos): String
	public species(Arg0: &Evos): String
	public xp(Arg0: &Evos): u32
	public gems(Arg0: &Evos): u32
	public level(Arg0: &Evos): u32
	
	public revealable_in(Arg0: u64, Arg1: &Clock): u64
	public all_evos_ids(Arg0: &Incubator): vector<ID>
	public get_evos_id_at(Arg0: &Incubator, Arg1: u64): ID
	public get_slots_id(Arg0: &Incubator, Arg1: &mut TxContext): vector<ID>
	entry public get_slot_revealable_at(Arg0: ID, Arg1: &Incubator, Arg2: &mut TxContext): u64
	entry public get_slot_owner(Arg0: ID, Arg1: &Incubator, Arg2: &mut TxContext): address
	
	public get_nft_field<Ty0: drop, Ty1: store>(Arg0: &mut BorrowRequest<Ty0, Evos>): Ty1 * ReturnPromise<Evos, Ty1>
	public return_nft_field<Ty0: drop, Ty1: store>(Arg0: &mut BorrowRequest<Ty0, Evos>, Arg1: Ty1, Arg2: ReturnPromise<Evos, Ty1>)
	public get_nft<Ty0: drop>(Arg0: &mut BorrowRequest<Ty0, Evos>): Evos
	public return_nft<Ty0: drop>(Arg0: &mut BorrowRequest<Ty0, Evos>, Arg1: Evos)

	// Setters
	public(friend) set_gems(Arg0: &mut Evos, Arg1: u32, Arg2: &mut TxContext): u32
	public(friend) set_xp(Arg0: &mut Evos, Arg1: u32, Arg2: &mut TxContext): u32
	public(friend) update_url(Arg0: &mut Evos, Arg1: vector<u8>, Arg2: &mut TxContext)
	public(friend) set_stage(Arg0: &mut Evos, Arg1: vector<u8>, Arg2: vector<u8>, Arg3: u32, Arg4: &mut TxContext)
	public(friend) set_level(Arg0: &mut Evos, Arg1: u32, Arg2: &mut TxContext)
	
	public(friend) set_attribute(Arg0: &mut Evos, Arg1: vector<u8>, Arg2: vector<u8>, Arg3: &mut TxContext)
	public has_attribute(Arg0: &mut Evos, Arg1: vector<u8>, Arg2: &mut TxContext): bool

	// OrderBook
	entry public init_protected_orderbook(Arg0: &Publisher, Arg1: &TransferPolicy<Evos>, Arg2: &mut TxContext)
	entry public enable_orderbook(Arg0: &Publisher, Arg1: &mut Orderbook<Evos, SUI>)
	entry public disable_orderbook(Arg0: &Publisher, Arg1: &mut Orderbook<Evos, SUI>)
	
	create_evos(Arg0: Witness<Evos>, Arg1: &mut Incubator, Arg2: &mut TxContext): Evos
	new_kiosk_with_evos(Arg0: Witness<Evos>, Arg1: &mut Incubator, Arg2: address, Arg3: &mut TxContext)
	create_specie(Arg0: String, Arg1: u8, Arg2: vector<u8>): Specie

	select(Arg0: u64, Arg1: &vector<u8>): u64
	draw_specie(Arg0: &vector<Specie>, Arg1: u64): &Specie
	register_new_evos(Arg0: &mut Incubator, Arg1: ID)
	remove_attribute(Arg0: &mut Evos, Arg1: vector<u8>, Arg2: &mut TxContext)

	Constants [
		0 => u64: 00ccbf1900000000
		1 => u32: ffffffff
		2 => u64: 4100000000000000
		3 => u64: 0100000000000000
		4 => address: 74a54d924aca2040b6c9800123ad9232105ea5796b8d5fc23af14dd3ce0f193f
		5 => address: 1dae98dcae53909f23184b273923184aa451986c4b71da1950d749def37f8ea0
		6 => address: 34f23af8106ecb5ada0c4ff956333ab234534a0060350f40b6e9518f861f7e02
		7 => u64: 0200000000000000
		8 => u64: 0300000000000000
		9 => u64: 0400000000000000
		10 => u64: 0500000000000000
		11 => u64: 0600000000000000
		12 => u64: 0700000000000000
		13 => u64: 0800000000000000
		14 => u64: 0900000000000000
		15 => u64: 0a00000000000000
		16 => u64: 0b00000000000000
		17 => u64: 0c00000000000000
		18 => vector<u8>: "name" // interpreted as UTF8 string
		19 => vector<u8>: "{name} #{index}" // interpreted as UTF8 string
		20 => vector<u8>: "species" // interpreted as UTF8 string
		21 => vector<u8>: "{species}" // interpreted as UTF8 string
		22 => vector<u8>: "stage" // interpreted as UTF8 string
		23 => vector<u8>: "{stage}" // interpreted as UTF8 string
		24 => vector<u8>: "level" // interpreted as UTF8 string
		25 => vector<u8>: "{level}" // interpreted as UTF8 string
		26 => vector<u8>: "xp" // interpreted as UTF8 string
		27 => vector<u8>: "{xp}" // interpreted as UTF8 string
		28 => vector<u8>: "gems" // interpreted as UTF8 string
		29 => vector<u8>: "{gems}" // interpreted as UTF8 string
		30 => vector<u8>: "attributes" // interpreted as UTF8 string
		31 => vector<u8>: "{attributes}" // interpreted as UTF8 string
		32 => vector<u8>: "image_url" // interpreted as UTF8 string
		33 => vector<u8>: "{url}" // interpreted as UTF8 string
		34 => vector<u8>: "tags" // interpreted as UTF8 string
		35 => vector<u8>: "ev0s" // interpreted as UTF8 string
		36 => vector<u8>: "ev0s is an evolutionary NFT adventure that pushes Dynamic NFTs to their fullest potential on Sui" // interpreted as UTF8 string
		37 => vector<u16>: 011027
		38 => vector<u8>: "Gold" // interpreted as UTF8 string
		39 => vector<u8>: "https://knw-gp.s3.eu-north-1.amazonaws.com/species/gold.png" // interpreted as UTF8 string
		40 => vector<u8>: "Forest" // interpreted as UTF8 string
		41 => vector<u8>: "https://knw-gp.s3.eu-north-1.amazonaws.com/species/forest.png" // interpreted as UTF8 string
		42 => vector<u8>: "Water" // interpreted as UTF8 string
		43 => vector<u8>: "https://knw-gp.s3.eu-north-1.amazonaws.com/species/water.png" // interpreted as UTF8 string
		44 => vector<u8>: "Rock" // interpreted as UTF8 string
		45 => vector<u8>: "https://knw-gp.s3.eu-north-1.amazonaws.com/species/rock.png" // interpreted as UTF8 string
		46 => vector<u8>: "Fire" // interpreted as UTF8 string
		47 => vector<u8>: "https://knw-gp.s3.eu-north-1.amazonaws.com/species/fire.png" // interpreted as UTF8 string
		48 => vector<u8>: "Evos" // interpreted as UTF8 string
		49 => vector<u8>: "Egg" // interpreted as UTF8 string
		50 => vector<u8>: "0" // interpreted as UTF8 string
		51 => vector<u8>: "1" // interpreted as UTF8 string
	]
}