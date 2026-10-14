# C-Based Toolchain Hardening Cheat Sheet

## Introduction

Project settings for reliable, secure code in C, C++, Objective C across development environments. Covers Microsoft and GCC toolchains: executables w/ firmer defensive postures, better platform security integration. Configured toolchain also gives enhanced warnings, static analysis, self-debugging code during development.

Four hardening areas: configuration, preprocessor, compiler, linker. Nearly all neglected in nearly all projects (Auto-configured, makefile-based, Eclipse-based, Visual Studio-based, Xcode-based). Address gaps at configuration and build time: difficult to impossible to add hardening on distributed executable after the fact on some platforms.

Prescriptive: no semantics debate or behavior speculation. Some info, e.g. C/C++ committee's motivation for `program diagnostics`, `NDEBUG`, `assert`, and `abort()`, appears lost. So article specifies semantics (philosophy of 'debug' and 'release' build configurations), assigns behaviors (what assert does in 'debug' vs 'release'), presents a position. Posture too aggressive → back off as needed.

Secure toolchain ≠ silver bullet; one piece of overall engineering strategy. Complements static analysis, dynamic analysis, secure coding, negative test suites. Still need Valgrind, Helgrind, solid designs and architectures.

OWASP ESAPI C++ project eats own dog food; many examples come from it.

Terse version: [C-Based Toolchain Hardening Cheat Sheet](C-Based_Toolchain_Hardening.md).

## Wisdom

Code **must** be correct. **Should** be secure. **Can** be efficient.

Dr. Jon Bentley: _"If it doesn't have to be correct, I can make it as fast as you'd like it to be"_.

Dr. Gary McGraw: _"Thou shalt not rely solely on security features and functions to build secure software as security is an emergent property of the entire system and thus relies on building and integrating all parts properly"_.

## Configuration

First opportunity to configure project for success. Configure project for reliability and security goals, and configure integrated libraries properly. Three choices: auto-configuration utilities (Linux/Unix); handwritten makefile (predominant on Linux, macOS, Unix, applies to Windows too); IDE.

### Build Configurations

Configure two builds: Debug and Release. Debug for development, full instrumentation. Release for production. Difference usually _optimization level_ and _debug level_. Third configuration Test, usually special case of Release.

Debug and Release settings typically opposed. Debug: no optimizations, full debug info. Release: optimizations, minimal to moderate debug info. Debug code also has full assertions and additional library integration, e.g. mudflaps and malloc guards such as `dmalloc`.

Test config = often Release making everything public for testing + test harness. E.g., all public member functions (C++ class) and all interfaces (library or shared object) available for testing. Many OO purists oppose testing private interfaces; this (_q.v._) is about building reliable and secure software, not OO-ness.

GCC 4.8 introduced optimization `-Og`. Only an optimization; still needs customary debug level via `-g`.

#### Debug Builds

Developers spend most time in debug builds vetting problems; build should be 'force multiplier'. Debug code more valuable than release code: extra instrumentation makes program nearly "self-debugging", catches bad parameters, failed API calls, memory problems.

Self-debugging code cuts troubleshooting/debugging time → more time for development and feature requests. Code checked in w/o debug instrumentation: fix by adding instrumentation, or reject.

GCC: optimizations and debug symbolication controlled by `-O` and `-g`. Use in `CFLAGS` and `CXXFLAGS` for minimal debug session:

```text
-O0 -g3 -ggdb
```

`-O0` turns off optimizations; `-g3` ensures maximum debug info, incl. symbolic constants and `#defines`. May need `-O1` so some analysis runs; otherwise debug build misses warnings present in release builds. `-ggdb` includes extensions for GDB debug session. For completeness, Jan Krachtovil stated `-ggdb` currently has no effect in private email.

x86 builds: choose speculative-execution mitigations for target CPU and OS. GCC's `-mindirect-branch=thunk` replaces indirect calls and jumps w/ call-and-return thunks; `-mfunction-return=thunk` transforms function returns. Retpoline mitigates specific Spectre variant 2 attack paths, not speculative-execution vulns in general. Follow current platform guidance; don't assume these flags protect vs every Spectre variant or Meltdown.

Debug build also defines `DEBUG`, ensures `NDEBUG` not defined. `NDEBUG` removes "program diagnostics", has undesirable behavior and side effects (below). Defines apply to all code (program + included libraries): need to know how they fail too (you take the bug report, not the third party library).

Use other relevant flags, e.g. `-fno-omit-frame-pointer`: frame pointer makes stack traces easier to decode. Debug builds not shipped → OK to leave symbols in executable. Debug info has no performance hit (see "How does the gcc -g option affect performance?").

Include additional diagnostic libraries, e.g. `dmalloc` and Address Sanitizer. Not using extra diagnostics in debug builds → start; OK to find errors you aren't looking for. See Comparison Of Memory Tools.

