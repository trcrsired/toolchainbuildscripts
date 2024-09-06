if [[ $1 == "restart" ]]; then
	echo "restarting"
	rm -f "$(realpath .)/buildstderrlogs.txt"
	echo "restart done"
fi

./all.sh "$@" > /dev/null 2 > "$(realpath .)/buildstderrlogs.txt"
