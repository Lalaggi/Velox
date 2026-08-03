public class Velox.SettingsManager : GLib.Object {
    private GLib.Settings settings;

    construct {
        settings = new GLib.Settings ("com.github.lalaggi.velox");
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

    // Apply saved defaults to a DownloadOptions object
    public void apply_defaults (Velox.DownloadOptions opts) {
        opts.output_directory = output_directory;
        opts.output_template = output_template;
        opts.is_audio_only = default_audio_only;
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
    }
}
