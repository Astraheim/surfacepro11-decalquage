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

function Set-ZoomValue([int]$val) {
    $val = [Math]::Max(10,[Math]::Min(200,$val))
    $script:imageScale = $val / 100.0
    if ($script:lblZoomVal -and -not $script:lblZoomVal.IsDisposed) { $script:lblZoomVal.Text = "$val %" }
    if ($script:imagePanel -and -not $script:imagePanel.IsDisposed) { $script:imagePanel.Invalidate() }
}

function Toggle-ToolbarCollapse {
    if (-not $script:toolbarForm -or $script:toolbarForm.IsDisposed) { return }
    $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    if ($script:toolbarExpanded) {
        foreach ($c in $script:toolbarOtherControls) { $c.Visible = $false }
        $script:toolbarForm.ClientSize = New-Object Drawing.Size($script:toolbarForm.ClientSize.Width, $script:toolbarCollapsedH)
        if ($script:btnCollapseRef) { $script:btnCollapseRef.Text = "Agrandir v" }
        $script:toolbarExpanded = $false
    } else {
        foreach ($c in $script:toolbarOtherControls) { $c.Visible = $true }
        if ($script:toolbarExpandedSize) { $script:toolbarForm.ClientSize = $script:toolbarExpandedSize }
        if ($script:btnCollapseRef) { $script:btnCollapseRef.Text = "Reduire ^" }
        $script:toolbarExpanded = $true
    }
    $script:toolbarForm.Left = $wa2.X + $wa2.Width - $script:toolbarForm.Width - 20
    Bring-ToolbarToFront
}

