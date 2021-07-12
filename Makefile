.PHONY: clean gen-headers samples/dots

clean:
	rm -rf zig-cache zig-out

samples/dots: samples/dots.c
	$(CC) -lzig-plotille -L$(PWD)/zig-out/lib samples/dots.c -o samples/dots

gen-headers:
	// do not forget to uncomment the `lib.emit_h = true;` part
	$(MAKE) clean
	docker run -it --rm -v $(PWD):/app \
				--platform linux/amd64 \
				euantorano/zig:0.6.0 build
	cp zig-cache/include/* .
	$(MAKE) clean
