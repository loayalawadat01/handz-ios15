#!/bin/bash
# Gets the newest Handz 15 (the iOS 15 copy of the iPhone app) from GitHub.
# Double-click it. Quit Xcode first.
cd "$(dirname "$0")" || exit 1

while pgrep -x Xcode >/dev/null; do
  echo "Please quit Xcode first (Xcode menu, then Quit Xcode). Waiting..."
  sleep 3
done

PBX="Handz.xcodeproj/project.pbxproj"

# Remember the signing team you picked in Xcode (Signing & Capabilities).
TEAM="$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Za-z0-9]*;' "$PBX" | sed 's/DEVELOPMENT_TEAM = //; s/;//')"

# Changes Xcode made to the project settings would block the update, so they
# are undone first. The team is put back below.
git checkout -- "$PBX"

if git checkout -q main && git pull --ff-only; then
  echo ""
  echo "Handz 15 is up to date."
else
  echo ""
  echo "The update didn't work. Send Claude a screenshot of this window."
fi

if [ -n "$TEAM" ]; then
  perl -pi -e "s/^(\s*)CODE_SIGN_STYLE = Automatic;/\$1CODE_SIGN_STYLE = Automatic;\n\$1DEVELOPMENT_TEAM = $TEAM;/" "$PBX"
  echo "Kept your signing team ($TEAM)."
fi

echo "You can open Xcode now."
read -n 1 -s -r -p "Press any key to close this window."
