{
  hostname = "rpi-ha";
  staticIp = "192.168.1.100/24";
  gateway = "192.168.1.1";
  dns = "8.8.8.8";
  sshUser = "admin";
  hashedPw = "$6$...";  # mkpasswd -m sha-512 output
  haPort = 8123;
  repoUrl = "github:your/repo";
}
