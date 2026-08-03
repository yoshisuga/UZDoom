message(STATUS "Creating GenZD (iOS) target configuration for zdoom")

message(STATUS "CMAKE_SOURCE_DIR: ${CMAKE_SOURCE_DIR}")

set(SDL2_FOUND TRUE)
set(SDL2_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/bin/iOS/sdl/include")
set(SDL2_LIBRARY "${CMAKE_SOURCE_DIR}/bin/iOS/sdl/libSDL2.a")
include_directories(SYSTEM "${SDL2_INCLUDE_DIR}")
# The prebuilt iOS SDL headers are flat, but upstream includes them as <SDL2/SDL.h>.
# bin/iOS/sdl/SDL2 is a symlink to include/, so adding its parent makes both forms resolve
# and lets us take upstream's include lines verbatim.
include_directories(SYSTEM "${CMAKE_SOURCE_DIR}/bin/iOS/sdl")
message(STATUS "✓ SDL2 configured for iOS")


# Debug output
message(STATUS "iOS SDL2_INCLUDE_DIR: ${SDL2_INCLUDE_DIR}")
message(STATUS "iOS SDL2_LIBRARY: ${SDL2_LIBRARY}")

set(IOS_FRAMEWORKS_TO_EMBED
    "${CMAKE_SOURCE_DIR}/bin/iOS/MoltenVK.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/openal.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/SharpYuv.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/VPX.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/WebP.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/WebPDecoder.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/WebPDemux.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/WebPMux.framework"
    "${CMAKE_SOURCE_DIR}/bin/iOS/ZIPFoundation.framework"
)
# Note: zmusic/zmusiclite are now built from source, not embedded as frameworks

set_target_properties(zdoom PROPERTIES
  OUTPUT_NAME "GenZD"
  XCODE_ATTRIBUTE_SDKROOT "iphoneos"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.yoshisuga.genZD"
  XCODE_ATTRIBUTE_PRODUCT_NAME "GenZD"
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
  XCODE_ATTRIBUTE_DEAD_CODE_STRIPPING "NO"
  XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_SOURCE_DIR}/ios/zdoom-Bridging-Header.h"
  XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
  XCODE_ATTRIBUTE_INSTALL_PATH "/Applications"

  XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS "$(PROJECT_DIR)/bin/iOS"
  LINK_FLAGS "-rpath @executable_path/Frameworks/MoltenVK.framework -rpath @executable_path/Frameworks"

  XCODE_EMBED_FRAMEWORKS "${IOS_FRAMEWORKS_TO_EMBED}"
  XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY TRUE
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/genzd-template-info.plist"

  XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon18"
  # Space-separated, NOT semicolon-separated: Xcode parses this as a string list. A ";"
  # joined value reaches actool as one bogus icon name, so no alternates get compiled and
  # no CFBundleAlternateIcons is emitted - which makes UIApplication.supportsAlternateIcons
  # false and setAlternateIconName() silently do nothing.
  XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES "AppIcon AppIconZero AppIconGold2 AppIconGold1"
)

set( CMAKE_EXE_LINKER_FLAGS "" )

target_link_libraries(zdoom
  "-framework AudioToolbox"
  "-framework AVFoundation"
  "-framework CoreAudio"
  "-framework CoreGraphics"
  "-framework CoreHaptics"
  "-framework CoreMIDI"
  "-framework CoreMotion"
  "-framework Foundation"
  "-framework GameController"
  "-framework IOSurface"
  "${CMAKE_SOURCE_DIR}/bin/iOS/sdl/libSDL2.a"
  "-framework MobileCoreServices"

  # ZMusic is built from source, link external FluidSynth
  "${CMAKE_SOURCE_DIR}/bin/iOS/libfluidsynth.a"

  # Audio decoding libraries for ZMusic (libsndfile and its dependencies)
  "${CMAKE_SOURCE_DIR}/bin/iOS/libsndfile.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libvorbis.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libvorbisenc.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libvorbisfile.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libogg.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libFLAC.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libmpg123.a"

  # libsndfile.a was built with MPEG (LAME) and Opus support, so it references lame_*/
  # id3tag_* and opus_* symbols. These only surface once libsndfile is actually linked -
  # i.e. once ZMusic stops dlopen'ing it (see the iOS branch in
  # libraries/ZMusic/source/CMakeLists.txt). Must come after libsndfile.a.
  "${CMAKE_SOURCE_DIR}/bin/iOS/liblame.a"
  "${CMAKE_SOURCE_DIR}/bin/iOS/libopus.a"

  "${CMAKE_SOURCE_DIR}/bin/iOS/VPX.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/WebP.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/WebPDecoder.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/WebPDemux.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/WebPMux.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/SharpYuv.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/MoltenVK.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/openal.framework"
  "${CMAKE_SOURCE_DIR}/bin/iOS/ZIPFoundation.framework"
)

