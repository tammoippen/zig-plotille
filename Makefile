.PHONY: clean gen-headers samples/dots.exe fmt tests

fmt:
	zig fmt .
	ruff format examples/*.py

tests:
	zig build --summary all test examples run install
	./examples/test_terminfo.py -v

clean:
	rm -rf zig-cache zig-out

examples/dots.exe: examples/dots.c
	$(CC) $(PWD)/zig-out/lib/libzig-plotille.a \
		examples/dots.c \
		-I. \
		-I$(HOME)/repos/zig/build/install/lib/zig \
		-o examples/dots.exe

gen-headers:
	# do not forget to uncomment the `lib.emit_h = true;` part
	$(MAKE) clean
	docker run -it --rm -v $(PWD):/app \
				--workdir /app \
				--platform linux/amd64 \
				euantorano/zig:0.6.0 build
	cp zig-cache/include/* .
	$(MAKE) clean
