Param(
    [Parameter(Mandatory = $true)]
    [bool]$IsReleaseBuild
)
function Show-Completed {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Percentage,
        [Parameter(Mandatory = $true)]
        [string]$Activity,
        [string]$Status = "Processing"
    )
    Write-Progress -Activity $Activity -Status $Status -percentComplete $Percentage
    Write-Host "`r$([math]::floor($Percentage).ToString().PadLeft(3, " "))% Completed" -NoNewline
}

if ($IsReleaseBuild) {
    Write-Host "****************************************************************************************************" -ForegroundColor "Green"
    Write-Host "**  'Release' builds are packaged as a zip file for loading into Chrome/Edge Extension Manager.   **" -ForegroundColor "Green"
    Write-Host "****************************************************************************************************`r`n" -ForegroundColor "Green"
}

$manifest = Get-Content -Raw -Path './src/manifest.json' | ConvertFrom-Json

Write-Host "Building " -NoNewline
Write-Host "$($manifest.name) $($manifest.version) " -ForegroundColor "Green" -NoNewline
Write-Host "($(if ($IsReleaseBuild) { "Release" } else { "Debug" }))" -ForegroundColor "DarkMagenta"

Show-Completed -Percentage 1 -Activity "Build" -Status "Creating Folders"

if (!(Test-Path -Path './obj/')) {
    New-Item -ItemType directory -Path './obj/' | Out-Null
}
if (!(Test-Path -Path './bin/')) {
    New-Item -ItemType directory -Path './bin/' | Out-Null
}

if ($IsReleaseBuild) {
    if (!(Test-Path -Path './obj/release')) {
        New-Item -ItemType directory -Path './obj/release' | Out-Null
    }
    if (!(Test-Path -Path './bin/release')) {
        New-Item -ItemType directory -Path './bin/release' | Out-Null
    }

    Show-Completed -Percentage 3 -Activity "Cleaning"
    Get-ChildItem -Path './bin/release' -Include * -File -Recurse | ForEach-Object { Set-ItemProperty $_.FullName -name IsReadOnly -value $false; $_.Delete() }
    Show-Completed -Percentage 5 -Activity "Cleaning"
    Get-ChildItem -Path './obj/release' -Include * -File -Recurse | ForEach-Object { Set-ItemProperty $_.FullName -name IsReadOnly -value $false; $_.Delete() }

    Show-Completed -Percentage 10 -Activity "Copying"
    Copy-Item -Path './src/*' -Destination './obj/release/' -Force -Recurse | Out-Null

    $i = 0; $files = Get-ChildItem './obj/release/' -Recurse -Force -Include *.css
    $files | ForEach-Object {
        & "./scripts/Minify-CSS.ps1" -file $_
        Show-Completed -Percentage (10 + (($i++ / ($files.Count) * 100) * 0.4)) -Activity "Minifying" -Status "Minifying $($_.BaseName).$($_.Extension)"
    }

    $i = 0;  $files = Get-ChildItem './obj/release/' -Recurse -Force -Include *.js
    $files | ForEach-Object {
        & "./scripts/Minify-Javascript.ps1" -file $_
        Show-Completed -Percentage (50 + (($i++ / ($files.Count) * 100) * 0.4)) -Activity "Minifying" -Status "Minifying $($_.BaseName).$($_.Extension)"
    }

    Show-Completed -Percentage 90 -Activity "Archiving"
    Compress-Archive -Path "./obj/release/*" -DestinationPath "./bin/release/$($manifest.name).zip" -Force | Out-Null
}
else {
    if (!(Test-Path -Path './obj/debug')) {
        New-Item -ItemType directory -Path './obj/debug' | Out-Null
    }
    if (!(Test-Path -Path './bin/debug')) {
        New-Item -ItemType directory -Path './bin/debug' | Out-Null
    }

    Show-Completed -Percentage 20 -Activity "Cleaning"
    Get-ChildItem -Path './bin/debug' -Include * -File -Recurse | ForEach-Object { Set-ItemProperty $_.FullName -name IsReadOnly -value $false; $_.Delete() }
    Show-Completed -Percentage 40 -Activity "Cleaning"
    Get-ChildItem -Path './obj/debug' -Include * -File -Recurse | ForEach-Object { Set-ItemProperty $_.FullName -name IsReadOnly -value $false; $_.Delete() }

    Show-Completed -Percentage 60 -Activity "Copying"
    Copy-Item -Path './src/*' -Destination './bin/debug/' -Force -Recurse | Out-Null
    Show-Completed -Percentage 80 -Activity "Copying"
    Copy-Item -Path './src/*' -Destination './obj/debug/' -Force -Recurse | Out-Null
}

Show-Completed -Percentage 100 -Activity "Build" -Status "Completed"