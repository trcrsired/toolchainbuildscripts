#!/usr/bin/env python3
import sys
import os

# Check arguments
if len(sys.argv) < 2:
    prog = sys.argv[0] if sys.argv else "script.py"
    print(f"Usage: {prog} <gcc source directory>")
    sys.exit(1)

SRCDIR = sys.argv[1]

# Exact OLD block (must match byte-for-byte)
OLD = r"""case $GCC,$host_os in
  yes,cygwin* | yes,mingw* | yes,pw32* | yes,cegcc*)
    library_names_spec='$libname.dll.a'
    # DLL is installed to $(libdir)/../bin by postinstall_cmds
    postinstall_cmds='base_file=`basename \${file}`~
      dlpath=`$SHELL 2>&1 -c '\''. $dir/'\''\${base_file}'\''i; echo \$dlname'\''`~
      dldir=$destdir/`dirname \$dlpath`~
      test -d \$dldir || mkdir -p \$dldir~
      $install_prog $dir/$dlname \$dldir/$dlname~
      chmod a+x \$dldir/$dlname~
      if test -n '\''$stripme'\'' && test -n '\''$striplib'\''; then
        eval '\''$striplib \$dldir/$dlname'\'' || exit \$?;
      fi'
    postuninstall_cmds='dldll=`$SHELL 2>&1 -c '\''. $file; echo \$dlname'\''`~
      dlpath=$dir/\$dldll~
       $RM \$dlpath'
    shlibpath_overrides_runpath=yes)"""

# Exact NEW block (must match C++ newvw exactly)
NEW = r"""case $GCC,$host_os in
  yes,cygwin* | yes,mingw* | yes,pw32* | yes,cegcc*)
    library_names_spec='$libname.dll.a'
    # DLL is installed to $(libdir)/../bin by postinstall_cmds
    # If user builds GCC with mulitlibs enabled,
    # it should just install on $(libdir)
    # not on $(libdir)/../bin or 32 bits dlls would override 64 bit ones.
    if test x${multilib} = xyes; then
    postinstall_cmds='base_file=`basename \${file}`~
      dlpath=`$SHELL 2>&1 -c '\''. $dir/'\''\${base_file}'\''i; echo \$dlname'\''`~
      dldir=$destdir/`dirname \$dlpath`~
      $install_prog $dir/$dlname $destdir/$dlname~
      chmod a+x $destdir/$dlname~
      if test -n '\''$stripme'\'' && test -n '\''$striplib'\''; then
    eval '\''$striplib $destdir/$dlname'\'' || exit \$?;
      fi'
    else
    postinstall_cmds='base_file=`basename \${file}`~
      dlpath=`$SHELL 2>&1 -c '\''. $dir/'\''\${base_file}'\''i; echo \$dlname'\''`~
      dldir=$destdir/`dirname \$dlpath`~
      test -d \$dldir || mkdir -p \$dldir~
      $install_prog $dir/$dlname \$dldir/$dlname~
      chmod a+x \$dldir/$dlname~
      if test -n '\''$stripme'\'' && test -n '\''$striplib'\''; then
    eval '\''$striplib \$dldir/$dlname'\'' || exit \$?;
      fi'
    fi
    postuninstall_cmds='dldll=`$SHELL 2>&1 -c '\''. $file; echo \$dlname'\''`~
      dlpath=$dir/\$dldll~
       $RM \$dlpath'
    shlibpath_overrides_runpath=yes)"""

# Convert to bytes (exact UTF‑8 encoding)
OLD_b = OLD.encode("utf-8")
NEW_b = NEW.encode("utf-8")

# Walk directory recursively
for root, dirs, files in os.walk(SRCDIR):
    for name in files:
        # Only process configure and libtool.m4
        if name not in ("configure", "libtool.m4"):
            continue

        path = os.path.join(root, name)

        # Read file as bytes
        with open(path, "rb") as f:
            data = f.read()

        # Skip if OLD block not found
        if OLD_b not in data:
            continue

        print("Patching", path)

        # Replace all occurrences (byte-for-byte)
        newdata = data.replace(OLD_b, NEW_b)

        # Write back
        with open(path, "wb") as f:
            f.write(newdata)
