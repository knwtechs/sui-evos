COLLECTION_PUBLISHER=0xc23a89d471fb61ca705b1c3b33de4d7e9a4212933592bdd224d73ba3fc85a127
TYPE=0xcca18faec0dbe4b35ffc8e95308aa008c7b3eba38c2a9ddedf861b96cbc74ee2::evosgenesisegg::EvosGenesisEgg
ALLOWLIST=0xb9353bccfb7ad87b9195c6956b2ac81551350b104d5bfec9cf0ea6f5c467c6d1
GAS_BUDGET=100000000

sui client call \
    --gas-budget $GAS_BUDGET \
    --package 0x70e34fcd390b767edbddaf7573450528698188c84c5395af8c4b12e3e37622fa \
    --module "allowlist" \
    --function "insert_collection" \
    --type-args $TYPE \
    --args $ALLOWLIST $COLLECTION_PUBLISHER