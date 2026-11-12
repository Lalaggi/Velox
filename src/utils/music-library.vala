public struct Velox.MusicTrackEntry {
    public string youtube_id;
    public string path;
    public string name;
    public string artist;
    public string album;
    public string album_id;
    public string[] playlists;
}

public class Velox.MusicLibrary : GLib.Object {
    // Port of ytm-sync sanitize / normalize_album / song_key
    private static GLib.Regex edition_regex = null;

    private static void ensure_regex () {
        if (edition_regex == null) {
            try {
                edition_regex = new GLib.Regex ("\\s*\\([^)]*\\b[Dd]eluxe\\b[^)]*\\)", GLib.RegexCompileFlags.CASELESS);
            } catch (Error e) {}
        }
    }

    public static string sanitize (string name) {
        if (name == null) return "_";
        // Replace unsafe chars: alnum, unicode >=128, or in ",. -_'!()&+#:;?/"
        var sb = new StringBuilder ();
        for (int i = 0; i < name.length; ) {
            unichar c = name.get_char (i);
            int clen = c.to_utf8 (null);
            string char_str = name.substring (i, clen);
            bool ok = false;
            if (c.isalnum ()) ok = true;
            else if (c >= 128) ok = true;
            else {
                string safe = ",. -_'!()&+#:;?";
                if (safe.contains (char_str)) ok = true;
            }
            if (ok) sb.append (char_str);
            else sb.append ("_");
            i += clen;
        }
        string raw = sb.str.strip ();
        raw = raw.strip ();
        while (raw.has_prefix ("_") || raw.has_suffix ("_")) {
            if (raw.has_prefix ("_")) raw = raw.substring (1);
            if (raw.has_suffix ("_")) raw = raw.substring (0, raw.length - 1);
            raw = raw.strip ();
            if (raw.length == 0) break;
        }
        if (raw.length == 0 || raw == "." || raw == "..") return "_";
        if (raw.has_prefix (".") && raw.length > 0) {
            bool all_dots = true;
            for (int i = 0; i < raw.length; i++) {
                if (raw[i] != '.') { all_dots = false; break; }
            }
            if (all_dots) return "_";
        }
        return raw.length > 0 ? raw : "_";
    }

    public static string normalize_album (string name) {
        if (name == null || name.length == 0) return "";
        ensure_regex ();
        string res = name;
        if (edition_regex != null) {
            try { res = edition_regex.replace (name, -1, 0, ""); } catch (Error e) {}
        }
        res = res.strip ();
        return res.length > 0 ? res : name;
    }

    public static string song_key (string artist, string title) {
        return "%s - %s".printf (sanitize (artist).down (), sanitize (title).down ());
    }

    public static string rel_path (string full_path, string music_dir) {
        string m = music_dir;
        if (m.has_suffix ("/")) m = m.substring (0, m.length - 1);
        if (full_path.has_prefix (m + "/")) {
            return full_path.substring (m.length + 1);
        }
        return full_path;
    }

    public static string expand_path (string p, string music_dir) {
        if (p.has_prefix ("~/")) {
            return p.replace ("~", Environment.get_home_dir ());
        }
        if (p.has_prefix ("/")) return p;
        string m = music_dir;
        if (m.has_suffix ("/")) m = m.substring (0, m.length - 1);
        if (p.length == 0) return m;
        return m + "/" + p;
    }

