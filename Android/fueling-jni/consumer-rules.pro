# swift-java uses JNI + reflection; keep the generated bindings and the SwiftKit
# runtime so R8 does not strip types referenced from native code. Automatically
# applied to any app that depends on this library (AGP consumer proguard files).
-keep class com.fuelingapp.jni.** { *; }
-keep interface com.fuelingapp.jni.** { *; }
-keep class org.swift.swiftkit.** { *; }
-keep interface org.swift.swiftkit.** { *; }
