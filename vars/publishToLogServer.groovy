def call(Map logServer, String srcDir, String destDir, boolean mayThrow = true) {
    script {
        if (fileExists(srcDir)) {
            def authority = "${logServer.user}@${logServer.addr}"
            def remoteDir = authority + ":" + destDir
            shellCommand "ssh", [authority, "mkdir", "-p", destDir]
            shellCommand "rsync", ["-r", srcDir + "/", remoteDir]
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
