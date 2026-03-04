#!/usr/bin/env bash

# Check argument count
if [ $# -lt 1 ]; then
    echo "Usage: $0 <gcc source directory>"
    exit 1
fi

SRCDIR="$1"

# Original block to search for (vw)
OLD=$(cat << 'EOF'
case $GCC,$host_os in
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
    shlibpath_overrides_runpath=yes)
EOF
)

# Replacement block (newvw)
NEW=$(cat << 'EOF'
case $GCC,$host_os in
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
    shlibpath_overrides_runpath=yes)
EOF
)

# Find and patch files
find "$SRCDIR" -type f \( -name configure -o -name libtool.m4 \) | while read -r file; do
    # Check if the file contains the old block
    if grep -Fq "$OLD" "$file"; then
        echo "Patching $file"
        # Use Perl for multi-line replacement
        perl -0777 -pi -e "s/\Q$OLD\E/$NEW/g" "$file"
    fi
done

