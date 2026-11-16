// Async, cached thumbnail loader for download rows.
//
// Uses libsoup for HTTP(S) (GIO's file API needs the optional gvfs http
// backend, which isn't guaranteed inside the Flatpak sandbox) and decodes
// with GdkPixbuf at a small size so we never hold full-resolution textures.
public class Velox.ThumbnailLoader : GLib.Object {
    public delegate void Callback (Gdk.Texture? texture);

    private const int THUMB_WIDTH = 128;
    private const int THUMB_HEIGHT = 72;
    private const uint MAX_CONCURRENT = 4;

    private class PendingRequest : GLib.Object {
        public string url;
        public Callback callback;

        public PendingRequest (string url, Callback callback) {
            this.url = url;
            this.callback = callback;
        }
    }

    private static GLib.HashTable<string, Gdk.Texture?> cache;
    private static GLib.GenericArray<PendingRequest> pending;
    private static Soup.Session? session;
    private static uint active = 0;

    static construct {
        cache = new GLib.HashTable<string, Gdk.Texture?> (str_hash, str_equal);
        pending = new GLib.GenericArray<PendingRequest> ();
    }

    public static void load (string url, Callback callback) {
        if (url.length == 0) {
            callback (null);
            return;
        }

        var cached = cache.lookup (url);
        if (cached != null) {
            callback (cached);
            return;
        }

        pending.add (new PendingRequest (url, callback));
        pump ();
    }

    private static void pump () {
        while (active < MAX_CONCURRENT && pending.length > 0) {
            var request = pending[0];
            pending.remove_index (0);
            active++;
            fetch (request);
        }
    }

    private static void fetch (PendingRequest request) {
        if (session == null) {
            session = new Soup.Session ();
            session.user_agent = "Velox";
            session.timeout = 15;
        }

        var msg = new Soup.Message ("GET", request.url);
        session.send_and_read_async.begin (msg, GLib.Priority.DEFAULT, null, (obj, res) => {
            Gdk.Texture? texture = null;
            try {
                var bytes = session.send_and_read_async.end (res);
                if (bytes != null && bytes.get_size () > 0) {
                    texture = decode (bytes);
                }
            } catch (Error e) {
                debug ("Could not fetch thumbnail %s: %s", request.url, e.message);
            }

            if (texture != null) {
                // Bound the in-memory cache; displayed rows keep their own refs.
                if (cache.size () >= 512) cache.remove_all ();
                cache.insert (request.url, texture);
            }
            request.callback (texture);

            active--;
            pump ();
        });
    }

    private static Gdk.Texture? decode (GLib.Bytes bytes) {
        try {
            var stream = new GLib.MemoryInputStream.from_bytes (bytes);
            var pixbuf = new Gdk.Pixbuf.from_stream_at_scale (
                stream, THUMB_WIDTH, THUMB_HEIGHT, true
            );
            return Gdk.Texture.for_pixbuf (pixbuf);
        } catch (Error e) {
            debug ("Could not decode thumbnail: %s", e.message);
            return null;
        }
    }
}
