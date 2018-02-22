@{
    Severity=@("Error", "Warning")
    ExcludeRules=@(
        "PSAvoidUsingWriteHost",        # This will be removed in favor of Write-Log in the future.
        "PSAvoidUsingInvokeExpression", # We don't have an alternative for this yet.
        "PSUseShouldProcessForStateChangingFunctions",      # We don't care about altering system state.
        "PSUseSingularNouns",           # We sometimes like using plural nouns.
        "PSAvoidUsingWMICmdlet"         # We tend to use WMI to access advanced Hyper-V features.
    )
}