    public static string build_music_output_path (Velox.DownloadItem item, Velox.DownloadOptions opts) {
        // Resolve music dir
        string mdir = opts.music_directory.length > 0 ? opts.music_directory.replace ("~", Environment.get_home_dir ()) : Environment.get_home_dir () + "/Music";
        while (mdir.has_suffix ("/")) mdir = mdir.substring (0, mdir.length - 1);

        // Determine artist/album/title from fetched info, fallback to uploader/title
        string artist = item.artist.length > 0 ? item.artist : (item.uploader.length > 0 ? item.uploader : "Unknown Artist");
        string album = item.album.length > 0 ? normalize_album (item.album) : "Unknown Album";
        string title = item.title.length > 0 ? item.title : "Unknown Title";

        string safe_artist = sanitize (artist);
        string safe_album = sanitize (album);
        string safe_title = sanitize (title);

        string filename = "%s - %s".printf (safe_artist, safe_title);
        string ext = opts.music_audio_format.length > 0 ? opts.music_audio_format : "opus";
        // Map m4a/mp3 container oddities
        if (ext == "m4a") ext = "m4a";
        if (ext == "opus") ext = "ogg";

        string rel;
        switch (opts.music_organization) {
            case "flat":
                rel = "%s.%s".printf (filename, ext);
                break;
            case "artist":
                rel = "%s/%s.%s".printf (safe_artist, filename, ext);
                break;
            default: // artist-album
                rel = "%s/%s/%s.%s".printf (safe_artist, safe_album, filename, ext);
                break;
        }
        return mdir + "/" + rel;
    }

    // TOML helpers - ytm-sync compatible
    private static string toml_escape (string s) {
        return s.replace ("\\", "\\\\").replace ("\"", "\\\"").replace ("\n", "\\n");
    }
    private static string toml_unescape (string s) {
        return s.replace ("\\n", "\n").replace ("\\\"", "\"").replace ("\\\\", "\\");
    }

    public static GLib.List<MusicTrackEntry?> load_content_toml (string music_dir_expanded) {
        var list = new GLib.List<MusicTrackEntry?> ();
        string path = music_dir_expanded.has_suffix ("/") ? music_dir_expanded.substring (0, music_dir_expanded.length - 1) + "/content.toml" : music_dir_expanded + "/content.toml";
        var f = File.new_for_path (path);
        if (!f.query_exists ()) return list;
        try {
            uint8[] contents;
            string etag;
            f.load_contents (null, out contents, out etag);
            string text = (string) contents;
            var lines = text.split ("\n");
            MusicTrackEntry? cur = null;
            bool in_tracks = false;
            foreach (var raw in lines) {
                string line = raw.strip ();
                if (line.length == 0 || line.has_prefix ("#")) continue;
                if (line == "[[tracks]]") {
                    if (cur != null) {
                        list.append (cur);
                    }
                    cur = MusicTrackEntry ();
                    cur.playlists = {};
                    in_tracks = true;
                    continue;
                }
                if (!in_tracks || cur == null) continue;
                int eq = line.index_of ("=");
                if (eq < 0) continue;
                string key = line.substring (0, eq).strip ();
                string val = line.substring (eq + 1).strip ();
                if (val.has_prefix ("\"") && val.has_suffix ("\"")) {
                    string inner = val.substring (1, val.length - 2);
                    string unesc = toml_unescape (inner);
                    switch (key) {
                        case "youtube_id": cur.youtube_id = unesc; break;
                        case "path": cur.path = unesc; break;
                        case "name": cur.name = unesc; break;
                        case "artist": cur.artist = unesc; break;
                        case "album": cur.album = unesc; break;
                        case "album_id": cur.album_id = unesc; break;
                    }
                } else if (val.has_prefix ("[")) {
                    // playlists = ["a", "b"]
                    var pls = new GLib.GenericArray<string> ();
                    try {
                        var re = new GLib.Regex ("\"([^\"]*)\"");
                        MatchInfo mi;
                        if (re.match (val, 0, out mi)) {
                            do {
                                pls.add (toml_unescape (mi.fetch (1)));
                            } while (mi.next ());
                        }
                    } catch (Error e) {}
                    cur.playlists = new string[pls.length];
                    for (int i = 0; i < pls.length; i++) cur.playlists[i] = pls[i];
                }
            }
            if (cur != null) {
                // Only append if it had at least youtube_id or path
                if ((cur.youtube_id != null && cur.youtube_id.length > 0) || (cur.path != null && cur.path.length > 0)) {
                    list.append (cur);
                }
            }
        } catch (Error e) {
            warning ("Failed to load content.toml: %s", e.message);
        }
        return list;
    }

