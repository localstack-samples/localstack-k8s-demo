{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  packages = [
    opentofu
    uv
    kubectl
    k9s
    minikube
    kubernetes-helm
    glow
  ];
}

