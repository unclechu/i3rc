all: clean build-invert-window-colors
	./make.pl create-symlink

build-invert-window-colors:
	./make.pl build-invert-window-colors

clean-invert-window-colors:
	./make.pl clean-invert-window-colors

clean:
	./make.pl clean
