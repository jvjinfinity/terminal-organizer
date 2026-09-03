#include "CWDProbe.h"

#include <libproc.h>
#include <stdlib.h>
#include <string.h>
#include <sys/proc_info.h>

int parent_probe_pid(pid_t pid, pid_t *out) {
    if (pid <= 0 || out == NULL) {
        return -1;
    }
    struct proc_bsdinfo info;
    memset(&info, 0, sizeof(info));
    int ret = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, (int)sizeof(info));
    if (ret <= 0) {
        return -1;
    }
    if (info.pbi_ppid <= 0) {
        return -1;
    }
    *out = (pid_t)info.pbi_ppid;
    return 0;
}

int cwd_probe_pid(pid_t pid, char *out, int out_len) {
    if (pid <= 0 || out == NULL || out_len <= 1) {
        return -1;
    }
    struct proc_vnodepathinfo vpi;
    memset(&vpi, 0, sizeof(vpi));
    int ret = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vpi, (int)sizeof(vpi));
    if (ret <= 0) {
        return -1;
    }
    strncpy(out, vpi.pvi_cdir.vip_path, (size_t)out_len - 1);
    out[out_len - 1] = '\0';
    if (out[0] == '\0') {
        return -1;
    }
    return 0;
}

int name_probe_pid(pid_t pid, char *out, int out_len) {
    if (pid <= 0 || out == NULL || out_len <= 1) {
        return -1;
    }
    memset(out, 0, (size_t)out_len);
    int n = proc_name(pid, out, (uint32_t)out_len);
    if (n <= 0) {
        out[0] = '\0';
        return -1;
    }
    out[out_len - 1] = '\0';
    if (out[0] == '\0') {
        return -1;
    }
    return 0;
}

int child_probe_pids(pid_t pid, pid_t *out, int max, int *count) {
    if (pid <= 0 || out == NULL || max <= 0 || count == NULL) {
        return -1;
    }
    *count = 0;
    int bytes = proc_listpids(PROC_PPID_ONLY, (uint32_t)pid, NULL, 0);
    if (bytes <= 0) {
        return 0;
    }
    pid_t *buf = malloc((size_t)bytes);
    if (buf == NULL) {
        return -1;
    }
    int filled = proc_listpids(PROC_PPID_ONLY, (uint32_t)pid, buf, bytes);
    if (filled <= 0) {
        free(buf);
        return 0;
    }
    int n = filled / (int)sizeof(pid_t);
    int written = 0;
    for (int i = 0; i < n && written < max; i++) {
        if (buf[i] <= 0 || buf[i] == pid) {
            continue;
        }
        out[written++] = buf[i];
    }
    free(buf);
    *count = written;
    return 0;
}

int grok_session_path_probe_pid(pid_t pid, char *out, int out_len) {
    if (pid <= 0 || out == NULL || out_len <= 1) {
        return -1;
    }
    out[0] = '\0';
    int bufSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (bufSize <= 0) {
        bufSize = (int)sizeof(struct proc_fdinfo) * 4096;
    }
    const int cap = (int)sizeof(struct proc_fdinfo) * 8192;
    if (bufSize > cap) {
        bufSize = cap;
    }
    struct proc_fdinfo *fds = malloc((size_t)bufSize);
    if (fds == NULL) {
        return -1;
    }
    int filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, bufSize);
    if (filled <= 0) {
        free(fds);
        return -1;
    }
    int n = filled / (int)sizeof(struct proc_fdinfo);
    int ok = -1;
    for (int i = 0; i < n; i++) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_VNODE) {
            continue;
        }
        struct vnode_fdinfowithpath info;
        memset(&info, 0, sizeof(info));
        int nb = proc_pidfdinfo(
            pid,
            fds[i].proc_fd,
            PROC_PIDFDVNODEPATHINFO,
            &info,
            (int)sizeof(info)
        );
        if (nb <= 0) {
            continue;
        }
        const char *path = info.pvip.vip_path;
        if (path[0] == '\0') {
            continue;
        }
        if (strstr(path, "/.grok/sessions/") == NULL) {
            continue;
        }
        strncpy(out, path, (size_t)out_len - 1);
        out[out_len - 1] = '\0';
        ok = 0;
        break;
    }
    free(fds);
    return ok;
}
