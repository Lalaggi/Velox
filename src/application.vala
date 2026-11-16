public class Velox.Application : Adw.Application {
    public Application () {
        Object (
            application_id: "xyz.lalaggi.velox",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    public override void startup () {
        base.startup ();

        // Subtle rounded corners for the video thumbnails in download rows.
        var css = new Gtk.CssProvider ();
        css.load_from_string (".velox-thumb { border-radius: 6px; }");
        var display = Gdk.Display.get_default ();
        if (display != null) {
            Gtk.StyleContext.add_provider_for_display (
                display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        var quit_action = ActionEntry ();
        quit_action.name = "quit";
        quit_action.activate = this.quit;
        this.add_action_entries (new ActionEntry[] { quit_action }, this);
        this.set_accels_for_action ("app.quit", { "<primary>q" });
    }

    public override void activate () {
        base.activate ();

        var win = this.active_window;
        if (win == null) {
            win = new Velox.Window (this);
        }
        win.present ();
    }
}
