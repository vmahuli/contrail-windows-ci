def call(Map logServer, String zuulUuid) {
    def path = zuulUuid != null ? zuulUuid : "github/${env.JOB_NAME}/${env.BUILD_NUMBER}"
    return "http://${logServer.addr}/${logServer.folder}/${path}"
}
