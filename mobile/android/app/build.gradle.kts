plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun resolveAmapKey(): String {
    return (project.findProperty("AMAP_ANDROID_KEY") as String?)
        ?: System.getenv("AMAP_ANDROID_KEY")
        ?: localProperties.getProperty("AMAP_ANDROID_KEY")
        ?: "55f733fae7a326ac12009b17dde876a4"
}

android {
    namespace = "com.laoleme.smartcare.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.laoleme.smartcare.mobile"
        manifestPlaceholders["AMAP_ANDROID_KEY"] = resolveAmapKey()
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