#### Release Builds

What customer receives. Run on production hardware and servers; reliable, secure, efficient. Stable release = product of development effort.

Use in `CFLAGS` and `CXXFLAGS` for release builds:

```text
-On -g2
```

`-O`_`n`_ sets optimizations for speed or size (e.g., `-Os` or `-O2`); `-g2` ensures debug info created.

Strip debug info, retain it for symbolication of field crash reports. Not desired, but debug info can stay in place w/o performance penalty (see _How does the gcc -g option affect performance?_).

Release builds define `NDEBUG`, ensure `DEBUG` not defined. Debugging/diagnostics time over: production code gets full optimizations, no "programming diagnostics", other efficiencies. Can't optimize or excessive logging → usually program not production-ready.

Relying on `assert` then `abort()` abuses "program diagnostics"; no place in production code. Want memory dump → create one deliberately so users needn't worry about secrets/sensitive info written to filesystem and emailed in plain text.

Windows: `/Od` for debug, `/Ox`, `/O2` or `/Os` for release. See Microsoft's /O Options (Optimize Code).

#### Test Builds

Heuristic validation via positive and negative test suites. All interfaces tested for spec conformance and "satisfaction": no crashing, no trashing memory arena, even under negative tests.

All interfaces tested (not just public), so `CFLAGS` and `CXXFLAGS` include:

```text
-Dprotected=public -Dprivate=public
```

Also change `__attribute__` `((visibility` `("hidden")))` to `__attribute__` `((visibility` `("default")))`.

Positive tests: nearly everyone gets right. Negative self tests more interesting: try to make program fail, verify graceful failure. Bad actors aren't courteous; your project takes egg on face via bug report or Full Disclosure / Bugtraq appearance, not `<some library>` you included.

### Autotools

Auto configuration tools popular on Linux/Unix: _Autoconf_, _Automake_, _config_, _Configure_. Produce project files from scripts and templates; then build w/ `make`.

Files of interest: `m4` and various `*.in`, `*.ac` (Autoconf), `*.am` (Automake). Sometimes must open them, or resulting makefiles, to tune "stock" configuration.

Three downsides of command-line configuration tools: (1) often ignore user requests, (2) switching build flags may reuse objects from earlier configuration, (3) security often not a goal.

Demo issue 1: configure w/ `configure` `CFLAGS="-Wall` `-fPIE"` `CXXFLAGS="-Wall` `-fPIE"` `LDFLAGS="-pie"`. Autotools probably ignores request, so command below won't produce expected results. Workaround: open `m4` script, `makefile.in` or `makefile.am`, fix configuration.

```bash
$ configure CFLAGS="-Wall -Wextra -Wconversion -fPIE -Wno-unused-parameter
    -Wformat=2 -Wformat-security -fstack-protector-all -Wstrict-overflow"
    LDFLAGS="-pie -z,noexecstack -z,noexecheap -z,relro -z,now"
```

Point 2: use separate build directories for different configurations. Make checks modification times of prerequisites and targets, so changing `CFLAGS` or `CXXFLAGS` alone doesn't rebuild existing objects. Separate debug, test, release build directories prevent reuse of objects compiled w/ different hardening flags.

Point 3: Autoconf and Automake miss many security opportunities, ship insecure out of box. Many compiler switches and linker flags improve defensive posture but not 'on' by default. Autoconf, supposed to handle this, often serves lowest common denominator.

Automake mailing list discussion _Enabling compiler warning flags_: attempts to improve defaults met resistance, no action. Resistance often of form "`<some useful warning> also produces false positives`" or "`<some obscure platform> does not support <established security feature>`". David Wheeler, author of _Secure Programming for Linux and Unix HOWTO_, was among those trying to improve posture.

### Makefiles

