def call() {
    if (env.ZUUL_UUID) {
        return env.ZUUL_UUID.split('-')[0]
    } else {
        return env.ghprbActualCommit.take(8)
    }
}
