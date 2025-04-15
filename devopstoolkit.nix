# /etc/nixos/custom/simple-devops-toolkit.nix
{ config, lib, pkgs, ... }:

let
  # !!! ACHTUNG: Hardcodierter Pfad zum Benutzer-Home-Verzeichnis !!!
  # Dies ist schlechte Praxis in einem Systemmodul.
  # Ändere 'fr4iser' und den Pfad entsprechend, wo du es geklont hast.
  targetUser = "fr4iser"; 
  simpleDevOpsToolkitScriptPath = "/home/${targetUser}/Documents/Git/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh"; 

in
{
  # Fügt einen Symlink in /usr/local/bin hinzu.
  # /usr/local/bin sollte standardmäßig im PATH sein.
  # Dies macht das Tool systemweit verfügbar, setzt aber voraus, 
  # dass der Pfad oben korrekt ist und das Skript dort liegt.
  environment.systemPackages = [
    (pkgs.runCommand "simple-devops-toolkit-link" {} ''
      mkdir -p $out/bin
      ln -s "${simpleDevOpsToolkitScriptPath}" $out/bin/SimpleDevOpsToolkit
      # Stelle sicher, dass das Ziel-Skript ausführbar ist (chmod +x außerhalb von Nix)
      # oder dass der Link selbst +x hat (Nix macht das normalerweise für $out/bin Inhalte)
    '')
  ];

  # Hinweis: Dies fügt nichts zur Home Manager Konfiguration hinzu.
  # Es stellt nur sicher, dass ein Link in einem systemweiten bin-Verzeichnis existiert.
}