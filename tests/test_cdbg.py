"""Real Cwhip GTK debugger, MI grammar, local GDB sessions and failure teardown."""

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from gtk_support import headless
from program_runner import environment, invoke
from test_cedit_shortcuts import Display


PARSER = r'''
include "mi.cw"
class Check {
    void require(bool condition, String name) {
        if (!condition) { print(format("FAIL {}", name))
            System.Process().exit(1) }
    }
}
start {
    Check test = Check()
    MiParser parser = MiParser()
    parser.parse("12^done,stack=[frame={level=\"0\",func=\"main\",fullname=\"a,b.cw\",line=\"10\"}]")
    test.require(parser.valid && parser.token.equals("12") && parser.kind.equals("^") &&
        parser.result.equals("done"), "result record")
    MiValue frame = parser.data.field("stack").values[0] as MiValue
    test.require(frame.field("fullname").text.equals("a,b.cw") &&
        frame.field("line").text.equals("10"), "nested tuple/list")
    parser.parse("*stopped,reason=\"breakpoint-hit\",frame={func=\"foo\",args=[{name=\"x\",value=\"21\"}]}")
    test.require(parser.valid &&
        (parser.data.field("frame").field("args").values[0] as MiValue).field("value").text.equals("21"),
        "value list")
    parser.parse("~\"tab\\tquote\\\"backslash\\\\newline\\n\\303\\251\"")
    test.require(parser.valid && parser.data.text.contains("tab\tquote\"backslash\\newline\n"),
        "C string escapes")
    parser.parse("13^error,msg=\"No symbol \\\"missing\\\" in current context.\"")
    test.require(parser.valid && parser.data.field("msg").text.contains("\"missing\""), "error")
    String input = "path \"with quotes\"\\and\nnewlines\t"
    parser.parse(format("~{}", parser.quote(input)))
    test.require(parser.valid && parser.data.text.equals(input), "quoting roundtrip")
    parser.parse("1^done,values=[]")
    test.require(parser.valid && parser.data.field("values").values.length == 0, "empty list")
    parser.parse("1^done,bkpt={number=\"3\",addr=\"<MULTIPLE>\"},{number=\"3.1\",line=\"7\"},{number=\"3.2\",line=\"9\"}")
    test.require(parser.valid && parser.data.field("bkpt").field("locations").values.length == 2 &&
        (parser.data.field("bkpt").field("locations").values[1] as MiValue).field("line").text.equals("9"),
        "legacy GDB unlabelled multiple breakpoint locations")
    parser.parse("=breakpoint-modified,bkpt={number=\"3\",locations=[{number=\"3.1\",line=\"7\"}]}")
    test.require(parser.valid && parser.data.field("bkpt").field("locations").values.length == 1,
        "nested multiple breakpoint locations")
    parser.parse("1^done,bkpt={number=\"3\"},{number=\"4.1\"}")
    test.require(!parser.valid, "unrelated unlabelled tuple rejected")
    parser.parse("1^done,other={number=\"3\"},{number=\"3.1\"}")
    test.require(!parser.valid, "unlabelled tuple outside bkpt rejected")
    parser.parse("1^done,values=[{name=\"x\"},]")
    test.require(!parser.valid, "trailing comma rejected")
    parser.parse("1^done,msg=\"unfinished")
    test.require(!parser.valid, "unterminated string rejected")
    parser.parse("1^done,msg=\"bad\\q\"")
    test.require(!parser.valid, "unknown escape rejected")
    parser.parse("1^done,msg=\"\\777\"")
    test.require(!parser.valid, "invalid byte escape rejected")
    String deep = "1^done,x="
    int i = 0
    while (i < 40) { deep.append("[")
        i = i + 1 }
    deep.append("\"x\"")
    i = 0
    while (i < 40) { deep.append("]")
        i = i + 1 }
    parser.parse(deep)
    test.require(!parser.valid, "depth bounded")
    print("true")
}
'''

