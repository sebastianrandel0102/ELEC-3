# Windows-only artwork helper. The app and builds use the checked-in PNGs.
param([ValidateSet('goal', 'planner', 'quick_save', 'today')][string[]]$Widget)

Add-Type -AssemblyName System.Drawing
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
$fontCollection.AddFontFile((Join-Path $projectRoot 'assets/fonts/Manrope.ttf'))
$fontFamily = $fontCollection.Families[0]
$icon = [System.Drawing.Image]::FromFile((Join-Path $projectRoot 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'))

function Draw-Text($graphics, $content, $x, $y, $size, $color, $bold = $false) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = New-Object System.Drawing.Font($fontFamily, $size, $style, ([System.Drawing.GraphicsUnit]::Pixel))
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
    $graphics.DrawString($content, $font, $brush, [float]$x, [float]$y)
    $font.Dispose()
    $brush.Dispose()
}

function New-RoundedPath($x, $y, $width, $height, $radius) {
    $diameter = $radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc(($x + $width - $diameter), $y, $diameter, $diameter, 270, 90)
    $path.AddArc(($x + $width - $diameter), ($y + $height - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($x, ($y + $height - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-Surface($graphics, $x, $y, $width, $height, $radius, $color) {
    $path = New-RoundedPath $x $y $width $height $radius
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
    $graphics.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
}

$previews = @(
    @{Name = 'goal'; Title = 'SAVINGS GOAL'; Main = 'Motorcycle Fund'; Value = '40% completed'; Light = $false},
    @{Name = 'planner'; Title = 'TODAY''S PLANNER'; Main = '2 tasks left'; Value = '1 / 3 tasks completed'; Light = $true},
    @{Name = 'quick_save'; Title = 'QUICK SAVE'; Main = 'Quick Save'; Value = 'PHP | Motorcycle Fund'; Light = $false},
    @{Name = 'today'; Title = 'SAVETRACK TODAY'; Main = 'Motorcycle Fund'; Value = '40% saved'; Light = $false}
)
foreach ($preview in $previews) {
    if ($Widget -and $preview.Name -notin $Widget) { continue }
    $bitmap = New-Object System.Drawing.Bitmap(600, 320)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $path = New-RoundedPath 0 0 600 320 28
    $start = if ($preview.Light) { '#EDFAF3' } else { '#052F28' }
    $end = if ($preview.Light) { '#DCF8EB' } else { '#0B5B4B' }
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, 600, 320)), ([System.Drawing.ColorTranslator]::FromHtml($start)), ([System.Drawing.ColorTranslator]::FromHtml($end)), 0)
    $graphics.FillPath($brush, $path)
    $graphics.DrawImage($icon, 28, 24, 48, 48)
    $foreground = if ($preview.Light) { '#14362B' } else { '#FFFFFF' }
    $secondary = if ($preview.Light) { '#526E61' } else { '#D9F6E9' }
    Draw-Text $graphics $preview.Title 88 36 18 $secondary $true
    if ($preview.Name -ne 'today') {
        Draw-Text $graphics $preview.Main 28 90 32 $foreground $true
        Draw-Text $graphics $preview.Value 28 144 25 $foreground
    }
    if ($preview.Name -eq 'today') {
        Draw-Surface $graphics 28 88 266 190 16 '#124D40'
        Draw-Surface $graphics 306 88 266 190 16 '#124D40'
        Draw-Text $graphics 'Savings' 48 106 18 $secondary $true
        Draw-Text $graphics '40%' 48 136 40 $foreground $true
        Draw-Text $graphics 'Motorcycle Fund' 48 196 20 $secondary
        Draw-Text $graphics "Today's tasks" 326 106 18 $secondary $true
        Draw-Text $graphics '2' 326 136 40 $foreground $true
        Draw-Text $graphics 'tasks left' 326 196 20 $secondary
        Draw-Surface $graphics 48 244 226 8 4 '#467564'
        Draw-Surface $graphics 48 244 90 8 4 '#4BD4A8'
        Draw-Surface $graphics 326 244 226 8 4 '#467564'
        Draw-Surface $graphics 326 244 75 8 4 '#4BD4A8'
        Draw-Text $graphics 'Sample preview' 28 290 15 $secondary
    } elseif ($preview.Name -eq 'quick_save') {
        $amounts = @('+50.00', '+100.00', '+500.00')
        for ($index = 0; $index -lt 3; $index++) {
            $left = 28 + 185 * $index
            Draw-Surface $graphics $left 202 174 52 14 '#ABF2D7'
            Draw-Text $graphics $amounts[$index] ($left + 22) 212 23 '#052F28' $true
        }
        Draw-Text $graphics 'Sample shortcuts. Review and confirm in SaveTrack.' 28 274 17 $secondary
    } else {
        $track = if ($preview.Light) { '#D7EAE0' } else { '#467564' }
        $accent = if ($preview.Light) { '#13876D' } else { '#4BD4A8' }
        $fraction = if ($preview.Name -eq 'planner') { 1.0 / 3.0 } else { 0.4 }
        $barY = 203
        Draw-Surface $graphics 28 $barY 544 8 4 $track
        Draw-Surface $graphics 28 $barY ([int](544 * $fraction)) 8 4 $accent
        Draw-Text $graphics 'Sample preview' 28 249 18 $secondary
    }
    $target = Join-Path $projectRoot ('android/app/src/main/res/drawable/st_widget_preview_' + $preview.Name + '.png')
    $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $path.Dispose()
    $brush.Dispose()
}
$icon.Dispose()
$fontCollection.Dispose()
Write-Output 'Generated widget picker previews.'
