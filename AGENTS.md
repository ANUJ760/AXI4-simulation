# Repository coordination

Codex is the sole implementation agent. Antigravity is a read-only supervisor.
Only Codex may modify RTL, UVM, scripts, tests, configurations, project
documentation, or Git state. The supervisor may append review feedback to the
shared communication log.

Use `.agent-coordination/COMMUNICATION.md` for communication. It is append-only:
never overwrite, truncate or modify an existing entry. Acquire an exclusive
lock using `flock` on `.agent-coordination/communication.lock` before appending,
and release it immediately after the append. Keep the lock file's inode stable;
do not delete it while participants may be using it.

Read the log before starting a milestone, after completing a milestone, before
finalizing a milestone, and whenever the supervisor reports a P0/P1 issue.
Each completed milestone entry must include changed files, actual commands and
results, known limitations, and a request for supervisor review.

Treat findings as review feedback. Reproduce or otherwise confirm issues before
changing behavior; explain disagreements with specification and execution
evidence. Do not bypass the DOCX specification to make tests pass. A supervisor
PASS never substitutes for actual test execution.
