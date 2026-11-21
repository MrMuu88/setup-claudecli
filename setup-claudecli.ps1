<#
.SYNOPSIS
    Claude Code CLI telepítése és Windows-integrációja (PATH, Windows Terminal profil, intéző helyi menü).

.DESCRIPTION
    Függvények:
      Install-ClaudeCli             - telepíti a Claude CLI-t, ha hiányzik, és felveszi a PATH-ba
      Register-ClaudeTerminalProfile - létrehozza a "Claude Code" Windows Terminal profilt (fragment)
      Register-ClaudeContextMenu    - "Open claude here" menüpont mappára és mappa hátterére (HKCU)
      Install-ClaudeIntegration     - a fentieket a megfelelő sorrendben futtatja

    Rendszergazdai jog nem kell, minden a felhasználói profilban / HKCU alatt történik.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup-claudecli.ps1

.EXAMPLE
    . .\setup-claudecli.ps1 -NoRun   # csak betölti a függvényeket
    Register-ClaudeContextMenu
#>
[CmdletBinding()]
param(
    # Ha meg van adva, csak betölti a függvényeket (dot-sourcing), nem futtat semmit.
    [switch]$NoRun
)

$script:ClaudeProfileName = 'Claude Code'
$script:ClaudeBinDir      = Join-Path $env:USERPROFILE '.local\bin'
$script:ClaudeMenuText    = 'Open claude here'
$script:ClaudeMenuKey     = 'OpenClaudeHere'

function Get-ClaudeExePath {
    # A claude.exe tényleges helye (PATH-ból vagy az alapértelmezett telepítési helyről).
    $cmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    $default = Join-Path $script:ClaudeBinDir 'claude.exe'
    if (Test-Path $default) { return $default }

    return $null
}

