def call(String stashName) {
    try {
        unstash stashName
        return true
    } catch (Exception ex) {
        echo "Failed to unstash ${stashName}"
        return false
    }
}
