public class Velox.DownloadItem : GLib.Object {
    public string url { get; set; }
    public string title { get; set; default = ""; }
    public string uploader { get; set; default = ""; }
    public int64 duration { get; set; default = 0; }
    public string thumbnail_url { get; set; default = ""; }
    public DownloadState state { get; set; default = QUEUED; }
    public double progress { get; set; default = 0; }
    public string status_text { get; set; default = "Queued"; }
    public string output_path { get; set; default = ""; }
    public string error_message { get; set; default = ""; }
    public int retry_count { get; set; default = 0; }
    public int max_retries { get; set; default = 3; }

    public DownloadItem (string url) {
        Object (url: url);
    }

    public string get_duration_string () {
        if (duration <= 0) return "";
        int hours = (int) (duration / 3600);
        int minutes = (int) ((duration % 3600) / 60);
        int seconds = (int) (duration % 60);
        if (hours > 0) {
            return "%d:%02d:%02d".printf (hours, minutes, seconds);
        }
        return "%d:%02d".printf (minutes, seconds);
    }

    public void update_state (DownloadState new_state) {
        state = new_state;
        status_text = new_state.to_string ();
    }
}
