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

ifeq ($(OS),Windows_NT)
    STATIC_LIB = zig-out/lib/plotille.lib
else
    STATIC_LIB = zig-out/lib/libplotille.a
endif

c: $(OBJS)

$(STATIC_LIB): build

c-examples/%.exe: c-examples/%.c plotille.h $(STATIC_LIB)
	$(CC) $(CURDIR)/$(STATIC_LIB) \
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