DRIVER = r'''
import time
class DebugUiFixture {
    bool alert()
    bool panes()
    bool noEmoji()
    bool centered()
    void track()
    int changes()
    bool bordered()
    int closeButtons()
    bool closeTab(String name)
    bool sourceVisible()
    bool findVisible()
    bool findClick(String name)
    bool shortcut(String trigger)
    void choose(String path)
    bool compact()
    bool lineClick(String pane, int line, String action)
    int marks(String file, int line)
    bool watchDialog(String expression, bool accept)
}
bool DebugUiFixture.alert() from "cdbg_fixture_alert"
bool DebugUiFixture.panes() from "cdbg_fixture_panes"
bool DebugUiFixture.noEmoji() from "cdbg_fixture_no_emoji"
bool DebugUiFixture.centered() from "cdbg_fixture_centered"
void DebugUiFixture.track() from "cdbg_fixture_track"
int DebugUiFixture.changes() from "cdbg_fixture_changes"
bool DebugUiFixture.bordered() from "cdbg_fixture_bordered"
int DebugUiFixture.closeButtons() from "cdbg_fixture_close_buttons"
bool DebugUiFixture.closeTab(String name) from "cdbg_fixture_close_tab"
bool DebugUiFixture.sourceVisible() from "cdbg_fixture_source_visible"
bool DebugUiFixture.findVisible() from "cdbg_fixture_find_visible"
bool DebugUiFixture.findClick(String name) from "cdbg_fixture_find_click"
bool DebugUiFixture.shortcut(String trigger) from "cdbg_fixture_shortcut"
void DebugUiFixture.choose(String path) from "cdbg_fixture_choose"
bool DebugUiFixture.compact() from "cdbg_fixture_compact"
bool DebugUiFixture.lineClick(String pane, int line, String action) from "cdbg_fixture_line_click"
int DebugUiFixture.marks(String file, int line) from "cdbg_fixture_marks"
bool DebugUiFixture.watchDialog(String expression, bool accept) from "cdbg_fixture_watch"

class DebugChecks {
    Cdbg ui
    int stage
    int stops
    unsigned deadline
    String mode
    String oldPid
    void require(bool condition, String label) {
        if (!condition) {
            System.StandardIO().writeErrorLine(format("FAIL {} stage {}: {} ({})",
                mode, stage, label, ui.status.text()))
            ui.endSession()
            System.Process().exit(1)
        }
    }
    void activate() {
        mode = System.Process().getEnv("CDBG_TEST_MODE")
        ui = Cdbg()
        ui.activate()
        ui.consume("~\"fragment")
        require(ui.console.text().equals(""), "incomplete record buffered")
        ui.consume("ed\\n\"\n")
        require(ui.console.text().equals("fragmented\n"), "fragmented record reassembled")
        deadline = Time.Clock().monotonicMilliseconds() + 20000u
        if (mode.equals("ui") || mode.equals("context")) {
            require(ui.sourceTabs.pageCount() == 1 && ui.source.text().startsWith("No source"),
                "source area starts with a placeholder page")
        }
        ui.loadTarget(System.Process().getEnv("CDBG_TEST_TARGET"))
        Gtk.Application().post(_self().tick)
    }
    int pages
    // Open Source Code rejection: wait for the parented dialog, then require
    // the source notebook to be visible with its tabs unchanged.
    bool rejected(String label) {
        if (!DebugUiFixture().alert()) { return false }
        require(!ui.failure.equals(""), label)
        require(ui.sourceTabs.pageCount() == pages && DebugUiFixture().sourceVisible() &&
            DebugUiFixture().closeButtons() == pages && ui.source.text().contains("counter"),
            format("{}: failed open leaves source tabs visible and unchanged", label))
        ui.failure = ""
        return true
    }
    void found(String button, String expected) {
        require(DebugUiFixture().findClick(button), format("Find dialog {} button", button))
        require(ui.findStatus.text().equals(expected),
            format("{} reported '{}' expecting '{}'", button, ui.findStatus.text(), expected))
    }
    bool uiTick() {
        String work = System.Process().getEnv("CDBG_TEST_WORK")
        String notes = format("{}/notes.txt", work)
        if (stage == 0 && ui.loaded && idle()) {
            require(ui.failure.equals(""), ui.failure)
            require(DebugUiFixture().bordered(), "source and inspector tabs are bordered")
            pages = ui.sourceTabs.pageCount()
            require(pages == 2 && DebugUiFixture().closeButtons() == 2 &&
                DebugUiFixture().sourceVisible(), "each DWARF source tab has a close icon")
            require(!ui.openSource(format("{}/missing.txt", work)), "missing source rejected")
            stage = 1
        }
        if (stage == 1 && rejected("missing source")) {
            require(!ui.openSource(format("{}/binary.cw", work)), "binary source rejected")
            stage = 2
        }
        if (stage == 2 && rejected("binary source")) {
            require(!ui.openSource(System.Process().getEnv("CDBG_TEST_TARGET")),
                "executable rejected by Open Source Code")
            stage = 3
        }
        if (stage == 3 && rejected("executable as source")) {
            require(!ui.openSource(format("{}/invalid-utf8.cw", work)), "invalid UTF-8 rejected")
            stage = 4
        }
        if (stage == 4 && rejected("invalid UTF-8 source")) {
            require(ui.loaded && !ui.hasRun, "rejections leave the debug session alone")
            require(ui.openSource(notes) && ui.sourceTabs.pageCount() == 3 &&
                DebugUiFixture().closeButtons() == 3 && ui.source.text().contains("needle"),
                "text source opens in a closable tab without compiling")
            require(ui.openSource(notes) && ui.sourceTabs.pageCount() == 3, "reopen reuses tab")
            require(ui.failure.equals("") && ui.loaded && !ui.hasRun, "Open Source keeps session")
            require(DebugUiFixture().shortcut("<Control>f") && DebugUiFixture().findVisible(),
                "Ctrl+F shows Find dialog")
            ui.source.centerCursor(1, 1)
            ui.findEntry.setText("needle")
            found("Find Next", "Found: needle at line 2")
            found("Find Next", "Found: needle at line 4")
            found("Find Next", "Wrapped: needle at line 2")
            found("Find Previous", "Wrapped: needle at line 4")
            found("Find Previous", "Found: needle at line 2")
            ui.findEntry.setText("absent")
            found("Find Next", "Not found: absent")
            found("Close", "Not found: absent")
            require(!DebugUiFixture().findVisible(), "Close hides Find dialog")
            require(DebugUiFixture().closeTab("helper.c") && DebugUiFixture().closeTab("notes.txt") &&
                ui.sourceTabs.pageCount() == 1 && DebugUiFixture().closeButtons() == 1,
                "close icons remove tabs")
            require(ui.loaded && ui.process != null, "closing tabs keeps the debug session")
            ui.addBreakpoint(format("{}:{}", System.Process().getEnv("CDBG_TEST_SOURCE"),
                System.Process().getEnv("CDBG_TEST_LINE")))
            stage = 5
        }
        if (stage == 5 && idle()) { ui.resume()
            stage = 6 }
        if (stage == 6 && ui.stopCount > 0 && !ui.running && idle()) {
            require(ui.sourceTabs.pageCount() == 1, "stop in open file adds no tab")
            stops = ui.stopCount
            ui.stepInto()
            stage = 7
        }
        if (stage == 7 && ui.stopCount > stops && !ui.running && idle()) {
            require(ui.source.text().contains("doubled") && ui.sourceTabs.pageCount() == 2 &&
                DebugUiFixture().closeButtons() == 2, "stop reopens closed file once")
            stops = ui.stopCount
            ui.stepOver()
            stage = 8
        }
        if (stage == 8 && ui.stopCount > stops && !ui.running && idle()) {
            require(ui.sourceTabs.pageCount() == 2, "stepping in reopened file adds no duplicate")
            require(DebugUiFixture().closeTab("helper.c") &&
                DebugUiFixture().closeTab(System.FileSystem().basename(
                    System.Process().getEnv("CDBG_TEST_SOURCE"))),
                "close every file tab")
            require(ui.sourceTabs.pageCount() == 1 && DebugUiFixture().closeButtons() == 0 &&
                DebugUiFixture().sourceVisible() && ui.source.text().startsWith("No source"),
                "closing the last tab leaves a visible placeholder")
            DebugUiFixture().choose(System.Process().getEnv("CDBG_TEST_TARGET"))
            ui.menu.activateItem(ui.loadItem)
            stage = 9
        }
        if (stage == 9 && ui.loaded && !ui.hasRun && idle() && ui.sourceTabs.pageCount() == 2) {
            require(ui.breaks.text().equals("") && ui.failure.equals("") &&
                DebugUiFixture().closeButtons() == 2 && ui.source.text().contains("counter"),
                "File > Load Executable starts a fresh session with DWARF tabs")
            DebugUiFixture().choose(notes)
            ui.menu.activateItem(ui.openItem)
            stage = 10
        }
        if (stage == 10 && ui.sourceTabs.pageCount() == 3) {
            require(ui.source.text().contains("needle") && ui.loaded && !ui.hasRun &&
                ui.failure.equals(""), "File > Open Source Code opens text without loading it")
            require(ui.window.hasShortcut("<Control>q") && ui.window.hasShortcut("<Control>f"),
                "Quit and Find shortcuts bound on the window")
            ui.menu.activateItem(ui.quitItem)
            require(ui.closed && ui.process == null, "Quit closes the debugger and GDB")
            print("true")
            return false
        }
        return true
    }
    DebugChecks _self()
    bool idle() { return ui.active == null && ui.requests.length == 0 }
    bool contextTick() {
        String path = System.Process().getEnv("CDBG_TEST_SOURCE")
        String helper = System.FileSystem().join(System.FileSystem().dirname(path), "context_helper.c")
        if (stage == 0 && ui.loaded && idle()) {
            require(DebugUiFixture().compact(), "main window has no breakpoint/watch/frame rows or End Session")
            ui.showSource(path, "")
            if (!DebugUiFixture().lineClick("", 7, "Add Breakpoint")) { return true }
            require(ui.source.line() == 7, format("source context click positions cursor at line 7, got {}",
                ui.source.line()))
            stage = 1
        }
        if (stage == 1 && idle()) {
            require(ui.breaks.text().contains("#1") && DebugUiFixture().marks("context.c", 7) == 1,
                "resolved file:line breakpoint has a colored mark and icon")
            require(ui.source.line() == 7, "adding marks retains source cursor")
            if (!DebugUiFixture().lineClick("", 7, "Delete Breakpoint")) { return true }
            stage = 2
        }
        if (stage == 2 && idle()) {
            require(ui.breaks.text().equals("") && DebugUiFixture().marks("context.c", 7) == 0,
                "source context delete removes breakpoint and marker")
            if (!DebugUiFixture().lineClick("", 7, "Add Breakpoint")) { return true }
            stage = 3
        }
        if (stage == 3 && idle()) {
            require(ui.breaks.text().contains("#2") && DebugUiFixture().marks("context.c", 7) == 1,
                "source breakpoint restored")
            ui.addBreakpoint("shared_point")
            stage = 4
        }
        if (stage == 4 && idle()) {
            require(ui.breaks.text().contains("#3") && DebugUiFixture().marks("context.c", 3) == 1 &&
                DebugUiFixture().marks("context_helper.c", 2) == 1,
                "multiple GDB breakpoint locations marked in all source tabs")
            if (!DebugUiFixture().lineClick("Breakpoints", 2, "Delete Breakpoint")) { return true }
            require(ui.breaks.hasSelection() && ui.breaks.selectedText().contains("#3"),
                "breakpoint context click highlights the selected entry")
            stage = 5
        }
        if (stage == 5 && idle()) {
            require(!ui.breaks.text().contains("#3") && ui.breaks.text().contains("#2") &&
                DebugUiFixture().marks("context.c", 3) == 0 &&
                DebugUiFixture().marks("context_helper.c", 2) == 0 &&
                DebugUiFixture().marks("context.c", 7) == 1,
                "selected breakpoint deletion clears every child marker, not other breakpoints")
            ui.showSource(path, "")
            require(DebugUiFixture().closeTab("context.c"), "close marked source tab")
            require(ui.showSource(path, "") && DebugUiFixture().marks("context.c", 7) == 1,
                "reopened tab inherits breakpoint marks")
            if (!DebugUiFixture().lineClick("Watches", 1, "Add Watch...")) { return true }
            require(DebugUiFixture().watchDialog("ignored", false) && ui.expressions.length == 0,
                "parented watch dialog Cancel adds nothing")
            stage = 6
        }
        if (stage == 6) {
            if (!DebugUiFixture().lineClick("Watches", 1, "Add Watch...")) { return true }
            require(DebugUiFixture().watchDialog("counter", true), "watch dialog Add accepts expression")
            stage = 7
        }
        if (stage == 7) {
            if (!DebugUiFixture().lineClick("Watches", 1, "Add Watch...")) { return true }
            require(DebugUiFixture().watchDialog("not_in_scope", true), "watch dialog accepts unknown expression")
            require(ui.expressions.length == 2, "watch expressions retained")
            ui.resume()
            stage = 8
        }
        if (stage == 8 && ui.stopCount > 0 && !ui.running && idle()) {
            require(ui.source.line() == 7 && ui.source.text().contains("int main") &&
                ui.watches.text().contains("counter = 21") &&
                ui.watches.text().contains("not_in_scope = <"),
                "dialog watches evaluate at stop, including out-of-scope errors")
            require(DebugUiFixture().marks("context.c", 7) == 1, "stop retains distinct breakpoint marking")
            stops = ui.stopCount
            ui.restart()
            stage = 9
        }
        if (stage == 9 && ui.stopCount > stops && !ui.running && idle()) {
            require(DebugUiFixture().marks("context.c", 7) == 1 && ui.breaks.text().contains("#2"),
                "Restart retains breakpoint state and marks")
            stops = ui.stopCount
            ui.stepInto()
            stage = 10
        }
        if (stage == 10 && ui.stopCount > stops && !ui.running && idle()) {
            require(ui.source.text().contains("int doubled") && ui.source.line() == 5,
                "execution stops inside helper")
            stops = ui.stopCount
            if (!DebugUiFixture().lineClick("Stack", 2, "")) { return true }
            stage = 11
        }
        if (stage == 11 && idle()) {
            require(ui.selectedFrame == 1 && ui.source.text().contains("int main") &&
                ui.source.line() == 7 && ui.locals.text().contains("counter = 21") &&
                ui.watches.text().contains("counter = 21") && ui.stopCount == stops,
                "single stack click navigates caller and refreshes inspection without execution")
            ui.stepOver()
            stage = 12
        }
        if (stage == 12 && ui.stopCount > stops && !ui.running && idle()) {
            require(ui.selectedFrame == 0 && ui.source.text().contains("int doubled") &&
                ui.source.line() == 6 && ui.locals.text().contains("doubled = 42"),
                "Step Over restores actual execution frame and returns to helper's next line")
            require(ui.showSource(path, "") && DebugUiFixture().marks("context.c", 7) == 1,
                "switching files keeps markers")
            ui.loadTarget(System.Process().getEnv("CDBG_TEST_TARGET"))
            stage = 13
        }
        if (stage == 13 && ui.loaded && idle()) {
            require(ui.breaks.text().equals("") && DebugUiFixture().marks("context.c", 7) == 0 &&
                DebugUiFixture().marks("context_helper.c", 2) == 0 && !ui.hasRun,
                "fresh load clears breakpoint markers in rebuilt tabs")
            require(ui.failure.equals(""), ui.failure)
            ui.window.close()
            require(ui.closed && ui.process == null && ui.terminal == null && ui.pollToken == 0 &&
                ui.watchWindow.disposed(), "Quit cleans GDB, output transport, watch dialog and polling")
            print("true")
            return false
        }
        return true
    }
    void tick() {
        require(Time.Clock().monotonicMilliseconds() < deadline, "session deadline")
        if (mode.equals("ui")) {
            if (uiTick()) { Gtk.Application().post(_self().tick) }
            return
        }
        if (mode.equals("context")) {
            if (contextTick()) { Gtk.Application().post(_self().tick) }
            return
        }
        if (mode.equals("missing") || mode.equals("compile-error") || mode.equals("invalid-target") ||
            mode.equals("missing-file") || mode.equals("binary-source") || mode.equals("invalid-utf8") ||
            mode.equals("missing-source")) {
            if (!ui.failure.equals("")) {
                if (!mode.equals("missing-source")) {
                    require(!ui.loaded && !ui.running, "failed startup not success-shaped")
                }
                if (!mode.equals("missing")) {
                    if (!DebugUiFixture().alert()) { Gtk.Application().post(_self().tick)
                        return }
                }
                ui.endSession()
                ui.window.close()
                print("true")
                return
            }
        } else {
            require(ui.failure.equals(""), ui.failure)
            require(DebugUiFixture().panes(), "all text panes read-only without Emoji hint")
            if (mode.equals("scroll")) {
                if (stage == 0 && ui.loaded && idle()) {
                    ui.addBreakpoint(format("{}:{}", System.Process().getEnv("CDBG_TEST_SOURCE"),
                        System.Process().getEnv("CDBG_TEST_LINE")))
                    stage = 1
                }
                if (stage == 1 && idle()) { ui.resume()
                    stage = 2 }
                if (stage == 2 && ui.stopCount > 0 && !ui.running && idle() &&
                    DebugUiFixture().centered()) {
                    require(DebugUiFixture().noEmoji(), "actual context menu omits Insert Emoji")
                    DebugUiFixture().track()
                    stops = ui.stopCount
                    ui.stepOver()
                    stage = 3
                }
                if (stage == 3 && ui.stopCount > stops && !ui.running && idle() &&
                    DebugUiFixture().centered()) {
                    require(DebugUiFixture().changes() == 0, "step retains source buffer text")
                    require(ui.sourceTabs.pageCount() == 1, "steps reuse existing file tab")
                    ui.window.close()
                    print("true")
                    return
                }
                Gtk.Application().post(_self().tick)
                return
            }
            if (mode.equals("no-source") && ui.loaded && idle()) {
                require(ui.source.text().startsWith("Source unavailable:"),
                    "missing debug source explicitly reported")
                require(DebugUiFixture().shortcut("<Control>q") && ui.closed && ui.process == null,
                    "Ctrl+Q quits through the window shortcut")
                print("true")
                return
            }
            if (mode.equals("no-source")) {
                Gtk.Application().post(_self().tick)
                return
            }
            if (mode.equals("cancel")) {
                if (stage == 0 && ui.loaded && idle()) { ui.resume()
                    stage = 1 }
                if (stage == 1 && ui.running && idle() && ui.programOutput.text().contains("ready")) {
                    ui.interrupt()
                    stage = 2 }
                if (stage == 2 && !ui.running && ui.stopCount > 0 && idle()) {
                    require(!ui.inferiorPid.equals(""), "inferior PID received")
                    ui.resume()
                    stage = 3
                }
                if (stage == 3 && ui.running && idle()) {
                    oldPid = ui.inferiorPid
                    ui.restart()
                    stage = 4
                }
                if (stage == 4 && ui.running && idle() && !ui.restarting &&
                    !ui.inferiorPid.equals(oldPid)) {
                    String pid = ui.inferiorPid
                    ui.window.close()
                    require(ui.closed && ui.process == null && ui.pollToken == 0,
                        "close running session cleans up")
                    print(format("true:{}:{}", oldPid, pid))
                    return
                }
                Gtk.Application().post(_self().tick)
                return
            }
            if (stage == 0 && ui.loaded && idle()) {
                require(ui.source.text().contains("counter"), "source visible immediately after Load")
                require(DebugUiFixture().noEmoji(), "source context menu excludes Emoji")
                if (mode.equals("native")) {
                    require(ui.sourceTabs.pageCount() == 2, "multiple source files have tabs")
                }
                ui.addBreakpoint(format("{}:{}", System.Process().getEnv("CDBG_TEST_SOURCE"),
                    System.Process().getEnv("CDBG_TEST_LINE")))
                stage = 1
            }
            if (stage == 1 && idle()) {
                require(ui.breaks.text().contains("#1"), "breakpoint listed")
                ui.addWatch("counter")
                ui.addWatch("not_in_scope")
                ui.resume()
                stage = 2
            }
            if (stage == 2 && ui.stopCount >= 1 && !ui.running && idle()) {
                require(ui.location.contains(System.Process().getEnv("CDBG_TEST_SOURCE")), "source stop")
                require(ui.source.text().contains("counter"), "source displayed")
                require(ui.source.line() == System.Process().getEnv("CDBG_TEST_LINE").toInt(),
                    "current source line highlighted")
                require(ui.locals.text().contains("counter = 21"), "DWARF scalar local")
                require(ui.watches.text().contains("counter = 21") &&
                    ui.watches.text().contains("not_in_scope = <"), "watches and evaluation failure")
                require(ui.stack.text().contains("#0"), "stack")
                ui.addWatch("counter + 1")
                ui.selectFrame("0")
                stage = 3
            }
            if (stage == 3 && idle()) {
                require(ui.watches.text().contains("counter + 1 = 22") &&
                    ui.watches.text().split("counter = 21").length == 2,
                    "new watches and frame refresh replace stale inspection")
                stops = ui.stopCount
                oldPid = ui.inferiorPid
                ui.restart()
                stage = 30
            }
            if (stage == 30 && ui.stopCount > stops && !ui.running && idle()) {
                require(!ui.inferiorPid.equals(oldPid), "Restart replaces stopped inferior")
                require(ui.breaks.text().contains("#1") &&
                    ui.watches.text().contains("counter + 1 = 22"),
                    "Restart preserves breakpoints and watches")
                stops = ui.stopCount
                ui.stepInto()
                stage = 4
            }
            if (stage == 4 && ui.stopCount > stops && !ui.running && idle()) {
                if (mode.equals("native")) {
                    require(ui.source.text().contains("doubled") && ui.sourceTabs.pageCount() == 2,
                        "stop switches to helper file without a duplicate tab")
                }
                stops = ui.stopCount
                ui.stepOver()
                stage = 5
            }
            if (stage == 5 && ui.stopCount > stops && !ui.running && idle()) {
                stops = ui.stopCount
                ui.stepOut()
                stage = 6
            }
            if (stage == 6 && ui.stopCount > stops && !ui.running && idle()) {
                ui.deleteBreakpoint("1")
                stage = 7
            }
            if (stage == 7 && idle()) {
                require(!ui.breaks.text().contains("#1"), "breakpoint deleted")
                ui.resume()
                stage = 8
            }
            if (stage == 8 && !ui.hasRun && !ui.running && idle()) {
                require(ui.status.text().contains("exited"), "normal inferior exit")
                if (mode.equals("native")) {
                    if (!ui.programOutput.text().contains("stderr-only")) {
                        Gtk.Application().post(_self().tick)
                        return
                    }
                    require(ui.programOutput.text().contains("stdout-only") &&
                        ui.programOutput.text().contains("^9999^done") &&
                        ui.programOutput.text().contains("\\0") &&
                        ui.programOutput.text().length <= 65536 &&
                        !ui.console.text().contains("stdout-only") &&
                        !ui.console.text().contains("stderr-only"),
                        "stdout/stderr and MI-like inferior output isolated from GDB")
                } else {
                    if (!ui.programOutput.text().contains("cwhip-output:42")) {
                        Gtk.Application().post(_self().tick)
                        return
                    }
                    require(!ui.console.text().contains("cwhip-output:42"),
                        "Cwhip output uses Program Output")
                }
                ui.restart()
                stage = 9
            }
            if (stage == 9 && !ui.hasRun && !ui.running && idle() && !ui.restarting) {
                require(ui.status.text().contains("exited"), "Restart after exit runs target again")
                ui.loadTarget(System.Process().getEnv("CDBG_TEST_TARGET"))
                stage = 10
            }
            if (stage == 10 && ui.loaded && idle()) {
                require(!ui.hasRun && !ui.running && ui.breaks.text().equals("") &&
                    ui.source.text().contains("counter"), "Load reloads source without running")
                ui.endSession()
                require(ui.process == null && !ui.loaded && ui.pollToken == 0 &&
                    ui.temporary.equals(""), "owned process and temporary cleanup")
                ui.window.close()
                print("true")
                return
            }
        }
        Gtk.Application().post(_self().tick)
    }
}
DebugChecks DebugChecks._self() from "cwhip_gtk_self"
start {
    Gtk.Application app = Gtk.Application("org.cwhip.CdbgTests")
    DebugChecks checks = DebugChecks()
    app.onActivate(checks.activate)
    app.run()
}
'''

