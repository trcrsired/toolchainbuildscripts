cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/binutils-gdb" ]; then
git clone git://sourceware.org/git/binutils-gdb.git
if [ $? -ne 0 ]; then
echo "binutils-gdb clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/binutils-gdb"
git pull --quiet

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/gcc" ]; then
git clone git://gcc.gnu.org/git/gcc.git
if [ $? -ne 0 ]; then
echo "gcc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/gcc"
git pull --quiet


cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/gmp" ]; then
hg clone https://gmplib.org/repo/gmp
if [ $? -ne 0 ]; then
echo "gmp clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/gmp"
hg pull --quiet
if [ ! -f "$TOOLCHAINS_BUILD/gmp/configure" ]; then
cd $TOOLCHAINS_BUILD/gmp
./.bootstrap
fi


cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mpfr" ]; then
git clone https://gitlab.inria.fr/mpfr/mpfr.git
if [ $? -ne 0 ]; then
echo "mpfr clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/mpfr"
git pull --quiet
if [ ! -f "$TOOLCHAINS_BUILD/mpfr/configure" ]; then
cd $TOOLCHAINS_BUILD/mpfr
./autogen.sh
fi

cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/mpc" ]; then
git clone https://gitlab.inria.fr/mpc/mpc.git
if [ $? -ne 0 ]; then
echo "mpc clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/mpc"
git pull --quiet
if [ ! -f "$TOOLCHAINS_BUILD/mpc/configure" ]; then
cd $TOOLCHAINS_BUILD/mpc
autoreconf -i
fi


cd "$TOOLCHAINS_BUILD"
if [ ! -d "$TOOLCHAINS_BUILD/isl" ]; then
git clone git://repo.or.cz/isl.git
if [ $? -ne 0 ]; then
echo "isl clone failed"
exit 1
fi
fi
cd "$TOOLCHAINS_BUILD/isl"
git pull --quiet
if [ ! -f "$TOOLCHAINS_BUILD/isl/configure" ]; then
cd $TOOLCHAINS_BUILD/isl
./autogen.sh
fi

if [[ ${USE_GETTEXT} == "yes" ]]; then
	cd "$TOOLCHAINS_BUILD"
	if [ ! -d "$TOOLCHAINS_BUILD/gettext" ]; then
		git clone git://git.savannah.gnu.org/gettext.git
		if [ $? -ne 0 ]; then
			echo "gettext clone failed"
			exit 1
		fi
		cd "$TOOLCHAINS_BUILD/gettext"
		git pull --quiet
		if [ ! -f "$TOOLCHAINS_BUILD/gettext/configure" ]; then
			cd $TOOLCHAINS_BUILD/gettext
			./autopull.sh
			if [ $? -ne 0 ]; then
				echo "gettext autopull failed"
				exit 1
			fi
			./autogen.sh
			if [ $? -ne 0 ]; then
				echo "gettext autogen failed"
				exit 1
			fi
		fi
	fi
fi

if [ ! -L "$TOOLCHAINS_BUILD/binutils-gdb/gmp" ]; then
cd $TOOLCHAINS_BUILD/binutils-gdb
ln -s $TOOLCHAINS_BUILD/gmp gmp
ln -s $TOOLCHAINS_BUILD/mpfr mpfr
ln -s $TOOLCHAINS_BUILD/mpc mpc
ln -s $TOOLCHAINS_BUILD/isl isl
fi

if [ ! -L "$TOOLCHAINS_BUILD/gcc/gmp" ]; then
cd $TOOLCHAINS_BUILD/gcc
ln -s $TOOLCHAINS_BUILD/gmp gmp
ln -s $TOOLCHAINS_BUILD/mpfr mpfr
ln -s $TOOLCHAINS_BUILD/mpc mpc
ln -s $TOOLCHAINS_BUILD/isl isl
fi