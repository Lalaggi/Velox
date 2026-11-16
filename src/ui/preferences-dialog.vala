public class Velox.PreferencesDialog : Adw.PreferencesDialog {
    public Velox.SettingsManager settings { get; set; }

    // Output widgets
    private Adw.ActionRow output_dir_row;
    private Adw.EntryRow output_template_row;
    private Adw.SwitchRow use_archive_row;
    private Adw.EntryRow archive_path_row;

    // Network widgets
    private Adw.EntryRow rate_limit_row;
    private Adw.EntryRow proxy_row;
    private Adw.EntryRow cookies_row;
    private Adw.SwitchRow force_ipv4_row;

    // Downloads widgets
    private Gtk.SpinButton max_concurrent_spin;

    // SponsorBlock widgets
    private Adw.SwitchRow sb_enable_row;
    private Adw.SwitchRow sb_remove_row;
    private Gtk.FlowBox sb_cats_box;

    // Default format widgets
    private Adw.ComboRow default_codec_row;
    private Adw.ComboRow default_quality_row;
    private Adw.ComboRow default_container_row;
    private Adw.ComboRow default_audio_codec_row;
    private Adw.SwitchRow default_audio_only_row;
    private Adw.SwitchRow default_is_music_row;
    private Adw.EntryRow default_sublangs_row;
    private Adw.SwitchRow default_download_subs_row;
    private Adw.SwitchRow default_embed_subs_row;
    private Adw.SwitchRow default_save_srt_row;
    private Adw.SwitchRow default_auto_subs_row;
    private Adw.SwitchRow default_embed_metadata_row;
    private Adw.SwitchRow default_embed_thumbnail_row;
    private Adw.SwitchRow default_embed_chapters_row;

    // Music library widgets
    private Adw.ActionRow music_dir_row;
    private Adw.ComboRow music_format_row;
    private Adw.ComboRow music_org_row;
    private Adw.SwitchRow music_crop_row;
    private Adw.SwitchRow music_toml_row;
    private Adw.SwitchRow music_playlist_row;
    private Adw.SwitchRow music_sync_row;

    public PreferencesDialog (Velox.SettingsManager mgr) {
        Object ();

        // Build UI here (not in construct) to guarantee settings is available
        this.title = "Preferences";

        // Output section
        var output_page = new Adw.PreferencesPage ();
        output_page.title = "Output";
        output_page.icon_name = "folder-download-symbolic";
        this.add (output_page);

        var output_group = new Adw.PreferencesGroup ();
        output_group.title = "Output";
        output_page.add (output_group);

        output_dir_row = new Adw.ActionRow ();
        output_dir_row.title = "Directory";
        output_dir_row.subtitle = mgr.output_directory;
        output_group.add (output_dir_row);

        var dir_button = new Gtk.Button ();
        dir_button.label = "Browse\u2026";
        dir_button.add_css_class ("flat");
        dir_button.clicked.connect (() => {
            var dialog = new Gtk.FileDialog ();
            dialog.title = "Choose output directory";
            var initial = File.new_for_path (mgr.output_directory);
            if (initial.query_exists ()) {
                dialog.initial_folder = initial;
            }
            dialog.select_folder.begin (null, null, (obj, res) => {
                try {
                    var folder = dialog.select_folder.end (res);
                    output_dir_row.subtitle = folder.get_path ();
                    save_settings (mgr);
                } catch (Error e) {
                    // cancelled, ignore
                }
            });
        });
        output_dir_row.add_suffix (dir_button);

        output_template_row = new Adw.EntryRow ();
        output_template_row.title = "Filename template";
        output_template_row.text = mgr.output_template;
        output_template_row.show_apply_button = true;
        output_group.add (output_template_row);

        use_archive_row = new Adw.SwitchRow ();
        use_archive_row.title = "Use download archive";
        use_archive_row.subtitle = "Skip already downloaded files";
        use_archive_row.active = mgr.use_archive;
        output_group.add (use_archive_row);

        archive_path_row = new Adw.EntryRow ();
        archive_path_row.title = "Archive file";
        archive_path_row.text = mgr.archive_path;
        archive_path_row.visible = mgr.use_archive;
        output_group.add (archive_path_row);

        use_archive_row.notify["active"].connect (() => {
            archive_path_row.visible = use_archive_row.active;
        });

        // Network section
        var network_page = new Adw.PreferencesPage ();
        network_page.title = "Network";
        network_page.icon_name = "network-wireless-symbolic";
        this.add (network_page);

        var network_group = new Adw.PreferencesGroup ();
        network_group.title = "Network";
        network_page.add (network_group);

        rate_limit_row = new Adw.EntryRow ();
        rate_limit_row.title = "Rate limit (KB/s)";
        rate_limit_row.tooltip_text = "Empty = unlimited. Bare numbers are treated as KB/s.";
        rate_limit_row.text = mgr.rate_limit;
        rate_limit_row.show_apply_button = true;
        network_group.add (rate_limit_row);

        proxy_row = new Adw.EntryRow ();
        proxy_row.title = "Proxy";
        proxy_row.text = mgr.proxy;
        proxy_row.show_apply_button = true;
        network_group.add (proxy_row);

        cookies_row = new Adw.EntryRow ();
        cookies_row.title = "Cookies file";
        cookies_row.text = mgr.cookies_file;
        cookies_row.show_apply_button = true;
        network_group.add (cookies_row);

        force_ipv4_row = new Adw.SwitchRow ();
        force_ipv4_row.title = "Force IPv4";
        force_ipv4_row.active = mgr.force_ipv4;
        network_group.add (force_ipv4_row);

        // Downloads section
        var downloads_page = new Adw.PreferencesPage ();
        downloads_page.title = "Downloads";
        downloads_page.icon_name = "emblem-synchronizing-symbolic";
        this.add (downloads_page);

        var downloads_group = new Adw.PreferencesGroup ();
        downloads_group.title = "Concurrency";
        downloads_page.add (downloads_group);

        var max_row = new Adw.ActionRow ();
        max_row.title = "Maximum concurrent downloads";
        max_row.subtitle = "Number of downloads to run at the same time";
        max_concurrent_spin = new Gtk.SpinButton.with_range (1, 10, 1);
        max_concurrent_spin.value = mgr.max_concurrent;
        max_row.add_suffix (max_concurrent_spin);
        downloads_group.add (max_row);

        // SponsorBlock section
        var sb_group = new Adw.PreferencesGroup ();
        sb_group.title = "SponsorBlock";
        downloads_page.add (sb_group);

        sb_enable_row = new Adw.SwitchRow ();
        sb_enable_row.title = "Enable SponsorBlock";
        sb_enable_row.subtitle = "Process sponsored segments by default";
        sb_enable_row.active = mgr.sponsorblock_enabled;
        sb_group.add (sb_enable_row);

        sb_remove_row = new Adw.SwitchRow ();
        sb_remove_row.title = "Remove segments";
        sb_remove_row.subtitle = "Remove segments (off = mark as chapters)";
        sb_remove_row.active = mgr.sponsorblock_remove;
        sb_remove_row.visible = mgr.sponsorblock_enabled;
        sb_group.add (sb_remove_row);

        sb_enable_row.notify["active"].connect (() => {
            sb_remove_row.visible = sb_enable_row.active;
            sb_cats_box.visible = sb_enable_row.active;
        });

        sb_cats_box = new Gtk.FlowBox ();
        sb_cats_box.orientation = Gtk.Orientation.HORIZONTAL;
        sb_cats_box.column_spacing = 8;
        sb_cats_box.row_spacing = 4;
        sb_cats_box.margin_start = 12;
        sb_cats_box.selection_mode = Gtk.SelectionMode.NONE;
        sb_cats_box.visible = mgr.sponsorblock_enabled;

        string[] cat_labels = { "Sponsor", "Intro", "Outro", "Self-promo", "Preview", "Filler" };
        string[] cat_keys = { "sponsor", "intro", "outro", "selfpromo", "preview", "filler" };
        var saved_cats = mgr.sponsorblock_categories;
        for (int i = 0; i < cat_labels.length; i++) {
            var check = new Gtk.CheckButton.with_label (cat_labels[i]);
            check.active = GLib.strv_contains (saved_cats, cat_keys[i]);
            check.name = cat_keys[i];
            sb_cats_box.append (check);
        }
        sb_group.add (sb_cats_box);

        // Default formats section
        var formats_page = new Adw.PreferencesPage ();
        formats_page.title = "Defaults";
        formats_page.icon_name = "preferences-other-symbolic";
        this.add (formats_page);

        var formats_group = new Adw.PreferencesGroup ();
        formats_group.title = "Default download options";
        formats_page.add (formats_group);

        default_audio_only_row = new Adw.SwitchRow ();
        default_audio_only_row.title = "Audio only";
        default_audio_only_row.subtitle = "Download audio by default";
        default_audio_only_row.active = mgr.default_audio_only;
        formats_group.add (default_audio_only_row);

        default_is_music_row = new Adw.SwitchRow ();
        default_is_music_row.title = "Music mode";
        default_is_music_row.subtitle = "Organized Artist/Album library with content.toml like ytm-sync";
        default_is_music_row.active = mgr.default_is_music;
        formats_group.add (default_is_music_row);

        // Video group (hidden when Audio only is on)
        default_codec_row = new Adw.ComboRow ();
        default_codec_row.title = "Video codec";
        default_codec_row.model = new Gtk.StringList ({
            "H.264", "H.265", "VP9", "AV1", "Any"
        });
        default_codec_row.selected = codec_to_index (mgr.default_video_codec);
        formats_group.add (default_codec_row);

        default_quality_row = new Adw.ComboRow ();
        default_quality_row.title = "Video quality";
        default_quality_row.model = new Gtk.StringList ({
            "Best", "2160p", "1080p", "720p", "480p", "360p", "Worst"
        });
        default_quality_row.selected = quality_to_index (mgr.default_quality);
        formats_group.add (default_quality_row);

        default_container_row = new Adw.ComboRow ();
        default_container_row.title = "Container";
        default_container_row.model = new Gtk.StringList ({
            "MP4", "MKV", "WebM"
        });
        default_container_row.selected = container_to_index (mgr.default_container);
        formats_group.add (default_container_row);

        default_audio_codec_row = new Adw.ComboRow ();
        default_audio_codec_row.title = "Audio codec";
        default_audio_codec_row.model = new Gtk.StringList ({
            "AAC", "Opus", "MP3", "FLAC", "Any"
        });
        default_audio_codec_row.selected = audio_codec_to_index (mgr.default_audio_codec);
        formats_group.add (default_audio_codec_row);

        // Audio-only / Music hides video-related rows (they are ignored by the audio pipeline)
        void update_format_visibility () {
            bool audio = default_audio_only_row.active;
            bool music = default_is_music_row.active;
            if (music) audio = true;
            default_codec_row.visible = !audio;
            default_quality_row.visible = !audio;
            default_container_row.visible = !audio;
            if (music) {
                default_audio_only_row.subtitle = "Audio only (enabled by Music)";
                default_audio_only_row.sensitive = false;
            } else {
                default_audio_only_row.subtitle = "Download audio by default";
                default_audio_only_row.sensitive = true;
            }
        }
        update_format_visibility ();
        default_audio_only_row.notify["active"].connect (() => {
            update_format_visibility ();
        });
        default_is_music_row.notify["active"].connect (() => {
            update_format_visibility ();
        });

        default_sublangs_row = new Adw.EntryRow ();
        default_sublangs_row.title = "Subtitle languages";
        default_sublangs_row.text = mgr.default_subtitle_langs;
        default_sublangs_row.show_apply_button = true;
        formats_group.add (default_sublangs_row);

        // Metadata defaults
        var meta_group = new Adw.PreferencesGroup ();
        meta_group.title = "Metadata defaults";
        formats_page.add (meta_group);

        default_embed_metadata_row = new Adw.SwitchRow ();
        default_embed_metadata_row.title = "Embed metadata";
        default_embed_metadata_row.active = mgr.default_embed_metadata;
        meta_group.add (default_embed_metadata_row);

        default_embed_thumbnail_row = new Adw.SwitchRow ();
        default_embed_thumbnail_row.title = "Embed thumbnail";
        default_embed_thumbnail_row.subtitle = "Not supported for WebM";
        default_embed_thumbnail_row.active = mgr.default_embed_thumbnail;
        meta_group.add (default_embed_thumbnail_row);

        default_embed_chapters_row = new Adw.SwitchRow ();
        default_embed_chapters_row.title = "Embed chapters";
        default_embed_chapters_row.active = mgr.default_embed_chapters;
        meta_group.add (default_embed_chapters_row);

        // Subtitle defaults
        var subs_group = new Adw.PreferencesGroup ();
        subs_group.title = "Subtitle defaults";
        formats_page.add (subs_group);

        default_download_subs_row = new Adw.SwitchRow ();
        default_download_subs_row.title = "Download subtitles";
        default_download_subs_row.active = mgr.default_download_subs;
        subs_group.add (default_download_subs_row);

        default_embed_subs_row = new Adw.SwitchRow ();
        default_embed_subs_row.title = "Embed subtitles";
        default_embed_subs_row.active = mgr.default_embed_subs;
        subs_group.add (default_embed_subs_row);

        default_save_srt_row = new Adw.SwitchRow ();
        default_save_srt_row.title = "Save as .srt only";
        default_save_srt_row.subtitle = "Save subtitle files without embedding";
        default_save_srt_row.active = mgr.default_save_subs_as_srt;
        subs_group.add (default_save_srt_row);

        default_auto_subs_row = new Adw.SwitchRow ();
        default_auto_subs_row.title = "Include auto-generated subtitles";
        default_auto_subs_row.active = mgr.default_auto_subs;
        subs_group.add (default_auto_subs_row);

        // Music library page (ytm-sync parity)
        var music_page = new Adw.PreferencesPage ();
        music_page.title = "Music";
        music_page.icon_name = "folder-music-symbolic";
        this.add (music_page);

        var music_group = new Adw.PreferencesGroup ();
        music_group.title = "Music Library";
        music_group.description = "Organized like ytm-sync: Artist/Album/Title + content.toml + .m3u8";
        music_page.add (music_group);

        music_dir_row = new Adw.ActionRow ();
        music_dir_row.title = "Music directory";
        music_dir_row.subtitle = mgr.music_directory;
        music_group.add (music_dir_row);
        var music_btn = new Gtk.Button ();
        music_btn.label = "Browse…";
        music_btn.add_css_class ("flat");
        music_btn.clicked.connect (() => {
            var dlg = new Gtk.FileDialog ();
            dlg.title = "Choose music library folder";
            var cur = File.new_for_path (mgr.music_directory.replace ("~", Environment.get_home_dir ()));
            if (cur.query_exists ()) dlg.initial_folder = cur;
            dlg.select_folder.begin (null, null, (obj,res) => {
                try {
                    var f = dlg.select_folder.end (res);
                    music_dir_row.subtitle = f.get_path ();
                    save_settings (mgr);
                } catch (Error e) {}
            });
        });
        music_dir_row.add_suffix (music_btn);

        music_format_row = new Adw.ComboRow ();
        music_format_row.title = "Music format";
        music_format_row.subtitle = "Opus recommended (ytm-sync)";
        music_format_row.model = new Gtk.StringList ({ "opus", "m4a", "mp3", "flac" });
        music_format_row.selected = music_format_to_index (mgr.music_audio_format);
        music_group.add (music_format_row);

        music_org_row = new Adw.ComboRow ();
        music_org_row.title = "Organization";
        music_org_row.model = new Gtk.StringList ({ "Artist / Album", "Artist only", "Flat" });
        music_org_row.selected = music_org_to_index (mgr.music_organization);
        music_group.add (music_org_row);

        music_crop_row = new Adw.SwitchRow ();
        music_crop_row.title = "Square cover art";
        music_crop_row.subtitle = "Center-crop non-square thumbnails to 1:1 (ytm-sync fix-covers)";
        music_crop_row.active = mgr.music_crop_thumbnail;
        music_group.add (music_crop_row);

        music_toml_row = new Adw.SwitchRow ();
        music_toml_row.title = "Track in content.toml";
        music_toml_row.subtitle = "Write ytm-sync compatible index";
        music_toml_row.active = mgr.music_use_content_toml;
        music_group.add (music_toml_row);

        music_playlist_row = new Adw.SwitchRow ();
        music_playlist_row.title = "Generate .m3u8 playlists";
        music_playlist_row.subtitle = "Group tracks by genre/playlist";
        music_playlist_row.active = mgr.music_generate_playlists;
        music_group.add (music_playlist_row);

        music_sync_row = new Adw.SwitchRow ();
        music_sync_row.title = "Optional YTM library sync";
        music_sync_row.subtitle = "Use ytm-sync auth if present (~/.local/share/ytm-sync/auth.txt)";
        music_sync_row.active = mgr.music_library_sync_enabled;
        music_group.add (music_sync_row);

        // Save when dialog closes
        this.closed.connect (() => { save_settings (mgr); });

        // Also save immediately on each change
        output_dir_row.notify["subtitle"].connect (() => { save_settings (mgr); });
        output_template_row.notify["text"].connect (() => { save_settings (mgr); });
        use_archive_row.notify["active"].connect (() => { save_settings (mgr); });
        archive_path_row.notify["text"].connect (() => { save_settings (mgr); });
        rate_limit_row.notify["text"].connect (() => { save_settings (mgr); });
        proxy_row.notify["text"].connect (() => { save_settings (mgr); });
        cookies_row.notify["text"].connect (() => { save_settings (mgr); });
        force_ipv4_row.notify["active"].connect (() => { save_settings (mgr); });
        max_concurrent_spin.notify["value"].connect (() => { save_settings (mgr); });
        sb_enable_row.notify["active"].connect (() => { save_settings (mgr); });
        sb_remove_row.notify["active"].connect (() => { save_settings (mgr); });
        default_audio_only_row.notify["active"].connect (() => { save_settings (mgr); });
        default_is_music_row.notify["active"].connect (() => { save_settings (mgr); });
        default_codec_row.notify["selected"].connect (() => { save_settings (mgr); });
        default_quality_row.notify["selected"].connect (() => { save_settings (mgr); });
        default_container_row.notify["selected"].connect (() => { save_settings (mgr); });
        default_audio_codec_row.notify["selected"].connect (() => { save_settings (mgr); });
        music_dir_row.notify["subtitle"].connect (() => { save_settings (mgr); });
        music_format_row.notify["selected"].connect (() => { save_settings (mgr); });
        music_org_row.notify["selected"].connect (() => { save_settings (mgr); });
        music_crop_row.notify["active"].connect (() => { save_settings (mgr); });
        music_toml_row.notify["active"].connect (() => { save_settings (mgr); });
        music_playlist_row.notify["active"].connect (() => { save_settings (mgr); });
        music_sync_row.notify["active"].connect (() => { save_settings (mgr); });
        default_sublangs_row.notify["text"].connect (() => { save_settings (mgr); });
        default_download_subs_row.notify["active"].connect (() => { save_settings (mgr); });
        default_embed_subs_row.notify["active"].connect (() => { save_settings (mgr); });
        default_save_srt_row.notify["active"].connect (() => { save_settings (mgr); });
        default_auto_subs_row.notify["active"].connect (() => { save_settings (mgr); });
        default_embed_metadata_row.notify["active"].connect (() => { save_settings (mgr); });
        default_embed_thumbnail_row.notify["active"].connect (() => { save_settings (mgr); });
        default_embed_chapters_row.notify["active"].connect (() => { save_settings (mgr); });
    }

    private void save_settings (Velox.SettingsManager mgr) {
        mgr.output_directory = output_dir_row.subtitle;
        mgr.output_template = output_template_row.text;
        mgr.use_archive = use_archive_row.active;
        mgr.archive_path = archive_path_row.text;

        mgr.rate_limit = rate_limit_row.text;
        mgr.proxy = proxy_row.text;
        mgr.cookies_file = cookies_row.text;
        mgr.force_ipv4 = force_ipv4_row.active;

        mgr.max_concurrent = max_concurrent_spin.get_value_as_int ();

        mgr.sponsorblock_enabled = sb_enable_row.active;
        mgr.sponsorblock_remove = sb_remove_row.active;

        var cats = new GLib.GenericArray<string> ();
        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    if (check.active) {
                        cats.add (check.name);
                    }
                }
            }
            child = child.get_next_sibling ();
        }
        string[] cat_array = new string[cats.length];
        for (int i = 0; i < cats.length; i++) {
            cat_array[i] = cats[i];
        }
        mgr.sponsorblock_categories = cat_array;

        mgr.default_audio_only = default_audio_only_row.active;
        mgr.default_is_music = default_is_music_row.active;
        mgr.default_video_codec = index_to_codec ((int) default_codec_row.selected);
        mgr.default_quality = index_to_quality ((int) default_quality_row.selected);
        mgr.default_container = index_to_container ((int) default_container_row.selected);
        mgr.default_audio_codec = index_to_audio_codec ((int) default_audio_codec_row.selected);
        mgr.default_subtitle_langs = default_sublangs_row.text;
        mgr.music_directory = music_dir_row.subtitle;
        mgr.music_audio_format = index_to_music_format ((int) music_format_row.selected);
        mgr.music_organization = index_to_music_org ((int) music_org_row.selected);
        mgr.music_crop_thumbnail = music_crop_row.active;
        mgr.music_use_content_toml = music_toml_row.active;
        mgr.music_generate_playlists = music_playlist_row.active;
        mgr.music_library_sync_enabled = music_sync_row.active;
        mgr.default_download_subs = default_download_subs_row.active;
        mgr.default_embed_subs = default_embed_subs_row.active;
        mgr.default_save_subs_as_srt = default_save_srt_row.active;
        mgr.default_auto_subs = default_auto_subs_row.active;
        mgr.default_embed_metadata = default_embed_metadata_row.active;
        mgr.default_embed_thumbnail = default_embed_thumbnail_row.active;
        mgr.default_embed_chapters = default_embed_chapters_row.active;
    }

    private int codec_to_index (string codec) {
        switch (codec) {
            case "H.264": return 0;
            case "H.265": return 1;
            case "VP9":   return 2;
            case "AV1":   return 3;
            default:      return 4;
        }
    }

    private string index_to_codec (int idx) {
        string[] codecs = { "H.264", "H.265", "VP9", "AV1", "Any" };
        return idx >= 0 && idx < codecs.length ? codecs[idx] : "Any";
    }

    private int quality_to_index (string quality) {
        switch (quality) {
            case "Best":  return 0;
            case "2160p": return 1;
            case "1080p": return 2;
            case "720p":  return 3;
            case "480p":  return 4;
            case "360p":  return 5;
            case "Worst": return 6;
            default:      return 0;
        }
    }

    private string index_to_quality (int idx) {
        string[] quals = { "Best", "2160p", "1080p", "720p", "480p", "360p", "Worst" };
        return idx >= 0 && idx < quals.length ? quals[idx] : "Best";
    }

    private int container_to_index (string container) {
        switch (container) {
            case "MP4":  return 0;
            case "MKV":  return 1;
            case "WebM": return 2;
            default:     return 0;
        }
    }

    private string index_to_container (int idx) {
        string[] containers = { "MP4", "MKV", "WebM" };
        return idx >= 0 && idx < containers.length ? containers[idx] : "MP4";
    }

    private int audio_codec_to_index (string codec) {
        switch (codec) {
            case "AAC":  return 0;
            case "Opus": return 1;
            case "MP3":  return 2;
            case "FLAC": return 3;
            default:     return 4;
        }
    }

    private string index_to_audio_codec (int idx) {
        string[] codecs = { "AAC", "Opus", "MP3", "FLAC", "Any" };
        return idx >= 0 && idx < codecs.length ? codecs[idx] : "Any";
    }

    private int music_format_to_index (string fmt) {
        switch (fmt) {
            case "m4a": return 1;
            case "mp3": return 2;
            case "flac": return 3;
            default: return 0;
        }
    }
    private string index_to_music_format (int idx) {
        string[] fmts = { "opus", "m4a", "mp3", "flac" };
        return idx >=0 && idx < fmts.length ? fmts[idx] : "opus";
    }
    private int music_org_to_index (string org) {
        switch (org) {
            case "artist": return 1;
            case "flat": return 2;
            default: return 0;
        }
    }
    private string index_to_music_org (int idx) {
        string[] orgs = { "artist-album", "artist", "flat" };
        return idx >=0 && idx < orgs.length ? orgs[idx] : "artist-album";
    }


}
