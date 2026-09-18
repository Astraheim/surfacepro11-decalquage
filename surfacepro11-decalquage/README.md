# 🖊️ SurfaceTrace — Mode Décalquage pour Surface Pro

Petit outil Windows (PowerShell + WinForms) pour transformer ta Surface Pro
en table à décalquer : le tactile est désactivé, l'écran reste allumé, et une
image de ton choix s'affiche en plein écran, parfaitement fixe, avec une
grille légère optionnelle pour t'aider à cadrer ton dessin.

## ✨ Fonctionnalités

- 🖼️ **Choisir une image** (JPG, PNG, BMP, GIF) à afficher sur l'écran
- 🔆 **Régler la luminosité** de l'écran directement depuis l'interface
- 🔒 **Désactiver le tactile** le temps du décalquage (pour poser ta feuille et ta main sans bouger l'image)
- 🔄 **Verrouiller l'orientation** de l'écran (évite les rotations intempestives)
- ⛶ **Image en plein écran** : ajustable/redimensionnable dans un premier temps, puis verrouillable en un clic
- 📐 **Grille légère optionnelle**, espacement réglable, pour t'aider à te repérer
- 📌 **Position et taille de l'image parfaitement fixes** une fois verrouillées
- Un bouton **« Retour au mode normal »** qui réactive le tactile et restaure les réglages d'origine

## 🚀 Installation

1. Télécharge ce dépôt (`Code > Download ZIP`) ou clone-le :
   ```bash
   git clone https://github.com/<ton-compte>/surfacetrace.git
   ```
2. Place les fichiers `Mode_Decalquage.ps1` et `Mode_Decalquage.bat` dans le
   même dossier sur ta Surface Pro.

## ▶️ Utilisation

1. Double-clique sur **`Mode_Decalquage.bat`**.
2. Accepte la demande de droits administrateur (nécessaire pour désactiver le tactile).
3. Dans la fenêtre :
   - clique sur **Choisir...** pour sélectionner ton image ;
   - ajuste la **luminosité** si besoin ;
   - coche **Verrouiller l'orientation** et/ou **Afficher une grille légère** si tu le souhaites ;
   - clique sur **ACTIVER LE MODE DÉCALQUAGE**.
4. L'image s'ouvre dans une fenêtre redimensionnable : ajuste sa taille et sa
   position avec la souris, puis clique sur **📌 Verrouiller taille et
   position** dans la petite barre d'outils flottante.
5. Pose ta feuille sur l'écran et dessine.
6. Pour tout arrêter : ferme la barre d'outils (**✕ Fermer l'image**) puis
   clique sur **RETOUR AU MODE NORMAL** dans la fenêtre principale.

> ⚠️ Le réglage de luminosité agit sur l'écran interne (via WMI) : il peut ne
> pas fonctionner sur un écran externe non compatible DDC/CI.

## 🛠️ Prérequis

- Windows 11 (testé sur Surface Pro)
- PowerShell (préinstallé avec Windows)
- Droits administrateur (pour activer/désactiver le pilote tactile)

## 📄 Licence

Ce projet est distribué sous licence MIT — libre à toi de le modifier et de
le réutiliser.
