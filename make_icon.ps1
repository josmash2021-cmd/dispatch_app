Add-Type -AssemblyName System.Drawing

function Make-Icon {
    param([string]$outPath, [int]$size, [float]$contentScale)

    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = 'HighQuality'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode   = 'HighQuality'
    $g.TextRenderingHint = 'AntiAliasGridFit'

    # Background
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,8,9,12))
    $g.FillRectangle($bgBrush, 0, 0, $size, $size)

    # Content area
    $margin = $size * (1 - $contentScale) / 2
    $cSize  = $size * $contentScale
    $cx     = $size / 2
    $cy     = $size / 2

    # ── Gold colours ──
    $gold      = [System.Drawing.Color]::FromArgb(255,212,168,67)
    $goldLight = [System.Drawing.Color]::FromArgb(255,235,200,110)
    $goldDark  = [System.Drawing.Color]::FromArgb(255,170,130,40)

    # ── GOLD "C" ARC (top portion) ──
    $arcPen = New-Object System.Drawing.Pen($gold, ($cSize * 0.045))
    $arcPen.StartCap = 'Round'
    $arcPen.EndCap   = 'Round'
    $arcR   = $cSize * 0.38
    $arcRect = New-Object System.Drawing.RectangleF(($cx - $arcR), ($cy - $arcR - $cSize*0.08), ($arcR*2), ($arcR*2))
    $g.DrawArc($arcPen, $arcRect, 200, 280)

    # Inner arc for thickness effect
    $arcPen2 = New-Object System.Drawing.Pen($goldLight, ($cSize * 0.02))
    $arcPen2.StartCap = 'Round'
    $arcPen2.EndCap   = 'Round'
    $arcR2 = $cSize * 0.34
    $arcRect2 = New-Object System.Drawing.RectangleF(($cx - $arcR2), ($cy - $arcR2 - $cSize*0.08), ($arcR2*2), ($arcR2*2))
    $g.DrawArc($arcPen2, $arcRect2, 210, 260)

    # ── MODERN CAR (bottom portion) ──
    $carW = $cSize * 0.72
    $carH = $cSize * 0.30
    $carX = $cx - $carW / 2
    $carY = $cy + $cSize * 0.10

    # --- Car body path (sleek modern sedan) ---
    $bodyPath = New-Object System.Drawing.Drawing2D.GraphicsPath

    # Bottom line (between wheels)
    $bL = $carX + $carW * 0.12
    $bR = $carX + $carW * 0.88
    $bY = $carY + $carH * 0.72

    # Main body shape - sleek sedan profile
    # Start from front bottom
    $bodyPath.AddLine(
        ($carX + $carW * 0.08), $bY,
        ($carX + $carW * 0.02), ($carY + $carH * 0.55)  # front lower
    )
    # Front nose (low and aerodynamic)
    $bodyPath.AddBezier(
        ($carX + $carW * 0.02), ($carY + $carH * 0.55),
        ($carX + $carW * 0.0),  ($carY + $carH * 0.40),
        ($carX + $carW * 0.03), ($carY + $carH * 0.30),
        ($carX + $carW * 0.08), ($carY + $carH * 0.28)   # hood start
    )
    # Hood line
    $bodyPath.AddBezier(
        ($carX + $carW * 0.08), ($carY + $carH * 0.28),
        ($carX + $carW * 0.15), ($carY + $carH * 0.25),
        ($carX + $carW * 0.25), ($carY + $carH * 0.22),
        ($carX + $carW * 0.32), ($carY + $carH * 0.20)   # A-pillar base
    )
    # Windshield to roof
    $bodyPath.AddBezier(
        ($carX + $carW * 0.32), ($carY + $carH * 0.20),
        ($carX + $carW * 0.36), ($carY + $carH * 0.02),
        ($carX + $carW * 0.42), ($carY - $carH * 0.05),
        ($carX + $carW * 0.48), ($carY - $carH * 0.06)  # roof front
    )
    # Roofline
    $bodyPath.AddBezier(
        ($carX + $carW * 0.48), ($carY - $carH * 0.06),
        ($carX + $carW * 0.55), ($carY - $carH * 0.07),
        ($carX + $carW * 0.62), ($carY - $carH * 0.05),
        ($carX + $carW * 0.70), ($carY + $carH * 0.05)  # rear window start
    )
    # Rear window / fastback
    $bodyPath.AddBezier(
        ($carX + $carW * 0.70), ($carY + $carH * 0.05),
        ($carX + $carW * 0.76), ($carY + $carH * 0.12),
        ($carX + $carW * 0.82), ($carY + $carH * 0.20),
        ($carX + $carW * 0.88), ($carY + $carH * 0.25)  # trunk
    )
    # Trunk to rear
    $bodyPath.AddBezier(
        ($carX + $carW * 0.88), ($carY + $carH * 0.25),
        ($carX + $carW * 0.94), ($carY + $carH * 0.30),
        ($carX + $carW * 0.98), ($carY + $carH * 0.40),
        ($carX + $carW * 0.97), ($carY + $carH * 0.55)  # rear end
    )
    # Rear bottom
    $bodyPath.AddLine(
        ($carX + $carW * 0.97), ($carY + $carH * 0.55),
        ($carX + $carW * 0.92), $bY
    )
    # Bottom (with wheel well gaps)
    $bodyPath.AddLine(($carX + $carW * 0.92), $bY, ($carX + $carW * 0.08), $bY)
    $bodyPath.CloseFigure()

    # Fill car body with gradient
    $bodyBounds = New-Object System.Drawing.RectangleF($carX, ($carY - $carH*0.1), $carW, ($carH * 1.2))
    $bodyBrush  = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $bodyBounds, $gold, $goldDark, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $g.FillPath($bodyBrush, $bodyPath)

    # Car body outline
    $outlinePen = New-Object System.Drawing.Pen($goldLight, ($cSize * 0.008))
    $g.DrawPath($outlinePen, $bodyPath)

    # --- Windows (dark cutouts) ---
    $winBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 15, 16, 22))

    # Windshield
    $wsPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $wsPath.AddBezier(
        ($carX + $carW * 0.34), ($carY + $carH * 0.18),
        ($carX + $carW * 0.37), ($carY + $carH * 0.04),
        ($carX + $carW * 0.42), ($carY - $carH * 0.01),
        ($carX + $carW * 0.47), ($carY - $carH * 0.02)
    )
    $wsPath.AddBezier(
        ($carX + $carW * 0.47), ($carY - $carH * 0.02),
        ($carX + $carW * 0.48), ($carY + $carH * 0.06),
        ($carX + $carW * 0.46), ($carY + $carH * 0.14),
        ($carX + $carW * 0.44), ($carY + $carH * 0.18)
    )
    $wsPath.AddLine(($carX + $carW * 0.44), ($carY + $carH * 0.18), ($carX + $carW * 0.34), ($carY + $carH * 0.18))
    $wsPath.CloseFigure()
    $g.FillPath($winBrush, $wsPath)

    # Side window
    $swPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $swPath.AddLine(
        ($carX + $carW * 0.46), ($carY + $carH * 0.18),
        ($carX + $carW * 0.49), ($carY - $carH * 0.02)
    )
    $swPath.AddBezier(
        ($carX + $carW * 0.49), ($carY - $carH * 0.02),
        ($carX + $carW * 0.56), ($carY - $carH * 0.03),
        ($carX + $carW * 0.63), ($carY - $carH * 0.01),
        ($carX + $carW * 0.68), ($carY + $carH * 0.06)
    )
    $swPath.AddBezier(
        ($carX + $carW * 0.68), ($carY + $carH * 0.06),
        ($carX + $carW * 0.70), ($carY + $carH * 0.12),
        ($carX + $carW * 0.70), ($carY + $carH * 0.16),
        ($carX + $carW * 0.68), ($carY + $carH * 0.18)
    )
    $swPath.AddLine(($carX + $carW * 0.68), ($carY + $carH * 0.18), ($carX + $carW * 0.46), ($carY + $carH * 0.18))
    $swPath.CloseFigure()
    $g.FillPath($winBrush, $swPath)

    # --- LED Headlights (gold strip) ---
    $headlightBrush = New-Object System.Drawing.SolidBrush($goldLight)
    $hlPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hlPath.AddBezier(
        ($carX + $carW * 0.02), ($carY + $carH * 0.38),
        ($carX + $carW * 0.03), ($carY + $carH * 0.32),
        ($carX + $carW * 0.06), ($carY + $carH * 0.30),
        ($carX + $carW * 0.10), ($carY + $carH * 0.29)
    )
    $hlPath.AddLine(($carX + $carW * 0.10), ($carY + $carH * 0.29), ($carX + $carW * 0.10), ($carY + $carH * 0.35))
    $hlPath.AddBezier(
        ($carX + $carW * 0.10), ($carY + $carH * 0.35),
        ($carX + $carW * 0.06), ($carY + $carH * 0.36),
        ($carX + $carW * 0.04), ($carY + $carH * 0.38),
        ($carX + $carW * 0.02), ($carY + $carH * 0.42)
    )
    $hlPath.CloseFigure()
    $g.FillPath($headlightBrush, $hlPath)

    # Headlight glow
    $glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80,235,200,110))
    $glowRect = New-Object System.Drawing.RectangleF(($carX - $carW*0.02), ($carY + $carH*0.28), ($carW*0.15), ($carH*0.18))
    $g.FillEllipse($glowBrush, $glowRect)

    # --- Taillights (red) ---
    $tailBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,200,40,40))
    $tlPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tlPath.AddBezier(
        ($carX + $carW * 0.93), ($carY + $carH * 0.32),
        ($carX + $carW * 0.95), ($carY + $carH * 0.36),
        ($carX + $carW * 0.96), ($carY + $carH * 0.42),
        ($carX + $carW * 0.96), ($carY + $carH * 0.48)
    )
    $tlPath.AddLine(($carX + $carW * 0.96), ($carY + $carH * 0.48), ($carX + $carW * 0.90), ($carY + $carH * 0.42))
    $tlPath.AddLine(($carX + $carW * 0.90), ($carY + $carH * 0.42), ($carX + $carW * 0.90), ($carY + $carH * 0.32))
    $tlPath.CloseFigure()
    $g.FillPath($tailBrush, $tlPath)

    # Tail glow
    $tailGlow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60,200,40,40))
    $tgRect = New-Object System.Drawing.RectangleF(($carX + $carW*0.88), ($carY + $carH*0.28), ($carW*0.14), ($carH*0.24))
    $g.FillEllipse($tailGlow, $tgRect)

    # --- Gold accent line (character line along body) ---
    $accentPen = New-Object System.Drawing.Pen($goldLight, ($cSize * 0.007))
    $accentPen.StartCap = 'Round'
    $accentPen.EndCap   = 'Round'
    $alPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $alPath.AddBezier(
        ($carX + $carW * 0.06), ($carY + $carH * 0.40),
        ($carX + $carW * 0.25), ($carY + $carH * 0.34),
        ($carX + $carW * 0.55), ($carY + $carH * 0.30),
        ($carX + $carW * 0.88), ($carY + $carH * 0.34)
    )
    $g.DrawPath($accentPen, $alPath)

    # --- Wheels ---
    $wheelR   = $carH * 0.17
    $wheelPen = New-Object System.Drawing.Pen($goldLight, ($cSize * 0.008))
    $tireBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,30,30,30))
    $rimBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,80,80,85))
    $hubBrush  = New-Object System.Drawing.SolidBrush($goldDark)
    $capBrush  = New-Object System.Drawing.SolidBrush($gold)

    # Front wheel
    $fwX = $carX + $carW * 0.18
    $fwY = $bY - $wheelR * 0.3
    $g.FillEllipse($tireBrush, ($fwX - $wheelR), ($fwY - $wheelR), ($wheelR*2), ($wheelR*2))
    $g.FillEllipse($rimBrush, ($fwX - $wheelR*0.72), ($fwY - $wheelR*0.72), ($wheelR*1.44), ($wheelR*1.44))

    # Front wheel spokes
    $spokePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180,160,160,165), ($cSize * 0.004))
    for ($i = 0; $i -lt 5; $i++) {
        $angle = $i * 72 * [Math]::PI / 180
        $sx = $fwX + [Math]::Cos($angle) * $wheelR * 0.25
        $sy = $fwY + [Math]::Sin($angle) * $wheelR * 0.25
        $ex = $fwX + [Math]::Cos($angle) * $wheelR * 0.65
        $ey = $fwY + [Math]::Sin($angle) * $wheelR * 0.65
        $g.DrawLine($spokePen, $sx, $sy, $ex, $ey)
    }

    $g.FillEllipse($hubBrush, ($fwX - $wheelR*0.28), ($fwY - $wheelR*0.28), ($wheelR*0.56), ($wheelR*0.56))
    $g.FillEllipse($capBrush, ($fwX - $wheelR*0.14), ($fwY - $wheelR*0.14), ($wheelR*0.28), ($wheelR*0.28))
    $g.DrawEllipse($wheelPen, ($fwX - $wheelR), ($fwY - $wheelR), ($wheelR*2), ($wheelR*2))

    # Rear wheel
    $rwX = $carX + $carW * 0.78
    $rwY = $bY - $wheelR * 0.3
    $g.FillEllipse($tireBrush, ($rwX - $wheelR), ($rwY - $wheelR), ($wheelR*2), ($wheelR*2))
    $g.FillEllipse($rimBrush, ($rwX - $wheelR*0.72), ($rwY - $wheelR*0.72), ($wheelR*1.44), ($wheelR*1.44))

    for ($i = 0; $i -lt 5; $i++) {
        $angle = ($i * 72 + 36) * [Math]::PI / 180
        $sx = $rwX + [Math]::Cos($angle) * $wheelR * 0.25
        $sy = $rwY + [Math]::Sin($angle) * $wheelR * 0.25
        $ex = $rwX + [Math]::Cos($angle) * $wheelR * 0.65
        $ey = $rwY + [Math]::Sin($angle) * $wheelR * 0.65
        $g.DrawLine($spokePen, $sx, $sy, $ex, $ey)
    }

    $g.FillEllipse($hubBrush, ($rwX - $wheelR*0.28), ($rwY - $wheelR*0.28), ($wheelR*0.56), ($wheelR*0.56))
    $g.FillEllipse($capBrush, ($rwX - $wheelR*0.14), ($rwY - $wheelR*0.14), ($wheelR*0.28), ($wheelR*0.28))
    $g.DrawEllipse($wheelPen, ($rwX - $wheelR), ($rwY - $wheelR), ($wheelR*2), ($wheelR*2))

    # --- Shadow under car ---
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40,0,0,0))
    $shadowRect  = New-Object System.Drawing.RectangleF(($carX + $carW*0.10), ($bY + $wheelR*0.5), ($carW*0.80), ($carH*0.06))
    $g.FillEllipse($shadowBrush, $shadowRect)

    # ── Save ──
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Saved: $outPath ($size x $size)"
}

# Generate both icons
$assetsDir = "C:\Users\josma\dispatch_app\assets"

# Regular icon (1024x1024, scale 0.62)
Make-Icon -outPath "$assetsDir\launcher_icon.png" -size 1024 -contentScale 0.62

# Adaptive foreground (1024x1024, scale 0.54 - extra padding for circle mask)
Make-Icon -outPath "$assetsDir\launcher_icon_foreground.png" -size 1024 -contentScale 0.54

Write-Host "`nIconos generados exitosamente!"
