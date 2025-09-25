plugins {
    `java-library`
}

group = "com.natsu"
version = "1.0-SNAPSHOT"

dependencies {
    api(project(":common:common-model"))
    api(project(":common:common-utils"))
    
    // JWT libraries
    api("io.jsonwebtoken:jjwt-api")
    runtimeOnly("io.jsonwebtoken:jjwt-impl")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson")
    
    // Spring Security Core (versions managed by BOM)
    api("org.springframework.security:spring-security-core")
    api("org.springframework.security:spring-security-crypto")
    
    // Session management
    api("org.springframework.session:spring-session-core")
    
    // Redis for session storage (optional)
    api("org.springframework.data:spring-data-redis")
    api("redis.clients:jedis")
    
    // Logging
    api("org.slf4j:slf4j-api")
    
    // Lombok
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testImplementation("org.mockito:mockito-core")
    testImplementation("org.springframework.security:spring-security-test")
}

tasks.test {
    useJUnitPlatform()
}
