Most [suckless.org](https://suckless.org) software comes with basic functionality which can be _extended_ by applying code _patches_. This typically involves a fair deal of tinkering on behalf of the end user especially when applying more than one patch.

The _flexipatch_ builds have a different take on patching where preprocessor directives are used to decide whether or not to include a patch during build time. This means, for better or worse, that the code contains both the patched and the original code. The aim being that you can pick and mix your patches from a configuration file and just compile.

The _flexipatch-finalizer_ is a custom pre-processor that uses the same configuration file and strips a flexipatch build of any unused code, leaving a build of the software with the selected patches applied.

Example flexipatch builds this finalizer can be used with:

   - [dwm-flexipatch](https://github.com/bakkeby/dwm-flexipatch)
   - [dmenu-flexipatch](https://github.com/bakkeby/dmenu-flexipatch)
   - [st-flexipatch](https://github.com/bakkeby/st-flexipatch)
   - [slock-flexipatch](https://github.com/bakkeby/slock-flexipatch)

:warning: Do make sure that you make a backup of your flexipatch build and your `patches.h` configuration file before running this script.

:warning: This script alters and removes files within the given source directory.

:warning: This process is irreversible.


Example usage:

```
$ ./flexipatch-finalizer.sh
Usage: flexipatch-finalizer.sh [OPTION?]

This is a custom pre-processor designed to remove unused flexipatch patches and create a final build.

  -r, --run                      include this flag to confirm that you really do want to run this script

  -d, --directory <dir>          the flexipatch directory to process (defaults to current directory)
  -o, --output <dir>             the output directory to store the processed files
  -h, --help                     display this help section
  -k, --keep                     keep temporary files and do not replace the original ones
  -e, --echo                     echo commands that will be run rather than running them
      --debug                    prints additional debug information to stderr

Warning! This script alters and removes files within the source directory.
Warning! This process is irreversible! Use with care. Do make a backup before running this.

$ ./flexipatch-finalizer.sh -r -d /path/to/dwm-flexipatch
$
```

Example end diff having VERTCENTER_PATCH enabled for st.

```diff
...
/* Purely graphic info */                                       /* Purely graphic info */
typedef struct {                                                typedef struct {
        int tw, th; /* tty width and height */                          int tw, th; /* tty width and height */
        int w, h; /* window width and height */                         int w, h; /* window width and height */
        #if ANYSIZE_PATCH                                     <
        int hborderpx, vborderpx;                             <
        #endif // ANYSIZE_PATCH                               <
        int ch; /* char height */                                       int ch; /* char height */
        int cw; /* char width  */                                       int cw; /* char width  */
        #if VERTCENTER_PATCH                                  <
        int cyo; /* char y offset */                                    int cyo; /* char y offset */
        #endif // VERTCENTER_PATCH                            <
        int mode; /* window state/mode flags */                         int mode; /* window state/mode flags */
        int cursor; /* cursor style */                                  int cursor; /* cursor style */
        #if VISUALBELL_2_PATCH || VISUALBELL_3_PATCH          <
        int vbellset; /* 1 during visual bell, 0 otherwise */ <
        struct timespec lastvbell;                            <
        #endif // VISUALBELL_2_PATCH                          <
} TermWindow;                                                   } TermWindow;
...
```
