"""
PlatformIO extra script for gdolib-c6

This script ensures the precompiled gdolib library is properly linked
to the main application but NOT to the bootloader (which would fail).
"""

Import("env")
import os

lib_path = os.path.dirname(os.path.realpath(__file__))

# Only link the library for the main application, not bootloader
if "bootloader" not in env.subst("$BUILD_DIR"):
    env.Append(LIBPATH=[lib_path])
    env.Append(LIBS=["gdolib"])
