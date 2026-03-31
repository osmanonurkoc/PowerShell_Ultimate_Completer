# Define the path to the JSON data file
$DataPath = Join-Path -Path $PSScriptRoot -ChildPath "completions.json"

# Load the JSON data into memory
if (Test-Path $DataPath) {
    $Global:UltimateCompletions = Get-Content -Raw -Path $DataPath | ConvertFrom-Json
} else {
    Write-Warning "UltimateCompleter: completions.json not found!"
    return
}

# Find the root commands in the JSON and register a completer for each
foreach ($RootCommand in $Global:UltimateCompletions.psobject.properties.name) {

    # KÜÇÜK DOKUNUŞ: Hem "adb" hem de "adb.exe" için motoru tetikle
    Register-ArgumentCompleter -CommandName $RootCommand, "$RootCommand.exe" -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        # Get the components of the typed command
        $Elements = $commandAst.CommandElements
        $RawRoot = $Elements[0].Value

        # KÜÇÜK DOKUNUŞ: Kullanıcı ".exe" yazdıysa JSON'da bulabilmek için o kısmı sil
        $Root = $RawRoot -replace '(?i)\.exe$', ''
        $CurrentNode = $Global:UltimateCompletions.$Root

        $Results = @()
        $IsTyping = ![string]::IsNullOrWhiteSpace($wordToComplete)

        # LEVEL 1: Completing the first argument (subcommands or root flags)
        if (($Elements.Count -eq 1 -and -not $IsTyping) -or ($Elements.Count -eq 2 -and $IsTyping)) {
            if ($CurrentNode.subcommands) {
                $Results += $CurrentNode.subcommands.psobject.properties.name
            }
            if ($CurrentNode.flags) {
                $Results += $CurrentNode.flags
            }
        }
        # LEVEL 2+: Completing arguments/flags AFTER a subcommand
        elseif (($Elements.Count -ge 2 -and -not $IsTyping) -or ($Elements.Count -ge 3 -and $IsTyping)) {
            $SubCommand = $Elements[1].Value

            if ($CurrentNode.subcommands.$SubCommand.flags) {
                $Results += $CurrentNode.subcommands.$SubCommand.flags
            }
        }

        # FILTER: If the user is actively typing, filter the results based on the input
        if ($IsTyping) {
            $Results = $Results | Where-Object { $_ -like "$wordToComplete*" }
        }

        # FORMAT: Convert the found results into PowerShell's CompletionResult format
        $Results | Select-Object -Unique | ForEach-Object {
            $ItemName = $_
            $Tooltip = $ItemName

            # Add descriptions to subcommands for better tooltips
            if ($CurrentNode.subcommands.$ItemName.description) {
                $Tooltip = $CurrentNode.subcommands.$ItemName.description
            }

            [System.Management.Automation.CompletionResult]::new($ItemName, $ItemName, 'ParameterValue', $Tooltip)
        }
    }
}
