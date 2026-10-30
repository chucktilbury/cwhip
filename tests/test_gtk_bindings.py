"""Real menus, asynchronous native choosers, GC/teardown and view allocations."""
import argparse
from pathlib import Path
import shlex
import subprocess

from gtk_support import headless
from program_runner import environment, invoke


NATIVE = """
import gtk
class F {
    void collect()
    int64 dialogs()
    int64 finalizedObjects()
    int64 finalizedConfirmations()
    void drain(int64 expected)
    int64 receivers()
    void track()
    void respond(String path, bool accept)
    void confirm(bool accept)
    void waitSize(int64 token, int64 width, int64 height, void<> ready)
    void assertMenu(int64 token)
    void resize(int64 token, int64 width, int64 height)
}
void F.collect() from "binding_collect"
int64 F.dialogs() from "binding_dialogs"
int64 F.finalizedObjects() from "binding_finalized_objects"
int64 F.finalizedConfirmations() from "binding_finalized_confirmations"
void F.drain(int64 expected) from "binding_drain"
int64 F.receivers() from "binding_receivers"
void F.track() from "binding_track"
void F.respond(String path, bool accept) from "binding_respond"
void F.confirm(bool accept) from "binding_confirm"
void F.waitSize(int64 token, int64 width, int64 height, void<> ready)
    from "binding_wait_size"
void F.assertMenu(int64 token) from "binding_assert_menu"
void F.resize(int64 token, int64 width, int64 height) from "binding_resize"
"""

SHORTCUT_NATIVE = """
import sourceview
class Keys {
    bool press(int64 token, String trigger)
    void viewProperties(int64 token, int64 tabs, bool enabled)
    void viewDisplay(int64 token, bool whitespace, bool indent)
}
bool Keys.press(int64 token, String trigger) from "binding_shortcut"
void Keys.viewProperties(int64 token, int64 tabs, bool enabled) from "binding_view_properties"
void Keys.viewDisplay(int64 token, bool whitespace, bool indent) from "binding_view_display"
"""

CONFIG = r'''
import system
class UI {
    String original
    String updated
    void<String> savedAction
    void<String> unexpectedAction
    void require(bool condition, String label) {
        if (!condition) {
            System.StandardIO().writeErrorLine(label)
            System.Process().exit(1)
        }
    }
    void activate() {
        Gtk.Window window = Gtk.Window("Config bindings")
        window.present()
        Gtk.Config config = Gtk.Config()
        original = "title = \"kept\"\n[view]\nsize = 12\nwrap = false\nitems = [\"a\", \"b\"]\n"
        require(config.validate(original).equals(""), "valid TOML")
        require(!config.validate("size = [").equals(""), "invalid TOML")
        require(config.value(original, "view", "size").equals("i12"), "integer value")
        require(config.value(original, "view", "wrap").equals("bfalse"), "boolean value")
        require(!config.key(original, "view", 0).equals(""), "key enumeration")
        require(config.arraySize(original, "view", "items") == 2, "array size")
        require(config.item(original, "view", "items", 1, "").equals("sb"), "array item")
        String quoted = format("text = {}\n", config.quote("quote \" slash \\"))
        require(config.validate(quoted).equals("") &&
                config.value(quoted, "", "text").equals("squote \" slash \\"), "quoted value")
        updated = config.merge(original, "[view]\nsize = 18\n")
        require(config.value(updated, "view", "size").equals("i18") &&
                config.value(updated, "", "title").equals("skept"), "merge preserves unrelated keys")
        String removed = config.remove(updated, "view", "items")
        require(config.arraySize(removed, "view", "items") == -1 &&
                config.value(removed, "view", "size").equals("i18"), "remove preserves unrelated keys")
        require(config.fileStatus("config-roundtrip.toml").equals("missing"), "missing file")
        require(config.saveNow("config-roundtrip.toml", original, "").equals(""), "atomic first save")
        require(config.fileStatus("config-roundtrip.toml").equals(""), "existing file")
        require(!config.saveNow("config-roundtrip.toml", updated, "stale").equals(""), "concurrent edit rejected")
        System.File file = System.File("config-roundtrip.toml", "r")
        require(file.readAll().equals(original), "rejected save preserves contents")
        file.close()
        config.save("config-roundtrip.toml", updated, original, savedAction)
        F().collect()
    }
    void saved(String error) {
        require(error.equals(""), "async save callback")
        System.File file = System.File("config-roundtrip.toml", "r")
        require(file.readAll().equals(updated), "async save contents")
        file.close()
        Gtk.Config().save("config-drain.toml", updated, "", unexpectedAction)
        Gtk.Application().shutdown()
        require(System.FileSystem().exists("config-drain.toml"), "shutdown drains pending save")
        print("PASS config")
    }
    void unexpected(String error) {
        require(false, "callback after shutdown")
    }
}
start {
    Gtk.Application app = Gtk.Application("org.cwhip.BindingConfig")
    UI ui = UI()
    ui.savedAction = ui.saved
    ui.unexpectedAction = ui.unexpected
    app.onActivate(ui.activate)
    app.run()
}
'''

