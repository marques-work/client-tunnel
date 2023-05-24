# How to use this

## Prerequisites (do these just once)

### Pre-req: Set up a bastion host

Use a cloud provider or other machine _**you**_ control/own. For instance, use your personal AWS account to create a Linux EC2 (amazon linux will work just fine) and make sure you can SSH into it with a keypair.

Or use GCP or whatever you have.

### Pre-req: configure `ssh-agent` and create a new password-encrypted ssh keypair on the target windows machine

0. Download a tarball of this repo: [main.tar.gz](https://github.com/marques-work/client-tunnel/archive/refs/heads/main.tar.gz)
    - Extract somewhere:

        ```console
        $ tar zxf path/to/main.tar.gz
        ```

    - Optional, but recommended: put these scripts in your `PATH`

1. Open a `git+bash` terminal session
2. Ensure `ssh-agent` is enabled in your session:

    ```bash
    # modify either your .profile, .bash_profile, or .zprofile (whichever is
    # applicable) and add:

    eval "$(ssh-agent -s)"
    trap "ssh-agent -k" EXIT

    # Now, restart your shell session
    ```

3. Generate a new SSH key (**with a password!!**) to use on your windows host:

    ```console
    $ ssh-keygen -t ed25519 -a 40 -C 'me@windows-remote-host'

    ...

    # set a password for the private key when prompted!
    ```

    - Using a password protects your key since we must assume the VM adminstrators can commandeer your VM and have access to all of your files, including this key
    - We don't want to allow such folks to log into the bastion and poke around; it's for your eyes only!

4. Send yourself the **public key** from the keypair you just generated (via email or chat)
5. Add this public key to your bastion:

    ```console
    # assuming you uploaded the public key as `id_ed25519.pub` to your bastion
    # and opened an ssh session into the box

    $ cat id_ed25519.pub >> ~/.ssh/authorized_keys

    # probably unnecessary, but included for good measure:
    $ chmod 600 ~/.ssh/authorized_keys
    ```

6. Send your personal public key to yourself (or somewhere you can access on THIS windows machine)
7. Add your personal public key to `~/.ssh/authorized_keys` on THIS windows machine (or if you created one specifically to log into here, use that one):

    ```console
    $ mkdir -p ~/.ssh
    $ touch ~/.ssh/authorized_keys
    $ chmod 600 ~/.ssh/authorized_keys
    $ cat path/to/your/personal/id_{ed25519|rsa}.pub >> ~/.ssh/authorized_keys
    ```

### Pre-req: configure `ssh-agent` on your machine and configure your key to be used on the bastion host

1. Option 1: add your default ssh public key to the bastion host, OR
2. Option 2: ensure `ssh-agent` is running and you configure ssh to automatically choose the key downloaded from AWS when you created your EC2
    - Follow the same steps noted for the windows machine to ensure `ssh-agent` is running. The steps are identical.
    - Configure `~/.ssh/config` to use the keypair for your EC2 when connecting to that machine:

        ```plain
        Host gilead-bastion
          HostName <IP address of your EC2>
          User ec2-user
          IdentityFile /absolute/path/to/your/ec2-private-key.pem
          IdentitiesOnly yes
        ```

## Using these scripts to connect your remote windows machine to your computer

### From the remote windows machine:

1. Open a `git+bash` terminal session
2. Add the ssh key you generated earlier in the prerequisites section to the `ssh-agent`:

    ```console
    # assuming you chose the default location to save the key
    $ ssh-add ~/.ssh/id_ed25519

    # enter your password; you will only need to do this once per
    # shell session
    ```

3. Start OpenSSH server by running the [`openssh-server.sh`](./openssh-server.sh) script:

    ```console
    $ ./openssh-server.sh start

    # you can stop the server by passing `stop`; `start` is an
    # alias for `restart`, which is what it really does.
    ```

4. Run [`target-machine.sh`](./target-machine.sh):

    ```console
    $ ./target-machine.sh --up

    # you can tear down this side of the tunnel by passing `--down`
    ```

### From your laptop/PC:

1. Open a terminal session
2. Add your EC2 key to `ssh-agent`:

    ```console
    $ ssh-add path/to/your/ec2-private-key.pem
    ```

3. Run [`your-machine.sh`](./your-machine.sh):

    ```console
    $ ./your-machine.sh --up

    # you can tear down this side of the tunnel by passing `--down`
    ```

4. Now, ssh into localhost at port 2200, and you should see your git+bash prompt from your windows VM!

    ```console
    $ ssh -p 2200 your-windows-username@127.0.0.1
    ```
