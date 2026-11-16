project(
    'velox',
    ['vala', 'c'],
    version: '0.5.1',
    meson_version: '>= 0.62.0',
    default_options: ['warning_level=2'],
)

gnome = import('gnome')

dependency('glib-2.0', version: '>= 2.76')
dependency('gtk4', version: '>= 4.12')
dependency('libadwaita-1', version: '>= 1.4')
dependency('json-glib-1.0')
dependency('libsoup-3.0')

add_project_arguments('-DGETTEXT_PACKAGE="velox"', language: 'c')

subdir('data')
subdir('src')

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
