# 🖊️ SurfaceTrace — Tracing Mode for Surface Pro

*[Lire ceci en français](README.md)*

A small Windows tool (PowerShell + WinForms) that turns your Surface Pro
into a light table for tracing: touch input is disabled, the screen stays
on, and an image of your choice is displayed full-screen, perfectly fixed
in place, with an optional light grid to help you frame your drawing.

## ✨ Features

- 🖼️ **Pick an image** (JPG, PNG, BMP, GIF) to display on the screen
- 🔆 **Adjust screen brightness** directly from the interface, with the
  real hardware value automatically read back so the display always stays
  in sync with the actual screen
- ✋ **Resize with your finger** by dragging the window edges, **or with the − / + buttons** (5% steps, from 10% to 200%) — touch stays active until you lock it
- 🔆 **Brightness also available once the image is shown** (− / + buttons in the toolbar), with the main window and the toolbar always kept in sync with each other
- 🖌️ **Crisp, non-pixelated rendering**: high-quality rendering plus a manually scaled interface for the Surface Pro's high-DPI screens
- 📂 **Collapsible toolbar**, always anchored above the image (no more fighting for the foreground): a "Collapse" button reduces it to a small tab to free up the screen, and **Ctrl+M** collapses/expands it from the keyboard at any time
- 🌐 **4-language interface** (French, English, Spanish, German) via a selector in the top-right corner of both the main window and the toolbar
- 📐 **Adjustable grid line thickness** (1 to 6 px), in addition to the existing spacing setting
- 🆘 **ESC key**: closes everything and re-enables touch immediately, even if the screen shows a display glitch — no more need for Alt+F4
- 🔒 **A clear "Lock + disable touch" button** once the image is well positioned: the window becomes fixed and the screen stops responding to touch
- 🔄 **Lock screen orientation** (prevents unwanted rotations)
- 📐 **Optional light grid**, with an adjustable cell size in pixels (helps with framing), a checkbox available both in the main window and in the floating toolbar, and an explanation shown directly in the interface
- 📌 **Image position and size perfectly fixed** once locked
- 🪟 **No visible PowerShell window** on launch — only the graphical interface appears
- A **"Back to normal mode"** button that re-enables touch and restores the original settings

## 🚀 Installation

1. Download this repository (`Code > Download ZIP`) or clone it:
   ```bash
   git clone https://github.com/<your-account>/surfacetrace.git
   ```
2. Place the `Mode_Decalquage.ps1` and `Mode_Decalquage.bat` files in the
   same folder on your Surface Pro.

## ▶️ Usage

1. Double-click **`Mode_Decalquage.bat`** (no black window appears, only the interface shows up).
2. Accept the administrator rights prompt (needed to disable touch).
3. In the window:
   - pick the interface language if needed (selector in the top-right corner);
   - click **Choose...** to select your image;
   - adjust the **brightness** if needed;
   - check **Lock screen orientation** and/or **Show a light grid** if you want;
   - click **🖼️ SHOW THE IMAGE**. *(touch is still active at this stage)*
4. The image opens in a window: **resize and position it directly with
   your finger** (edges/corners), just like any Windows window, until it's
   properly framed on your sheet of paper.
5. Click the big green **🔒 LOCK + DISABLE TOUCH** button in the small
   floating toolbar: the window becomes fixed and touch is disabled.
6. Place your sheet of paper on the screen and draw.
7. To stop everything: click **BACK TO NORMAL MODE** in the main window
   (touch is automatically re-enabled even if you just close the image
   window).

> 💡 Need to readjust the image after locking it? Click the same button
> (now showing **🔓 Unlock**): touch is re-enabled long enough to
> reposition the image, then locks again normally.

> ⚠️ The brightness control acts on the internal screen (via WMI): it may
> not work on an external monitor that doesn't support DDC/CI.

## 🛠️ Requirements

- Windows 11 (tested on Surface Pro)
- PowerShell (pre-installed with Windows)
- Administrator rights (to enable/disable the touch driver)

## 📄 License

This project is distributed under the MIT license — feel free to modify
and reuse it.
