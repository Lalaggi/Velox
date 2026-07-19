public class Velox.ProgressParser {
    public double progress { get; private set; default = 0; }
    public string speed { get; private set; default = ""; }
    public string eta { get; private set; default = ""; }
    public string destination { get; private set; default = ""; }
    public string phase { get; private set; default = ""; }

    private static Regex progress_regex;
    private static Regex speed_regex;
    private static Regex eta_regex;

    static construct {
        try {
            progress_regex = new Regex ("""(\d+\.?\d*)%""");
            speed_regex = new Regex ("""at\s+([\d.]+\S+/s)""");
            eta_regex = new Regex ("""ETA\s+(\S+)""");
        } catch (Error e) {
            critical ("Failed to compile progress regexes: %s", e.message);
        }
    }

    public bool parse_line (string line) {
        bool updated = false;
        MatchInfo mi;

        if (line.contains ("[download]")) {
            phase = "download";

            if (progress_regex.match (line, 0, out mi)) {
                progress = double.parse (mi.fetch (1)) / 100.0;
                updated = true;
            }
            if (speed_regex.match (line, 0, out mi)) {
                speed = mi.fetch (1);
                updated = true;
            }
            if (eta_regex.match (line, 0, out mi)) {
                eta = mi.fetch (1);
                updated = true;
            }
        } else if (line.contains ("[Merger]")) {
            phase = "merge";
            destination = line;
            updated = true;
        } else if (line.contains ("[ExtractAudio]")) {
            phase = "extract_audio";
            updated = true;
        } else if (line.contains ("[Metadata]")) {
            phase = "metadata";
            updated = true;
        } else if (line.contains ("[EmbedSubtitle]")) {
            phase = "embed_subtitles";
            updated = true;
        } else if (line.contains ("[EmbedThumbnail]")) {
            phase = "embed_thumbnail";
            updated = true;
        } else if (line.contains ("[SponsorBlock]")) {
            phase = "sponsorblock";
            updated = true;
        } else if (line.has_prefix ("[download] Destination:")) {
            destination = line.substring ("[download] Destination:".length).strip ();
            updated = true;
        } else if (line.contains ("Destination:")) {
            destination = line;
            updated = true;
        } else if (line.contains ("has already been downloaded")) {
            phase = "already_downloaded";
            updated = true;
        } else if (line.contains ("ERROR")) {
            phase = "error";
            updated = true;
        }

        return updated;
    }

    public string get_status_text () {
        if (phase == "error") return "Error";
        if (phase == "merge") return "Merging...";
        if (phase == "extract_audio") return "Extracting audio...";
        if (phase == "metadata") return "Writing metadata...";
        if (phase == "embed_subtitles") return "Embedding subtitles...";
        if (phase == "embed_thumbnail") return "Embedding thumbnail...";
        if (phase == "sponsorblock") return "Processing SponsorBlock...";
        if (phase == "already_downloaded") return "Already downloaded";
        if (phase == "download") {
            string text = "%.1f%%".printf (progress * 100);
            if (speed.length > 0) text += " at %s".printf (speed);
            if (eta.length > 0) text += " ETA %s".printf (eta);
            return text;
        }
        return "Processing...";
    }
}
