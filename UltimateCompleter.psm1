# Define the path to the JSON data file
$DataPath = Join-Path -Path $PSScriptRoot -ChildPath "completions.json"

# Load the JSON data into memory (Using -AsHashTable to prevent case collisions like -d vs -D)
if (Test-Path $DataPath) {
    # This requires PowerShell 6+ / 7
    $Global:UltimateCompletions = Get-Content -Raw -Path $DataPath | ConvertFrom-Json -AsHashTable
} else {
    Write-Warning "UltimateCompleter: completions.json not found!"
    return
}

# Find the root commands in the JSON and register a completer for each
foreach ($RootCommand in $Global:UltimateCompletions.Keys) {

    Register-ArgumentCompleter -CommandName $RootCommand, "$RootCommand.exe" -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        $Elements = $commandAst.CommandElements
        $RawRoot = $Elements[0].Value
        $Root = ($RawRoot -replace '(?i)\.exe$', '').ToLower()

        if (-not $Global:UltimateCompletions.Contains($Root)) { return }
        $CurrentNode = $Global:UltimateCompletions[$Root]

        $Results = @()
        $IsTyping = ![string]::IsNullOrWhiteSpace($wordToComplete)
        $IgnoredItems = @('--color', '--version', '-v', '--help', '-h')

        # 1. SCAN FOR SUBCOMMAND: Scan the entire command line for a known subcommand
        $FoundSubCommand = $null
        $SubCommandIndex = -1

        for ($i = 1; $i -lt $Elements.Count; $i++) {
            $Value = $Elements[$i].Value.ToString().ToLower()
            # Do not treat the word currently being typed as a finalized subcommand
            if ($IsTyping -and $i -eq ($Elements.Count - 1)) { continue }

            if ($CurrentNode.Contains('subcommands') -and $CurrentNode['subcommands'].Contains($Value)) {
                $FoundSubCommand = $Value
                $SubCommandIndex = $i
                break
            }
        }

        # 2. DETERMINE ALREADY TYPED ARGUMENTS
        $AlreadyTyped = @()
        $StartIndex = if ($FoundSubCommand) { $SubCommandIndex + 1 } else { 1 }
        $EndIndex = if ($IsTyping) { $Elements.Count - 2 } else { $Elements.Count - 1 }

        if ($EndIndex -ge $StartIndex) {
            $AlreadyTyped = $Elements[$StartIndex..$EndIndex] | Select-Object -ExpandProperty Value
        }

        # 3. SMART DEPTH & STACKING LIMITER (The Magic Heuristic)
        # If any of the already typed arguments does NOT start with '-', we assume it's a
        # positional argument (like a filename, partition 'boot', or package name).
        # Once a positional argument is typed, we STOP suggesting flags and let PowerShell suggest files.
        $StopSuggesting = $false
        foreach ($Arg in $AlreadyTyped) {
            if (-not $Arg.StartsWith('-')) {
                $StopSuggesting = $true
                break
            }
        }

        if ($StopSuggesting) {
            return # Exit completer, enabling default file/path autocomplete
        }

        # 4. POPULATE RESULTS BASED ON CONTEXT
        if ($FoundSubCommand) {
            # Subcommand Context (e.g., fastboot flash)
            $SubNode = $CurrentNode['subcommands'][$FoundSubCommand]
            if ($SubNode.Contains('flags')) {
                $Results += ($SubNode['flags'] -is [System.Collections.Hashtable]) ? $SubNode['flags'].Keys : $SubNode['flags']
            }
        } else {
            # Root Context (e.g., fastboot)
            if ($CurrentNode.Contains('subcommands')) { $Results += $CurrentNode['subcommands'].Keys }
            if ($CurrentNode.Contains('flags')) {
                $Results += ($CurrentNode['flags'] -is [System.Collections.Hashtable]) ? $CurrentNode['flags'].Keys : $CurrentNode['flags']
            }
        }

        # 5. FILTER: Remove ignored items and already typed items (to prevent duplicates like vendor vendor)
        if ($AlreadyTyped.Count -gt 0) {
            $Results = $Results | Where-Object { $_ -notin $AlreadyTyped }
        }
        $Results = $Results | Where-Object { $_ -notin $IgnoredItems }

        if ($IsTyping) {
            $Results = $Results | Where-Object { $_ -like "$wordToComplete*" }
        }

        # 6. FORMAT: Convert to PowerShell's CompletionResult with Tooltips
        $Results | Select-Object -Unique | ForEach-Object {
            $ItemName = $_
            $Tooltip = $ItemName

            if ($CurrentNode.Contains('subcommands') -and $CurrentNode['subcommands'].Contains($ItemName)) {
                if ($CurrentNode['subcommands'][$ItemName].Contains('description')) {
                    $Tooltip = $CurrentNode['subcommands'][$ItemName]['description']
                }
            } elseif ($CurrentNode.Contains('flags') -and $CurrentNode['flags'] -is [System.Collections.Hashtable] -and $CurrentNode['flags'].Contains($ItemName)) {
                $Tooltip = $CurrentNode['flags'][$ItemName]
            } elseif ($FoundSubCommand) {
                $SubNode = $CurrentNode['subcommands'][$FoundSubCommand]
                if ($SubNode.Contains('flags') -and $SubNode['flags'] -is [System.Collections.Hashtable] -and $SubNode['flags'].Contains($ItemName)) {
                    $Tooltip = $SubNode['flags'][$ItemName]
                }
            }

            [System.Management.Automation.CompletionResult]::new($ItemName, $ItemName, 'ParameterValue', $Tooltip)
        }
    }
}