Make: one of earliest build tools (1970s). Available on Linux, macOS, Unix; frequently encountered. Shortcomings (_Recursive Make Considered Harmful_, _What's Wrong With GNU make?_). ESAPI C++ uses Make for three reasons: omnipresent; easier to manage than Autotools family; `libtool` out of the question.

Consider (1) `make` `debug`, then `make` `release`. Each needs different `CFLAGS` (optimizations, debug support level). In makefile, extract relevant target and set `CFLAGS` and `CXXFLAGS` like below (from ESAPI C++ makefile):

```text
## makefile
DEBUG_GOALS = $(filter $(MAKECMDGOALS), debug)
ifneq ($(DEBUG_GOALS),)
    WANT_DEBUG := 1
    WANT_TEST := 0
    WANT_RELEASE := 0
endif
…

ifeq ($(WANT_DEBUG),1)
    ESAPI_CFLAGS += -DDEBUG=1 -UNDEBUG -g3 -ggdb -O0
    ESAPI_CXXFLAGS += -DDEBUG=1 -UNDEBUG -g3 -ggdb -O0
endif

ifeq ($(WANT_RELEASE),1)
    ESAPI_CFLAGS += -DNDEBUG=1 -UDEBUG -g -O2
    ESAPI_CXXFLAGS += -DNDEBUG=1 -UDEBUG -g -O2
endif

ifeq ($(WANT_TEST),1)
    ESAPI_CFLAGS += -DESAPI_NO_ASSERT=1 -g2 -ggdb -O2 -Dprivate=public
                                                      -Dprotected=public
    ESAPI_CXXFLAGS += -DESAPI_NO_ASSERT=1 -g2 -ggdb -O2 -Dprivate=public
                                                        -Dprotected=public
endif
…

## Merge ESAPI flags with user supplied flags. We perform the extra step to ensure
## user options follow our options, which should give user option's a preference.
override CFLAGS := $(ESAPI_CFLAGS) $(CFLAGS)
override CXXFLAGS := $(ESAPI_CXXFLAGS) $(CXXFLAGS)
override LDFLAGS := $(ESAPI_LDFLAGS) $(LDFLAGS)
…
```

Make first builds program in debug configuration for debugger session using rule like:

```text
%.cpp:%.o:
        $(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
```

For release build, Make does nothing: everything considered up to date despite changed `CFLAGS` and `CXXFLAGS`. Program stays in debug configuration, risks `SIGABRT` at runtime because debug instrumentation present (`assert` calls `abort()` when `NDEBUG` **not** defined). You DoS'd yourself via `make`.

Many projects don't honor user's command-line. ESAPI C++ honors user flags via `override` (above); others don't. E.g., project to be built w/ Position Independent Executable (PIE or ASLR) and data execution prevention (DEP): ignoring user settings + insecure defaults (not picked up in auto-setup/auto-configure) → program built with following likely has neither defense:

```bash
make CFLAGS="-fPIE" CXXFLAGS="-fPIE" LDFLAGS="-pie -z,noexecstack, -z,noexecheap"
```

ASLR and DEP especially important on Linux: Data Execution (not Prevention) is the norm.

### Integration

Project-level integration lets you harden program or library w/ domain knowledge. Platform supports PIE/ASLR and DEP → integrate. Not doing so can lead to exploitation. Case: KingCope's 0-days for MySQL, December, 2012 (CVE-2012-5579 and CVE-2012-5612, among others). Platform security integration would have neutered several.

Include helpful libraries not needed for business logic. Platform has DMalloc or Address Sanitizer → probably use in debug builds.

Ubuntu: DMalloc via package manager, `sudo apt install libdmalloc5`. Apple platforms: scheme option. Address Sanitizer in GCC 4.8 and above for many platforms.

Also harden third party libraries you chose to include: you and users responsible. `SP800-53` audit puts third party libraries in scope: supply chain included (item SA-12, Supply Chain Protection). Not limited to US Federal arena; financial institutions review too. Violating example: CVE-2012-1525, from Adobe's inclusion of defective Sablotron library.

Another: including OpenSSL. Know (1) SSLv2 insecure, (2) SSLv3 insecure, (3) compression insecure (among others). Suppose also no hardware and engines, static linking only. Configure OpenSSL:

```bash
$ Configure darwin64-x86_64-cc -no-hw -no-engine -no-comp -no-shared
    -no-dso -no-ssl2 -no-ssl3 --openssldir=…
```

_Note Well_: may want engines, esp. on Ivy Bridge microarchitectures (3rd generation Intel Core i5 and i7 processors). To use processor's RNG (via `rdrand` instruction), call OpenSSL's `ENGINE_load_rdrand()` then `ENGINE_set_default` w/ `ENGINE_METHOD_RAND`. See OpenSSL's Random Numbers.

Configuring w/o switches → likely vulnerable code/libraries, audit-failure risk. Remote server: following command reveals whether compression active on channel:

```bash
echo "GET / HTTP1.0" | openssl s_client -connect <nowiki>example.com:443</nowiki>
```

`nm` or `openssl` `s_client` shows compression enabled in client. Any symbol within `OPENSSL_NO_COMP` preprocessor macro also witnesses, since `-no-comp` translates to `CFLAGS` define.

```bash
$ nm /usr/local/ssl/iphoneos/lib/libcrypto.a 2>/dev/null | egrep -i "(COMP_CTX_new|COMP_CTX_free)"
0000000000000110 T COMP_CTX_free
0000000000000000 T COMP_CTX_new
```

Worse: answering auditors asking about configurations and protocols w/ "we don't use weak/wounded/broken ciphers" or "we follow best practices". Using compression tells auditor you use wounded protocols in insecure configuration and don't follow best practices. Sets off alarm bells, auditor digs deeper.

## Preprocessor

Crucial to project setup. C committee provided one macro, `NDEBUG`, usable to derive configurations and drive engineering processes. Committee left many related items to chance → programmers abuse built-in facilities. This section: integrate well with other projects, ensure reliability and security.

Three hardening topics: well-defined configurations w/ well-defined behaviors; useful behavior from assert; proper macro use integrating vendor code and third party libraries.

### Configurations

Remove ambiguity: recognize two configurations, Release and Debug. Release = production code on live servers, requested via C/C++ `NDEBUG` macro; only macro observed by C and C++ Committees and Posix. Opposite: Debug. Though compelling argument for `!defined(NDEBUG)`, use explicit macro `DEBUG` for configuration: vendors and outside libraries use `DEBUG` (or similar). E.g., Carnegie Mellon's Mach kernel uses `DEBUG`, Microsoft's CRT uses `_DEBUG`, Wind River Workbench uses `DEBUG_MODE`.

Besides `NDEBUG` (Release) and `DEBUG` (Debug), two additional cross products: both defined, or neither. Both defined = error; neither defined = default to release. Below from ESAPI C++ EsapiCommon.h, configuration file used by all source files:

```c
// Only one or the other, but not both
##if (defined(DEBUG) || defined(_DEBUG)) && (defined(NDEBUG)
                                           || defined(_NDEBUG))
## error Both DEBUG and NDEBUG are defined.
##endif

// The only time we switch to debug is when asked.
// NDEBUG or {nothing} results
// in release build (fewer surprises at runtime).
##if defined(DEBUG) || defined(_DEBUG)
## define ESAPI_BUILD_DEBUG 1
##else
## define ESAPI_BUILD_RELEASE 1
##endif
```

`DEBUG` in effect → code gets full debug instrumentation, incl. full force of assertions.

### ASSERT

Asserts create self-debugging code: find point of first failure quickly. Use throughout program: parameter validation, return value checking, program state. `assert` silently guards code through lifetime, always there even when not debugging a component. Thorough code coverage → less debugging time, more development: programs debug themselves.

Assert everything: parameters on function entry, function call return values, any program state. Every `if` for validation/checking → also an assert. Every `assert` for validation/checking → also an `if` statement. Go hand-in-hand.

Still using `printf`'s → room to improve. Writing `printf` or `NSLog` takes as long as writing an `assert`. `printf`/`NSLog` often removed when no longer needed; `assert` stays active forever. Goal: find point of first failure quickly.

One problem: Posix states `assert` should call `abort()` if `NDEBUG` is **not** defined. When debugging `NDEBUG` never defined (want "program diagnostics", Posix quote). Makes `assert` + `abort()` useless for development. Result: disuse; developers don't use them. Bad for community: self-debugging programs eradicate many stability problems.

Supply own assert and signal handler w/ improved behavior: exchange auto-aborting for auto-debugging. Debugger snaps when problem detected; find point of first failure quickly.

ESAPI C++ supplies own assert w/ this behavior. Below, `ASSERT` raises `SIGTRAP` when in effect, else evaluates to `void`.

```c
// A debug assert which should be sprinkled liberally.
// This assert fires and then continues rather
// than calling abort(). Useful when examining negative
// test cases from the command-line.
##if (defined(ESAPI_BUILD_DEBUG) && defined(ESAPI_OS_STARNIX))
##  define ESAPI_ASSERT1(exp) {                                    \
    if(!(exp)) {                                                  \
        std::ostringstream oss;                                     \
        oss << "Assertion failed: " << (char*)(__FILE__) << "("     \
            << (int)__LINE__ << "): " << (char*)(__func__)          \
            << std::endl;                                           \
        std::cerr << oss.str();                                     \
        raise(SIGTRAP);                                             \
    }                                                             \
    }
##  define ESAPI_ASSERT2(exp, msg) {                               \
    if(!(exp)) {                                                  \
        std::ostringstream oss;                                     \
        oss << "Assertion failed: " << (char*)(__FILE__) << "("     \
            << (int)__LINE__ << "): " << (char*)(__func__)          \
            << ": \"" << (msg) << "\"" << std::endl;                \
        std::cerr << oss.str();                                     \
        raise(SIGTRAP);                                             \
    }                                                             \
    }
##elif (defined(ESAPI_BUILD_DEBUG) && defined(ESAPI_OS_WINDOWS))
##  define ESAPI_ASSERT1(exp)      assert(exp)
##  define ESAPI_ASSERT2(exp, msg) assert(exp)
##else
##  define ESAPI_ASSERT1(exp)      ((void)(exp))
##  define ESAPI_ASSERT2(exp, msg) ((void)(exp))
##endif

##if !defined(ASSERT)
##  define ASSERT(exp)     ESAPI_ASSERT1(exp)
##endif
```

At startup, `SIGTRAP` handler installed if none provided by another component:

```c
    struct DebugTrapHandler
    {
      DebugTrapHandler()
      {
        struct sigaction new_handler, old_handler;

        do
          {
            int ret = 0;

            ret = sigaction (SIGTRAP, NULL, &old_handler);
            if (ret != 0) break; // Failed

            // Don't step on another's handler
            if (old_handler.sa_handler != NULL) break;

            new_handler.sa_handler = &DebugTrapHandler::NullHandler;
            new_handler.sa_flags = 0;

            ret = sigemptyset (&new_handler.sa_mask);
            if (ret != 0) break; // Failed

            ret = sigaction (SIGTRAP, &new_handler, NULL);
            if (ret != 0) break; // Failed

          } while(0);
      }

      static void NullHandler(int /*unused*/) { }

    };

    // We specify a relatively low priority, to make sure we run before other CTORs
    // http://gcc.gnu.org/onlinedocs/gcc/C_002b_002b-Attributes.html#C_002b_002b-Attributes
    static const DebugTrapHandler g_dummyHandler __attribute__ ((init_priority (110)));
```

Windows: call `_set_invalid_parameter_handler` (and possibly `set_unexpected` or `set_terminate`) to install new handler.

Live hosts running production code always define `NDEBUG` (release configuration): no assert, no auto-abort. Auto-abortion unacceptable; asking for it abuses "program diagnostics". Program wanting core dump should create dump, not crash.

Further reading on effective asserting: John Robbin's books, e.g. _Debugging Applications_. Legendary Windows bug slayer; covers simple program debugging to multithreaded bug slaying.

### Additional Macros

Macros needed to integrate properly and securely: with platform (e.g. MFC or Cocoa/CocoaTouch) and libraries (e.g., Crypto++ or OpenSSL). Challenging: need proficiency w/ platform and all included libraries and frameworks. List below shows needed level of detail.

Boost missing from list: appears to lack recommendations, additional debug diagnostics, hardening guide. See _BOOST Hardening Guide (Preprocessor Macros)_. Tim Day also points to _[boost.build] should we not define _SECURE_SCL=0 by default for all msvc toolsets_ for recent hardening discussion.

Besides what to define, defining some macros and undefining others should trigger security defect. E.g., `-U_FORTIFY_SOURCES` on Linux and `_CRT_SECURE_NO_WARNINGS=1`, `_SCL_SECURE_NO_WARNINGS`, `_ATL_SECURE_NO_WARNINGS` or `STRSAFE_NO_DEPRECATE` on Windows.

![AdditionalPlatformLibraryMacrosTable](../assets/C-Based_Toolchain_Hardening_AdditionalPlatformLibraryMacrosTable.png)

a) Careful w/ `_GLIBCXX_DEBUG` using pre-compiled libraries such as Boost from distribution: ABI incompatibilities, likely crash. Compile Boost w/ `_GLIBCXX_DEBUG` or omit `_GLIBCXX_DEBUG`.