function Bring-ToolbarToFront {
    if ($script:toolbarForm -and -not $script:toolbarForm.IsDisposed) {
        $script:toolbarForm.TopMost = $false
        $script:toolbarForm.TopMost = $true
    }
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
# Règle la luminosité PUIS relit la vraie valeur matérielle : évite tout
# désynchronisage entre le % affiché et l'écran réel (pilote/luminosité
# adaptative pouvant arrondir ou ignorer la valeur demandée).
function Nudge-Brightness([int]$delta) {
    $target = [Math]::Max(5,[Math]::Min(100,$script:currentBrightness + $delta))
    Set-Brightness $target
    Start-Sleep -Milliseconds 150
    $real = Get-CurrentBrightness
    $script:currentBrightness = $real
    return $real
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
$script:gridThickness    = 2
$script:imageScale       = 1.0
$script:touchLockedByUs  = $false
$script:closingInProgress = $false
$script:brightSupported  = Get-BrightnessSupported
$script:currentBrightness = if ($script:brightSupported) { [Math]::Max(5,(Get-CurrentBrightness)) } else { 100 }
$script:lblZoomVal       = $null
$script:lblBrightToolVal = $null
$script:toolbarExpanded  = $true
$script:toolbarExpandedSize = $null
$script:toolbarCollapsedH   = 60
$script:toolbarOtherControls = @()
$script:btnCollapseRef   = $null

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
                try {
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
                } catch {}
            }
            if ($script:showGrid) {
                try {
                    $thick = [Math]::Max(1,[int]$script:gridThickness)
                    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(190,124,92,255)), $thick
                    for ($x = 0; $x -lt $s.Width; $x += $script:gridSpacing) { $g.DrawLine($pen,$x,0,$x,$s.Height) }
                    for ($y = 0; $y -lt $s.Height; $y += $script:gridSpacing) { $g.DrawLine($pen,0,$y,$s.Width,$y) }
                    $pen.Dispose()
                } catch {}
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
        elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::M) { Toggle-ToolbarCollapse }
    })
    # Toucher/cliquer l'image amène naturellement imgForm au premier plan,
    # ce qui passe la barre d'outils DERRIÈRE elle (deux fenêtres "TopMost"
    # se disputent le dessus). On la reforce systématiquement au-dessus.
    $imgForm.Add_Activated({ Bring-ToolbarToFront })
    $panel.Add_MouseDown({ Bring-ToolbarToFront })

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

    # --- Bouton Réduire/Agrandir : toujours visible, même replié, pour
    #     libérer l'écran en plein écran sans perdre l'accès aux outils ---
    $btnCollapse = New-Btn "Reduire ^" 110 30 175 8 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 8 $true
    $toolbar.Controls.Add($btnCollapse)

    $lblHelp = New-Object System.Windows.Forms.Label
    $lblHelp.Text = "1. Redimensionne la fenetre (bords)`n2. Ajuste avec les boutons ci-dessous`n3. Verrouille quand c'est bon"
    $lblHelp.ForeColor = $C_SUBTEXT
    $lblHelp.AutoSize = $true
    $lblHelp.Location = New-Object Drawing.Point(15,46)
    $toolbar.Controls.Add($lblHelp)

    $btnFullscreen = New-Btn "Ajuster au plein ecran" 270 34 15 108 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 9 $false
    $btnFullscreen.Add_Click({
        if (-not $script:locked) {
            $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $script:imgForm.Bounds = New-Object Drawing.Rectangle($wa2.X, $wa2.Y, $wa2.Width, $wa2.Height)
        }
    })
    $toolbar.Controls.Add($btnFullscreen)

    # --- Taille de l'image : boutons +/- (fiables au tactile, contrairement
    #     à un curseur à glisser dont le tracé se perd facilement au doigt) ---
    $lblZoom = New-Object System.Windows.Forms.Label
    $lblZoom.Text = "Taille de l'image"
    $lblZoom.ForeColor = $C_TEXT
    $lblZoom.AutoSize = $true
    $lblZoom.Location = New-Object Drawing.Point(15,155)
    $toolbar.Controls.Add($lblZoom)

    $lblZoomVal = New-Object System.Windows.Forms.Label
    $lblZoomVal.Text = "100 %"
    $lblZoomVal.ForeColor = $C_TEXT
    $lblZoomVal.Font = New-Object Drawing.Font("Segoe UI",13,[Drawing.FontStyle]::Bold)
    $lblZoomVal.TextAlign = 'MiddleCenter'
    $lblZoomVal.Size = New-Object Drawing.Size(120,40)
    $lblZoomVal.Location = New-Object Drawing.Point(90,178)
    $toolbar.Controls.Add($lblZoomVal)
    $script:lblZoomVal = $lblZoomVal

    $btnZoomMinus = New-Btn "-" 70 40 15 178 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 16 $true
    $btnZoomMinus.Add_Click({ Set-ZoomValue ([int]($script:imageScale*100) - 5) })
    $toolbar.Controls.Add($btnZoomMinus)

    $btnZoomPlus = New-Btn "+" 70 40 215 178 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 16 $true
    $btnZoomPlus.Add_Click({ Set-ZoomValue ([int]($script:imageScale*100) + 5) })
    $toolbar.Controls.Add($btnZoomPlus)

    # --- Luminosité : disponible ici aussi, une fois l'image affichée
    #     (le curseur de la fenêtre principale n'est plus accessible) ---
    $lblBright = New-Object System.Windows.Forms.Label
    $lblBright.Text = "Luminosite de l'ecran"
    $lblBright.ForeColor = $C_TEXT
    $lblBright.AutoSize = $true
    $lblBright.Location = New-Object Drawing.Point(15,232)
    $toolbar.Controls.Add($lblBright)

    $lblBrightVal2 = New-Object System.Windows.Forms.Label
    $lblBrightVal2.Text = "$($script:currentBrightness) %"
    $lblBrightVal2.ForeColor = $C_TEXT
    $lblBrightVal2.Font = New-Object Drawing.Font("Segoe UI",13,[Drawing.FontStyle]::Bold)
    $lblBrightVal2.TextAlign = 'MiddleCenter'
    $lblBrightVal2.Size = New-Object Drawing.Size(120,40)
    $lblBrightVal2.Location = New-Object Drawing.Point(90,255)
    $toolbar.Controls.Add($lblBrightVal2)
    if (-not $script:brightSupported) { $lblBrightVal2.Text = "N/A" }

    $btnBrightMinus = New-Btn "-" 70 40 15 255 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 16 $true
    $btnBrightMinus.Enabled = $script:brightSupported
    $btnBrightMinus.Add_Click({
        $real = Nudge-Brightness -10
        $lblBrightVal2.Text = "$real %"
    })
    $toolbar.Controls.Add($btnBrightMinus)

    $btnBrightPlus = New-Btn "+" 70 40 215 255 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 16 $true
    $btnBrightPlus.Enabled = $script:brightSupported
    $btnBrightPlus.Add_Click({
        $real = Nudge-Brightness 10
        $lblBrightVal2.Text = "$real %"
    })
    $toolbar.Controls.Add($btnBrightPlus)

    $btnGrid = New-Object System.Windows.Forms.CheckBox
    $btnGrid.Text = "Grille legere"
    $btnGrid.ForeColor = $C_TEXT
    $btnGrid.Checked = $script:showGrid
    $btnGrid.AutoSize = $true
    $btnGrid.Location = New-Object Drawing.Point(15,308)
    $btnGrid.Add_CheckedChanged({ $script:showGrid = $btnGrid.Checked; if ($script:imagePanel) { $script:imagePanel.Invalidate() } })
    $toolbar.Controls.Add($btnGrid)

    $btnLock = New-Btn "VERROUILLER + DESACTIVER LE TACTILE" 270 52 15 340 $C_LOCK $C_LOCK_DK ([Drawing.Color]::White) 9 $true
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
    $lblSafety.Text = "ECHAP = tout annuler. CTRL+M = replier/deplier`ncette barre, meme si elle est hors de vue."
    $lblSafety.ForeColor = $C_SUBTEXT
    $lblSafety.Font = New-Object Drawing.Font("Segoe UI",7)
    $lblSafety.AutoSize = $true
    $lblSafety.Location = New-Object Drawing.Point(15,396)
    $toolbar.Controls.Add($lblSafety)

    $btnClose = New-Btn "Fermer l'image" 270 30 15 428 $C_STOP $C_STOP_DK ([Drawing.Color]::White) 9 $false
    $btnClose.Add_Click({ Close-ImageWindow })
    $toolbar.Controls.Add($btnClose)

    $toolbar.ClientSize = New-Object Drawing.Size(300,474)

    # --- Repli/dépli : réduit la barre à son seul bouton "Agrandir" pour
    #     ne pas gêner le dessin en plein écran. Logique dans la fonction
    #     globale Toggle-ToolbarCollapse (aussi appelable au clavier). ---
    $script:toolbarExpanded = $true
    $script:toolbarCollapsedH = $btnCollapse.Bottom + 15
    $script:toolbarOtherControls = @($toolbar.Controls) | Where-Object { $_ -ne $btnCollapse }
    $script:btnCollapseRef = $btnCollapse
    $btnCollapse.Add_Click({ Toggle-ToolbarCollapse })

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
        elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::M) { Toggle-ToolbarCollapse }
    })

    # --- Mise à l'échelle manuelle de la barre d'outils, PUIS on la
    #     positionne (avec sa largeur réelle une fois mise à l'échelle) ---
    if ($script:UIScale -ne 1.0) {
        $toolbar.Scale((New-Object Drawing.SizeF($script:UIScale,$script:UIScale)))
    }
    Apply-RoundedCorners $toolbar 10
    $script:toolbarExpandedSize = New-Object Drawing.Size($toolbar.ClientSize.Width, $toolbar.ClientSize.Height)
    $script:toolbarCollapsedH = [int]($script:toolbarCollapsedH * $script:UIScale)
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
$form.ClientSize = New-Object Drawing.Size(480,725)
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

