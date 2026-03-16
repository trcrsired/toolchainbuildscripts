#!/usr/bin/env python3
import sys
import os

def main():
    if len(sys.argv) < 2:
        prog = sys.argv[0] if sys.argv else "script.py"
        print(f"Usage: {prog} <gcc source directory>", file=sys.stderr)
        return 1

    srcdir = sys.argv[1]

    # EXACT COPY of C++ vw (byte-for-byte)
    OLD = b"""case $GCC,$host_os in
  yes,cygwin* | yes,mingw* | yes,pw32* | yes,cegcc*)
    library_names_spec='$libname.dll.a'
    # DLL is installed to $(libdir)/../bin by postinstall_cmds
    postinstall_cmds='base_file=`basename \\${file}`~
      dlpath=`$SHELL 2>&1 -c '\\''. $dir/'\\''\\${base_file}'\\''i; echo \\$dlname'\\''`~
      dldir=$destdir/`dirname \\$dlpath`~
      test -d \\$dldir || mkdir -p \\$dldir~
      $install_prog $dir/$dlname \\$dldir/$dlname~
      chmod a+x \\$dldir/$dlname~
      if test -n '\\''$stripme'\\'' && test -n '\\''$striplib'\\''; then
        eval '\\''$striplib \\$dldir/$dlname'\\'' || exit \\$?;
      fi'
    postuninstall_cmds='dldll=`$SHELL 2>&1 -c '\\''. $file; echo \\$dlname'\\''`~
      dlpath=$dir/\\$dldll~
       $RM \\$dlpath'
    shlibpath_overrides_runpath=yes"""

    # EXACT COPY of C++ newvw (byte-for-byte)
    NEW = b"""case $GCC,$host_os in
  yes,cygwin* | yes,mingw* | yes,pw32* | yes,cegcc*)
    library_names_spec='$libname.dll.a'
    # DLL is installed to $(libdir)/../bin by postinstall_cmds
    # If user builds GCC with mulitlibs enabled,
    # it should just install on $(libdir)
    # not on $(libdir)/../bin or 32 bits dlls would override 64 bit ones.
    if test x${multilib} = xyes; then
    postinstall_cmds='base_file=`basename \\${file}`~
      dlpath=`$SHELL 2>&1 -c '\\''. $dir/'\\''\\${base_file}'\\''i; echo \\$dlname'\\''`~
      dldir=$destdir/`dirname \\$dlpath`~
      $install_prog $dir/$dlname $destdir/$dlname~
      chmod a+x $destdir/$dlname~
      if test -n '\\''$stripme'\\'' && test -n '\\''$striplib'\\''; then
        eval '\\''$striplib $destdir/$dlname'\\'' || exit \\$?;
      fi'
    else
    postinstall_cmds='base_file=`basename \\${file}`~
      dlpath=`$SHELL 2>&1 -c '\\''. $dir/'\\''\\${base_file}'\\''i; echo \\$dlname'\\''`~
      dldir=$destdir/`dirname \\$dlpath`~
      test -d \\$dldir || mkdir -p \\$dldir~
      $install_prog $dir/$dlname \\$dldir/$dlname~
      chmod a+x \\$dldir/$dlname~
      if test -n '\\''$stripme'\\'' && test -n '\\''$striplib'\\''; then
        eval '\\''$striplib \\$dldir/$dlname'\\'' || exit \\$?;
      fi'
    fi
    postuninstall_cmds='dldll=`$SHELL 2>&1 -c '\\''. $file; echo \\$dlname'\\''`~
      dlpath=$dir/\\$dldll~
       $RM \\$dlpath'
    shlibpath_overrides_runpath=yes"""

    for root, dirs, files in os.walk(srcdir):
        for name in files:
            if name not in ("configure", "libtool.m4"):
                continue

            path = os.path.join(root, name)

            with open(path, "rb") as f:
                data = f.read()

            if OLD not in data:
                continue

            print("Patching", path)

            newdata = data.replace(OLD, NEW)

            with open(path, "wb") as f:
                f.write(newdata)

    return 0


if __name__ == "__main__":
    sys.exit(main())
