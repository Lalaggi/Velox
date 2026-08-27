install_data(
    'xyz.lalaggi.velox.svg',
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps'),
    rename: 'xyz.lalaggi.velox.svg',
)

install_data(
    'xyz.lalaggi.velox.desktop.in',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    rename: 'xyz.lalaggi.velox.desktop',
)

install_data(
    'xyz.lalaggi.velox.metainfo.xml.in',
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
    rename: 'xyz.lalaggi.velox.metainfo.xml',
)

install_data(
    'xyz.lalaggi.velox.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

# Transitional: keep old schema for seamless migration from com.github.lalaggi.velox
# Remove after one release once users have migrated.
install_data(
    'com.github.lalaggi.velox.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)
