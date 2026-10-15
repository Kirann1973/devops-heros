# Secret Base64 Gotcha — The Newline Bug

## The Problem

When encoding secret values for Kubernetes, using `echo` without `-n` adds a hidden newline character (`\n`) at the end of the value.

## Wrong Way

```bash
echo "secretpassword" | base64
```

Output:

```text
c2VjcmV0cGFzc3dvcmQK
```

Notice: ends in `QK` — the `K` encodes the hidden `\n`.

## Correct Way

```bash
echo -n "secretpassword" | base64
```

Output:

```text
c2VjcmV0cGFzc3dvcmQ=
```

Notice: ends cleanly in `Q=`.

## Why This Matters

When Kubernetes injects the Secret value into a container:

- **Wrong:** `secretpassword\n` (15 characters)
- **Correct:** `secretpassword` (14 characters)

The database receives `secretpassword\n` and rejects it because the password doesn't match.

## How to Verify

```bash
# Decode the wrong value
echo "c2VjcmV0cGFzc3dvcmQK" | base64 --decode | xxd | tail -1
```

You will see `0a` at the end — that's the hex value of `\n`.

```bash
# Decode the correct value
echo "c2VjcmV0cGFzc3dvcmQ=" | base64 --decode | xxd | tail -1
```

No trailing `0a`.

## Rule

**Always use `echo -n` when encoding Base64 values for Kubernetes Secrets.**
