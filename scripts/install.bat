@echo off
set "SOURCE=%~dp0..\\"
set "DEST=%PROGRAMFILES(x86)%\World of Warcraft\_retail_\Interface\AddOns\TerribleLuraHelper"

if not exist "%DEST%" mkdir "%DEST%"

echo Copying TerribleLuraHelper to WoW retail addons folder...
copy /Y "%SOURCE%TerribleLuraHelper.toc" "%DEST%\"
copy /Y "%SOURCE%Core.lua" "%DEST%\"
copy /Y "%SOURCE%Macros.lua" "%DEST%\"
copy /Y "%SOURCE%Window.lua" "%DEST%\"
copy /Y "%SOURCE%Config.lua" "%DEST%\"
copy /Y "%SOURCE%templates.xml" "%DEST%\"
copy /Y "%SOURCE%reference.tga" "%DEST%\"

echo Done! /reload in WoW to load the addon.
