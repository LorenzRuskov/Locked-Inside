@echo off
cd /d "%~dp0"
echo Serveur Locked Inside - port UDP 7777 - fermer cette fenetre pour arreter
"outils\Godot_v4.3-stable_win64_console.exe" --headless --path . -- --server
pause
