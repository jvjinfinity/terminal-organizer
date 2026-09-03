#pragma once

#include <sys/types.h>

/// Writes the current working directory of `pid` into `out`.
/// Returns 0 on success, -1 on failure.
int cwd_probe_pid(pid_t pid, char *out, int out_len);

/// Writes the parent pid of `pid` into `out`.
/// Returns 0 on success, -1 on failure.
int parent_probe_pid(pid_t pid, pid_t *out);

/// Writes the process name of `pid` into `out`.
/// Returns 0 on success, -1 on failure.
int name_probe_pid(pid_t pid, char *out, int out_len);

/// Writes up to `max` direct child pids of `pid` into `out`.
/// On success `*count` is the number written. Returns 0 on success, -1 on failure.
int child_probe_pids(pid_t pid, pid_t *out, int max, int *count);

/// Copies the first open vnode path of `pid` that contains `/.grok/sessions/`.
/// Returns 0 on success, -1 on failure.
int grok_session_path_probe_pid(pid_t pid, char *out, int out_len);
