public class Velox.DownloadItemRow : Adw.ActionRow {
    public Velox.DownloadItem item { get; construct; }

    private Gtk.Label status_label;
    private Gtk.ProgressBar progress_bar;
    private Gtk.Button action_button;

    public signal void remove_clicked (Velox.DownloadItem item);
    public signal void retry_clicked (Velox.DownloadItem item);

    public DownloadItemRow (Velox.DownloadItem item) {
        Object (item: item);
    }

    construct {
        activatable = false;

        status_label = new Gtk.Label ("");
        status_label.add_css_class ("dim-label");
        status_label.add_css_class ("caption");
        status_label.width_chars = 14;
        status_label.xalign = 1;
        add_suffix (status_label);

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.width_request = 120;
        progress_bar.show_text = false;
        progress_bar.visible = false;
        progress_bar.valign = Gtk.Align.CENTER;
        add_suffix (progress_bar);

        action_button = new Gtk.Button ();
        action_button.icon_name = "window-close-symbolic";
        action_button.tooltip_text = "Remove";
        action_button.add_css_class ("flat");
        action_button.add_css_class ("circular");
        action_button.clicked.connect (() => {
            if (item.state == ERROR && item.error_message.length > 0) {
                retry_clicked (item);
            } else {
                remove_clicked (item);
            }
        });
        add_suffix (action_button);

        item.notify["title"].connect (() => {
            if (item.title.length > 0) {
                title = Markup.escape_text (item.title);
            }
        });
        item.notify["status-text"].connect (() => {
            status_label.label = item.status_text;
        });
    }

    public void set_title_from_url () {
        title = Markup.escape_text (item.url);
    }

    public void set_subtitle (string sub) {
        subtitle = sub;
    }

    public void show_progress () {
        progress_bar.visible = true;
        progress_bar.fraction = 0;
    }

    public void update_progress (double fraction) {
        progress_bar.fraction = fraction;
    }

    public void hide_progress () {
        progress_bar.visible = false;
    }

    public void set_state_downloading () {
        action_button.icon_name = "process-stop-symbolic";
        action_button.tooltip_text = "Cancel";
    }

    public void set_state_done () {
        action_button.icon_name = "object-select-symbolic";
        action_button.tooltip_text = "Dismiss";
        action_button.remove_css_class ("flat");
        action_button.add_css_class ("success");
    }

    public void set_state_error () {
        action_button.icon_name = "view-refresh-symbolic";
        action_button.tooltip_text = "Retry";
        action_button.remove_css_class ("flat");
        action_button.add_css_class ("error");
    }

    public void set_state_retrying () {
        action_button.icon_name = "content-loading-symbolic";
        action_button.tooltip_text = "Retrying…";
        action_button.sensitive = false;
    }
}
