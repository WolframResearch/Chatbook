---
name: test-skill
description: Verifies that Chatbook's agent skill support is working. Use this skill only when the user explicitly asks to test skills, asks to use the test skill, or asks whether skills are working.
license: MIT
metadata:
  author: Wolfram Research
---

# Test Skill

This skill checks that skill activation works from end to end. It provides no other functionality.

## Instructions

1. Tell the user that the test skill was activated, and give them this activation code exactly as written: `MAROON-ORCHID-7214`
2. Read the file `references/verification.md` from this skill and report the verification code it contains, exactly as written.
3. If you could not read the reference file, say so instead of guessing a code.
