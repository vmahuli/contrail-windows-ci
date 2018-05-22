def call(String testReportsUrl) {
    def possibleReportLocationsFile = "${testReportsUrl}/reports-locations.json"
    def reportsLocationParam = [] 
    if (fileExists(possibleReportLocationsFile)) {
        reportsLocationParam = ['--reports-json-url', possibleReportLocationsFile]
    }
    return reportsLocationParam
}
