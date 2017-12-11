class Repo {
    [string] $Url;
    [string] $Branch;
    [string] $DefaultBranch;
    [string] $Dir;

    [void] init([string] $Url, [string] $Branch, [string] $DefaultBranch, [string] $Dir) {
        $this.Url = $Url
        $this.Branch = $Branch
        $this.Dir = $Dir
        $this.DefaultBranch = $DefaultBranch
    }

    Repo ([string] $Url, [string] $Branch, [string] $DefaultBranch, [string] $Dir) {
        $this.init($Url, $Branch, $DefaultBranch, $Dir)
    }
}