$trkBright = New-Object System.Windows.Forms.TrackBar
$trkBright.Minimum = 5
$trkBright.Maximum = 100
$trkBright.TickFrequency = 10
$trkBright.Size = New-Object Drawing.Size(290,40)
$trkBright.Location = New-Object Drawing.Point(10,35)
$trkBright.Value = $script:currentBrightness
$trkBright.Enabled = $script:brightSupported
$panBright.Controls.Add($trkBright)

$lblBrightVal = New-Object System.Windows.Forms.Label
$lblBrightVal.Text = if ($script:brightSupported) { "$($trkBright.Value)%" } else { "N/A" }
$lblBrightVal.ForeColor = $C_TEXT
$lblBrightVal.Size = New-Object Drawing.Size(60,20)
$lblBrightVal.Location = New-Object Drawing.Point(320,42)
$panBright.Controls.Add($lblBrightVal)

$trkBright.Add_ValueChanged({
    try {
        $lblBrightVal.Text = "$($trkBright.Value)%"
        $script:currentBrightness = $trkBright.Value
        Set-Brightness $trkBright.Value
    } catch {}
})

# --- Panneau Options ---
$panOpt = New-Panel 400 195 40 325
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

$lblThick = New-Object System.Windows.Forms.Label
$lblThick.Text = "Épaisseur des lignes :"
$lblThick.ForeColor = $C_SUBTEXT
$lblThick.AutoSize = $true
$lblThick.Location = New-Object Drawing.Point(35,153)
$panOpt.Controls.Add($lblThick)

