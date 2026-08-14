{ config, ... }:
let
  coreModule = config.flake.modules.homeManager.core;

  targetModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dendriticSlop;
      takeoverScript = pkgs.writeShellScript "dendritic-slop-global-skills-takeover" ''
        set -euo pipefail

        state_root="$HOME/.local/state/dendritic-slop/global-skills"
        journal="$state_root/journal"
        backup_root="$state_root/backups"
        completed="$state_root/completed"
        lock_dir="$state_root/lock"
        agents_root="$HOME/.agents"

        fail() {
          printf 'dendritic-slop global skills takeover: %s\n' "$*" >&2
          exit 1
        }

        path_exists() {
          test -e "$1" || test -L "$1"
        }

        fingerprint() {
          local path="$1"
          local digest
          if test -L "$path"; then
            digest="$({ printf 'symlink\0'; ${pkgs.coreutils}/bin/readlink "$path"; } | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)"
            printf 'symlink:%s\n' "$digest"
          elif test -f "$path"; then
            digest="$(${pkgs.coreutils}/bin/sha256sum "$path" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)"
            printf 'file:%s\n' "$digest"
          elif test -d "$path"; then
            digest="$(${pkgs.gnutar}/bin/tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu -cf - -C "$path" . | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)"
            printf 'directory:%s\n' "$digest"
          else
            fail "unsupported filesystem object at $path"
          fi
        }

        atomic_marker() {
          local path="$1"
          local value="''${2:-completed}"
          local temporary="$path.tmp.$$"
          printf '%s\n' "$value" > "$temporary"
          ${pkgs.coreutils}/bin/mv -T -- "$temporary" "$path"
        }

        maybe_stop() {
          if test "''${DENDRITIC_SLOP_TEST_STOP_AFTER:-}" = "$1"; then
            printf 'injected stop after %s\n' "$1" >&2
            exit 75
          fi
        }

        source_for() {
          case "$1" in
            skills) printf '%s\n' "$agents_root/skills" ;;
            skill-lock) printf '%s\n' "$agents_root/.skill-lock.json" ;;
            *) fail "unknown journal path $1" ;;
          esac
        }

        destination_for() {
          case "$1" in
            skills) printf '%s\n' "$backup_root/skills" ;;
            skill-lock) printf '%s\n' "$backup_root/.skill-lock.json" ;;
            *) fail "unknown journal path $1" ;;
          esac
        }

        atomic_rename_noreplace() {
          local source="$1"
          local destination="$2"
          local id="$3"
          local allow_forced_exdev="$4"
          ${pkgs.python3}/bin/python3 - "$source" "$destination" "$id" "$allow_forced_exdev" <<'PY'
        import ctypes
        import errno
        import os
        import sys

        source, destination, path_id, allow_forced_exdev = sys.argv[1:]
        forced = os.environ.get("DENDRITIC_SLOP_TEST_FORCE_EXDEV", "")
        if allow_forced_exdev == "true" and forced in ("all", path_id):
            raise SystemExit(18)

        libc = ctypes.CDLL(None, use_errno=True)
        source_bytes = os.fsencode(source)
        destination_bytes = os.fsencode(destination)

        if sys.platform == "darwin":
            rename = libc.renamex_np
            rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
            rename.restype = ctypes.c_int
            result = rename(source_bytes, destination_bytes, 0x00000004)  # RENAME_EXCL
        elif sys.platform.startswith("linux"):
            rename = libc.renameat2
            rename.argtypes = [
                ctypes.c_int,
                ctypes.c_char_p,
                ctypes.c_int,
                ctypes.c_char_p,
                ctypes.c_uint,
            ]
            rename.restype = ctypes.c_int
            result = rename(-100, source_bytes, -100, destination_bytes, 1)  # RENAME_NOREPLACE
        else:
            print(f"atomic no-replace rename is unsupported on {sys.platform}", file=sys.stderr)
            raise SystemExit(1)

        if result != 0:
            error_number = ctypes.get_errno()
            if error_number == errno.EXDEV:
                raise SystemExit(18)
            if error_number in (errno.EEXIST, errno.ENOTEMPTY):
                raise SystemExit(17)
            error = OSError(error_number, os.strerror(error_number), destination)
            print(f"atomic no-replace rename failed: {error}", file=sys.stderr)
            raise SystemExit(1)
        PY
        }

        pause_after_ready() {
          local point="$1"
          if test "''${DENDRITIC_SLOP_TEST_PAUSE_AFTER_READY:-}" = "$point"; then
            test -n "''${DENDRITIC_SLOP_TEST_READY_SIGNAL:-}" \
              || fail "race fixture is missing its ready signal path"
            test -n "''${DENDRITIC_SLOP_TEST_RELEASE_SIGNAL:-}" \
              || fail "race fixture is missing its release signal path"
            printf 'ready\n' > "$DENDRITIC_SLOP_TEST_READY_SIGNAL"
            while ! path_exists "$DENDRITIC_SLOP_TEST_RELEASE_SIGNAL"; do
              ${pkgs.coreutils}/bin/sleep 0.01
            done
          fi
        }

        remove_original() {
          local source="$1"
          local expected="$2"
          test "$(fingerprint "$source")" = "$expected" \
            || fail "refusing to remove changed transaction source $source"
          if test -d "$source" && ! test -L "$source"; then
            ${pkgs.coreutils}/bin/rm -rf --one-file-system -- "$source"
          else
            ${pkgs.coreutils}/bin/rm -f -- "$source"
          fi
          if path_exists "$source"; then
            fail "could not completely remove transaction source $source"
          fi
        }

        resume_cross_filesystem() {
          local id="$1"
          local source="$2"
          local destination="$3"
          local expected="$4"
          local temporary="$backup_root/.$id.transaction-copy"
          local copy_ready="$journal/steps/$id.copy-ready"
          local status

          if ! test -e "$copy_ready"; then
            if path_exists "$destination"; then
              fail "backup destination appeared before the copy was prepared: $destination"
            fi
            if path_exists "$temporary"; then
              if test "$(fingerprint "$temporary")" != "$expected"; then
                ${pkgs.coreutils}/bin/rm -rf --one-file-system -- "$temporary"
              fi
            fi
            if ! path_exists "$temporary"; then
              ${pkgs.coreutils}/bin/cp -a -- "$source" "$temporary"
            fi
            test "$(fingerprint "$temporary")" = "$expected" \
              || fail "cross-filesystem copy verification failed for $source"
            atomic_marker "$copy_ready"
            maybe_stop "$id-copy-ready"
          fi

          if path_exists "$temporary"; then
            path_exists "$destination" \
              && fail "both prepared and final backup paths exist for $id"
            pause_after_ready "$id-copy-ready"
            if atomic_rename_noreplace "$temporary" "$destination" "$id" false; then
              :
            else
              status=$?
              test "$status" -ne 17 \
                || fail "backup destination appeared during atomic publication: $destination"
              fail "atomic copy publication failed for $temporary"
            fi
          fi

          path_exists "$destination" || fail "prepared backup disappeared for $id"
          test "$(fingerprint "$destination")" = "$expected" \
            || fail "prepared backup changed for $id"
          if path_exists "$source"; then
            remove_original "$source" "$expected"
          fi
        }

        prepare_journal() {
          local temporary="$state_root/.journal.prepared.$$"
          local id source destination

          test ! -e "$journal" || fail "journal path already exists without a resumable transaction"
          ${pkgs.coreutils}/bin/mkdir -m 700 -p "$backup_root"
          ${pkgs.coreutils}/bin/chmod 700 "$backup_root"
          for id in skills skill-lock; do
            destination="$(destination_for "$id")"
            path_exists "$destination" \
              && fail "backup destination already exists: $destination"
          done

          ${pkgs.coreutils}/bin/mkdir -m 700 -p "$temporary/inventory" "$temporary/steps"
          printf '1\n' > "$temporary/version"
          for id in skills skill-lock; do
            source="$(source_for "$id")"
            if path_exists "$source"; then
              printf 'present %s\n' "$(fingerprint "$source")" > "$temporary/inventory/$id"
            else
              printf 'absent\n' > "$temporary/inventory/$id"
            fi
          done
          ${pkgs.coreutils}/bin/mv -T -- "$temporary" "$journal"
          maybe_stop prepared
        }

        resume_path() {
          local id="$1"
          local source destination presence expected actual status
          source="$(source_for "$id")"
          destination="$(destination_for "$id")"
          read -r presence expected < "$journal/inventory/$id"

          if test -e "$journal/steps/$id.done"; then
            path_exists "$source" \
              && fail "post-transaction content appeared at $source"
            if test "$presence" = present; then
              path_exists "$destination" || fail "completed backup is missing: $destination"
              test "$(fingerprint "$destination")" = "$expected" \
                || fail "completed backup changed: $destination"
            fi
            return
          fi

          if test "$presence" = absent; then
            path_exists "$source" \
              && fail "content appeared after the prepared inventory at $source"
            path_exists "$destination" \
              && fail "backup appeared for an absent inventory path: $destination"
            atomic_marker "$journal/steps/$id.done"
            maybe_stop "$id"
            return
          fi

          if test -e "$journal/steps/$id.cross-filesystem"; then
            resume_cross_filesystem "$id" "$source" "$destination" "$expected"
          elif path_exists "$destination"; then
            path_exists "$source" \
              && fail "refusing to overwrite post-transaction content at $source"
            test "$(fingerprint "$destination")" = "$expected" \
              || fail "backup destination contains unexpected content: $destination"
          else
            path_exists "$source" || fail "transaction source and backup are both missing for $id"
            actual="$(fingerprint "$source")"
            test "$actual" = "$expected" \
              || fail "transaction source changed after inventory: $source"
            atomic_marker "$journal/steps/$id.rename-ready"
            pause_after_ready "$id-rename-ready"
            if atomic_rename_noreplace "$source" "$destination" "$id" true; then
              :
            else
              status=$?
              if test "$status" -eq 18; then
                atomic_marker "$journal/steps/$id.cross-filesystem"
                resume_cross_filesystem "$id" "$source" "$destination" "$expected"
              elif test "$status" -eq 17; then
                fail "backup destination appeared during atomic publication: $destination"
              else
                fail "atomic rename failed for $source"
              fi
            fi
          fi

          maybe_stop "$id-transferred"
          path_exists "$source" \
            && fail "transaction source remains after backup: $source"
          path_exists "$destination" || fail "transaction backup is missing: $destination"
          test "$(fingerprint "$destination")" = "$expected" \
            || fail "transaction backup verification failed: $destination"
          atomic_marker "$journal/steps/$id.done"
          maybe_stop "$id"
        }

        validate_completed() {
          local id source destination presence expected target
          test -d "$journal" || fail "completed marker exists without its journal"
          for id in skills skill-lock; do
            test -e "$journal/steps/$id.done" || fail "completed marker has an incomplete $id step"
            read -r presence expected < "$journal/inventory/$id"
            if test "$presence" = present; then
              destination="$(destination_for "$id")"
              path_exists "$destination" || fail "completed backup is missing: $destination"
              test "$(fingerprint "$destination")" = "$expected" \
                || fail "completed backup changed: $destination"
            fi
          done

          source="$(source_for skill-lock)"
          if path_exists "$source"; then
            fail "post-migration collision at $source"
          fi

          source="$(source_for skills)"
          if path_exists "$source"; then
            if ! test -L "$source"; then
              fail "post-migration collision at $source"
            fi
            target="$(${pkgs.coreutils}/bin/readlink "$source")"
            case "$target" in
              ${builtins.storeDir}/*) ;;
              *) fail "post-migration symlink at $source is not Home Manager managed" ;;
            esac
          fi
        }

        ${pkgs.coreutils}/bin/mkdir -m 700 -p "$state_root"
        exec 9> "$state_root/lock.guard"
        ${pkgs.coreutils}/bin/chmod 600 "$state_root/lock.guard"
        if ! ${pkgs.flock}/bin/flock -n 9; then
          fail "another takeover is active"
        fi
        if test -d "$lock_dir"; then
          ${pkgs.coreutils}/bin/rmdir "$lock_dir" 2>/dev/null \
            || fail "stale lock directory contains unexpected content: $lock_dir"
        fi
        ${pkgs.coreutils}/bin/mkdir -m 700 "$lock_dir"
        trap '${pkgs.coreutils}/bin/rmdir "$lock_dir" 2>/dev/null || true' EXIT HUP INT TERM

        if test -e "$completed"; then
          validate_completed
          exit 0
        fi

        ${pkgs.coreutils}/bin/mkdir -p "$agents_root"
        test -d "$journal" || prepare_journal
        test "$(< "$journal/version")" = 1 || fail "unsupported takeover journal version"

        resume_path skills
        resume_path skill-lock
        atomic_marker "$completed"
      '';
    in
    {
      options = {
        dendriticSlop.migrations.globalSkills.takeOver = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Back up existing global skill-manager state before Home Manager takes ownership.";
        };

        dendriticSlopInternal.globalSkills.takeoverScript = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          internal = true;
        };
      };

      config = {
        dendriticSlopInternal.globalSkills.takeoverScript = takeoverScript;
        home.activation.dendriticSlopGlobalSkillsTakeOver = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
          lib.optionalString (cfg.enable && cfg.migrations.globalSkills.takeOver) ''
            $DRY_RUN_CMD ${takeoverScript}
          ''
        );
      };
    };
in
{
  dendriticSlopInternal.homeManagerTargets = [ targetModule ];
  flake.modules.homeManager.global-skills.imports = [
    coreModule
    targetModule
  ];
}
