#!/bin/sh
# 사용: sh render.sh  → ../santa/*.png, ../fairy/*.png  (⑦ 그룹 홈 버전만 다름)
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
cd "$(dirname "$0")"
render() { # name width height
  for v in santa fairy; do mkdir -p ../$v
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1.5 \
    --window-size="$2,$3" --screenshot="$(cygpath -w "$PWD/../$v/$1.png")" "file:///$(cygpath -m "$PWD/$1.html")?v=$v" 2>/dev/null
  done
}
render 01-ia 1240 760
render 02-wireframe 1960 1760
render 03-loop 1240 1000
render 04-manitto 1240 760
render 05-flow 1780 1300
