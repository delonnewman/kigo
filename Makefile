SHELL := bash

all: examples/basic examples/funcall examples/echo

examples/basic:
	./bin/kigoc examples/basic.rb examples/basic

examples/funcall:
	./bin/kigoc examples/funcall.rb examples/funcall

examples/echo:
	./bin/kigoc examples/echo.rb examples/echo

clean:
	rm examples/basic examples/funcall examples/echo

PHONY: clean all
