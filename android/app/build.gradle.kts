plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // 👈 Firebase için gerekli
}

android {
    namespace = "com.example.lojistik"
    compileSdk = 36 // 👈 Sabit değer kullan (flutter.compileSdkVersion yerine)
    ndkVersion = "27.0.12077973" // Bu satırı ekle

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.lojistik"
        minSdk = flutter.minSdkVersion // 👈 Cloud Functions için minimum 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true // 👈 ÇOK ÖNEMLİ! Firebase için gerekli
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}
configurations.all {
    resolutionStrategy {
        force("androidx.core:core-ktx:1.12.0")
        force("androidx.core:core:1.12.0")
        force("androidx.activity:activity:1.8.2")
        force("androidx.browser:browser:1.7.0")
    }
}


dependencies {
    // Firebase BoM (Bill of Materials) - Tüm Firebase sürümlerini yönetir
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))

    // Firebase bağımlılıkları (BoM'dan sürüm alır)
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-storage")

    // MultiDex desteği (Firebase için gerekli)
    implementation("androidx.multidex:multidex:2.0.1")

    // AndroidX temel bağımlılıklar
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
