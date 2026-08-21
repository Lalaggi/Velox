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
                "--no-playlist",
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
            if (root.has_member ("duration")) {
                item.duration = root.get_int_member ("duration");
            }
            if (root.has_member ("thumbnail")) {
                item.thumbnail_url = root.get_string_member ("thumbnail");
            }

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

        // Format selection
        if (opts.is_audio_only) {
            args.add ("-x");
            args.add ("--audio-format");
            args.add (opts.audio_container);

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
        if (opts.embed_metadata) {
            args.add ("--embed-metadata");
        }
        if (opts.embed_thumbnail) {
            args.add ("--embed-thumbnail");
        }
        if (opts.embed_chapters) {
            args.add ("--embed-chapters");
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

        // Output template
        string output_dir = opts.output_directory.length > 0
            ? opts.output_directory.replace ("~", Environment.get_home_dir ())
            : Environment.get_home_dir ();
        // Strip trailing slashes, then add exactly one
        while (output_dir.has_suffix ("/")) {
            output_dir = output_dir.substring (0, output_dir.length - 1);
        }
        string template = opts.output_template.length > 0
            ? opts.output_template
            : "%(title)s.%(ext)s";
        args.add ("-o");
        args.add (output_dir + "/" + template);

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

        string height_part = height_filter.length > 0
            ? "[height<=%s]".printf (height_filter)
            : "";

        if (codec_part.length > 0 || height_part.length > 0) {
            return "bestvideo*%s%s+ba/b" .printf (height_part, codec_part);
        }
        return "bestvideo+ba/b";
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

            if (proc.get_successful ()) {
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

    public void cancel_download (Velox.DownloadItem item) {
        var proc = active_procs.@get (item);
        if (proc != null) {
            proc.force_exit ();
        }
    }
}
