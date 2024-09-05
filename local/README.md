# Use RStudio server on ERIS with conda

## What does this doc do?
This setup allows you to achieve several things at the same time: run **RStudio** from ERIS **computation nodes** in a web browser with you own **R versions** and **conda environments**.

## Why bother?
**TL; DR**
**It's worth it!**

As you can see, setting this up can be a laborious process. So you may be wondering, why? Here is my logic. First, the obvious alternative is to use Jupyter Notebook or [Jupyter Hub](https://jupyterhub2.partners.org). But I personally think RStudio works better than Jupyter for interactive data analysis in R:
1. RStudio offers better code completion and context help.
2. `.ipynb` can only be viewed by Jupyter, whereas `.R`, `.Rmd` or `.qmd` (Quarto) offer much more flexibility.
3. There is a nice terminal in RStudio if you want to use it, whereas the terminal in Jupyter Hub does not work very well.

Assuming I have persuaded you that RStudio is better than Jupyter, another option is to use the RStudio Server provided by [ERIS](https://rstudio2.partners.org) or O2. These mostly work well except for several problems:
1. ERIS RStudio breaks down frequently.
2. Memory and cores are limited and shared on ERIS RStudio, and can be a problem for large-scale data analysis, which is one of the reasons why it breaks down so easily.
3. Core-managed RStudio only provides a few versions of R, and can be out dated. For example, you cannot install `seurat5` on ERIS RStudio because it requires `R>=4.4`.
4. Related to 3, there's no flexibility to maintain various  versions of R and coding environments for different purposes, because the core would not allow it (for good reasons).

Now it becomes natural that we install our own version of RStudio Server that can be launched in a web browser. But this comes with another problem: RStudio Server requires root privilege to install. This has been major hurdle for me previously, but luckily, ERISTwo provides a pre-installed version of RStudio Server.

## How?

I will use my own setup to run `seurat5` as an example here. Since I haven't figured out a way to do ssh tunneling on ERIS, we will use VS Code dev tunnel for now. To do so, you have to install VS Code on your local computer and on ERIS.

#### 00. Preparation

First, install VS Code Desktop app on your computer. You should also install Remote - SSH extension (https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh).

Then, install VS Code CLI in your ERIS home folder following [from here](https://code.visualstudio.com/download).
After installing, it should be an executable `code` in the folder you installed it. You can also learn more about how to use VS Code Server [here](https://code.visualstudio.com/docs/remote/vscode-server).

For everything we do below, it's necessary to do them in a computation node. If you do them in the login node, your connection can get cut and you can break the login node. So, start an interactive session with `bsub` or `salloc`.

```sh
bsub -Is -W 12:00 -M 80000 -n 16 -q interactive /bin/bash
```

Or:

```sh
salloc --mem=80G --time=12:00:00 -c 16
```

Once you are in the interactive session, check that your host name with `echo $HOSTNAME`; this should not be `eris2n4` or `eris2n5`. Then activate the conda env that you want to work in.

```sh
$ conda activate seurat5
$ which R
~/miniforge3/envs/seurat5/bin/R
```

Start a VS Code tunnel that allows you to connect to ERIS from the VS Code app on your local computer.

```sh
./code tunnel
```

Follow the instructions. Basically, you will be directed to a web page where you login with your Github account. After that, you should be able to connect to ERIS from VS Code on your computer. You can find that under "Remote Explorer".

After connecting to ERIS in VS Code, we can use the integrated Terminal in VS Code for all the following commands.
#### 01. Load necessary modules
Let's first check whether there is a pre-installed rstudio on ERIS.
```sh
$ module avail rstudio
----------------------------------------------------------------- /apps/modulefiles/conversion ------------------------------------------------------------------

   Rstudio-server/2023.12.1-402

Module defaults are chosen based on Find First Rules due to Name/Version/Version modules found in the module tree.

See https://lmod.readthedocs.io/en/latest/060_locating.html for details.

If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.

"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.

Use "module keyword key1 key2 ..." to search for all possible modules matching any of the "keys".
```

Luckily, there is one. Let's load this module into our environment.
```sh
$ module load Rstudio-server/2023.12.1-402
$ which rserver
/apps/lib-osver/Rstudio-server/2023.12.1-402/bin/rserver                      $ which rstudio-server
/apps/lib-osver/Rstudio-server/2023.12.1-402/bin/rstudio-server
```

You can also add the line `module load Rstudio-server/2023.12.1-402` to your `~/.bash_profile` or `~/.zshrc` (if you are using `zsh`) so that it will be automatically loaded each time you log in.

#### 02. Clone some helper scripts

```sh
$ git clone https://github.com/Zepeng-Mu/rstudio-server-conda.git
```

This was forked from https://github.com/grst/rstudio-server-conda. This repo also allows you to run RStudio Server using Docker or Singularity containers; these are needed when there's no pre-installed RStudio Server. In our case, we only need the scripts in `local` directory. I have made several changes to make it work on ERIS.

#### 03. Run RStudio Server (rserver)

```sh
$ cd rstudio-server-conda/local
$ ./start_rstudio_server.sh 8787
```

You can make an alias in your `~/.bash_profile` or `~/.zshrc` to make things easier:
```sh
alias rs='~/tools/rstudio-server-conda/local/start_rstudio_server.sh 8787'
```

If RStudio Server is successfully launched, you will get something like this:

```sh
## Current env is >>
/PHShome/zm104/miniforge3/envs/seurat5
TTY detected. Printing informational message about logging configuration. Logging configuration loaded from '/etc/rstudio/logging.conf'. Logging to '/PHShome/zm104/.local/share/rstudio/log/rserver.log'.
```

But remember that we are running `rserver` on ERIS. To connect to it from a browser window on your local computer, you need to forward the port to your local computer. We will do this in VS Code.

Find the "PORTS" tab in VS Code, click "Add Port", input `8787`.

#### 04. Connect to RStudio in browser

Now you can copy the "Forwarded Address" from VS Code and paste it in your favorite browser. Sometimes you need to refresh a few times to connect. This is just an issue with older version of `rserver` .

## Caveats

- Setting up can be a pain. One needs to login through terminal first, and then launch VS Code, and then launch the server from an interactive session. This is because there is no easy way to do ssh tunneling on ERIS. But hopefully this only needs to be done once each day.

## Perks

- One nice thing about VS Code connection is that once you have connected, you don't need VPN when you are off-campus. You only need VPN to launch VS Code from you terminal, but after that VPN is not necessary.
