# ============================================================
#  Mode Decalquage - Surface Pro
#  Affiche une image fixe en plein ecran pour decalquer, avec
#  grille legere optionnelle, puis verrouille tactile + fenetre
#  d'un seul clic une fois l'image bien placee.
# ============================================================

# --- DPI : rend le rendu net (pas de flou) SANS utiliser le mode
#     "Per-Monitor V2" (mal supporte par WinForms classique lance
#     depuis un script -> plantages/mise en page cassee). On calcule
#     ensuite nous-memes un facteur d'echelle applique manuellement
#     a toute l'interface. ---
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

# --- Masque la fenetre console PowerShell ---
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

# --- API Windows pour le verrouillage de la rotation d'ecran ---
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

# --- Panel avec rendu haute qualite et double buffering ---
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
#  PALETTE - theme sombre
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

# ============================================================
#  TRADUCTIONS (FR / EN / ES / DE)
# ============================================================
$script:I18N = @{
    fr = @{
        app_title = "Mode Decalquage"
        title = "MODE DECALQUAGE"
        info = "Choisis ton image, regle les options, affiche-la, ajuste-la`n(bords ou curseur), puis verrouille."
        hdr_image = "Image"
        lbl_no_image = "Aucune image selectionnee"
        btn_choose = "Choisir..."
        hdr_brightness = "Luminosite de l'ecran"
        lbl_na = "N/A"
        hdr_options = "Options"
        chk_orientation = "Verrouiller l'orientation de l'ecran"
        chk_grid = "Afficher une grille legere sur l'image"
        lbl_spacing = "Taille des cases de la grille :"
        lbl_spacing_help = "= distance en pixels entre 2 lignes (petit nombre = grille plus serree)"
        lbl_thickness = "Epaisseur des lignes :"
        btn_start = "AFFICHER L'IMAGE   (tactile encore actif)"
        btn_touch_only = "Desactiver uniquement le tactile (sans image)"
        btn_stop = "RETOUR AU MODE NORMAL"
        msg_choose_first = "Choisis d'abord une image avec le bouton `" Choisir... `"."
        msg_touch_off = "Tactile desactive.`n`nClique sur `" RETOUR AU MODE NORMAL `" pour le reactiver."
        msg_normal_restored = "Mode normal restaure.`n`nTactile : reactive`nOrientation : deverrouillee`nAlimentation : valeurs normales."
        msg_title_normal = "Mode normal"
        filter_images = "Images"
        filter_all = "Tous les fichiers"
        title_toolbar = "Outils decalquage"
        title_img = "Decalquage"
        btn_collapse = "Reduire ^"
        btn_expand = "Agrandir v"
        help_text = "1. Redimensionne la fenetre (bords)`n2. Ajuste avec les boutons ci-dessous`n3. Verrouille quand c'est bon"
        btn_fullscreen = "Ajuster au plein ecran"
        lbl_zoom = "Taille de l'image"
        chk_grid_short = "Grille legere"
        btn_lock = "VERROUILLER + DESACTIVER LE TACTILE"
        btn_unlock = "DEVERROUILLER (reactive le tactile)"
        lbl_safety = "ECHAP = tout annuler. CTRL+M = replier/deplier`ncette barre, meme si elle est hors de vue."
        btn_close_image = "Fermer l'image"
        lang_label = "Langue"
    }
    en = @{
        app_title = "Tracing Mode"
        title = "TRACING MODE"
        info = "Pick your image, adjust the settings, show it,`nresize it (edges or buttons), then lock it."
        hdr_image = "Image"
        lbl_no_image = "No image selected"
        btn_choose = "Choose..."
        hdr_brightness = "Screen brightness"
        lbl_na = "N/A"
        hdr_options = "Options"
        chk_orientation = "Lock screen orientation"
        chk_grid = "Show a light grid on the image"
        lbl_spacing = "Grid cell size:"
        lbl_spacing_help = "= distance in pixels between lines (smaller number = tighter grid)"
        lbl_thickness = "Line thickness:"
        btn_start = "SHOW THE IMAGE   (touch still active)"
        btn_touch_only = "Disable touch only (no image)"
        btn_stop = "BACK TO NORMAL MODE"
        msg_choose_first = "Choose an image first using the ""Choose..."" button."
        msg_touch_off = "Touch disabled.`n`nClick ""BACK TO NORMAL MODE"" to re-enable it."
        msg_normal_restored = "Normal mode restored.`n`nTouch: re-enabled`nOrientation: unlocked`nPower settings: back to normal."
        msg_title_normal = "Normal mode"
        filter_images = "Images"
        filter_all = "All files"
        title_toolbar = "Tracing tools"
        title_img = "Tracing"
        btn_collapse = "Collapse ^"
        btn_expand = "Expand v"
        help_text = "1. Resize the window (edges)`n2. Adjust with the buttons below`n3. Lock once it's right"
        btn_fullscreen = "Fit to full screen"
        lbl_zoom = "Image size"
        chk_grid_short = "Light grid"
        btn_lock = "LOCK + DISABLE TOUCH"
        btn_unlock = "UNLOCK (re-enables touch)"
        lbl_safety = "ESC = cancel everything. CTRL+M = collapse/expand`nthis bar, even if it's out of view."
        btn_close_image = "Close image"
        lang_label = "Language"
    }
    es = @{
        app_title = "Modo Calco"
        title = "MODO CALCO"
        info = "Elige tu imagen, ajusta las opciones, muestrala,`najustala (bordes o botones) y bloqueala."
        hdr_image = "Imagen"
        lbl_no_image = "Ninguna imagen seleccionada"
        btn_choose = "Elegir..."
        hdr_brightness = "Brillo de la pantalla"
        lbl_na = "N/D"
        hdr_options = "Opciones"
        chk_orientation = "Bloquear la orientacion de la pantalla"
        chk_grid = "Mostrar una cuadricula ligera sobre la imagen"
        lbl_spacing = "Tamano de la cuadricula:"
        lbl_spacing_help = "= distancia en pixeles entre lineas (numero pequeno = cuadricula mas tupida)"
        lbl_thickness = "Grosor de las lineas:"
        btn_start = "MOSTRAR LA IMAGEN   (tactil aun activo)"
        btn_touch_only = "Desactivar solo el tactil (sin imagen)"
        btn_stop = "VOLVER AL MODO NORMAL"
        msg_choose_first = "Primero elige una imagen con el boton `"Elegir...`"."
        msg_touch_off = "Pantalla tactil desactivada.`n`nHaz clic en `"VOLVER AL MODO NORMAL`" para reactivarla."
        msg_normal_restored = "Modo normal restaurado.`n`nTactil: reactivado`nOrientacion: desbloqueada`nEnergia: valores normales."
        msg_title_normal = "Modo normal"
        filter_images = "Imagenes"
        filter_all = "Todos los archivos"
        title_toolbar = "Herramientas de calco"
        title_img = "Calco"
        btn_collapse = "Reducir ^"
        btn_expand = "Ampliar v"
        help_text = "1. Redimensiona la ventana (bordes)`n2. Ajusta con los botones de abajo`n3. Bloquea cuando este bien"
        btn_fullscreen = "Ajustar a pantalla completa"
        lbl_zoom = "Tamano de la imagen"
        chk_grid_short = "Cuadricula ligera"
        btn_lock = "BLOQUEAR + DESACTIVAR TACTIL"
        btn_unlock = "DESBLOQUEAR (reactiva el tactil)"
        lbl_safety = "ESC = cancelar todo. CTRL+M = replegar/desplegar`nesta barra, aunque este fuera de vista."
        btn_close_image = "Cerrar la imagen"
        lang_label = "Idioma"
    }
    de = @{
        app_title = "Abpaus-Modus"
        title = "ABPAUS-MODUS"
        info = "Waehle dein Bild, passe die Einstellungen an, zeig es,`ngroesse es an (Rand oder Knoepfe) und sperre es."
        hdr_image = "Bild"
        lbl_no_image = "Kein Bild ausgewaehlt"
        btn_choose = "Auswaehlen..."
        hdr_brightness = "Bildschirmhelligkeit"
        lbl_na = "N/V"
        hdr_options = "Optionen"
        chk_orientation = "Bildschirmausrichtung sperren"
        chk_grid = "Leichtes Raster ueber dem Bild anzeigen"
        lbl_spacing = "Rastergroesse:"
        lbl_spacing_help = "= Abstand in Pixel zwischen den Linien (kleinere Zahl = engeres Raster)"
        lbl_thickness = "Linienstaerke:"
        btn_start = "BILD ANZEIGEN   (Touch noch aktiv)"
        btn_touch_only = "Nur Touch deaktivieren (ohne Bild)"
        btn_stop = "ZURUECK ZUM NORMALMODUS"
        msg_choose_first = "Waehle zuerst ein Bild ueber die Schaltflaeche `"Auswaehlen...`"."
        msg_touch_off = "Touch deaktiviert.`n`nKlicke auf `"ZURUECK ZUM NORMALMODUS`", um ihn zu reaktivieren."
        msg_normal_restored = "Normalmodus wiederhergestellt.`n`nTouch: reaktiviert`nAusrichtung: entsperrt`nEnergieeinstellungen: normal."
        msg_title_normal = "Normalmodus"
        filter_images = "Bilder"
        filter_all = "Alle Dateien"
        title_toolbar = "Abpaus-Werkzeuge"
        title_img = "Abpausen"
        btn_collapse = "Einklappen ^"
        btn_expand = "Ausklappen v"
        help_text = "1. Fenster am Rand vergroessern/verkleinern`n2. Mit den Knoepfen unten anpassen`n3. Sperren, wenn es passt"
        btn_fullscreen = "An Vollbild anpassen"
        lbl_zoom = "Bildgroesse"
        chk_grid_short = "Leichtes Raster"
        btn_lock = "SPERREN + TOUCH DEAKTIVIEREN"
        btn_unlock = "ENTSPERREN (aktiviert Touch)"
        lbl_safety = "ESC = alles abbrechen. STRG+M = diese Leiste`nein-/ausklappen, auch ausserhalb des Sichtbereichs."
        btn_close_image = "Bild schliessen"
        lang_label = "Sprache"
    }
}
$script:Lang = 'fr'
$script:textRefs = @()
$script:toolbarTextRefs = @()

