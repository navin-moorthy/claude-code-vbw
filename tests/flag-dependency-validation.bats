#!/usr/bin/env bats

load test_helper

setup() {
  setup_temp_dir
  create_test_config
  # session-start.sh needs SCRIPT_DIR to resolve plugin.json — create minimal structure
  mkdir -p "$TEST_TEMP_DIR/.claude-plugin"
  echo '{"version":"0.0.0-test"}' > "$TEST_TEMP_DIR/.claude-plugin/plugin.json"
  # Create minimal project structure so session-start doesn't bail early
  mkdir -p "$TEST_TEMP_DIR/.vbw-planning/phases/01-test"
}

teardown() {
  teardown_temp_dir
}

@test "flag-deps: no warnings when all flags default false" {
  cd "$TEST_TEMP_DIR"
  # Override SCRIPT_DIR by running from the test dir with the plugin.json
  run bash -c "SCRIPT_DIR='$TEST_TEMP_DIR' CLAUDE_CONFIG_DIR='$TEST_TEMP_DIR/.claude' bash '$SCRIPTS_DIR/session-start.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARNING"* ]]
}

@test "flag-deps: warns when v2_hard_gates without v2_hard_contracts" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_hard_gates = true | .v2_hard_contracts = false' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  run bash -c "SCRIPT_DIR='$TEST_TEMP_DIR' CLAUDE_CONFIG_DIR='$TEST_TEMP_DIR/.claude' bash '$SCRIPTS_DIR/session-start.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v2_hard_gates requires v2_hard_contracts"* ]]
}

@test "flag-deps: no warning when both v2_hard_gates and v2_hard_contracts enabled" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_hard_gates = true | .v2_hard_contracts = true' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  run bash -c "SCRIPT_DIR='$TEST_TEMP_DIR' CLAUDE_CONFIG_DIR='$TEST_TEMP_DIR/.claude' bash '$SCRIPTS_DIR/session-start.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"v2_hard_gates requires v2_hard_contracts"* ]]
}

@test "flag-deps: warns when v3_event_recovery without v3_event_log" {
  cd "$TEST_TEMP_DIR"
  jq '.v3_event_recovery = true | .v3_event_log = false' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  run bash -c "SCRIPT_DIR='$TEST_TEMP_DIR' CLAUDE_CONFIG_DIR='$TEST_TEMP_DIR/.claude' bash '$SCRIPTS_DIR/session-start.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v3_event_recovery requires v3_event_log"* ]]
}

@test "flag-deps: warns when v2_two_phase_completion without v3_event_log" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_two_phase_completion = true | .v3_event_log = false' .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  run bash -c "SCRIPT_DIR='$TEST_TEMP_DIR' CLAUDE_CONFIG_DIR='$TEST_TEMP_DIR/.claude' bash '$SCRIPTS_DIR/session-start.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v2_two_phase_completion requires v3_event_log"* ]]
}

@test "flag-deps: multiple warnings when multiple deps unsatisfied" {
  cd "$TEST_TEMP_DIR"
  jq '.v2_hard_gates = true | .v2_hard_contracts = false | .v3_event_recovery = true | .v3_event_log = false' \
    .vbw-planning/config.json > .vbw-planning/config.json.tmp \
    && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
  run bash -c "SCRIPT_DIR='$TEST_TEMP_DIR' CLAUDE_CONFIG_DIR='$TEST_TEMP_DIR/.claude' bash '$SCRIPTS_DIR/session-start.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v2_hard_gates requires v2_hard_contracts"* ]]
  [[ "$output" == *"v3_event_recovery requires v3_event_log"* ]]
}
