plugins {
    id("org.springframework.boot") version "3.2.0"
    id("io.spring.dependency-management") version "1.1.4"
    java
}

group = "com.natsu"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    // Use common Spring Boot template with all standard dependencies
    implementation(project(":common:common-spring-boot"))
    implementation(project(":common:common-security"))
    implementation(project(":common:common-messaging"))
    
    // Auth-specific dependencies (versions managed by BOM)
    implementation("org.springframework.security:spring-security-oauth2-jose")
    implementation("org.springframework.session:spring-session-data-redis")
    
    // Testing
    testImplementation("org.springframework.kafka:spring-kafka-test")
}

tasks.test {
    useJUnitPlatform()
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("${project.name}.jar")
}


