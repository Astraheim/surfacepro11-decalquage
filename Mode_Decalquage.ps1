# ============================================================
#  Mode Décalquage - Surface Pro
#  Affiche une image fixe en plein écran pour décalquer, avec
#  grille légère optionnelle, puis verrouille tactile + fenêtre
#  d'un seul clic une fois l'image bien placée.
# ============================================================

# --- DPI : rend le rendu net (pas de flou) SANS utiliser le mode
#     "Per-Monitor V2" (mal supporté par WinForms classique lancé
#     depuis un script -> plantages/mise en page cassée). On calcule
#     ensuite nous-mêmes un facteur d'échelle appliqué manuellement
#     à toute l'interface. ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")]
    public static extern uint GetDpiForSystem();
}
"@
try { [DpiHelper]::SetProcessDPIAware() | Out-Null } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:UIScale = 1.0
try {
    $sysDpi = [DpiHelper]::GetDpiForSystem()
    if ($sysDpi -gt 0) { $script:UIScale = $sysDpi / 96.0 }
} catch {}

# --- Masque la fenêtre console PowerShell ---
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
try {
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
} catch {}

# --- API Windows pour le verrouillage de la rotation d'écran ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RotationApi {
    [DllImport("user32.dll")]
    public static extern bool SetDisplayAutoRotationPreferences(uint orientation);
}
"@
$ORIENTATION_NONE      = 0
$ORIENTATION_LANDSCAPE = 1
$ORIENTATION_PORTRAIT  = 2

# --- Panel avec rendu haute qualité et double buffering ---
Add-Type -ReferencedAssemblies 'System.Windows.Forms','System.Drawing' -TypeDefinition @"
using System.Windows.Forms;
public class SmoothPanel : Panel {
    public SmoothPanel() {
        SetStyle(ControlStyles.OptimizedDoubleBuffer |
                  ControlStyles.AllPaintingInWmPaint |
                  ControlStyles.UserPaint |
                  ControlStyles.ResizeRedraw, true);
    }
}
"@

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

# ============================================================
#  PALETTE — thème sombre
# ============================================================
$C_BG        = [Drawing.Color]::FromArgb(255, 27, 27, 47)
$C_PANEL     = [Drawing.Color]::FromArgb(255, 36, 36, 68)
$C_TEXT      = [Drawing.Color]::FromArgb(255, 245, 245, 250)
$C_SUBTEXT   = [Drawing.Color]::FromArgb(255, 168, 168, 196)
$C_ACCENT    = [Drawing.Color]::FromArgb(255, 124, 92, 255)
$C_ACCENT_DK = [Drawing.Color]::FromArgb(255, 99, 70, 224)
$C_LOCK      = [Drawing.Color]::FromArgb(255, 34, 197, 94)
$C_LOCK_DK   = [Drawing.Color]::FromArgb(255, 22, 163, 74)
$C_STOP      = [Drawing.Color]::FromArgb(255, 239, 68, 68)
$C_STOP_DK   = [Drawing.Color]::FromArgb(255, 200, 45, 45)

# Arrondi les coins d'un contrôle. Le rayon est automatiquement réduit
# si le contrôle est trop petit (évite toute erreur / forme absurde).
function Set-RoundedCorners($ctrl, $radius) {
    $w = $ctrl.Width; $h = $ctrl.Height
    if ($w -le 0 -or $h -le 0) { return }
    $r = [Math]::Min($radius, [Math]::Floor([Math]::Min($w,$h) / 2))
    if ($r -lt 2) { $ctrl.Region = $null; return }
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0,0,$r,$r,180,90)
    $path.AddArc($w-$r,0,$r,$r,270,90)
    $path.AddArc($w-$r,$h-$r,$r,$r,0,90)
    $path.AddArc(0,$h-$r,$r,$r,90,90)
    $path.CloseFigure()
    $ctrl.Region = New-Object Drawing.Region($path)
}

# Parcourt récursivement un conteneur et arrondit tous les boutons/panneaux.
# Appelé APRÈS la mise à l'échelle, pour arrondir en fonction de la
# taille réelle finale (et non de la taille "de conception").
function Apply-RoundedCorners($container, $radius) {
    foreach ($c in @($container.Controls)) {
        if ($c -is [System.Windows.Forms.Button] -or ($c -is [System.Windows.Forms.Panel] -and $c.Height -gt 50)) {
            Set-RoundedCorners $c $radius
        }
        if ($c.Controls -and $c.Controls.Count -gt 0) { Apply-RoundedCorners $c $radius }
    }
}

