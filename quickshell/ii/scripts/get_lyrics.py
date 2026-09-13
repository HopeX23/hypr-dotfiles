import sys
import os
import subprocess
import json

dbus_name = sys.argv[1] if len(sys.argv) > 1 else ""

if not dbus_name:
    sys.exit(0)

# playerctl -p <dbus_name> metadata xesam:url
try:
    url = subprocess.check_output(["playerctl", "-p", dbus_name.replace("org.mpris.MediaPlayer2.", ""), "metadata", "xesam:url"], stderr=subprocess.DEVNULL).decode("utf-8").strip()
except Exception:
    print(json.dumps([]))
    sys.exit(0)

if not url.startswith("file://"):
    print(json.dumps([]))
    sys.exit(0)

from urllib.parse import unquote
file_path = unquote(url[7:])

# Find .lrc file
base_path = os.path.splitext(file_path)[0]
lrc_path = base_path + ".lrc"

if not os.path.exists(lrc_path):
    print(json.dumps([]))
    sys.exit(0)

lyrics = []
with open(lrc_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("[") or "]" not in line:
            continue
        time_str, text = line[1:].split("]", 1)
        if ":" not in time_str:
            continue
        try:
            m, s = time_str.split(":")
            seconds = int(m) * 60 + float(s)
            lyrics.append({"time": seconds, "text": text.strip()})
        except:
            continue

print(json.dumps(lyrics))
