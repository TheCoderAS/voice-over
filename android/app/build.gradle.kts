import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing configuration.
//
// By default every build — local and CI alike — is signed with the committed
// testing keystore at android/keystore/voiceover-testing.jks. Using one fixed
// key everywhere means every APK shares the same signature, so app updates
// install in place without an uninstall. This is a TESTING key, not the Play
// upload key; its password is intentionally non-secret.
//
// To sign with a real upload key later, set these environment variables (e.g.
// from CI secrets) and they take precedence over the testing key — no code
// change required:
//   VOICEOVER_STORE_FILE, VOICEOVER_STORE_PASSWORD,
//   VOICEOVER_KEY_ALIAS, VOICEOVER_KEY_PASSWORD
val signingProps = Properties().apply {
    setProperty("storeFile", "../keystore/voiceover-testing.jks")
    setProperty("storePassword", "voiceover")
    setProperty("keyAlias", "voiceover")
    setProperty("keyPassword", "voiceover")
    System.getenv("VOICEOVER_STORE_FILE")?.let { setProperty("storeFile", it) }
    System.getenv("VOICEOVER_STORE_PASSWORD")?.let { setProperty("storePassword", it) }
    System.getenv("VOICEOVER_KEY_ALIAS")?.let { setProperty("keyAlias", it) }
    System.getenv("VOICEOVER_KEY_PASSWORD")?.let { setProperty("keyPassword", it) }
}

android {
    namespace = "com.unisync.voiceover"
    // permission_handler_android requires compiling against SDK 37+. compileSdk
    // only affects which APIs are available at compile time; targetSdk/minSdk
    // below are unchanged, so runtime behavior and device support stay the same.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.unisync.voiceover"
        // Audio recording/effect plugins in this space generally require API 24+.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // storeFile is resolved relative to this module (android/app).
            storeFile = file(signingProps.getProperty("storeFile"))
            storePassword = signingProps.getProperty("storePassword")
            keyAlias = signingProps.getProperty("keyAlias")
            keyPassword = signingProps.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            // Fixed key so every release APK shares one signature and updates
            // install over previous builds. Swap in a real upload key via the
            // env vars above before publishing to Play.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
