# dmgbuild 설정. scripts/build-dmg.sh 가 -D app=... -D background=... -D volume_icon=... 으로 경로를 넘긴다.
# 아이콘 위치는 scripts/make-dmg-background.swift 의 화살표·문구 배치와 맞춘다.
import os.path

application = defines["app"]
appname = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}
icon = defines["volume_icon"]

background = defines["background"]
window_rect = ((200, 120), (600, 460))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
icon_locations = {
    appname: (160, 160),
    "Applications": (440, 160),
}