    public static void append_to_content_toml (string music_dir_expanded, MusicTrackEntry entry) {
        // Check duplicate by path or youtube_id
        var existing = load_content_toml (music_dir_expanded);
        foreach (var e in existing) {
            if (e == null) continue;
            if (e.youtube_id == entry.youtube_id && e.youtube_id.length > 0) return;
            if (e.path == entry.path && e.path.length > 0) {
                // Merge playlists into existing entry instead of duplicate
                string[] merged = merge_playlists (e.playlists, entry.playlists);
                update_playlists_in_toml (music_dir_expanded, e.path, merged);
                return;
            }
        }
        string path = music_dir_expanded.has_suffix ("/") ? music_dir_expanded.substring (0, music_dir_expanded.length - 1) + "/content.toml" : music_dir_expanded + "/content.toml";
        var f = File.new_for_path (path);
        bool exists = f.query_exists ();
        try {
            var stream = f.append_to (FileCreateFlags.NONE, null);
            if (!exists) {
                string header = "# YTM-Sync Content Library - managed by Velox music mode\n# ytm-sync compatible\n\n";
                stream.write (header.data);
            }
            var sb = new StringBuilder ();
            sb.append ("[[tracks]]\n");
            sb.append ("youtube_id = \"%s\"\n".printf (toml_escape (entry.youtube_id)));
            sb.append ("path = \"%s\"\n".printf (toml_escape (entry.path)));
            sb.append ("name = \"%s\"\n".printf (toml_escape (entry.name)));
            sb.append ("artist = \"%s\"\n".printf (toml_escape (entry.artist)));
            sb.append ("album = \"%s\"\n".printf (toml_escape (entry.album)));
            sb.append ("album_id = \"%s\"\n".printf (toml_escape (entry.album_id)));
            sb.append ("playlists = [");
            for (int i = 0; i < entry.playlists.length; i++) {
                sb.append ("\"%s\"".printf (toml_escape (entry.playlists[i])));
                if (i + 1 < entry.playlists.length) sb.append (", ");
            }
            sb.append ("]\n\n");
            stream.write (sb.str.data);
            stream.close ();
        } catch (Error e) {
            warning ("Failed to append content.toml: %s", e.message);
        }
    }

    private static string[] merge_playlists (string[] a, string[] b) {
        var set = new GLib.HashTable<string, bool> (str_hash, str_equal);
        var res = new GLib.GenericArray<string> ();
        foreach (var s in a) { if (s.length>0 && !set.contains (s)) { set.insert (s,true); res.add (s); } }
        foreach (var s in b) { if (s.length>0 && !set.contains (s)) { set.insert (s,true); res.add (s); } }
        string[] out = new string[res.length];
        for (int i=0;i<res.length;i++) out[i]=res[i];
        return out;
    }

