# 🖊️ SurfaceTrace — Mode Décalquage pour Surface Pro

Petit outil Windows (PowerShell + WinForms) pour transformer ta Surface Pro
en table à décalquer : le tactile est désactivé, l'écran reste allumé, et une
image de ton choix s'affiche en plein écran, parfaitement fixe, avec une
grille légère optionnelle pour t'aider à cadrer ton dessin.

## ✨ Fonctionnalités

- 🖼️ **Choisir une image** (JPG, PNG, BMP, GIF) à afficher sur l'écran
- 🔆 **Régler la luminosité** de l'écran directement depuis l'interface
- ✋ **Redimensionner au doigt** en tirant les bords de la fenêtre, **ou avec les boutons − / +** (par pas de 5 %, de 10 % à 200 %) — le tactile reste actif tant que tu n'as pas verrouillé
- 🔆 **Luminosité accessible aussi une fois l'image affichée** (boutons − / + dans la barre d'outils, toujours synchronisés avec la vraie luminosité de l'écran)
- 🖌️ **Rendu net, pas pixélisé** : haute qualité d'affichage + interface mise à l'échelle manuellement pour les écrans haute résolution (DPI) de la Surface Pro
- 📂 **Barre d'outils repliable** : un bouton « Réduire » la ramène à une simple languette pour dégager l'écran ; elle reste toujours au premier plan même quand on touche l'image, et **Ctrl+M** la replie/déplie au clavier à tout moment
- 🌐 **Interface en 4 langues** (Français, English, Español, Deutsch) via un sélecteur en haut à droite de la fenêtre principale et de la barre d'outils
- 📐 **Épaisseur de la grille réglable** (1 à 6 px), en plus de l'espacement déjà présent
- 🆘 **Touche ECHAP** : ferme tout et réactive le tactile immédiatement, même si l'écran affiche un souci d'affichage — plus besoin d'Alt+F4
- 🔒 **Un bouton clair « Verrouiller + désactiver le tactile »** une fois l'image bien placée : la fenêtre devient fixe et l'écran ne réagit plus au toucher
- 🔄 **Verrouiller l'orientation** de l'écran (évite les rotations intempestives)
- 📐 **Grille légère optionnelle**, avec une taille de case réglable en pixels (aide au cadrage), et une explication affichée directement dans l'interface
- 📌 **Position et taille de l'image parfaitement fixes** une fois verrouillées
- 🪟 **Aucune fenêtre PowerShell visible** au lancement — seule l'interface graphique s'affiche
- Un bouton **« Retour au mode normal »** qui réactive le tactile et restaure les réglages d'origine

## 🚀 Installation

1. Télécharge ce dépôt (`Code > Download ZIP`) ou clone-le :
   ```bash
   git clone https://github.com/<ton-compte>/surfacetrace.git
   ```
2. Place les fichiers `Mode_Decalquage.ps1` et `Mode_Decalquage.bat` dans le
   même dossier sur ta Surface Pro.

## ▶️ Utilisation

1. Double-clique sur **`Mode_Decalquage.bat`** (aucune fenêtre noire ne s'affiche, seule l'interface apparaît).
2. Accepte la demande de droits administrateur (nécessaire pour désactiver le tactile).
3. Dans la fenêtre :
   - clique sur **Choisir...** pour sélectionner ton image ;
   - ajuste la **luminosité** si besoin ;
   - coche **Verrouiller l'orientation** et/ou **Afficher une grille légère** si tu le souhaites ;
   - clique sur **🖼️ AFFICHER L'IMAGE**. *(le tactile reste actif à cette étape)*
4. L'image s'ouvre dans une fenêtre : **redimensionne-la et positionne-la
   directement au doigt** (bords/coins), comme n'importe quelle fenêtre
   Windows, jusqu'à ce qu'elle soit bien cadrée sur ta feuille.
5. Clique sur le gros bouton vert **🔒 VERROUILLER + DÉSACTIVER LE TACTILE**
   dans la petite barre d'outils flottante : la fenêtre devient fixe et le
   tactile est coupé.
6. Pose ta feuille sur l'écran et dessine.
7. Pour tout arrêter : clique sur **RETOUR AU MODE NORMAL** dans la fenêtre
   principale (le tactile est automatiquement réactivé même si tu fermes
   juste la fenêtre image).

> 💡 Besoin de rajuster l'image après l'avoir verrouillée ? Clique sur le
> même bouton (devenu **🔓 Déverrouiller**) : le tactile est réactivé le
> temps de repositionner l'image, puis reverrouille normalement.

> ⚠️ Le réglage de luminosité agit sur l'écran interne (via WMI) : il peut ne
> pas fonctionner sur un écran externe non compatible DDC/CI.

## 🛠️ Prérequis

- Windows 11 (testé sur Surface Pro)
- PowerShell (préinstallé avec Windows)
- Droits administrateur (pour activer/désactiver le pilote tactile)

## 📄 Licence

Ce projet est distribué sous licence MIT — libre à toi de le modifier et de
le réutiliser.
