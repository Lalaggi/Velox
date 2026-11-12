public class Velox.SettingsManager : GLib.Object {
    private GLib.Settings settings;

    construct {
        // Seamless migration from old app ID (com.github.lalaggi.velox) -> xyz.lalaggi.velox
        migrate_flatpak_data ();
        migrate_gsettings ();
        settings = new GLib.Settings ("xyz.lalaggi.velox");
    }

    private string get_real_home () {
        var home = Environment.get_home_dir ();
        // Inside a flatpak the sandbox sets HOME to ~/.var/app/<id>; the real
        // home (where the old com.github… data lives) is three levels up.
        if (FileUtils.test ("/.flatpak-info", FileTest.EXISTS)) {
            return Path.build_filename (home, "..", "..", "..");
        }
        return home;
    }

    private void migrate_flatpak_data () {
        try {
            var real_home = get_real_home ();
            var old_dir = File.new_for_path (Path.build_filename (real_home, ".var", "app", "com.github.lalaggi.velox"));
            var new_dir = File.new_for_path (Path.build_filename (real_home, ".var", "app", "xyz.lalaggi.velox"));
            if (old_dir.query_exists ()) {
                try { new_dir.make_directory_with_parents (); } catch (Error e) {}
                // Merge old contents into the (possibly already created) new dir.
                // -n avoids clobbering anything the new app already wrote.
                string cmd = "cp -a -n \"%s/.\" \"%s\"".printf ((!)old_dir.get_path (), (!)new_dir.get_path ());
                int es; string so, se;
                Process.spawn_command_line_sync (cmd, out so, out se, out es);
                if (es == 0) print ("Migrated flatpak data %s -> %s\n", (!)old_dir.get_path (), (!)new_dir.get_path ());
            }
            // Host XDG cache that used the old app ID as a directory name
            var old_cache = File.new_for_path (Path.build_filename (real_home, ".cache", "com.github.lalaggi.velox"));
            var new_cache = File.new_for_path (Path.build_filename (real_home, ".cache", "xyz.lalaggi.velox"));
            if (old_cache.query_exists ()) {
                try { new_cache.make_directory_with_parents (); } catch (Error e) {}
                string cmd = "cp -a -n \"%s/.\" \"%s\"".printf ((!)old_cache.get_path (), (!)new_cache.get_path ());
                int es; string so, se;
                Process.spawn_command_line_sync (cmd, out so, out se, out es);
            }
        } catch (Error e) {
            warning ("Flatpak data migration error: %s", e.message);
        }
    }

    private void migrate_gsettings () {
        try {
            var old_settings = new GLib.Settings ("com.github.lalaggi.velox");
            var new_settings = new GLib.Settings ("xyz.lalaggi.velox");
            var schema = new_settings.settings_schema;
            foreach (var key in old_settings.list_keys ()) {
                try {
                    if (!schema.has_key (key)) continue;
                    var old_val = old_settings.get_value (key);
                    var new_val = new_settings.get_value (key);
                    var def_val = new_settings.get_default_value (key);
                    if (def_val != null && new_val.equal ((!)def_val) && !old_val.equal (new_val)) {
                        new_settings.set_value (key, old_val);
                    }
                } catch (Error e) {
                    warning ("GSettings migrate key %s failed: %s", key, e.message);
                }
            }
            Settings.sync ();
        } catch (Error e) {
            debug ("GSettings migration skipped (no old schema): %s", e.message);
        }
    }

    // Output
    public string output_directory {
        owned get { return settings.get_string ("output-directory"); }
        set { settings.set_string ("output-directory", value); }
    }

    public string output_template {
        owned get { return settings.get_string ("output-template"); }
        set { settings.set_string ("output-template", value); }
    }

    public bool use_archive {
        get { return settings.get_boolean ("use-archive"); }
        set { settings.set_boolean ("use-archive", value); }
    }

    public string archive_path {
        owned get { return settings.get_string ("archive-path"); }
        set { settings.set_string ("archive-path", value); }
    }

    // Network
    public string rate_limit {
        owned get { return settings.get_string ("rate-limit"); }
        set { settings.set_string ("rate-limit", value); }
    }

    public string proxy {
        owned get { return settings.get_string ("proxy"); }
        set { settings.set_string ("proxy", value); }
    }

    public string cookies_file {
        owned get { return settings.get_string ("cookies-file"); }
        set { settings.set_string ("cookies-file", value); }
    }

    public bool force_ipv4 {
        get { return settings.get_boolean ("force-ipv4"); }
        set { settings.set_boolean ("force-ipv4", value); }
    }

    // Downloads
    public int max_concurrent {
        get { return settings.get_int ("max-concurrent"); }
        set { settings.set_int ("max-concurrent", value); }
    }

    // SponsorBlock
    public bool sponsorblock_enabled {
        get { return settings.get_boolean ("sponsorblock-enabled"); }
        set { settings.set_boolean ("sponsorblock-enabled", value); }
    }

    public bool sponsorblock_remove {
        get { return settings.get_boolean ("sponsorblock-remove"); }
        set { settings.set_boolean ("sponsorblock-remove", value); }
    }

    public string[] sponsorblock_categories {
        owned get { return settings.get_strv ("sponsorblock-categories"); }
        set { settings.set_strv ("sponsorblock-categories", value); }
    }

    // Default formats
    public string default_video_codec {
        owned get { return settings.get_string ("default-video-codec"); }
        set { settings.set_string ("default-video-codec", value); }
    }

    public string default_audio_codec {
        owned get { return settings.get_string ("default-audio-codec"); }
        set { settings.set_string ("default-audio-codec", value); }
    }

    public string default_quality {
        owned get { return settings.get_string ("default-quality"); }
        set { settings.set_string ("default-quality", value); }
    }

    public string default_container {
        owned get { return settings.get_string ("default-container"); }
        set { settings.set_string ("default-container", value); }
    }

    public bool default_audio_only {
        get { return settings.get_boolean ("default-audio-only"); }
        set { settings.set_boolean ("default-audio-only", value); }
    }

    public string default_subtitle_langs {
        owned get { return settings.get_string ("default-subtitle-langs"); }
        set { settings.set_string ("default-subtitle-langs", value); }
    }

    public bool default_download_subs {
        get { return settings.get_boolean ("default-download-subs"); }
        set { settings.set_boolean ("default-download-subs", value); }
    }

    public bool default_embed_subs {
        get { return settings.get_boolean ("default-embed-subs"); }
        set { settings.set_boolean ("default-embed-subs", value); }
    }

    public bool default_save_subs_as_srt {
        get { return settings.get_boolean ("default-save-subs-as-srt"); }
        set { settings.set_boolean ("default-save-subs-as-srt", value); }
    }

    public bool default_auto_subs {
        get { return settings.get_boolean ("default-auto-subs"); }
        set { settings.set_boolean ("default-auto-subs", value); }
    }

    public bool default_embed_metadata {
        get { return settings.get_boolean ("default-embed-metadata"); }
        set { settings.set_boolean ("default-embed-metadata", value); }
    }

    public bool default_embed_thumbnail {
        get { return settings.get_boolean ("default-embed-thumbnail"); }
        set { settings.set_boolean ("default-embed-thumbnail", value); }
    }

    public bool default_embed_chapters {
        get { return settings.get_boolean ("default-embed-chapters"); }
        set { settings.set_boolean ("default-embed-chapters", value); }
    }

    // Music library (ytm-sync parity)
    public string music_directory {
        owned get { return settings.get_string ("music-directory"); }
        set { settings.set_string ("music-directory", value); }
    }
    public bool music_crop_thumbnail {
        get { return settings.get_boolean ("music-crop-thumbnail"); }
        set { settings.set_boolean ("music-crop-thumbnail", value); }
    }
    public bool music_generate_playlists {
        get { return settings.get_boolean ("music-generate-playlists"); }
        set { settings.set_boolean ("music-generate-playlists", value); }
    }
    public bool music_use_content_toml {
        get { return settings.get_boolean ("music-use-content-toml"); }
        set { settings.set_boolean ("music-use-content-toml", value); }
    }
    public string music_audio_format {
        owned get { return settings.get_string ("music-audio-format"); }
        set { settings.set_string ("music-audio-format", value); }
    }
    public string music_organization {
        owned get { return settings.get_string ("music-organization"); }
        set { settings.set_string ("music-organization", value); }
    }
    public bool music_library_sync_enabled {
        get { return settings.get_boolean ("music-library-sync-enabled"); }
        set { settings.set_boolean ("music-library-sync-enabled", value); }
    }
    public bool default_is_music {
        get { return settings.get_boolean ("default-is-music"); }
        set { settings.set_boolean ("default-is-music", value); }
    }

    // Apply saved defaults to a DownloadOptions object
    public void apply_defaults (Velox.DownloadOptions opts) {
        opts.output_directory = output_directory;
        opts.output_template = output_template;
        opts.is_audio_only = default_audio_only;
        opts.is_music_mode = default_is_music;
        opts.music_directory = music_directory;
        opts.music_crop_thumbnail = music_crop_thumbnail;
        opts.music_generate_playlists = music_generate_playlists;
        opts.music_use_content_toml = music_use_content_toml;
        opts.music_audio_format = music_audio_format;
        opts.music_organization = music_organization;
        opts.music_library_sync_enabled = music_library_sync_enabled;
        opts.video_codec = default_video_codec;
        opts.audio_codec = default_audio_codec;
        opts.video_quality = default_quality;
        opts.container = default_container;
        opts.subtitle_languages = default_subtitle_langs;
        opts.download_subtitles = default_download_subs;
        opts.embed_subtitles = default_embed_subs;
        opts.save_subtitles_as_srt = default_save_subs_as_srt;
        opts.auto_subtitles = default_auto_subs;
        opts.embed_metadata = default_embed_metadata;
        opts.embed_thumbnail = default_embed_thumbnail;
        opts.embed_chapters = default_embed_chapters;
        opts.sponsorblock_enabled = sponsorblock_enabled;
        opts.sponsorblock_remove = sponsorblock_remove;
        opts.sponsorblock_categories = sponsorblock_categories;
        opts.use_archive = use_archive;
        opts.archive_path = archive_path;
        opts.rate_limit = rate_limit;
        opts.proxy = proxy;
        opts.cookies_file = cookies_file;
        opts.force_ipv4 = force_ipv4;
    }
}