function T([string]$key) {
    if ($script:I18N[$script:Lang] -and $script:I18N[$script:Lang].ContainsKey($key)) { return $script:I18N[$script:Lang][$key] }
    if ($script:I18N['fr'].ContainsKey($key)) { return $script:I18N['fr'][$key] }
    return $key
}

# Enregistre un controle pour qu'il soit retraduit automatiquement par
# Update-MainFormTexts / Update-ToolbarTexts lors d'un changement de langue.
function Reg-Text($ctrl, [string]$key, [bool]$isToolbar = $false) {
    $ctrl.Text = T $key
    if ($isToolbar) { $script:toolbarTextRefs += ,@{C=$ctrl;K=$key} }
    else { $script:textRefs += ,@{C=$ctrl;K=$key} }
    return $ctrl
}

function Update-MainFormTexts {
    foreach ($item in $script:textRefs) {
        if ($item.C -and -not $item.C.IsDisposed) { $item.C.Text = T $item.K }
    }
    if ($script:formRef) { $script:formRef.Text = T "app_title" }
    if ($script:lblImageRef -and -not $script:hasImageChosen) { $script:lblImageRef.Text = T "lbl_no_image" }
    if ($script:lblBrightValRef -and -not $script:brightSupported) { $script:lblBrightValRef.Text = T "lbl_na" }
}

