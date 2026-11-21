plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.recitro.recitro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.recitro.recitro"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

val recitroRoot = rootProject.projectDir.parentFile!!
val ensureEmulatorScript = recitroRoot.resolve("scripts/ensure-pixel8-ready.ps1")

// Flutter passes -Ptarget-platform (e.g. android-arm64 for a real phone, android-x64 for the
// emulator). The Pixel 8 emulator check only applies to emulator builds; real phones skip it.
val recitroTargetPlatform = (project.findProperty("target-platform") as String?).orEmpty()
val recitroTargetsEmulator =
    recitroTargetPlatform.isEmpty() ||
        recitroTargetPlatform.contains("android-x64") ||
        recitroTargetPlatform.contains("android-x86")
val recitroTargetAbi =
    when {
        recitroTargetPlatform.contains("android-arm64") -> "arm64-v8a"
        recitroTargetPlatform.contains("android-arm") -> "armeabi-v7a"
        else -> "x86_64"
    }

fun runRecitroEnsureEmulator(phase: String) {
    if (!ensureEmulatorScript.isFile) return
    if (System.getenv("CI") != null) return
    if (!org.gradle.internal.os.OperatingSystem.current().isWindows) return
    if (!recitroTargetsEmulator) return
    logger.lifecycle("Recitro: $phase — wait for emulator-5554 Package Manager…")
    val process =
        ProcessBuilder(
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                ensureEmulatorScript.absolutePath,
                "-DeviceId",
                "emulator-5554",
                "-TimeoutMinutes",
                "8",
            )
            .directory(recitroRoot)
            .inheritIO()
            .start()
    val code = process.waitFor()
    if (code != 0) {
        throw org.gradle.api.GradleException(
            "Recitro: emulator not ready for adb install (exit $code). " +
                "Run: .\\scripts\\stop-all-emulators.ps1 then .\\scripts\\start-pixel8-emulator.ps1 -Wait"
        )
    }
}

// Windows-only: wait for emulator Package Manager before adb install (skipped on CI / Linux).
if (org.gradle.internal.os.OperatingSystem.current().isWindows) {
    tasks.register("recitroEnsureEmulatorInstallable") {
        outputs.upToDateWhen { false }
        doLast { runRecitroEnsureEmulator("before adb install") }
    }

    afterEvaluate {
        tasks.named("assembleDebug").configure {
            finalizedBy("recitroEnsureEmulatorInstallable")
            doFirst { runRecitroEnsureEmulator("before debug assemble") }
            doLast {
                val apkDir = recitroRoot.resolve("build/app/outputs/flutter-apk")
                val split = apkDir.resolve("app-$recitroTargetAbi-debug.apk")
                val installApk = apkDir.resolve("app-debug.apk")
                if (split.isFile) {
                    split.copyTo(installApk, overwrite = true)
                    logger.lifecycle(
                        "Recitro: using ${split.name} for Flutter install (${installApk.length() / 1024 / 1024} MB)"
                    )
                }
            }
        }
    }
}
