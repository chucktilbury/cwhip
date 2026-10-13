message(FATAL_ERROR
    "cdbg is unavailable in this configuration. Install pkg-config, GTK 4 and "
    "GtkSourceView 5 development files, then reconfigure with "
    "-DCWHIP_GTK=ON -DCWHIP_GTK_SOURCEVIEW=ON. Install GDB to debug local targets.")