function Update-ToolbarTexts {
    foreach ($item in $script:toolbarTextRefs) {
        if ($item.C -and -not $item.C.IsDisposed) { $item.C.Text = T $item.K }
    }
    if ($script:toolbarForm -and -not $script:toolbarForm.IsDisposed) { $script:toolbarForm.Text = T "title_toolbar" }
    if ($script:imgForm -and -not $script:imgForm.IsDisposed) { $script:imgForm.Text = T "title_img" }
    if ($script:btnCollapseRef) { $script:btnCollapseRef.Text = if ($script:toolbarExpanded) { T "btn_collapse" } else { T "btn_expand" } }
    if ($script:btnLockRef) { $script:btnLockRef.Text = if ($script:locked) { T "btn_unlock" } else { T "btn_lock" } }
    if ($script:lblBrightVal2Ref -and -not $script:brightSupported) { $script:lblBrightVal2Ref.Text = T "lbl_na" }
}

function Set-Language([string]$code) {
    $script:Lang = $code
    Update-MainFormTexts
    Update-ToolbarTexts
}

# Petit selecteur de langue (haut-droit) reutilisable pour la fenetre
# principale ET la barre d'outils.
function New-LangSelector($x,$y) {
    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.DropDownStyle = 'DropDownList'
    $cmb.Items.AddRange(@("FR","EN","ES","DE"))
    $cmb.Size = New-Object Drawing.Size(66,26)
    $cmb.Location = New-Object Drawing.Point($x,$y)
    $cmb.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
    $map = @{'fr'=0;'en'=1;'es'=2;'de'=3}
    $cmb.SelectedIndex = $map[$script:Lang]
    $codes = @('fr','en','es','de')
    $cmb.Add_SelectedIndexChanged({
        Set-Language $codes[$cmb.SelectedIndex]
    }.GetNewClosure())
    return $cmb
}

# Arrondi les coins d'un controle. Le rayon est automatiquement reduit
# si le controle est trop petit (evite toute erreur / forme absurde).
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

# Parcourt recursivement un conteneur et arrondit tous les boutons/panneaux.
# Appele APRES la mise a l'echelle, pour arrondir en fonction de la
# taille reelle finale (et non de la taille "de conception").
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
        $_.FriendlyName -match '(?i)touch screen|ecran tactile'
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

