import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use { releaseSigningProperties.load(it) }
}
val releaseStorePath = releaseSigningProperties.getProperty("storeFile")
val hasReleaseSigning = !releaseStorePath.isNullOrBlank() &&
    !releaseSigningProperties.getProperty("storePassword").isNullOrBlank() &&
    !releaseSigningProperties.getProperty("keyAlias").isNullOrBlank() &&
    !releaseSigningProperties.getProperty("keyPassword").isNullOrBlank()

android {
    namespace = "com.example.signbridge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = rootProject.file(releaseStorePath!!)
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable package identity for the first team distribution release.
        applicationId = "com.umarmubiru.signbridge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    androidResources {
        noCompress += "task"
    }

    buildTypes {
        release {
            // Release signing is configured only from the ignored key.properties
            // file. Without it Gradle can produce an unsigned release APK, but
            // never silently signs a release with the debug key.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

dependencies {
    implementation("com.google.mediapipe:tasks-vision:1.0.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