C_FIXTURE = """\
#include "helper.c"
#include <stdio.h>
/* fixture */
/* fixture */
int main(void) {
    int counter = 21;
    counter = helper(counter);
    for (int index = 0; index < 23000; ++index) fputs("\\xe2\\x82\\xac", stdout);
    puts("stdout-only");
    fputs("stderr-only\\n", stderr);
    puts("^9999^done");
    const unsigned char binary[] = {0, 255, '\\n'};
    fwrite(binary, 1, sizeof binary, stdout);
    return counter == 42 ? 0 : 1;
}
"""

CW_FIXTURE = """\
class Counter {
    int double(int value) {
        int doubled = value * 2
        return doubled
    }
}
start {
    Counter worker = Counter()
    int counter = 21
    counter = worker.double(counter)
    print(format("cwhip-output:{}", counter))
}
"""


def compile_program(compiler: Path, source: Path, output: Path, work: Path,
                    env: dict[str, str], objects: list[Path] | None = None) -> None:
    result = invoke([str(compiler), str(source), "-o", str(output)] +
                    [str(obj) for obj in objects or []], work, env)
    assert result.returncode == 0, result.stderr


def binary_smoke(executable: Path, target: Path, compiler: Path, gdb: str,
                 xvfb: str, work: Path, env: dict[str, str]) -> None:
    with headless(xvfb, work, env) as gtk_env:
        gtk_env.update(CDBG_COMPILER=str(compiler), CDBG_GDB=gdb)
        process = subprocess.Popen([str(executable), str(target)], cwd=work, env=gtk_env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        display = Display(gtk_env["DISPLAY"])
        gdb_pid = None
        try:
            window = display.focus_editor()
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and process.poll() is None:
                children = Path(f"/proc/{process.pid}/task/{process.pid}/children").read_text()
                for child in children.split():
                    try:
                        if Path(f"/proc/{child}/exe").resolve().name == Path(gdb).name:
                            gdb_pid = int(child)
                    except FileNotFoundError:
                        pass
                if gdb_pid is not None:
                    break
                time.sleep(0.05)
            assert gdb_pid is not None, "actual cdbg did not compile and start GDB"
            display.settle(0.5)
            display.delete_window(window)
            output = process.communicate(timeout=10)[0]
            assert process.returncode == 0, output
            assert not output, output
            assert not Path(f"/proc/{gdb_pid}").exists(), "actual cdbg leaked GDB on close"
        finally:
            display.close()
            if process.poll() is None:
                process.terminate()
                process.communicate(timeout=10)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--cmake")
    parser.add_argument("--gdb")
    parser.add_argument("--clang")
    parser.add_argument("--xvfb")
    parser.add_argument("--group", choices=("parser", "session", "build"), required=True)
    args = parser.parse_args()
    args.compiler = args.compiler.resolve()
    args.work.mkdir(parents=True, exist_ok=True)
    if args.group == "build":
        command = [args.cmake, "--build", str(args.build), "--target", "cdbg"]
        subprocess.run(command, check=True, timeout=120)
        outputs = [args.executable, args.compiler]
        before = [path.stat().st_mtime_ns for path in outputs]
        subprocess.run(command, check=True, timeout=120)
        assert before == [path.stat().st_mtime_ns for path in outputs], "No-op cdbg rebuild"
        result = subprocess.run([str(args.executable), "--help"], capture_output=True, text=True,
                                timeout=10)
        assert result.returncode == 0 and "Usage: cdbg" in result.stdout, result
        assert not result.stderr, result.stderr
        return
    with tempfile.TemporaryDirectory(dir=args.work.resolve(), prefix="cdbg-") as directory:
        work = Path(directory)
        env = environment(work)
        shutil.copy(args.source.parent / "mi.cw", work / "mi.cw")
        shutil.copy(args.source.parent / "terminal.cw", work / "terminal.cw")
        source = work / "checks.cw"
        binary = work / "checks"
        if args.group == "parser":
            source.write_text('import system\n' + PARSER)
            compile_program(args.compiler, source, binary, work, env)
            result = invoke([str(binary)], work, env)
            assert result.returncode == 0 and result.stdout == "true", result
            assert not result.stderr, result.stderr
            return
        source.write_text(args.source.read_text().split("\nstart {")[0] + DRIVER)
        root = args.source.resolve().parents[2]
        fixture = work / "ui.o"
        terminal = work / "terminal.o"
        gtk_flags = subprocess.check_output(
            ["pkg-config", "--cflags", "gtk4", "gtksourceview-5"], text=True).split()
        subprocess.run([args.clang, "-g", "-c", str(root / "tests/cdbg_ui_fixture.c"),
                        "-I", str(root / "include"), *gtk_flags, "-o", str(fixture)], check=True)
        subprocess.run([args.clang, "-c", str(args.source.parent / "terminal.c"),
                        "-I", str(root / "include"), "-o", str(terminal)], check=True)
        compile_program(args.compiler, source, binary, work, env, [fixture, terminal])
        (work / "helper.c").write_text(
            "int helper(int value) {\n    int doubled = value * 2;\n    return doubled;\n}\n")
        c_source = work / 'target with "quotes".c'
        c_source.write_text(C_FIXTURE)
        c_binary = work / "native target"
        subprocess.run([args.clang, "-g", "-O0", str(c_source), "-o", str(c_binary)], check=True)
        context_source = work / "context.c"
        context_source.write_text(
            "int helper(int value);\nstatic int shared_point(int value) {\n return value + 1;\n}\n"
            "int main(void) {\n int counter = 21;\n counter = helper(counter);\n"
            " return counter == shared_point(41) ? 0 : 1;\n}\n")
        context_helper = work / "context_helper.c"
        context_helper.write_text(
            "static int shared_point(int value) {\n return value + 1;\n}\n"
            "int helper(int value) {\n int doubled = value * 2;\n"
            " return doubled + shared_point(0) - 1;\n}\n")
        context_binary = work / "context target"
        subprocess.run([args.clang, "-g", "-O0", str(context_source), str(context_helper),
                        "-o", str(context_binary)], check=True)
        stripped_binary = work / "no debug info"
        subprocess.run([args.clang, str(c_source), "-o", str(stripped_binary)], check=True)
        (work / "notes.txt").write_text("alpha\nneedle one\nbeta\nneedle two\n")
        vanished_source = work / "vanished.c"
        vanished_source.write_text("int main(void) { return 0; }\n")
        vanished_binary = work / "vanished"
        subprocess.run([args.clang, "-g", str(vanished_source), "-o", str(vanished_binary)], check=True)
        vanished_source.unlink()
        loop_source = work / "loop.c"
        loop_source.write_text('#include <stdio.h>\nint main(void) { volatile unsigned counter = 0; '
                               'puts("ready"); fflush(stdout); while (1) { counter++; } }\n')
        loop_binary = work / "loop"
        subprocess.run([args.clang, "-g", "-O0", str(loop_source), "-o", str(loop_binary)], check=True)
        cw_source = work / "target with spaces.cw"
        cw_source.write_text(CW_FIXTURE)
        bad_source = work / "bad.cw"
        bad_source.write_text("start { missing_symbol() }\n")
        binary_source = work / "binary.cw"
        binary_source.write_bytes(b"\x00not source")
        invalid_utf8 = work / "invalid-utf8.cw"
        invalid_utf8.write_bytes(b"\xffnot source")
        invalid_target = work / "invalid-target"
        invalid_target.write_text("This is not an executable\n")
        scroll_source = work / "scroll.c"
        scroll_source.write_text("\n" * 120 +
            "int main(void) {\n volatile int counter = 21;\n counter++;\n counter++;\n return 0;\n}\n" +
            "\n" * 150)
        scroll_binary = work / "scroll"
        subprocess.run([args.clang, "-g", "-O0", str(scroll_source), "-o", str(scroll_binary)], check=True)
        for mode, target, debug_source, line in (
            ("native", c_binary, c_source, "7"),
            ("cwhip", cw_source, cw_source, "10"),
            ("relative-cwhip", Path(cw_source.name), cw_source, "10"),
            ("no-source", stripped_binary, c_source, "7"),
            ("missing", c_binary, c_source, "7"),
            ("compile-error", bad_source, bad_source, "1"),
            ("invalid-target", invalid_target, invalid_target, "1"),
            ("missing-file", work / "missing.cw", work / "missing.cw", "1"),
            ("binary-source", binary_source, binary_source, "1"),
            ("invalid-utf8", invalid_utf8, invalid_utf8, "1"),
            ("missing-source", vanished_binary, vanished_source, "1"),
            ("scroll", scroll_binary, scroll_source, "123"),
            ("cancel", loop_binary, loop_source, "1"),
            ("ui", c_binary, c_source, "7"),
            ("context", context_binary, context_source, "7"),
        ):
            with headless(args.xvfb, work, env) as gtk_env:
                gtk_env.update(CDBG_TEST_MODE=mode, CDBG_TEST_TARGET=str(target),
                               CDBG_TEST_WORK=str(work),
                               CDBG_TEST_SOURCE=str(debug_source), CDBG_TEST_LINE=line,
                               CDBG_COMPILER=str(args.compiler),
                               CDBG_GDB=args.gdb if mode != "missing" else str(work / "no-gdb"))
                result = invoke([str(binary)], work, gtk_env, timeout=45)
                expected_output = result.stdout == "true"
                if mode == "cancel":
                    expected_output = result.stdout.startswith("true:")
                    for value in result.stdout.split(":")[1:]:
                        pid = int(value)
                        deadline = time.monotonic() + 5
                        while Path(f"/proc/{pid}").exists() and time.monotonic() < deadline:
                            time.sleep(0.05)
                        assert not Path(f"/proc/{pid}").exists(), f"orphan inferior {pid}"
                assert result.returncode == 0 and expected_output, (
                    mode, result.returncode, result.stdout, result.stderr)
                if mode == "ui":
                    lines = [line for line in result.stderr.splitlines() if line]
                    assert len(lines) == 4 and all(line.startswith("cdbg: ") for line in lines), (
                        result.stderr)
                elif mode in ("native", "cwhip", "relative-cwhip", "no-source", "cancel", "scroll", "context"):
                    assert not result.stderr, result.stderr
                else:
                    assert "cdbg:" in result.stderr, result.stderr
        binary_smoke(args.executable.resolve(), cw_source, args.compiler, args.gdb,
                     args.xvfb, work, env)


if __name__ == "__main__":
    main()
