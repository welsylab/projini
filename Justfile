def remotes():
    output = run("git remote -v")
    lines = output.splitlines()
    remote_names = set()
    for line in lines:
        parts = line.split()
        if len(parts) >= 2:
            remote_names.add(parts[0])
    return list(remote_names)

push-all:
    @for remote in remotes():
        @echo "Pushing to {remote}..."
        @git push $$remote --all
