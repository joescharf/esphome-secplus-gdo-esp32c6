# CMakeLists.txt for gdolib-c6 ESP-IDF component
# This ensures the library is linked to the main application but not the bootloader

idf_component_register(
    INCLUDE_DIRS include
)

# Link the precompiled static library to the main application
target_link_libraries(${COMPONENT_LIB} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/libgdolib.a)
