plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // Flutter Gradle plugin po android/kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.moto_manager_mobile"
    compileSdk = 35               // lub flutter.compileSdkVersion, jeśli działa
    ndkVersion = "27.0.12077973"  // <-- wymuszona wersja NDK dla firebase_auth itp

    defaultConfig {
        applicationId = "com.example.moto_manager_mobile"
        minSdk = 23               // <-- MINIMUM DLA FIREBASE_AUTH (21 nie zadziała!)
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        getByName("release") {
            // Tymczasowe podpisywanie debugowe, aby `flutter run --release` działał bez klucza prod
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
