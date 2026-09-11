#define _XOPEN_SOURCE 700

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static const char *markers[] = {
    ".devcontainer", ".git", ".hg", ".idea", ".jj", ".svn", ".vscode",
};

static const char *ignored[] = {
    ".android", ".bun", ".cache", ".cargo", ".devcontainer", ".dotnet",
    ".git", ".gradle", ".hg", ".idea", ".jj", ".local", ".npm",
    ".nuget", ".pki", ".pnpm-store", ".pytest_cache", ".ruff_cache",
    ".rustup", ".ssh", ".steam", ".svn", ".tmp", ".tox", ".var",
    ".venv", ".vscode", ".vscode-oss", ".vscode-oss-shared",
    ".vscode-shared", ".yarn", "__pycache__", "build", "cache", "caches",
    "dist", "node_modules", "out", "target", "vendor", "venv",
};

struct paths {
    char **items;
    size_t length;
    size_t capacity;
};

static bool contains(const char *name, const char *const *values, size_t count) {
    for (size_t index = 0; index < count; index++) {
        if (strcmp(name, values[index]) == 0) return true;
    }
    return false;
}

static void push(struct paths *paths, char *path) {
    if (paths->length == paths->capacity) {
        size_t capacity = paths->capacity ? paths->capacity * 2 : 64;
        char **items = realloc(paths->items, capacity * sizeof(*items));
        if (!items) exit(EXIT_FAILURE);
        paths->items = items;
        paths->capacity = capacity;
    }
    paths->items[paths->length++] = path;
}

static char *join(const char *directory, const char *name) {
    size_t length = strlen(directory) + strlen(name) + 2;
    char *path = malloc(length);
    if (!path) exit(EXIT_FAILURE);
    snprintf(path, length, "%s/%s", directory, name);
    return path;
}

static const char *base_name(const char *path) {
    const char *slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

static bool scan(const char *directory, bool check_markers, struct paths *stack) {
    DIR *stream = opendir(directory);
    if (!stream) return false;
    int descriptor = dirfd(stream);
    size_t original_length = stack->length;
    struct dirent *entry;
    while ((entry = readdir(stream))) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        if (check_markers && contains(entry->d_name, markers,
                sizeof(markers) / sizeof(*markers))) {
            while (stack->length > original_length) free(stack->items[--stack->length]);
            closedir(stream);
            return true;
        }
        struct stat status;
        if (fstatat(descriptor, entry->d_name, &status, AT_SYMLINK_NOFOLLOW) == 0 &&
            S_ISDIR(status.st_mode))
            push(stack, join(directory, entry->d_name));
    }
    closedir(stream);
    return false;
}

static bool excluded_path(const char *path, char **excluded, int count) {
    for (int index = 0; index < count; index++) {
        if (excluded[index] && strcmp(path, excluded[index]) == 0) return true;
    }
    return false;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: project_candidates HOME [EXCLUDED_ROOT ...]\n");
        return 2;
    }
    char *home = realpath(argv[1], NULL);
    if (!home) return 0;
    char **excluded = calloc((size_t)argc, sizeof(*excluded));
    if (!excluded) return 1;
    int excluded_count = 0;
    for (int index = 2; index < argc; index++)
        excluded[excluded_count++] = realpath(argv[index], NULL);
    excluded[excluded_count++] = join(home, "go/pkg");

    struct paths stack = {0};
    scan(home, false, &stack);
    while (stack.length) {
        char *directory = stack.items[--stack.length];
        if (!excluded_path(directory, excluded, excluded_count) &&
            !contains(base_name(directory), ignored, sizeof(ignored) / sizeof(*ignored))) {
            if (scan(directory, true, &stack)) {
                if (fwrite(directory, strlen(directory) + 1, 1, stdout) != 1) {
                    free(directory);
                    break;
                }
                fflush(stdout);
            }
        }
        free(directory);
    }

    while (stack.length) free(stack.items[--stack.length]);
    for (int index = 0; index < excluded_count; index++) free(excluded[index]);
    free(excluded);
    free(stack.items);
    free(home);
    return ferror(stdout) && errno != EPIPE;
}
