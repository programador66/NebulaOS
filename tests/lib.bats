#!/usr/bin/env bats
load helpers

setup() {
  # shellcheck source=../scripts/lib.sh
  source "$NEBULA_ROOT/scripts/lib.sh"
  cd "$BATS_TEST_TMPDIR"
}

@test "backup_conflict moves real file" {
  echo original > f
  backup_conflict "$PWD/f"
  [ ! -e f ]
  [ "$(cat f.nebula-bak)" = original ]
}

@test "backup_conflict ignores symlink" {
  echo x > alvo
  ln -s alvo l
  backup_conflict "$PWD/l"
  [ -L l ]
  [ ! -e l.nebula-bak ]
}

@test "backup_conflict ignores missing path" {
  backup_conflict "$PWD/nada"
  [ ! -e nada.nebula-bak ]
}

@test "backup_conflict second backup gets epoch suffix" {
  echo velho > f.nebula-bak
  echo novo > f
  backup_conflict "$PWD/f"
  [ "$(cat f.nebula-bak)" = velho ]
  run bash -c 'ls f.nebula-bak.* | grep -E "^f\.nebula-bak\.[0-9]+$"'
  [ "$status" -eq 0 ]
}

@test "ini_set updates existing key" {
  printf '[a]\nvalue=X\n\n[b]\nvalue=Y\n' > c.conf
  ini_set c.conf b value Z
  run awk '/^\[b\]/{f=1;next} /^\[/{f=0} f&&/^value=/' c.conf
  [ "$output" = "value=Z" ]
  run awk '/^\[a\]/{f=1;next} /^\[/{f=0} f&&/^value=/' c.conf
  [ "$output" = "value=X" ]
}

@test "ini_set adds missing section" {
  printf '[a]\nvalue=X\n' > c.conf
  ini_set c.conf c k v
  [ "$(tail -n 2 c.conf)" = "$(printf '[c]\nk=v')" ]
  grep -qx 'value=X' c.conf
}

@test "ini_set adds missing key in existing section" {
  printf '[a]\nvalue=X\n\n[b]\nvalue=Y\n' > c.conf
  ini_set c.conf a novo 1
  run awk '/^\[a\]/{f=1;next} /^\[/{f=0} f&&/^novo=/' c.conf
  [ "$output" = "novo=1" ]
  grep -qx 'value=Y' c.conf
}

@test "ini_set creates file when missing" {
  ini_set novo.conf s k v
  [ "$(cat novo.conf)" = "$(printf '[s]\nk=v')" ]
}
