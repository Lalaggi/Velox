public class Velox.Window : Adw.ApplicationWindow {
    private Adw.NavigationView nav_view;
    private Adw.ToastOverlay toast_overlay;
    private Adw.StatusPage status_page;
    private Gtk.ListBox url_list;
    private Gtk.Entry url_entry;
    private Gtk.Button next_button;
    private Gtk.Button paste_button;
    private Gtk.Button clear_completed_button;
    private Gtk.Label queue_summary_label;
    private Adw.Banner ytdlp_banner;
    private Gtk.Stack stack;
    private GLib.ListStore item_store;
    private Velox.YtdlpService ytdlp_service;
    private Velox.DownloadManager download_manager;
    private Velox.DownloadOptions download_options;
    private Velox.SettingsManager settings_manager;
    private Velox.OptionsPageBuilder options_builder;

    // Track rows by item identity (not URL string)
    private GLib.HashTable<Velox.DownloadItem, Velox.DownloadItemRow> item_rows;

    public Window (Adw.Application app) {
        Object (
            application: app,
            title: "Velox",
            default_width: 720,
            default_height: 580
        );
    }

    construct {
        item_store = new GLib.ListStore (typeof (Velox.DownloadItem));
        ytdlp_service = new Velox.YtdlpService ();
        download_manager = new Velox.DownloadManager ();
        download_options = new Velox.DownloadOptions ();
        settings_manager = new Velox.SettingsManager ();
        options_builder = new Velox.OptionsPageBuilder ();

        settings_manager.apply_defaults (download_options);

        item_rows = new GLib.HashTable<Velox.DownloadItem, Velox.DownloadItemRow> (direct_hash, direct_equal);

        nav_view = new Adw.NavigationView ();

        var url_page = new Adw.NavigationPage (build_url_page (), "Velox");
        url_page.tag = "url";

        Gtk.Button start_button;
        var options_view = options_builder.build (out start_button);
        start_button.clicked.connect (on_start_download);
        var options_page = new Adw.NavigationPage (options_view, "Options");
        options_page.tag = "options";

        nav_view.add (url_page);
        nav_view.add (options_page);

        toast_overlay = new Adw.ToastOverlay ();
        toast_overlay.child = nav_view;
        this.content = toast_overlay;

        // Drop target for URLs dragged from browser
        var drop_target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.COPY);
        drop_target.on_drop.connect ((target, value, x, y) => {
            if (value.holds (typeof (string))) {
                string s = (string) value;
                handle_pasted_text (s);
                return true;
            }
            return false;
        });
        ((Gtk.Widget) this).add_controller (drop_target);

        // Also handle file drops (text files with URLs)
        var file_drop = new Gtk.DropTarget (typeof (GLib.File), Gdk.DragAction.COPY);
        file_drop.on_drop.connect ((target, value, x, y) => {
            if (value.holds (typeof (GLib.File))) {
                var file = (GLib.File) value;
                try {
                    uint8[] contents;
                    string etag;
                    file.load_contents (null, out contents, out etag);
                    string text = (string) contents;
                    handle_pasted_text (text);
                } catch (Error e) {
                    send_toast ("Could not read dropped file: %s".printf (e.message));
                }
                return true;
            }
            return false;
        });
        ((Gtk.Widget) this).add_controller (file_drop);

        // Keyboard shortcuts: Ctrl+V to paste, Delete to remove focused, Ctrl+Enter to start
        var key_ctrl = new Gtk.EventControllerKey ();
        key_ctrl.key_pressed.connect ((keyval, keycode, state) => {
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            if (ctrl && keyval == Gdk.Key.v) {
                // Let real text fields handle paste normally; only treat Ctrl+V
                // as "paste URLs into the queue" when focus is not editable.
                var focus = get_focus ();
                if (focus is Gtk.Editable) return false;
                on_paste_from_clipboard ();
                return true;
            }
            if (ctrl && keyval == Gdk.Key.Return) {
                if (next_button.sensitive) {
                    next_button.clicked ();
                    return true;
                }
            }
            return false;
        });
        ((Gtk.Widget) this).add_controller (key_ctrl);

        // Close guard if downloads active
        this.close_request.connect (() => {
            bool has_active = false;
            for (uint i = 0; i < item_store.n_items; i++) {
                var it = (Velox.DownloadItem) item_store.get_item (i);
                if (it.state == Velox.DownloadState.DOWNLOADING || it.state == Velox.DownloadState.FETCHING) {
                    has_active = true;
                    break;
                }
            }
            if (!has_active) return false;
            var dialog = new Adw.AlertDialog (
                "Downloads in progress",
                "Some downloads are still running. Quit and cancel them?"
            );
            dialog.add_response ("cancel", "Keep Running");
            dialog.add_response ("quit", "Quit");
            dialog.set_response_appearance ("quit", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");
            dialog.choose (this, null, (obj, res) => {
                try {
                    string r = dialog.choose.end (res);
                    if (r == "quit") {
                        download_manager.cancel_all ();
                        this.destroy ();
                    }
                } catch (Error e) {}
            });
            return true;
        });

        ytdlp_service.info_fetched.connect (on_info_fetched);
        ytdlp_service.info_fetch_failed.connect (on_info_fetch_failed);

        download_manager.download_started.connect (on_download_started);
        download_manager.download_progress.connect (on_download_progress);
        download_manager.download_complete.connect (on_download_complete);
        download_manager.download_failed.connect (on_download_failed);
        download_manager.all_complete.connect (() => {
            send_toast ("All downloads complete");
            var notif = new GLib.Notification ("Velox");
            notif.set_body ("All downloads have finished");
            notif.set_icon (new GLib.ThemedIcon ("folder-videos-symbolic"));
            GLib.Application.get_default ().send_notification ("velox-complete", notif);
        });

        options_builder.container_dropdown.notify["selected"].connect (update_thumbnail_sensitivity);

        sync_ui_from_options ();

        // Dependency + config validation after window is realized
        GLib.Idle.add (() => {
            check_dependencies ();
            return false;
        });
    }

    private Adw.ToolbarView build_url_page () {
        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.reveal_top_bars = true;

        var header = new Adw.HeaderBar ();
        header.title_widget = new Gtk.Label ("Velox");

        var prefs_button = new Gtk.Button ();
        prefs_button.icon_name = "emblem-system-symbolic";
        prefs_button.tooltip_text = "Preferences";
        prefs_button.clicked.connect (on_preferences_clicked);
        header.pack_end (prefs_button);

        toolbar_view.add_top_bar (header);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        vbox.margin_start = 12;
        vbox.margin_end = 12;
        vbox.margin_top = 12;
        vbox.margin_bottom = 12;

        var entry_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

        url_entry = new Gtk.Entry ();
        url_entry.hexpand = true;
        url_entry.placeholder_text = "Paste URL(s) here — YouTube, Instagram, TikTok, SoundCloud…";
        url_entry.activates_default = true;
        entry_box.append (url_entry);

        paste_button = new Gtk.Button ();
        paste_button.icon_name = "edit-paste-symbolic";
        paste_button.tooltip_text = "Paste from clipboard (Ctrl+V)";
        paste_button.clicked.connect (on_paste_from_clipboard);
        entry_box.append (paste_button);

        var add_button = new Gtk.Button ();
        add_button.icon_name = "list-add-symbolic";
        add_button.tooltip_text = "Add URL";
        add_button.add_css_class ("suggested-action");
        add_button.clicked.connect (on_add_url);
        entry_box.append (add_button);

        ytdlp_banner = new Adw.Banner ("");
        ytdlp_banner.revealed = false;
        ytdlp_banner.add_css_class ("warning");
        vbox.append (ytdlp_banner);

        vbox.append (entry_box);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.vexpand = true;
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

        url_list = new Gtk.ListBox ();
        url_list.selection_mode = Gtk.SelectionMode.NONE;
        url_list.add_css_class ("boxed-list");
        scrolled.child = url_list;

        status_page = new Adw.StatusPage ();
        status_page.icon_name = "folder-videos-symbolic";
        status_page.title = "No videos yet";
        status_page.description = "Paste a link above or drag URLs here.\nYouTube, SoundCloud, Instagram, TikTok and 1800+ sites via yt-dlp.";
        status_page.vexpand = true;
        var status_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        status_box.halign = Gtk.Align.CENTER;
        var paste_status_btn = new Gtk.Button ();
        paste_status_btn.label = "Paste from Clipboard";
        paste_status_btn.add_css_class ("pill");
        paste_status_btn.add_css_class ("suggested-action");
        paste_status_btn.clicked.connect (on_paste_from_clipboard);
        status_box.append (paste_status_btn);
        var tip = new Gtk.Label ("Tip: Instagram/TikTok private reels need a cookies.txt in Preferences → Network");
        tip.add_css_class ("dim-label");
        tip.add_css_class ("caption");
        tip.wrap = true;
        tip.justify = Gtk.Justification.CENTER;
        status_box.append (tip);
        status_page.child = status_box;

        stack = new Gtk.Stack ();
        stack.add_named (scrolled, "list");
        stack.add_named (status_page, "empty");
        stack.visible_child_name = "empty";
        stack.vexpand = true;

        vbox.append (stack);

        var bottom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        bottom_box.valign = Gtk.Align.CENTER;

        queue_summary_label = new Gtk.Label ("");
        queue_summary_label.add_css_class ("dim-label");
        queue_summary_label.add_css_class ("caption");
        queue_summary_label.halign = Gtk.Align.START;
        queue_summary_label.hexpand = true;
        bottom_box.append (queue_summary_label);

        clear_completed_button = new Gtk.Button ();
        clear_completed_button.label = "Clear Finished";
        clear_completed_button.tooltip_text = "Remove finished and failed downloads from the list";
        clear_completed_button.visible = false;
        clear_completed_button.clicked.connect (on_clear_completed);
        bottom_box.append (clear_completed_button);

        next_button = new Gtk.Button ();
        next_button.label = "Next \u2192";
        next_button.add_css_class ("suggested-action");
        next_button.sensitive = false;
        next_button.clicked.connect (() => {
            // Do not re-apply saved defaults here: that would silently discard
            // any option changes the user made for this batch. Defaults are
            // applied at startup and after the Preferences dialog closes.
            nav_view.push_by_tag ("options");
        });
        bottom_box.append (next_button);

        vbox.append (bottom_box);
        toolbar_view.content = vbox;

        url_entry.activate.connect (on_add_url);

        return toolbar_view;
    }

    private void send_toast (string msg, uint timeout = 3) {
        var toast = new Adw.Toast (msg);
        toast.timeout = timeout;
        toast_overlay.add_toast (toast);
    }

    private bool is_valid_url (string url) {
        if (url.length < 8) return false;
        // Must contain dot and no spaces, and start with http(s) or www.
        if (url.contains (" ")) return false;
        string lower = url.down ();
        if (lower.has_prefix ("http://") || lower.has_prefix ("https://")) {
            return lower.contains (".");
        }
        if (lower.has_prefix ("www.")) return lower.contains (".");
        // Also allow youtu.be, youtube.com without scheme
        if (lower.contains ("youtu.be") || lower.contains ("youtube.com") || lower.contains ("soundcloud.com")) return true;
        return lower.contains (".") && (lower.contains ("/") || lower.contains ("."));
    }

    private void handle_pasted_text (string text) {
        if (text == null || text.strip ().length == 0) {
            send_toast ("Clipboard is empty");
            return;
        }
        // Normalize: handle commas, semicolons, whitespace, newlines as separators
        // Also extract URLs via regex if text contains surrounding prose (e.g. "check this https://... great")
        try {
            var url_regex = new GLib.Regex ("""https?://[^\s,\"]+|www\.[^\s,\"]+""", GLib.RegexCompileFlags.CASELESS);
            MatchInfo mi;
            bool has_match = url_regex.match (text, 0, out mi);
            if (has_match) {
                int added = 0;
                do {
                    string m = mi.fetch (0);
                    // Trim trailing punctuation often copied with URLs
                    while (m.length > 0 && (m.has_suffix (".") || m.has_suffix (",") || m.has_suffix (")") || m.has_suffix ("]") || m.has_suffix ("!") || m.has_suffix ("?"))) {
                        m = m.substring (0, m.length - 1);
                    }
                    if (m.length > 0) {
                        if (add_url_with_feedback (m)) added++;
                    }
                } while (mi.next ());
                if (added > 0) {
                    url_entry.text = "";
                    return;
                }
            }
        } catch (Error e) {}
        // Fallback: split on any whitespace / comma / semicolon
        string normalized = text.replace (",", "\n").replace (";", "\n");
        var parts = normalized.split_set (" \t\n\r");
        int count = 0;
        foreach (var part in parts) {
            var trimmed = part.strip ();
            if (trimmed.length == 0) continue;
            // Strip surrounding < > [ ] ( ) " '
            while (trimmed.length > 0 && (trimmed.has_prefix ("<") || trimmed.has_prefix ("[") || trimmed.has_prefix ("(") || trimmed.has_prefix ("\"") || trimmed.has_prefix ("'"))) {
                trimmed = trimmed.substring (1);
            }
            while (trimmed.length > 0 && (trimmed.has_suffix (">") || trimmed.has_suffix ("]") || trimmed.has_suffix (")") || trimmed.has_suffix ("\"") || trimmed.has_suffix ("'"))) {
                trimmed = trimmed.substring (0, trimmed.length - 1);
            }
            if (trimmed.length == 0) continue;
            if (add_url_with_feedback (trimmed)) count++;
        }
        if (count > 0) url_entry.text = "";
        else send_toast ("No valid URLs found");
    }

    private bool add_url_with_feedback (string url) {
        // Check duplicate before adding
        for (uint i = 0; i < item_store.n_items; i++) {
            var existing = (Velox.DownloadItem) item_store.get_item (i);
            if (existing.url == url) {
                send_toast ("Already added: %s".printf (url));
                return false;
            }
        }
        if (!is_valid_url (url)) {
            send_toast ("Skipped invalid URL: %s".printf (url));
            return false;
        }
        add_url (url);
        return true;
    }

    private void on_paste_from_clipboard () {
        var clipboard = this.get_clipboard ();
        clipboard.read_text_async.begin (null, (obj, res) => {
            try {
                string? text = clipboard.read_text_async.end (res);
                if (text != null) {
                    handle_pasted_text (text);
                } else {
                    // Fallback: use entry text if clipboard empty
                    if (url_entry.text.strip ().length > 0) {
                        handle_pasted_text (url_entry.text);
                    } else {
                        send_toast ("Clipboard is empty");
                    }
                }
            } catch (Error e) {
                send_toast ("Could not read clipboard");
            }
        });
    }

    private void on_add_url () {
        var text = url_entry.text.strip ();
        if (text.length == 0) {
            on_paste_from_clipboard ();
            return;
        }
        handle_pasted_text (text);
    }

    private void add_url (string url) {
        if (Velox.YtdlpService.looks_like_playlist (url)) {
            add_playlist (url);
            return;
        }

        for (uint i = 0; i < item_store.n_items; i++) {
            var existing = (Velox.DownloadItem) item_store.get_item (i);
            if (existing.url == url) {
                send_toast ("Already in queue");
                return;
            }
        }

        var item = new Velox.DownloadItem (url);
        item_store.append (item);

        var row = new Velox.DownloadItemRow (item);
        row.set_title_from_url ();
        row.subtitle = "Fetching info…";

        row.remove_clicked.connect (remove_item);
        row.retry_clicked.connect (retry_item);
        row.open_folder_clicked.connect (open_item_folder);
        url_list.append (row);
        item_rows.@set (item, row);

        update_empty_state ();
        ytdlp_service.fetch_info.begin (item);
    }

    private void add_playlist (string url) {
        var item = new Velox.DownloadItem (url);
        item.update_state (Velox.DownloadState.FETCHING);
        item.status_text = "Parsing playlist…";
        item_store.append (item);

        var row = new Velox.DownloadItemRow (item);
        row.set_title_from_url ();
        row.subtitle = "Parsing playlist…";
        row.set_state_downloading ();

        row.remove_clicked.connect (remove_item);
        url_list.append (row);
        update_empty_state ();

        expand_playlist.begin (item, url, row);
    }

    private void remove_item (Velox.DownloadItem item) {
        download_manager.cancel_item (item);
        uint idx;
        if (item_store.find (item, out idx)) {
            item_store.remove (idx);
        }
        var row = item_rows.@get (item);
        if (row != null) {
            url_list.remove (row);
            item_rows.remove (item);
        }
        update_empty_state ();
    }

    private void retry_item (Velox.DownloadItem item) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.set_state_downloading ();
            row.set_subtitle ("Retrying…");
            row.tooltip_text = "";
        }
        download_manager.retry_item (item);
    }

    private void open_item_folder (Velox.DownloadItem item) {
        string target = "";
        if (item.output_path.length > 0) {
            var fp = File.new_for_path (item.output_path);
            var parent = fp.get_parent ();
            if (parent != null) target = parent.get_path ();
        }
        if (target.length == 0) {
            if (download_options.is_music_mode) {
                target = download_options.music_directory.length > 0 ? download_options.music_directory : settings_manager.music_directory;
            } else {
                target = settings_manager.output_directory;
            }
            if (target.length == 0) target = Environment.get_home_dir () + "/Downloads";
        }
        string expanded = target.replace ("~", Environment.get_home_dir ());
        try {
            var f = File.new_for_path (expanded);
            string uri = f.get_uri ();
            GLib.AppInfo.launch_default_for_uri (uri, null);
        } catch (Error e) {
            send_toast ("Could not open folder: %s".printf (e.message));
        }
    }

    private void on_clear_completed () {
        // Collect to remove after iteration to avoid mutation during loop
        var to_remove = new GLib.List<Velox.DownloadItem> ();
        for (uint i = 0; i < item_store.n_items; i++) {
            var it = (Velox.DownloadItem) item_store.get_item (i);
            if (it.state == Velox.DownloadState.DONE ||
                it.state == Velox.DownloadState.ERROR ||
                it.state == Velox.DownloadState.CANCELLED) {
                to_remove.append (it);
            }
        }
        foreach (var it in to_remove) {
            uint idx;
            if (item_store.find (it, out idx)) item_store.remove (idx);
            var row = item_rows.@get (it);
            if (row != null) {
                url_list.remove (row);
                item_rows.remove (it);
            }
        }
        update_empty_state ();
        send_toast ("Cleared finished downloads");
    }

    private async void expand_playlist (Velox.DownloadItem placeholder, string url, Velox.DownloadItemRow row) {
        string[] entries = yield ytdlp_service.parse_playlist_urls (url);

        uint idx;
        if (item_store.find (placeholder, out idx)) {
            item_store.remove (idx);
        }
        url_list.remove (row);
        item_rows.remove (placeholder);
        update_empty_state ();

        if (entries.length == 0) {
            add_url (url);
            return;
        }

        // Guard large playlists
        const int CONFIRM_THRESHOLD = 20;
        if (entries.length > CONFIRM_THRESHOLD) {
            var dialog = new Adw.AlertDialog (
                "Large playlist",
                "This playlist contains %d videos. Add all of them?".printf (entries.length)
            );
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("first10", "Add first 10");
            dialog.add_response ("all", "Add all %d".printf (entries.length));
            dialog.set_response_appearance ("all", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("all");
            dialog.set_close_response ("cancel");
            try {
                string resp = yield dialog.choose (this, null);
                if (resp == "cancel") return;
                int limit = (resp == "first10") ? 10 : entries.length;
                for (int i = 0; i < limit; i++) {
                    add_url (entries[i]);
                }
                send_toast ("Added %d / %d videos".printf (limit, entries.length));
                return;
            } catch (Error e) {
                return;
            }
        }

        foreach (var entry in entries) {
            add_url (entry);
        }
        if (entries.length > 1) {
            send_toast ("Added %d videos from playlist".printf (entries.length));
        }
    }

    private void on_info_fetched (Velox.DownloadItem item) {
        item.status_text = "Ready";
        var row = item_rows.@get (item);
        if (row != null) {
            string sub = item.title;
            if (item.uploader.length > 0) {
                sub = "%s • %s".printf (item.uploader, item.get_duration_string ());
                if (item.get_duration_string ().length == 0) sub = item.uploader;
            } else if (item.get_duration_string ().length > 0) {
                sub = item.get_duration_string ();
            }
            row.set_subtitle (sub);
            row.update_progress (0);
        }
        update_empty_state ();
    }

    private void on_info_fetch_failed (Velox.DownloadItem item, string error) {
        item.status_text = "Failed to fetch info";
        warning ("Failed to fetch info for %s: %s", item.url, error);
        var row = item_rows.@get (item);
        if (row != null) {
            row.set_subtitle ("Failed to fetch info — click retry");
            row.set_state_error ();
            row.tooltip_text = error;
        }
        send_toast ("Could not fetch info for one item");
    }

    private void on_download_started (Velox.DownloadItem item) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.show_progress ();
            row.set_state_downloading ();
            row.set_subtitle ("Starting…");
        }
        update_empty_state ();
    }

    private void on_download_progress (Velox.DownloadItem item, string status, double progress) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.update_progress (progress);
            // Use parser status text for subtitle if download phase
            if (status.length > 0 && status != "Queued" && status != "Done") {
                row.set_subtitle (status);
            }
        }
        update_queue_summary ();
    }

    private void on_download_complete (Velox.DownloadItem item) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.hide_progress ();
            row.set_state_done ();
            row.set_subtitle ("Completed • click folder to open");
        }
        item.status_text = "Done";
        update_empty_state ();
        update_queue_summary ();
    }

    private void on_download_failed (Velox.DownloadItem item, string error) {
        printerr ("Download failed: %s\nError: %s\n", item.url, error);
        string brief = error;
        string[] lines = error.split ("\n");
        for (int i = lines.length - 1; i >= 0; i--) {
            var l = lines[i].strip ();
            if (l.length > 0 && !l.has_prefix ("Usage:")) {
                brief = l;
                break;
            }
        }
        if (brief.length > 100) brief = brief.substring (0, 97) + "...";
        if (item.retry_count >= item.max_retries && item.retry_count > 0) {
            brief = "Failed after %d retries: %s".printf (item.max_retries, brief);
        }
        var row = item_rows.@get (item);
        if (row != null) {
            row.hide_progress ();
            row.set_state_error ();
            row.set_subtitle (brief);
            row.tooltip_text = error;
            if (item.retry_count < item.max_retries) {
                row.tooltip_text += "\n\nUse the retry button to try again.";
            }
        }
        item.status_text = "Error";
        item.error_message = error;
        send_toast (brief, 4);
        update_empty_state ();
    }

    private void check_dependencies () {
        // yt-dlp existence + staleness check (Instagram/TikTok break often)
        if (GLib.Environment.find_program_in_path ("yt-dlp") == null) {
            ytdlp_banner.title = "yt-dlp not found — install it for YouTube, Instagram, TikTok and 1800+ sites";
            ytdlp_banner.revealed = true;
            var dialog = new Adw.AlertDialog (
                "yt-dlp not found",
                "Velox requires yt-dlp to be installed and on your PATH.\n\nInstall it via your package manager (e.g. pacman -S yt-dlp / pipx install yt-dlp) and restart Velox."
            );
            dialog.add_response ("ok", "OK");
            dialog.choose (this, null);
            warning ("yt-dlp not found on PATH — downloads will fail");
        } else {
            // Async version staleness: warn if >30 days old (extractors rot fast for IG/TikTok)
            check_ytdlp_version.begin ();
        }
        // Output directory writable check
        string dir = settings_manager.output_directory;
        if (dir.length > 0) {
            string expanded = dir.replace ("~", Environment.get_home_dir ());
            var f = File.new_for_path (expanded);
            if (!f.query_exists ()) {
                try { f.make_directory_with_parents (); } catch (Error e) {
                    var d = new Adw.AlertDialog (
                        "Output folder not writable",
                        "Cannot create %s:\n%s".printf (expanded, e.message)
                    );
                    d.add_response ("ok", "OK");
                    d.choose (this, null);
                }
            }
        }
        // Background helper for banner dismissal on click
        ytdlp_banner.button_label = null;

        // Archive path validation
        if (settings_manager.use_archive) {
            string ap = settings_manager.archive_path;
            if (ap.length > 0) {
                string exp = ap.replace ("~", Environment.get_home_dir ());
                var pf = File.new_for_path (Path.get_dirname (exp));
                if (!pf.query_exists ()) {
                    warning ("Archive directory does not exist: %s", Path.get_dirname (exp));
                }
            }
        }
    }

    private async void check_ytdlp_version () {
        try {
            string[] argv = { "yt-dlp", "--version" };
            var proc = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string stdout; string stderr;
            yield proc.communicate_utf8_async (null, null, out stdout, out stderr);
            if (!proc.get_successful ()) return;
            string ver = stdout.strip (); // e.g. 2024.03.10 or 2025.08.31.123456
            var parts = ver.split (".");
            if (parts.length < 3) return;
            int y = int.parse (parts[0]); int m = int.parse (parts[1]); int d = int.parse (parts[2].split ("-")[0].split ("_")[0]);
            var ver_date = new DateTime.local (y, m, d, 0, 0, 0);
            var now = new DateTime.now_local ();
            int diff = (int) (now.difference (ver_date) / TimeSpan.DAY);
            if (diff > 30) {
                ytdlp_banner.title = "yt-dlp %s is %d days old — run `yt-dlp -U` for Instagram/TikTok fixes".printf (ver, diff);
                ytdlp_banner.button_label = "Dismiss";
                ytdlp_banner.revealed = true;
                // Dismiss on button
                ulong handler = 0;
                handler = ytdlp_banner.button_clicked.connect (() => {
                    ytdlp_banner.revealed = false;
                    if (handler != 0) ytdlp_banner.disconnect (handler);
                });
            }
        } catch (Error e) {
            debug ("yt-dlp version check failed: %s", e.message);
        }
    }

    private void update_empty_state () {
        if (item_store.n_items > 0) {
            stack.visible_child_name = "list";
            next_button.sensitive = true;
            next_button.label = "Next (%u) \u2192".printf (item_store.n_items);
        } else {
            stack.visible_child_name = "empty";
            next_button.sensitive = false;
            next_button.label = "Next \u2192";
        }
        update_queue_summary ();
    }

    private void update_queue_summary () {
        uint total = item_store.n_items;
        if (total == 0) {
            queue_summary_label.label = "";
            clear_completed_button.visible = false;
            return;
        }
        uint queued = 0, fetching = 0, downloading = 0, done = 0, err = 0;
        double total_progress = 0;
        for (uint i = 0; i < total; i++) {
            var it = (Velox.DownloadItem) item_store.get_item (i);
            switch (it.state) {
                case Velox.DownloadState.QUEUED: queued++; break;
                case Velox.DownloadState.FETCHING: fetching++; break;
                case Velox.DownloadState.DOWNLOADING:
                case Velox.DownloadState.MERGING:
                case Velox.DownloadState.POST_PROCESSING: downloading++; total_progress += it.progress; break;
                case Velox.DownloadState.DONE: done++; total_progress += 1.0; break;
                case Velox.DownloadState.ERROR: err++; break;
                default: break;
            }
        }
        var parts = new GLib.StringBuilder ();
        if (downloading > 0) parts.append ("%u downloading".printf (downloading));
        if (fetching > 0) {
            if (parts.len > 0) parts.append (" • ");
            parts.append ("%u fetching".printf (fetching));
        }
        if (queued > 0) {
            if (parts.len > 0) parts.append (" • ");
            parts.append ("%u queued".printf (queued));
        }
        if (done > 0) {
            if (parts.len > 0) parts.append (" • ");
            parts.append ("%u done".printf (done));
        }
        if (err > 0) {
            if (parts.len > 0) parts.append (" • ");
            parts.append ("%u failed".printf (err));
        }
        if (parts.len == 0) parts.append ("%u total".printf (total));
        queue_summary_label.label = parts.str;
        clear_completed_button.visible = (done > 0 || err > 0);
    }

    private void update_thumbnail_sensitivity () {
        // Music mode always embeds thumbnail, so don't disable
        if (options_builder.type_dropdown.get_selected () == 2) {
            options_builder.thumb_check.sensitive = true;
            return;
        }
        var container_obj = (Gtk.StringObject) options_builder.container_dropdown.get_selected_item ();
        bool is_webm = container_obj != null && container_obj.get_string () == "WebM";
        options_builder.thumb_check.sensitive = !is_webm;
        if (is_webm) {
            options_builder.thumb_check.active = false;
        }
    }

    private void sync_ui_from_options () {
        options_builder.sync_from_options (download_options);
    }

    private void on_start_download () {
        download_options.output_directory = settings_manager.output_directory;
        download_options.output_template = settings_manager.output_template;

        options_builder.sync_to_options (download_options);

        if (item_store.n_items == 0) return;

        uint startable = 0;
        for (uint i = 0; i < item_store.n_items; i++) {
            var it = (Velox.DownloadItem) item_store.get_item (i);
            if (it.state != Velox.DownloadState.DONE &&
                it.state != Velox.DownloadState.DOWNLOADING) {
                startable++;
            }
        }
        if (startable == 0) {
            send_toast ("Nothing to download");
            return;
        }

        download_manager.max_concurrent = settings_manager.max_concurrent;
        download_manager.start (item_store, download_options);
        nav_view.pop ();
        send_toast ("Started %u download%s".printf (startable, startable == 1 ? "" : "s"));
    }

    private void on_preferences_clicked () {
        var dialog = new Velox.PreferencesDialog (settings_manager);
        // Re-apply saved defaults when the user closes Preferences so changes
        // take effect without restarting, while batch tweaks survive navigation.
        dialog.closed.connect (() => {
            settings_manager.apply_defaults (download_options);
            sync_ui_from_options ();
        });
        dialog.present (this);
    }
}