function New-Btn($text, $w, $h, $x, $y, $bg, $bgHover, $fg, $fontSize, $bold) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Size = New-Object Drawing.Size($w,$h)
    $b.Location = New-Object Drawing.Point($x,$y)
    $b.BackColor = $bg
    $b.ForeColor = $fg
    $style = if ($bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $b.Font = New-Object Drawing.Font("Segoe UI",$fontSize,$style)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.TextAlign = 'MiddleCenter'
    $b.Add_MouseEnter({ $b.BackColor = $bgHover }.GetNewClosure())
    $b.Add_MouseLeave({ $b.BackColor = $bg }.GetNewClosure())
    return $b
}

function New-Panel($w,$h,$x,$y) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Size = New-Object Drawing.Size($w,$h)
    $p.Location = New-Object Drawing.Point($x,$y)
    $p.BackColor = $C_PANEL
    return $p
}

function New-Header($text,$x,$y) {
    $bar = New-Object System.Windows.Forms.Panel
    $bar.Size = New-Object Drawing.Size(4,16)
    $bar.Location = New-Object Drawing.Point($x,($y+2))
    $bar.BackColor = $C_ACCENT

    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text.ToUpper()
    $l.AutoSize = $true
    $l.Location = New-Object Drawing.Point(($x+12),$y)
    $l.ForeColor = $C_ACCENT
    $l.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)

    return @($bar,$l)
}

# ============================================================
#  TACTILE
# ============================================================
function Get-TouchDevices {
    Get-PnpDevice -PresentOnly | Where-Object {
        $_.FriendlyName -match '(?i)touch screen|écran tactile'
    }
}
function Restore-TouchIfNeeded {
    if ($script:touchLockedByUs) {
        Set-Touch $true
        $script:touchLockedByUs = $false
    }
    $script:locked = $false
}

function Set-Touch([bool]$Enable) {
    $devices = @(Get-TouchDevices)
    if ($devices.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Aucun écran tactile n'a été trouvé.`n`nLes autres réglages seront quand même appliqués.",
            "Mode Décalquage", "OK", "Warning"
        ) | Out-Null
        return
    }
    foreach ($d in $devices) {
        try {
            if ($Enable) { Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop }
            else { Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Impossible de modifier : $($d.FriendlyName)`n`n$($_.Exception.Message)",
                "Mode Décalquage", "OK", "Error"
            ) | Out-Null
        }
    }
}

# ============================================================
#  ALIMENTATION / VEILLE
# ============================================================
function Set-Awake([bool]$Decalquage) {
    if ($Decalquage) {
        powercfg /change monitor-timeout-ac 0
        powercfg /change standby-timeout-ac 0
    } else {
        powercfg /change monitor-timeout-ac 15
        powercfg /change standby-timeout-ac 30
    }
}

