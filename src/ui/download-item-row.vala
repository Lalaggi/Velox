public class Velox.DownloadItemRow : Adw.ActionRow {
    public Velox.DownloadItem item { get; construct; }

    private Gtk.Label status_label;
    private Gtk.Label duration_label;
    private Gtk.ProgressBar progress_bar;
    private Gtk.Button action_button;
    private Gtk.Image thumb_image;

    public signal void remove_clicked (Velox.DownloadItem item);
    public signal void retry_clicked (Velox.DownloadItem item);
    public signal void open_folder_clicked (Velox.DownloadItem item);

    public DownloadItemRow (Velox.DownloadItem item) {
        Object (item: item);
    }

    construct {
        activatable = false;

        // Site-aware thumbnail placeholder
        thumb_image = new Gtk.Image.from_icon_name (icon_for_url (item.url));
        thumb_image.pixel_size = 24;
        thumb_image.add_css_class ("dim-label");
        thumb_image.valign = Gtk.Align.CENTER;
        add_prefix (thumb_image);

        duration_label = new Gtk.Label ("");
        duration_label.add_css_class ("caption");
        duration_label.add_css_class ("dim-label");
        duration_label.visible = false;
        duration_label.xalign = 0;
        add_suffix (duration_label);

        status_label = new Gtk.Label ("");
        status_label.add_css_class ("dim-label");
        status_label.add_css_class ("caption");
        status_label.ellipsize = Pango.EllipsizeMode.END;
        status_label.max_width_chars = 18;
        status_label.width_chars = 14;
        status_label.xalign = 1;
        add_suffix (status_label);

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.width_request = 140;
        progress_bar.show_text = false;
        progress_bar.visible = false;
        progress_bar.valign = Gtk.Align.CENTER;
        add_suffix (progress_bar);

        action_button = new Gtk.Button ();
        action_button.icon_name = "window-close-symbolic";
        action_button.tooltip_text = "Remove";
        action_button.add_css_class ("flat");
        action_button.add_css_class ("circular");
        action_button.valign = Gtk.Align.CENTER;
        action_button.clicked.connect (() => {
            if (item.state == DONE) {
                open_folder_clicked (item);
                return;
            }
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
            // Keep status_label in sync unless row is showing detailed download status
            if (item.state != DOWNLOADING) {
                status_label.label = item.status_text;
            }
        });
        item.notify["duration"].connect (() => {
            string d = item.get_duration_string ();
            if (d.length > 0) {
                duration_label.label = d;
                duration_label.visible = true;
            }
        });
        // If duration already set before row creation
        if (item.get_duration_string ().length > 0) {
            duration_label.label = item.get_duration_string ();
            duration_label.visible = true;
        }
    }

    private string icon_for_url (string url) {
        string l = url.down ();
        if (l.contains ("instagram.com")) return "camera-photo-symbolic";
        if (l.contains ("tiktok.com")) return "media-tape-symbolic";
        if (l.contains ("soundcloud.com")) return "audio-x-generic-symbolic";
        if (l.contains ("bandcamp.com")) return "audio-x-generic-symbolic";
        if (l.contains ("twitch.tv")) return "video-display-symbolic";
        return "video-display-symbolic";
    }

    public void set_title_from_url () {
        // Update icon per site (yt-dlp supports ~1800 extractors)
        thumb_image.icon_name = icon_for_url (item.url);
        // Truncate long URLs for display
        string display = item.url;
        if (display.length > 60) {
            display = display.substring (0, 57) + "...";
        }
        title = Markup.escape_text (display);
    }

    public new void set_subtitle (string sub) {
        subtitle = sub;
    }

    public void show_progress () {
        progress_bar.visible = true;
        progress_bar.fraction = 0;
        status_label.visible = false;
        duration_label.visible = false;
    }

    public void update_progress (double fraction) {
        progress_bar.fraction = fraction;
        // Show percentage as text when >0, else keep hidden
        if (fraction > 0) {
            progress_bar.show_text = true;
            progress_bar.text = "%.0f%%".printf (fraction * 100);
        } else {
            progress_bar.show_text = false;
        }
        // Also update status_label if you want overlay? Keep progress bar text.
    }

    public void hide_progress () {
        progress_bar.visible = false;
        progress_bar.show_text = false;
        status_label.visible = true;
        // duration stays visible if set
        if (item.get_duration_string ().length > 0) {
            duration_label.visible = true;
        }
    }

    public void set_state_downloading () {
        action_button.icon_name = "process-stop-symbolic";
        action_button.tooltip_text = "Cancel download";
        action_button.remove_css_class ("success");
        action_button.remove_css_class ("error");
        action_button.add_css_class ("flat");
        action_button.sensitive = true;
    }

    public void set_state_done () {
        action_button.icon_name = "folder-open-symbolic";
        action_button.tooltip_text = "Open containing folder — click to dismiss with × in menu";
        // Keep flat but add success accent on icon via css? Use suggested-action subtle
        action_button.remove_css_class ("flat");
        action_button.add_css_class ("success");
        action_button.remove_css_class ("error");
        action_button.sensitive = true;
        thumb_image.icon_name = "emblem-ok-symbolic";
        thumb_image.remove_css_class ("dim-label");
        thumb_image.add_css_class ("success");
    }

    public void set_state_error () {
        action_button.icon_name = "view-refresh-symbolic";
        action_button.tooltip_text = "Retry download";
        action_button.remove_css_class ("flat");
        action_button.remove_css_class ("success");
        action_button.add_css_class ("error");
        action_button.sensitive = true;
        thumb_image.icon_name = "dialog-error-symbolic";
        thumb_image.remove_css_class ("dim-label");
        thumb_image.add_css_class ("error");
        add_css_class ("error");
    }

    public void set_state_retrying () {
        action_button.icon_name = "content-loading-symbolic";
        action_button.tooltip_text = "Retrying…";
        action_button.sensitive = false;
    }
}
