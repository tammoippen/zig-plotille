.PHONY: clean gen-headers samples/dots.exe

clean:
	rm -rf zig-cache zig-out

samples/dots.exe: samples/dots.c
	$(CC) $(PWD)/zig-out/lib/libzig-plotille.a samples/dots.c -I. -o samples/dots.exe

gen-headers:
	# do not forget to uncomment the `lib.emit_h = true;` part
	$(MAKE) clean
	docker run -it --rm -v $(PWD):/app \
				--platform linux/amd64 \
				euantorano/zig:0.6.0 build
	cp zig-cache/include/* .
	$(MAKE) clean