# ============================================================
#  LUMINOSITÉ (écran interne via WMI)
# ============================================================
function Get-BrightnessSupported {
    try { Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightness -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}
function Get-CurrentBrightness {
    try { return [int](Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightness -ErrorAction Stop).CurrentBrightness }
    catch { return 100 }
}
function Set-Brightness([int]$Level) {
    try { (Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightnessMethods -ErrorAction Stop).WmiSetBrightness(1, $Level) | Out-Null }
    catch {}
}

# ============================================================
#  ROTATION D'ÉCRAN
# ============================================================
function Get-CurrentOrientationValue {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    if ($b.Width -ge $b.Height) { return $ORIENTATION_LANDSCAPE } else { return $ORIENTATION_PORTRAIT }
}
function Lock-Orientation([bool]$Lock) {
    if ($Lock) { [RotationApi]::SetDisplayAutoRotationPreferences((Get-CurrentOrientationValue)) | Out-Null }
    else { [RotationApi]::SetDisplayAutoRotationPreferences($ORIENTATION_NONE) | Out-Null }
}

# ============================================================
#  ÉTAT PARTAGÉ
# ============================================================
$script:imagePath        = $null
$script:currentImage     = $null
$script:imgForm          = $null
$script:toolbarForm      = $null
$script:imagePanel       = $null
$script:locked           = $false
$script:lockedBounds     = $null
$script:showGrid         = $false
$script:gridSpacing      = 50
$script:imageScale       = 1.0
$script:touchLockedByUs  = $false
$script:closingInProgress = $false

# ============================================================
#  FENÊTRE IMAGE + BARRE D'OUTILS FLOTTANTE
# ============================================================
function Close-ImageWindow {
    # Un seul point d'entrée : ferme imgForm, dont le FormClosing se
    # charge de fermer le toolbar (voir garde anti-récursion plus bas).
    if ($script:imgForm -and -not $script:imgForm.IsDisposed) {
        $script:imgForm.Close()
    } elseif ($script:toolbarForm -and -not $script:toolbarForm.IsDisposed) {
        $script:toolbarForm.Close()
    }
    $script:imgForm = $null
    $script:toolbarForm = $null
    $script:imagePanel = $null
    $script:closingInProgress = $false
}

function Open-ImageWindow {
    if (-not $script:imagePath -or -not (Test-Path $script:imagePath)) { return }
    Close-ImageWindow
    $script:closingInProgress = $false
    $script:imageScale = 1.0

    if ($script:currentImage) { $script:currentImage.Dispose() }
    $script:currentImage = [Drawing.Image]::FromFile($script:imagePath)

    $imgForm = New-Object System.Windows.Forms.Form
    $imgForm.Text = "Décalquage"
    $imgForm.AutoScaleMode = 'None'
    $imgForm.BackColor = [Drawing.Color]::Black
    $imgForm.FormBorderStyle = 'SizableToolWindow'
    $imgForm.TopMost = $true
    $imgForm.ShowInTaskbar = $false
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $imgForm.Bounds = New-Object Drawing.Rectangle($wa.X, $wa.Y, $wa.Width, $wa.Height)

    $panel = New-Object SmoothPanel
    $panel.Dock = 'Fill'
    $panel.BackColor = [Drawing.Color]::Black
    $panel.Add_Paint({
        param($s,$e)
        try {
            if ($s.Width -le 0 -or $s.Height -le 0) { return }
            $g = $e.Graphics
            $g.SmoothingMode = 'AntiAlias'
            $g.InterpolationMode = 'HighQualityBicubic'
            $g.PixelOffsetMode = 'HighQuality'
            $g.CompositingQuality = 'HighQuality'

            if ($script:currentImage) {
                $img = $script:currentImage
                $ratioImg = $img.Width / $img.Height
                $ratioBox = $s.Width / $s.Height
                if ($ratioImg -gt $ratioBox) {
                    $fitW = $s.Width
                    $fitH = [int]($s.Width / $ratioImg)
                } else {
                    $fitH = $s.Height
                    $fitW = [int]($s.Height * $ratioImg)
                }
                $drawW = [Math]::Max(1,[int]($fitW * $script:imageScale))
                $drawH = [Math]::Max(1,[int]($fitH * $script:imageScale))
                $drawX = [int](($s.Width  - $drawW) / 2)
                $drawY = [int](($s.Height - $drawH) / 2)
                $g.DrawImage($img, $drawX, $drawY, $drawW, $drawH)
            }
            if ($script:showGrid) {
                $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(70,255,255,255)), 1
                for ($x = 0; $x -lt $s.Width; $x += $script:gridSpacing) { $g.DrawLine($pen,$x,0,$x,$s.Height) }
                for ($y = 0; $y -lt $s.Height; $y += $script:gridSpacing) { $g.DrawLine($pen,0,$y,$s.Width,$y) }
                $pen.Dispose()
            }
        } catch {}
    })
    $imgForm.Controls.Add($panel)

    $imgForm.Add_LocationChanged({
        if ($script:locked -and $script:lockedBounds -and $script:imgForm.Bounds -ne $script:lockedBounds) {
            $script:imgForm.Bounds = $script:lockedBounds
        }
    })
    $imgForm.Add_SizeChanged({
        if ($script:locked -and $script:lockedBounds -and $script:imgForm.Bounds -ne $script:lockedBounds) {
            $script:imgForm.Bounds = $script:lockedBounds
        }
    })
    $imgForm.Add_FormClosing({
        if ($script:closingInProgress) { return }
        $script:closingInProgress = $true
        Restore-TouchIfNeeded
        if ($script:toolbarForm -and -not $script:toolbarForm.IsDisposed) { $script:toolbarForm.Close() }
    })
    $imgForm.KeyPreview = $true
    $imgForm.Add_KeyDown({
        param($s,$e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { Close-ImageWindow }
    })

    $script:imgForm = $imgForm
    $script:imagePanel = $panel

    # --- Barre d'outils flottante (construite en tailles "de conception",
    #     puis mise à l'échelle et repositionnée à la fin) ---
    $toolbar = New-Object System.Windows.Forms.Form
    $toolbar.Text = "Outils décalquage"
    $toolbar.AutoScaleMode = 'None'
    $toolbar.FormBorderStyle = 'FixedToolWindow'
    $toolbar.TopMost = $true
    $toolbar.ShowInTaskbar = $false
    $toolbar.StartPosition = 'Manual'
    $toolbar.BackColor = $C_BG
    $toolbar.Font = New-Object Drawing.Font("Segoe UI",9)

    $lblHelp = New-Object System.Windows.Forms.Label
    $lblHelp.Text = "1. Redimensionne la fenetre (bords) ou`n    fais glisser la barre ci-dessous`n2. Verrouille quand c'est bon"
    $lblHelp.ForeColor = $C_SUBTEXT
    $lblHelp.AutoSize = $true
    $lblHelp.Location = New-Object Drawing.Point(15,12)
    $toolbar.Controls.Add($lblHelp)

    $btnFullscreen = New-Btn "Ajuster au plein ecran" 270 34 15 75 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 9 $false
    $btnFullscreen.Add_Click({
        if (-not $script:locked) {
            $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $script:imgForm.Bounds = New-Object Drawing.Rectangle($wa2.X, $wa2.Y, $wa2.Width, $wa2.Height)
        }
    })
    $toolbar.Controls.Add($btnFullscreen)

    $lblZoom = New-Object System.Windows.Forms.Label
    $lblZoom.Text = "Taille de l'image : 100 %"
    $lblZoom.ForeColor = $C_TEXT
    $lblZoom.AutoSize = $true
    $lblZoom.Location = New-Object Drawing.Point(15,122)
    $toolbar.Controls.Add($lblZoom)

    # --- Curseur tactile personnalisé : toute la barre est cliquable/
    #     glissable (plus fiable au doigt qu'un curseur natif, dont le
    #     petit "plot" est difficile à attraper avec le tactile). ---
    $ZOOM_MIN = 10
    $ZOOM_MAX = 200
    $zoomBar = New-Object SmoothPanel
    $zoomBar.Size = New-Object Drawing.Size(270,36)
    $zoomBar.Location = New-Object Drawing.Point(15,146)
    $zoomBar.BackColor = [Drawing.Color]::FromArgb(255,50,50,90)
    $zoomBar.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:zoomDragging = $false

    $updateZoomFromX = {
        param($panelWidth,$xPos)
        $ratio = [Math]::Max(0.0,[Math]::Min(1.0, $xPos / [double]$panelWidth))
        $val = [int]($ZOOM_MIN + $ratio * ($ZOOM_MAX - $ZOOM_MIN))
        $script:imageScale = $val / 100.0
        $lblZoom.Text = "Taille de l'image : $val %"
        $zoomBar.Invalidate()
        if ($script:imagePanel -and -not $script:imagePanel.IsDisposed) { $script:imagePanel.Invalidate() }
    }

    $zoomBar.Add_Paint({
        param($s,$e)
        try {
            $ratio = ($script:imageScale * 100 - $ZOOM_MIN) / [double]($ZOOM_MAX - $ZOOM_MIN)
            $ratio = [Math]::Max(0.0,[Math]::Min(1.0,$ratio))
            $fillW = [int]($s.Width * $ratio)
            $brush = New-Object Drawing.SolidBrush($C_ACCENT)
            $e.Graphics.FillRectangle($brush, 0, 0, $fillW, $s.Height)
            $brush.Dispose()
        } catch {}
    })
    $zoomBar.Add_MouseDown({
        param($s,$e)
        $script:zoomDragging = $true
        $s.Capture = $true
        & $updateZoomFromX $s.Width $e.X
    })
    $zoomBar.Add_MouseMove({
        param($s,$e)
        if ($script:zoomDragging) { & $updateZoomFromX $s.Width $e.X }
    })
    $zoomBar.Add_MouseUp({
        param($s,$e)
        $script:zoomDragging = $false
        $s.Capture = $false
    })
    $toolbar.Controls.Add($zoomBar)

    $btnReset = New-Btn "Reinitialiser (100 %)" 270 28 15 190 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_SUBTEXT 8 $false
    $btnReset.Add_Click({
        $script:imageScale = 1.0
        $lblZoom.Text = "Taille de l'image : 100 %"
        $zoomBar.Invalidate()
        if ($script:imagePanel -and -not $script:imagePanel.IsDisposed) { $script:imagePanel.Invalidate() }
    })
    $toolbar.Controls.Add($btnReset)

    $btnGrid = New-Object System.Windows.Forms.CheckBox
    $btnGrid.Text = "Grille legere"
    $btnGrid.ForeColor = $C_TEXT
    $btnGrid.AutoSize = $true
    $btnGrid.Location = New-Object Drawing.Point(15,228)
    $btnGrid.Add_CheckedChanged({ $script:showGrid = $btnGrid.Checked; if ($script:imagePanel) { $script:imagePanel.Invalidate() } })
    $toolbar.Controls.Add($btnGrid)

    $btnLock = New-Btn "VERROUILLER + DESACTIVER LE TACTILE" 270 52 15 258 $C_LOCK $C_LOCK_DK ([Drawing.Color]::White) 9 $true
    $btnLock.Add_Click({
        if (-not $script:locked) {
            $script:lockedBounds = $script:imgForm.Bounds
            $script:imgForm.FormBorderStyle = 'None'
            $script:locked = $true
            Set-Touch $false
            $script:touchLockedByUs = $true
            $btnLock.Text = "DEVERROUILLER (reactive le tactile)"
            $btnLock.BackColor = $C_ACCENT
        } else {
            $script:locked = $false
            $script:imgForm.FormBorderStyle = 'SizableToolWindow'
            $script:imgForm.Bounds = $script:lockedBounds
            Set-Touch $true
            $script:touchLockedByUs = $false
            $btnLock.Text = "VERROUILLER + DESACTIVER LE TACTILE"
            $btnLock.BackColor = $C_LOCK
        }
    })
    $toolbar.Controls.Add($btnLock)

    $lblSafety = New-Object System.Windows.Forms.Label
    $lblSafety.Text = "Astuce : si l'ecran clignote en noir un instant, c'est`nle pilote tactile qui redemarre - attends 2-3 sec.`nBloque(e) ? Touche ECHAP annule tout, meme si l'ecran`nest noir."
    $lblSafety.ForeColor = $C_SUBTEXT
    $lblSafety.Font = New-Object Drawing.Font("Segoe UI",7)
    $lblSafety.AutoSize = $true
    $lblSafety.Location = New-Object Drawing.Point(15,314)
    $toolbar.Controls.Add($lblSafety)

    $btnClose = New-Btn "Fermer l'image" 270 30 15 370 $C_STOP $C_STOP_DK ([Drawing.Color]::White) 9 $false
    $btnClose.Add_Click({ Close-ImageWindow })
    $toolbar.Controls.Add($btnClose)

    $toolbar.ClientSize = New-Object Drawing.Size(300,415)

    $toolbar.Add_FormClosing({
        if ($script:closingInProgress) { return }
        $script:closingInProgress = $true
        Restore-TouchIfNeeded
        if ($script:imgForm -and -not $script:imgForm.IsDisposed) { $script:imgForm.Close() }
    })
    $toolbar.KeyPreview = $true
    $toolbar.Add_KeyDown({
        param($s,$e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { Close-ImageWindow }
    })

    # --- Mise à l'échelle manuelle de la barre d'outils, PUIS on la
    #     positionne (avec sa largeur réelle une fois mise à l'échelle) ---
    if ($script:UIScale -ne 1.0) {
        $toolbar.Scale((New-Object Drawing.SizeF($script:UIScale,$script:UIScale)))
    }
    Apply-RoundedCorners $toolbar 10
    $toolbar.Location = New-Object Drawing.Point(($wa.X + $wa.Width - $toolbar.Width - 20), ($wa.Y + 20))

    $script:toolbarForm = $toolbar
    $imgForm.Show()
    $toolbar.Show()
}

# ============================================================
#  FENÊTRE PRINCIPALE
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Mode Décalquage"
$form.AutoScaleMode = 'None'
$form.ClientSize = New-Object Drawing.Size(480,700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $C_BG
$form.Font = New-Object Drawing.Font("Segoe UI",10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "MODE DECALQUAGE"
$title.Font = New-Object Drawing.Font("Segoe UI",20,[Drawing.FontStyle]::Bold)
$title.ForeColor = $C_TEXT
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(40,20)
$form.Controls.Add($title)

$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object Drawing.Size(60,4)
$titleBar.Location = New-Object Drawing.Point(42,62)
$titleBar.BackColor = $C_ACCENT
$form.Controls.Add($titleBar)

$info = New-Object System.Windows.Forms.Label
$info.Text = "Choisis ton image, regle les options, affiche-la, ajuste-la`n(bords ou curseur), puis verrouille."
$info.ForeColor = $C_SUBTEXT
$info.AutoSize = $true
$info.Location = New-Object Drawing.Point(42,78)
$form.Controls.Add($info)

# --- Panneau Image ---
$panImage = New-Panel 400 85 40 130
$form.Controls.Add($panImage)
foreach ($ctl in (New-Header "Image" 15 10)) { $panImage.Controls.Add($ctl) }

$lblImage = New-Object System.Windows.Forms.Label
$lblImage.Text = "Aucune image sélectionnée"
$lblImage.ForeColor = $C_SUBTEXT
$lblImage.AutoEllipsis = $true
$lblImage.Size = New-Object Drawing.Size(230,20)
$lblImage.Location = New-Object Drawing.Point(15,42)
$panImage.Controls.Add($lblImage)

$btnChoose = New-Btn "Choisir..." 130 32 255 38 $C_ACCENT $C_ACCENT_DK ([Drawing.Color]::White) 9 $true
$btnChoose.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Images (*.jpg;*.jpeg;*.png;*.bmp;*.gif)|*.jpg;*.jpeg;*.png;*.bmp;*.gif|Tous les fichiers (*.*)|*.*"
    if ($ofd.ShowDialog() -eq 'OK') {
        $script:imagePath = $ofd.FileName
        $lblImage.Text = [System.IO.Path]::GetFileName($ofd.FileName)
        $lblImage.ForeColor = $C_TEXT
        if ($script:imgForm) { Open-ImageWindow }
    }
})
$panImage.Controls.Add($btnChoose)

# --- Panneau Luminosité ---
$panBright = New-Panel 400 85 40 225
$form.Controls.Add($panBright)
foreach ($ctl in (New-Header "Luminosite de l'ecran" 15 10)) { $panBright.Controls.Add($ctl) }

$brightSupported = Get-BrightnessSupported
$trkBright = New-Object System.Windows.Forms.TrackBar
$trkBright.Minimum = 5
$trkBright.Maximum = 100
$trkBright.TickFrequency = 10
$trkBright.Size = New-Object Drawing.Size(290,40)
$trkBright.Location = New-Object Drawing.Point(10,35)
$trkBright.Value = if ($brightSupported) { [Math]::Max(5,(Get-CurrentBrightness)) } else { 100 }
$trkBright.Enabled = $brightSupported
$panBright.Controls.Add($trkBright)

$lblBrightVal = New-Object System.Windows.Forms.Label
$lblBrightVal.Text = if ($brightSupported) { "$($trkBright.Value)%" } else { "N/A" }
$lblBrightVal.ForeColor = $C_TEXT
$lblBrightVal.Size = New-Object Drawing.Size(60,20)
$lblBrightVal.Location = New-Object Drawing.Point(320,42)
$panBright.Controls.Add($lblBrightVal)

$trkBright.Add_ValueChanged({ try { $lblBrightVal.Text = "$($trkBright.Value)%"; Set-Brightness $trkBright.Value } catch {} })

# --- Panneau Options ---
$panOpt = New-Panel 400 170 40 325
$form.Controls.Add($panOpt)
foreach ($ctl in (New-Header "Options" 15 10)) { $panOpt.Controls.Add($ctl) }

$chkOrientation = New-Object System.Windows.Forms.CheckBox
$chkOrientation.Text = "Verrouiller l'orientation de l'écran"
$chkOrientation.ForeColor = $C_TEXT
$chkOrientation.AutoSize = $true
$chkOrientation.Location = New-Object Drawing.Point(15,40)
$panOpt.Controls.Add($chkOrientation)

$chkGridMain = New-Object System.Windows.Forms.CheckBox
$chkGridMain.Text = "Afficher une grille légère sur l'image"
$chkGridMain.ForeColor = $C_TEXT
$chkGridMain.AutoSize = $true
$chkGridMain.Location = New-Object Drawing.Point(15,70)
$chkGridMain.Add_CheckedChanged({ $script:showGrid = $chkGridMain.Checked; if ($script:imagePanel) { $script:imagePanel.Invalidate() } })
$panOpt.Controls.Add($chkGridMain)

$lblSpacing = New-Object System.Windows.Forms.Label
$lblSpacing.Text = "Taille des cases de la grille :"
$lblSpacing.ForeColor = $C_SUBTEXT
$lblSpacing.AutoSize = $true
$lblSpacing.Location = New-Object Drawing.Point(35,100)
$panOpt.Controls.Add($lblSpacing)

$numSpacing = New-Object System.Windows.Forms.NumericUpDown
$numSpacing.Minimum = 10
$numSpacing.Maximum = 300
$numSpacing.Value = 50
$numSpacing.Size = New-Object Drawing.Size(60,22)
$numSpacing.Location = New-Object Drawing.Point(220,98)
$numSpacing.Add_ValueChanged({ $script:gridSpacing = [int]$numSpacing.Value; if ($script:imagePanel) { $script:imagePanel.Invalidate() } })
$panOpt.Controls.Add($numSpacing)

$lblSpacingUnit = New-Object System.Windows.Forms.Label
$lblSpacingUnit.Text = "px"
$lblSpacingUnit.ForeColor = $C_SUBTEXT
$lblSpacingUnit.AutoSize = $true
$lblSpacingUnit.Location = New-Object Drawing.Point(285,100)
$panOpt.Controls.Add($lblSpacingUnit)

$lblSpacingHelp = New-Object System.Windows.Forms.Label
$lblSpacingHelp.Text = "= distance en pixels entre 2 lignes (petit nombre = grille plus serrée)"
$lblSpacingHelp.ForeColor = $C_SUBTEXT
$lblSpacingHelp.Font = New-Object Drawing.Font("Segoe UI",8)
$lblSpacingHelp.AutoSize = $true
$lblSpacingHelp.Location = New-Object Drawing.Point(35,125)
$panOpt.Controls.Add($lblSpacingHelp)

# --- Bouton principal : afficher l'image (tactile encore actif) ---
$start = New-Btn "AFFICHER L'IMAGE   (tactile encore actif)" 400 55 40 515 $C_ACCENT $C_ACCENT_DK ([Drawing.Color]::White) 11 $true
$start.Add_Click({
    Set-Awake $true
    if ($brightSupported) { Set-Brightness $trkBright.Value }
    if ($chkOrientation.Checked) { Lock-Orientation $true }

    if (-not $script:imagePath) {
        [System.Windows.Forms.MessageBox]::Show("Choisis d'abord une image avec le bouton « Choisir... ».","Mode Décalquage","OK","Warning") | Out-Null
        return
    }
    Open-ImageWindow
})
$form.Controls.Add($start)

# --- Bouton secondaire : désactiver le tactile seul, sans image ---
$btnTouchOnly = New-Btn "Désactiver uniquement le tactile (sans image)" 400 34 40 580 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_SUBTEXT 8 $false
$btnTouchOnly.Add_Click({
    Set-Touch $false
    Set-Awake $true
    [System.Windows.Forms.MessageBox]::Show("Tactile désactivé.`n`nClique sur « RETOUR AU MODE NORMAL » pour le réactiver.","Mode Décalquage","OK","Information") | Out-Null
})
$form.Controls.Add($btnTouchOnly)

# --- Bouton retour ---
$stop = New-Btn "RETOUR AU MODE NORMAL" 400 55 40 624 $C_STOP $C_STOP_DK ([Drawing.Color]::White) 10 $true
$stop.Add_Click({
    Set-Touch $true
    Set-Awake $false
    Lock-Orientation $false
    Close-ImageWindow
    [System.Windows.Forms.MessageBox]::Show(
        "Mode normal restauré.`n`nTactile : réactivé`nOrientation : déverrouillée`nAlimentation : valeurs normales.",
        "Mode normal", "OK", "Information"
    ) | Out-Null
})
$form.Controls.Add($stop)

$form.Add_FormClosing({ Close-ImageWindow })

# --- Mise à l'échelle manuelle de la fenêtre principale (une seule fois,
#     après avoir ajouté tous les contrôles), puis arrondis ---
if ($script:UIScale -ne 1.0) {
    $form.Scale((New-Object Drawing.SizeF($script:UIScale,$script:UIScale)))
}
Apply-RoundedCorners $form 10

$form.ShowDialog() | Out-Null