    private static void update_playlists_in_toml (string music_dir_expanded, string target_path, string[] new_playlists) {
        // Simple rewrite: load all, update matching, rewrite file
        var all = load_content_toml (music_dir_expanded);
        bool found = false;
        foreach (var e in all) {
            if (e != null && e.path == target_path) { e.playlists = new_playlists; found = true; }
        }
        if (!found) return;
        string path = music_dir_expanded.has_suffix ("/") ? music_dir_expanded.substring (0, music_dir_expanded.length - 1) + "/content.toml" : music_dir_expanded + "/content.toml";
        var f = File.new_for_path (path);
        try {
            var stream = f.replace (null, false, FileCreateFlags.NONE, null);
            string header = "# YTM-Sync Content Library - managed by Velox music mode\n# ytm-sync compatible\n\n";
            stream.write (header.data);
            foreach (var e in all) {
                if (e == null) continue;
                var sb = new StringBuilder ();
                sb.append ("[[tracks]]\n");
                sb.append ("youtube_id = \"%s\"\n".printf (toml_escape (e.youtube_id)));
                sb.append ("path = \"%s\"\n".printf (toml_escape (e.path)));
                sb.append ("name = \"%s\"\n".printf (toml_escape (e.name)));
                sb.append ("artist = \"%s\"\n".printf (toml_escape (e.artist)));
                sb.append ("album = \"%s\"\n".printf (toml_escape (e.album)));
                sb.append ("album_id = \"%s\"\n".printf (toml_escape (e.album_id)));
                sb.append ("playlists = [");
                for (int i = 0; i < e.playlists.length; i++) {
                    sb.append ("\"%s\"".printf (toml_escape (e.playlists[i])));
                    if (i+1 < e.playlists.length) sb.append (", ");
                }
                sb.append ("]\n\n");
                stream.write (sb.str.data);
            }
            stream.close ();
        } catch (Error e) {
            warning ("Failed to rewrite content.toml: %s", e.message);
        }
    }

    public static void write_playlists (string music_dir_expanded, GLib.List<MusicTrackEntry?> tracks) {
        var playlists = new GLib.HashTable<string, GLib.GenericArray<string>> (str_hash, str_equal);
        foreach (var t in tracks) {
            if (t == null || t.path.length == 0) continue;
            foreach (var pl in t.playlists) {
                if (pl.length == 0 || pl == "__GET__") continue;
                var arr = playlists.lookup (pl);
                if (arr == null) {
                    arr = new GLib.GenericArray<string> ();
                    playlists.insert (pl, arr);
                }
                // Expand path and check exists
                string full = expand_path (t.path, music_dir_expanded);
                var f = File.new_for_path (full);
                if (!f.query_exists ()) continue;
                // dedupe
                bool exists = false;
                for (int i=0;i<arr.length;i++) if (arr[i]==full) { exists=true; break; }
                if (!exists) arr.add (full);
            }
        }
        var keys = playlists.get_keys ();
        foreach (var pl in keys) {
            var arr = playlists.lookup (pl);
            if (arr.length == 0) continue;
            string safe_pl = sanitize (pl);
            string pl_dir = music_dir_expanded.has_suffix ("/") ? music_dir_expanded.substring (0, music_dir_expanded.length - 1) + "/" + safe_pl : music_dir_expanded + "/" + safe_pl;
            var dir_f = File.new_for_path (pl_dir);
            try { dir_f.make_directory_with_parents (); } catch (Error e) {}
            string m3u = pl_dir + "/" + safe_pl + ".m3u8";
            var mf = File.new_for_path (m3u);
            try {
                var out = mf.replace (null, false, FileCreateFlags.NONE, null);
                out.write ("#EXTM3U\n".data);
                // sort
                var sorted = new GLib.GenericArray<string> ();
                for (int i=0;i<arr.length;i++) sorted.add (arr[i]);
                sorted.sort ((a,b) => strcmp (a,b));
                for (int i=0;i<sorted.length;i++) {
                    string rel = Path.get_dirname (m3u) != null ? File.new_for_path (sorted[i]).get_relative_path (dir_f) : sorted[i];
                    // fallback to os path rel: use relative to pl_dir via manual
                    // Use GLib path relative via string: if pl_dir prefix, strip
                    if (rel == null) {
                        string full = sorted[i];
                        if (full.has_prefix (pl_dir + "/")) rel = full.substring (pl_dir.length + 1);
                        else rel = full;
                    }
                    // If still absolute, compute via .. steps
                    if (rel.has_prefix ("/")) {
                        rel = "../" + rel; // simple fallback - m3u player will still try
                    }
                    out.write ((rel + "\n").data);
                }
                out.close ();
                print ("Written %s (%u tracks)\n", m3u, arr.length);
            } catch (Error e) {
                warning ("Failed to write m3u %s: %s", m3u, e.message);
            }
        }
    }