MENU = """
class Handler {
    void action() { F().collect()
        print("action;") }
}
class Stop {
    void action() { Gtk.Application().shutdown()
        print("stopped;") }
}
class Check {
    void action(bool active) { print(format("check {};", active)) }
}
class UI {
    Gtk.Window window
    Gtk.MenuBar menus
    int64 item
    void activate() {
        window = Gtk.Window("Menu bindings")
        menus = Gtk.MenuBar()
        window.setChild(menus)
        int64 menu = menus.addMenu("File")
        item = menus.addItem(menu, "Open", Handler().action)
        F().assertMenu(menus._widgetToken())
        F().collect()
        menus.activateItem(item)
        menus.setItemEnabled(item, false)
        menus.activateItem(item)
        menus.setItemEnabled(item, true)
        menus.activateItem(item)
        int64 check = menus.addCheckItem(menu, "Numbers", false, Check().action)
        menus.activateItem(check)
        menus.setItemChecked(check, false)
        menus.activateItem(check)
        int64 stop = menus.addItem(menu, "Shutdown", Stop().action)
        menus.activateItem(stop)
        print(menus.disposed())
    }
}
start {
    Gtk.Application app = Gtk.Application("org.cwhip.BindingMenus")
    app.onActivate(UI().activate)
    app.run()
}
"""

DIALOG = """
class Relay {
    void<String> target
    Relay(void<String> action) { target = action }
    void deliver(String path) { F().collect()
        target(path) }
    void note()
    destroy { note() }
}
void Relay.note() from "binding_released"
class UI {
    Gtk.Window window
    Gtk.FileDialog dialog
    void<String> resultAction
    int64 phase
    void show(bool save, String path) {
        dialog = Gtk.FileDialog(window, save, path, Relay(resultAction).deliver)
        print(dialog.pending())
        F().track()
        F().collect()
    }
    void result(String path) {
        F().collect()
        print(path)
        print(";")
        print(dialog.pending())
        print(F().dialogs())
        phase = phase + 1
        if (phase == 1) {
            show(false, "")
            F().respond("", false)
            return()}
        if (phase == 2) {
            show(true, "fresh.cw")
            F().respond("fresh.cw", true)
            return()}
        if (phase == 3) {
            show(true, "existing.cw")
            F().respond("existing.cw", true)
            F().confirm(false)
            return()}
        if (phase == 4) {
            show(true, "existing.cw")
            F().respond("existing.cw", true)
            F().confirm(true)
            return()}
        {
            print(F().finalizedObjects() == 5)
            print(F().finalizedConfirmations() == 2)
            show(false, "")
            dialog.cancel()
            dialog.cancel()
            print(dialog.pending())
            print(F().dialogs())
            F().collect()
            print(F().receivers() == 5)
            show(false, "")
            window.dispose()
            print(dialog.pending())
            print(F().dialogs())
            F().collect()
            print(F().receivers() == 6)
            window = Gtk.Window("Shutdown")
            show(false, "")
            Gtk.Application().shutdown()
            print(dialog.pending())
            print(F().dialogs())
            F().collect()
            print(F().receivers() == 7)
        }
    }
    void activate() {
        window = Gtk.Window("Dialog bindings")
        window.present()
        show(false, "existing.cw")
        F().respond("existing.cw", true)
    }
}
start {
    Gtk.Application app = Gtk.Application("org.cwhip.BindingDialogs")
    UI ui = UI()
    ui.resultAction = ui.result
    app.onActivate(ui.activate)
    app.run()
    F().drain(8)
    print(F().finalizedObjects())
    F().collect()
    print(F().receivers())
}
"""

LIFETIME = """
import system
class Relay {
    void received(String path) { System.Process().exit(1) }
    void receivedMany(list paths) { System.Process().exit(1) }
    void note()
    destroy { note() }
}
void Relay.note() from "binding_released"
class UI {
    Gtk.Window window
    Gtk.FileDialog dialog
    void show() {
        String operation = System.Process().getEnv("BINDING_OPERATION")
        if (operation.equals("open")) {
            dialog = Gtk.FileDialog(window, false, "", Relay().received)
        }
        if (operation.equals("save")) {
            dialog = Gtk.FileDialog(window, true, "", Relay().received)
        }
        if (operation.equals("multiple")) {
            dialog = Gtk.FileDialog(window, "", Relay().receivedMany)
        }
        if (operation.equals("folder")) {
            dialog = Gtk.FileDialog(window, "", Relay().received)
        }
        F().track()
    }
    void teardown() {
        String teardown = System.Process().getEnv("BINDING_TEARDOWN")
        if (teardown.equals("cancel")) {
            dialog.cancel()
            dialog.cancel()
        }
        if (teardown.equals("parent")) { window.dispose() }
        if (teardown.equals("shutdown")) { Gtk.Application().shutdown() }
        if (dialog.pending() || F().dialogs() != 0) { System.Process().exit(1) }
        dialog = null
    }
    void activate() {
        window = Gtk.Window("Dialog lifetime")
        window.present()
        show()
        teardown()
        F().collect()
        if (F().receivers() != 1) { System.Process().exit(1) }
        if (!window.disposed()) { window.dispose() }
    }
}
start {
    Gtk.Application app = Gtk.Application("org.cwhip.BindingLifetime")
    UI ui = UI()
    app.onActivate(ui.activate)
    app.run()
    F().drain(1)
    print("PASS lifetime")
}
"""

