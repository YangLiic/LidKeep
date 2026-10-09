#!/usr/bin/env python3
"""Build a compressed disk image with a Finder drag-to-install layout."""
import argparse
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias


def build(stage, background, icon, output):
    with tempfile.TemporaryDirectory(prefix="dmg-image.", dir=stage.parent) as temporary:
        writable = Path(temporary) / "LidKeep.dmg"
        subprocess.run([
            "hdiutil", "create", "-quiet", "-volname", "LidKeep Installer", "-fs", "HFS+",
            "-srcfolder", str(stage), "-format", "UDRW", str(writable),
        ], check=True)
        attached = plistlib.loads(subprocess.check_output([
            "hdiutil", "attach", "-readwrite", "-nobrowse", "-plist", str(writable),
        ]))
        mount = next(Path(item["mount-point"]) for item in attached["system-entities"] if "mount-point" in item)
        try:
            backdrop = mount / ".background" / "background@2x.png"
            backdrop.parent.mkdir()
            shutil.copyfile(background, backdrop)
            shutil.copyfile(icon, mount / ".VolumeIcon.icns")
            subprocess.run(["SetFile", "-a", "C", str(mount)], check=True)
            with DSStore.open(str(mount / ".DS_Store"), "w+") as store:
                store["."]["vSrn"] = ("long", 1)
                store["."]["icvl"] = ("type", "icnv")
                store["."]["bwsp"] = {
                    "ShowToolbar": False, "ShowSidebar": False, "ShowStatusBar": False,
                    "ShowPathbar": False, "ShowTabView": False,
                    "WindowBounds": "{{400, 160}, {700, 590}}", "ContainerShowSidebar": False,
                    "PreviewPaneVisibility": False, "SidebarWidth": 0,
                }
                store["."]["icvp"] = {
                    "viewOptionsVersion": 1, "backgroundType": 2,
                    "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0, "backgroundColorBlue": 1.0,
                    "backgroundImageAlias": Alias.for_file(str(backdrop)).to_bytes(),
                    "iconSize": 108.0, "textSize": 14.0, "gridSpacing": 100.0,
                    "scrollPositionX": 0.0, "scrollPositionY": 0.0,
                    "gridOffsetX": 0.0, "gridOffsetY": 0.0, "arrangeBy": "none",
                    "labelOnBottom": True, "showItemInfo": False, "showIconPreview": False,
                }
                store["LidKeep.app"]["Iloc"] = (190, 235)
                store["Applications"]["Iloc"] = (510, 235)
        finally:
            subprocess.run(["hdiutil", "detach", "-quiet", str(mount)], check=True)
        subprocess.run([
            "hdiutil", "convert", "-quiet", str(writable), "-format", "UDZO", "-o", str(output),
        ], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", type=Path)
    parser.add_argument("background", type=Path)
    parser.add_argument("icon", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.stage.resolve(), args.background.resolve(), args.icon.resolve(), args.output.resolve())
