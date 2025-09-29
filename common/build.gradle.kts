plugins {
    `java-library`
}

group = "com.natsu.jefag"
version = "1.0-SNAPSHOT"

// This is just a parent module for common submodules
// No dependencies here to avoid circular dependencies
dependencies {
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

tasks.test {
    useJUnitPlatform()
}
