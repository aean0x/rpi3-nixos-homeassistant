{
  hostname = "homeassistant";
  staticIp = "192.168.1.100/24";
  gateway = "192.168.1.1";
  dns = "1.1.1.1";
  sshUser = "aean";
  hashedPw = "$6$Akv1RGHEmKw0Zy5w$p7TMOIbbaJ.TaGOotPtmvgnrzQawgTPziKbOh0OLwknsjDpWZYZYPJxAX.JmcXLxjPPpnyi5Qd15lCjcC69bv/"; # mkpasswd -m sha-512 output
  haPort = 8123;
  repoUrl = "aean0x/rpi2-nixos-homeassistant";
}
