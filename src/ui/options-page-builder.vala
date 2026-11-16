public class Velox.OptionsPageBuilder : GLib.Object {
    public Gtk.DropDown type_dropdown { get; private set; }
    public Gtk.DropDown codec_dropdown { get; private set; }
    public Gtk.DropDown quality_dropdown { get; private set; }
    public Gtk.DropDown container_dropdown { get; private set; }
    public Gtk.DropDown audio_codec_dropdown { get; private set; }
    // Containers for video-specific rows (hidden in Audio Only / Music)
    private Gtk.Box video_codec_box;
    private Gtk.Box quality_box;
    private Gtk.Box container_box;
    private Gtk.Box fmt_row1;
    private Gtk.Separator sep1;
    private Gtk.Box fmt_row2;
    private Gtk.Box audio_box;
    private Adw.PreferencesGroup music_group;
    // Music widgets
    public Gtk.Entry music_dir_entry { get; private set; }
    public Gtk.DropDown music_format_dropdown { get; private set; }
    public Gtk.DropDown music_org_dropdown { get; private set; }
    public Gtk.CheckButton music_crop_check { get; private set; }
    public Gtk.CheckButton music_toml_check { get; private set; }
    public Gtk.CheckButton music_playlist_check { get; private set; }
    public Gtk.Entry music_playlist_entry { get; private set; }
    public Gtk.CheckButton music_sync_check { get; private set; }
    public Gtk.CheckButton meta_check { get; private set; }
    public Gtk.CheckButton thumb_check { get; private set; }
    public Gtk.CheckButton chapters_check { get; private set; }
    public Gtk.CheckButton subs_check { get; private set; }
    public Gtk.CheckButton auto_subs_check { get; private set; }
    public Gtk.CheckButton save_subs_srt_check { get; private set; }
    public Gtk.Entry langs_entry { get; private set; }
    public Gtk.CheckButton sb_enable { get; private set; }
    public Gtk.CheckButton sb_remove_radio { get; private set; }
    public Gtk.CheckButton sb_mark_radio { get; private set; }
    public Gtk.FlowBox sb_cats_box { get; private set; }
    public Gtk.Entry adv_entry { get; private set; }
    public Gtk.Label summary_label { get; private set; }

    public Adw.ToolbarView build (out Gtk.Button start_button) {
        var toolbar_view = new Adw.ToolbarView ();

        var header = new Adw.HeaderBar ();
        header.show_title = false;

        start_button = new Gtk.Button ();
        start_button.label = "Download";
        start_button.tooltip_text = "Start downloading with these options";
        start_button.add_css_class ("suggested-action");
        start_button.add_css_class ("pill");
        header.pack_end (start_button);

        toolbar_view.add_top_bar (header);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled.vexpand = true;

        var clamp = new Adw.Clamp ();
        clamp.maximum_size = 640;
        clamp.tightening_threshold = 500;
        clamp.margin_start = 12;
        clamp.margin_end = 12;

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
        content_box.margin_top = 16;
        content_box.margin_bottom = 16;
        clamp.child = content_box;

        // Live summary banner
        summary_label = new Gtk.Label ("");
        summary_label.add_css_class ("dim-label");
        summary_label.add_css_class ("caption");
        summary_label.wrap = true;
        summary_label.xalign = 0;
        summary_label.visible = false;
        content_box.append (summary_label);

        // --- Format PreferencesGroup ---
        var format_group = new Adw.PreferencesGroup ();
        format_group.title = "Format";
        format_group.description = "Choose how to download";

        // Type row as ActionRow with dropdown
        var type_row = new Adw.ActionRow ();
        type_row.title = "Type";
        type_row.subtitle = "Video, audio, or organized music library";
        type_dropdown = new Gtk.DropDown.from_strings ({ "Video", "Audio Only", "Music" });
        type_dropdown.valign = Gtk.Align.CENTER;
        type_row.add_suffix (type_dropdown);
        format_group.add (type_row);

        // Video rows container - will be hidden for audio / music
        var video_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        video_box.add_css_class ("card");
        // Row 1: codec + quality
        fmt_row1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        fmt_row1.margin_start = 12;
        fmt_row1.margin_end = 12;
        fmt_row1.margin_top = 8;
        fmt_row1.margin_bottom = 8;

        video_codec_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        video_codec_box.hexpand = true;
        var codec_label = new Gtk.Label ("Codec:");
        codec_label.xalign = 0;
        codec_dropdown = new Gtk.DropDown.from_strings ({
            "H.264", "H.265", "VP9", "AV1", "Any"
        });
        codec_dropdown.hexpand = true;
        video_codec_box.append (codec_label);
        video_codec_box.append (codec_dropdown);

        quality_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        quality_box.hexpand = true;
        var quality_label = new Gtk.Label ("Quality:");
        quality_label.xalign = 0;
        quality_dropdown = new Gtk.DropDown.from_strings ({
            "Best", "2160p", "1080p", "720p", "480p", "360p", "Worst"
        });
        quality_dropdown.hexpand = true;
        quality_box.append (quality_label);
        quality_box.append (quality_dropdown);

        fmt_row1.append (video_codec_box);
        fmt_row1.append (quality_box);
        video_box.append (fmt_row1);

        sep1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        video_box.append (sep1);

        // Row 2: container + audio
        fmt_row2 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        fmt_row2.margin_start = 12;
        fmt_row2.margin_end = 12;
        fmt_row2.margin_top = 8;
        fmt_row2.margin_bottom = 8;

        container_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        container_box.hexpand = true;
        var container_label = new Gtk.Label ("Container:");
        container_label.xalign = 0;
        container_dropdown = new Gtk.DropDown.from_strings ({
            "MP4", "MKV", "WebM"
        });
        container_dropdown.hexpand = true;
        container_box.append (container_label);
        container_box.append (container_dropdown);

        audio_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        audio_box.hexpand = true;
        var audio_codec_label = new Gtk.Label ("Audio:");
        audio_codec_label.xalign = 0;
        audio_codec_dropdown = new Gtk.DropDown.from_strings ({
            "AAC", "Opus", "MP3", "FLAC", "Any"
        });
        audio_codec_dropdown.hexpand = true;
        audio_box.append (audio_codec_label);
        audio_box.append (audio_codec_dropdown);

        fmt_row2.append (container_box);
        fmt_row2.append (audio_box);
        video_box.append (fmt_row2);
        format_group.add (video_box);

        // --- Music group (like ytm-sync) ---
        music_group = new Adw.PreferencesGroup ();
        music_group.title = "Music Library";
        music_group.description = "Organized as Artist / Album / Title — tracks content.toml like ytm-sync";

        var music_dir_row = new Adw.ActionRow ();
        music_dir_row.title = "Music directory";
        music_dir_row.subtitle = "Root for Artist/Album structure and content.toml";
        music_dir_entry = new Gtk.Entry ();
        music_dir_entry.placeholder_text = "~/Music";
        music_dir_entry.width_chars = 18;
        music_dir_entry.hexpand = true;
        var music_browse = new Gtk.Button ();
        music_browse.label = "Browse…";
        music_browse.add_css_class ("flat");
        music_browse.clicked.connect (() => {
            var dlg = new Gtk.FileDialog ();
            dlg.title = "Choose music library folder";
            try {
                var cur = File.new_for_path (music_dir_entry.text.replace ("~", Environment.get_home_dir ()));
                if (cur.query_exists ()) dlg.initial_folder = cur;
            } catch (Error e) {}
            dlg.select_folder.begin (null, null, (obj,res) => {
                try {
                    var f = dlg.select_folder.end (res);
                    music_dir_entry.text = f.get_path ();
                } catch (Error e) {}
            });
        });
        var music_dir_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        music_dir_box.append (music_dir_entry);
        music_dir_box.append (music_browse);
        music_dir_row.add_suffix (music_dir_box);
        music_group.add (music_dir_row);

        var music_fmt_row = new Adw.ActionRow ();
        music_fmt_row.title = "Music format";
        music_fmt_row.subtitle = "Opus recommended (ytm-sync default)";
        music_format_dropdown = new Gtk.DropDown.from_strings ({ "opus", "m4a", "mp3", "flac" });
        music_fmt_row.add_suffix (music_format_dropdown);
        music_group.add (music_fmt_row);

        var music_org_row = new Adw.ActionRow ();
        music_org_row.title = "Organization";
        music_org_row.subtitle = "How to arrange files";
        music_org_dropdown = new Gtk.DropDown.from_strings ({ "Artist / Album", "Artist only", "Flat" });
        music_org_row.add_suffix (music_org_dropdown);
        music_group.add (music_org_row);

        var music_playlist_row = new Adw.ActionRow ();
        music_playlist_row.title = "Playlist / Genre tag";
        music_playlist_row.subtitle = "Used as genre; empty = auto from source";
        music_playlist_entry = new Gtk.Entry ();
        music_playlist_entry.placeholder_text = "e.g. My Mix";
        music_playlist_entry.width_chars = 12;
        music_playlist_row.add_suffix (music_playlist_entry);
        music_group.add (music_playlist_row);

        music_crop_check = new Gtk.CheckButton.with_label ("Crop cover art to 1:1 square");
        music_crop_check.tooltip_text = "Center-crop non-square thumbnails like ytm-sync fix-covers";
        var crop_row = new Adw.ActionRow ();
        crop_row.title = "Square cover art";
        crop_row.subtitle = "Crop thumbnails to square (recommended)";
        crop_row.add_suffix (music_crop_check);
        music_group.add (crop_row);

        music_toml_check = new Gtk.CheckButton.with_label ("Track in content.toml");
        var toml_row = new Adw.ActionRow ();
        toml_row.title = "content.toml tracking";
        toml_row.subtitle = "Write ytm-sync-compatible index at \u00b7/content.toml";
        toml_row.add_suffix (music_toml_check);
        music_group.add (toml_row);

        music_playlist_check = new Gtk.CheckButton.with_label ("Generate .m3u8 playlists");
        var pl_row = new Adw.ActionRow ();
        pl_row.title = "Generate .m3u8";
        pl_row.subtitle = "Create playlist files per genre/playlist like ytm-sync";
        pl_row.add_suffix (music_playlist_check);
        music_group.add (pl_row);

        music_sync_check = new Gtk.CheckButton.with_label ("Optional YTM library sync");
        var sync_row = new Adw.ActionRow ();
        sync_row.title = "YTM library sync";
        sync_row.subtitle = "Requires ytm-sync auth at ~/.local/share/ytm-sync/auth.txt (optional)";
        sync_row.add_suffix (music_sync_check);
        music_group.add (sync_row);

        content_box.append (music_group);

        void update_format_visibility () {
            uint sel = type_dropdown.get_selected ();
            bool is_video = sel == 0;
            bool is_audio = sel == 1;
            bool is_music = sel == 2;
            // Video controls
            video_box.visible = is_video || is_audio;
            fmt_row1.visible = is_video;
            video_codec_box.visible = is_video;
            quality_box.visible = is_video;
            container_box.visible = is_video;
            sep1.visible = is_video;
            // Audio dropdown is visible for video and audio, hidden for music (music has its own)
            audio_box.visible = !is_music;
            // Music group
            music_group.visible = is_music;
            if (is_music) {
                format_group.description = "Music mode: Artist/Album/Title structure, Opus + metadata + content.toml";
            } else if (is_audio) {
                format_group.description = "Audio will be extracted — video options hidden";
            } else {
                format_group.description = "Choose how to download";
            }
            update_summary ();
        }
        update_format_visibility ();
        type_dropdown.notify["selected"].connect (() => {
            update_format_visibility ();
        });

        // Update summary when format changes
        codec_dropdown.notify["selected"].connect (() => { update_summary (); });
        quality_dropdown.notify["selected"].connect (() => { update_summary (); });
        container_dropdown.notify["selected"].connect (() => { update_summary (); });
        audio_codec_dropdown.notify["selected"].connect (() => { update_summary (); });
        music_format_dropdown.notify["selected"].connect (() => { update_summary (); });
        music_org_dropdown.notify["selected"].connect (() => { update_summary (); });

        content_box.append (format_group);

        // --- Metadata and Subtitles group ---
        // The ExpanderRow already carries the section title; leaving the group
        // untitled avoids the duplicated heading in the options page.
        var metadata_group = new Adw.PreferencesGroup ();

        var meta_expander = new Adw.ExpanderRow ();
        meta_expander.title = "Metadata and Subtitles";
        meta_expander.subtitle = "Embed metadata, thumbnails, and subtitles";
        // Use FlowBox for wrapping checkboxes
        var meta_flow = new Gtk.FlowBox ();
        meta_flow.orientation = Gtk.Orientation.HORIZONTAL;
        meta_flow.column_spacing = 12;
        meta_flow.row_spacing = 6;
        meta_flow.selection_mode = Gtk.SelectionMode.NONE;
        meta_flow.max_children_per_line = 3;
        meta_flow.min_children_per_line = 2;

        meta_check = new Gtk.CheckButton.with_label ("Metadata");
        meta_flow.append (meta_check);
        thumb_check = new Gtk.CheckButton.with_label ("Thumbnail");
        thumb_check.tooltip_text = "Not supported for WebM";
        meta_flow.append (thumb_check);
        chapters_check = new Gtk.CheckButton.with_label ("Chapters");
        meta_flow.append (chapters_check);
        subs_check = new Gtk.CheckButton.with_label ("Subtitles");
        meta_flow.append (subs_check);
        auto_subs_check = new Gtk.CheckButton.with_label ("Auto-subs");
        meta_flow.append (auto_subs_check);
        save_subs_srt_check = new Gtk.CheckButton.with_label (".srt only");
        save_subs_srt_check.tooltip_text = "Save subtitles as .srt files without embedding";
        meta_flow.append (save_subs_srt_check);

        var langs_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        langs_row.margin_top = 6;
        langs_row.append (new Gtk.Label ("Languages:"));
        langs_entry = new Gtk.Entry ();
        langs_entry.placeholder_text = "en, es";
        langs_entry.width_chars = 10;
        langs_entry.hexpand = true;
        langs_entry.tooltip_text = "Comma-separated language codes (e.g. en,es,ja)";
        langs_row.append (langs_entry);
        var meta_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        meta_inner.margin_top = 6;
        meta_inner.margin_bottom = 6;
        meta_inner.margin_start = 6;
        meta_inner.margin_end = 6;
        meta_inner.append (meta_flow);
        meta_inner.append (langs_row);
        meta_expander.add_row (meta_inner);
        metadata_group.add (meta_expander);

        content_box.append (metadata_group);

        // --- SponsorBlock group ---
        // The ExpanderRow already carries the section title.
        var sb_group = new Adw.PreferencesGroup ();

        var sb_expander = new Adw.ExpanderRow ();
        sb_expander.title = "SponsorBlock";
        sb_expander.subtitle = "Remove or mark sponsored segments";

        var sb_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
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
        sb_cats_box.max_children_per_line = 4;
        string[] cat_labels = { "Sponsor", "Intro", "Outro", "Self-promo", "Preview", "Filler" };
        string[] cat_keys = { "sponsor", "intro", "outro", "selfpromo", "preview", "filler" };
        for (int i = 0; i < cat_labels.length; i++) {
            var check = new Gtk.CheckButton.with_label (cat_labels[i]);
            // Store the yt-dlp category key (e.g. "selfpromo", not "self-promo").
            check.name = cat_keys[i];
            sb_cats_box.append (check);
        }
        sb_inner.append (sb_cats_box);

        // Sensitivity binding
        sb_enable.notify["active"].connect (() => {
            bool en = sb_enable.active;
            sb_action_box.sensitive = en;
            sb_cats_box.sensitive = en;
        });
        // Init
        sb_action_box.sensitive = sb_enable.active;
        sb_cats_box.sensitive = sb_enable.active;

        sb_expander.add_row (sb_inner);
        sb_group.add (sb_expander);
        content_box.append (sb_group);

        // --- Advanced group ---
        var adv_group = new Adw.PreferencesGroup ();
        adv_group.title = "Advanced";
        adv_group.description = "Custom yt-dlp arguments";

        var adv_row = new Adw.ActionRow ();
        adv_row.title = "Extra arguments";
        adv_row.subtitle = "e.g. --split-chapters --concurrent-fragments 4";
        adv_row.activatable = false;
        adv_entry = new Gtk.Entry ();
        adv_entry.placeholder_text = "--split-chapters --force-keyframes-at-cuts";
        adv_entry.hexpand = true;
        adv_entry.width_chars = 30;
        adv_entry.valign = Gtk.Align.CENTER;
        adv_row.add_suffix (adv_entry);
        adv_group.add (adv_row);

        content_box.append (adv_group);

        scrolled.child = clamp;
        toolbar_view.content = scrolled;

        return toolbar_view;
    }

    private void update_summary () {
        if (summary_label == null || type_dropdown == null) return;
        uint sel = type_dropdown.get_selected ();
        if (sel == 2) {
            var fmt_obj = (Gtk.StringObject) music_format_dropdown.get_selected_item ();
            var org_obj = (Gtk.StringObject) music_org_dropdown.get_selected_item ();
            string fmt = fmt_obj != null ? fmt_obj.get_string () : "opus";
            string org = org_obj != null ? org_obj.get_string () : "Artist / Album";
            summary_label.label = "Music • %s • %s • %sArtist/Album/Title + content.toml".printf (fmt, org, music_crop_check.active ? "square cover • " : "");
            summary_label.visible = true;
            return;
        }
        bool is_audio = sel == 1;
        var audio_obj = (Gtk.StringObject) audio_codec_dropdown.get_selected_item ();
        string audio = audio_obj != null ? audio_obj.get_string () : "AAC";
        if (is_audio) {
            summary_label.label = "Audio only • %s".printf (audio);
            summary_label.visible = true;
            return;
        }
        var codec_obj = (Gtk.StringObject) codec_dropdown.get_selected_item ();
        var qual_obj = (Gtk.StringObject) quality_dropdown.get_selected_item ();
        var cont_obj = (Gtk.StringObject) container_dropdown.get_selected_item ();
        string codec = codec_obj != null ? codec_obj.get_string () : "H.264";
        string qual = qual_obj != null ? qual_obj.get_string () : "Best";
        string cont = cont_obj != null ? cont_obj.get_string () : "MP4";
        summary_label.label = "%s • %s • %s • Audio: %s".printf (cont, qual, codec, audio);
        summary_label.visible = true;
    }

    public void sync_from_options (Velox.DownloadOptions opts) {
        // Type: 0 Video, 1 Audio, 2 Music
        if (opts.is_music_mode) type_dropdown.set_selected (2);
        else type_dropdown.set_selected (opts.is_audio_only ? 1 : 0);

        codec_dropdown.set_selected (dropdown_index_of (codec_dropdown, opts.video_codec));
        quality_dropdown.set_selected (dropdown_index_of (quality_dropdown, opts.video_quality));
        container_dropdown.set_selected (dropdown_index_of (container_dropdown, opts.container));
        audio_codec_dropdown.set_selected (dropdown_index_of (audio_codec_dropdown, opts.audio_codec));

        // Music
        music_dir_entry.text = opts.music_directory;
        music_format_dropdown.set_selected (dropdown_index_of (music_format_dropdown, opts.music_audio_format));
        // org maps: artist-album -> 0, artist ->1, flat->2
        int org_idx = 0;
        switch (opts.music_organization) {
            case "artist": org_idx = 1; break;
            case "flat": org_idx = 2; break;
            default: org_idx = 0; break;
        }
        music_org_dropdown.set_selected (org_idx);
        music_crop_check.active = opts.music_crop_thumbnail;
        music_toml_check.active = opts.music_use_content_toml;
        music_playlist_check.active = opts.music_generate_playlists;
        music_playlist_entry.text = opts.music_playlist_name;
        music_sync_check.active = opts.music_library_sync_enabled;

        meta_check.active = opts.embed_metadata;
        thumb_check.active = opts.embed_thumbnail;
        chapters_check.active = opts.embed_chapters;

        subs_check.active = opts.download_subtitles;
        auto_subs_check.active = opts.auto_subtitles;
        save_subs_srt_check.active = opts.save_subtitles_as_srt;
        langs_entry.text = opts.subtitle_languages;

        sb_enable.active = opts.sponsorblock_enabled;
        sb_remove_radio.active = opts.sponsorblock_remove;
        sb_remove_radio.group = sb_mark_radio;

        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    check.active = GLib.strv_contains (opts.sponsorblock_categories, check.name);
                }
            }
            child = child.get_next_sibling ();
        }

        adv_entry.text = opts.extra_args;
        update_summary ();
    }

    public void sync_to_options (Velox.DownloadOptions opts) {
        uint sel = type_dropdown.get_selected ();
        opts.is_music_mode = (sel == 2);
        opts.is_audio_only = (sel == 1) || opts.is_music_mode; // music also audio-only underneath

        var codec_obj = (Gtk.StringObject) codec_dropdown.get_selected_item ();
        opts.video_codec = codec_obj.get_string ();

        var quality_obj = (Gtk.StringObject) quality_dropdown.get_selected_item ();
        opts.video_quality = quality_obj.get_string ();

        var container_obj = (Gtk.StringObject) container_dropdown.get_selected_item ();
        opts.container = container_obj.get_string ();

        var audio_obj = (Gtk.StringObject) audio_codec_dropdown.get_selected_item ();
        opts.audio_codec = audio_obj.get_string ();

        // Music
        opts.music_directory = music_dir_entry.text.length > 0 ? music_dir_entry.text : "~/Music";
        var mfmt_obj = (Gtk.StringObject) music_format_dropdown.get_selected_item ();
        opts.music_audio_format = mfmt_obj != null ? mfmt_obj.get_string () : "opus";
        uint org_sel = music_org_dropdown.get_selected ();
        switch (org_sel) {
            case 1: opts.music_organization = "artist"; break;
            case 2: opts.music_organization = "flat"; break;
            default: opts.music_organization = "artist-album"; break;
        }
        opts.music_crop_thumbnail = music_crop_check.active;
        opts.music_use_content_toml = music_toml_check.active;
        opts.music_generate_playlists = music_playlist_check.active;
        opts.music_playlist_name = music_playlist_entry.text;
        opts.music_library_sync_enabled = music_sync_check.active;

        opts.embed_metadata = meta_check.active;
        opts.embed_thumbnail = thumb_check.active;
        opts.embed_chapters = chapters_check.active;

        opts.download_subtitles = subs_check.active;
        opts.embed_subtitles = subs_check.active && !save_subs_srt_check.active;
        opts.save_subtitles_as_srt = save_subs_srt_check.active;
        opts.auto_subtitles = auto_subs_check.active;
        opts.subtitle_languages = langs_entry.text.length > 0
            ? langs_entry.text : "en";

        opts.sponsorblock_enabled = sb_enable.active;
        opts.sponsorblock_remove = sb_remove_radio.active;

        var cats = new Array<string> ();
        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    if (check.active) {
                        cats.append_val (check.name);
                    }
                }
            }
            child = child.get_next_sibling ();
        }
        opts.sponsorblock_categories = cats.data;

        opts.extra_args = adv_entry.text;
    }

    private int dropdown_index_of (Gtk.DropDown dropdown, string value) {
        var model = dropdown.get_model () as Gtk.StringList;
        if (model == null) return 0;
        for (uint i = 0; i < model.get_n_items (); i++) {
            if (model.get_string (i) == value) return (int) i;
        }
        return 0;
    }
}
