AC_INIT([kzorp], m4_esyscmd([tr -d '\n' < VERSION]))
AC_CONFIG_SRCDIR([driver/kzorp_core.c])
AM_INIT_AUTOMAKE([-Wall foreign subdir-objects])
AM_SILENT_RULES([yes])

AC_PROG_INSTALL
AC_PROG_CC
AM_PROG_CC_C_O
AM_PATH_PYTHON
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

KZORP_PYTHON_DIR="${pythondir}/kzorp"
ZORP_PYTHON_DIR="${pythondir}/Zorp"

AC_SUBST([PYTHON])
AC_SUBST(KZORP_PYTHON_DIR)
AC_SUBST(ZORP_PYTHON_DIR)

AC_CONFIG_FILES([
Makefile
daemon/Makefile
driver/tests/Makefile
driver/tests/communication/Makefile
driver/tests/query/Makefile
scripts/Makefile
pylib/Makefile
pylib/kzorp/Makefile
pylib/Zorp/Makefile
])
AC_OUTPUT