# Centralise tout changement lie a la grille : met a jour la variable
# partagee, force un vrai redessin immediat (Invalidate + Update, plus
# fiable qu'Invalidate seul sur une fenetre TopMost), et garde les DEUX
# cases a cocher (fenetre principale + barre d'outils) en phase l'une
# avec l'autre, meme si l'utilisateur ne touche qu'une seule des deux.
function Set-GridState([bool]$enabled) {
    $script:showGrid = $enabled
    if ($script:chkGridMainRef -and -not $script:chkGridMainRef.IsDisposed -and $script:chkGridMainRef.Checked -ne $enabled) {
        $script:chkGridMainRef.Checked = $enabled
    }
    if ($script:btnGridRef -and -not $script:btnGridRef.IsDisposed -and $script:btnGridRef.Checked -ne $enabled) {
        $script:btnGridRef.Checked = $enabled
    }
    Update-GridDisplay
}

function Update-GridDisplay {
    if ($script:imagePanel -and -not $script:imagePanel.IsDisposed) {
        $script:imagePanel.Invalidate()
        $script:imagePanel.Update()
    }
}

function Toggle-ToolbarCollapse {
    if (-not $script:toolbarForm -or $script:toolbarForm.IsDisposed) { return }
    $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    if ($script:toolbarExpanded) {
        foreach ($c in $script:toolbarOtherControls) { $c.Visible = $false }
        $script:toolbarForm.ClientSize = New-Object Drawing.Size($script:toolbarForm.ClientSize.Width, $script:toolbarCollapsedH)
        if ($script:btnCollapseRef) { $script:btnCollapseRef.Text = T "btn_expand" }
        $script:toolbarExpanded = $false
    } else {
        foreach ($c in $script:toolbarOtherControls) { $c.Visible = $true }
        if ($script:toolbarExpandedSize) { $script:toolbarForm.ClientSize = $script:toolbarExpandedSize }
        if ($script:btnCollapseRef) { $script:btnCollapseRef.Text = T "btn_collapse" }
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
            "Aucun ecran tactile n'a ete trouve.`n`nLes autres reglages seront quand meme appliques.",
            "Mode Decalquage", "OK", "Warning"
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
                "Mode Decalquage", "OK", "Error"
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
#  LUMINOSITE (ecran interne via WMI)
# ============================================================
function Get-BrightnessSupported {
    try { Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1 | Out-Null; return $true }
    catch { return $false }
}
function Get-CurrentBrightness {
    try {
        $inst = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1
        return [int]$inst.CurrentBrightness
    } catch { return 100 }
}
function Set-Brightness([int]$Level) {
    try {
        $inst = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop | Select-Object -First 1
        Invoke-CimMethod -InputObject $inst -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]0; Brightness = [byte]$Level } -ErrorAction Stop | Out-Null
    } catch {}
}
# Regle la luminosite PUIS relit la vraie valeur materielle : evite tout
# desynchronisage entre le % affiche et l'ecran reel (pilote/luminosite
# adaptative pouvant arrondir ou ignorer la valeur demandee). Utilise
# l'API CIM moderne, plus fiable que l'ancienne Get-WmiObject sur
# certains pilotes d'ecran tactile/tablette.
function Nudge-Brightness([int]$delta) {
    $target = [Math]::Max(5,[Math]::Min(100,$script:currentBrightness + $delta))
    Set-Brightness $target
    Start-Sleep -Milliseconds 350
    $real = Get-CurrentBrightness
    $script:currentBrightness = $real
    return $real
}

# Met a jour TOUS les affichages de luminosite (curseur + les deux
# labels, fenetre principale ET barre d'outils) avec la meme valeur,
# pour que rien ne puisse desynchroniser. Le flag syncingBrightness
# evite que le repositionnement programmatique du curseur ne redeclenche
# Set-Brightness en boucle.
function Sync-BrightnessDisplay([int]$real) {
    $script:currentBrightness = $real
    $script:syncingBrightness = $true
    try {
        if ($script:trkBrightRef -and -not $script:trkBrightRef.IsDisposed -and $script:trkBrightRef.Value -ne $real) {
            $script:trkBrightRef.Value = $real
        }
        if ($script:lblBrightValRef -and -not $script:lblBrightValRef.IsDisposed) { $script:lblBrightValRef.Text = "$real%" }
        if ($script:lblBrightVal2Ref -and -not $script:lblBrightVal2Ref.IsDisposed) { $script:lblBrightVal2Ref.Text = "$real %" }
    } finally { $script:syncingBrightness = $false }
}

# Timer de "debounce" : pendant qu'on glisse le curseur, on applique la
# luminosite tout de suite (reactif), mais on ne relit la vraie valeur
# materielle qu'une fois que l'utilisateur s'est arrete 400ms - sinon un
# Start-Sleep a chaque cran gelerait l'interface pendant le glissement.
$script:brightSyncTimer = New-Object System.Windows.Forms.Timer
$script:brightSyncTimer.Interval = 400
$script:brightSyncTimer.Add_Tick({
    $script:brightSyncTimer.Stop()
    $real = Get-CurrentBrightness
    Sync-BrightnessDisplay $real
})

