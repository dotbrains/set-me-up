# `set-me-up`

![preview](preview.png)

`set-me-up` aims to simplify the dull setup and maintenance of Mac OS development environments.
It does so by automating the process through a collection of dotfiles and shell scripts [bundled into modules](#available-modules).

Instead of enforcing a certain setup it tries to act as a solid template that is highly customizable to your needs.

## Table of Contents

- [`set-me-up`](#set-me-up)
	- [Table of Contents](#table-of-contents)
	- [Usage](#usage)
		- [Use the blueprint](#use-the-blueprint)
		- [Obtaining `set-me-up`](#obtaining-set-me-up-via-set-me-up-installer)
		- [Running `set-me-up`](#running-set-me-up)
		- [Customize `set-me-up`](#customize-set-me-up)
			- [Using hooks](#using-hooks)
			- [Using `rcm`](#using-rcm)
				- [Creating a custom tag](#creating-a-custom-tag)
		- [Wait! I am confused 😕](#wait-i-am-confused-)
	- [A closer look 🤓](#a-closer-look-)
		- [The smu script](#the-smu-script)
		- [How does it work?](#how-does-it-work)
		- [Local Settings](#local-settings)
			- [`~/.bash.local`](#bashlocal)
			- [`~/.fish.local`](#fishlocal)
			- [`~/.zsh.local`](#zshlocal)
	- [Credits](#credits)
	- [Liability](#liability)
	- [Contributions](#contributions)
	- [License](#license)

## Usage

No matter how you obtain `smu`, as a sane developer you should take a look at the provided modules and dotfiles to verify that no shenanigans are happening.

### Use the blueprint

The recommended way to obtain `set-me-up` is by forking the [blueprint setup](https://github.com/nicholasadamou/set-me-up-blueprint), which is its own lean repo that comes pre-configured with a [tag](#using-rcm) and module.

You might wonder why not work directly with this repo? Having a remote and external repo for your dotfiles and `set-me-up` customizations has a few advantages:

- It is loosely coupled, making your life way easier. The only connection between your repo and `set-me-up` is through the installer.
- You can easily walk away from using `set-me-up` but can keep your precious dotfiles and shell scripts.
- It is easier to make your setup private because there are no direct ties to the blueprint or `set-me-up` repo.
- Your commit history and file list will stay clean.
- The referenced `set-me-up` version is fixated in the installer, ensuring that your setup will work even when the master advances. Advancing to the next version is easy by bumping the version in the installer.
- Its fancy, at least I think so 😉.

### Obtaining `set-me-up` via [`set-me-up` installer](https://github.com/nicholasadamou/set-me-up-installer)

To start, your default shell must be set to `bash` prior to executing the `install` snippet for the first time. This is because on newer versions of Mac OS, the default shell is `zsh` instead of `bash`. To change your default shell, run the following command in your console.

```bash
sudo chsh -s $(which bash) $(whoami)
```

Once the default shell is `bash`, close and reopen the terminal window. Then, run the following command in your console.

(⚠️ **DO NOT** run the `install` snippet if you don't fully
understand [what it does](https://raw.githubusercontent.com/nicholasadamou/set-me-up-installer/main/install.sh). Seriously, **DON'T**!)

```bash
bash <(curl -s -L https://raw.githubusercontent.com/nicholasadamou/set-me-up-installer/main/install.sh)
```

You can change the `smu` home directory by setting an environment variable called `SMU_HOME_DIR`. Please keep the variable declared or else the `smu` scripts are unable to pickup the sources.

```bash
export SMU_HOME_DIR="some-path" \
    bash <(curl -s -L https://raw.githubusercontent.com/nicholasadamou/set-me-up-installer/main/install.sh)
```

### Running `set-me-up`

[![xkcd: Automation](http://imgs.xkcd.com/comics/automation.png)](http://xkcd.com/1319/)

1. Use the `smu` script (which you will find inside the `smu` home directory) to run the base module. Check out the [base module documentation](#base) for more insights.

        smu --provision \
			--module base

    ⚠️ Please note that after running the base module, moving the source folder is not recommended due to the usage of symlinks.

2. Afterwards, provision your machine with [further modules](#available-modules) via the `smu` script. Repeat the `-m` switch to specify more then one module.

        smu --provision \
			--module app_store \
			--module casks \
			--module php \
			--no-base

    As a general rule of thumb, only pick the modules you need, running all modules can take quite some time.
    Fear not, all modules can be installed when you need it.

### Customize `set-me-up`

#### Using hooks

To customize the setup to your needs `set-me-up` provides two hook points: Before and after sourcing the module script.

Before hooks enable you to perform special preparations or apply definitions that can influence the module. All `smu` base variables are defined to check if an existing declaration already exists, giving you the possibility to come up with your own values.

Polishing module setups or using module functionality can be done with after hooks. A bit of inspiration: By calling git commands in an after hook file you could replace the git username and email placeholders or install further extensions.

To use hooks provide a `before.sh` or `after.sh` inside the module directory. Use `rcm` tags to provide the hook files.

#### Using `rcm`

Through the power of [rcm tags](http://thoughtbot.github.io/rcm/rcup.1.html) `set-me-up` can favor your version of a file when you provide one. This mitigates the need to tinker directly with `set-me-up` source files.

[Create your own `rcm` tag](#creating-a-custom-tag) and then duplicate the directory structure and files you would like to modify. `rcm` will combine all files from the given tags in the order you define. For example, when you would like to modify the `brewfile` of the app_store module, the path should look like this: `.dotfiles/tag-my/modules/app_store/brewfile`.

Use the `smu --lsrc` command to show how `rcm` would manage your dotfiles and to verify your setup.

- You can add new dotfiles and modules to your tag. `rcm` symlinks all files if finds.
- File contents are not merged between tags, your file simply has a higher precedence and will be used instead.

Use `smu --rcup` command to symlink the dotfiles using [`rcup`](http://thoughtbot.github.io/rcm/rcup.1.html) contained within [`.dotfiles`](/.dotfiles) using [`.rcrc`](/.dotfiles/rcrc).

Additionally, you can use `smu --rcdn` command to remove files listed within [`.rcrc`](/.dotfiles/rcrc) that were symlinked via `rcup` from [`.dotfiles`](/.dotfiles).

##### Creating a custom tag

1. Create a new `rcm` tag, by creating a new folder prefixed `tag-` inside the [`.dotfiles`](/.dotfiles) directory: `.dotfiles/tag-my`
2. Add your tag to the [`.rcrc`](/.dotfiles/rcrc) configuration file in front of the currently defined tags. Resulting in `TAGS="my smu"`

### Wait! I am confused 😕

[Go to the blueprint repo](https://github.com/nicholasadamou/set-me-up-blueprint#how-to-use). Fork it. Apply your changes using the techniques from above. Use the installer inside your forked repo to obtain everything. Provision your machine through the `smu` script.

For more on using the `smu` script, simply run `smu --help`.

## A closer look 🤓

### [The smu script](https://github.com/nicholasadamou/set-me-up-installer/blob/main/smu)

The `smu` script is part of the `set-me-up` toolkit, designed to automate the setup of a development environment on macOS or Debian-based Linux systems. It begins by sourcing utility functions and defining key paths for the installation process. The script detects the operating system and creates necessary configuration files if they do not already exist. It then checks for the presence of essential tools like Homebrew, Python 3, RCM, and Git, installing them if necessary. The script also ensures that Homebrew is properly initialized and its paths are correctly set. Finally, it pulls the latest updates from the `set-me-up-installer` repository and runs the [`smu.py`](https://github.com/nicholasadamou/set-me-up-installer/blob/main/smu.py) script to complete the setup process. The `smu` script streamlines the configuration of a consistent development environment, saving time and reducing the potential for errors.

#### How does it work?

> Hamid: What's that?

> Rambo: It's blue light.

> Hamid: What does it do?

> Rambo: It turns blue.

**TL;DR;** It symlinks all dotfiles and stupidly runs shell scripts.

`smu` symlinks all dotfiles from the `.dotfiles` folder, which includes the modules, to your home directory. With the power of [rcm](https://github.com/thoughtbot/rcm), `.dotfiles/tag-smu/gitconfig` becomes `~/.gitconfig`. Using bash scripting the installation of `brew` is ensured. All this is covered by the base module and provides an opinionated base setup on which `smu` operates.

Depending on the module, further applications will be installed by "automating" their installation through other bash scripts.
In most cases `set-me-up` delegates the legwork to tools that are meant to be used for the job (e.g. installing `zplugin` for zsh plugin management).

Nothing describes the actual functionality better than the code. It is recommended to check the appropriate module script to gain insights as to what it exactly does.

`set-me-up` is a plain collection of bash scripts and tools that you probably already worked with, therefore understanding what is happening will be easy 😄.

### Local Settings

The `dotfiles` can be easily extended to suit additional local
requirements by using the following files:

#### `~/.bash.local`

The `~/.bash.local` file it will be automatically sourced after
all the other [`bash` related files](/.dotfiles/tag-smu/config), thus, allowing
its content to add to or overwrite the existing aliases, settings,
PATH, etc.

Here is a very simple example of a `~/.bash.local` file:

```bash
# Set local aliases.

alias starwars="telnet towel.blinkenlights.nl"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set PATH additions.

export $PATH="$HOME/dotfiles/src/symlinks/.local/bin:$PATH"
```

#### `~/.fish.local`

The `~/.fish.local` file it will be automatically sourced after
all the other [`fish` related files](/.dotfiles/tag-smu/config), thus, allowing
its content to add to or overwrite the existing aliases, settings,
PATH, etc.

Here is a very simple example of a `~/.fish.local` file:

```fish
# Set local aliases.

alias starwars "telnet towel.blinkenlights.nl"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set PATH additions.

set -gx PATH $PATH "$HOME/dotfiles/src/symlinks/.local/bin"
```

#### `~/.zsh.local`

The `~/.zsh.local` file it will be automatically sourced after
all the other [`zsh` related files](/.dotfiles/tag-smu/config), thus, allowing
its content to add to or overwrite the existing aliases, settings,
PATH, etc.

Here is a very simple example of a `~/.zsh.local` file:

```bash
# Set local aliases.

alias starwars="telnet towel.blinkenlights.nl"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set PATH additions.

export $PATH="$HOME/dotfiles/src/symlinks/.local/bin:$PATH"
```

## Credits

- [omares/set-me-up](https://github.com/omares/set-me-up) for the initial platform that [nicholasadamou/set-me-up](https://github.com/nicholasadamou/set-me-up) was built on.
- [donnemartin/dev-setup](https://github.com/donnemartin/dev-setup)
- [mathiasbynens](https://github.com/mathiasbynens/dotfiles) for his popular [macOS script](https://github.com/mathiasbynens/dotfiles/blob/master/.macos).
- [brew](https://brew.sh/) and [brew bundle](https://github.com/Homebrew/homebrew-bundle) for the awesome package management.
- [thoughtbot rcm](https://github.com/thoughtbot/rcm) for easy dotfile management.
- All of the authors of the installed applications via `set-me-up` , I am in no way connected to any of them.

Should I miss your name on the credits list please let me know :heart:

## Liability

The creator of this repo is _not responsible_ if your machine ends up in a state you are not happy with.

## Contributions

Yes please! This is a GitHub repo. I encourage anyone to contribute. 😃

## License

The code is available under the [MIT license](LICENSE).
