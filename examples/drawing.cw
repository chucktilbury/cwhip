import gtk
import system

class Demo {
    Gtk.DrawingArea area
    int64 paints
    void<> doneAction
    void<int64, int64> paintAction

    void paint(int64 width, int64 height) {
        paints = paints + 1
        area.setColor(0.12f64, 0.14f64, 0.20f64, 1.0f64)
        area.fillRect(0.0f64, 0.0f64, width, height)
        area.setColor(0.25f64, 0.75f64, 0.40f64, 1.0f64)
        area.fillCircle(width / 2, height / 2, 48.0f64)
        area.setColor(1.0f64, 1.0f64, 1.0f64, 1.0f64)
        area.setLineWidth(2.0f64)
        area.strokeCircle(width / 2, height / 2, 56.0f64)
        area.strokeLine(16.0f64, 16.0f64, width - 16, height - 16)
        area.strokeRect(24.0f64, 24.0f64, width - 48, height - 48)
    }

    void done() {
        if (paints < 1) {
            System.StandardIO().writeErrorLine("DrawingArea did not paint")
            System.Process().exit(1)
        }
        print("Hello DrawingArea")
        Gtk.Application().quit()
    }

    void activate() {
        Gtk.Window window = Gtk.Window("DrawingArea demo")
        window.setDefaultSize(480, 320)
        Gtk.Box layout = Gtk.Box(Gtk.Box.VERTICAL, 0)
        area = Gtk.DrawingArea()
        area.setHExpand(true)
        area.setVExpand(true)
        area.onDraw(paintAction)
        layout.append(area)
        window.setChild(layout)
        window.present()
        area.queueDraw()
        if (System.Process().arg(1).equals("--test")) {
            Gtk.Application().schedule(250, doneAction)
        } else {
            Gtk.Application().schedule(2000, doneAction)
        }
    }
}

start {
    Gtk.Application app = Gtk.Application("org.cwhip.DrawingDemo")
    Demo demo = Demo()
    demo.paintAction = demo.paint
    demo.doneAction = demo.done
    app.onActivate(demo.activate)
    app.run()
}
