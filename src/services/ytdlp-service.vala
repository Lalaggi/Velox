public class Velox.YtdlpService : GLib.Object {
    public signal void info_fetched (Velox.DownloadItem item);
    public signal void info_fetch_failed (Velox.DownloadItem item, string error);
    public signal void progress_updated (Velox.DownloadItem item, string status_text, double progress);
    public signal void download_complete (Velox.DownloadItem item);
    public signal void download_failed (Velox.DownloadItem item, string error);

    private string ytdlp_path = "yt-dlp";
    private GLib.HashTable<Velox.DownloadItem, Subprocess> active_procs;

    construct {
        active_procs = new GLib.HashTable<Velox.DownloadItem, Subprocess> (direct_hash, direct_equal);
    }

    // Heuristic: does this look like a playlist URL we should expand?
    public static bool looks_like_playlist (string url) {
        string u = url.down ();
        return u.contains ("playlist?") || u.contains ("&list=") ||
               u.contains ("/sets/") || u.contains ("/playlist") ||
               u.contains ("album/") || u.contains ("/channel/") ||
               (u.contains ("list=") && !u.contains ("watch?"));
    }

    // Expand a playlist URL into its individual video URLs using
    // `yt-dlp --flat-playlist`. Returns an empty array if it isn't actually a
    // playlist (so the caller can fall back to treating it as a single video).
    public async string[] parse_playlist_urls (string url) {
        var result = new GLib.GenericArray<string> ();

        try {
            string[] argv = {
                ytdlp_path,
                "--flat-playlist",
                "--dump-json",
                "--no-warnings",
                "--ignore-errors",
                url
            };

            var proc = new Subprocess.newv (
                argv,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
            );

            var stdout = new DataInputStream (proc.get_stdout_pipe ());
            var stderr = new DataInputStream (proc.get_stderr_pipe ());

            // Drain stderr concurrently to prevent pipe-buffer deadlock.
            // If yt-dlp writes enough to stderr to fill the OS pipe buffer
            // (typically 64 KB), the child blocks and never closes stdout,
            // causing this coroutine to hang forever.
            var err_builder = new StringBuilder ();
            bool stderr_done = false;
            drain_stderr.begin (stderr, err_builder, (obj, res) => {
                drain_stderr.end (res);
                stderr_done = true;
            });

            string? line;
            while ((line = yield stdout.read_line_async (Priority.DEFAULT)) != null) {
                if (line.length == 0) continue;

                try {
                    var parser = new Json.Parser ();
                    parser.load_from_data (line);
                    var root = parser.get_root ().get_object ();
                    if (root == null) continue;

                    string? video_url = null;
                    if (root.has_member ("url")) {
                        video_url = root.get_string_member ("url");
                    } else if (root.has_member ("webpage_url")) {
                        video_url = root.get_string_member ("webpage_url");
                    }

                    if (video_url != null && video_url.length > 0) {
                        result.add (video_url);
                    }
                } catch (Error e) {
                    // Skip lines we can't parse.
                }
            }

            while (!stderr_done) {
                yield wait_idle ();
            }

            yield proc.wait_async ();
        } catch (Error e) {
            warning ("Failed to parse playlist %s: %s", url, e.message);
        }

        string[] urls = new string[result.length];
        for (int i = 0; i < result.length; i++) {
            urls[i] = result[i];
        }
        return urls;
    }

    public async void fetch_info (Velox.DownloadItem item) {
        item.update_state (FETCHING);

        try {
            string[] argv = {
                ytdlp_path,
                "--dump-json",
                "--no-download",
                "--no-playlist",
                "--no-warnings",
                item.url
            };

            var proc = new Subprocess.newv (
                argv,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
            );

            string stdout;
            string stderr;
            yield proc.communicate_utf8_async (null, null, out stdout, out stderr);

            if (!proc.get_successful ()) {
                info_fetch_failed (item, stderr.strip ());
                return;
            }

            // Parse JSON
            var parser = new Json.Parser ();
            parser.load_from_data (stdout);
            var root = parser.get_root ().get_object ();

            if (root.has_member ("title")) {
                item.title = root.get_string_member ("title");
            }
            if (root.has_member ("uploader")) {
                item.uploader = root.get_string_member ("uploader");
            }
            if (root.has_member ("creator")) {
                // Artist fallback for music
                string cr = root.get_string_member ("creator");
                if (cr.length > 0 && item.uploader.length == 0) item.uploader = cr;
                if (cr.length > 0) item.artist = cr;
            }
            if (root.has_member ("artist") && root.get_string_member ("artist").length > 0) {
                item.artist = root.get_string_member ("artist");
            } else if (root.has_member ("artists")) {
                // Rare: array string?
            }
            if (root.has_member ("album")) {
                var node = root.get_member ("album");
                if (node.get_node_type () == Json.NodeType.VALUE) {
                    string al = node.get_string ();
                    if (al != null) item.album = al;
                }
            }
            if (root.has_member ("album_id")) {
                item.album_id = root.get_string_member ("album_id");
            }
            if (root.has_member ("playlist_title")) {
                item.playlist_title = root.get_string_member ("playlist_title");
            } else if (root.has_member ("playlist")) {
                item.playlist_title = root.get_string_member ("playlist");
            }
            if (root.has_member ("id")) {
                item.youtube_id = root.get_string_member ("id");
            }
            if (root.has_member ("duration")) {
                try { item.duration = root.get_int_member ("duration"); } catch (Error e) {}
            }
            if (root.has_member ("thumbnail")) {
                item.thumbnail_url = root.get_string_member ("thumbnail");
            } else if (root.has_member ("thumbnails")) {
                // Try first thumbnail
                try {
                    var arr = root.get_array_member ("thumbnails");
                    if (arr.get_length () > 0) {
                        var first = arr.get_object_element (0);
                        if (first.has_member ("url")) item.thumbnail_url = first.get_string_member ("url");
                    }
                } catch (Error e) {}
            }
            // Fallback artist from uploader if still empty (music mode relies on artist)
            if (item.artist.length == 0 && item.uploader.length > 0) item.artist = item.uploader;

            info_fetched (item);
        } catch (Error e) {
            info_fetch_failed (item, e.message);
        }
    }

    public string[] build_download_args (Velox.DownloadItem item, Velox.DownloadOptions opts) {
        // Collect args into a GenericArray then convert
        var args = new GLib.GenericArray<string> ();

        args.add (ytdlp_path);
        args.add ("--newline");
        args.add ("--no-playlist");
        args.add ("--no-warnings");
        args.add ("--progress");

        // Format selection - music has its own pipeline (like ytm-sync)
        if (opts.is_music_mode) {
            // Music: Opus library mode - mirrors ytm-sync/download_track
            args.add ("-x");
            string mfmt = opts.music_audio_format.down ();
            if (mfmt == "m4a") mfmt = "m4a";
            else if (mfmt == "flac") mfmt = "flac";
            else if (mfmt == "mp3") mfmt = "mp3";
            else mfmt = "opus";
            args.add ("--audio-format");
            args.add (mfmt);
            if (mfmt == "opus") {
                args.add ("--audio-quality");
                args.add ("0");
            }
            // ytm-sync extractor hints for YTM
            args.add ("--extractor-args");
            args.add ("youtube:player-client=web_embedded,web");
            args.add ("--js-runtimes");
            args.add ("node");
            // Parse-metadata trick to ensure title correct
            if (item.title.length > 0) {
                args.add ("--parse-metadata");
                args.add (":%s:%%(title)s".printf (item.title));
            }
            // Embed thumbnail/metadata always for music (ytm-sync parity)
            args.add ("--embed-thumbnail");
            args.add ("--embed-metadata");
        } else if (opts.is_audio_only) {
            // Audio-only: extract audio with proper format mapping
            // Do NOT use video codec/quality/container at all
            args.add ("-x");
            string audio_fmt = get_audio_format_for_codec (opts.audio_codec);
            if (audio_fmt.length > 0) {
                args.add ("--audio-format");
                args.add (audio_fmt);
            }

            if (opts.audio_quality != "best") {
                args.add ("--audio-quality");
                args.add (opts.audio_quality);
            }

            string codec_filter = get_audio_codec_filter (opts.audio_codec);
            if (codec_filter.length > 0) {
                args.add ("-f");
                args.add (codec_filter);
            }
        } else {
            string fmt = build_video_format_string (opts);
            args.add ("-f");
            args.add (fmt);
            args.add ("--merge-output-format");
            args.add (opts.container.down ());
        }

        // Subtitles
        if (opts.embed_subtitles || opts.save_subtitles_as_srt) {
            if (opts.embed_subtitles) {
                args.add ("--embed-subs");
            } else {
                args.add ("--write-subs");
                args.add ("--convert-subs");
                args.add ("srt");
            }
            if (opts.auto_subtitles) {
                args.add ("--write-auto-subs");
            }
            args.add ("--sub-langs");
            args.add (opts.subtitle_languages);
        }

        // Metadata
        if (opts.is_music_mode) {
            // Music always embeds rich metadata (ytm-sync parity)
            // yt-dlp will already embed thumbnail/metadata above; add extra tags
            string artist = item.artist.length > 0 ? item.artist : (item.uploader.length > 0 ? item.uploader : "Unknown Artist");
            string album = item.album.length > 0 ? item.album : "Unknown Album";
            string title = item.title.length > 0 ? item.title : "Unknown Title";
            string genre = item.playlist_title.length > 0 ? item.playlist_title : (opts.music_playlist_name.length > 0 ? opts.music_playlist_name : "");
            string yid = item.youtube_id.length > 0 ? item.youtube_id : "";
            string url = yid.length > 0 ? "https://music.youtube.com/watch?v=%s".printf (yid) : item.url;
            args.add ("--metadata"); args.add ("title=%s".printf (title));
            args.add ("--metadata"); args.add ("artist=%s".printf (artist));
            args.add ("--metadata"); args.add ("album=%s".printf (album));
            if (genre.length > 0) { args.add ("--metadata"); args.add ("genre=%s".printf (genre)); }
            args.add ("--metadata"); args.add ("comment=%s".printf (url));
            args.add ("--metadata"); args.add ("purl=%s".printf (url));
            // Chapters not needed for music, but allow opt-in
            if (opts.embed_chapters) { args.add ("--embed-chapters"); }
        } else {
            if (opts.embed_metadata) {
                args.add ("--embed-metadata");
            }
            if (opts.embed_thumbnail) {
                args.add ("--embed-thumbnail");
            }
            if (opts.embed_chapters) {
                args.add ("--embed-chapters");
            }
        }

        // SponsorBlock
        if (opts.sponsorblock_enabled) {
            if (opts.sponsorblock_remove) {
                args.add ("--sponsorblock-remove");
            } else {
                args.add ("--sponsorblock-mark");
            }
            args.add (string.joinv (",", opts.sponsorblock_categories));
        }

        // Output template - music mode uses MusicLibrary helper (Artist/Album layout)
        if (opts.is_music_mode) {
            string outpath = Velox.MusicLibrary.build_music_output_path (item, opts);
            // Ensure parent dir exists (yt-dlp will create, but also ensure for content.toml)
            string dir = Path.get_dirname (outpath);
            var dfile = File.new_for_path (dir);
            try { dfile.make_directory_with_parents (); } catch (Error e) {}
            args.add ("-o");
            args.add (outpath);
            // Remember for post-processing
            item.output_path = outpath;
        } else {
            string output_dir = opts.output_directory.length > 0
                ? opts.output_directory.replace ("~", Environment.get_home_dir ())
                : Environment.get_home_dir ();
            while (output_dir.has_suffix ("/")) {
                output_dir = output_dir.substring (0, output_dir.length - 1);
            }
            string template = opts.output_template.length > 0
                ? opts.output_template
                : "%(title)s.%(ext)s";
            args.add ("-o");
            args.add (output_dir + "/" + template);
        }

        // Download archive
        if (opts.use_archive) {
            string archive = opts.archive_path.length > 0
                ? opts.archive_path.replace ("~", Environment.get_home_dir ())
                : Environment.get_home_dir () + "/Downloads/archive.txt";
            args.add ("--download-archive");
            args.add (archive);
        }

        // Extra args
        if (opts.extra_args.length > 0) {
            string[] extra = opts.extra_args.split (" ");
            foreach (var arg in extra) {
                var trimmed = arg.strip ();
                if (trimmed.length > 0) {
                    args.add (trimmed);
                }
            }
        }

        // Network settings
        if (opts.rate_limit.length > 0) {
            args.add ("--limit-rate");
            args.add (opts.rate_limit);
        }
        if (opts.proxy.length > 0) {
            args.add ("--proxy");
            args.add (opts.proxy);
        }
        if (opts.cookies_file.length > 0) {
            args.add ("--cookies");
            args.add (opts.cookies_file);
        }
        if (opts.force_ipv4) {
            args.add ("--force-ipv4");
        }

        args.add (item.url);

        // Convert to string[]
        string[] result = new string[args.length];
        for (int i = 0; i < args.length; i++) {
            result[i] = args[i];
        }
        return result;
    }

    private string build_video_format_string (Velox.DownloadOptions opts) {
        string height_filter = "";
        switch (opts.video_quality) {
            case "2160p": height_filter = "2160"; break;
            case "1440p": height_filter = "1440"; break;
            case "1080p": height_filter = "1080"; break;
            case "720p":  height_filter = "720"; break;
            case "480p":  height_filter = "480"; break;
            case "360p":  height_filter = "360"; break;
            case "240p":  height_filter = "240"; break;
            default: height_filter = ""; break;
        }

        string codec_part = "";
        switch (opts.video_codec) {
            case "H.264": codec_part = "[vcodec~='^((he|a)vc|h26[45])']"; break;
            case "H.265": codec_part = "[vcodec~='^(hevc|h265)']"; break;
            case "VP9":   codec_part = "[vcodec^='vp9']"; break;
            case "AV1":   codec_part = "[vcodec^='av01']"; break;
            default:      codec_part = ""; break;
        }

        // For vertical video (IG reels, TikTok 1080x1920) we must allow either orientation.
        // A strict [height<=1080] rejects vertical 1080x1920 (h=1920). Instead use both
        // short/long edge limits: short<=H and long<=W where W = H*16/9.
        // Two groups cover both orientations via AND:
        //  * width<=H height<=W  → vertical 1080x1920
        //  * height<=H width<=W  → horizontal 1920x1080
        if (height_filter.length > 0) {
            int h = int.parse (height_filter);
            int w = (int) (h * 16 / 9);
            // Fallback to h if parse failed
            if (w <= 0) w = h;
            string hf = "[height<=%d]".printf (h);
            string wf = "[width<=%d]".printf (h);
            string hf_w = "[height<=%d][width<=%d]".printf (h, w);
            string wf_h = "[width<=%d][height<=%d]".printf (h, w);
            string vcodec = codec_part;
            if (codec_part.length > 0) {
                // Include codec in each group
                return "bestvideo*%s%s+ba/bestvideo*%s%s+ba/bestvideo*%s+ba/b".printf (wf_h, vcodec, hf_w, vcodec, vcodec);
            } else {
                // No codec filter — pure resolution groups, then unrestricted best
                return "bestvideo*%s+ba/bestvideo*%s+ba/bv*+ba/b".printf (wf_h, hf_w);
            }
        }
        if (codec_part.length > 0) {
            return "bestvideo*%s+ba/b".printf (codec_part);
        }
        return "bestvideo+ba/b";
    }

    private string get_audio_format_for_codec (string codec) {
        // Map audio codec to the --audio-format container yt-dlp/ffmpeg expects
        // Any -> "" (no conversion, keep original best audio)
        switch (codec) {
            case "AAC":  return "m4a";
            case "Opus": return "opus";
            case "MP3":  return "mp3";
            case "FLAC": return "flac";
            default:     return "";
        }
    }

    private string get_audio_codec_filter (string codec) {
        switch (codec) {
            case "AAC":  return "ba[acodec~='mp4a']/ba";
            case "Opus": return "ba[acodec~='opus']/ba";
            case "MP3":  return "ba[acodec~='mp3']/ba";
            case "FLAC": return "ba[acodec~='flac']/ba";
            default:     return "";
        }
    }

    public async void download (Velox.DownloadItem item, Velox.DownloadOptions opts) {
        item.update_state (DOWNLOADING);
        item.progress = 0;

        // Buffered values for UI smoothing
        double buffered_progress = 0;
        string buffered_status = "";
        bool tick_pending = false;

        // Throttle UI updates to every 500ms
        uint tick_id = 0;
        tick_id = GLib.Timeout.add (500, () => {
            item.progress = buffered_progress;
            item.status_text = buffered_status;
            progress_updated (item, buffered_status, buffered_progress);
            tick_pending = false;
            return true; // keep ticking
        });

        try {
            string[] args = build_download_args (item, opts);

            var proc = new Subprocess.newv (
                args,
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
            );
            active_procs.@set (item, proc);

            var stdout = new DataInputStream (proc.get_stdout_pipe ());
            var stderr = new DataInputStream (proc.get_stderr_pipe ());

            var parser = new ProgressParser ();

            // Drain stderr concurrently. If we only read stdout to EOF first,
            // a verbose stderr (e.g. repeated 403 / rate-limit errors) can fill
            // its OS pipe buffer and block the child, which never exits and
            // never closes stdout -> the whole download coroutine hangs and its
            // slot is never released, wedging the queue.
            var err_builder = new StringBuilder ();
            bool stderr_done = false;
            drain_stderr.begin (stderr, err_builder, (obj, res) => {
                drain_stderr.end (res);
                stderr_done = true;
            });

            // Read stdout line by line
            string? line;
            while ((line = yield stdout.read_line_async (Priority.DEFAULT)) != null) {
                parser.parse_line (line);
                buffered_progress = parser.progress;
                buffered_status = parser.get_status_text ();

                // Immediately emit for non-progress phases
                if (parser.phase != "download") {
                    item.progress = buffered_progress;
                    item.status_text = buffered_status;
                    progress_updated (item, buffered_status, buffered_progress);
                }

                if (line.contains ("Destination:")) {
                    item.output_path = line.substring (line.index_of ("Destination:") + 13).strip ();
                }
            }

            // Wait for the concurrent stderr drain to finish (it ends once the
            // child closes its stderr pipe, which happens at process exit).
            while (!stderr_done) {
                yield wait_idle ();
            }

            // Remove the tick timer
            GLib.Source.remove (tick_id);

            yield proc.wait_async ();

            active_procs.remove (item);

            if (!proc.get_successful () && err_builder.str.contains ("is unusual") && err_builder.str.contains ("extracted extension")) {
                // Pornhub et al have thumbnail URLs like .../vts:9.9?hdnea=... where yt-dlp extracts ext '9' and aborts (GHSA-79w7-vh3h-8g4j).
                // Retry once without thumbnail embedding — video itself downloads fine (verified via direct yt-dlp without --embed-thumbnail).
                bool had_thumb = false;
                foreach (var a in args) if (a == "--embed-thumbnail") { had_thumb = true; break; }
                if (had_thumb && (opts.embed_thumbnail || opts.is_music_mode)) {
                    warning ("Retrying without --embed-thumbnail due to unsafe extension %s", err_builder.str.strip ());
                    // Build retry opts without thumbnail
                    var retry_opts = new DownloadOptions ();
                    retry_opts.output_directory = opts.output_directory;
                    retry_opts.output_template = opts.output_template;
                    retry_opts.video_codec = opts.video_codec;
                    retry_opts.video_quality = opts.video_quality;
                    retry_opts.container = opts.container;
                    retry_opts.audio_codec = opts.audio_codec;
                    retry_opts.audio_quality = opts.audio_quality;
                    retry_opts.is_audio_only = opts.is_audio_only;
                    retry_opts.is_music_mode = opts.is_music_mode;
                    retry_opts.music_directory = opts.music_directory;
                    retry_opts.music_audio_format = opts.music_audio_format;
                    retry_opts.music_crop_thumbnail = false;
                    retry_opts.music_generate_playlists = opts.music_generate_playlists;
                    retry_opts.music_use_content_toml = opts.music_use_content_toml;
                    retry_opts.music_organization = opts.music_organization;
                    retry_opts.music_playlist_name = opts.music_playlist_name;
                    retry_opts.download_subtitles = opts.download_subtitles;
                    retry_opts.embed_subtitles = opts.embed_subtitles;
                    retry_opts.save_subtitles_as_srt = opts.save_subtitles_as_srt;
                    retry_opts.auto_subtitles = opts.auto_subtitles;
                    retry_opts.subtitle_languages = opts.subtitle_languages;
                    retry_opts.embed_metadata = opts.embed_metadata;
                    retry_opts.embed_thumbnail = false;
                    retry_opts.embed_chapters = opts.embed_chapters;
                    retry_opts.sponsorblock_enabled = opts.sponsorblock_enabled;
                    retry_opts.sponsorblock_remove = opts.sponsorblock_remove;
                    retry_opts.sponsorblock_categories = opts.sponsorblock_categories;
                    retry_opts.use_archive = opts.use_archive;
                    retry_opts.archive_path = opts.archive_path;
                    retry_opts.extra_args = opts.extra_args;
                    retry_opts.rate_limit = opts.rate_limit;
                    retry_opts.proxy = opts.proxy;
                    retry_opts.cookies_file = opts.cookies_file;
                    retry_opts.force_ipv4 = opts.force_ipv4;
                    // Reset state to allow retry (tick/active already cleaned)
                    item.update_state (QUEUED);
                    yield download (item, retry_opts);
                    return;
                }
            }

            if (proc.get_successful ()) {
                // Enforce requested container + codecs via ffmpeg (fail-soft, bundled in flatpak)
                // Previous behaviour was "hint" (--merge-output-format) which yt-dlp ignores for single-file
                // downloads (pornhub, ig progressive). Now we strictly remux/re-encode to match UI.
                if (!opts.is_music_mode && !opts.is_audio_only) {
                    string outpath = item.output_path;
                    if (outpath.length > 0 && File.new_for_path (outpath).query_exists ()) {
                        if (GLib.Environment.find_program_in_path ("ffmpeg") != null && GLib.Environment.find_program_in_path ("ffprobe") != null) {
                            string new_path;
                            string reason;
                            if (needs_enforcement (outpath, opts, out reason)) {
                                string before = "Post-processing (%s)…".printf (reason);
                                item.status_text = before;
                                progress_updated (item, before, 1.0);
                                if (enforce_video_output (outpath, opts, out new_path)) {
                                    // ffmpeg produced new_path (maybe new ext) — update item
                                    if (new_path != outpath) {
                                        item.output_path = new_path;
                                    }
                                } else {
                                    warning ("Enforcement %s failed for %s — keeping original", reason, outpath);
                                }
                            }
                        }
                    }
                }
                // Music mode post-processing: crop cover + content.toml + playlists
                if (opts.is_music_mode) {
                    string outpath = item.output_path.length > 0 ? item.output_path : Velox.MusicLibrary.build_music_output_path (item, opts);
                    // Fallback to actual file if yt-dlp used alternative extension (ogg vs opus)
                    var f = File.new_for_path (outpath);
                    if (!f.query_exists ()) {
                        // Try ogg fallback if opus requested
                        string alt = outpath;
                        if (alt.has_suffix (".opus")) alt = alt.substring (0, alt.length - 5) + ".ogg";
                        else if (alt.has_suffix (".ogg")) alt = alt.substring (0, alt.length - 4) + ".opus";
                        var af = File.new_for_path (alt);
                        if (af.query_exists ()) {
                            outpath = alt;
                            item.output_path = outpath;
                        }
                    }
                    if (opts.music_crop_thumbnail) {
                        try {
                            Velox.MusicLibrary.crop_cover_in_file (outpath);
                        } catch (Error e) {
                            warning ("Cover crop failed for %s: %s", outpath, e.message);
                        }
                    }
                    if (opts.music_use_content_toml) {
                        string mdir = opts.music_directory.length > 0 ? opts.music_directory.replace ("~", Environment.get_home_dir ()) : Environment.get_home_dir () + "/Music";
                        while (mdir.has_suffix ("/")) mdir = mdir.substring (0, mdir.length - 1);
                        try { File.new_for_path (mdir).make_directory_with_parents (); } catch (Error e) {}
                        string rel = Velox.MusicLibrary.rel_path (outpath, mdir);
                        string yid = item.youtube_id.length > 0 ? item.youtube_id : "";
                        // Derive youtube_id from url if missing
                        if (yid.length == 0) {
                            try {
                                var re = new GLib.Regex ("v=([^&]+)|youtu\\.be/([^?&]+)");
                                MatchInfo mi;
                                if (re.match (item.url, 0, out mi)) {
                                    yid = mi.fetch (1);
                                    if (yid == null || yid.length == 0) yid = mi.fetch (2);
                                }
                            } catch (Error e) {}
                        }
                        var entry = MusicTrackEntry ();
                        entry.youtube_id = yid;
                        entry.path = rel;
                        entry.name = item.title.length > 0 ? item.title : "Unknown Title";
                        string artist = item.artist.length > 0 ? item.artist : (item.uploader.length > 0 ? item.uploader : "Unknown Artist");
                        entry.artist = artist;
                        entry.album = item.album.length > 0 ? item.album : "Unknown Album";
                        entry.album_id = item.album_id;
                        string pl = item.playlist_title.length > 0 ? item.playlist_title : (opts.music_playlist_name.length > 0 ? opts.music_playlist_name : "__MUSIC__");
                        entry.playlists = { pl };
                        Velox.MusicLibrary.append_to_content_toml (mdir, entry);
                        if (opts.music_generate_playlists) {
                            var all = Velox.MusicLibrary.load_content_toml (mdir);
                            Velox.MusicLibrary.write_playlists (mdir, all);
                        }
                    }
                }
                item.progress = 1.0;
                item.status_text = "Done";
                progress_updated (item, "Done", 1.0);
                item.update_state (DONE);
                download_complete (item);
            } else {
                item.update_state (ERROR);
                item.error_message = err_builder.str.strip ();
                download_failed (item, item.error_message);
            }
        } catch (Error e) {
            active_procs.remove (item);
            GLib.Source.remove (tick_id);
            item.update_state (ERROR);
            item.error_message = e.message;
            download_failed (item, e.message);
        }
    }

    private async bool drain_stderr (DataInputStream stderr, StringBuilder err_builder) {
        try {
            string? err_line;
            while ((err_line = yield stderr.read_line_async (Priority.DEFAULT)) != null) {
                err_builder.append (err_line);
                err_builder.append_c ('\n');
            }
        } catch (Error e) {
            // Pipe closed / process killed: nothing more to read.
        }
        return true;
    }

    private async void wait_idle () {
        var src = new GLib.TimeoutSource (1);
        src.set_callback (() => { wait_idle.callback (); return false; });
        src.attach (null);
        yield;
    }

    private bool needs_enforcement (string filepath, DownloadOptions opts, out string reason) {
        reason = "";
        string cur_ext = "";
        int dot = filepath.last_index_of (".");
        if (dot >= 0) cur_ext = filepath.substring (dot + 1).down ();
        string req_ext = opts.container.down (); // mp4/mkv/webm
        // Probe codecs
        string cur_vcodec = "";
        string cur_acodec = "";
        try {
            string[] probe_argv = { "ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", filepath };
            var probe = new Subprocess.newv (probe_argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string so, se;
            probe.communicate_utf8 (null, null, out so, out se);
            if (probe.get_successful () && so.length > 0) {
                var parser = new Json.Parser ();
                parser.load_from_data (so);
                var root = parser.get_root ().get_object ();
                if (root.has_member ("streams")) {
                    var arr = root.get_array_member ("streams");
                    for (uint i = 0; i < arr.get_length (); i++) {
                        var obj = arr.get_object_element (i);
                        string type = obj.has_member ("codec_type") ? obj.get_string_member ("codec_type") : "";
                        string cname = obj.has_member ("codec_name") ? obj.get_string_member ("codec_name") : "";
                        if (type == "video" && cur_vcodec.length == 0) cur_vcodec = cname.down ();
                        if (type == "audio" && cur_acodec.length == 0) cur_acodec = cname.down ();
                    }
                }
            }
        } catch (Error e) {}
        bool need = false;
        var parts = new StringBuilder ();
        if (req_ext.length > 0 && cur_ext != req_ext) {
            need = true;
            parts.append (req_ext.up ());
            parts.append (" ");
        }
        // Video codec
        if (opts.video_codec != "Any" && cur_vcodec.length > 0) {
            bool match = false;
            string req = opts.video_codec;
            if (req == "H.264") match = cur_vcodec.contains ("h264") || cur_vcodec.contains ("avc");
            else if (req == "H.265") match = cur_vcodec.contains ("hevc") || cur_vcodec.contains ("h265") || cur_vcodec.contains ("265");
            else if (req == "VP9") match = cur_vcodec == "vp9";
            else if (req == "AV1") match = cur_vcodec.contains ("av1") || cur_vcodec.contains ("av01");
            if (!match) {
                need = true;
                parts.append (req);
                parts.append (" ");
            }
        }
        // Audio codec
        if (opts.audio_codec != "Any" && opts.audio_codec.length > 0 && cur_acodec.length > 0) {
            string expected;
            switch (opts.audio_codec.down ()) {
                case "aac": expected = "aac"; break;
                case "opus": expected = "opus"; break;
                case "mp3": expected = "mp3"; break;
                case "flac": expected = "flac"; break;
                default: expected = ""; break;
            }
            if (expected.length > 0 && cur_acodec != expected) {
                need = true;
                parts.append (opts.audio_codec);
                parts.append (" ");
            }
        }
        reason = parts.str.strip ();
        if (reason.length == 0 && need) reason = "remux";
        return need;
    }

    private bool enforce_video_output (string filepath, DownloadOptions opts, out string new_path) {
        new_path = filepath;
        string cur_ext = "";
        int dot = filepath.last_index_of (".");
        string base_no_ext = filepath;
        if (dot >= 0) {
            cur_ext = filepath.substring (dot + 1).down ();
            base_no_ext = filepath.substring (0, dot);
        }
        string req_ext = opts.container.down ();
        if (req_ext.length == 0) req_ext = cur_ext;
        string out_file = base_no_ext + "." + req_ext;
        // If input already has requested ext and no codec mismatch, we still may need to transcode codecs but keep same path via temp
        // Use temp file
        string tmp = filepath + ".velox.tmp." + req_ext;
        // Probe again for codec decisions
        string cur_vcodec = "";
        string cur_acodec = "";
        try {
            string[] probe_argv = { "ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", filepath };
            var probe = new Subprocess.newv (probe_argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string so, se;
            probe.communicate_utf8 (null, null, out so, out se);
            if (probe.get_successful () && so.length > 0) {
                var parser = new Json.Parser ();
                parser.load_from_data (so);
                var root = parser.get_root ().get_object ();
                if (root.has_member ("streams")) {
                    var arr = root.get_array_member ("streams");
                    for (uint i = 0; i < arr.get_length (); i++) {
                        var obj = arr.get_object_element (i);
                        string type = obj.has_member ("codec_type") ? obj.get_string_member ("codec_type") : "";
                        string cname = obj.has_member ("codec_name") ? obj.get_string_member ("codec_name") : "";
                        if (type == "video" && cur_vcodec.length == 0) cur_vcodec = cname.down ();
                        if (type == "audio" && cur_acodec.length == 0) cur_acodec = cname.down ();
                    }
                }
            }
        } catch (Error e) {}

        // Determine video encoder
        string vcodec_arg = "copy";
        string acodec_arg = "copy";
        string abitrate = "";
        bool need_vtrans = false;
        if (opts.video_codec != "Any" && cur_vcodec.length > 0) {
            string req = opts.video_codec;
            bool match = false;
            string enc = "copy";
            if (req == "H.264") { match = cur_vcodec.contains ("h264") || cur_vcodec.contains ("avc"); enc = "libx264"; }
            else if (req == "H.265") { match = cur_vcodec.contains ("hevc") || cur_vcodec.contains ("h265"); enc = "libx265"; }
            else if (req == "VP9") { match = cur_vcodec == "vp9"; enc = "libvpx-vp9"; }
            else if (req == "AV1") { match = cur_vcodec.contains ("av1") || cur_vcodec.contains ("av01"); enc = "libaom-av1"; }
            if (!match) { vcodec_arg = enc; need_vtrans = true; }
        }
        bool need_atrans = false;
        if (opts.audio_codec != "Any" && opts.audio_codec.length > 0 && cur_acodec.length > 0) {
            string expected; string enc; string br = "";
            switch (opts.audio_codec.down ()) {
                case "aac": expected = "aac"; enc = "aac"; br = "192k"; break;
                case "opus": expected = "opus"; enc = "libopus"; br = "160k"; break;
                case "mp3": expected = "mp3"; enc = "libmp3lame"; br = "192k"; break;
                case "flac": expected = "flac"; enc = "flac"; br = ""; break;
                default: expected = ""; enc = "copy"; break;
            }
            if (expected.length > 0 && cur_acodec != expected) {
                acodec_arg = enc;
                abitrate = br;
                need_atrans = true;
            }
        }
        // If nothing to do but container mismatch (ext differs), we still need remux with copy
        bool need_remux = (cur_ext != req_ext);
        if (!need_vtrans && !need_atrans && !need_remux) {
            new_path = filepath;
            return true;
        }
        var args = new GLib.GenericArray<string> ();
        args.add ("ffmpeg");
        args.add ("-y");
        args.add ("-i");
        args.add (filepath);
        args.add ("-map");
        args.add ("0");
        args.add ("-c:v");
        args.add (vcodec_arg);
        if (vcodec_arg == "libx264") { args.add ("-preset"); args.add ("veryfast"); args.add ("-crf"); args.add ("18"); }
        if (vcodec_arg == "libx265") { args.add ("-preset"); args.add ("veryfast"); args.add ("-crf"); args.add ("24"); }
        if (vcodec_arg == "libvpx-vp9") { args.add ("-b:v"); args.add ("0"); args.add ("-crf"); args.add ("32"); }
        if (vcodec_arg == "libaom-av1") { args.add ("-crf"); args.add ("32"); }
        args.add ("-c:a");
        args.add (acodec_arg);
        if (abitrate.length > 0 && need_atrans) { args.add ("-b:a"); args.add (abitrate); }
        // For webm, ensure compatible codecs
        args.add (tmp);
        string[] argv = new string[args.length];
        for (int i = 0; i < args.length; i++) argv[i] = args[i];
        try {
            var proc = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string so, se;
            proc.communicate_utf8 (null, null, out so, out se);
            if (!proc.get_successful ()) {
                warning ("ffmpeg enforce failed %s → %s (%s/%s): %s", filepath, tmp, vcodec_arg, acodec_arg, se);
                try { File.new_for_path (tmp).delete (); } catch (Error e) {}
                return false;
            }
            var src = File.new_for_path (filepath);
            var dst = File.new_for_path (tmp);
            if (!dst.query_exists ()) return false;
            // If output ext differs, new_path is out_file, else tmp replaces original
            if (cur_ext != req_ext) {
                var outf = File.new_for_path (out_file);
                // If out_file already exists (maybe same as input with different ext side-by-side), remove
                try { outf.delete (); } catch (Error e) {}
                dst.move (outf, FileCopyFlags.OVERWRITE, null, null);
                try { src.delete (); } catch (Error e) {}
                new_path = out_file;
            } else {
                try { src.delete (); } catch (Error e) {}
                dst.move (src, FileCopyFlags.OVERWRITE, null, null);
                new_path = filepath;
            }
            return true;
        } catch (Error e) {
            warning ("ffmpeg enforce spawn failed: %s", e.message);
            try { File.new_for_path (tmp).delete (); } catch (Error e2) {}
            return false;
        }
    }

    private bool transcode_audio_to_codec (string filepath, string requested) {
        string req = requested.down ();
        string expected;
        string encoder;
        string bitrate = "";
        switch (req) {
            case "aac": expected = "aac"; encoder = "aac"; bitrate = "192k"; break;
            case "opus": expected = "opus"; encoder = "libopus"; bitrate = "160k"; break;
            case "mp3": expected = "mp3"; encoder = "libmp3lame"; bitrate = "192k"; break;
            case "flac": expected = "flac"; encoder = "flac"; bitrate = ""; break;
            default: return true;
        }
        // Probe current audio codec via ffprobe
        try {
            string[] probe_argv = { "ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", filepath };
            var probe = new Subprocess.newv (probe_argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string so, se;
            probe.communicate_utf8 (null, null, out so, out se);
            if (probe.get_successful () && so.length > 0) {
                var parser = new Json.Parser ();
                parser.load_from_data (so);
                var root = parser.get_root ().get_object ();
                if (root.has_member ("streams")) {
                    var arr = root.get_array_member ("streams");
                    bool found_audio = false;
                    for (uint i = 0; i < arr.get_length (); i++) {
                        var obj = arr.get_object_element (i);
                        if (obj.has_member ("codec_type") && obj.get_string_member ("codec_type") == "audio") {
                            found_audio = true;
                            string cur = obj.has_member ("codec_name") ? obj.get_string_member ("codec_name") : "";
                            if (cur.down () == expected) {
                                // Already matches — no transcode needed
                                return true;
                            }
                            break;
                        }
                    }
                    if (!found_audio) return true; // nothing to transcode
                }
            }
        } catch (Error e) {
            debug ("ffprobe failed for %s: %s", filepath, e.message);
        }
        // Need transcode — run ffmpeg copy video, re-encode audio
        string ext = "";
        int dot = filepath.last_index_of (".");
        if (dot >= 0) ext = filepath.substring (dot);
        string tmp = filepath + ".tmp" + ext;
        var args = new GLib.GenericArray<string> ();
        args.add ("ffmpeg");
        args.add ("-y");
        args.add ("-i");
        args.add (filepath);
        args.add ("-c:v");
        args.add ("copy");
        args.add ("-c:a");
        args.add (encoder);
        if (bitrate.length > 0) {
            args.add ("-b:a");
            args.add (bitrate);
        }
        // Preserve metadata, avoid mapping issues (keep all streams)
        args.add ("-map");
        args.add ("0");
        args.add (tmp);
        string[] argv = new string[args.length];
        for (int i = 0; i < args.length; i++) argv[i] = args[i];
        try {
            var proc = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            string so, se;
            proc.communicate_utf8 (null, null, out so, out se);
            if (!proc.get_successful ()) {
                warning ("ffmpeg transcode failed (%s → %s): %s", filepath, expected, se);
                try { File.new_for_path (tmp).delete (); } catch (Error e) {}
                return false;
            }
            var src = File.new_for_path (filepath);
            var dst = File.new_for_path (tmp);
            if (!dst.query_exists ()) return false;
            // Replace original atomically
            try { src.delete (); } catch (Error e) {}
            dst.move (src, FileCopyFlags.OVERWRITE, null, null);
            return true;
        } catch (Error e) {
            warning ("ffmpeg spawn failed: %s", e.message);
            try { File.new_for_path (tmp).delete (); } catch (Error e2) {}
            return false;
        }
    }

    public void cancel_download (Velox.DownloadItem item) {
        var proc = active_procs.@get (item);
        if (proc != null) {
            proc.force_exit ();
        }
    }
}
