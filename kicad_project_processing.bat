@echo off
chcp 65001 >nul
rem Проверка ERC/DRC и выпуск документации для проекта KiCad
rem Запускать из папки проекта (рядом с .kicad_pro), пути относительные

cd /d "%~dp0"

rem если kicad-cli нет в PATH - берём из папки установки KiCad
where kicad-cli >nul 2>&1 || set "PATH=%PATH%;C:\Program Files\KiCad\10.0\bin"

rem имя проекта = имя файла .kicad_pro
for %%f in (*.kicad_pro) do set "NAME=%%~nf"
if not defined NAME (
    echo [ERROR] .kicad_pro not found
    exit /b 1
)

set "SCH=%NAME%.kicad_sch"
set "PCB=%NAME%.kicad_pcb"
set "OUT=output"
set "ERR=0"

if not exist "%OUT%\gerbers" mkdir "%OUT%\gerbers"

echo === ERC ===
kicad-cli sch erc --severity-error --exit-code-violations -o "%OUT%\erc_report.rpt" "%SCH%"
if errorlevel 1 ( echo [ERROR] ERC failed, see %OUT%\erc_report.rpt & set "ERR=1" )

echo === DRC ===
kicad-cli pcb drc --schematic-parity --refill-zones --severity-error --exit-code-violations -o "%OUT%\drc_report.rpt" "%PCB%"
if errorlevel 1 ( echo [ERROR] DRC failed, see %OUT%\drc_report.rpt & set "ERR=1" )

echo === PDF schematic ===
kicad-cli sch export pdf -b -o "%OUT%\%NAME%_schematic.pdf" "%SCH%"

echo === BOM ===
kicad-cli sch export bom -o "%OUT%\%NAME%_BOM.csv" ^
    --fields "Reference,Value,Footprint,Manufacturer_Part_Number,${QUANTITY}" ^
    --labels "Поз. обозначение,Номинал,Корпус,Партномер,Кол." ^
    --group-by "Value,Footprint,Manufacturer_Part_Number" ^
    --exclude-dnp "%SCH%"

echo === Gerber ===
kicad-cli pcb export gerbers --layers "F.Cu,B.Cu,F.Paste,B.Paste,F.Mask,B.Mask,F.Silkscreen,B.Silkscreen,Edge.Cuts" ^
    --use-drill-file-origin -o "%OUT%\gerbers\\" "%PCB%"

echo === Drill ===
kicad-cli pcb export drill --excellon-separate-th --drill-origin plot -o "%OUT%\gerbers\\" "%PCB%"

rem архив для заказа на Резоните
powershell -NoProfile -Command "Compress-Archive -Force -Path '%OUT%\gerbers\*' -DestinationPath '%OUT%\%NAME%_gerbers.zip'"

echo === STEP ===
kicad-cli pcb export step -f -o "%OUT%\%NAME%.step" "%PCB%"

echo.
if "%ERR%"=="1" (
    echo DONE WITH ERRORS
    exit /b 1
)
echo DONE, results in %OUT%\
exit /b 0
