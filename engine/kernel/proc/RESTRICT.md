# P8: taking rights away from the simulating process on Windows (on paper)

**Nothing in this file was run.** No job object, token or container was created and no setting of this machine was
changed: the brief forbids weakening the machine to test a restriction, and two of the three mechanisms need either
a native launcher (which the engine does not have) or a change to the machine's own configuration. What is written
here is what the operating system documents, read against what the spike's process S was seen to do.

## What S was seen to need (measured in the spike, unrestricted)

- **Read**: the engine executable, the project folder (`engine/`, as `--path`; a `.pck` in a built game) and the
  pack's folder. `ctx.read_json` and `ctx.load_script` read only inside the pack.
- **Write**: nothing of its own. The worker writes one result file where `--result` points (the spike could send it
  over the channel instead) and the engine writes a log under the user's data folder unless told otherwise.
- **Network**: one TCP connection on 127.0.0.1 to D. Nothing else.
- **Other processes**: one. The worker starts a PowerShell helper to read its own processor time
  (`kernel/host/cpuclock.gd`). Where the helper cannot start the clock gives up and the watchdog falls back to wall time.
- **Devices**: none. `--headless` uses the dummy display and renderer: no window, no graphics device, no input device.
  Audio is not played in S (the kernel records the event and returns).

## What Windows offers

| Mechanism | Takes away | Does not take away | Needs |
|---|---|---|---|
| **Job object** (`CreateJobObject`, `AssignProcessToJobObject`) | child processes (`ActiveProcessLimit = 1`), memory above a cap, processor share above a cap; the clipboard, the desktop, display settings, other processes' window handles (UI restrictions); and it ends S when D ends (`KILL_ON_JOB_CLOSE`), which answers "no process left behind" by construction | files, network | a launcher that can call the Win32 API. No rights beyond the user's own. |
| **Restricted token at low integrity** (`CreateRestrictedToken`, `SetTokenInformation(TokenIntegrityLevel)`, `CreateProcessAsUser`) | writing to almost everything the user owns (files, registry, other processes' windows); privileges | **reading** the user's files (low integrity blocks writing up, not reading); network | the same launcher |
| **App container** (`CreateAppContainerProfile`, `CreateProcess` with `PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES`), optionally the less-privileged form | reading and writing every file and registry key not granted to the container; all network unless a capability is given; other processes; most devices | what it is explicitly granted | the same launcher, a container profile created once per user, and an access entry for the container on the folders S must read (the game's own install folder and the pack's folder) |

Only the app container gives the two properties the brief names (no network, no file outside a folder). The job
object is worth having in every case (it is the only one of the three that also bounds memory and processor and
cleans up), and it costs nothing in rights.

## What an engine process started that way would be denied (expected, not tested)

1. **The loopback connection itself.** An app container has no network without a capability, and loopback to a
   process outside the container is blocked even with one; the documented way round is a per-container loopback
   exemption, which is a change to the machine's network isolation settings and exactly the kind of weakening this
   spike must not do. So **the measured channel (TCP on 127.0.0.1) is right for multiplayer and wrong for the
   sandbox.** The sandbox channel has to be a pipe whose handle D gives S at start (or a named pipe with an access
   entry for the container). A script cannot make one: `FileAccess.open` on a new pipe name fails with
   error 7 (measured; whether it opens a pipe that a native launcher made first was not tested), and a child started
   with `OS.execute_with_pipe` can read its stdin but has no binary stdout. This needs a small native piece (a
   GDExtension or a launcher), not a kernel API change.
2. **The helper process.** Under `ActiveProcessLimit = 1` the PowerShell helper of the processor clock does not
   start. The clock reports "no source" and the limits fall back to wall time, which fails healthy code on a busy
   machine (round 1's finding). The fix is on D's side and better than today: the job object reports S's processor
   time to whoever holds the job (`JobObjectBasicAccountingInformation`), so D can be the watchdog.
3. **The console wrapper.** The `..._console.exe` this project starts is a wrapper that starts the real engine as
   its child. Under a one-process job the child would be refused. S has to be the engine executable itself.
4. **The user's data folder.** The engine makes `user://` under `%APPDATA%` at start and writes its log there. A
   container cannot write there. It would have to be pointed at the container's own folder (by setting `APPDATA`
   for S, or a custom user directory in the project settings) and file logging switched off or sent to a path it
   owns. Whether the engine treats a failure to create that folder as fatal: not tested.
5. **Reading the engine and the pack.** A container reads only what is granted to it. The game's install folder and
   each shared pack's folder need an access entry for the container (an installer step, or D does it when it
   unpacks an item into a folder it owns).
6. **The audio driver.** S plays nothing, but the engine still opens the audio device at start unless told
   `--audio-driver Dummy`. Expected to be needed; not tested.
7. **The result file and the "alive" file** of the worker: paths outside the container. Both can go over the channel.

## What no operating-system mechanism does for us

- It does not make D safe from what S **sends**. D has to treat the stream as hostile input: the spike decodes with
  `bytes_to_var` (objects are never decoded) and bounds each read at 32 MB, but it trusts counts, numbers and node
  numbers. A real D checks every index, caps nodes, bytes per tick and text length, and drops S when it is exceeded.
- It does not help while **D runs the pack's own setup code** to build the picture, which is what the spike does.
  For a stranger's pack D must build from records (`CROSSING.md`, rule 2), or the boundary has a door in it.
- A script in S can still call everything the engine has (`OS.execute`, `FileAccess`, `HTTPRequest`). Lint stops
  being the defence; the container is. That is the point of the exercise.

## What I could not test, in one list

Every row of the table; whether the engine starts at all in a container; items 1 to 7 above; the cost of starting a
process through `CreateProcess` with a container (expected to be the same order as a normal start, 1 to 2 s of
which is the engine and the pack loading, see PROCESS.md); Linux and macOS (seccomp and namespaces, the App Sandbox)
were not looked at.
