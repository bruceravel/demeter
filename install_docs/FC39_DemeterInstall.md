# Install Demeter on Fedora 39
------------------------------
Follow these steps to install Demeter from source on Fedora 39.

1. Prepare perl

   - perl should be up-to-date and sufficient for installing Demeter on Fedora but it is good practice to confirm. Execute the following line in a terminal and confirm the version is later than 5.8. On Fedora 39, perl 5.38.0 should be installed.

     ```bash
     perl --version
     ```

   - Install the build system, which includes CPAN and Module::Build.

     ```bash
     sudo dnf install perl-CPAN perl-Module-Build
     ```

2. Install gnuplot

   - Check if gnuplot is installed

     ```bash
     gnuplot --version
     ```

   - If it is not found, you can install a minimal version of gnuplot. The Wx version can also be installed, however the version of Wx too recent for what is required in Demeter.
   
     ```bash
     sudo dnf install gnuplot-minimal
     ```

   - If it is not found, you can install gnuplot using `sudo dnf install gnuplot gnuplot-wx`

3. Install dependencies

   - Several dependencies are required for building IFEFFIT and Demeter. Install the following list of packages:

     ```bash
     sudo dnf install gcc gcc-c++ gcc-gfortran git libX11-devel ncurses ncurses-devel 
     ```

