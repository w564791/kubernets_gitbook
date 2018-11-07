#!/bin/bash
gitbook_command=$(which gitbook)
if [ ! -f $gitbook_command ];then
	apt install nodejs-legacy npm
	npm install -g gitbook-cli
	wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
fi
gitbook install
gitbook pdf .
