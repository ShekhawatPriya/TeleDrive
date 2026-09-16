import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from android/key.properties when present (used by CI
// and for production builds). Release validation below requires this identity.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.flutter_m_fsdk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Kept stable for compatibility with already published sideloaded
        // releases. Changing this ID would break in-place updates.
        applicationId = "com.example.flutter_m_fsdk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(31, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            ndk {
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }
        release {
            // Sign with the dedicated release key when key.properties is present
            // (CI / production). The validation task rejects a missing release identity.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            ndk {
                abiFilters.clear()
                abiFilters += "arm64-v8a"
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// A release must never silently ship with a debug identity or private client assets.
val validateReleaseConfiguration = tasks.register("validateReleaseConfiguration") {
    doLast {
        check(hasReleaseSigning) { "Release signing requires android/key.properties. Use a debug build for local development." }
        val configFile = rootProject.file("../.env.local")
        check(configFile.exists()) { "Release client configuration is missing." }
        val forbidden = setOf("GITHUB_TOKEN", "JWT_SECRET", "DATABASE_URL", "TELEGRAM_SESSION_ENCRYPTION_KEY")
        val invalid = configFile.readLines().mapNotNull { line ->
            val parts = line.trim().removePrefix("export ").split("=", limit = 2)
            if (parts.size != 2 || parts[0].trim() !in forbidden) null
            else parts[1].substringBefore("#").trim().trim('\"', '\'').takeIf { it.isNotEmpty() }?.let { parts[0].trim() }
        }
        check(invalid.isEmpty()) { "Private/server credential keys cannot be bundled in a release: ${invalid.joinToString()}" }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateReleaseConfiguration)
}
