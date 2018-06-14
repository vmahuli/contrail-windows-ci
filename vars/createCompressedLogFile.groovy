def call(String jobName, String buildNumber, String outputFile) {
  // The timestamps are not stored on disk as raw text, but in some encoded form,
  // so the easiest way to decode them is to use http path provided by the timestamper plugin.
  def jobSubpath = jobName.replaceAll("/", "/job/")
  def timestampFormat = "time=yyyy-MM-dd%20HH:mm:ss.SSS000%20|&appendLog"
  def logHttpPath = "job/$jobSubpath/$buildNumber/timestamps/?$timestampFormat"
  def curl = "curl --silent 'http://localhost:8080/$logHttpPath'"

  // Indents lines that lack a timestamp, so they're aligned
  def indent = "sed 's/^  /                           |  /'"

  // Removes extra space after | symbol
  def removeExtraSpace = /sed 's#\(^[^|]*| \) #\1#'/

  sh "$curl | $indent | $removeExtraSpace | gzip > $outputFile"
}
