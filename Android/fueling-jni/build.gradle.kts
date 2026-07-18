plugins {
    alias(libs.plugins.android.library)
}

// ---------------------------------------------------------------------------
// swift-java (jextract, JNI mode) integration
//
// The Swift wrapper target `FuelingAndroid` is cross-compiled to a native
// `.so` for Android; the `JExtractSwiftPlugin` emits the Java JNI bindings as a
// side effect of `swift build`. This reimplements, inline, what swift-java's
// monorepo `BuildLogic` does for its own samples (which an external app cannot
// reuse): run the Swift build, add the generated Java + SwiftKit runtime sources
// to the source set, and stage every required `.so` into `jniLibs`.
//
// Packaged as its own Android library module (rather than living in `:app`) so
// the JNI bindings + native libraries can be consumed as a standalone `.aar` by
// any Android app, not just this one.
// ---------------------------------------------------------------------------

// The Swift package root: FuelingAndroid lives in its own package at
// Android/Package.swift (a `path: ".."` dependency on the outer FuelingApp
// package), rather than as a target inside the outer package directly.
val swiftPackageRoot: File = rootProject.projectDir
val androidTriple = "aarch64-unknown-linux-android28"
val swiftAbi = "arm64-v8a"
val userHome: String = System.getProperty("user.home")

// Configuration the Swift wrapper is cross-compiled with. This is independent of
// the Android build type: an `assembleRelease` still gets a debug `.so` unless this
// is set too, so release builds (CI) must pass `-PswiftBuildConfig=release` to pick
// up the `-Osize -internalize-at-link` flags declared for `.android`/`.release`.
val swiftBuildConfig: String = (findProperty("swiftBuildConfig") as String?) ?: "debug"

// Locates both the toolchain and the matching Android SDK artifactbundle. Keep in
// sync with the toolchain used to build/test the rest of this repo.
val swiftToolchainVersion: String = (findProperty("swiftToolchainVersion") as String?) ?: "6.3.3"

// The Android SDK's prebuilt Swift modules require the matching swift.org
// toolchain (Apple's Xcode Swift produces incompatible `.swiftmodule`s).
// Override with `-PswiftBin=/path/to/swift` if installed elsewhere.
val swiftBin: String = (findProperty("swiftBin") as String?)
    ?: "$userHome/Library/Developer/Toolchains/swift-$swiftToolchainVersion-RELEASE.xctoolchain/usr/bin/swift"

// swift-java's `enableJavaCallbacks` feature would need its own JDK 25 sub-build;
// unused here (see Android/Sources/FuelingAndroid/swift-java.config), so no
// `jdk25Home` property is needed.

// The first path segment is the lowercased *directory name* of the Swift package
// (SwiftPM's `outputs/<dir>/<TargetName>/...` convention) — "android" here, since
// FuelingAndroid lives in its own package at Android/Package.swift, not the
// lowercased manifest `name:` field and not the outer repo's directory name.
val generatedJavaDir = File(swiftPackageRoot, ".build/plugins/outputs/android/FuelingAndroid/destination/JExtractSwiftPlugin/src/generated/java")
val swiftKitCoreDir = File(swiftPackageRoot, ".build/checkouts/swift-java/SwiftKitCore/src/main/java")
val swiftBuildDir = File(swiftPackageRoot, ".build/$androidTriple/$swiftBuildConfig")
val swiftAndroidRuntimeDir = File(
    (findProperty("swiftAndroidRuntimeDir") as String?)
        ?: "$userHome/Library/org.swift.swiftpm/swift-sdks/swift-${swiftToolchainVersion}-RELEASE_android.artifactbundle/swift-android/swift-resources/usr/lib/swift-aarch64/android"
)

