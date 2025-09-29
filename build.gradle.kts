plugins {
    java
    id("org.springframework.boot") version "3.2.0" apply false
    id("io.spring.dependency-management") version "1.1.4"
}

group = "com.natsu.jefag"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral {
        content {
            // Only resolve from Maven Central for faster resolution
            includeGroupByRegex(".*")
        }
    }
}

// Global dependency management for all subprojects
subprojects {
    repositories {
        mavenCentral {
            content {
                // Only resolve from Maven Central for faster resolution
                includeGroupByRegex(".*")
            }
        }
    }
    
    // Apply dependency management to all subprojects
    apply(plugin = "io.spring.dependency-management")
    
    dependencyManagement {
        imports {
            mavenBom("org.springframework.boot:spring-boot-dependencies:3.2.0")
            mavenBom("org.springframework.cloud:spring-cloud-dependencies:2023.0.0")
            mavenBom("software.amazon.awssdk:bom:2.21.29")
            mavenBom("org.testcontainers:testcontainers-bom:1.19.1")
        }
        
        // Define versions for dependencies not covered by BOMs
        dependencies {
            dependency("com.amazonaws:aws-lambda-java-core:1.2.3")
            dependency("com.amazonaws:aws-lambda-java-events:3.11.3")
            dependency("jakarta.inject:jakarta.inject-api:2.0.1")
            dependency("net.logstash.logback:logstash-logback-encoder:7.4")
            dependency("org.threeten:threeten-extra:1.7.2")
            dependency("commons-io:commons-io:2.11.0")
            dependency("com.google.guava:guava:32.1.3-jre")
            dependency("io.jsonwebtoken:jjwt-api:0.12.3")
            dependency("io.jsonwebtoken:jjwt-impl:0.12.3")
            dependency("io.jsonwebtoken:jjwt-jackson:0.12.3")
            dependency("com.opencsv:opencsv:5.8")
            dependency("com.clickhouse:clickhouse-jdbc:0.4.6")
            dependency("com.clickhouse:clickhouse-http-client:0.4.6")
            dependency("org.apache.avro:avro:1.11.3")
            dependency("io.github.resilience4j:resilience4j-spring-boot3:2.1.0")
            dependency("io.github.resilience4j:resilience4j-circuitbreaker:2.1.0")
            dependency("io.github.resilience4j:resilience4j-retry:2.1.0")
            dependency("org.springframework.statemachine:spring-statemachine-core:4.0.0")
            dependency("org.apache.commons:commons-math3:3.6.1")
            dependency("org.apache.commons:commons-csv:1.10.0")
        }
    }
}

dependencies {
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

tasks.test {
    useJUnitPlatform()
}