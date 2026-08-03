public class Velox.DownloadManager : GLib.Object {
    public signal void download_started (Velox.DownloadItem item);
    public signal void download_progress (Velox.DownloadItem item, string status, double progress);
    public signal void download_complete (Velox.DownloadItem item);
    public signal void download_failed (Velox.DownloadItem item, string error);
    public signal void all_complete ();

    public int max_concurrent { get; set; default = 3; }

    private Velox.YtdlpService ytdlp_service;
    private GLib.List<Velox.DownloadItem> queue;
    private int active_count = 0;
    private Velox.DownloadOptions current_options;
    private bool cancelled = false;
    construct {
        ytdlp_service = new Velox.YtdlpService ();
        queue = new GLib.List<Velox.DownloadItem> ();

        ytdlp_service.progress_updated.connect ((item, status, progress) => {
            download_progress (item, status, progress);
        });

        ytdlp_service.download_complete.connect (on_item_complete);
        ytdlp_service.download_failed.connect (on_item_failed);
    }

    public void start (GLib.ListStore items, Velox.DownloadOptions opts) {
        cancelled = false;
        current_options = opts;

        for (uint i = 0; i < items.n_items; i++) {
            var item = (Velox.DownloadItem) items.get_item (i);
            if (item.state == DONE || item.state == DOWNLOADING) continue;
            queue.append (item);
        }

        process_queue ();
    }

    public void cancel_all () {
        cancelled = true;
        foreach (var item in queue) {
            item.update_state (CANCELLED);
        }
        queue = new GLib.List<Velox.DownloadItem> ();
        active_count = 0;
    }

    public void cancel_item (Velox.DownloadItem item) {
        if (item.state == DOWNLOADING) {
            ytdlp_service.cancel_download (item);
            item.update_state (CANCELLED);
            active_count--;
            if (active_count < 0) active_count = 0;
            item.status_text = "Cancelled";
            process_queue ();
        } else {
            queue.remove (item);
            item.status_text = "Cancelled";
        }
    }

    private void process_queue () {
        if (cancelled) {
            return;
        }

        while (active_count < max_concurrent && queue.length () > 0) {
            var item = queue.nth_data (0);
            queue.remove_link (queue.find (item));

            active_count++;
            item.error_message = "";
            item.update_state (DOWNLOADING);
            download_started (item);

            ytdlp_service.download.begin (item, current_options);
        }

        if (queue.length () == 0 && active_count == 0 && !cancelled) {
            all_complete ();
        }
    }

    private void on_item_complete (Velox.DownloadItem item) {
        if (item.state == CANCELLED) {
            return;
        }
        release_slot ();
        download_complete (item);
        process_queue ();
    }

    private void on_item_failed (Velox.DownloadItem item, string error) {
        if (item.state == CANCELLED) {
            return;
        }
        release_slot ();
        download_failed (item, error);
        process_queue ();
    }

    private void release_slot () {
        active_count--;
        if (active_count < 0) active_count = 0;
    }
}
