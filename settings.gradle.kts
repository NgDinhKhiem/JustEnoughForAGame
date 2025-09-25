rootProject.name = "JustEnoughForAGame"

include("common")
include("common:common-model")
include("common:common-utils")
include("common:common-security")
include("common:common-messaging")
include("common:common-spring-boot")
include("services")
include("services:auth-service")
include("services:user-service")
include("services:lobby-service")
include("services:game-service")
include("services:leaderboard-service")
include("services:analytics-service")
include("infra")

