def call(String srcDir, String destDir, String filter) {
    def status = powershell script: "robocopy ${srcDir} ${destDir} ${filter} /S"
    if (status != 1) {
        // robocopy makes extensive use of exit codes. We're interested in checking
        // exit code 1: One of more files were copied successfully.
        return 1
    }
}
