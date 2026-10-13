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
class DebugChecks {
    Cdbg ui
    int stage
    int stops
    unsigned deadline
    String mode
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
        ui.target.setText(System.Process().getEnv("CDBG_TEST_TARGET"))
        ui.launch()
        Gtk.Application().post(_self().tick)
    }
    DebugChecks _self()
    bool idle() { return ui.active == null && ui.requests.length == 0 }
    void tick() {
        require(Time.Clock().monotonicMilliseconds() < deadline, "session deadline")
        if (mode.equals("missing") || mode.equals("compile-error") || mode.equals("invalid-target")) {
            if (!ui.failure.equals("")) {
                require(!ui.loaded && !ui.running, "failed startup not success-shaped")
                ui.endSession()
                ui.window.close()
                print("true")
                return
            }
        } else {
            require(ui.failure.equals(""), ui.failure)
            if (mode.equals("cancel")) {
                if (stage == 0 && ui.loaded && idle()) { ui.resume()
                    stage = 1 }
                if (stage == 1 && ui.running && idle()) { ui.interrupt()
                    stage = 2 }
                if (stage == 2 && !ui.running && ui.stopCount > 0 && idle()) {
                    require(!ui.inferiorPid.equals(""), "inferior PID received")
                    ui.resume()
                    stage = 3
                }
                if (stage == 3 && ui.running && idle()) {
                    String pid = ui.inferiorPid
                    ui.window.close()
                    require(ui.closed && ui.process == null && ui.pollToken == 0,
                        "close running session cleans up")
                    print(format("true:{}", pid))
                    return
                }
                Gtk.Application().post(_self().tick)
                return
            }
            if (stage == 0 && ui.loaded && idle()) {
                ui.breakpoint.setText(format("{}:{}", System.Process().getEnv("CDBG_TEST_SOURCE"),
                    System.Process().getEnv("CDBG_TEST_LINE")))
                ui.addBreakpoint()
                stage = 1
            }
            if (stage == 1 && idle()) {
                require(ui.breaks.text().contains("#1"), "breakpoint listed")
                ui.watch.setText("counter")
                ui.addWatch()
                ui.watch.setText("not_in_scope")
                ui.addWatch()
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
                ui.watch.setText("counter + 1")
                ui.addWatch()
                ui.frameNumber.setText("0")
                ui.selectFrame()
                stage = 3
            }
            if (stage == 3 && idle()) {
                require(ui.watches.text().contains("counter + 1 = 22") &&
                    ui.watches.text().split("counter = 21").length == 2,
                    "new watches and frame refresh replace stale inspection")
                stops = ui.stopCount
                ui.stepInto()
                stage = 4
            }
            if (stage == 4 && ui.stopCount > stops && !ui.running && idle()) {
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
                ui.breakpointNumber.setText("1")
                ui.deleteBreakpoint()
                stage = 7
            }
            if (stage == 7 && idle()) {
                require(!ui.breaks.text().contains("#1"), "breakpoint deleted")
                ui.resume()
                stage = 8
            }
            if (stage == 8 && !ui.hasRun && !ui.running && idle()) {
                require(ui.status.text().contains("exited"), "normal inferior exit")
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
int helper(int value) {
    int doubled = value * 2;
    return doubled;
}
int main(void) {
    int counter = 21;
    counter = helper(counter);
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
    print(counter)
}
"""


def compile_program(compiler: Path, source: Path, output: Path, work: Path,
                    env: dict[str, str]) -> None:
    result = invoke([str(compiler), str(source), "-o", str(output)], work, env)
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
        compile_program(args.compiler, source, binary, work, env)
        c_source = work / 'target with "quotes".c'
        c_source.write_text(C_FIXTURE)
        c_binary = work / "native target"
        subprocess.run([args.clang, "-g", "-O0", str(c_source), "-o", str(c_binary)], check=True)
        loop_source = work / "loop.c"
        loop_source.write_text("int main(void) { volatile int counter = 0; while (1) { counter++; } }\n")
        loop_binary = work / "loop"
        subprocess.run([args.clang, "-g", "-O0", str(loop_source), "-o", str(loop_binary)], check=True)
        cw_source = work / "target with spaces.cw"
        cw_source.write_text(CW_FIXTURE)
        bad_source = work / "bad.cw"
        bad_source.write_text("start { missing_symbol() }\n")
        invalid_target = work / "invalid-target"
        invalid_target.write_text("This is not an executable\n")
        for mode, target, debug_source, line in (
            ("native", c_binary, c_source, "7"),
            ("cwhip", cw_source, cw_source, "10"),
            ("missing", c_binary, c_source, "7"),
            ("compile-error", bad_source, bad_source, "1"),
            ("invalid-target", invalid_target, invalid_target, "1"),
            ("cancel", loop_binary, loop_source, "1"),
        ):
            with headless(args.xvfb, work, env) as gtk_env:
                gtk_env.update(CDBG_TEST_MODE=mode, CDBG_TEST_TARGET=str(target),
                               CDBG_TEST_SOURCE=str(debug_source), CDBG_TEST_LINE=line,
                               CDBG_COMPILER=str(args.compiler),
                               CDBG_GDB=args.gdb if mode != "missing" else str(work / "no-gdb"))
                result = invoke([str(binary)], work, gtk_env, timeout=45)
                expected_output = result.stdout == "true"
                if mode == "cancel":
                    expected_output = result.stdout.startswith("true:")
                    pid = int(result.stdout.split(":")[1])
                    deadline = time.monotonic() + 5
                    while Path(f"/proc/{pid}").exists() and time.monotonic() < deadline:
                        time.sleep(0.05)
                    assert not Path(f"/proc/{pid}").exists(), f"orphan inferior {pid}"
                assert result.returncode == 0 and expected_output, (
                    mode, result.returncode, result.stdout, result.stderr)
                if mode in ("native", "cwhip", "cancel"):
                    assert not result.stderr, result.stderr
                else:
                    assert "cdbg:" in result.stderr, result.stderr
        binary_smoke(args.executable.resolve(), cw_source, args.compiler, args.gdb,
                     args.xvfb, work, env)


if __name__ == "__main__":
    main()
