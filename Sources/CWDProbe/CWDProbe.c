#include "CWDProbe.h"

#include <libproc.h>
#include <string.h>

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