# Remove rt library for iOS (clock_gettime is in libc on iOS/macOS)
if(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    list(REMOVE_ITEM PROJECT_LIBRARIES rt)
    message(STATUS "Removed rt library for iOS build")
endif()

set(DYN_OPENAL OFF CACHE BOOL "Disable dynamic OpenAL loading for iOS" FORCE)

function(add_ios_sources target_name ios_source_dir)
    if(NOT EXISTS "${ios_source_dir}")
        message(STATUS "iOS source directory does not exist: ${ios_source_dir}")
        return()
    endif()
    
    message(STATUS "Adding iOS sources from: ${ios_source_dir}")
    
    # Enable Swift if not already enabled
    enable_language(Swift OPTIONAL)
    
    # Find all source files recursively
    file(GLOB_RECURSE IOS_SOURCE_FILES 
        "${ios_source_dir}/*.swift"
        "${ios_source_dir}/*.m"
        "${ios_source_dir}/*.mm"
        "${ios_source_dir}/*.cpp"
        "${ios_source_dir}/*.c"
        "${ios_source_dir}/*.h"
    )

    if(NOT target_name STREQUAL "genzd-zero")
        message(STATUS "Excluding free-version-only files for target: ${target_name}")
        list(FILTER IOS_SOURCE_FILES EXCLUDE REGEX ".*UpgradeView\\.swift$")
        list(FILTER IOS_SOURCE_FILES EXCLUDE REGEX ".*PurchaseViewModel\\.swift$")
    else()
        message(STATUS "Including all files for free version target: ${target_name}")
    endif()
    
    # Find all resource files recursively
    file(GLOB_RECURSE IOS_RESOURCE_FILES
        "${ios_source_dir}/*.md"
        "${ios_source_dir}/*.storyboard"
        "${ios_source_dir}/*.ttf"
    )

    # Add .xcassets directories explicitly
    file(GLOB XCASSETS_DIRS "${ios_source_dir}/*.xcassets")
    list(APPEND IOS_RESOURCE_FILES ${XCASSETS_DIRS})

    # exclude tvOS for now
    list(FILTER IOS_RESOURCE_FILES EXCLUDE REGEX ".*tvOS\\.storyboard$")
    
    # Add source files to target
    if(IOS_SOURCE_FILES)
        target_sources(${target_name} PRIVATE ${IOS_SOURCE_FILES})
        
        # Set special properties for different file types
        foreach(source_file ${IOS_SOURCE_FILES})
            if(source_file MATCHES "\\.mm$")
                # Objective-C++ files might need special flags
                set_source_files_properties("${source_file}"
                    PROPERTIES COMPILE_FLAGS "-fobjc-arc")
            elseif(source_file MATCHES "\\.m$")
                # Objective-C files
                set_source_files_properties("${source_file}"
                    PROPERTIES COMPILE_FLAGS "-fobjc-arc")
            endif()
        endforeach()
    endif()
    
    # Add resource files with proper properties for iOS bundles
    if(IOS_RESOURCE_FILES)
        target_sources(${target_name} PRIVATE ${IOS_RESOURCE_FILES})
        set_source_files_properties(${IOS_RESOURCE_FILES}
            PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    endif()
    
    # Create hierarchical source groups that preserve exact folder structure
    foreach(source_file ${IOS_SOURCE_FILES})
        get_filename_component(file_dir ${source_file} DIRECTORY)
        file(RELATIVE_PATH rel_dir "${ios_source_dir}" ${file_dir})
        
        if(rel_dir STREQUAL "")
            # File is in root iOS directory
            source_group("iOS Sources" FILES ${source_file})
        else()
            # File is in subdirectory - preserve the exact path
            string(REPLACE "/" "\\" rel_dir_win ${rel_dir})
            source_group("iOS Sources\\${rel_dir_win}" FILES ${source_file})
        endif()
    endforeach()
    
    # Create separate resource groups
    # foreach(resource_file ${IOS_RESOURCE_FILES})
    #     get_filename_component(file_dir ${resource_file} DIRECTORY)
    #     file(RELATIVE_PATH rel_dir "${ios_source_dir}" ${file_dir})
        
    #     if(rel_dir STREQUAL "")
    #         # Resource is in root iOS directory
    #         source_group("iOS Resources" FILES ${resource_file})
    #     else()
    #         # Resource is in subdirectory
    #         string(REPLACE "/" "\\" rel_dir_win ${rel_dir})
    #         source_group("iOS Resources\\${rel_dir_win}" FILES ${resource_file})
    #     endif()
    # endforeach()
    
    # Set up Swift bridging header if it exists
    set(BRIDGING_HEADER "${ios_source_dir}/zdoom-Bridging-Header.h")
    if(EXISTS "${BRIDGING_HEADER}")
        set_target_properties(${target_name} PROPERTIES
            XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${BRIDGING_HEADER}")
    endif()
    
    set_target_properties(${target_name} PROPERTIES
        XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
        # XCODE_ATTRIBUTE_SWIFT_OBJC_INTERFACE_HEADER_NAME "${target_name}-Swift.h"
    )
    
    # Report what was added
    list(LENGTH IOS_SOURCE_FILES source_count)
    list(LENGTH IOS_RESOURCE_FILES resource_count)
    message(STATUS "✓ iOS: ${source_count} source files, ${resource_count} resources")
    
endfunction()

add_ios_sources(zdoom "${CMAKE_SOURCE_DIR}/src/ios")

# --------------------------------------------------------------------------------------
# Stage game data into the real iOS app bundle.
#
# add_pk3()'s copy step and the soundfont/fm_bank POST_BUILD in src/CMakeLists.txt both
# target ZDOOM_RESOURCE_DIR, which on Apple resolves to
# "${PROJECT_BINARY_DIR}/${ZDOOM_EXE_NAME}.app/Contents/Resources" - a macOS layout using
# the wrong app name ("uzdoom" vs OUTPUT_NAME "GenZD") and ignoring Xcode's per-config
# output directory. On iOS that is a stray directory that never ships; bundles are flat,
# so the engine looks for BASEWAD next to the executable at the .app root.
#
# This must be POST_BUILD on zdoom itself. A separate copy target referencing
# $<TARGET_BUNDLE_DIR:zdoom> makes that target depend on zdoom, while zdoom already
# depends on the pk3 copy targets - CMake then fails with an inter-target dependency
# cycle. POST_BUILD also guarantees the bundle exists before anything is copied into it.
set(GENZD_PK3S
    uzdoom.pk3
    brightmaps.pk3
    lights.pk3
    game_support.pk3
    game_widescreen_gfx.pk3
)

foreach(pk3 IN LISTS GENZD_PK3S)
    add_custom_command(TARGET zdoom POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${ZDOOM_OUTPUT_DIR}/${pk3}"
            "$<TARGET_BUNDLE_DIR:zdoom>/${pk3}"
        COMMENT "GenZD: staging ${pk3} into the app bundle"
        VERBATIM
    )
endforeach()

add_custom_command(TARGET zdoom POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:zdoom>/soundfonts"
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:zdoom>/fm_banks"

    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/soundfont/uzdoom.sf2"
        "$<TARGET_BUNDLE_DIR:zdoom>/soundfonts/uzdoom.sf2"

    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/fm_banks/GENMIDI.GS.wopl"
        "$<TARGET_BUNDLE_DIR:zdoom>/fm_banks/GENMIDI.GS.wopl"

    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/fm_banks/gs-by-papiezak-and-sneakernets.wopn"
        "$<TARGET_BUNDLE_DIR:zdoom>/fm_banks/gs-by-papiezak-and-sneakernets.wopn"

    COMMENT "GenZD: staging soundfonts and fm_banks into the app bundle"
    VERBATIM
)

message(STATUS "GenZD target configuration complete")
