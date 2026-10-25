#!/usr/bin/env bash
# Проверка ERC/DRC и выпуск документации для проекта KiCad (Linux/macOS)
# Запускать из папки проекта, пути относительные

cd "$(dirname "$0")"

NAME=$(basename "$(ls *.kicad_pro | head -n1)" .kicad_pro)
[ -z "$NAME" ] && { echo "[ERROR] .kicad_pro not found"; exit 1; }

SCH="$NAME.kicad_sch"
PCB="$NAME.kicad_pcb"
OUT=output
ERR=0
mkdir -p "$OUT/gerbers"

echo "=== ERC ==="
kicad-cli sch erc --severity-error --exit-code-violations -o "$OUT/erc_report.rpt" "$SCH" || { echo "[ERROR] ERC failed"; ERR=1; }

echo "=== DRC ==="
kicad-cli pcb drc --schematic-parity --refill-zones --severity-error --exit-code-violations \
    -o "$OUT/drc_report.rpt" "$PCB" || { echo "[ERROR] DRC failed"; ERR=1; }

echo "=== PDF schematic ==="
kicad-cli sch export pdf -b -o "$OUT/${NAME}_schematic.pdf" "$SCH"

echo "=== BOM ==="
kicad-cli sch export bom -o "$OUT/${NAME}_BOM.csv" \
    --fields 'Reference,Value,Footprint,Manufacturer_Part_Number,${QUANTITY}' \
    --labels 'Поз. обозначение,Номинал,Корпус,Партномер,Кол.' \
    --group-by 'Value,Footprint,Manufacturer_Part_Number' \
    --exclude-dnp "$SCH"

echo "=== Gerber + drill ==="
kicad-cli pcb export gerbers --layers "F.Cu,B.Cu,F.Paste,B.Paste,F.Mask,B.Mask,F.Silkscreen,B.Silkscreen,Edge.Cuts" \
    --use-drill-file-origin -o "$OUT/gerbers/" "$PCB"
kicad-cli pcb export drill --excellon-separate-th --drill-origin plot -o "$OUT/gerbers/" "$PCB"
(cd "$OUT/gerbers" && zip -q -r "../${NAME}_gerbers.zip" .)

echo "=== STEP ==="
kicad-cli pcb export step -f -o "$OUT/${NAME}.step" "$PCB"

[ $ERR -ne 0 ] && { echo "DONE WITH ERRORS"; exit 1; }
echo "DONE, results in $OUT/"
