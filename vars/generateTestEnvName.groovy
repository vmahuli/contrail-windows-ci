def call() {
    return UUID.randomUUID().toString().split('-')[-1]
}
