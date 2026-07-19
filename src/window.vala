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

    // Maps item URL -> row widgets for progress updates
    private GLib.HashTable<string, Adw.ActionRow> item_rows;
    private GLib.HashTable<string, Gtk.Label> item_status_labels;
    private GLib.HashTable<string, Gtk.ProgressBar> item_progress_bars;
    private GLib.HashTable<string, Gtk.Button> item_action_buttons;

    // Options page widgets
    private Gtk.DropDown type_dropdown;
    private Gtk.DropDown codec_dropdown;
    private Gtk.DropDown quality_dropdown;
    private Gtk.DropDown container_dropdown;
    private Gtk.DropDown audio_codec_dropdown;
    private Gtk.CheckButton meta_check;
    private Gtk.CheckButton thumb_check;
    private Gtk.CheckButton chapters_check;
    private Gtk.CheckButton subs_check;
    private Gtk.CheckButton auto_subs_check;
    private Gtk.CheckButton save_subs_srt_check;
    private Gtk.Entry langs_entry;
    private Gtk.CheckButton sb_enable;
    private Gtk.CheckButton sb_remove_radio;
    private Gtk.CheckButton sb_mark_radio;
    private Gtk.FlowBox sb_cats_box;
    private Gtk.Entry adv_entry;

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

        // Apply saved defaults to download options
        settings_manager.apply_defaults (download_options);

        item_rows = new GLib.HashTable<string, Adw.ActionRow> (str_hash, str_equal);
        item_status_labels = new GLib.HashTable<string, Gtk.Label> (str_hash, str_equal);
        item_progress_bars = new GLib.HashTable<string, Gtk.ProgressBar> (str_hash, str_equal);
        item_action_buttons = new GLib.HashTable<string, Gtk.Button> (str_hash, str_equal);

        nav_view = new Adw.NavigationView ();

        var url_page = new Adw.NavigationPage (build_url_page (), "Velox");
        url_page.tag = "url";

        var options_page = new Adw.NavigationPage (build_options_page (), "Options");
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

        // Disable thumbnail when WebM is selected (WebM doesn't support attachments)
        container_dropdown.notify["selected"].connect (update_thumbnail_sensitivity);

        // Sync options page UI with saved defaults
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

        // URL entry row
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

        // URL list
        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.vexpand = true;
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

        url_list = new Gtk.ListBox ();
        url_list.selection_mode = Gtk.SelectionMode.NONE;
        url_list.add_css_class ("boxed-list");
        scrolled.child = url_list;

        // Empty state
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

        // Bottom bar
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
        // Playlist URLs are expanded into their individual videos.
        if (Velox.YtdlpService.looks_like_playlist (url)) {
            add_playlist (url);
            return;
        }

        var item = new Velox.DownloadItem (url);
        item_store.append (item);

        // Escape URL for Pango markup
        string safe_title = Markup.escape_text (url);

        // Build the row
        var row = new Adw.ActionRow ();
        row.title = safe_title;
        row.subtitle = "Fetching info...";
        row.activatable = false;

        // Status label (right side, before button)
        var status_label = new Gtk.Label ("");
        status_label.add_css_class ("dim-label");
        status_label.add_css_class ("caption");
        status_label.width_chars = 14;
        status_label.xalign = 1;
        row.add_suffix (status_label);

        // Progress bar (right side, hidden until download starts)
        var progress_bar = new Gtk.ProgressBar ();
        progress_bar.width_request = 120;
        progress_bar.show_text = false;
        progress_bar.visible = false;
        progress_bar.valign = Gtk.Align.CENTER;
        row.add_suffix (progress_bar);

        // Action button (rightmost)
        var action_button = new Gtk.Button ();
        action_button.icon_name = "window-close-symbolic";
        action_button.tooltip_text = "Remove";
        action_button.add_css_class ("flat");
        action_button.add_css_class ("circular");
        action_button.clicked.connect (() => {
            // Always tell the manager: this pulls the item out of the queue
            // if it hasn't started yet, and cancels/kills the process if it
            // has. Otherwise a removed row would keep downloading invisibly
            // and still consume a concurrency slot.
            download_manager.cancel_item (item);
            uint idx;
            if (item_store.find (item, out idx)) {
                item_store.remove (idx);
            }
            url_list.remove (row);
            item_rows.remove (url);
            item_status_labels.remove (url);
            item_progress_bars.remove (url);
            item_action_buttons.remove (url);
            update_empty_state ();
        });
        row.add_suffix (action_button);

        url_list.append (row);
        update_empty_state ();

        // Store references keyed by URL
        item_rows.@set (url, row);
        item_status_labels.@set (url, status_label);
        item_progress_bars.@set (url, progress_bar);
        item_action_buttons.@set (url, action_button);

        // Watch for property changes
        item.notify["title"].connect (() => {
            if (item.title.length > 0) {
                row.title = Markup.escape_text (item.title);
            }
        });
        item.notify["status-text"].connect (() => {
            status_label.label = item.status_text;
        });

        // Fetch metadata
        ytdlp_service.fetch_info.begin (item);
    }

    private void add_playlist (string url) {
        // Placeholder row shown while we expand the playlist.
        var item = new Velox.DownloadItem (url);
        item.update_state (Velox.DownloadState.FETCHING);
        item.status_text = "Parsing playlist...";
        item_store.append (item);

        var row = new Adw.ActionRow ();
        row.title = Markup.escape_text (url);
        row.subtitle = "Parsing playlist...";
        row.activatable = false;

        var status_label = new Gtk.Label ("Parsing…");
        status_label.add_css_class ("dim-label");
        status_label.add_css_class ("caption");
        row.add_suffix (status_label);

        var action_button = new Gtk.Button ();
        action_button.icon_name = "window-close-symbolic";
        action_button.tooltip_text = "Remove";
        action_button.add_css_class ("flat");
        action_button.add_css_class ("circular");
        action_button.clicked.connect (() => {
            download_manager.cancel_item (item);
            uint idx;
            if (item_store.find (item, out idx)) {
                item_store.remove (idx);
            }
            url_list.remove (row);
            update_empty_state ();
        });
        row.add_suffix (action_button);

        url_list.append (row);
        update_empty_state ();

        expand_playlist.begin (item, url, row);
    }

    private async void expand_playlist (Velox.DownloadItem placeholder, string url, Adw.ActionRow row) {
        string[] entries = yield ytdlp_service.parse_playlist_urls (url);

        // Remove the placeholder regardless of outcome.
        uint idx;
        if (item_store.find (placeholder, out idx)) {
            item_store.remove (idx);
        }
        url_list.remove (row);
        update_empty_state ();

        if (entries.length == 0) {
            // Not actually a playlist (or it failed) — treat as a single video.
            add_url (url);
            return;
        }

        foreach (var entry in entries) {
            add_url (entry);
        }
    }

    private void on_info_fetched (Velox.DownloadItem item) {
        item.status_text = "Ready";
        var row = item_rows.@get (item.url);
        if (row != null) {
            string sub = item.title;
            if (item.uploader.length > 0) {
                sub = item.uploader;
            }
            row.subtitle = sub;
        }
    }

    private void on_info_fetch_failed (Velox.DownloadItem item, string error) {
        item.status_text = "Failed to fetch info";
        warning ("Failed to fetch info for %s: %s", item.url, error);
        var row = item_rows.@get (item.url);
        if (row != null) {
            row.subtitle = "Failed to fetch info";
        }
    }

    private void on_download_started (Velox.DownloadItem item) {
        var progress_bar = item_progress_bars.@get (item.url);
        if (progress_bar != null) {
            progress_bar.visible = true;
            progress_bar.fraction = 0;
        }

        var action_button = item_action_buttons.@get (item.url);
        if (action_button != null) {
            action_button.icon_name = "process-stop-symbolic";
            action_button.tooltip_text = "Cancel";
        }

        var row = item_rows.@get (item.url);
        if (row != null) {
            row.subtitle = "Downloading...";
        }
    }

    private void on_download_progress (Velox.DownloadItem item, string status, double progress) {
        var progress_bar = item_progress_bars.@get (item.url);
        if (progress_bar != null) {
            progress_bar.fraction = progress;
        }
    }

    private void on_download_complete (Velox.DownloadItem item) {
        var progress_bar = item_progress_bars.@get (item.url);
        if (progress_bar != null) {
            progress_bar.visible = false;
        }

        var action_button = item_action_buttons.@get (item.url);
        if (action_button != null) {
            action_button.icon_name = "object-select-symbolic";
            action_button.tooltip_text = "Dismiss";
            action_button.remove_css_class ("flat");
            action_button.add_css_class ("success");
        }

        item.status_text = "Done";
        var row = item_rows.@get (item.url);
        if (row != null) {
            row.subtitle = "Completed";
        }
    }

    private void on_download_failed (Velox.DownloadItem item, string error) {
        printerr ("Download failed: %s\nError: %s\n", item.url, error);

        var progress_bar = item_progress_bars.@get (item.url);
        if (progress_bar != null) {
            progress_bar.visible = false;
        }

        var row = item_rows.@get (item.url);
        if (row != null) {
            // Show the last meaningful line of the error as subtitle
            string brief = error;
            string[] lines = error.split ("\n");
            for (int i = lines.length - 1; i >= 0; i--) {
                var l = lines[i].strip ();
                if (l.length > 0 && !l.has_prefix ("Usage:")) {
                    brief = l;
                    break;
                }
            }
            row.subtitle = brief;
        }

        var action_button = item_action_buttons.@get (item.url);
        if (action_button != null) {
            action_button.icon_name = "dialog-error-symbolic";
            action_button.tooltip_text = "Dismiss";
            action_button.remove_css_class ("flat");
            action_button.add_css_class ("error");
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
        var container_obj = (Gtk.StringObject) container_dropdown.get_selected_item ();
        bool is_webm = container_obj != null && container_obj.get_string () == "WebM";
        thumb_check.sensitive = !is_webm;
        if (is_webm) {
            thumb_check.active = false;
        }
    }

    private Adw.ToolbarView build_options_page () {
        var toolbar_view = new Adw.ToolbarView ();

        var header = new Adw.HeaderBar ();
        header.show_title = false;

        var start_button = new Gtk.Button ();
        start_button.label = "Start";
        start_button.add_css_class ("suggested-action");
        start_button.clicked.connect (on_start_download);
        header.pack_end (start_button);

        toolbar_view.add_top_bar (header);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        content_box.margin_start = 12;
        content_box.margin_end = 12;
        content_box.margin_top = 12;
        content_box.margin_bottom = 12;

        // Type row
        var type_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        type_row.valign = Gtk.Align.CENTER;

        var type_label = new Gtk.Label ("Type:");
        type_label.width_chars = 6;
        type_label.xalign = 0;
        type_row.append (type_label);

        type_dropdown = new Gtk.DropDown.from_strings ({ "Video", "Audio Only" });
        type_dropdown.valign = Gtk.Align.CENTER;
        type_row.append (type_dropdown);

        content_box.append (type_row);

        // Format grid
        var format_grid = new Gtk.Grid ();
        format_grid.column_spacing = 12;
        format_grid.row_spacing = 6;

        var codec_label = new Gtk.Label ("Codec:");
        codec_label.xalign = 1;
        format_grid.attach (codec_label, 0, 0);

        codec_dropdown = new Gtk.DropDown.from_strings ({
            "H.264", "H.265", "VP9", "AV1", "Any"
        });
        format_grid.attach (codec_dropdown, 1, 0);

        var quality_label = new Gtk.Label ("Quality:");
        quality_label.xalign = 1;
        format_grid.attach (quality_label, 2, 0);

        quality_dropdown = new Gtk.DropDown.from_strings ({
            "Best", "2160p", "1080p", "720p", "480p", "360p", "Worst"
        });
        format_grid.attach (quality_dropdown, 3, 0);

        var container_label = new Gtk.Label ("Container:");
        container_label.xalign = 1;
        format_grid.attach (container_label, 0, 1);

        container_dropdown = new Gtk.DropDown.from_strings ({
            "MP4", "MKV", "WebM"
        });
        format_grid.attach (container_dropdown, 1, 1);

        var audio_codec_label = new Gtk.Label ("Audio:");
        audio_codec_label.xalign = 1;
        format_grid.attach (audio_codec_label, 2, 1);

        audio_codec_dropdown = new Gtk.DropDown.from_strings ({
            "AAC", "Opus", "MP3", "FLAC", "Any"
        });
        format_grid.attach (audio_codec_dropdown, 3, 1);

        content_box.append (format_grid);
        content_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

        // Metadata and Subtitles
        var metadata_expander = new Adw.ExpanderRow ();
        metadata_expander.title = "Metadata and Subtitles";
        metadata_expander.subtitle = "Embed metadata, thumbnails, and subtitles";

        var meta_grid = new Gtk.Grid ();
        meta_grid.column_spacing = 12;
        meta_grid.row_spacing = 6;
        meta_grid.margin_top = 6;
        meta_grid.margin_bottom = 6;

        meta_check = new Gtk.CheckButton.with_label ("Metadata");
        meta_grid.attach (meta_check, 0, 0);

        thumb_check = new Gtk.CheckButton.with_label ("Thumbnail");
        meta_grid.attach (thumb_check, 1, 0);

        chapters_check = new Gtk.CheckButton.with_label ("Chapters");
        meta_grid.attach (chapters_check, 2, 0);

        subs_check = new Gtk.CheckButton.with_label ("Subtitles");
        meta_grid.attach (subs_check, 0, 1);

        auto_subs_check = new Gtk.CheckButton.with_label ("Auto-subs");
        meta_grid.attach (auto_subs_check, 1, 1);

        save_subs_srt_check = new Gtk.CheckButton.with_label (".srt only");
        save_subs_srt_check.tooltip_text = "Save subtitles as .srt files without embedding";
        meta_grid.attach (save_subs_srt_check, 2, 1);

        langs_entry = new Gtk.Entry ();
        langs_entry.placeholder_text = "en";
        langs_entry.width_chars = 8;
        langs_entry.valign = Gtk.Align.CENTER;
        var langs_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        langs_box.append (new Gtk.Label ("Langs:"));
        langs_box.append (langs_entry);
        meta_grid.attach (langs_box, 0, 2, 2, 1);

        metadata_expander.add_row (meta_grid);
        content_box.append (metadata_expander);

        // SponsorBlock
        var sb_expander = new Adw.ExpanderRow ();
        sb_expander.title = "SponsorBlock";
        sb_expander.subtitle = "Remove or mark sponsored segments";

        var sb_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        sb_inner.margin_top = 6;
        sb_inner.margin_bottom = 6;

        sb_enable = new Gtk.CheckButton.with_label ("Enable SponsorBlock");
        sb_inner.append (sb_enable);

        var sb_action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        sb_action_box.margin_start = 24;
        sb_remove_radio = new Gtk.CheckButton.with_label ("Remove");
        sb_remove_radio.active = true;
        sb_mark_radio = new Gtk.CheckButton.with_label ("Mark as chapters");
        sb_remove_radio.group = sb_mark_radio;
        sb_action_box.append (sb_remove_radio);
        sb_action_box.append (sb_mark_radio);
        sb_inner.append (sb_action_box);

        sb_cats_box = new Gtk.FlowBox ();
        sb_cats_box.orientation = Gtk.Orientation.HORIZONTAL;
        sb_cats_box.column_spacing = 8;
        sb_cats_box.row_spacing = 4;
        sb_cats_box.margin_start = 24;
        sb_cats_box.selection_mode = Gtk.SelectionMode.NONE;
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Sponsor"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Intro"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Outro"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Self-promo"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Preview"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Filler"));
        sb_inner.append (sb_cats_box);

        sb_expander.add_row (sb_inner);
        content_box.append (sb_expander);

        // Advanced
        var adv_expander = new Adw.ExpanderRow ();
        adv_expander.title = "Advanced";
        adv_expander.subtitle = "Custom yt-dlp arguments";

        adv_entry = new Gtk.Entry ();
        adv_entry.placeholder_text = "e.g. --split-chapters --force-keyframes-at-cuts";
        adv_entry.hexpand = true;
        adv_entry.margin_top = 6;
        adv_entry.margin_bottom = 6;
        adv_entry.margin_start = 12;
        adv_entry.margin_end = 12;
        adv_expander.add_row (adv_entry);

        content_box.append (adv_expander);

        scrolled.child = content_box;
        toolbar_view.content = scrolled;

        return toolbar_view;
    }

    private void sync_ui_from_options () {
        type_dropdown.set_selected (download_options.is_audio_only ? 1 : 0);

        codec_dropdown.set_selected (dropdown_index_of (codec_dropdown, download_options.video_codec));
        quality_dropdown.set_selected (dropdown_index_of (quality_dropdown, download_options.video_quality));
        container_dropdown.set_selected (dropdown_index_of (container_dropdown, download_options.container));
        audio_codec_dropdown.set_selected (dropdown_index_of (audio_codec_dropdown, download_options.audio_codec));

        meta_check.active = download_options.embed_metadata;
        thumb_check.active = download_options.embed_thumbnail;
        chapters_check.active = download_options.embed_chapters;

        subs_check.active = download_options.download_subtitles;
        auto_subs_check.active = download_options.auto_subtitles;
        save_subs_srt_check.active = download_options.save_subtitles_as_srt;
        langs_entry.text = download_options.subtitle_languages;

        sb_enable.active = download_options.sponsorblock_enabled;
        sb_remove_radio.active = download_options.sponsorblock_remove;
        sb_remove_radio.group = sb_mark_radio;

        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    check.active = contains_string (download_options.sponsorblock_categories, check.label.down ());
                }
            }
            child = child.get_next_sibling ();
        }

        adv_entry.text = download_options.extra_args;
    }

    private int dropdown_index_of (Gtk.DropDown dropdown, string value) {
        var model = dropdown.get_model () as Gtk.StringList;
        if (model == null) return 0;
        for (uint i = 0; i < model.get_n_items (); i++) {
            if (model.get_string (i) == value) return (int) i;
        }
        return 0;
    }

    private bool contains_string (string[] arr, string val) {
        foreach (var s in arr) {
            if (s == val) return true;
        }
        return false;
    }

    private void sync_options_from_ui () {
        download_options.is_audio_only = (type_dropdown.get_selected () == 1);

        var codec_obj = (Gtk.StringObject) codec_dropdown.get_selected_item ();
        download_options.video_codec = codec_obj.get_string ();

        var quality_obj = (Gtk.StringObject) quality_dropdown.get_selected_item ();
        download_options.video_quality = quality_obj.get_string ();

        var container_obj = (Gtk.StringObject) container_dropdown.get_selected_item ();
        download_options.container = container_obj.get_string ();

        var audio_obj = (Gtk.StringObject) audio_codec_dropdown.get_selected_item ();
        download_options.audio_codec = audio_obj.get_string ();

        download_options.embed_metadata = meta_check.active;
        download_options.embed_thumbnail = thumb_check.active;
        download_options.embed_chapters = chapters_check.active;

        download_options.download_subtitles = subs_check.active;
        download_options.embed_subtitles = subs_check.active && !save_subs_srt_check.active;
        download_options.save_subtitles_as_srt = save_subs_srt_check.active;
        download_options.auto_subtitles = auto_subs_check.active;
        download_options.subtitle_languages = langs_entry.text.length > 0
            ? langs_entry.text : "en";

        download_options.sponsorblock_enabled = sb_enable.active;
        download_options.sponsorblock_remove = sb_remove_radio.active;

        var cats = new Array<string> ();
        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    if (check.active) {
                        cats.append_val (check.label.down ());
                    }
                }
            }
            child = child.get_next_sibling ();
        }
        download_options.sponsorblock_categories = cats.data;

        download_options.extra_args = adv_entry.text;
    }

    private void on_start_download () {
        // Re-apply settings defaults (user may have changed prefs)
        download_options.output_directory = settings_manager.output_directory;
        download_options.output_template = settings_manager.output_template;

        sync_options_from_ui ();

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
