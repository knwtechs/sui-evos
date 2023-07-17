COLLECTION_PUBLISHER=0xa8177796bc4b06e084328e943541a393895ec47e988ed51e68278c665c61f6b4
TYPE=0x169664f0f62bec3d59bb621d84df69927b3377a1f32ff16c862d28c158480065::evos::Evos
ALLOWLIST=0xb9353bccfb7ad87b9195c6956b2ac81551350b104d5bfec9cf0ea6f5c467c6d1
GAS_BUDGET=100000000

sui client call \
    --gas-budget $GAS_BUDGET \
    --package 0x70e34fcd390b767edbddaf7573450528698188c84c5395af8c4b12e3e37622fa \
    --module "allowlist" \
    --function "insert_collection" \
    --type-args $TYPE \
    --args $ALLOWLIST $COLLECTION_PUBLISHER