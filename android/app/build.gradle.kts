import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = rootProject.file("key.properties")
if (releaseKeyPropertiesFile.isFile) {
    releaseKeyPropertiesFile.inputStream().use(releaseKeyProperties::load)
}
val releaseKeystoreFile = releaseKeyProperties.getProperty("storeFile")
    ?.let(rootProject::file)

val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        check(releaseKeyPropertiesFile.isFile) {
            "Create android/key.properties and an Android release keystore before building a release APK."
        }
        val requiredProperties = listOf(
            "storePassword",
            "keyPassword",
            "keyAlias",
        )
        val missingProperties = requiredProperties.filter {
            releaseKeyProperties.getProperty(it).isNullOrBlank()
        }
        check(missingProperties.isEmpty()) {
            "Missing Android release signing properties: ${missingProperties.joinToString()}."
        }
        check(releaseKeystoreFile?.isFile == true) {
            "The Android release keystore configured in android/key.properties was not found."
        }
    }
}

tasks.configureEach {
    if (name in setOf("assembleRelease", "bundleRelease")) {
        dependsOn(verifyReleaseSigning)
    }
}

android {
    namespace = "ug.co.glonlure.glonlure_platform"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyProperties.getProperty("keyAlias")
            keyPassword = releaseKeyProperties.getProperty("keyPassword")
            storeFile = releaseKeystoreFile
            storePassword = releaseKeyProperties.getProperty("storePassword")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ug.co.glonlure.glonlure_platform"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