# ============================================================
#  ROTATION D'ECRAN
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
#  ETAT PARTAGE
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
$script:chkGridMainRef   = $null
$script:btnGridRef       = $null
$script:trkBrightRef     = $null
$script:syncingBrightness = $false

# ============================================================
#  FENETRE IMAGE + BARRE D'OUTILS FLOTTANTE
# ============================================================
function Close-ImageWindow {
    # Un seul point d'entree : ferme imgForm, dont le FormClosing se
    # charge de fermer le toolbar (voir garde anti-recursion plus bas).
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
    $imgForm.Text = T "title_img"
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
                    $penColor = [Drawing.Color]::FromArgb(255,124,92,255)
                    $pen = New-Object Drawing.Pen($penColor, $thick)
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
    # Toucher/cliquer l'image amene naturellement imgForm au premier plan,
    # ce qui passe la barre d'outils DERRIERE elle (deux fenetres "TopMost"
    # se disputent le dessus). On la reforce systematiquement au-dessus.
    $imgForm.Add_Activated({ Bring-ToolbarToFront })
    $panel.Add_MouseDown({ Bring-ToolbarToFront })

    $script:imgForm = $imgForm
    $script:imagePanel = $panel

    # --- Barre d'outils flottante (construite en tailles "de conception",
    #     puis mise a l'echelle et repositionnee a la fin) ---
    $script:toolbarTextRefs = @()
    $toolbar = New-Object System.Windows.Forms.Form
    $toolbar.Text = T "title_toolbar"
    $toolbar.AutoScaleMode = 'None'
    $toolbar.FormBorderStyle = 'FixedToolWindow'
    $toolbar.TopMost = $true
    $toolbar.ShowInTaskbar = $false
    $toolbar.StartPosition = 'Manual'
    $toolbar.BackColor = $C_BG
    $toolbar.Font = New-Object Drawing.Font("Segoe UI",9)

    # --- Selecteur de langue (haut-gauche) ---
    $cmbLangTool = New-LangSelector 15 8
    $toolbar.Controls.Add($cmbLangTool)

    # --- Bouton Reduire/Agrandir : toujours visible, meme replie, pour
    #     liberer l'ecran en plein ecran sans perdre l'acces aux outils ---
    $btnCollapse = New-Btn (T "btn_collapse") 110 30 175 8 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 8 $true
    $toolbar.Controls.Add($btnCollapse)

    $lblHelp = New-Object System.Windows.Forms.Label
    Reg-Text $lblHelp "help_text" $true | Out-Null
    $lblHelp.ForeColor = $C_SUBTEXT
    $lblHelp.AutoSize = $true
    $lblHelp.Location = New-Object Drawing.Point(15,46)
    $toolbar.Controls.Add($lblHelp)

    $btnFullscreen = New-Btn (T "btn_fullscreen") 270 34 15 108 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 9 $false
    $script:toolbarTextRefs += ,@{C=$btnFullscreen;K="btn_fullscreen"}
    $btnFullscreen.Add_Click({
        if (-not $script:locked) {
            $wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $script:imgForm.Bounds = New-Object Drawing.Rectangle($wa2.X, $wa2.Y, $wa2.Width, $wa2.Height)
        }
    })
    $toolbar.Controls.Add($btnFullscreen)

    # --- Taille de l'image : boutons +/- (fiables au tactile, contrairement
    #     a un curseur a glisser dont le trace se perd facilement au doigt) ---
    $lblZoom = New-Object System.Windows.Forms.Label
    Reg-Text $lblZoom "lbl_zoom" $true | Out-Null
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

    # --- Luminosite : disponible ici aussi, une fois l'image affichee
    #     (le curseur de la fenetre principale n'est plus accessible) ---
    $lblBright = New-Object System.Windows.Forms.Label
    Reg-Text $lblBright "hdr_brightness" $true | Out-Null
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
    if (-not $script:brightSupported) { $lblBrightVal2.Text = T "lbl_na" }
    $script:lblBrightVal2Ref = $lblBrightVal2

    $btnBrightMinus = New-Btn "-" 70 40 15 255 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 16 $true
    $btnBrightMinus.Enabled = $script:brightSupported
    $btnBrightMinus.Add_Click({
        $real = Nudge-Brightness -10
        Sync-BrightnessDisplay $real
    })
    $toolbar.Controls.Add($btnBrightMinus)

    $btnBrightPlus = New-Btn "+" 70 40 215 255 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_TEXT 16 $true
    $btnBrightPlus.Enabled = $script:brightSupported
    $btnBrightPlus.Add_Click({
        $real = Nudge-Brightness 10
        Sync-BrightnessDisplay $real
    })
    $toolbar.Controls.Add($btnBrightPlus)

    $btnGrid = New-Object System.Windows.Forms.CheckBox
    Reg-Text $btnGrid "chk_grid_short" $true | Out-Null
    $btnGrid.ForeColor = $C_TEXT
    $btnGrid.Checked = $script:showGrid
    $btnGrid.AutoSize = $true
    $btnGrid.Location = New-Object Drawing.Point(15,308)
    $script:btnGridRef = $btnGrid
    $btnGrid.Add_CheckedChanged({ if ($btnGrid.Checked -ne $script:showGrid) { Set-GridState $btnGrid.Checked } })
    $toolbar.Controls.Add($btnGrid)

    $btnLock = New-Btn (T "btn_lock") 270 52 15 340 $C_LOCK $C_LOCK_DK ([Drawing.Color]::White) 9 $true
    $script:btnLockRef = $btnLock
    $btnLock.Add_Click({
        if (-not $script:locked) {
            $script:lockedBounds = $script:imgForm.Bounds
            $script:imgForm.FormBorderStyle = 'None'
            $script:locked = $true
            Set-Touch $false
            $script:touchLockedByUs = $true
            $btnLock.Text = T "btn_unlock"
            $btnLock.BackColor = $C_ACCENT
        } else {
            $script:locked = $false
            $script:imgForm.FormBorderStyle = 'SizableToolWindow'
            $script:imgForm.Bounds = $script:lockedBounds
            Set-Touch $true
            $script:touchLockedByUs = $false
            $btnLock.Text = T "btn_lock"
            $btnLock.BackColor = $C_LOCK
        }
    })
    $toolbar.Controls.Add($btnLock)

    $lblSafety = New-Object System.Windows.Forms.Label
    Reg-Text $lblSafety "lbl_safety" $true | Out-Null
    $lblSafety.ForeColor = $C_SUBTEXT
    $lblSafety.Font = New-Object Drawing.Font("Segoe UI",7)
    $lblSafety.AutoSize = $true
    $lblSafety.Location = New-Object Drawing.Point(15,396)
    $toolbar.Controls.Add($lblSafety)

    $btnClose = New-Btn (T "btn_close_image") 270 30 15 428 $C_STOP $C_STOP_DK ([Drawing.Color]::White) 9 $false
    $script:toolbarTextRefs += ,@{C=$btnClose;K="btn_close_image"}
    $btnClose.Add_Click({ Close-ImageWindow })
    $toolbar.Controls.Add($btnClose)

    $toolbar.ClientSize = New-Object Drawing.Size(300,474)

    # --- Repli/depli : reduit la barre a son seul bouton "Agrandir" pour
    #     ne pas gener le dessin en plein ecran. Logique dans la fonction
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

    # --- Mise a l'echelle manuelle de la barre d'outils, PUIS on la
    #     positionne (avec sa largeur reelle une fois mise a l'echelle) ---
    if ($script:UIScale -ne 1.0) {
        $toolbar.Scale((New-Object Drawing.SizeF($script:UIScale,$script:UIScale)))
    }
    Apply-RoundedCorners $toolbar 10
    $script:toolbarExpandedSize = New-Object Drawing.Size($toolbar.ClientSize.Width, $toolbar.ClientSize.Height)
    $script:toolbarCollapsedH = [int]($script:toolbarCollapsedH * $script:UIScale)
    $toolbar.Location = New-Object Drawing.Point(($wa.X + $wa.Width - $toolbar.Width - 20), ($wa.Y + 20))

    $script:toolbarForm = $toolbar
    $imgForm.Text = T "title_img"
    $imgForm.Show()
    $toolbar.Show()
}

