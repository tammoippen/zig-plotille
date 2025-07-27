.PHONY: clean fmt tests c

fmt:
	zig fmt .
	uvx ruff format *.py

build:
	zig build
	(cd zig-examples; zig build)

tests: build
	zig build test
	(cd zig-examples; zig build run)
	./test_terminfo.py -v


SRCS=$(wildcard c-examples/*.c)
OBJS=$(SRCS:.c=.exe)

c: $(OBJS)

c-examples/%.exe: c-examples/%.c plotille.h $(PWD)/zig-out/lib/libplotille.a
	$(CC) $(PWD)/zig-out/lib/libplotille.a \
		$< \
		-I$(PWD) \
		-o $@
	./$@

clean:
	rm -rf .zig-cache zig-out zig-examples/.zig-cache zig-examples/zig-out c-examples/*.exe