b) See Chapter 5, Diagnostics of libstdc++ manual.

c) SQLite secure deletion zeroizes memory on destruction. Define as required; always define in US Federal: zeroization required for FIPS 140-2, Level 1.

d) _N_ is 0644 by default: everyone has some access.

e) Force temporary tables into memory (no unencrypted data to disk).

## Compiler and Linker

Compilers provide rich warnings from code analysis. GCC and Visual Studio both have static analysis to find mistakes early. Built-in static analysis usually sufficient for proper API usage and catching mistakes such as uninitialized variable use or comparing negative signed int to positive unsigned int.

Concrete example (C/C++ promotion rules): warning issued if signed integer promoted to unsigned then compared, since side effect is `-1 > 1` after promotion! GCC and Visual Studio currently won't catch e.g. SQL injections and other tainted data usage; need tool doing data flow or taint analysis.

Some in development community resist static analysis or refute results. E.g., static analysis warned Linux kernel's `sys_prctl` compared unsigned value against less than zero; Jesper Juhl offered cleanup patch. Linus Torvalds howled "No, you don't do this… GCC is crap" (re compiling w/ warnings). Full discussion: _[PATCH] Don't compare unsigned variable for &lt;0 in sys_prctl()_ on Linux Kernel mailing list.

Following sections cover three platforms: typical GNU Linux distribution w/ GCC and Binutils; Clang and Xcode; modern Windows.