$numThick = New-Object System.Windows.Forms.NumericUpDown
$numThick.Minimum = 1
$numThick.Maximum = 6
$numThick.Value = 2
$numThick.Size = New-Object Drawing.Size(60,22)
$numThick.Location = New-Object Drawing.Point(220,151)
$numThick.Add_ValueChanged({ $script:gridThickness = [int]$numThick.Value; if ($script:imagePanel) { $script:imagePanel.Invalidate() } })
$panOpt.Controls.Add($numThick)

$lblThickUnit = New-Object System.Windows.Forms.Label
$lblThickUnit.Text = "px"
$lblThickUnit.ForeColor = $C_SUBTEXT
$lblThickUnit.AutoSize = $true
$lblThickUnit.Location = New-Object Drawing.Point(285,153)
$panOpt.Controls.Add($lblThickUnit)

# --- Bouton principal : afficher l'image (tactile encore actif) ---
$start = New-Btn "AFFICHER L'IMAGE   (tactile encore actif)" 400 55 40 540 $C_ACCENT $C_ACCENT_DK ([Drawing.Color]::White) 11 $true
$start.Add_Click({
    Set-Awake $true
    if ($script:brightSupported) { Set-Brightness $trkBright.Value }
    if ($chkOrientation.Checked) { Lock-Orientation $true }

    if (-not $script:imagePath) {
        [System.Windows.Forms.MessageBox]::Show("Choisis d'abord une image avec le bouton « Choisir... ».","Mode Décalquage","OK","Warning") | Out-Null
        return
    }
    Open-ImageWindow
})
$form.Controls.Add($start)

# --- Bouton secondaire : désactiver le tactile seul, sans image ---
$btnTouchOnly = New-Btn "Désactiver uniquement le tactile (sans image)" 400 34 40 605 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_SUBTEXT 8 $false
$btnTouchOnly.Add_Click({
    Set-Touch $false
    Set-Awake $true
    [System.Windows.Forms.MessageBox]::Show("Tactile désactivé.`n`nClique sur « RETOUR AU MODE NORMAL » pour le réactiver.","Mode Décalquage","OK","Information") | Out-Null
})
$form.Controls.Add($btnTouchOnly)

# --- Bouton retour ---
$stop = New-Btn "RETOUR AU MODE NORMAL" 400 55 40 649 $C_STOP $C_STOP_DK ([Drawing.Color]::White) 10 $true
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