# ============================================================
#  FENETRE PRINCIPALE
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = T "app_title"
$form.AutoScaleMode = 'None'
$form.ClientSize = New-Object Drawing.Size(480,725)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $C_BG
$form.Font = New-Object Drawing.Font("Segoe UI",10)
$script:formRef = $form

$title = New-Object System.Windows.Forms.Label
Reg-Text $title "title" | Out-Null
$title.Font = New-Object Drawing.Font("Segoe UI",20,[Drawing.FontStyle]::Bold)
$title.ForeColor = $C_TEXT
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(40,20)
$form.Controls.Add($title)

# --- Selecteur de langue (haut-droit) ---
$cmbLangMain = New-LangSelector 399 24
$form.Controls.Add($cmbLangMain)

$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object Drawing.Size(60,4)
$titleBar.Location = New-Object Drawing.Point(42,62)
$titleBar.BackColor = $C_ACCENT
$form.Controls.Add($titleBar)

$info = New-Object System.Windows.Forms.Label
Reg-Text $info "info" | Out-Null
$info.ForeColor = $C_SUBTEXT
$info.AutoSize = $true
$info.Location = New-Object Drawing.Point(42,78)
$form.Controls.Add($info)

# --- Panneau Image ---
$panImage = New-Panel 400 85 40 130
$form.Controls.Add($panImage)
foreach ($ctl in (New-Header (T "hdr_image") 15 10)) { $panImage.Controls.Add($ctl) }

