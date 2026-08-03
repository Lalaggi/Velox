public class Velox.OptionsPageBuilder : GLib.Object {
    public Gtk.DropDown type_dropdown { get; private set; }
    public Gtk.DropDown codec_dropdown { get; private set; }
    public Gtk.DropDown quality_dropdown { get; private set; }
    public Gtk.DropDown container_dropdown { get; private set; }
    public Gtk.DropDown audio_codec_dropdown { get; private set; }
    public Gtk.CheckButton meta_check { get; private set; }
    public Gtk.CheckButton thumb_check { get; private set; }
    public Gtk.CheckButton chapters_check { get; private set; }
    public Gtk.CheckButton subs_check { get; private set; }
    public Gtk.CheckButton auto_subs_check { get; private set; }
    public Gtk.CheckButton save_subs_srt_check { get; private set; }
    public Gtk.Entry langs_entry { get; private set; }
    public Gtk.CheckButton sb_enable { get; private set; }
    public Gtk.CheckButton sb_remove_radio { get; private set; }
    public Gtk.CheckButton sb_mark_radio { get; private set; }
    public Gtk.FlowBox sb_cats_box { get; private set; }
    public Gtk.Entry adv_entry { get; private set; }

    public Adw.ToolbarView build (out Gtk.Button start_button) {
        var toolbar_view = new Adw.ToolbarView ();

        var header = new Adw.HeaderBar ();
        header.show_title = false;

        start_button = new Gtk.Button ();
        start_button.label = "Start";
        start_button.add_css_class ("suggested-action");
        header.pack_end (start_button);

        toolbar_view.add_top_bar (header);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        content_box.margin_start = 12;
        content_box.margin_end = 12;
        content_box.margin_top = 12;
        content_box.margin_bottom = 12;

        // Type row
        var type_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        type_row.valign = Gtk.Align.CENTER;

        var type_label = new Gtk.Label ("Type:");
        type_label.width_chars = 6;
        type_label.xalign = 0;
        type_row.append (type_label);

        type_dropdown = new Gtk.DropDown.from_strings ({ "Video", "Audio Only" });
        type_dropdown.valign = Gtk.Align.CENTER;
        type_row.append (type_dropdown);

        content_box.append (type_row);

        // Format grid
        var format_grid = new Gtk.Grid ();
        format_grid.column_spacing = 12;
        format_grid.row_spacing = 6;

        var codec_label = new Gtk.Label ("Codec:");
        codec_label.xalign = 1;
        format_grid.attach (codec_label, 0, 0);

        codec_dropdown = new Gtk.DropDown.from_strings ({
            "H.264", "H.265", "VP9", "AV1", "Any"
        });
        format_grid.attach (codec_dropdown, 1, 0);

        var quality_label = new Gtk.Label ("Quality:");
        quality_label.xalign = 1;
        format_grid.attach (quality_label, 2, 0);

        quality_dropdown = new Gtk.DropDown.from_strings ({
            "Best", "2160p", "1080p", "720p", "480p", "360p", "Worst"
        });
        format_grid.attach (quality_dropdown, 3, 0);

        var container_label = new Gtk.Label ("Container:");
        container_label.xalign = 1;
        format_grid.attach (container_label, 0, 1);

        container_dropdown = new Gtk.DropDown.from_strings ({
            "MP4", "MKV", "WebM"
        });
        format_grid.attach (container_dropdown, 1, 1);

        var audio_codec_label = new Gtk.Label ("Audio:");
        audio_codec_label.xalign = 1;
        format_grid.attach (audio_codec_label, 2, 1);

        audio_codec_dropdown = new Gtk.DropDown.from_strings ({
            "AAC", "Opus", "MP3", "FLAC", "Any"
        });
        format_grid.attach (audio_codec_dropdown, 3, 1);

        content_box.append (format_grid);
        content_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

        // Metadata and Subtitles
        var metadata_expander = new Adw.ExpanderRow ();
        metadata_expander.title = "Metadata and Subtitles";
        metadata_expander.subtitle = "Embed metadata, thumbnails, and subtitles";

        var meta_grid = new Gtk.Grid ();
        meta_grid.column_spacing = 12;
        meta_grid.row_spacing = 6;
        meta_grid.margin_top = 6;
        meta_grid.margin_bottom = 6;

        meta_check = new Gtk.CheckButton.with_label ("Metadata");
        meta_grid.attach (meta_check, 0, 0);

        thumb_check = new Gtk.CheckButton.with_label ("Thumbnail");
        meta_grid.attach (thumb_check, 1, 0);

        chapters_check = new Gtk.CheckButton.with_label ("Chapters");
        meta_grid.attach (chapters_check, 2, 0);

        subs_check = new Gtk.CheckButton.with_label ("Subtitles");
        meta_grid.attach (subs_check, 0, 1);

        auto_subs_check = new Gtk.CheckButton.with_label ("Auto-subs");
        meta_grid.attach (auto_subs_check, 1, 1);

        save_subs_srt_check = new Gtk.CheckButton.with_label (".srt only");
        save_subs_srt_check.tooltip_text = "Save subtitles as .srt files without embedding";
        meta_grid.attach (save_subs_srt_check, 2, 1);

        langs_entry = new Gtk.Entry ();
        langs_entry.placeholder_text = "en";
        langs_entry.width_chars = 8;
        langs_entry.valign = Gtk.Align.CENTER;
        var langs_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        langs_box.append (new Gtk.Label ("Langs:"));
        langs_box.append (langs_entry);
        meta_grid.attach (langs_box, 0, 2, 2, 1);

        metadata_expander.add_row (meta_grid);
        content_box.append (metadata_expander);

        // SponsorBlock
        var sb_expander = new Adw.ExpanderRow ();
        sb_expander.title = "SponsorBlock";
        sb_expander.subtitle = "Remove or mark sponsored segments";

        var sb_inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        sb_inner.margin_top = 6;
        sb_inner.margin_bottom = 6;

        sb_enable = new Gtk.CheckButton.with_label ("Enable SponsorBlock");
        sb_inner.append (sb_enable);

        var sb_action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        sb_action_box.margin_start = 24;
        sb_remove_radio = new Gtk.CheckButton.with_label ("Remove");
        sb_remove_radio.active = true;
        sb_mark_radio = new Gtk.CheckButton.with_label ("Mark as chapters");
        sb_remove_radio.group = sb_mark_radio;
        sb_action_box.append (sb_remove_radio);
        sb_action_box.append (sb_mark_radio);
        sb_inner.append (sb_action_box);

        sb_cats_box = new Gtk.FlowBox ();
        sb_cats_box.orientation = Gtk.Orientation.HORIZONTAL;
        sb_cats_box.column_spacing = 8;
        sb_cats_box.row_spacing = 4;
        sb_cats_box.margin_start = 24;
        sb_cats_box.selection_mode = Gtk.SelectionMode.NONE;
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Sponsor"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Intro"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Outro"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Self-promo"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Preview"));
        sb_cats_box.append (new Gtk.CheckButton.with_label ("Filler"));
        sb_inner.append (sb_cats_box);

        sb_expander.add_row (sb_inner);
        content_box.append (sb_expander);

        // Advanced
        var adv_expander = new Adw.ExpanderRow ();
        adv_expander.title = "Advanced";
        adv_expander.subtitle = "Custom yt-dlp arguments";

        adv_entry = new Gtk.Entry ();
        adv_entry.placeholder_text = "e.g. --split-chapters --force-keyframes-at-cuts";
        adv_entry.hexpand = true;
        adv_entry.margin_top = 6;
        adv_entry.margin_bottom = 6;
        adv_entry.margin_start = 12;
        adv_entry.margin_end = 12;
        adv_expander.add_row (adv_entry);

        content_box.append (adv_expander);

        scrolled.child = content_box;
        toolbar_view.content = scrolled;

        return toolbar_view;
    }

    public void sync_from_options (Velox.DownloadOptions opts) {
        type_dropdown.set_selected (opts.is_audio_only ? 1 : 0);

        codec_dropdown.set_selected (dropdown_index_of (codec_dropdown, opts.video_codec));
        quality_dropdown.set_selected (dropdown_index_of (quality_dropdown, opts.video_quality));
        container_dropdown.set_selected (dropdown_index_of (container_dropdown, opts.container));
        audio_codec_dropdown.set_selected (dropdown_index_of (audio_codec_dropdown, opts.audio_codec));

        meta_check.active = opts.embed_metadata;
        thumb_check.active = opts.embed_thumbnail;
        chapters_check.active = opts.embed_chapters;

        subs_check.active = opts.download_subtitles;
        auto_subs_check.active = opts.auto_subtitles;
        save_subs_srt_check.active = opts.save_subtitles_as_srt;
        langs_entry.text = opts.subtitle_languages;

        sb_enable.active = opts.sponsorblock_enabled;
        sb_remove_radio.active = opts.sponsorblock_remove;
        sb_remove_radio.group = sb_mark_radio;

        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    check.active = GLib.strv_contains (opts.sponsorblock_categories, check.label.down ());
                }
            }
            child = child.get_next_sibling ();
        }

        adv_entry.text = opts.extra_args;
    }

    public void sync_to_options (Velox.DownloadOptions opts) {
        opts.is_audio_only = (type_dropdown.get_selected () == 1);

        var codec_obj = (Gtk.StringObject) codec_dropdown.get_selected_item ();
        opts.video_codec = codec_obj.get_string ();

        var quality_obj = (Gtk.StringObject) quality_dropdown.get_selected_item ();
        opts.video_quality = quality_obj.get_string ();

        var container_obj = (Gtk.StringObject) container_dropdown.get_selected_item ();
        opts.container = container_obj.get_string ();

        var audio_obj = (Gtk.StringObject) audio_codec_dropdown.get_selected_item ();
        opts.audio_codec = audio_obj.get_string ();

        opts.embed_metadata = meta_check.active;
        opts.embed_thumbnail = thumb_check.active;
        opts.embed_chapters = chapters_check.active;

        opts.download_subtitles = subs_check.active;
        opts.embed_subtitles = subs_check.active && !save_subs_srt_check.active;
        opts.save_subtitles_as_srt = save_subs_srt_check.active;
        opts.auto_subtitles = auto_subs_check.active;
        opts.subtitle_languages = langs_entry.text.length > 0
            ? langs_entry.text : "en";

        opts.sponsorblock_enabled = sb_enable.active;
        opts.sponsorblock_remove = sb_remove_radio.active;

        var cats = new Array<string> ();
        unowned Gtk.Widget? child = sb_cats_box.get_first_child ();
        while (child != null) {
            if (child is Gtk.FlowBoxChild) {
                var fbc = (Gtk.FlowBoxChild) child;
                var box_child = fbc.get_child ();
                if (box_child is Gtk.CheckButton) {
                    var check = (Gtk.CheckButton) box_child;
                    if (check.active) {
                        cats.append_val (check.label.down ());
                    }
                }
            }
            child = child.get_next_sibling ();
        }
        opts.sponsorblock_categories = cats.data;

        opts.extra_args = adv_entry.text;
    }

    private int dropdown_index_of (Gtk.DropDown dropdown, string value) {
        var model = dropdown.get_model () as Gtk.StringList;
        if (model == null) return 0;
        for (uint i = 0; i < model.get_n_items (); i++) {
            if (model.get_string (i) == value) return (int) i;
        }
        return 0;
    }
}