// Supplies libc++_shared.so, which every Swift Android binary links against. CI
// agents export ANDROID_NDK_* and pin a different NDK patch version than a local
// Android Studio install, so prefer the environment over the hardcoded fallback.
val ndkRoot = File(
    (findProperty("ndkRoot") as String?)
        ?: System.getenv("ANDROID_NDK_HOME")
        ?: System.getenv("ANDROID_NDK_ROOT")
        ?: "$userHome/Library/Android/sdk/ndk/27.2.12479018"
)

// Cross-compile the Swift wrapper + generate the JNI Java bindings.
val jextract = tasks.register<Exec>("jextract") {
    workingDir = swiftPackageRoot
    environment("SWIFT_BUILD_DYNAMIC_LIBRARY", "1")
    commandLine(
        swiftBin, "build",
        "--swift-sdk", androidTriple,
        "--product", "FuelingAndroid",
        "-c", swiftBuildConfig,
        "--disable-sandbox",
        "--disable-experimental-prebuilts"
    )
    outputs.dir(generatedJavaDir)
    outputs.file(File(swiftBuildDir, "libFuelingAndroid.so"))
}

// Stage the cross-compiled library, the swift-java runtime, the Swift Android
// runtime and libc++_shared into this module's jniLibs so they end up in the .aar.
val stageJniLibs = tasks.register<Copy>("stageJniLibs") {
    dependsOn(jextract)
    into(layout.projectDirectory.dir("src/main/jniLibs/$swiftAbi"))
    from(swiftBuildDir) {
        // Every dynamic library product built by the package graph (this
        // module's own wrapper, swift-java's runtime, and any dynamic
        // dependency like CoreModel/CoreModelSQLite/SQLite) — anything less
        // leaves a dangling `dlopen` at runtime.
        include("*.so")
    }
    from(swiftAndroidRuntimeDir) {
        include("*.so")
        // Test-only runtime libraries are not needed by consumers.
        exclude("*Testing*", "libXCTest.so")
        // `FuelingModel`'s dependency on `FuelingAPI` (and its
        // `HTTPTypesFoundation`/`FoundationNetworking` transitive dependency) is
        // excluded from the Android build entirely (see the `nonAndroidPlatforms`
        // condition in the outer package manifest) — no network transport is
        // wired up on Android yet. So `libFoundationNetworking.so` and XML aren't
        // linked. Internationalization *is* linked (`Locale.measurementSystem` in
        // `LocationsViewModel`), so unlike a project that avoids it entirely,
        // `lib_FoundationICU.so`/`libFoundationInternationalization.so` are kept.
        exclude(
            "libFoundationNetworking.so",
            "libFoundationXML.so"
        )
    }
    from(File(ndkRoot, "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android")) {
        include("libc++_shared.so")
    }
}

android {
    namespace = "com.fuelingapp.jni"
    compileSdk = libs.versions.androidSdkCompile.get().toInt()

    defaultConfig {
        minSdk = libs.versions.androidSdkMin.get().toInt()
        ndk {
            abiFilters += swiftAbi
        }
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.toVersion(libs.versions.jvm.get())
        targetCompatibility = JavaVersion.toVersion(libs.versions.jvm.get())
    }

    // Generated JNI bindings + the SwiftKit Java runtime (consumed as source,
    // since swift-java is not published to Maven).
    sourceSets["main"].java.srcDir(generatedJavaDir)
    sourceSets["main"].java.srcDir(swiftKitCoreDir)
    // These two annotations pull in `jdk.jfr` (Java Flight Recorder), which is
    // unavailable on Android; the JNI bindings don't reference them.
    sourceSets["main"].java.filter.exclude(
        "org/swift/swiftkit/core/annotations/ThreadSafe.java",
        "org/swift/swiftkit/core/annotations/Unsigned.java"
    )

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols.add("**/*.so")
        }
    }
}

// Ensure Swift is built + bindings generated + libs staged before Java compiles.
tasks.withType<JavaCompile>().configureEach {
    dependsOn(jextract)
}
tasks.named("preBuild") {
    dependsOn(stageJniLibs)
}
