def call(String jobName, String buildNumber, String zuulUuid) {
    return zuulUuid != null ? zuulUuid : "github/${jobName}/${buildNumber}"
}
