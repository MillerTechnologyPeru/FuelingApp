// Fueling Android app — plain Gradle project that consumes Swift via
// swift-java (jextract, JNI mode).
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Fueling"
include(":app")
include(":fueling-jni")