$lblImage = New-Object System.Windows.Forms.Label
Reg-Text $lblImage "lbl_no_image" | Out-Null
$lblImage.ForeColor = $C_SUBTEXT
$lblImage.AutoEllipsis = $true
$lblImage.Size = New-Object Drawing.Size(230,20)
$lblImage.Location = New-Object Drawing.Point(15,42)
$panImage.Controls.Add($lblImage)
$script:lblImageRef = $lblImage
$script:hasImageChosen = $false

$btnChoose = New-Btn (T "btn_choose") 130 32 255 38 $C_ACCENT $C_ACCENT_DK ([Drawing.Color]::White) 9 $true
$script:textRefs += ,@{C=$btnChoose;K="btn_choose"}
$btnChoose.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "$(T 'filter_images') (*.jpg;*.jpeg;*.png;*.bmp;*.gif)|*.jpg;*.jpeg;*.png;*.bmp;*.gif|$(T 'filter_all') (*.*)|*.*"
    if ($ofd.ShowDialog() -eq 'OK') {
        $script:imagePath = $ofd.FileName
        $lblImage.Text = [System.IO.Path]::GetFileName($ofd.FileName)
        $lblImage.ForeColor = $C_TEXT
        $script:hasImageChosen = $true
        if ($script:imgForm) { Open-ImageWindow }
    }
})
$panImage.Controls.Add($btnChoose)

# --- Panneau Luminosite ---
$panBright = New-Panel 400 85 40 225
$form.Controls.Add($panBright)
foreach ($ctl in (New-Header (T "hdr_brightness") 15 10)) { $panBright.Controls.Add($ctl) }

$trkBright = New-Object System.Windows.Forms.TrackBar
$trkBright.Minimum = 5
$trkBright.Maximum = 100
$trkBright.TickFrequency = 10
$trkBright.Size = New-Object Drawing.Size(290,40)
$trkBright.Location = New-Object Drawing.Point(10,35)
$trkBright.Value = $script:currentBrightness
$trkBright.Enabled = $script:brightSupported
$panBright.Controls.Add($trkBright)
$script:trkBrightRef = $trkBright

$lblBrightVal = New-Object System.Windows.Forms.Label
$lblBrightVal.Text = if ($script:brightSupported) { "$($trkBright.Value)%" } else { T "lbl_na" }
$lblBrightVal.ForeColor = $C_TEXT
$lblBrightVal.Size = New-Object Drawing.Size(60,20)
$lblBrightVal.Location = New-Object Drawing.Point(320,42)
$panBright.Controls.Add($lblBrightVal)
$script:lblBrightValRef = $lblBrightVal

$trkBright.Add_ValueChanged({
    if ($script:syncingBrightness) { return }
    try {
        $lblBrightVal.Text = "$($trkBright.Value)%"
        if ($script:lblBrightVal2Ref -and -not $script:lblBrightVal2Ref.IsDisposed) { $script:lblBrightVal2Ref.Text = "$($trkBright.Value) %" }
        $script:currentBrightness = $trkBright.Value
        Set-Brightness $trkBright.Value
        # Relit la vraie valeur materielle 400ms apres le dernier mouvement
        # (voir Sync-BrightnessDisplay) pour corriger l'affichage si le
        # pilote a arrondi/ignore la valeur demandee.
        $script:brightSyncTimer.Stop()
        $script:brightSyncTimer.Start()
    } catch {}
})

# --- Panneau Options ---
$panOpt = New-Panel 400 195 40 325
$form.Controls.Add($panOpt)
foreach ($ctl in (New-Header (T "hdr_options") 15 10)) { $panOpt.Controls.Add($ctl) }

$chkOrientation = New-Object System.Windows.Forms.CheckBox
Reg-Text $chkOrientation "chk_orientation" | Out-Null
$chkOrientation.ForeColor = $C_TEXT
$chkOrientation.AutoSize = $true
$chkOrientation.Location = New-Object Drawing.Point(15,40)
$panOpt.Controls.Add($chkOrientation)

