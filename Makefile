# Emulator course — thin dispatcher; stage logic lives in course.sh.

.PHONY: start stage test challenge submit progress next clean doctor verify-course verify verify_course reset

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

# Validate the dev environment (cc, make, bash, python3; extensible for Metal)
doctor:
	bash course.sh doctor

# Validate that course material itself is structurally valid
verify-course:
	bash course.sh verify-course

verify: verify-course
verify_course: verify-course

# Safe progress reset — removes .progress/state and build/ only, never src/
reset:
	bash course.sh reset

clean:
	rm -rf build
