plugins {
    `java-library`
}

group = "com.natsu.jefag"
version = "1.0-SNAPSHOT"

dependencies {
    api(project(":common:common-model"))
    
    // Apache Commons for utilities (versions managed by BOM)
    api("org.apache.commons:commons-lang3")
    api("org.apache.commons:commons-collections4")
    api("commons-io:commons-io")
    
    // Guava for additional utilities
    api("com.google.guava:guava")
    
    // Logging
    api("org.slf4j:slf4j-api")
    
    // Configuration parsing libraries
    // YAML support
    api("org.yaml:snakeyaml:2.2")
    
    // JSON support (Jackson)
    api("com.fasterxml.jackson.core:jackson-databind")
    api("com.fasterxml.jackson.core:jackson-core")
    api("com.fasterxml.jackson.datatype:jackson-datatype-jsr310")
    
    // TOML support
    api("com.moandjiezana.toml:toml4j:0.7.2")
    
    // Lombok
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.mockito:mockito-core")
}

tasks.test {
    useJUnitPlatform()
}