$chkGridMain = New-Object System.Windows.Forms.CheckBox
Reg-Text $chkGridMain "chk_grid" | Out-Null
$chkGridMain.ForeColor = $C_TEXT
$chkGridMain.AutoSize = $true
$chkGridMain.Location = New-Object Drawing.Point(15,70)
$script:chkGridMainRef = $chkGridMain
$chkGridMain.Add_CheckedChanged({ if ($chkGridMain.Checked -ne $script:showGrid) { Set-GridState $chkGridMain.Checked } })
$panOpt.Controls.Add($chkGridMain)

$lblSpacing = New-Object System.Windows.Forms.Label
Reg-Text $lblSpacing "lbl_spacing" | Out-Null
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
$numSpacing.Add_ValueChanged({ $script:gridSpacing = [int]$numSpacing.Value; Update-GridDisplay })
$panOpt.Controls.Add($numSpacing)

$lblSpacingUnit = New-Object System.Windows.Forms.Label
$lblSpacingUnit.Text = "px"
$lblSpacingUnit.ForeColor = $C_SUBTEXT
$lblSpacingUnit.AutoSize = $true
$lblSpacingUnit.Location = New-Object Drawing.Point(285,100)
$panOpt.Controls.Add($lblSpacingUnit)

$lblSpacingHelp = New-Object System.Windows.Forms.Label
Reg-Text $lblSpacingHelp "lbl_spacing_help" | Out-Null
$lblSpacingHelp.ForeColor = $C_SUBTEXT
$lblSpacingHelp.Font = New-Object Drawing.Font("Segoe UI",8)
$lblSpacingHelp.AutoSize = $true
$lblSpacingHelp.Location = New-Object Drawing.Point(35,125)
$panOpt.Controls.Add($lblSpacingHelp)

$lblThick = New-Object System.Windows.Forms.Label
Reg-Text $lblThick "lbl_thickness" | Out-Null
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
$numThick.Add_ValueChanged({ $script:gridThickness = [int]$numThick.Value; Update-GridDisplay })
$panOpt.Controls.Add($numThick)

$lblThickUnit = New-Object System.Windows.Forms.Label
$lblThickUnit.Text = "px"
$lblThickUnit.ForeColor = $C_SUBTEXT
$lblThickUnit.AutoSize = $true
$lblThickUnit.Location = New-Object Drawing.Point(285,153)
$panOpt.Controls.Add($lblThickUnit)

# --- Bouton principal : afficher l'image (tactile encore actif) ---
$start = New-Btn (T "btn_start") 400 55 40 540 $C_ACCENT $C_ACCENT_DK ([Drawing.Color]::White) 11 $true
$script:textRefs += ,@{C=$start;K="btn_start"}
$start.Add_Click({
    Set-Awake $true
    if ($script:brightSupported) { Set-Brightness $trkBright.Value }
    if ($chkOrientation.Checked) { Lock-Orientation $true }

    if (-not $script:imagePath) {
        [System.Windows.Forms.MessageBox]::Show((T "msg_choose_first"),(T "app_title"),"OK","Warning") | Out-Null
        return
    }
    Open-ImageWindow
})
$form.Controls.Add($start)

# --- Bouton secondaire : desactiver le tactile seul, sans image ---
$btnTouchOnly = New-Btn (T "btn_touch_only") 400 34 40 605 $C_PANEL ([Drawing.Color]::FromArgb(255,50,50,90)) $C_SUBTEXT 8 $false
$script:textRefs += ,@{C=$btnTouchOnly;K="btn_touch_only"}
$btnTouchOnly.Add_Click({
    Set-Touch $false
    Set-Awake $true
    [System.Windows.Forms.MessageBox]::Show((T "msg_touch_off"),(T "app_title"),"OK","Information") | Out-Null
})
$form.Controls.Add($btnTouchOnly)

# --- Bouton retour ---
$stop = New-Btn (T "btn_stop") 400 55 40 649 $C_STOP $C_STOP_DK ([Drawing.Color]::White) 10 $true
$script:textRefs += ,@{C=$stop;K="btn_stop"}
$stop.Add_Click({
    Set-Touch $true
    Set-Awake $false
    Lock-Orientation $false
    Close-ImageWindow
    [System.Windows.Forms.MessageBox]::Show(
        (T "msg_normal_restored"),
        (T "msg_title_normal"), "OK", "Information"
    ) | Out-Null
})
$form.Controls.Add($stop)

$form.Add_FormClosing({ Close-ImageWindow })

# --- Mise a l'echelle manuelle de la fenetre principale (une seule fois,
#     apres avoir ajoute tous les controles), puis arrondis ---
if ($script:UIScale -ne 1.0) {
    $form.Scale((New-Object Drawing.SizeF($script:UIScale,$script:UIScale)))
}
Apply-RoundedCorners $form 10

$form.ShowDialog() | Out-Null
