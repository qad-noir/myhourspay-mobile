param([int]$Width = 390)
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '../docs/visual-review')).Path
$names = @('sign-in','your-week','add-hours','weekly-timesheet','verify','workspaces','review-timesheet','account')
$height = @{360=800;390=844;430=932}[$Width]
if (-not $height) { throw 'Use 360, 390 or 430.' }
$board = [System.Drawing.Bitmap]::new((4*($Width+20)+20),(2*($height+54)+20))
$canvas = [System.Drawing.Graphics]::FromImage($board)
$font = [System.Drawing.Font]::new('Segoe UI',14)
try {
  $canvas.Clear([System.Drawing.ColorTranslator]::FromHtml('#e9e6e1'))
  for ($i=0; $i -lt 8; $i++) {
    $x=20+($i%4)*($Width+20)
    $y=20+[Math]::Floor($i/4)*($height+54)
    $canvas.DrawString($names[$i],$font,[System.Drawing.Brushes]::Black,$x,$y)
    $shot=[System.Drawing.Image]::FromFile((Join-Path $root "$Width/$($names[$i]).png"))
    try { $canvas.DrawImage($shot,$x,($y+32),$Width,$height) } finally { $shot.Dispose() }
  }
  $output = if ($Width -eq 390) {'contact-sheet.png'} else {"contact-sheet-$Width.png"}
  $board.Save((Join-Path $root $output),[System.Drawing.Imaging.ImageFormat]::Png)
} finally { $canvas.Dispose(); $board.Dispose(); $font.Dispose() }
