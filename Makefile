.PHONY: clean gen-headers examples/dots.exe fmt tests

fmt:
	zig fmt .
	uvx ruff format examples/*.py

tests:
	zig build test
	(cd zig-examples; zig build run)
	./test_terminfo.py -v

clean:
	rm -rf zig-cache zig-out

SRCS=$(wildcard c-examples/*.c)
OBJS=$(SRCS:.c=.exe)

c: $(OBJS)

c-examples/%.exe: c-examples/%.c plotille.h $(PWD)/zig-out/lib/libplotille.a
	$(CC) $(PWD)/zig-out/lib/libplotille.a \
		$< \
		-I$(PWD) \
		-o $@
