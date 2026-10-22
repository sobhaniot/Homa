# این دستور روی رزبری اجرا می‌شود؛ رمز فقط در ترمینال SSH وارد می‌شود.
$taskRemoteCommand = "sudo sh -c 'visudo -cf /home/sobhan/homa-nopasswd && install -o root -g root -m 0440 /home/sobhan/homa-nopasswd /etc/sudoers.d/99-homa-sobhan-nopasswd'; sudo -n true && echo HOMA_SUDO_READY"
& ssh.exe -t -i 'C:\Users\Sobhan\.ssh\homa_pi_ed25519' -o 'HostKeyAlias=192.168.1.12' 'sobhan@192.168.1.55' $taskRemoteCommand