    public static bool crop_cover_in_file (string filepath) {
        // Use GdkPixbuf to center-crop embedded cover extracted via ffmpeg, then re-embed?
        // MVP: Use ffmpeg + gdk-pixbuf pipeline: extract cover to temp, crop, re-embed with ffmpeg.
        // For opus/ogg we can round-trip via GdkPixbuf.
        try {
            string ext = "";
            int dot = filepath.last_index_of (".");
            if (dot >= 0) ext = filepath.substring (dot).down ();
            if (ext != ".ogg" && ext != ".opus" && ext != ".m4a" && ext != ".mp3" && ext != ".flac") return false;
            // Extract cover art to temp jpeg using ffmpeg
            string cover_tmp = filepath + ".__cover.jpg";
            string[] args_extract = { "ffmpeg", "-y", "-i", filepath, "-an", "-vcodec", "copy", cover_tmp };
            int es; string so, se;
            try {
                GLib.Process.spawn_sync (null, args_extract, null, GLib.SpawnFlags.SEARCH_PATH, null, out so, out se, out es);
            } catch (Error e) { return false; }
            var cf = File.new_for_path (cover_tmp);
            if (!cf.query_exists ()) return false;
            // Load via GdkPixbuf
            Gdk.Pixbuf pix;
            try {
                pix = new Gdk.Pixbuf.from_file (cover_tmp);
            } catch (Error e) {
                cf.delete ();
                return false;
            }
            int w = pix.width, h = pix.height;
            if (w == h) { cf.delete (); return false; }
            int size = int.min (w, h);
            int x = (w - size) / 2;
            int y = (h - size) / 2;
            var cropped = new Gdk.Pixbuf.subpixbuf (pix, x, y, size, size);
            try {
                cropped.save (cover_tmp, "jpeg", "quality", "92");
            } catch (Error e) {
                cf.delete ();
                return false;
            }
            // Re-embed via ffmpeg: create temp output then replace
            string fixed = filepath + ".__fixed" + ext;
            // For opus/ogg we need to re-encode? Use ffmpeg to attach cover as metadata_block_picture for opus or as video stream for mp3?
            // Simplest: use ffmpeg to copy audio and attach new cover
            string[] args_embed;
            if (ext == ".mp3") {
                args_embed = { "ffmpeg", "-y", "-i", filepath, "-i", cover_tmp, "-map", "0", "-map", "1", "-c", "copy", "-id3v2_version", "3", "-metadata:s:v", "title=\"Album cover\"", "-metadata:s:v", "comment=\"Cover (front)\"", fixed };
            } else {
                // opus/ogg/flac/m4a: use ffmpeg with attached_pic
                args_embed = { "ffmpeg", "-y", "-i", filepath, "-i", cover_tmp, "-map", "0", "-map", "1", "-c", "copy", "-disposition:v", "attached_pic", fixed };
            }
            try {
                GLib.Process.spawn_sync (null, args_embed, null, GLib.SpawnFlags.SEARCH_PATH, null, out so, out se, out es);
            } catch (Error e) {}
            cf.delete ();
            var fixed_f = File.new_for_path (fixed);
            if (fixed_f.query_exists () && es == 0) {
                var orig = File.new_for_path (filepath);
                try { orig.delete (); } catch (Error e) {}
                try { fixed_f.move (orig, FileCopyFlags.OVERWRITE, null, null); } catch (Error e) { fixed_f.delete (); return false; }
                return true;
            } else {
                if (fixed_f.query_exists ()) try { fixed_f.delete (); } catch (Error e) {}
                return false;
            }
        } catch (Error e) {
            warning ("crop_cover_in_file failed: %s", e.message);
            return false;
        }
    }
}
