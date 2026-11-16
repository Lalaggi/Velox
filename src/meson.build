sources = files(
    'main.vala',
    'application.vala',
    'window.vala',
    'models/download-state.vala',
    'models/download-item.vala',
    'models/download-options.vala',
    'services/ytdlp-service.vala',
    'services/download-manager.vala',
    'utils/progress-parser.vala',
    'utils/settings-manager.vala',
    'utils/music-library.vala',
    'utils/thumbnail-loader.vala',
    'ui/preferences-dialog.vala',
    'ui/download-item-row.vala',
    'ui/options-page-builder.vala',
)

app = executable(
    'velox',
    sources,
    dependencies: [
        dependency('glib-2.0', version: '>= 2.76'),
        dependency('gtk4', version: '>= 4.12'),
        dependency('libadwaita-1', version: '>= 1.4'),
        dependency('json-glib-1.0'),
        dependency('gdk-pixbuf-2.0'),
        dependency('libsoup-3.0'),
    ],
    install: true,
)

run_target('run',
    command: [app],
)
