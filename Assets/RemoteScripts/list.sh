# cb_ls: one folder listing for Chatbook's remote folder picker (format ACPLS1). POSIX sh, shell builtins only (no
# external programs), so GNU/BSD differences don't matter. Output: NUL-terminated fields "tag:value" (values may contain
# any byte but NUL; file names can't contain NUL):
#   v:1:<nonce>               format version and the request's nonce (anything before it, e.g. text printed by the
#                             remote shell's startup files, is ignored)
#   h:<$HOME>                 the remote home folder
#   q:<path>                  the requested folder after ~ and relative-path resolution
#   s:<status>                ok | missing | notdir | access | unreadable | badpath
#   a:<path>                  (fallback mode) the requested folder can't be opened: the next s: is about this folder
#                             above it, and so on up to the first one that can be opened (or /)
#   p:<logical path>          $PWD after cd -L (only when the cd worked)
#   r:<physical path>         pwd -P
#   <kind>:<name>             one entry; kind: d (folder) f (file) o (other: fifo, socket, device) b (broken link),
#                             plus l (a symbolic link) and x (a folder that can't be opened or listed)
#   c:<d> <hd> <f> <hf>       entries seen: folders, hidden folders, other entries, hidden other entries
#   xd:<n> / xf:<n>           only the first n folders / other entries were looked at (their counts are lower bounds)
#   w:unlisted                the folder looked empty, but ls could not read it (e.g. macOS privacy protection)
#   e:                        the end (the listing is complete)
# Folders come first (their own pass, with the pattern */, which matches folders and links to folders only), so that a
# folder with very many files still lists all its subfolders.
# Arguments: nonce, path, base (for relative paths; empty: $HOME), max folders listed per class (hidden or not), max other
# entries listed per class, max folders looked at, max other entries looked at, fallback (1: list the nearest folder
# above the requested one that can be opened, if the requested one can't be). Runs in a subshell: the cd, set +f, LC_ALL and
# the ls_ variables don't leak (the remote script prelude runs with set -f).
cb_ls() (
    ls_v=$1; ls_q=$2; ls_b=$3; ls_md=$4; ls_mf=$5; ls_sd=$6; ls_sf=$7; ls_up=$8
    LC_ALL=C
    export LC_ALL
    unset CDPATH
    printf 'v:1:%s\000h:%s\000' "$ls_v" "$HOME"
    case $ls_q in
        '~') ls_q=$HOME;;
        '~/'*) ls_q=$HOME/${ls_q#??};;
        /*) ;;
        *) ls_q=${ls_b:-$HOME}/$ls_q;;
    esac
    printf 'q:%s\000' "$ls_q"
    case $ls_q in
        /*) ;;
        *) printf 's:badpath\000e:\000'; exit 0;;
    esac
    ls_t=$ls_q
    while ! cd -L "$ls_t" 2>/dev/null >/dev/null; do
        if [ -d "$ls_t" ]; then ls_s=access
        elif [ -e "$ls_t" ]; then ls_s=notdir
        else ls_s=missing
        fi
        printf 's:%s\000' "$ls_s"
        if [ "$ls_up" != 1 ] || [ "$ls_t" = / ]; then printf 'e:\000'; exit 0; fi
        # fallback: the nearest folder above it that can be opened
        while :; do case $ls_t in ?*/) ls_t=${ls_t%/};; *) break;; esac; done
        ls_t=${ls_t%/*}
        if [ -z "$ls_t" ]; then ls_t=/; fi
        printf 'a:%s\000' "$ls_t"
    done
    # pwd -P's output ends in one newline; the "." keeps a name that ends in newlines intact
    ls_r=$(pwd -P 2>/dev/null && printf .)
    ls_r=${ls_r%.}
    ls_r=${ls_r%?}
    if [ ! -r . ]; then
        printf 's:unreadable\000p:%s\000r:%s\000e:\000' "$PWD" "$ls_r"
        exit 0
    fi
    printf 's:ok\000p:%s\000r:%s\000' "$PWD" "$ls_r"
    set +f
    ls_n=0; ls_d=0; ls_hd=0
    for ls_e in */ .[!.]*/ ..?*/; do
        ls_e=${ls_e%/}
        if [ ! -d "$ls_e" ]; then continue; fi    # the pattern itself when nothing matched
        ls_n=$((ls_n + 1))
        if [ "$ls_n" -gt "$ls_sd" ]; then printf 'xd:%s\000' "$ls_sd"; break; fi
        ls_t=d
        if [ -L "$ls_e" ]; then ls_t=dl; fi
        if [ ! -x "$ls_e" ] || [ ! -r "$ls_e" ]; then ls_t=${ls_t}x; fi
        case $ls_e in
            .*) ls_hd=$((ls_hd + 1)); ls_c=$ls_hd;;
            *) ls_d=$((ls_d + 1)); ls_c=$ls_d;;
        esac
        if [ "$ls_c" -le "$ls_md" ]; then printf '%s:%s\000' "$ls_t" "$ls_e"; fi
    done
    ls_n=0; ls_f=0; ls_hf=0
    for ls_e in * .[!.]* ..?*; do
        if [ -d "$ls_e" ]; then continue; fi
        if [ -L "$ls_e" ]; then
            if [ -e "$ls_e" ]; then ls_t=fl; else ls_t=b; fi
        elif [ -f "$ls_e" ]; then ls_t=f
        elif [ -e "$ls_e" ]; then ls_t=o
        else continue                              # the pattern itself when nothing matched
        fi
        ls_n=$((ls_n + 1))
        if [ "$ls_n" -gt "$ls_sf" ]; then printf 'xf:%s\000' "$ls_sf"; break; fi
        case $ls_e in
            .*) ls_hf=$((ls_hf + 1)); ls_c=$ls_hf;;
            *) ls_f=$((ls_f + 1)); ls_c=$ls_f;;
        esac
        if [ "$ls_c" -le "$ls_mf" ]; then printf '%s:%s\000' "$ls_t" "$ls_e"; fi
    done
    # nothing found: make sure the folder could really be read (macOS privacy protection lets [ -r ] pass for ~/Documents
    # and others, but reading them over ssh fails; ls says so with its exit code)
    if [ "$((ls_d + ls_hd + ls_f + ls_hf))" -eq 0 ] && ! ls -a . >/dev/null 2>&1; then printf 'w:unlisted\000'; fi
    printf 'c:%s %s %s %s\000e:\000' "$ls_d" "$ls_hd" "$ls_f" "$ls_hf"
)
