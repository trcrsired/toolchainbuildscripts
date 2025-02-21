DOWNLOAD_ALL=yes SETLLVMENV=yes ./install-llvm.sh
if [ $? -ne 0 ]; then
echo "install-llvm failure"
exit 1
fi
./create_cfgs.sh
