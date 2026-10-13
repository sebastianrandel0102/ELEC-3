allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some Flutter plugins declare older AGP versions (flutter_timezone uses 7.3.0).
// Use the app's tooling so their classpaths cannot introduce an old SDK XML parser.
val androidGradlePluginVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
subprojects {
    buildscript.configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                useVersion(androidGradlePluginVersion)
                because("Flutter plugins must use the application's Android SDK tooling")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