4. Install IFEFFIT

   - Programs can be downloaded and built in various locations. I like to setup a `~/software` directory to build in.
   - Download IFEFFIT from the [github repository](https://github.com/newville/ifeffit).

     ```bash
     git clone --depth=1 https://github.com/newville/ifeffit.git
     ```

   - Change into the `ifeffit` directory and start to build. Since we will use `gnuplot` for plotting in Demeter, these instructions will build `ifeffit` without `PGPLOT`

     ```bash
     cd ifeffit
     FFLAGS="-g -O2 -fPIC" ./configure --without-pgplot
     make
     sudo make install
     ```

5. Install Demeter

   - Download `Demeter` into the `software` directory from the [github repository](https://github.com/bruceravel/demeter).

     ```bash
     git clone --depth=1 https://github.com/bruceravel/demeter.git
     ```

   - Change into the `demeter` directory.

     ```bash
     cd demeter
     ```

   - We need to export a variable so `perl` knows where the `DemeterBuilder.pm` file is located. Since we are in the directory, we can assign the current location to the `PERL5LIB` variable and then confirm the correct location.

     ```bash
     export PERL5LIB=$(pwd -P)
     echo $PERL5LIB
     ```

     This is a temporary variable assignment. `PERL5LIB` can be set in `~/.bashrc` to make this assignment permanent.

   - Configure CPAN
     Configure CPAN by running the following command. Allowing it to automatically configure itself is usually sufficient.

     ```bash
     sudo cpan
     ```
   
   - To fix a bug where some buttons do not display the text, make the buttons larger by running the following command.

     ```bash
     sed '1653,1656s/25/35/' -i lib/Demeter/UI/Athena.pm
     ```

   - First pass installing `perl` dependencies

     Start to install the necessary dependencies to run `Demeter`. It will ask about some optional package, say yes to all of them.

     ```bash
     perl ./Build.PL
     sudo ./Build installdeps
     ```

     This process will take a while. Try to keep an eye on it because there are some questions that pop up which will pause the installation.

     You can also get an infinite loop looking for `apache src``. Hit `Ctrl-C` to continue the installation.

     ```
     Can't stat `../apache_x.x/src'
     Please tell me where I can find your apache src
       [../apache_x.x/src] ../apache_x.x/src
     ```

   - Fix failed dependencies

     Some dependencies might fail during the first pass. Here I will walk through the failed dependencies for the current install.

     ```bash
     perl ./Build.PL
     ...
     Checking prerequisites...
       requires:
        !  XMLRPC::Lite is not installed
      recommends:
        *  Wx is not installed
     ...
     ```

     Let's install `XMLRPC::Lite`. Simply running the install again was successful.

     ```bash
     sudo cpan -i XMLRPC::Lite
     ```

     Now let's fix Wx. It looks like the older version of `wxWidgets` (3.0.5) is no longer in the fedora repositories. We will need to build from source.

     For good measure, let's remove the failed builds.

     ```bash
     sudo rm -rf /root/.local/share/.cpan/build/Wx*
     sudo rm -rf /root/.local/share/.cpan/build/Alien*
     ```

     Download the sources for `wxWidgets 3.0.5` and enter the directory.
     ```bash
     git clone --depth=1 --branch=v3.0.5 https://github.com/wxWidgets/wxWidgets.git
     cd wxWidgets
     ```

     Install the dependencies to build wxWidgets

     ```bash
     sudo dnf install gtk3-devel mesa-libGL-devel mesa-libGLU-devel gstreamer1-plugins-base-devel libcurl-devel webkit2gtk4.0-devel libpng-devel libjpeg-turbo-devel libtiff-devel zlib-devel
     ```

     Build `wxWidgets`

     ```bash
     mkdir buildgtk
     cd buildgtk
     ../configure --with-gtk
     make
     sudo make install
     sudo ldconfig
     ```

     Let's check `Demeter` again. From the `demeter` source directory:

     ```bash
     perl ./Build.PL
     sudo ./Build installdeps
     ```

     We see an error building `Wx`. We will need to fix that manually.

     ```bash
     sudo su -
     cd /root/.local/share/.cpan/build/Wx*
     sed '27187s/wxVariant(/wxAny(/' -i ext/propgrid/PropertyGrid.c
     make
     sed '12704s/THIS->GetPixel()/NULL/' -i GDI.c
     make
     LD_LIBRARY_PATH=/usr/local/lib make test
     make install
     ```
   - Install `Demeter`

     ```bash
     perl Build.PL
     sed '307 i compile_flags .= "-w";' -i DemeterBuilder.pm
     ./Build
     LD_LIBRARY_PATH=/usr/local/lib ./Build test
     sudo ./Build install
     ```
6. Run `Demeter`

   The programs are still missing the library path so to execute, for example, Athena, you must run:

   ```bash
   LD_LIBRARY_PATH=/usr/local/lib dathena
   ```

   It would be a good idea to setup an alias in `~/.bashrc` or a simple script in `~/bin/` which would set the `LD_LIBRARY_PATH` automatically.

7. Setup desktop icons

   - The desktop files are located in `~/.local/share/applications/`
   - The desktop files can be copied from this document and include:

   `dathea.desktop`

   ```
   [Desktop Entry]
   Version=1.0
   Type=Application

   Name=Athena
   Comment=Process X-ray Absorption Spectroscopy Data
   Categories=Science;Physics;

   Icon=/home/akiss/software/demeter/lib/Demeter/UI/Athena/share/athena_icon.png
   Exec=bash -c "LD_LIBRARY_PATH=/usr/local/lib dathena"
   Terminal=false

    ```

    `dartemis.desktop`

    ```
    [Desktop Entry]
    Version=1.0
    Type=Application

    Name=Artemis
    Comment=Process X-ray Absorption Spectroscopy Data
    Categories=Science;Physics;

    Icon=/home/akiss/software/demeter/lib/Demeter/UI/Artemis/share/artemis_icon.png
    Exec=bash -c "LD_LIBRARY_PATH=/usr/local/lib dartemis"
    Terminal=false
    ```

    `dhephaestus.desktop`

    ```
    [Desktop Entry]
    Version=1.0
    Type=Application

    Name=Hephaestus
    Comment=Process X-ray Absorption Spectroscopy Data
    Categories=Science;Physics;

    Icon=/home/akiss/software/demeter/lib/Demeter/share/Demeter_icon.png
    Exec=bash -c "LD_LIBRARY_PATH=/usr/local/lib dhephaestus"
    Terminal=false
    ```