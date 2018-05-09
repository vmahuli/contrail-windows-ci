def call(String text) {
    if (env.ghprbPullId) {
        def body="""{
                "body": "${text}",
                "commit_id": "${env.ghprbActualCommit}",
                "path": "/",
                "position": 0
        }"""
        def response = httpRequest authentication: "codijenkinsbot", httpMode: 'POST', requestBody: body,
            url: "https://api.github.com/repos/${env.ghprbGhRepository}/issues/${env.ghprbPullId}/comments"
        println("Status: " + response.status)
        println("Content: " + response.content)
    }
}
