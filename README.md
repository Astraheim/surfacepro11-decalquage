# 🖊️ SurfaceTrace — Tracing Mode for Surface Pro

A small Windows tool (PowerShell + WinForms) that turns your Surface Pro into a digital lightbox for tracing: touch input can be disabled, the screen stays on, and an image of your choice is displayed fullscreen and perfectly fixed, with an optional lightweight grid to help you align your drawing.

## ✨ Features

* 🖼️ **Choose an image** (JPG, PNG, BMP, GIF) to display on the screen
* 🔆 **Adjust screen brightness** directly from the interface
* ✋ **Resize the image with your finger** by dragging the window edges, **or using the "Image size" touch slider** (you can slide anywhere on it without having to aim for a tiny handle) — touch remains active until you lock the image
* 🖌️ **Sharp, non-pixelated rendering**: high-quality image display + manually scaled interface for high-DPI Surface Pro screens
* 🆘 **ESC key**: immediately closes everything and re-enables touch input, even if the display is experiencing an issue — no need for Alt+F4
* 🔒 A clear **"Lock + Disable Touch"** button once the image is correctly positioned: the window becomes fixed and the screen no longer reacts to touch
* 🔄 **Lock screen orientation** to prevent unwanted rotations
* 📐 **Optional lightweight grid**, with an adjustable cell size in pixels to help with alignment, with an explanation displayed directly in the interface
* 📌 **Image position and size remain perfectly fixed** once locked
* 🪟 **No PowerShell window visible** at startup — only the graphical interface is displayed
* A **"Return to Normal Mode"** button that re-enables touch input and restores the original settings

## 🚀 Installation

1. Download this repository (`Code > Download ZIP`) or clone it:

   ```bash
   git clone https://github.com/<your-account>/surfacetrace.git
   ```
2. Place the `Mode_Decalquage.ps1` and `Mode_Decalquage.bat` files in the
   same folder on your Surface Pro.

## ▶️ Usage

1. Double-click **`Mode_Decalquage.bat`** (no black console window will appear; only the interface will be displayed).
2. Accept the administrator permission request (required to disable touch input).
3. In the main window:

   * click **Choose...** to select your image;
   * adjust the **brightness** if needed;
   * enable **Lock orientation** and/or **Show lightweight grid** if desired;
   * click **🖼️ DISPLAY IMAGE**. *(touch input remains active at this stage)*
4. The image opens in a window: **resize and position it directly with your finger** (using the edges/corners), just like any normal Windows window, until it is correctly aligned with your sheet of paper.
5. Click the large green **🔒 LOCK + DISABLE TOUCH** button in the floating toolbar: the window becomes fixed and touch input is disabled.
6. Place your sheet of paper on the screen and start tracing.
7. To stop everything: click **RETURN TO NORMAL MODE** in the main window (touch input is automatically re-enabled even if you simply close the image window).

> 💡 Need to adjust the image after locking it? Click the same button (now labelled **🔓 Unlock**): touch input is temporarily re-enabled so you can reposition the image, then lock it again normally.

> ⚠️ The brightness control affects the internal display through WMI: it may not work on an external display that does not support DDC/CI.

## 🛠️ Requirements

* Windows 11 (tested on Surface Pro)
(If you test the application on any other device, please contact me so I can update the list of compatible devices)
* PowerShell (pre-installed with Windows)
* Administrator privileges (required to enable/disable the touch driver)

## 📄 License

This project is distributed under the MIT License — feel free to modify and reuse it.
