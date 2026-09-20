allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Flutter's expected project build/ output, but plugin intermediates under
// LOCALAPPDATA avoid OneDrive/Music file locking that breaks Gradle 9 packaging.
val flutterBuildDir: Directory =
    rootProject.layout.projectDirectory
        .dir("../build")
val localPluginBuildRoot =
    file("${System.getenv("LOCALAPPDATA")}/DrapeGradleBuild")

rootProject.layout.buildDirectory.value(flutterBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = flutterBuildDir.dir(project.name)
    // App module stays in project build/ so Flutter finds the AAB.
    // Plugin modules build under LOCALAPPDATA to avoid OneDrive races.
    if (project.name == "app") {
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    } else {
        project.layout.buildDirectory.set(File(localPluginBuildRoot, project.name))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    tasks.configureEach {
        if (name == "packageReleaseResources" || name == "packageDebugResources") {
            outputs.upToDateWhen { false }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(localPluginBuildRoot)
}
