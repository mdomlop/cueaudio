exe='cueaudio.sh'

install:
	install -m 755 $(exe) /usr/bin/
uninstall:
	rm /usr/bin/$(exe)
