param([string]$Only = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$scale = 2
$ink = [Drawing.Color]::Black
$muted = [Drawing.Color]::Black
$line = [Drawing.Color]::Black
$soft = [Drawing.Color]::White
$white = [Drawing.Color]::White
$script:fonts = @{}
function Font([float]$size, [bool]$bold = $false) {
    $size = [Math]::Min($size,22)
    $key = "$size-regular"
    if (!$script:fonts.ContainsKey($key)) {
        $script:fonts[$key] = New-Object Drawing.Font('Arial', $size, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    }
    return $script:fonts[$key]
}
$measureBitmap = New-Object Drawing.Bitmap(10,10)
$script:mg = [Drawing.Graphics]::FromImage($measureBitmap)
$script:mg.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
function TH([string]$text,[float]$size,[float]$width,[bool]$bold=$false) {
    if ([string]::IsNullOrEmpty($text)) { return 0 }
    return [Math]::Ceiling($script:mg.MeasureString($text,(Font $size $bold),[int]$width).Height)
}
function T([string]$text,[float]$x,[float]$y,[float]$width,[float]$size=15,[bool]$bold=$false,$color=$ink,[string]$align='Near') {
    if (!$text) { return }
    $brush = New-Object Drawing.SolidBrush($ink)
    $format = New-Object Drawing.StringFormat
    $format.Alignment = [Drawing.StringAlignment]::$align
    $height = (TH $text $size $width $bold) + 8
    $rect = New-Object Drawing.RectangleF($x,$y,$width,$height)
    $script:g.DrawString($text,(Font $size $bold),$brush,$rect,$format)
    $format.Dispose(); $brush.Dispose()
}
function Line([float]$x1,[float]$y1,[float]$x2,[float]$y2,$color=$line,[float]$weight=1) {
    $pen=New-Object Drawing.Pen($color,$weight)
    $script:g.DrawLine($pen,$x1,$y1,$x2,$y2)
    $pen.Dispose()
}
function Box([float]$x,[float]$y,[float]$w,[float]$h,$fill=$white,$stroke=$line,[float]$radius=10) {
    # Reference style: white interiors and straight, thin black outlines.
    $fill=$white; $stroke=$ink; $radius=0
    $path=New-Object Drawing.Drawing2D.GraphicsPath
    if ($radius -le 0) { $path.AddRectangle((New-Object Drawing.RectangleF($x,$y,$w,$h))) }
    else {
        $d=[Math]::Min($radius*2,[Math]::Min($w,$h))
        $path.AddArc($x,$y,$d,$d,180,90)
        $path.AddArc($x+$w-$d,$y,$d,$d,270,90)
        $path.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90)
        $path.AddArc($x,$y+$h-$d,$d,$d,90,90)
        $path.CloseFigure()
    }
    if ($null -ne $fill) { $b=New-Object Drawing.SolidBrush($fill); $script:g.FillPath($b,$path); $b.Dispose() }
    if ($null -ne $stroke) { $p=New-Object Drawing.Pen($stroke,1); $script:g.DrawPath($p,$path); $p.Dispose() }
    $path.Dispose()
}
function Circle([float]$x,[float]$y,[float]$diameter,$fill=$white,$stroke=$line) {
    $fill=$white; $stroke=$ink
    if($null -ne $fill){$b=New-Object Drawing.SolidBrush($fill);$script:g.FillEllipse($b,$x,$y,$diameter,$diameter);$b.Dispose()}
    if($null -ne $stroke){$p=New-Object Drawing.Pen($stroke,1);$script:g.DrawEllipse($p,$x,$y,$diameter,$diameter);$p.Dispose()}
}
function CrossBox([float]$x,[float]$y,[float]$w,[float]$h) {
    Box $x $y $w $h
    Line $x $y ($x+$w) ($y+$h)
    Line ($x+$w) $y $x ($y+$h)
}
function CrossCircle([float]$x,[float]$y,[float]$diameter) {
    Circle $x $y $diameter
    $inset=$diameter*(1-1/[Math]::Sqrt(2))/2
    Line ($x+$inset) ($y+$inset) ($x+$diameter-$inset) ($y+$diameter-$inset)
    Line ($x+$diameter-$inset) ($y+$inset) ($x+$inset) ($y+$diameter-$inset)
}
function BlockHeight($e,[float]$w) {
    switch($e.type) {
        'section' { return (TH $e.title 19 $w $true)+16 }
        'text' { return (TH $e.title 14 $w)+8 }
        'notice' { return (TH $e.title 13 ($w-28))+28 }
        'field' { return 42+(TH $e.title 12 ($w-28))+(TH $(if($e.detail){$e.detail}else{'Enter value'}) 15 ($w-28)) }
        'button' { return [Math]::Max(46,24+(TH $e.title 14 ($w-30) $true)) }
        'row' { return 24+(TH $e.title 15 ($w-58) $true)+(TH $e.detail 12 ($w-58)) }
        'toggle' { return 28+(TH $e.title 14 ($w-78) $true)+(TH $e.detail 12 ($w-78)) }
        'choice' { return 28+(TH $e.title 15 ($w-55) $true)+(TH $e.detail 12 ($w-55)) }
        'hero' { return 42+(TH $e.title 13 ($w-36))+(TH $e.detail 27 ($w-36) $true)+(TH $e.sub 13 ($w-36)) }
        'brand' { return 72 }
        'identity' { return 86 }
        'tabs' {
            $cell=($w-8)/$e.items.Count; $max=0
            foreach($item in $e.items){$max=[Math]::Max($max,(TH $item 12 ($cell-10) $true))}
            return $max+24
        }
        'quick' { return 88 }
        'progress' { return 22+(TH $e.title 12 $w) }
        'image' { return [float]$e.h+8+(TH $e.title 12 $w) }
        'stats' {
            $cell=($w-10*($e.items.Count-1))/$e.items.Count; $max=0
            foreach($item in $e.items){$p=$item.Split('|');$max=[Math]::Max($max,30+(TH $p[0] 12 ($cell-24))+(TH $p[1] 18 ($cell-24) $true))}
            return $max
        }
        'grid' { return [Math]::Ceiling($e.items.Count/2)*154-12 }
        'task' { return 30+(TH $e.title 15 ($w-106) $true)+(TH $e.detail 11 ($w-106)) }
        'chart' { return 216 }
        'week' { return 108 }
        'calendar' { return 310 }
        'bubble' { return 28+(TH $e.title 15 ($w-58)) }
        'composer' { return 76 }
        'orb' { return 242 }
        'slider' { return 68 }
        'status' { return 115+(TH $e.title 23 ($w-32) $true)+(TH $e.detail 14 ($w-32)) }
        'loading' { return 88+(TH $e.title 14 ($w-32)) }
        'skeleton' { return 174 }
        'keypad' { if($e.compact){return 46};return 208 }
        'buttonrow' {
            $cell=($w-16)/$e.items.Count;$max=0
            foreach($item in $e.items){$max=[Math]::Max($max,(TH $item 13 ($cell-10) $true))}
            return $max+26
        }
        default { throw "Unknown component $($e.type)" }
    }
}
function Draw($e,[float]$x,[float]$y,[float]$w) {
    $h=BlockHeight $e $w
    switch($e.type) {
        'section' { Line $x $y ($x+$w) $y; T $e.title $x ($y+10) $w 19 }
        'text' { T $e.title $x ($y+2) $w 14 $false $muted }
        'notice' { Box $x $y $w $h $soft $line 8; T $e.title ($x+14) ($y+12) ($w-28) 13 $false $muted }
        'field' {
            Box $x $y $w $h; T $e.title ($x+14) ($y+10) ($w-28) 12 $false $muted
            $v=if($e.detail){$e.detail}else{'Enter value'}
            if($e.title -match '^Search'){
                Circle ($x+15) ($y+37) 15
                Line ($x+28) ($y+50) ($x+35) ($y+57)
                T $v ($x+45) ($y+18+(TH $e.title 12 ($w-28))) ($w-59) 15
            }else{T $v ($x+14) ($y+18+(TH $e.title 12 ($w-28))) ($w-28) 15}
        }
        'button' {
            $fill=if($e.secondary){$white}else{$ink};$color=if($e.secondary){$ink}else{$white}
            Box $x $y $w $h $fill $ink 9
            T $e.title ($x+15) ($y+($h-(TH $e.title 14 ($w-30) $true))/2-1) ($w-30) 14 $true $color 'Center'
        }
        'row' {
            Box $x $y $w $h $white $line 8
            T $e.title ($x+14) ($y+10) ($w-58) 15 $true
            T $e.detail ($x+14) ($y+14+(TH $e.title 15 ($w-58) $true)) ($w-58) 12 $false $muted
            T $e.end ($x+$w-40) ($y+($h-26)/2) 32 16 $false $muted 'Center'
        }
        'toggle' {
            Line $x ($y+$h) ($x+$w) ($y+$h)
            T $e.title $x ($y+10) ($w-78) 14 $true
            T $e.detail $x ($y+14+(TH $e.title 14 ($w-78) $true)) ($w-78) 12 $false $muted
            if($e.on){CrossBox ($x+$w-25) ($y+12) 22 22}else{Box ($x+$w-25) ($y+12) 22 22}
        }
        'choice' {
            Box $x $y $w $h $(if($e.selected){$soft}else{$white}) $line 9
            Circle ($x+14) ($y+14) 18
            if($e.selected){CrossCircle ($x+14) ($y+14) 18}
            T $e.title ($x+43) ($y+11) ($w-55) 15 $true
            T $e.detail ($x+43) ($y+15+(TH $e.title 15 ($w-55) $true)) ($w-55) 12 $false $muted
        }
        'hero' {
            Box $x $y $w $h $soft $line 13
            T $e.title ($x+18) ($y+16) ($w-36) 13 $false $muted
            $yy=$y+22+(TH $e.title 13 ($w-36))
            T $e.detail ($x+18) $yy ($w-36) 27 $true
            T $e.sub ($x+18) ($yy+6+(TH $e.detail 27 ($w-36) $true)) ($w-36) 13 $false $muted
        }
        'brand' {
            CrossBox ($x+($w-46)/2) $y 46 46
            T $e.title $x ($y+54) $w 16 $false $ink 'Center'
        }
        'identity' {
            CrossCircle $x ($y+8) 62
            T $e.title ($x+80) ($y+13) ($w-80) 24 $true
            T $e.detail ($x+80) ($y+47) ($w-80) 13 $false $muted
        }
        'tabs' {
            Box $x $y $w $h
            $cell=$w/$e.items.Count
            for($i=0;$i -lt $e.items.Count;$i++){
                if($i -gt 0){Line ($x+$i*$cell) $y ($x+$i*$cell) ($y+$h)}
                if($i -eq $e.selected){Line ($x+$i*$cell+12) ($y+$h-5) ($x+($i+1)*$cell-12) ($y+$h-5)}
                $hh=TH $e.items[$i] 12 ($cell-10) $true
                T $e.items[$i] ($x+5+$i*$cell) ($y+($h-$hh)/2) ($cell-10) 12 $true $ink 'Center'
            }
        }
        'quick' {
            $cell=$w/$e.items.Count
            for($i=0;$i -lt $e.items.Count;$i++){
                CrossBox ($x+$i*$cell+($cell-38)/2) $y 38 38
                T $e.items[$i] ($x+$i*$cell+2) ($y+51) ($cell-4) 11 $false $ink 'Center'
            }
        }
        'progress' {
            Box $x $y $w 8 $soft $null 4
            if($e.value -gt 0){Line $x ($y+4) ($x+$w*$e.value/100) ($y+4) $ink 2}
            T $e.title $x ($y+17) $w 12 $false $muted
        }
        'image' {
            CrossBox $x $y $w ([float]$e.h)
            T $e.title $x ($y+[float]$e.h+8) $w 12
        }
        'stats' {
            $cell=($w-10*($e.items.Count-1))/$e.items.Count
            for($i=0;$i -lt $e.items.Count;$i++){
                $p=$e.items[$i].Split('|');$xx=$x+$i*($cell+10)
                Box $xx $y $cell $h $soft $line 10
                T $p[0] ($xx+12) ($y+12) ($cell-24) 12 $false $muted
                T $p[1] ($xx+12) ($y+18+(TH $p[0] 12 ($cell-24))) ($cell-24) 18 $true
            }
        }
        'grid' {
            $cell=($w-12)/2
            for($i=0;$i -lt $e.items.Count;$i++){
                $xx=$x+($i%2)*($cell+12);$yy=$y+[Math]::Floor($i/2)*154;$p=$e.items[$i].Split('|')
                Box $xx $yy $cell 142 $soft $line 12
                CrossBox ($xx+13) ($yy+13) 22 22
                T $p[0] ($xx+13) ($yy+45) ($cell-26) 15 $true
                $textY=$yy+49+(TH $p[0] 15 ($cell-26) $true)
                if($p.Count -gt 1){T $p[1] ($xx+13) $textY ($cell-26) 12 $false $muted}
                if($p.Count -gt 2){T $p[2] ($xx+13) ($yy+115) ($cell-26) 11 $true}
            }
        }
        'task' {
            T $e.time $x ($y+12) 48 12 $true
            Line ($x+55) $y ($x+55) ($y+$h)
            Box ($x+68) $y ($w-68) $h $soft $line 12
            T $e.title ($x+81) ($y+12) ($w-106) 15 $true
            T $e.detail ($x+81) ($y+19+(TH $e.title 15 ($w-106) $true)) ($w-106) 11 $false $muted
            if($e.done){CrossBox ($x+$w-24) ($y+12) 13 13}else{Box ($x+$w-24) ($y+12) 13 13}
        }
        'chart' {
            Box $x $y $w $h $white $line 12
            T $e.title ($x+16) ($y+12) ($w-32) 13 $true
            for($i=0;$i -le 3;$i++){Line ($x+20) ($y+54+$i*37) ($x+$w-20) ($y+54+$i*37) $soft}
            $values=@(28,66,42,91,55,105,75);$cw=($w-48)/7
            for($i=0;$i -lt 7;$i++){Box ($x+24+$i*$cw+8) ($y+167-$values[$i]) ($cw-16) $values[$i] $muted $null 4;T ([string](23+$i)) ($x+24+$i*$cw) ($y+174) $cw 10 $false $muted 'Center'}
            T $e.detail ($x+16) ($y+196) ($w-32) 10 $false $muted 'Center'
        }
        'week' {
            T '‹          October 2026          ›' $x $y $w 14 $true $ink 'Center'
            $days=@('M','T','W','T','F','S','S');$cw=$w/7
            for($i=0;$i -lt 7;$i++){
                if($i -eq 3){Box ($x+$i*$cw+3) ($y+35) ($cw-6) 60 $soft $line 12}
                T $days[$i] ($x+$i*$cw) ($y+41) $cw 11 $false $muted 'Center'
                T ([string](@(26,27,28,29,30,31,1)[$i])) ($x+$i*$cw) ($y+65) $cw 16 $true $ink 'Center'
            }
        }
        'calendar' {
            T ('‹       '+$e.title+'       ›') $x ($y+4) $w 18 $true $ink 'Center'
            $cw=$w/7;$days=@('M','T','W','T','F','S','S')
            for($i=0;$i -lt 7;$i++){T $days[$i] ($x+$i*$cw) ($y+49) $cw 12 $false $muted 'Center'}
            for($day=1;$day -le 31;$day++){
                $n=$day+2;$xx=$x+($n%7)*$cw;$yy=$y+81+[Math]::Floor($n/7)*42
                if($day -eq 29){Circle ($xx+($cw-32)/2) ($yy-4) 32 $soft $ink}
                T ([string]$day) $xx $yy $cw 14 $false $ink 'Center'
            }
        }
        'bubble' {
            $xx=if($e.user){$x+30}else{$x};$fill=if($e.user){$soft}else{$white}
            Box $xx $y ($w-30) $h $fill $line 13
            T $e.title ($xx+14) ($y+12) ($w-58) 15
        }
        'composer' {
            Box $x $y $w $h $white $ink 18
            CrossBox ($x+$w-48) ($y+14) 32 32
            T $e.title ($x+17) ($y+20) ($w-80) 13 $false $muted
            T 'Message input' ($x+17) ($y+53) ($w-34) 10 $false $muted
        }
        'orb' {
            CrossCircle ($x+($w-146)/2) ($y+12) 146
            T $e.title $x ($y+186) $w 17 $true $ink 'Center'
        }
        'slider' {
            T $e.title $x $y $w 13 $false $muted
            Line ($x+8) ($y+43) ($x+$w-8) ($y+43) $line 3
            Circle ($x+$w*0.52) ($y+35) 16 $white $ink
        }
        'status' {
            CrossCircle ($x+($w-52)/2) ($y+8) 52
            T $e.title ($x+16) ($y+82) ($w-32) 23 $true $ink 'Center'
            T $e.detail ($x+16) ($y+94+(TH $e.title 23 ($w-32) $true)) ($w-32) 14 $false $muted 'Center'
        }
        'loading' {
            $p=New-Object Drawing.Pen($muted,3);$script:g.DrawArc($p,($x+$w/2-17),($y+10),34,34,-70,270);$p.Dispose()
            T $e.title ($x+16) ($y+62) ($w-32) 14 $false $muted 'Center'
        }
        'skeleton' {
            CrossBox $x $y $w 48
            Box $x ($y+62) ($w*0.78) 16 $soft $null 5
            Box $x ($y+90) ($w*0.94) 16 $soft $null 5
            CrossBox $x ($y+122) $w 46
        }
        'keypad' {
            $rows=if($e.compact){1}else{4};$cw=($w-16)/3;$keys=@('1','2','3','4','5','6','7','8','9','.','0','Clear')
            for($r=0;$r -lt $rows;$r++){for($c=0;$c -lt 3;$c++){
                Box ($x+$c*($cw+8)) ($y+$r*54) $cw 46 $white $line 7
                T $keys[$r*3+$c] ($x+$c*($cw+8)) ($y+$r*54+12) $cw 16 $true $ink 'Center'
            }}
        }
        'buttonrow' {
            $cw=($w-8*($e.items.Count-1))/$e.items.Count
            for($i=0;$i -lt $e.items.Count;$i++){
                $last=$i -eq ($e.items.Count-1)
                Box ($x+$i*($cw+8)) $y $cw $h $(if($last){$ink}else{$white}) $line 7
                T $e.items[$i] ($x+$i*($cw+8)+5) ($y+12) ($cw-10) 13 $true $(if($last){$white}else{$ink}) 'Center'
            }
        }
    }
    return $h
}
function Navigation([string]$active,[float]$x,[float]$y,[float]$w) {
    Line $x $y ($x+$w) $y
    $names=@('Today','Goals','Planner','Reports','Profile');$cw=$w/5
    for($i=0;$i -lt 5;$i++){
        CrossBox ($x+$i*$cw+($cw-28)/2) ($y+15) 28 28
        T $names[$i] ($x+$i*$cw) ($y+49) $cw 11 $false $ink 'Center'
    }
}
$results = [Collections.Generic.List[object]]::new()
foreach($s in $manifest.screens) {
    if($Only -and $s.slug -notmatch $Only){continue}
    $widget=$s.kind -eq 'widget';$modal=$s.kind -in @('dialog','sheet')
    $frameW=478.0
    if($widget){$frameW=switch($s.size){'Compact'{260.0};'Medium'{356.0};default{400.0}}}
    $frameX=(480-$frameW)/2;$bodyW=$frameW-78;$bodyX=$frameX+39
    if($widget){$bodyW=$frameW-40;$bodyX=$frameX+20}
    $headerH=TH $s.title 20 $bodyW
    $bodyY=if($widget){134.0}elseif($modal){250.0+$headerH}else{145.0+$headerH}
    $bodyHeight=0.0
    foreach($e in $s.items){$bodyHeight+=(BlockHeight $e $bodyW)+12}
    $navHeight=if($s.nav){76}else{20}
    $bottom=$bodyY+$bodyHeight+$navHeight+16
    if(!$widget){$bottom=[Math]::Max($bottom,850)}
    $canvasH=[int]($bottom+1)
    $bitmap=New-Object Drawing.Bitmap((480*$scale),($canvasH*$scale))
    $bitmap.SetResolution(144,144)
    $script:g=[Drawing.Graphics]::FromImage($bitmap)
    $script:g.ScaleTransform($scale,$scale)
    $script:g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $script:g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $script:g.Clear($white)
    if($widget){
        T $s.title 32 28 416 20
        Box $frameX 78 $frameW ($bottom-78)
        CrossBox ($frameX+20) 94 24 24
        T 'SaveTrack' ($frameX+54) 97 ($frameW-74) 16
    } else {
        Box $frameX 1 $frameW ($bottom-1)
        CrossBox ($frameX+32) 32 48 48
        T 'SaveTrack' ($frameX+96) 44 ($frameW-205) 22
        CrossCircle ($frameX+$frameW-95) 28 60
        if($modal){
            T $s.parent $bodyX 114 $bodyW 20
            CrossBox $bodyX 154 $bodyW 50
            Line $frameX 226 ($frameX+$frameW) 226
            T $s.title $bodyX 242 $bodyW 20
        }else{
            T $s.title $bodyX 112 $bodyW 20
        }
    }
    $yy=$bodyY
    foreach($e in $s.items){$yy+=(Draw $e $bodyX $yy $bodyW)+12}
    if($s.nav){Navigation $s.nav $frameX ($bottom-76) $frameW}
    $folder=Join-Path $root $s.group
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $name=$s.id+'-'+$s.slug+'.png'
    $path=Join-Path $folder $name
    $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
    $results.Add([pscustomobject]@{id=$s.id;title=$s.title;file=($s.group+'/'+$name);width=$bitmap.Width;height=$bitmap.Height;source=$s.source;coverage=$s.coverage;kind=$s.kind;note=$s.note;style='reference-outline'})
    $script:g.Dispose();$bitmap.Dispose()
    if($results.Count % 25 -eq 0){Write-Output ('Rendered '+$results.Count+' pictures...')}
}
if(!$Only){$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $root 'index.json') -Encoding UTF8}
$script:mg.Dispose();$measureBitmap.Dispose()
foreach($f in $script:fonts.Values){$f.Dispose()}
Write-Output ('Rendered '+$results.Count+' individual PNG wireframes to '+$root)
