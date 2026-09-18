# ============================================================
#  Mode Décalquage - Surface Pro
#  Bloque le tactile, garde l'écran allumé, affiche une image
#  fixe en plein écran (avec grille légère optionnelle) pour
#  décalquer directement sur l'écran.
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- API Windows pour le verrouillage de la rotation d'écran ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RotationApi {
    [DllImport("user32.dll")]
    public static extern bool SetDisplayAutoRotationPreferences(uint orientation);
    [DllImport("user32.dll")]
    public static extern bool GetDisplayAutoRotationPreferences(out uint orientation);
}
"@

# Valeurs de ORIENTATION_PREFERENCE
$ORIENTATION_NONE              = 0
$ORIENTATION_LANDSCAPE         = 1
$ORIENTATION_PORTRAIT          = 2
$ORIENTATION_LANDSCAPE_FLIPPED = 4
$ORIENTATION_PORTRAIT_FLIPPED  = 8

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ============================================================
#  TACTILE
# ============================================================
function Get-TouchDevices {
    Get-PnpDevice -PresentOnly | Where-Object {
        $_.FriendlyName -match '(?i)touch screen|écran tactile'
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
            if ($Enable) {
                Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
            } else {
                Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
            }
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
    try {
        Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightness -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Get-CurrentBrightness {
    try {
        $b = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightness -ErrorAction Stop
        return [int]$b.CurrentBrightness
    } catch { return 100 }
}

function Set-Brightness([int]$Level) {
    try {
        $method = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightnessMethods -ErrorAction Stop
        $method.WmiSetBrightness(1, $Level) | Out-Null
    } catch {
        # Pas grave si non supporté (ex : écran externe sans DDC/CI)
    }
}

# ============================================================
#  ROTATION D'ÉCRAN
# ============================================================
function Get-CurrentOrientationValue {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    if ($bounds.Width -ge $bounds.Height) { return $ORIENTATION_LANDSCAPE }
    else { return $ORIENTATION_PORTRAIT }
}

function Lock-Orientation([bool]$Lock) {
    if ($Lock) {
        [RotationApi]::SetDisplayAutoRotationPreferences((Get-CurrentOrientationValue)) | Out-Null
    } else {
        [RotationApi]::SetDisplayAutoRotationPreferences($ORIENTATION_NONE) | Out-Null
    }
}

# ============================================================
#  ÉTAT PARTAGÉ
# ============================================================
$script:imagePath   = $null
$script:imgForm      = $null
$script:toolbarForm  = $null
$script:pictureBox   = $null
$script:locked       = $false
$script:lockedBounds = $null
$script:showGrid     = $false
$script:gridSpacing  = 50

# ============================================================
#  FENÊTRE IMAGE + BARRE D'OUTILS FLOTTANTE
# ============================================================
function Close-ImageWindow {
    if ($script:toolbarForm) { $script:toolbarForm.Close(); $script:toolbarForm = $null }
    if ($script:imgForm)     { $script:imgForm.Close();     $script:imgForm = $null }
    $script:locked = $false
}

function Open-ImageWindow {
    if (-not $script:imagePath -or -not (Test-Path $script:imagePath)) { return }

    Close-ImageWindow

    # --- Fenêtre image ---
    $imgForm = New-Object System.Windows.Forms.Form
    $imgForm.Text = "Décalquage"
    $imgForm.BackColor = [Drawing.Color]::Black
    $imgForm.FormBorderStyle = 'SizableToolWindow'
    $imgForm.TopMost = $true
    $imgForm.ShowInTaskbar = $false
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $imgForm.Bounds = New-Object Drawing.Rectangle($wa.X, $wa.Y, $wa.Width, $wa.Height)

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Dock = 'Fill'
    $pictureBox.SizeMode = 'Zoom'
    $pictureBox.BackColor = [Drawing.Color]::Black
    $pictureBox.Image = [Drawing.Image]::FromFile($script:imagePath)
    $pictureBox.Add_Paint({
        param($s, $e)
        if ($script:showGrid) {
            $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(70,255,255,255)), 1
            for ($x = 0; $x -lt $s.Width; $x += $script:gridSpacing) {
                $e.Graphics.DrawLine($pen, $x, 0, $x, $s.Height)
            }
            for ($y = 0; $y -lt $s.Height; $y += $script:gridSpacing) {
                $e.Graphics.DrawLine($pen, 0, $y, $s.Width, $y)
            }
            $pen.Dispose()
        }
    })
    $imgForm.Controls.Add($pictureBox)

    # Empêche tout déplacement/redimensionnement une fois verrouillé
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
    $imgForm.Add_FormClosing({ $script:locked = $false })

    $script:imgForm = $imgForm
    $script:pictureBox = $pictureBox

    # --- Petite barre d'outils flottante toujours visible ---
    $toolbar = New-Object System.Windows.Forms.Form
    $toolbar.Text = "Outils décalquage"
    $toolbar.FormBorderStyle = 'FixedToolWindow'
    $toolbar.TopMost = $true
    $toolbar.ShowInTaskbar = $false
    $toolbar.StartPosition = 'Manual'
    $toolbar.Size = New-Object Drawing.Size(250,180)
    $toolbar.Location = New-Object Drawing.Point(($wa.X + $wa.Width - 270), ($wa.Y + 20))
    $toolbar.Font = New-Object Drawing.Font("Segoe UI",9)

    $btnFullscreen = New-Object System.Windows.Forms.Button
    $btnFullscreen.Text = "🖥️ Ajuster au plein écran"
    $btnFullscreen.Size = New-Object Drawing.Size(220,30)
    $btnFullscreen.Location = New-Object Drawing.Point(15,15)
    $btnFullscreen.Add_Click({
        if (-not $script:locked) {
            $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $script:imgForm.Bounds = New-Object Drawing.Rectangle($wa2.X, $wa2.Y, $wa2.Width, $wa2.Height)
        }
    })
    $toolbar.Controls.Add($btnFullscreen)

    $btnGrid = New-Object System.Windows.Forms.CheckBox
    $btnGrid.Text = "📐 Afficher la grille légère"
    $btnGrid.Size = New-Object Drawing.Size(220,25)
    $btnGrid.Location = New-Object Drawing.Point(15,55)
    $btnGrid.Add_CheckedChanged({
        $script:showGrid = $btnGrid.Checked
        if ($script:pictureBox) { $script:pictureBox.Invalidate() }
    })
    $toolbar.Controls.Add($btnGrid)

    $btnLock = New-Object System.Windows.Forms.Button
    $btnLock.Text = "📌 Verrouiller taille et position"
    $btnLock.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
    $btnLock.Size = New-Object Drawing.Size(220,35)
    $btnLock.Location = New-Object Drawing.Point(15,90)
    $btnLock.Add_Click({
        if (-not $script:locked) {
            $script:lockedBounds = $script:imgForm.Bounds
            $script:imgForm.FormBorderStyle = 'None'
            $script:locked = $true
            $btnLock.Text = "🔓 Déverrouiller (réajuster)"
        } else {
            $script:locked = $false
            $script:imgForm.FormBorderStyle = 'SizableToolWindow'
            $script:imgForm.Bounds = $script:lockedBounds
            $btnLock.Text = "📌 Verrouiller taille et position"
        }
    })
    $toolbar.Controls.Add($btnLock)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "✕ Fermer l'image"
    $btnClose.Size = New-Object Drawing.Size(220,30)
    $btnClose.Location = New-Object Drawing.Point(15,135)
    $btnClose.Add_Click({ Close-ImageWindow })
    $toolbar.Controls.Add($btnClose)

    $script:toolbarForm = $toolbar

    $imgForm.Show()
    $toolbar.Show()
}

# ============================================================
#  FENÊTRE PRINCIPALE
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Mode Décalquage"
$form.Size = New-Object Drawing.Size(460,560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object Drawing.Font("Segoe UI",10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "MODE DÉCALQUAGE"
$title.Font = New-Object Drawing.Font("Segoe UI",18,[Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(85,20)
$form.Controls.Add($title)

$info = New-Object System.Windows.Forms.Label
$info.Text = "Choisis une image, règle les options, puis active le mode."
$info.AutoSize = $true
$info.Location = New-Object Drawing.Point(45,60)
$form.Controls.Add($info)

# --- Choix de l'image ---
$grpImage = New-Object System.Windows.Forms.GroupBox
$grpImage.Text = "🖼️ Image"
$grpImage.Size = New-Object Drawing.Size(370,70)
$grpImage.Location = New-Object Drawing.Point(45,95)
$form.Controls.Add($grpImage)

$lblImage = New-Object System.Windows.Forms.Label
$lblImage.Text = "Aucune image sélectionnée"
$lblImage.AutoEllipsis = $true
$lblImage.Size = New-Object Drawing.Size(220,20)
$lblImage.Location = New-Object Drawing.Point(15,32)
$grpImage.Controls.Add($lblImage)

$btnChoose = New-Object System.Windows.Forms.Button
$btnChoose.Text = "Choisir..."
$btnChoose.Size = New-Object Drawing.Size(110,28)
$btnChoose.Location = New-Object Drawing.Point(245,28)
$btnChoose.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Images (*.jpg;*.jpeg;*.png;*.bmp;*.gif)|*.jpg;*.jpeg;*.png;*.bmp;*.gif|Tous les fichiers (*.*)|*.*"
    if ($ofd.ShowDialog() -eq 'OK') {
        $script:imagePath = $ofd.FileName
        $lblImage.Text = [System.IO.Path]::GetFileName($ofd.FileName)
        if ($script:imgForm) { Open-ImageWindow }
    }
})
$grpImage.Controls.Add($btnChoose)

# --- Luminosité ---
$grpBright = New-Object System.Windows.Forms.GroupBox
$grpBright.Text = "🔆 Luminosité de l'écran"
$grpBright.Size = New-Object Drawing.Size(370,70)
$grpBright.Location = New-Object Drawing.Point(45,175)
$form.Controls.Add($grpBright)

$brightSupported = Get-BrightnessSupported

$trkBright = New-Object System.Windows.Forms.TrackBar
$trkBright.Minimum = 5
$trkBright.Maximum = 100
$trkBright.TickFrequency = 10
$trkBright.Size = New-Object Drawing.Size(260,45)
$trkBright.Location = New-Object Drawing.Point(10,20)
$trkBright.Value = if ($brightSupported) { [Math]::Max(5, (Get-CurrentBrightness)) } else { 100 }
$trkBright.Enabled = $brightSupported
$grpBright.Controls.Add($trkBright)

$lblBrightVal = New-Object System.Windows.Forms.Label
$lblBrightVal.Text = "$($trkBright.Value)%"
$lblBrightVal.Size = New-Object Drawing.Size(60,20)
$lblBrightVal.Location = New-Object Drawing.Point(285,30)
$grpBright.Controls.Add($lblBrightVal)

if (-not $brightSupported) {
    $lblBrightVal.Text = "N/A"
}

$trkBright.Add_Scroll({
    $lblBrightVal.Text = "$($trkBright.Value)%"
    Set-Brightness $trkBright.Value
})

# --- Options ---
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Text = "Options"
$grpOptions.Size = New-Object Drawing.Size(370,105)
$grpOptions.Location = New-Object Drawing.Point(45,255)
$form.Controls.Add($grpOptions)

$chkOrientation = New-Object System.Windows.Forms.CheckBox
$chkOrientation.Text = "🔄 Verrouiller l'orientation de l'écran"
$chkOrientation.AutoSize = $true
$chkOrientation.Location = New-Object Drawing.Point(15,25)
$grpOptions.Controls.Add($chkOrientation)

$chkGridMain = New-Object System.Windows.Forms.CheckBox
$chkGridMain.Text = "📐 Afficher une grille légère sur l'image"
$chkGridMain.AutoSize = $true
$chkGridMain.Location = New-Object Drawing.Point(15,55)
$chkGridMain.Add_CheckedChanged({
    $script:showGrid = $chkGridMain.Checked
    if ($script:pictureBox) { $script:pictureBox.Invalidate() }
})
$grpOptions.Controls.Add($chkGridMain)

$lblSpacing = New-Object System.Windows.Forms.Label
$lblSpacing.Text = "Espacement (px) :"
$lblSpacing.AutoSize = $true
$lblSpacing.Location = New-Object Drawing.Point(35,82)
$grpOptions.Controls.Add($lblSpacing)

$numSpacing = New-Object System.Windows.Forms.NumericUpDown
$numSpacing.Minimum = 10
$numSpacing.Maximum = 300
$numSpacing.Value = 50
$numSpacing.Size = New-Object Drawing.Size(60,22)
$numSpacing.Location = New-Object Drawing.Point(160,80)
$numSpacing.Add_ValueChanged({
    $script:gridSpacing = [int]$numSpacing.Value
    if ($script:pictureBox) { $script:pictureBox.Invalidate() }
})
$grpOptions.Controls.Add($numSpacing)

# --- Boutons principaux ---
$start = New-Object System.Windows.Forms.Button
$start.Text = "ACTIVER LE MODE DÉCALQUAGE"
$start.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$start.Size = New-Object Drawing.Size(370,55)
$start.Location = New-Object Drawing.Point(45,375)
$start.Add_Click({
    Set-Touch $false
    Set-Awake $true
    if ($brightSupported) { Set-Brightness $trkBright.Value }
    if ($chkOrientation.Checked) { Lock-Orientation $true }

    if ($script:imagePath) {
        Open-ImageWindow
    }

    $msg = "Mode Décalquage activé !`n`nTactile : désactivé`nÉcran : toujours allumé"
    if ($chkOrientation.Checked) { $msg += "`nOrientation : verrouillée" }
    if ($script:imagePath) { $msg += "`nImage : affichée (ajuste-la puis verrouille-la depuis la barre d'outils)" }
    else { $msg += "`n`nAstuce : choisis une image pour l'afficher en plein écran." }

    [System.Windows.Forms.MessageBox]::Show($msg, "Prêt à décalquer", "OK", "Information") | Out-Null
})
$form.Controls.Add($start)

$stop = New-Object System.Windows.Forms.Button
$stop.Text = "RETOUR AU MODE NORMAL"
$stop.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$stop.Size = New-Object Drawing.Size(370,55)
$stop.Location = New-Object Drawing.Point(45,440)
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

$form.ShowDialog() | Out-Null
