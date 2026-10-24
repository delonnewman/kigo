SHELL := bash

all: examples/basic examples/funcall

examples/basic:
	./bin/kigoc examples/basic.rb examples/basic

examples/funcall:
	./bin/kigoc examples/funcall.rb examples/funcall

clean:
	rm examples/basic

PHONY: clean all
