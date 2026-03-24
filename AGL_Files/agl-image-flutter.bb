require recipes-platform/images/agl-image-compositor.bb

SUMMARY = "Example Flutter application image"
LICENSE = "MIT"

CLANGSDK = "1"

IMAGE_FEATURES += "ssh-server-openssh"

# IMAGE_INSTALL += "\
#     weston-ini-conf-landscape \
#     \
#     flutter-auto \
#     bluez5 \
#     bluez5-obex \
#     dbus \
#     dbus-lib \
#     glib-2.0 \
#     agl-version-app \
# " 
# IMAGE_INSTALL += "\
#     weston-ini-conf-landscape \
#     \ 
#     flutter-auto \
#     bluez5 \
#     bluez5-obex \
#     dbus \
#     dbus-lib \ 
#     glib-2.0 \
#     agl-version-app \
# "
TOOLCHAIN_HOST_TASK:append = " nativesdk-flutter-sdk"


IMAGE_INSTALL += "\
    weston-ini-conf-landscape \
    \
    flutter-auto \
    bluez5 \
    bluez5-obex \
    dbus \
    dbus-lib \
    glib-2.0 \
    linux-firmware-ibt-20 \    
    linux-firmware-ibt-license \    
    agl-version-app \
" 
IMAGE_INSTALL += " \
    fontconfig \
    fontconfig-utils \
    ttf-dejavu-sans \
    ttf-dejavu-serif \
    ttf-dejavu-sans-mono \
"
#IMAGE_INSTALL += "\
#    weston-ini-conf-landscape \
#    \
#    flutter-auto \
#   flutter-samples-material-3-demo \
#    agl-version-app \
#    agl-test-app \
#" 
