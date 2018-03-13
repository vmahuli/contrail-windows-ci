def call(Map logServer, String zuulUuid) {
    def logsRemoteDir

    if (zuulUuid != null) {
        logsRemoteDir = "${logServer.rootDir}/${zuulUuid}"
    } else {
        logsRemoteDir = "${logServer.rootDir}/github/${env.JOB_NAME}/${env.BUILD_NUMBER}"
    }

    return logsRemoteDir
}
