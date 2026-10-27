# Export actual native RemoteViews sample renders; never redraw them independently.
param(
    [ValidateSet('goal', 'planner', 'quick_save', 'today')][string[]]$Widget,
    [switch]$Render
)
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previewDirectory = Join-Path $projectRoot 'build/widget-atelier'
if ($Render) {
    $previousPreviewDirectory = $env:SAVETRACK_WIDGET_PREVIEW_DIR
    try {
        $env:SAVETRACK_WIDGET_PREVIEW_DIR = $previewDirectory
        Push-Location (Join-Path $projectRoot 'android')
        try {
            & .\gradlew.bat :app:testDebugUnitTest --rerun --tests 'com.example.myproject.widgets.WidgetAtelierRenderingTest.allWidgetsRenderAcrossThemesAndShapes' --console=plain
            if ($LASTEXITCODE -ne 0) { throw 'Native preview rendering failed.' }
        } finally { Pop-Location }
    } finally { $env:SAVETRACK_WIDGET_PREVIEW_DIR = $previousPreviewDirectory }
}
$names = @{goal='goal'; planner='planner'; quick_save='quickSave'; today='today'}
foreach ($name in @('goal', 'planner', 'quick_save', 'today')) {
    if ($Widget -and $name -notin $Widget) { continue }
    # Use the verified native reference frame. High-density picker captures
    # can clip branding in Robolectric even when their view bounds are correct.
    $theme = if ($name -eq 'planner') { 'mint' } else { 'emerald' }
    $source = Join-Path $previewDirectory ($names[$name] + '-' + $theme + '-day-300x220.png')
    if (-not (Test-Path -LiteralPath $source)) { throw 'Native previews are missing. Set JAVA_HOME and rerun this helper with -Render.' }
    $destination = Join-Path $projectRoot ('android/app/src/main/res/drawable/st_widget_preview_' + $name + '.png')
    Copy-Item -LiteralPath $source -Destination $destination -Force
}
Write-Output 'Updated widget picker previews from actual native sample renders.'