### Distribution Hardening

Some defenses below already present in distributions. Design by committee: usually only mild variation of what's available (everyone mildly offended). For performance worriers: you may already have taken the small performance hit unknowingly.

Linux and BSD distributions often apply some hardening unprompted via _GCC Spec Files_. Debian, Ubuntu, Linux Mint and family: _Debian Hardening_. Red Hat and Fedora: _New hardened build support (coming) in F16_. Gentoo: _Hardened Gentoo_.

View distribution settings via `gcc` `-dumpspecs`. Linux Mint 12 below: `-fstack-protector` (not -fstack-protector-all) used by default.

```bash
$ gcc -dumpspecs
…
*link_ssp: %{fstack-protector:}

*ssp_default: %{!fno-stack-protector:%{!fstack-protector-all:
              %{!ffreestanding:%{!nostdlib:-fstack-protector}}}}
…
```

"SSP" = Stack Smashing Protector. Reimplementation of Hiroaki Etoh's work on IBM Pro Police Stack Detector. See Etoh's patch _gcc stack-smashing protector_ and IBM's _GCC extension for protecting applications from stack-smashing attacks_.

### GCC/Binutils

GCC (compiler collection) and Binutils (assemblers, linkers, other tools): separate projects producing final executable together. Compiler and linker both offer options for safer, more secure code. Linker produces code using platform security features from kernel and PaX, such as no-exec stacks and heaps (NX) and Position Independent Executable (PIE).

