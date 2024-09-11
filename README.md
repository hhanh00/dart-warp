## Dart - Zcash Warp Bindings

1. Build the zcash-warp crate 
1. Generate the binding.h header file: `cbindgen`
1. Generate the Dart bindings: `dart run ffigen`
1. Copy the dylib to this folder
1. Copy the config and database files
1. Run: `dart run`
