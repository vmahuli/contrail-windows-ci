#
# Job is a utility class that keeps track of time that parts of code
# take to execute and prints them lazily.
#
# Class usage example:
#
# ```
# $t = [Job]::new("asdf")
# $t.PushStep("t")
#     $t.PushStep("t0")
#     $t.PopStep()
#     $t.PushStep("t1")
#         $t.PushStep("t11")
#         $t.PopStep()
#         $t.PushStep("t12")
#         $t.PopStep()
#     $t.PopStep()
#     $t.PushStep("t2")
#     $t.PopStep()
#     $t.StepQuiet("ttt1", { echo "test123" })
#     $t.Step("ttt2", { echo "test456" })
# $t.PopStep()
# $t.PushStep("tx")
#     $t.PushStep("Should be closed automatically")
# $t.Done()
# ```
#
# console output:
#
# ```
# t
# t0
# t1
# t11
# t12
# t2
# ttt1
# test123
# ttt2
# ttt2
# test456
# tx
# Should be closed automatically
# =======================================================

#  Time measurement results:

#      - [00:00:00.2979891]: asdf
#                - [00:00:00.1989877]: t
#                          - [00:00:00.0099960]: t0
#                          - [00:00:00.0160005]: t1
#                                    - [00:00:00.0009887]: t11
#                                    - [00:00:00]: t12
#                          - [00:00:00.0010003]: t2
#                          - [00:00:00.0679968]: ttt1
#                          - [00:00:00.0259872]: ttt2
#                - [00:00:00.0370220]: tx
#                          - [00:00:00.0270315]: Should be closed automatically
# =======================================================
# ```

   
class JobStep {
    [string] $Name
    [DateTime] $Start
    [DateTime] $End
    [System.Collections.ArrayList] $Children

    JobStep ([string] $Name) {
        $this.Name = $Name
        $this.Children = New-Object System.Collections.ArrayList
    }

    [TimeSpan] GetResult() {
        return ($this.End - $this.Start)
    }

    Print([int] $IndentLevel) {
        $msg = ""
        1..($IndentLevel) | ForEach-Object {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="Issue #804 from PSScriptAnalyzer GitHub")]
            $msg += " "
        }
        $msg += "- [" + ($this.GetResult()) + "]: " + $this.Name
        Write-Host $msg

        ForEach($Child in $this.Children) {
            $Child.Print($IndentLevel + 10)
        }
    }
}

class Job {
    [int] $CurrentIndentLevel
    [System.Collections.Stack] $Stack
    [JobStep] $Root

    Job ([string] $name = "Job") {
        $this.Root = [JobStep]::new($name)
        $this.Root.Start = Get-Date
        $this.Stack = New-Object System.Collections.Stack
        $this.Stack.Push($this.Root)
        $this.CurrentIndentLevel = 0
    }

    PushStep([string] $msg) {
        Write-Host $msg
        $this.PushQuiet($msg)
    }

    PushQuiet([string] $msg) {
        $tm = [JobStep]::new($msg)
        $tm.Start = Get-Date
        $top = $this.Stack.Peek()
        $top.Children.Add($tm)
        $this.Stack.Push($tm)
    }

    PopStep() {
        $tm = $this.Stack.Pop()
        $tm.End = Get-Date
    }

    Step([string] $msg, [scriptblock] $block) {
        Write-Host $msg
        $this.StepQuiet($msg, $block)
    }

    StepQuiet([string] $msg, [scriptblock] $block) {
        $this.PushQuiet($msg)
        $sb = [scriptblock]::Create($block)
        & $sb | ForEach-Object { Write-Host "$_" }
        $this.PopStep()
    }

    Done() {
        Write-Host "=======================================================`n"
        Write-Host " Time measurement results: `n"
        while($this.Root -ne $this.Stack.Peek()) {
            $this.PopStep()
        }
        $this.Root.End = Get-Date
        $this.Root.Print(5)
        Write-Host "=======================================================`n"
    }
}
