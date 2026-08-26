// Minimal test framework for the emulator course.
//
// Usage:
//   #include "test.h"
//
//   static void test_foo(void) { CHECK_EQ(1 + 1, 2); }
//
//   int main(void) {
//       RUN(test_foo);
//       return summary("suite-name");
//   }
//
// CHECK macros never abort: they print the failing expression, file, and
// line, count the failure, and continue. A suite passes only if every
// check passed.

#ifndef COURSE_TEST_H
#define COURSE_TEST_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static int checks_run = 0;
static int checks_failed = 0;
static const char *current_test = "";

static void check_begin(const char *name) __attribute__((unused));
static void check_begin(const char *name) {
    current_test = name;
}

#define CHECK(cond)                                                       \
    do {                                                                  \
        checks_run++;                                                     \
        if (!(cond)) {                                                    \
            checks_failed++;                                              \
            printf("  FAIL [%s] %s:%d: %s\n", current_test, __FILE__,     \
                   __LINE__, #cond);                                      \
        }                                                                 \
    } while (0)

#define CHECK_TRUE(x) CHECK(x)
#define CHECK_EQ(a, b) CHECK((a) == (b))
#define CHECK_NE(a, b) CHECK((a) != (b))

#define CHECK_MEM_EQ(buf, expected, n)                                    \
    do {                                                                  \
        checks_run++;                                                     \
        if (memcmp((buf), (expected), (n)) != 0) {                        \
            checks_failed++;                                              \
            printf("  FAIL [%s] %s:%d: memcmp(%s, %s, %zu) mismatch\n",   \
                   current_test, __FILE__, __LINE__, #buf, #expected,     \
                   (size_t)(n));                                          \
        }                                                                 \
    } while (0)

#define RUN(fn)               \
    do {                      \
        check_begin(#fn);     \
        fn();                 \
    } while (0)

static int summary(const char *suite) __attribute__((unused));
static int summary(const char *suite) {
    if (checks_failed == 0) {
        printf("PASS %s (%d checks)\n", suite, checks_run);
    } else {
        printf("FAIL %s (%d of %d checks failed)\n", suite, checks_failed,
               checks_run);
    }
    return checks_failed == 0 ? 0 : 1;
}

#endif // COURSE_TEST_H
