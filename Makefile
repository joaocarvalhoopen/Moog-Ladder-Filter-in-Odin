all:
	odin build . -out:moog_filter_test.exe -o:speed

clean:
	rm moog_filter_test.exe

run:
	./moog_filter_test.exe
