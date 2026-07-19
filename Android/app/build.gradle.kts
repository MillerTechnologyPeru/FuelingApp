import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.fromTarget(libs.versions.jvm.get()))
    }
}

// The fueling API's base URL, injected at build time from an environment
// variable rather than hardcoded — mirrors `ServerURL.fromEnvironment(_:default:)`
// on the Swift side, since an installed app has no shell environment of its
// own to read from at runtime. Override with `-PfuelingServerUrl=...` for a
// one-off build. Defaults to localhost; on the Android emulator (not a real
// device), the host machine's localhost is reachable at `10.0.2.2`, not
// `localhost` — override accordingly when running a local dev server there.
val fuelingServerUrl: String = (findProperty("fuelingServerUrl") as String?)
    ?: System.getenv("FUELING_SERVER_URL")
    ?: "http://localhost:8080"

android {
    namespace = "com.fuelingapp"
    compileSdk = libs.versions.androidSdkCompile.get().toInt()

    defaultConfig {
        applicationId = "com.fuelingapp"
        minSdk = libs.versions.androidSdkMin.get().toInt()
        targetSdk = libs.versions.androidSdkCompile.get().toInt()
        versionCode = 1
        versionName = "0.0.1"
        ndk {
            abiFilters += "arm64-v8a"
        }
        buildConfigField("String", "FUELING_SERVER_URL", "\"$fuelingServerUrl\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.toVersion(libs.versions.jvm.get())
        targetCompatibility = JavaVersion.toVersion(libs.versions.jvm.get())
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols.add("**/*.so")
        }
    }

    // default signing configuration tries to load from keystore.properties
    signingConfigs {
        val keystorePropertiesFile = file("keystore.properties")
        if (keystorePropertiesFile.isFile) {
            create("release") {
                val keystoreProperties = Properties()
                keystoreProperties.load(keystorePropertiesFile.inputStream())
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    // The swift-java (JNI) bindings + native libraries, packaged as a
    // standalone Android library module (see Android/fueling-jni).
    implementation(project(":fueling-jni"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
}
