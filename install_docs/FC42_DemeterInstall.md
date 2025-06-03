# Install Demeter on Fedora 42
Follow these steps to install Demeter from source on Fedora 42.

1. Prepare perl

   - perl should be up-to-date and sufficient for installing Demeter on Fedora but it is good practice to confirm. Execute the following line in a terminal and confirm the version is later than 5.8. On Fedora 42, perl 5.40.2 should be installed.

     ```bash
     perl --version
     ```

   - Install the build system, which includes CPAN and Module::Build. CPAN Minus (`cpanm`) seems to work faster and resolve dependencies better than CPAN so let's use that.

     ```bash
     sudo dnf install perl-CPAN perl-Module-Build perl-App-cpanminus
     ```


2. Install gnuplot

   - Check if gnuplot is installed

     ```bash
     gnuplot --version
     ```

   - If it is not found, you can install a minimal version of gnuplot. The Wx version seems to work better than the qt version. There seems to be a disconnect and the gnuplot-qt plot only works once and will not update. Once installed, set the `gnuplot->program` to `gnuplot-wx` and check that the terminal is set to `wxt`. 
   
     ```bash
     sudo dnf install gnuplot-wx
     ```
   

3. Install some build dependencies

   - Several dependencies are required for building IFEFFIT and Demeter. Install the following list of packages:
   - I need to confirm if `libX11-devel` is required. Trying without this.

     ```bash
     sudo dnf install gcc gcc-c++ gcc-gfortran git lncurses ncurses-devel 
     ```

4. Install IFEFFIT

   - Programs can be downloaded and built in various locations. I like to setup a `~/software` directory to build in.
   - Download IFEFFIT from the [github repository](https://github.com/newville/ifeffit).

     ```bash
     cd ~/software
     git clone --depth=1 https://github.com/newville/ifeffit.git
     ```

   - Change into the `ifeffit` directory and start to build. Since we will use `gnuplot` for plotting in Demeter, these instructions will build `ifeffit` without `PGPLOT`

     ```bash
     cd ifeffit
     FFLAGS="-g -O2 -fPIC -std=legacy" CFLAGS="-std=gnu17 -Wno-implicit-function-declaration" ./configure --without-pgplot --with-termcap-link=-lncurses
     make
     sudo make install
     ```

5. Install wxWidgets
   - Download the sources for `wxWidgets 3.0.5` and enter the directory.
       ```bash
       cd ~/software
       git clone --depth=1 --branch=v3.0.5 https://github.com/wxWidgets/wxWidgets.git
       cd wxWidgets
       ```

   - Install the dependencies to build wxWidgets

     ```bash
     sudo dnf install gtk3-devel mesa-libGL-devel mesa-libGLU-devel gstreamer1-plugins-base-devel libcurl-devel webkit2gtk4.0-devel libpng-devel libjpeg-turbo-devel libtiff-devel zlib-devel
     ```

   - Build `wxWidgets`

     ```bash
     mkdir buildgtk
     cd buildgtk
     ../configure --with-gtk
     make -j8
     sudo make install
     sudo ldconfig
     ```


6. Install Demeter


   - Download `Demeter` into the `software` directory from a newer fork of Demeter that has some moidifications [here](https://github.com/andrewmkiss/demeter-fork.git). The link to the original software can be found [here](https://github.com/bruceravel/demeter).

     ```bash
     cd ~/software
     git clone --depth=1 https://github.com/andrewmkiss/demeter-fork.git demeter
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

     This is a temporary variable assignment. `PERL5LIB` can be set in `~/.bashrc` to make this assignment permanent. This is not necessary after install is complete.

   - Configure CPAN
     Configure CPAN by running the following command. Allowing it to automatically configure itself is usually sufficient.

     ```bash
     sudo cpan
     ```
   
   - First pass installing `perl` dependencies

     Some `perl` libraries need additonal dependencies

     ```bash
     sudo dnf install expat expat-devel
     ```

     Start to install the necessary dependencies to run `Demeter`. It will ask about some optional package, say yes to all of them.

     ```bash
     perl ./Build.PL
     sudo cpanm --installdeps .
     # sudo cpanm .              # First attempt that eventually fails
     # sudo ./Build installdeps  # Instructions from bravel
     ```

     `cpanm` will only install the required dependencies. Let's install the optional ones because we will use them.

     ```bash
     sudo cpanm File::Monitor::Lite Graphics::GnuplotIF Term::Sk Term::Twiddle PDL::Filter::Linear
     ```

     Need to install wxPerl library. This requires some work.
     
     ```bash
     sudo cpan Wx 
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

     As yourself - not `root` - check the `Demeter` build again. From the `demeter` source directory:

     ```bash
     cd ~/software/demeter
     perl ./Build.PL
     # All dependencies should be resolved at this point
     # If not, you can run
     # sudo cpanm --installdeps .
     # -or-
     # sudo ./Build installdeps
     ```
    
   - Install `Demeter`

     ```bash
     perl Build.PL
     CFLAGS="-Wno-format-security" ./Build
     LD_LIBRARY_PATH=/usr/local/lib ./Build test
     sudo ./Build install
     ```
7. Run `Demeter`

   - The programs are still missing the library path so to execute, for example, Athena, you must run:

     ```bash
     LD_LIBRARY_PATH=/usr/local/lib dathena
     ```

    - I supposed this step could be moved earlier to save some typing. \
    Add this path to `ldconfig` by writing a file to `/etc/ld.so.conf.d/` named `demeter.conf`. In this file, simply write the path. `ldconfig` needs to be recached using `sudo ldconfig`. Now the `LD_LIBRARY_PATH` is no longer needed

      ```
      # /etc/ld.so.conf.d/demeter.conf
      /usr/local/lib
      ```


   
8. Setup desktop icons

   - The desktop files are located in `~/.local/share/applications/`
   - The desktop files can be copied from this document, as seen below.
   - After creating these files, run `update-desktop-database ~/.local/share/applications/`

   ```
   # ~/.local/share/applications/dathena.desktop

   [Desktop Entry]
   Version=1.0
   Type=Application

   Name=Athena
   Comment=Process X-ray Absorption Spectroscopy Data
   Categories=Science;Physics;

   Icon=/home/akiss/software/demeter/lib/Demeter/UI/Athena/share/athena_icon.png
   Exec=env GTK_THEME=Adwaita:Light dathena
   Terminal=false

    ```

    ```
    # ~/.local/share/applications/dartemis.desktop

    [Desktop Entry]
    Version=1.0
    Type=Application

    Name=Artemis
    Comment=Process X-ray Absorption Spectroscopy Data
    Categories=Science;Physics;

    Icon=/home/akiss/software/demeter/lib/Demeter/UI/Artemis/share/artemis_icon.png
    Exec=env GTK_THEME=Adwaita:Light dartemis
    Terminal=false
    ```

    ```
    # ~/.local/share/applications/dhephaestus.desktop

    [Desktop Entry]
    Version=1.0
    Type=Application

    Name=Hephaestus
    Comment=Process X-ray Absorption Spectroscopy Data
    Categories=Science;Physics;

    Icon=/home/akiss/software/demeter/lib/Demeter/share/Demeter_icon.png
    Exec=env GTK_THEME=Adwaita:Light dhephaestus
    Terminal=false
    ```