"""
Add a Collision shortcut button to the right-click menu (Nautilus GTK4).

Ported from upstream's nautilus-extension/collision-extension.py.

A Nautilus/GNOME Files extension is loaded by Nautilus itself, in Nautilus's
own process, through libnautilus-extension's Python bindings
(nautilus-python) — not through the Ruby gem's own process or its
require path. There is no Ruby equivalent of nautilus-python: Nautilus
extensions are Python (via nautilus-python) or C/GObject only, so a Ruby
port cannot register a Nautilus extension written in Ruby. Shipping this
file, unchanged in shape from upstream, is what the port does instead — the
same mechanism upstream uses, finding and launching this gem's own
`collision` executable rather than upstream's Crystal binary or flatpak.

Install with `rake nautilus:install` (see Rakefile), which mirrors upstream's
`make install_nautilus_extension` target: it copies this file to
~/.local/share/nautilus-python/extensions/ and asks a running Nautilus to
reload.
"""

from subprocess import Popen
from urllib.parse import urlparse, unquote
from shutil import which
from gi import require_version
from gettext import textdomain, gettext

textdomain('dev.geopjr.Collision')
_ = gettext

require_version('Gtk', '4.0')
try:
    require_version('Nautilus', '4.1')
except ValueError:
    # Fallback if only Nautilus 4.0 exists
    require_version('Nautilus', '4.0')

from gi.repository import Nautilus, GObject, Gtk, Gdk

def get_collision():
    # The Ruby port installs its executable as `collision` (gem bindir),
    # the same name upstream's own binary and Makefile install target use,
    # so the same PATH lookup upstream's fallback branch does is the whole
    # story here — there is no flatpak build of the Ruby port to prefer.
    if which("collision") is not None:
        return ["collision"]
    else:
        return False

class NautilusCollision(Nautilus.MenuProvider, GObject.GObject):
    collision = get_collision()

    def __init__(self):
        self.window = None
        return

    # Executed method when the right-click entry is clicked
    def openWithCollision(self, menu, files):
        args = self.collision.copy()

        for file in files:
            file_path = unquote(urlparse(file.get_uri()).path)
            args.append(file_path)
        Popen(args, shell=False)  # collision needs to be in your PATH

    def get_background_items(self, files):
        return

    def get_file_items(self, files):
        # The option doesn't appear when a folder is selected
        if self.collision == False or any(x.is_directory() for x in files):
            return ()

        menu_item = Nautilus.MenuItem(
                        name="NautilusCollision::CheckHashes",
                        label=_("Check Hashes"))

        menu_item.connect('activate', self.openWithCollision, files)

        return menu_item,
