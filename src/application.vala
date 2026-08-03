public class Velox.Application : Adw.Application {
    public Application () {
        Object (
            application_id: "com.github.lalaggi.velox",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    public override void startup () {
        base.startup ();

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