Table below: compiler options for building program. Static analysis warnings catch mistakes early; linker options harden executable at runtime. "GCC" in table loosely = "non-ancient distributions." GCC team considers 4.2 ancient, but still encountered on Apple and BSD platforms due to GPL licensing changes around 2007. See _GCC Option Summary_, _Options to Request or Suppress Warnings_, _Binutils (LD) Command Line Options_ for usage.

Special mention: `-fno-strict-overflow` and `-fwrapv`ₐ. Flags ensure compiler doesn't remove statements that overflow or wrap. Program correct only with the flags → likely violates C/C++ overflow rules, illegal. If illegal due to overflow or wrap checking, consider safe-iop for C or David LeBlanc's SafeInt in C++.

Hardened-settings builds: verify some settings with Checksec tool (Tobias Klein). `checksec.sh` tests standard Linux OS and PaX security features used by an application. See Trapkit web page.

GCC C Warning Options table:

![GCCCWarningOptionsTable](../assets/C-Based_Toolchain_Hardening_GCCCWarningOptionsTable.png)

- AddressSanitizer
- ThreadSanitizer

a) Unlike Clang and -Weverything, GCC has no switch truly enabling all warnings.
b) -fstack-protector guards functions with high risk objects such as C strings; -fstack-protector-all guards all objects.

Additional C++ warnings in Table 3. See _GCC's Options Controlling C++ Dialect_.

GCC C++ Warning Options table:

![GCCCPPWarningOptionsTable](../assets/C-Based_Toolchain_Hardening_GCCCPPWarningOptionsTable.png)

Effective C++, Second Edition book.

Additional useful Objective C warnings. See _Options Controlling Objective-C and Objective-C++ Dialects_.

GCC Objective C Warning Options table:

![GCCObjectiveCWarningOptionsTable](../assets/C-Based_Toolchain_Hardening_GCCObjectiveCWarningOptionsTable.png)

Aggressive warnings produce spurious noise: tradeoff, learn of potential problems at cost of wading through chaff. Reduce noise with:

- `-Wno-unused-parameter` (GCC)
- `-Wno-type-limits` (GCC 4.3)
- `-Wno-tautological-compare` (Clang)

Simple version-based makefile example below. Differs from feature-based makefile produced by Autotools (tests for feature, defines symbol or configures template file). Not all platforms use all options and flags. Two strategies: ship weakened posture serving lowest common denominator; or ship with everything in force. Latter: users lacking a feature edit makefile to fit installation.

```bash
CXX=g++
EGREP = egrep
…

GCC_COMPILER = $(shell $(CXX) -v 2>&1 | $(EGREP) -i -c '^gcc version')
GCC41_OR_LATER = $(shell $(CXX) -v 2>&1 | $(EGREP) -i -c '^gcc version (4\.[1-9]|[5-9])')
…

GNU_LD210_OR_LATER = $(shell $(LD) -v 2>&1 | $(EGREP) -i -c '^gnu ld .* (2\.1[0-9]|2\.[2-9])')
GNU_LD214_OR_LATER = $(shell $(LD) -v 2>&1 | $(EGREP) -i -c '^gnu ld .* (2\.1[4-9]|2\.[2-9])')
…

ifeq ($(GCC_COMPILER),1)
    MY_CC_FLAGS += -Wall -Wextra -Wconversion
    MY_CC_FLAGS += -Wformat=2 -Wformat-security
    MY_CC_FLAGS += -Wno-unused-parameter
endif

ifeq ($(GCC41_OR_LATER),1)
    MY_CC_FLAGS += -fstack-protector-all
endif

ifeq ($(GCC42_OR_LATER),1)
    MY_CC_FLAGS += -Wstrict-overflow
endif

ifeq ($(GCC43_OR_LATER),1)
    MY_CC_FLAGS += -Wtrampolines
endif

ifeq ($(GNU_LD210_OR_LATER),1)
    MY_LD_FLAGS += -z,nodlopen -z,nodump
endif

ifeq ($(GNU_LD214_OR_LATER),1)
    MY_LD_FLAGS += -z,noexecstack -z,noexecheap
endif

ifeq ($(GNU_LD215_OR_LATER),1)
    MY_LD_FLAGS += -z,relro -z,now
endif

ifeq ($(GNU_LD216_OR_LATER),1)
    MY_CC_FLAGS += -fPIE
    MY_LD_FLAGS += -pie
endif

## Use 'override' to honor the user's command line
override CFLAGS := $(MY_CC_FLAGS) $(CFLAGS)
override CXXFLAGS := $(MY_CC_FLAGS) $(CXXFLAGS)
override LDFLAGS := $(MY_LD_FLAGS) $(LDFLAGS)
…
```

