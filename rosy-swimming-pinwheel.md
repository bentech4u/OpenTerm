# FreeRDP Dylib RPATH Fix

Summary:
- The app crashed at runtime because FreeRDP dylibs referenced each other by bare names (e.g. `libfreerdp3.3.dylib`) instead of `@rpath/...`.
- The EmbedFreeRDP build phase now rewrites install names for all FreeRDP dylibs and also updates their internal cross-references to `@rpath`.
- The app binaries are also updated to load the FreeRDP dylibs via `@rpath`.

Files touched:
- `OpenTerm.xcodeproj/project.pbxproj`

Expected result:
- Running the app should no longer fail with dyld “Library not loaded” errors for FreeRDP libraries.