# SourceView cases live under tests/repro/gtk/ for hand editing and repro.
_REPRO_GTK = Path(__file__).resolve().parent / "repro" / "gtk"
SOURCEVIEW = (_REPRO_GTK / "sourceview_allocation.cw").read_text()
SOURCEVIEW_EDITING = (_REPRO_GTK / "sourceview_editing.cw").read_text()
# Shortcut callbacks that dispose their own view (closing a tab) or the whole
# window (quitting) must not release their in-flight callback registration.
SHORTCUTS = (_REPRO_GTK / "shortcuts_dispose.cw").read_text()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--clang", default="clang")
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--xvfb", required=True)
    parser.add_argument("--sourceview", action="store_true")
    parser.add_argument("--sanitize", default="")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    env = environment(work)
    flags = shlex.split(subprocess.check_output(
        ["pkg-config", "--cflags", "gtksourceview-5" if args.sourceview else "gtk4"],
        text=True))
    if args.sourceview:
        languages = root / "stdlib/sourceview/0.1.0/language-specs"
        flags += ["-DCWHIP_GTK_SOURCEVIEW=1",
                  f'-DCWHIP_GTK_SOURCEVIEW_SOURCE_LANG_DIR="{languages}"',
                  f'-DCWHIP_GTK_SOURCEVIEW_INSTALL_LANG_DIR="{languages}"']
    if args.sanitize:
        flags.append(f"-fsanitize={args.sanitize}")
    native = work / "fixture.o"
    result = invoke([args.clang, "-std=c11", "-Wall", "-Wextra", "-Werror",
                     "-Wno-deprecated-declarations", "-I", str(root / "include"),
                     "-c", str(root / "tests/gtk_bindings_fixture.c"), "-o",
                     str(native), *flags], work, env)
    assert result.returncode == 0, result.stderr
    existing = work / "existing.cw"
    existing.write_text("unchanged")
    fresh = work / "fresh.cw"
    fresh.unlink(missing_ok=True)
    for name in ("config-roundtrip.toml", "config-drain.toml"):
        (work / name).unlink(missing_ok=True)
    dialog = DIALOG.replace('"existing.cw"', f'"{existing}"').replace(
        '"fresh.cw"', f'"{fresh}"')
    expected_dialog = (f"true{existing};false0true;false0true{fresh};false0"
                       f"true;false0true{existing};false0truetrue"
                       "truefalse0truetruefalse0truetruefalse0true88")
    cases = [("config", CONFIG, "PASS config"),
             ("menus", MENU, "action;action;check true;check true;stopped;true"),
             ("dialogs", dialog, expected_dialog),
             ("lifetime", LIFETIME, "PASS lifetime")]
    if args.sourceview:
        cases.append(("sourceview-editing", SHORTCUT_NATIVE + SOURCEVIEW_EDITING,
                      "PASS sourceview editing"))
        cases.append(("allocation", SOURCEVIEW, "falsetruetruetruetruetruetruetruemultiline;grew;"))
        cases.append(("shortcuts", SHORTCUT_NATIVE + SHORTCUTS,
                      "truetrueclosed;truequit;true2"))
    with headless(args.xvfb, work, env) as env:
        for name, program, expected in cases:
            source = work / f"{name}.cw"
            source.write_text(NATIVE + program)
            output = work / name
            result = invoke([str(args.compiler.resolve()), str(source), str(native),
                             "-o", str(output)], work, env)
            assert result.returncode == 0, f"{name}: {result.stderr}"
            runs = [(name, env)]
            if name == "lifetime":
                runs = [(f"{operation}-{teardown}",
                         dict(env, BINDING_OPERATION=operation, BINDING_TEARDOWN=teardown))
                        for operation in ("open", "save", "multiple", "folder")
                        for teardown in ("cancel", "parent", "shutdown")]
            for case, case_env in runs:
                result = invoke([str(output)], work, case_env)
                assert result.returncode == 0, f"{case}: {result.stderr}\n{result.stdout}"
                assert result.stdout == expected, (case, result.stdout, expected, result.stderr)
                assert "CRITICAL" not in result.stderr and "ERROR" not in result.stderr, result.stderr
                assert existing.read_text() == "unchanged" and not fresh.exists()
                print(f"PASS {case}")


if __name__ == "__main__":
    main()
