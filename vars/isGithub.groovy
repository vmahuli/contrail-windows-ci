def call(String text) {
    // we determine if project was triggered from github by detecting if variable used by
    // Github Pull Request Builder (Jenkins plugin) is set.
    return env.ghprbPullId
}
