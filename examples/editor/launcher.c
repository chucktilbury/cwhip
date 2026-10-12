#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int child_status(pid_t child) {
    int status;
    while (waitpid(child, &status, 0) < 0) {
        if (errno != EINTR) { perror("cwhip-editor: waitpid"); return 1; }
    }
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return WIFSIGNALED(status) ? 128 + WTERMSIG(status) : 1;
}

int main(int argc, char **argv) {
    char executable[PATH_MAX];
    ssize_t length = readlink("/proc/self/exe", executable, sizeof(executable) - 1);
    if (length < 0 || (size_t)length >= sizeof(executable) - 1) {
        perror("cwhip-editor: executable path");
        return 1;
    }
    executable[length] = '\0';
    char *name = strrchr(executable, '/');
    if (!name || (size_t)(name - executable) + sizeof("/cwhip-editor.bin") > sizeof(executable)) {
        fprintf(stderr, "cwhip-editor: executable path is too long\n");
        return 1;
    }
    strcpy(name, "/cwhip-editor.bin");
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--foreground") || !strcmp(argv[i], "--test")) {
            execv(executable, argv);
            perror("cwhip-editor: exec");
            return 1;
        }
    }
    int ready[2];
    if (pipe(ready) < 0) { perror("cwhip-editor: pipe"); return 1; }
    if (ready[1] < 3) {
        int fd = fcntl(ready[1], F_DUPFD, 3);
        if (fd < 0) { perror("cwhip-editor: readiness fd"); return 1; }
        close(ready[1]);
        ready[1] = fd;
    }
    pid_t child = fork();
    if (child < 0) { perror("cwhip-editor: fork"); return 1; }
    if (!child) {
        close(ready[0]);
        char fd[32];
        snprintf(fd, sizeof(fd), "%d", ready[1]);
        if (setenv("CWHIP_EDITOR_READY_FD", fd, 1) < 0 || setsid() < 0) {
            perror("cwhip-editor: background startup");
            _exit(1);
        }
        int input = open("/dev/null", O_RDONLY);
        if (input < 0 || dup2(input, STDIN_FILENO) < 0) {
            perror("cwhip-editor: stdin");
            _exit(1);
        }
        if (input != STDIN_FILENO) close(input);
        execv(executable, argv);
        perror("cwhip-editor: exec");
        _exit(1);
    }
    close(ready[1]);
    struct pollfd pollfd = { .fd = ready[0], .events = POLLIN };
    int result;
    do { result = poll(&pollfd, 1, 30000); } while (result < 0 && errno == EINTR);
    char message = 0;
    ssize_t received = 0;
    if (result > 0) {
        do { received = read(ready[0], &message, 1); } while (received < 0 && errno == EINTR);
    }
    close(ready[0]);
    if (received == 1 && message == 'R') return 0;
    if (result <= 0) {
        if (result < 0) perror("cwhip-editor: startup readiness");
        else fprintf(stderr, "cwhip-editor: startup did not become ready within 30 seconds\n");
        kill(child, SIGTERM);
        child_status(child);
        return 1;
    }
    int status = child_status(child);
    if (!status) {
        fprintf(stderr, "cwhip-editor: exited before reporting startup readiness\n");
        return 1;
    }
    return status;
}
