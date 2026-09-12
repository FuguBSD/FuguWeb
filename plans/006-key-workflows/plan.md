# 006 — The key workflows

## Status

Proposed. It waits on plan 003. A caller can add the OpenPGP type and the
certificate type without a change here. The type, the email address, the expiry
date and the key file are inputs, per WEB-ACTIONS-1.

Implements: WEB-ACTIONS.

## Purpose

The rotation workflow of the organization site holds the credential, the slots,
the commit, the publish, the confirmation and the declaration of the key. It
serves one purpose and one organization, and a second publisher copies the whole
file.

This plan moves the generic part into this repository, as one reusable workflow
and two composite actions. A publisher calls
`FuguBSD/FuguWeb/.github/workflows/keys-rotate.yml` from a thin caller, or
composes `FuguBSD/FuguWeb/actions/keys-slot` and
`FuguBSD/FuguWeb/actions/keys-store` on its own.

## Evidence

### The prototype

The rotation workflow of the organization site is the prototype. A review panel
reproduced the faults of a wrong step order, and the site specification holds a
rule for each one. This plan carries each rule into WEB-ACTIONS:

| The fault                                            | The rule       |
| ---------------------------------------------------- | -------------- |
| A secret in the script text becomes a command.       | WEB-ACTIONS-4  |
| An unpinned install runs beside a private key.       | WEB-ACTIONS-5  |
| The variable names a key that the site cannot serve. | WEB-ACTIONS-7  |
| The site never rebuilds after a token push.          | WEB-ACTIONS-8  |
| A published key has no private half in a slot.       | WEB-ACTIONS-7  |
| A private key file outlives the run.                 | WEB-ACTIONS-12 |

The prototype names its secrets literally, because the `secrets` context takes
no name from an input. The JSON form of the context does: `toJSON(secrets)`
gives an object, and `fromJSON` indexes it by a name that `format` builds. The
runner masks the value as it masks every secret. WEB-ACTIONS-4 rests on this,
and the first step of the change proves it in a scratch workflow.

### The research

A reusable workflow runs at the job level with `on: workflow_call`, and a
composite action runs at the step level. Permissions can shrink and never grow.
`secrets: inherit` passes every secret inside one organization. A `GITHUB_TOKEN`
cannot write a secret, so a GitHub App token does, and `gh secret set` reads the
value from standard input. GitHub can now require a commit pin on every action
that an organization uses, and WEB-ACTIONS-11 pins each one here.

### The consumer test

The synced test `t/ci/workflows.t` accepts each `uses:` reference under the
`FuguBSD/` owner, so a caller of this workflow passes it today. The text of
Tooling WFL-ACTIONS-1 names the actions of Tooling alone, and Tooling widens it
when it syncs.

## The change

1. A scratch workflow proves the JSON read of a secret by a formed name. The run
   log of that proof goes into the pull request.
2. `actions/keys-slot/action.yml` reads the slot variable of one purpose and
   writes the working key files, with the outputs `active` and `idle`.
3. `actions/keys-store/action.yml` writes a secret from a file into the idle
   slot, and moves the variable when the caller asks.
4. `.github/workflows/keys-rotate.yml` composes the two around the verb, in the
   order of the prototype. The order is this: guard, install, confirm the tool,
   token, report the reach, read the slots, run the verb. Then mask, store,
   commit, publish, confirm the bytes, move the variable, output the facts. The
   removal of the work directory comes last.
5. `t/ci/keys-rotate.t` holds the order and each guard as text.
6. `t/ci/workflows.t` stays synced, and the pins of WEB-ACTIONS-11 pass it.
7. `spec/STATUS.md` sets WEB-ACTIONS, and this plan directory goes in the same
   change.

## What this plan does not do

It opens no pull request against Tooling, and it orders no `deps/KEYS.txt`. The
caller of the organization site holds that follow-up, and it reads the outputs
of WEB-ACTIONS-2 for it.

It holds no caller. The organization site replaces its workflow with a thin
caller when it pins the release that holds this plan.

It reads no PKCS#12 file. The slot holds the PEM private key, per WEB-X509-3.
The operator converts a PKCS#12 file once, with `openssl pkcs12`, before the
first secret write. Neither the verbs nor the workflow read one.
