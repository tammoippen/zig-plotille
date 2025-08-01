.PHONY: clean fmt tests c build run-c

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

zig-out/lib/libplotille.a: build

c-examples/%.exe: c-examples/%.c plotille.h zig-out/lib/libplotille.a
	$(CC) $(CURDIR)/zig-out/lib/libplotille.a \
		$< \
		-I$(CURDIR) \
		-o $@

run-c: c
	@for exe in $(OBJS); do \
		echo "Running $$exe..."; \
		./$$exe || echo "Failed to run $$exe"; \
	done

clean:
	rm -rf .zig-cache zig-out zig-examples/.zig-cache zig-examples/zig-out c-examples/*.exe
