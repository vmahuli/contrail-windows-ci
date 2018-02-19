def call() {
    def build = currentBuild.getRawBuild()
    def lockManager = org.jenkins.plugins.lockableresources.LockableResourcesManager.class.get()
    def lockedNetworkResource = lockManager.getResourcesFromBuild(build)[0]
    return lockedNetworkResource.getName()
}
