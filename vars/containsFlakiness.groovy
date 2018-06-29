def call(String compressedLogFile) {
    def command = "zcat '$compressedLogFile' | flakes/grep.sh > /dev/null"
    def status = sh script: command, returnStatus: true
    return status == 0
}
