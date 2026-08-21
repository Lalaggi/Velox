public class Velox.DownloadOptions : GLib.Object {
    // Output
    public string output_directory { get; set; default = ""; }
    public string output_template { get; set; default = "%(title)s.%(ext)s"; }

    // Video
    public string video_codec { get; set; default = "H.264"; }
    public string video_quality { get; set; default = "Best"; }
    public string container { get; set; default = "MP4"; }

    // Audio
    public string audio_codec { get; set; default = "AAC"; }
    public string audio_quality { get; set; default = "best"; }
    public string audio_container { get; set; default = "m4a"; }

    // Type
    public bool is_audio_only { get; set; default = false; }

    // Subtitles
    public bool download_subtitles { get; set; default = false; }
    public bool embed_subtitles { get; set; default = false; }
    public bool save_subtitles_as_srt { get; set; default = false; }
    public bool auto_subtitles { get; set; default = false; }
    public string subtitle_languages { get; set; default = "en"; }

    // Metadata
    public bool embed_metadata { get; set; default = false; }
    public bool embed_thumbnail { get; set; default = false; }
    public bool embed_chapters { get; set; default = false; }

    // SponsorBlock
    public bool sponsorblock_enabled { get; set; default = false; }
    public bool sponsorblock_remove { get; set; default = true; }
    public string[] sponsorblock_categories {
        owned get { return _sb_categories; }
        set { _sb_categories = value; }
    }
    private string[] _sb_categories = { "sponsor", "intro", "outro", "selfpromo" };

    // Archive
    public bool use_archive { get; set; default = false; }
    public string archive_path { get; set; default = ""; }

    // Advanced
    public string extra_args { get; set; default = ""; }

    // Network
    public string rate_limit { get; set; default = ""; }
    public string proxy { get; set; default = ""; }
    public string cookies_file { get; set; default = ""; }
    public bool force_ipv4 { get; set; default = false; }
}
