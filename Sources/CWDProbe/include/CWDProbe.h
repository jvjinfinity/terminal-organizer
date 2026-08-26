#pragma once

#include <sys/types.h>

/// Writes the current working directory of `pid` into `out`.
/// Returns 0 on success, -1 on failure.
int cwd_probe_pid(pid_t pid, char *out, int out_len);

/// Writes the parent pid of `pid` into `out`.
/// Returns 0 on success, -1 on failure.
int parent_probe_pid(pid_t pid, pid_t *out);
