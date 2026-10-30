# make        -> build lukOS.img
# make run    -> build and boot it in QEMU (if you have QEMU installed)
# make clean  -> delete build output
all:
	python3 build.py

run: all
	qemu-system-i386 -fda lukOS.img

clean:
	rm -rf build lukOS.img
