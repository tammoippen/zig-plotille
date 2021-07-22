.PHONY: clean gen-headers samples/dots.exe fmt tests

fmt:
	zig fmt .
	black tests/*.py

tests:
	zig build test examples install
	python3 tests/test_terminfo.py -v

clean:
	rm -rf zig-cache zig-out

samples/dots.exe: samples/dots.c
	$(CC) $(PWD)/zig-out/lib/libzig-plotille.a samples/dots.c -I. -o samples/dots.exe

gen-headers:
	# do not forget to uncomment the `lib.emit_h = true;` part
	$(MAKE) clean
	docker run -it --rm -v $(PWD):/app \
				--workdir /app \
				--platform linux/amd64 \
				euantorano/zig:0.6.0 build
	cp zig-cache/include/* .
	$(MAKE) clean
