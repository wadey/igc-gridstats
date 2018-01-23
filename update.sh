#!/bin/bash

set -eux -o pipefail

DIR=".data/$(date +%s)"

mkdir -p "$DIR"

curl -A "GridStats/1.0 (+http://k1wdy.com/igc)" -f -s "https://igc.arrl.org/grid-totals.php" | grep "Last updated" | tee "$DIR/_start"
on_exit() {
  curl -A "GridStats/1.0 (+http://k1wdy.com/igc)" -f -s "https://igc.arrl.org/grid-totals.php" | grep "Last updated" | tee "$DIR/_exit"
}
trap 'on_exit' exit

set +x
LEFT=488 # "$(wc -l grids.txt)"
while read -r GRID
do
  echo "$GRID"
  curl -A "GridStats/1.0 (+http://k1wdy.com/igc)" -f -s -S -o "$DIR/$GRID" "https://igc.arrl.org/resources/api/grid-totals-api.php?gridSquare=$GRID"
  jq '.rows[0].QSLSum' "$DIR/$GRID"
  LEFT="$(( LEFT - 1))"
  SLEEP="$(( ( RANDOM % 10 )  + 1 ))"
  echo "LEFT=$LEFT : sleep $SLEEP"
  sleep "$SLEEP"
done <grids.txt
set -x

curl -A "GridStats/1.0 (+http://k1wdy.com/igc)" -f -s "https://igc.arrl.org/grid-totals.php" | grep "Last updated" | tee "$DIR/_finish"
(cd "$DIR" && for g in ????; do echo "$g,$(jq -r '.rows[0].QSLSum' "$g")"; done) | tee "$DIR/grids.csv"
START_TS="$(date -d"$(sed -E 's/^.*Last updated: *([^<]+?) *<.*$/\1/' "$DIR/_start")" '+%s')"
END_TS="$(date -d"$(sed -E 's/^.*Last updated: *([^<]+?) *<.*$/\1/' "$DIR/_finish")" '+%s')"
jq -csR 'split("\n") | [.[] | split(",") | select(length==2) | [.[0], (.[1]|tonumber)]]' "$DIR/grids.csv" | tee "$DIR/grids.json"
jq -c "{start: $START_TS, end: $END_TS, grids: .}" "$DIR/grids.json" >"$DIR/data.json"
cp "$DIR/data.json" data.json
