# README.md for KNW Evos Blockchain Game Modules

## Overview

This documentation provides a comprehensive overview of the modules developed for Ev0s by KNW Technologies. These modules collectively form the backbone of a blockchain-based game, focusing on managing Non-Fungible Tokens (NFTs), game dynamics, and user interactions. 

## Modules Breakdown

### 1. Module: `knw_evos::evos`
   **Purpose**: Manages main entities in the game, such as EVOS and Incubators.
   **Key Functions**:
   - `deposit` and `withdraw` EvosGenesisEgg.
   - `reveal` deposited EvosGenesisEgg into an Evos.
   - Admin functionalities for species addition (`add_specie`).
   - Experience and gems management (add/subtract).
   - Utility functions for managing Evos attributes.
   **Dependencies**: std, sui, nft_protocol, ob_pseudorandom, ob_utils, ob_permissions, ob_request, ob_kiosk, liquidity_layer_v1, knw_genesis.

### 2. Module: `knw_evos::history`
   **Purpose**: Tracks the history and changes in the state of EVOS.
   **Key Functions**:
   - `create_history` to initialize an EvosHistory object.
   - Functions to `push` and `pop` state and box openings.
   - Function to check if a box has been opened (`box_already_open`).
   - Retrieval of all opened boxes (`opened_boxes`).
   **Dependencies**: std, sui, knw_evos.

### 3. Module: `knw_evos::settings`
   **Purpose**: Manages game settings, including stages and resources like XP and gems.
   **Key Functions**:
   - Creation of `GameSettings` and `GemsMine`.
   - Stage configuration functions like `create_stage`.
   - Management of XP and gem parameters.
   **Dependencies**: std.

### 4. Module: `knw_evos::traits`
   **Purpose**: Manages traits and trait boxes within the game.
   **Key Functions**:
   - Creation of `TraitSettings`, `TraitBox`, and `Trait`.
   - Functions for creating and confirming `BoxReceipts`.
   - Retrieval of a `TraitBox` by box index.
   - Retrieval of all `TraitBox` for a given `Stage` name.
   **Dependencies**: std, sui, ob_pseudorandom.

### 5. Module: `knw_evos::utils`
   **Purpose**: Provides utility functions, primarily for randomness.
   **Key Functions**:
   - `select` for random number generation in a range.
   - Test functions for creating a clock.
   **Dependencies**: None explicitly mentioned, but likely relies on ob_pseudorandom for random number generation.

## Module Interrelations
- `knw_evos::evos` is the core module, interacting with nearly all other modules. It uses `knw_evos::settings` for game settings, `knw_evos::history` for tracking state changes, and `knw_evos::traits` for managing EVOS traits.
- `knw_evos::history` links closely with `knw_evos::evos`, providing historical data for the main game entities.
- `knw_evos::settings` and `knw_evos::traits` are auxiliary modules, providing configuration and feature sets that the `knw_evos::evos` module utilizes.
- `knw_evos::utils` offers support functionalities, like randomness, used across other modules, especially in `knw_evos::traits`.

## General Information
- **Game Dynamics**: The modules collectively handle complex game mechanics, including NFT management, dynamic attribute changes, and resource allocation.
- **User and Admin Roles**: Differentiated roles are evident, with specific functionalities gated for admin use, ensuring proper game management and fairness.
- **Scalability and Modularity**: The game's architecture is designed for scalability and modularity, allowing for future expansions and updates.
- **Fairness and Engagement**: The implementation of randomness and diverse traits enhances the fairness and engagement level of the game.
- **Testing and Reliability**: The presence of test functionalities highlights the importance of reliability and integrity in the game's development.
