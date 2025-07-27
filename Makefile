.PHONY: clean gen-headers examples/dots.exe fmt tests

fmt:
	zig fmt .
	uvx ruff format examples/*.py

tests:
	zig build test
	./test_terminfo.py -v
	(cd zig-examples; zig build run)

clean:
	rm -rf zig-cache zig-out

SRCS=$(wildcard c-examples/*.c)
OBJS=$(SRCS:.c=.exe)

c: $(OBJS)

c-examples/%.exe: c-examples/%.c
	$(CC) $(PWD)/zig-out/lib/libplotille.a \
		$< \
		-I$(PWD) \
		-o $@
