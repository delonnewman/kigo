SHELL := bash

all: examples/basic

examples/basic:
	./bin/kigoc examples/basic.rb examples/basic

clean:
	rm examples/basic

PHONY: clean all