function Install-ClaudeCli {
    <#
    .SYNOPSIS
        Ellenőrzi és szükség esetén telepíti a Claude CLI-t, majd biztosítja, hogy a mappája a felhasználói PATH-ban legyen.
    #>
    [CmdletBinding()]
    param()

    $exe = Get-ClaudeExePath
    if ($exe) {
        Write-Host "[OK] Claude CLI már telepítve van: $exe" -ForegroundColor Green
    }
    else {
        Write-Host '[..] Claude CLI nincs telepítve, telepítés a hivatalos telepítővel...' -ForegroundColor Yellow
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-RestMethod -Uri 'https://claude.ai/install.ps1' -UseBasicParsing | Invoke-Expression
        }
        catch {
            throw "A Claude CLI telepítése nem sikerült: $($_.Exception.Message)"
        }

        $exe = Get-ClaudeExePath
        if (-not $exe) { throw 'A telepítő lefutott, de a claude.exe nem található.' }
        Write-Host "[OK] Claude CLI telepítve: $exe" -ForegroundColor Green
    }

    # PATH ellenőrzése (felhasználói szint)
    $binDir   = (Split-Path $exe -Parent).TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $entries  = (@($userPath, $machPath) -join ';') -split ';' |
                Where-Object { $_ } |
                ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') }

    if ($entries -contains $binDir) {
        Write-Host "[OK] A PATH már tartalmazza: $binDir" -ForegroundColor Green
    }
    else {
        $newPath = if ([string]::IsNullOrEmpty($userPath)) { $binDir } else { $userPath.TrimEnd(';') + ';' + $binDir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "[OK] Hozzáadva a felhasználói PATH-hoz: $binDir" -ForegroundColor Green
    }

    # Az aktuális sessionben is legyen elérhető
    if (($env:Path -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $binDir) {
        $env:Path = $env:Path.TrimEnd(';') + ';' + $binDir
    }

    return $exe
}

function Register-ClaudeTerminalProfile {
    <#
    .SYNOPSIS
        Létrehozza a "Claude Code" profilt a Windows Terminalban, ha még nem létezik.
    .DESCRIPTION
        JSON fragmentként hozza létre (%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\ClaudeCode),
        így a settings.json-höz nem nyúl. A Windows Terminal a következő indításkor betölti.
    #>
    [CmdletBinding()]
    param(
        [string]$ClaudeExe = (Get-ClaudeExePath)
    )

    if (-not $ClaudeExe) { throw 'A claude.exe nem található. Előbb futtasd: Install-ClaudeCli' }

    if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
        Write-Warning 'A Windows Terminal (wt.exe) nem található. Telepítés: winget install --id Microsoft.WindowsTerminal -e'
    }

    # 1) Van-e már ilyen nevű profil a settings.json-ben (pl. kézzel létrehozva)?
    $settingsFiles = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    ) | Where-Object { Test-Path $_ }

    $namePattern = '"name"\s*:\s*"' + [regex]::Escape($script:ClaudeProfileName) + '"'
    foreach ($file in $settingsFiles) {
        if ((Get-Content $file -Raw) -match $namePattern) {
            Write-Host "[OK] A '$($script:ClaudeProfileName)' profil már létezik: $file" -ForegroundColor Green
            return
        }
    }

    # 2) Fragment létrehozása / ellenőrzése
    $fragmentDir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\ClaudeCode'
    $fragmentFile = Join-Path $fragmentDir 'claude.json'

    if (Test-Path $fragmentFile) {
        Write-Host "[OK] A '$($script:ClaudeProfileName)' profil már létezik: $fragmentFile" -ForegroundColor Green
        return
    }

    $fragment = [ordered]@{
        profiles = @(
            [ordered]@{
                name              = $script:ClaudeProfileName
                # A PowerShell nyitva marad, ha kilépsz a claude-ból
                commandline       = "powershell.exe -NoLogo -NoExit -Command `"& '$ClaudeExe'`""
                icon              = $ClaudeExe
                startingDirectory = '%USERPROFILE%'
                tabTitle          = $script:ClaudeProfileName
                suppressApplicationTitle = $true
            }
        )
    }

    New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
    $json = $fragment | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($fragmentFile, $json, (New-Object Text.UTF8Encoding($false)))

    Write-Host "[OK] Windows Terminal profil létrehozva: $fragmentFile" -ForegroundColor Green
    Write-Host '     (A Windows Terminal újraindítása után jelenik meg.)' -ForegroundColor DarkGray
}

function Register-ClaudeContextMenu {
    <#
    .SYNOPSIS
        "Open claude here" menüpont az intézőben: mappára jobb klikk és mappa üres területére jobb klikk.
        Csak az aktuális felhasználó registry-jét módosítja (HKCU).
    #>
    [CmdletBinding()]
    param(
        [string]$ClaudeExe = (Get-ClaudeExePath)
    )

    $wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (-not (Test-Path $wt)) {
        $wtCmd = Get-Command wt.exe -ErrorAction SilentlyContinue
        if ($wtCmd) { $wt = $wtCmd.Source } else { throw 'A Windows Terminal (wt.exe) nem található.' }
    }

    # "%V\." : így a meghajtó gyökere (C:\) sem rontja el az idézőjelezést
    $command = "`"$wt`" -p `"$($script:ClaudeProfileName)`" -d `"%V\.`""

    $targets = @(
        'HKCU:\Software\Classes\Directory\shell',             # jobb klikk egy mappán
        'HKCU:\Software\Classes\Directory\Background\shell'   # jobb klikk a mappa üres területén
    )

    foreach ($base in $targets) {
        $key = Join-Path $base $script:ClaudeMenuKey
        New-Item -Path "$key\command" -Force | Out-Null

        Set-ItemProperty -Path $key -Name '(default)' -Value $script:ClaudeMenuText
        if ($ClaudeExe) { Set-ItemProperty -Path $key -Name 'Icon' -Value "`"$ClaudeExe`",0" }
        Set-ItemProperty -Path "$key\command" -Name '(default)' -Value $command

        Write-Host "[OK] Helyi menü bejegyezve: $key" -ForegroundColor Green
    }
    Write-Host '     (Windows 11-en a "További beállítások megjelenítése" / Shift+F10 menüben látszik.)' -ForegroundColor DarkGray
}

function Unregister-ClaudeContextMenu {
    # Visszavonás: eltávolítja a helyi menü bejegyzéseket.
    [CmdletBinding()]
    param()
    foreach ($base in 'HKCU:\Software\Classes\Directory\shell', 'HKCU:\Software\Classes\Directory\Background\shell') {
        $key = Join-Path $base $script:ClaudeMenuKey
        if (Test-Path $key) { Remove-Item $key -Recurse -Force; Write-Host "[OK] Törölve: $key" }
    }
}

function Install-ClaudeIntegration {
    <#
    .SYNOPSIS
        Összefogó függvény: CLI + PATH -> Terminal profil -> helyi menü.
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n=== 1/3 Claude CLI és PATH ===" -ForegroundColor Cyan
    $exe = Install-ClaudeCli

    Write-Host "`n=== 2/3 Windows Terminal profil ===" -ForegroundColor Cyan
    Register-ClaudeTerminalProfile -ClaudeExe $exe

    Write-Host "`n=== 3/3 Intéző helyi menü ===" -ForegroundColor Cyan
    Register-ClaudeContextMenu -ClaudeExe $exe

    Write-Host "`nKész. Nyiss új terminált / indítsd újra a Windows Terminalt, hogy minden érvénybe lépjen." -ForegroundColor Cyan
}

if (-not $NoRun) {
    Install-ClaudeIntegration
}
