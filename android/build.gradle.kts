import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        google()
        mavenCentral()
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

// Some Flutter plugins still publish JVM 8 metadata or compile Java sources
// that use unchecked/deprecated Android APIs. Keep app warnings visible while
// silencing these upstream-only javac notes for dependency modules.
subprojects {
    if (name != "app") {
        tasks.withType<JavaCompile>().configureEach {
            options.isWarnings = false
            options.compilerArgs.add("-XDsuppressNotes")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
