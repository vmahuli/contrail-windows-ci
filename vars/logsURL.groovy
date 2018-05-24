def call(String logServerAddr, String logServerFolder, String relativeLogsPath) {
    return "http://${logServerAddr}/${logServerFolder}/${relativeLogsPath}"
}
