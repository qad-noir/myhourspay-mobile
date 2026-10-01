Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $root 'assets/brand/brand-mark.png'))
function Write-Icon([string]$relative, [int]$size, [double]$scale = 1.0) {
  $bitmap = [System.Drawing.Bitmap]::new($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear($source.GetPixel(100, 100))
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $edge = [int]($size * $scale)
  $offset = [int](($size - $edge) / 2)
  $graphics.DrawImage($source, $offset, $offset, $edge, $edge)
  $bitmap.Save((Join-Path $root $relative), [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()
}
foreach ($entry in @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}.GetEnumerator()) {
  Write-Icon "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png" $entry.Value
}
$catalog = Get-Content (Join-Path $root 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($entry in $catalog.images) {
  $size = [int]([double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x')))
  Write-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" $size
}
Write-Icon 'web/favicon.png' 32
foreach ($size in @(192,512)) {
  Write-Icon "web/icons/Icon-$size.png" $size
  Write-Icon "web/icons/Icon-maskable-$size.png" $size 0.75
}
$source.Dispose()

