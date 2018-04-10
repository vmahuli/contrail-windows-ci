def showUrl(Map logServer, String destDir) {
    def httpRootLocation = '/var/www/logs/'
    if (destDir.contains(httpRootLocation)) {
        echo ('logs published to http://' + logServer.addr + destDir.replace(httpRootLocation, '/'))
    }
}

def call(Map logServer, String srcDir, String destDir, boolean mayThrow = true) {
    script {
        if (fileExists(srcDir)) {
            def authority = "${logServer.user}@${logServer.addr}"
            def remoteDir = authority + ":" + destDir
            shellCommand "ssh", [authority, "mkdir", "-p", destDir]
            shellCommand "rsync", ["-r", srcDir + "/", remoteDir]
            showUrl(logServer, destDir)
        } else {
            def message = "publishToLogServer: Directory '${src}' does not exist."
            if (mayThrow) {
                error message
            } else {
                echo message
            }
        }
    }
}
