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

        # Lowercase the root command to safely find it in the Hashtable
        $Root = ($RawRoot -replace '(?i)\.exe$', '').ToLower()

        # Check if root command exists in JSON
        if (-not $Global:UltimateCompletions.Contains($Root)) { return }
        $CurrentNode = $Global:UltimateCompletions[$Root]

        $Results = @()
        $IsTyping = ![string]::IsNullOrWhiteSpace($wordToComplete)

        # IGNORE LIST: You can list flags here that cause unnecessary clutter
        $IgnoredItems = @('--color', '--version', '-v', '--help', '-h')

        # LEVEL 1: Completing the first argument (subcommands or root flags)
        if (($Elements.Count -eq 1 -and -not $IsTyping) -or ($Elements.Count -eq 2 -and $IsTyping)) {
            if ($CurrentNode.Contains('subcommands')) {
                $Results += $CurrentNode['subcommands'].Keys
            }
            if ($CurrentNode.Contains('flags')) {
                # Check if flags are an array or an object/hashtable containing descriptions
                if ($CurrentNode['flags'] -is [System.Collections.Hashtable]) {
                    $Results += $CurrentNode['flags'].Keys
                } else {
                    $Results += $CurrentNode['flags']
                }
            }
        }
        # LEVEL 2+: Completing arguments/flags AFTER a subcommand
        elseif (($Elements.Count -ge 2 -and -not $IsTyping) -or ($Elements.Count -ge 3 -and $IsTyping)) {
            $SubCommand = $Elements[1].Value.ToLower()

            if ($CurrentNode.Contains('subcommands') -and $CurrentNode['subcommands'].Contains($SubCommand)) {
                $SubNode = $CurrentNode['subcommands'][$SubCommand]
                if ($SubNode.Contains('flags')) {
                    $FlagsNode = $SubNode['flags']
                    if ($FlagsNode -is [System.Collections.Hashtable]) {
                        $Results += $FlagsNode.Keys
                    } else {
                        $Results += $FlagsNode
                    }
                }
            }
        }

        # FILTER: Remove ignored items first, then filter by typed characters
        $Results = $Results | Where-Object { $_ -notin $IgnoredItems }

        if ($IsTyping) {
            $Results = $Results | Where-Object { $_ -like "$wordToComplete*" }
        }

        # FORMAT: Convert the found results into PowerShell's CompletionResult format
        $Results | Select-Object -Unique | ForEach-Object {
            $ItemName = $_
            $Tooltip = $ItemName

            # 1. Add descriptions to subcommands
            if ($CurrentNode.Contains('subcommands') -and $CurrentNode['subcommands'].Contains($ItemName)) {
                if ($CurrentNode['subcommands'][$ItemName].Contains('description')) {
                    $Tooltip = $CurrentNode['subcommands'][$ItemName]['description']
                }
            }
            # 2. Add descriptions to root flags (if formatted as a hashtable)
            elseif ($CurrentNode.Contains('flags') -and $CurrentNode['flags'] -is [System.Collections.Hashtable] -and $CurrentNode['flags'].Contains($ItemName)) {
                $Tooltip = $CurrentNode['flags'][$ItemName]
            }
            # 3. Add descriptions to subcommand flags (if formatted as a hashtable)
            elseif ($Elements.Count -ge 2) {
                $SubCommand = $Elements[1].Value.ToLower()
                if ($CurrentNode.Contains('subcommands') -and $CurrentNode['subcommands'].Contains($SubCommand)) {
                    $SubNode = $CurrentNode['subcommands'][$SubCommand]
                    if ($SubNode.Contains('flags') -and $SubNode['flags'] -is [System.Collections.Hashtable] -and $SubNode['flags'].Contains($ItemName)) {
                        $Tooltip = $SubNode['flags'][$ItemName]
                    }
                }
            }

            [System.Management.Automation.CompletionResult]::new($ItemName, $ItemName, 'ParameterValue', $Tooltip)
        }
    }
}
