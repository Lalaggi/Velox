public class Velox.Window : Adw.ApplicationWindow {
    private Adw.NavigationView nav_view;
    private Gtk.ListBox url_list;
    private Gtk.Entry url_entry;
    private Gtk.Button next_button;
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
            default_width: 700,
            default_height: 550
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

        this.content = nav_view;

        ytdlp_service.info_fetched.connect (on_info_fetched);
        ytdlp_service.info_fetch_failed.connect (on_info_fetch_failed);

        download_manager.download_started.connect (on_download_started);
        download_manager.download_progress.connect (on_download_progress);
        download_manager.download_complete.connect (on_download_complete);
        download_manager.download_failed.connect (on_download_failed);

        options_builder.container_dropdown.notify["selected"].connect (update_thumbnail_sensitivity);

        sync_ui_from_options ();
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
        url_entry.placeholder_text = "Paste URL(s) here...";
        url_entry.activates_default = true;
        entry_box.append (url_entry);

        var add_button = new Gtk.Button ();
        add_button.label = "+";
        add_button.tooltip_text = "Add URL";
        add_button.add_css_class ("suggested-action");
        add_button.clicked.connect (on_add_url);
        entry_box.append (add_button);

        vbox.append (entry_box);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.vexpand = true;
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

        url_list = new Gtk.ListBox ();
        url_list.selection_mode = Gtk.SelectionMode.NONE;
        url_list.add_css_class ("boxed-list");
        scrolled.child = url_list;

        var empty_state = new Gtk.Label ("No videos added");
        empty_state.halign = Gtk.Align.CENTER;
        empty_state.valign = Gtk.Align.CENTER;
        empty_state.vexpand = true;
        empty_state.add_css_class ("dim-label");

        stack = new Gtk.Stack ();
        stack.add_named (scrolled, "list");
        stack.add_named (empty_state, "empty");
        stack.visible_child_name = "empty";
        stack.vexpand = true;

        vbox.append (stack);

        var bottom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bottom_box.halign = Gtk.Align.END;

        next_button = new Gtk.Button ();
        next_button.label = "Next \u2192";
        next_button.add_css_class ("suggested-action");
        next_button.sensitive = false;
        next_button.clicked.connect (() => {
            settings_manager.apply_defaults (download_options);
            sync_ui_from_options ();
            nav_view.push_by_tag ("options");
        });
        bottom_box.append (next_button);

        vbox.append (bottom_box);
        toolbar_view.content = vbox;

        url_entry.activate.connect (on_add_url);

        return toolbar_view;
    }

    private void on_add_url () {
        var text = url_entry.text.strip ();
        if (text.length == 0) return;

        var urls = text.split ("\n");
        foreach (var url in urls) {
            var trimmed = url.strip ();
            if (trimmed.length == 0) continue;
            add_url (trimmed);
        }

        url_entry.text = "";
    }

    private void add_url (string url) {
        if (Velox.YtdlpService.looks_like_playlist (url)) {
            add_playlist (url);
            return;
        }

        for (uint i = 0; i < item_store.n_items; i++) {
            var existing = (Velox.DownloadItem) item_store.get_item (i);
            if (existing.url == url && existing.title.length > 0) {
                return;
            }
        }

        var item = new Velox.DownloadItem (url);
        item_store.append (item);

        var row = new Velox.DownloadItemRow (item);
        row.set_title_from_url ();
        row.subtitle = "Fetching info...";

        row.remove_clicked.connect (remove_item);
        url_list.append (row);
        item_rows.@set (item, row);

        update_empty_state ();
        ytdlp_service.fetch_info.begin (item);
    }

    private void add_playlist (string url) {
        var item = new Velox.DownloadItem (url);
        item.update_state (Velox.DownloadState.FETCHING);
        item.status_text = "Parsing playlist...";
        item_store.append (item);

        var row = new Velox.DownloadItemRow (item);
        row.set_title_from_url ();
        row.subtitle = "Parsing playlist...";

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

        foreach (var entry in entries) {
            add_url (entry);
        }
    }

    private void on_info_fetched (Velox.DownloadItem item) {
        item.status_text = "Ready";
        var row = item_rows.@get (item);
        if (row != null) {
            string sub = item.title;
            if (item.uploader.length > 0) {
                sub = item.uploader;
            }
            row.set_subtitle (sub);
        }
    }

    private void on_info_fetch_failed (Velox.DownloadItem item, string error) {
        item.status_text = "Failed to fetch info";
        warning ("Failed to fetch info for %s: %s", item.url, error);
        var row = item_rows.@get (item);
        if (row != null) {
            row.set_subtitle ("Failed to fetch info");
        }
    }

    private void on_download_started (Velox.DownloadItem item) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.show_progress ();
            row.set_state_downloading ();
            row.set_subtitle ("Downloading...");
        }
    }

    private void on_download_progress (Velox.DownloadItem item, string status, double progress) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.update_progress (progress);
        }
    }

    private void on_download_complete (Velox.DownloadItem item) {
        var row = item_rows.@get (item);
        if (row != null) {
            row.hide_progress ();
            row.set_state_done ();
            row.set_subtitle ("Completed");
        }
        item.status_text = "Done";
    }

    private void on_download_failed (Velox.DownloadItem item, string error) {
        printerr ("Download failed: %s\nError: %s\n", item.url, error);
        var row = item_rows.@get (item);
        if (row != null) {
            row.hide_progress ();
            row.set_state_error ();

            string brief = error;
            string[] lines = error.split ("\n");
            for (int i = lines.length - 1; i >= 0; i--) {
                var l = lines[i].strip ();
                if (l.length > 0 && !l.has_prefix ("Usage:")) {
                    brief = l;
                    break;
                }
            }
            row.set_subtitle (brief);
        }
        item.status_text = "Error";
    }

    private void update_empty_state () {
        if (item_store.n_items > 0) {
            stack.visible_child_name = "list";
            next_button.sensitive = true;
        } else {
            stack.visible_child_name = "empty";
            next_button.sensitive = false;
        }
    }

    private void update_thumbnail_sensitivity () {
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

        download_manager.max_concurrent = settings_manager.max_concurrent;
        download_manager.start (item_store, download_options);
        nav_view.pop ();
    }

    private void on_preferences_clicked () {
        var dialog = new Velox.PreferencesDialog (settings_manager);
        dialog.present (this);
    }
}
