#!/usr/bin/env python3
import sys
import os

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <gcc source directory>")
    sys.exit(1)

SRCDIR = sys.argv[1]

# Read OLD block
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

# Read NEW block
NEW = r"""case $GCC,$host_os in
  yes,cygwin* | yes,mingw* | yes,pw32* | yes,cegcc*)
    library_names_spec='$libname.dll.a'
    # DLL is installed to $(libdir)/../bin by postinstall_cmds
    # If user builds GCC with multilibs enabled,
    # it should install into $(libdir) directly
    # instead of $(libdir)/../bin, otherwise 32-bit DLLs
    # may override 64-bit ones.
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

OLD_b = OLD.encode("utf-8")
NEW_b = NEW.encode("utf-8")

for root, dirs, files in os.walk(SRCDIR):
    for name in files:
        if name not in ("configure", "libtool.m4"):
            continue

        path = os.path.join(root, name)

        with open(path, "rb") as f:
            data = f.read()

        if OLD_b not in data:
            continue

        print("Patching", path)

        newdata = data.replace(OLD_b, NEW_b)

        with open(path, "wb") as f:
            f.write(newdata)