### Clang/Xcode

Clang and LLVM aggressively developed since Apple lost its GPL compiler in 2007 (Tivoization → GPLv3). Since then, developers and Google joined. Clang consumes most (all?) GCC/Binutil flags and switches, plus own options incl. static analyzer. Relatively easy to build w/ additional diagnostics, e.g. Dr. John Regher and Peng Li's Integer Overflow Checker (IOC).

IOC very useful; found bugs in Linux Kernel (`include/linux/bitops.h`, still unfixed), SQLite, PHP, Firefox (many still unfixed), LLVM, Python. Clang 3.3 and above enable checks out of box w/ `-fsanitize=integer` and `-fsanitize=shift`.

Clang options: Clang Compiler User's Manual. Clang has option enabling all warnings: `-Weverything`. Use with care but regularly: much noise plus missed issues. E.g., add `-Weverything` for production builds, make non-spurious issues quality gate. Xcode: add `-Weverything` to `CFLAGS` and `CXXFLAGS`.

Beyond warnings, static analysis and extra security checks possible. See Clang Static Analyzer. Figure 1 shows some security checks used by Xcode.

![XCode1](../assets/C-Based_Toolchain_Hardening_XCode1.png)

### Visual Studio

Convenient IDE managing solutions and settings. "Visual Studio Options" section: options to use; "Project Properties" section: incorporating them into solution's project.

Table below: compiler and linker switches to use under Visual Studio. See Howard and LeBlanc's Writing Secure Code (Microsoft Press) or _Protecting Your Code with Visual C++ Defenses_ in Security Briefs by Michael Howard. "Visual Studio" = nearly all versions, incl. Visual Studio 5.0 and 6.0.

Hardened-settings builds verifiable with BinScope: Microsoft tool analyzing binaries for compliance w/ Microsoft's Security Development Lifecycle (SDLC) requirements and recommendations. See BinScope Binary Analyzer download page.

![VStudioWarningOptionsTable](../assets/C-Based_Toolchain_Hardening_VStudioWarningOptionsTable.png)

a) See Jon Sturgeon's discussion of the switch: _Off By Default Compiler Warnings in Visual C++_.

a) With /GS, several circumstances affect security cookie inclusion. E.g., guard not used if no buffer in stack frame, optimizations disabled, or function declared naked or contains inline assembly.

b) `#pragma` `strict_gs_check(on)` use sparingly, but recommended in high risk situations, e.g. source file parsing internet input.

### Warning Suppression

Many warnings enabled to detect possible programming mistakes; compiler carries much contextual info during analysis. Sometimes spurious warnings: compiler not _that_ smart. Understandable, even good (out of a job if programs write own programs). Learn to work with compiler's warning system to suppress warnings. Not said: turn off the warnings.

Suppressing placates compiler on spurious noise so you reach issues that matter (wheat from chaff). Hints and minefields follow. First: unused parameter (e.g., `argc` or `argv`). Suppressing unused parameter warnings esp. helpful for C++ and interface programming, where parameters often unused. Define "UNUSED" macro, wrap parameter:

```c
##define UNUSED_PARAMETER(x) ((void)x)
…

int main(int argc, char* argv[])
{
    UNUSED_PARAMETER(argc);
    UNUSED_PARAMETER(argv);
    …
}
```

Minefield: "comparing unsigned and signed" values; `-Wconversion` catches it. C/C++ promotion rules: signed value promoted to unsigned, then compared. So `-1` `>` `1` after promotion! Can't blindly cast; first range test the value:

```c
int x = GetX();
unsigned int y = GetY();

ASSERT(x >= 0);
if(!(x >= 0))
    throw runtime_error("WTF??? X is negative.");

if(static_cast<unsigned int>(x) > y)
    cout << "x is greater than y" << endl;
else
    cout << "x is not greater than y" << endl;
```

