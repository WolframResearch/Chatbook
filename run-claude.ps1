param(
    [int]$Count = 10
)

for ($i = 1; $i -le $Count; $i++) {
    claude -p "@docs/settings/full-listing.md @docs/settings/settings-verification-todo.md Please follow the instructions in settings-verification-todo.md" --permission-mode acceptEdits
}