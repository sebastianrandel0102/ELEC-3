// Temporary Android-only fixes for these published FlutterFire versions.
// Stage local copies so neither the shared Pub cache nor Flutter SDK is changed.
val flutterFireSettings = settings
val pluginVersions = mapOf(
    "firebase_core" to "4.15.0",
    "firebase_auth" to "6.7.0",
    "firebase_storage" to "13.6.0",
    "cloud_firestore" to "6.10.0",
)

fun writeIfChanged(destination: File, bytes: ByteArray) {
    if (!destination.isFile || !destination.readBytes().contentEquals(bytes)) {
        destination.parentFile.mkdirs()
        destination.writeBytes(bytes)
    }
}

fun migrateKotlin(script: String): String {
    val legacyKotlin = Regex(
        """(?ms)^// AGP 9\+ has built-in Kotlin support.*?^if \([^\n]+\) \{\n    apply plugin: 'kotlin-android'\n\}\n""",
    )
    val legacyCompilerOptions = Regex(
        """(?ms)^plugins\.withId\("org\.jetbrains\.kotlin\.android"\) \{.*?^\}\n""",
    )
    check(legacyKotlin.findAll(script).count() == 1 &&
        legacyCompilerOptions.findAll(script).count() == 1) {
        "FlutterFire build script changed; review flutterfire-compat.settings.gradle.kts."
    }
    return legacyCompilerOptions.replace(legacyKotlin.replace(script, ""), """
        kotlin {
            compilerOptions {
                jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(project.ext.javaVersion.toString())
            }
        }

    """.trimIndent() + "\n")
}

pluginVersions.forEach { (pluginName, version) ->
    val descriptor = flutterFireSettings.findProject(":$pluginName") ?: return@forEach
    val originalAndroid = descriptor.projectDir
    val originalPackage = originalAndroid.parentFile
    val pubspec = File(originalPackage, "pubspec.yaml")
    // An upgraded package uses its own build without these version-specific patches.
    if (!pubspec.isFile || !Regex("(?m)^version: *['\"]?${Regex.escape(version)}['\"]? *$")
            .containsMatchIn(pubspec.readText().replace("\r\n", "\n"))) return@forEach

    val stagedPackage = File(flutterFireSettings.settingsDir, ".gradle/flutterfire-compat/$pluginName-$version")
    val stagedAndroid = File(stagedPackage, "android")
    writeIfChanged(File(stagedPackage, "pubspec.yaml"), pubspec.readBytes())

    originalAndroid.walkTopDown()
        .onEnter { it == originalAndroid || it.name !in setOf("build", ".gradle", ".kotlin") }
        .filter { it.isFile }
        .forEach { source ->
            val relativePath = source.relativeTo(originalAndroid).invariantSeparatorsPath
            val destination = File(stagedAndroid, relativePath)
            val bytes = when {
                relativePath == "build.gradle" && pluginName != "cloud_firestore" ->
                    migrateKotlin(source.readText().replace("\r\n", "\n")).toByteArray(Charsets.UTF_8)
                pluginName == "cloud_firestore" && relativePath.endsWith("/PipelineStageHandlers.java") -> {
                    // Channel messages use generic maps; the upstream parser already uses
                    // this annotation on several methods but omits it on other helpers.
                    val original = source.readText()
                    val declaration = "class PipelineStageHandlers {"
                    check(original.contains(declaration)) { "Firestore pipeline parser changed." }
                    original.replace(declaration, "@SuppressWarnings(\"unchecked\")\n$declaration")
                        .toByteArray(Charsets.UTF_8)
                }
                else -> source.readBytes()
            }
            writeIfChanged(destination, bytes)
        }
    descriptor.projectDir = stagedAndroid
}
