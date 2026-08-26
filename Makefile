# Emulator course — thin dispatcher; stage logic lives in course.sh.

.PHONY: start stage test challenge submit progress next clean

start:
	bash course.sh start

stage:
	bash course.sh stage

test:
	bash course.sh test

challenge:
	bash course.sh challenge

submit:
	bash course.sh submit

progress:
	bash course.sh progress

next:
	bash course.sh next

clean:
	rm -rf build
