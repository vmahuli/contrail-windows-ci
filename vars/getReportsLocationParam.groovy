def call(String fullLogsURL) {
    // DEPRECATED: we want to get rid of the need for reports-location.json. 
    // - this path is hardcoded, but w/e because we intend to get rid of it in very near future
    // - also, there are two reports-locations.json, but we only use the one for WindowsCompute
    // Getting rid of reports-location.json should be possible by modifying the monitoring
    // collector script and just passing path to unstashed xml files in the same Stage.
    def possibleReportLocationsFile = "${fullLogsURL}/TestReports/WindowsCompute/reports-locations.json"
    def reportsLocationParam = [] 
    if (fileExists(possibleReportLocationsFile)) {
        reportsLocationParam = ['--reports-json-url', possibleReportLocationsFile]
    }
    return reportsLocationParam
}