Code above debugs itself: no breakpoint needed to see problem with `x`. Run program, wait for report. On problem, program snaps debugger (and, more importantly, doesn't call useless `abort()` as Posix specifies). Beats `printf`s removed when no longer needed or polluting outputs.

Another conversion problem: between types; `-Wconversion` also catches it. Following can always fail, lights up like Christmas tree:

```c
struct sockaddr_in addr;
…

addr.sin_port = htons(atoi(argv[2]));
```

Following serves much better. `atoi` and friends not used: can silently fail. Code instrumented so no wasted debugging time. Check 16-bit transport port range before narrowing value; maximum value of `unsigned int` may be larger than port can represent.

```c
const char* cstr = GetPortString();

ASSERT(cstr != NULL);
if(!(cstr != NULL))
    throw runtime_error("WTF??? Port string is not valid.");

istringstream iss(cstr);
long long t = 0;
iss >> t;

ASSERT(!(iss.fail()));
if(iss.fail())
    throw runtime_error("WTF??? Failed to read port.");

// Should this be a port above the reserved range ([0-1024] on Unix)?
ASSERT(t > 0);
if(!(t > 0))
    throw runtime_error("WTF??? Port is too small");

ASSERT(t <= 65535);
if(!(t <= 65535))
    throw runtime_error("WTF??? Port is too large");

// OK to use port
unsigned short port = static_cast<unsigned short>(t);
…
```

Again code debugs itself: no breakpoint needed to see problem with `port`. Keeps checking conditions years after instrumented (assuming config-file-reading code written early in project). No need to remove `ASSERT`s as with `printf`: silent guardians.

Another suppression trick: don't ignore return values. Useful for suppressing warning and required for correct code. E.g., `snprint` signals truncation via return value. Don't make silent truncations by ignoring warning or casting to `void`:

```c
char path[PATH_MAX];
…

int ret = snprintf(path, sizeof(path), "%s/%s", GetDirectory(), GetObjectName());
ASSERT(ret != -1);
ASSERT(!(ret >= sizeof(path)));

if(ret == -1 || ret >= sizeof(path))
    throw runtime_error("WTF??? Unable to build full object name");

// OK to use path
…
```

Problem pandemic, not just boring user-land programs. High integrity projects such as SELinux suffer silent truncations. Following from approved SELinux patch, though comment noted silent truncations in its `security_compute_create_name` function from `compute_create.c`.

```c
12  int security_compute_create_raw(security_context_t scon,
13                                  security_context_t tcon,
14                                  security_class_t   tclass,
15                                  security_context_t * newcon)
16  {
17    char path[PATH_MAX];
18    char *buf;
19    size_t size;
20    int fd, ret;
21
22    if (!selinux_mnt) {
23      errno = ENOENT;
24      return -1;
25    }
26
27    snprintf(path, sizeof path, "%s/create", selinux_mnt);
28    fd = open(path, O_RDWR);
```

Unlike other examples, above code won't debug itself; must set breakpoints and trace calls for point of first failure. (And it gambles that truncated file doesn't exist or isn't adversary-controlled, blindly performing the `open`).

## Runtime

Earlier sections: set up project for success. This section: hints for running w/ increased diagnostics and defenses. Platforms unequal: GNU Linux difficult to impossible to add hardening to program after compiling and static linking; Windows allows post-build hardening through download. Goal: find point of first failure quickly to improve reliability and security.

### Xcode

Xcode offers Code Diagnostics for memory errors and object use problems. Manage schemes via _Products_ menu item, _Scheme_ submenu item, then _Edit_. In editor, go to _Diagnostics_ tab. Figure below: four additional instruments enabled for debugging cycle: Scribble guards, Edge guards, Malloc guards, Zombies.

![XCode2](../assets/C-Based_Toolchain_Hardening_XCode2.png)

Caveat: Apple provides some guards only for simulator, not device. Previously available for both.

#### Windows

Visual Studio offers debugging aids during development: Managed Debugging Assistants (MDAs). Find on _Debug_ menu, _Exceptions_ submenu. MDAs tune debugging, e.g. filter exceptions debugger snaps on. See Stephen Toub's _Let The CLR Find Bugs For You With Managed Debugging Assistants_.

![Windows1](../assets/C-Based_Toolchain_Hardening_Windows1.png)

Runtime hardening: Microsoft provides **Windows Defender Exploit Guard** and **Process Mitigation Management Tool**.  
Windows Defender Exploit Guard replaces EMET, offers advanced exploit protection.  

Process Mitigation Management Tool (`ProcessMitigations` module) lets administrators configure exploit mitigation policies via PowerShell and Group Policy.

![Windows2](../assets/C-Based_Toolchain_Hardening_Windows2.png)

## References

- GCC: Instrumentation Options
- Clang Compiler User’s Manual
- Microsoft: Security Best Practices for C++
