public enum Velox.DownloadState {
    QUEUED,
    FETCHING,
    DOWNLOADING,
    MERGING,
    POST_PROCESSING,
    DONE,
    ERROR,
    CANCELLED;

    public string to_string () {
        switch (this) {
            case QUEUED: return "Queued";
            case FETCHING: return "Fetching info...";
            case DOWNLOADING: return "Downloading";
            case MERGING: return "Merging";
            case POST_PROCESSING: return "Post-processing";
            case DONE: return "Done";
            case ERROR: return "Error";
            case CANCELLED: return "Cancelled";
            default: return "Unknown";
        }
    }
}
