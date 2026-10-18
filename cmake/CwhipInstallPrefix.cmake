if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT
   AND (CMAKE_VERSION VERSION_LESS 3.29 OR NOT DEFINED ENV{CMAKE_INSTALL_PREFIX}))
    if("$ENV{HOME}" STREQUAL "")
        message(FATAL_ERROR
            "Cannot select the default Cwhip install prefix: HOME is not set; "
            "set HOME to an absolute path or configure with -DCMAKE_INSTALL_PREFIX=<path>")
    endif()
    if(NOT IS_ABSOLUTE "$ENV{HOME}")
        message(FATAL_ERROR
            "Cannot select the default Cwhip install prefix: HOME must be absolute "
            "(got '$ENV{HOME}'); configure with -DCMAKE_INSTALL_PREFIX=<path> to override it")
    endif()

    get_filename_component(cwhip_install_home "$ENV{HOME}" ABSOLUTE)
    set(CMAKE_INSTALL_PREFIX "${cwhip_install_home}/opt/cwhip" CACHE PATH
        "Install path prefix, prepended onto install directories." FORCE)
    set(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT FALSE)
endif()
