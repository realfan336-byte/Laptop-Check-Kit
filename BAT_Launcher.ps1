# ============================================================
#  BAT Launcher - PowerShell App
#  Scans its own folder (and subfolders) for .bat files.
#  If none found, asks you to select a folder.
#  Then shows a simple menu to launch any BAT file.
# ============================================================

#Requires -Version 3.0

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Get-ScriptDirectory {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) {
        return Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    return (Get-Location).Path
}

function Find-BatFiles {
    param([string]$RootPath)

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return @()
    }

    try {
        $files = Get-ChildItem -LiteralPath $RootPath -Filter "*.bat" -Recurse -File -ErrorAction SilentlyContinue |
                 Sort-Object FullName
        return $files
    }
    catch {
        return @()
    }
}

function Show-FolderPicker {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the folder that contains your .bat files"
    $dialog.ShowNewFolderButton = $false
    $dialog.SelectedPath = (Get-ScriptDirectory)

    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

function Show-Menu {
    param(
        [array]$BatFiles,
        [string]$SearchRoot
    )

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                 BAT LAUNCHER" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Searching in: $SearchRoot" -ForegroundColor Yellow
    Write-Host ("Found {0} BAT file(s)" -f $BatFiles.Count) -ForegroundColor Green
    Write-Host ""

    if ($BatFiles.Count -eq 0) {
        Write-Host "Nothing found." -ForegroundColor Red
        Write-Host ""
        return $null
    }

    $i = 1
    foreach ($f in $BatFiles) {
        $relative = $f.FullName.Substring($SearchRoot.Length).TrimStart('\')
        Write-Host ("  {0,3}. {1}" -f $i, $relative)
        $i++
    }

    Write-Host ""
    Write-Host "  R.  Rescan current folder"
    Write-Host "  C.  Choose a different folder"
    Write-Host "  Q.  Quit"
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan

    $choice = Read-Host "Enter number to launch (or R / C / Q)"

    if ($choice -match '^[Qq]$') { return "QUIT" }
    if ($choice -match '^[Rr]$') { return "RESCAN" }
    if ($choice -match '^[Cc]$') { return "CHOOSE" }

    if ($choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $BatFiles.Count) {
            return $BatFiles[$index]
        }
    }

    Write-Host "Invalid choice." -ForegroundColor Red
    Start-Sleep -Seconds 1
    return "RESCAN"
}

# -------------------- Main --------------------

$Host.UI.RawUI.WindowTitle = "BAT Launcher"

$currentRoot = Get-ScriptDirectory
$batFiles = Find-BatFiles -RootPath $currentRoot

# If nothing found in the script's own folder, ask for a folder
if ($batFiles.Count -eq 0) {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                 BAT LAUNCHER" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Nothing found in the folder where this script is located:" -ForegroundColor Yellow
    Write-Host "  $currentRoot" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Please select a folder that contains .bat files..." -ForegroundColor White
    Write-Host ""

    $selected = Show-FolderPicker
    if (-not $selected) {
        Write-Host "No folder selected. Exiting." -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit
    }
    $currentRoot = $selected
    $batFiles = Find-BatFiles -RootPath $currentRoot
}

# Main loop
while ($true) {
    $result = Show-Menu -BatFiles $batFiles -SearchRoot $currentRoot

    if ($result -eq "QUIT") {
        Write-Host "Goodbye." -ForegroundColor Cyan
        Start-Sleep -Seconds 1
        exit
    }
    elseif ($result -eq "RESCAN") {
        $batFiles = Find-BatFiles -RootPath $currentRoot
        continue
    }
    elseif ($result -eq "CHOOSE") {
        $selected = Show-FolderPicker
        if ($selected) {
            $currentRoot = $selected
            $batFiles = Find-BatFiles -RootPath $currentRoot
        }
        continue
    }
    elseif ($result -is [System.IO.FileInfo]) {
        $batPath = $result.FullName
        Write-Host ""
        Write-Host "Launching: $batPath" -ForegroundColor Green
        Write-Host ""

        try {
            # Start the BAT in its own window so the launcher stays open
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -WorkingDirectory $result.DirectoryName
        }
        catch {
            Write-Host "Failed to launch: $_" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }

        Write-Host ""
        Write-Host "Press any key to return to the menu..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
