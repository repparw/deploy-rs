# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

# Returns a transformed copy of `deploy` where any profile whose `path`
# evaluated to a derivation also exposes that derivation's `drvPath`. This
# lets deploy-rs build content-addressed and floating-output derivations,
# whose `outPath` is only a placeholder at eval time, without users having
# to set `drvPath` manually in their flake.
#
# For remote evaluation, remove the profile path without forcing its value.
# The nullable CLI override comes first, followed by profile, node and deploy.
#
# The deploy-rs binary loads this file via `include_str!` from `src/cli.rs`
# and applies it. The expression is self-contained so it can be parsed in
# isolation for linting, and exercised by `nix/tests/transform-deploy.nix`.
cliRemoteEval: deploy:
let
  patchProfile = n: p:
    let
      remoteEval = builtins.head (builtins.filter (v: v != null) [
        cliRemoteEval (p.remoteEval or null) (n.remoteEval or null) (deploy.remoteEval or null) false
      ]);
    in
    if remoteEval then builtins.removeAttrs p [ "path" ]
    else if (p ? path) && (builtins.isAttrs p.path) && (p.path ? drvPath)
    then p // { path = p.path.outPath; drvPath = p.path.drvPath; }
    else p;
  patchNode = n: n // {
    profiles = builtins.mapAttrs (_: patchProfile n) (n.profiles or { });
  };
in
if deploy ? nodes
then deploy // { nodes = builtins.mapAttrs (_: patchNode) deploy.nodes; }
else deploy
