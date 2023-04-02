#!/bin/bash 

printf "Function: \nIf this script runs smoothly, all necessary dependencies for OpenFASoC will be 
downloaded at once. If you've already downloaded all dependencies with this script, 
you can run this script again to update the installed dependencies.\n
Basic Requirements (not exhaustive): 
(1) Python 3.7 or higher is required.
(2) Intel x86 architecture is required, as this script will use Conda to download several
Python packages for which versions compatible with ARM architecture currently do not
exist for installation in Conda's package repository. If your machine does not run 
on Intel x86 architecture, this script will likely not work.
(3) CentOS and Ubuntu are the only operating systems this script has been verified to work on.
We cannot guarantee successful compilation on other systems.\n\n"

proceed_confirmed=false
update_confirmed=false
while ! $proceed_confirmed
do
        echo "Do you wish to proceed with the installation? 
[y] Yes. Install for the first time.
[u] Yes. Update already-installed dependencies.
[n] No. Exit this script." 
        read -p "Select the desired option: " selection
        if [ "$selection" == "y" ] || [ "$selection" == "Y" ]; then 
        echo "Beginning installation..."; proceed_confirmed=true
        elif [ "$selection" == "n" ] || [ "$selection" == "N" ]; then
        echo "Quitting script."; exit
        elif [ "$selection" == "u" ] || [ "$selection" == "U" ]; then
        update_confirmed=true
        proceed_confirmed=true
        else
        echo "Invalid selection. Choose y or n."
        fi
done

if $update_confirmed; then
        if ! [ -x /usr/bin/miniconda3 ]; then
                echo "Conda could not be found. If you have not yet successfully installed the dependencies, you cannot update the dependencies."
                exit
        fi
        echo "Note: Because the latest version of Conda requires Python 3.8 or higher, your device
must be equipped with Python 3.8 or above for this script to fully update everything. If you have
Python 3.7, this script will nonetheless run and attempt to install every compatible update."
        export PATH=/usr/bin/miniconda3/bin:$PATH
        conda update conda -y
        if [ $? != 0 ]; then conda install -c anaconda conda -y; if [ $? != 0 ]; then echo "Failed to update conda" ; exit ; fi ; fi
        update_successful=true
        conda update --all -y
        if [ $? != 0 ]; then 
        echo "Attempting to install core packages individually..."
        conda install -c litex-hub magic -y; if [ $? != 0 ]; then update_successful=false; echo "magic could not be updated"; fi
        conda install -c litex-hub netgen -y; if [ $? != 0 ]; then update_successful=false; echo "netgen could not be updated"; fi
        conda install -c litex-hub open_pdks.sky130a -y; if [ $? != 0 ]; then update_successful=false; echo "open_pdks could not be updated"; fi
        conda install -c litex-hub openroad -y; if [ $? != 0 ]; then update_successful=false; echo "openroad could not be updated"; fi
        conda install -c litex-hub yosys -y; if [ $? != 0 ]; then update_successful=false; echo "yosys could not be updated"; fi
        fi
        if [ $update_successful ]; then
        echo "Magic, netgen, open_pdks, openroad, and yosys updated successfully to latest versions possible given user's Python (completely latest versions if >=3.8)."
        fi

        echo "Updating ngspice..."
        cd ngspice
        git pull --rebase
        ./compile_linux.sh 
        if [ $? == 0 ]; then
        echo "ngspice updated successfully."
        else 
        echo "nspice could not be updated."
        fi

        echo "Updating xyce..."
        SRCDIR=$PWD/Trilinos-trilinos-release-12-12-1
        LIBDIR=/opt/xyce/xyce_lib
        INSTALLDIR=/opt/xyce/xyce_serial
        FLAGS="-O3 -fPIC"
        if cat /etc/os-release | grep "centos" >> /dev/null
        then
                yum install -y centos-release-scl
                yum install -y devtoolset-7
                scl enable devtoolset-7 bash
        fi
        cd ./docker/conda/scripts/Xyce
        git pull --rebase
        ./bootstrap
        ./configure CXXFLAGS="-O3 -std=c++11" ARCHDIR=$LIBDIR --prefix=$INSTALLDIR CPPFLAGS="-I/usr/include/suitesparse"
        make
        make install
                if [ $? == 0 ]; then
        echo "xyce updated successfully."
        else 
        echo "xyce could not be updated."
        fi

        echo "All dependencies except Klayout have been updated. To update Klayout, visit https://www.klayout.de/build.html and follow the instructions."

fi



if which python3 >> /dev/null
then
	echo "Python3 exists. Continuing..."
else
	echo "Python3 could not be found. Please install python3 and try again. Exiting..."
	exit
fi

ma_ver=$(python3 -c"import sys; print(str(sys.version_info.major))")
mi_ver=$(python3 -c"import sys; print(str(sys.version_info.minor))")

if [ "$ma_ver" -lt 3 ]
then
    echo "[Warning] python version less than 3.* . Not compatible. You atleast need version above or equal to 3.7."
    sed -i 's/gdsfactory==5.1.1/#gdsfactory==5.1.1/g' requirements.txt
    echo "[Warning] Skipping installing the gdsfactory python package because of that error. Continuing installation..."
elif [ "$mi_ver" -lt 6 ]
then
    echo "[Warning] python version less than 3.6 . Not compatible. You atleast need version above or equal to 3.7."
    sed -i 's/gdsfactory==5.1.1/#gdsfactory==5.1.1/g' requirements.txt
    echo "[Warning] Skipping installing the gdsfactory python package because of that error. Continuing installation..."
else
    echo "Compatible python version exists: $ma_ver.$mi_ver"
fi


if which pip3 >> /dev/null
then
        echo "Pip3 exists"
        pip3 install -r requirements.txt

else
        if cat /etc/os-release | grep "ubuntu" >> /dev/null
        then
                echo "Ubuntu"
                apt install python3-pip -y
                if [ $? == 0 ]
                then
                       pip3 install -r requirements.txt
                       apt install wget git -y
                else
                        echo "Pip3 installation failed.. exiting"
                        exit
                fi

        elif cat /etc/os-release | grep -e "centos" -e "el7" -e "el8" >> /dev/null
        then
                echo "Centos"
                yum install python3-pip -y
                if [ $? == 0 ]
                then
                       pip3 install -r requirements.txt
		       yum install wget git -y
                else
                        echo "Pip3 installation failed.. exiting"
                        exit
                fi
        else
                echo "This script is not compatabile with your Linux Distribution"
		exit
        fi
fi

if [ $? == 0 ]
then
 echo "Python packages installed successfully. Continuing the installation...\n"
if ! [ -x /usr/bin/miniconda3 ]
then
      wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.12.0-Linux-x86_64.sh \
    && bash Miniconda3-py37_4.12.0-Linux-x86_64.sh -b -p /usr/bin/miniconda3/ \
    && rm -f Miniconda3-py37_4.12.0-Linux-x86_64.sh
else
    echo "Found miniconda3. Continuing the installation...\n"
fi
else
	echo "Failed to install python packages. Check above for error messages."
	exit
fi


if [ $? == 0 ] && [ -x /usr/bin/miniconda3 ]
then
        echo "miniconda3 installed successfully. Continuing the installation...\n"
	export PATH=/usr/bin/miniconda3/bin:$PATH
	conda update -y conda
        if [ $? == 0 ];then conda install -c litex-hub --file conda_versions.txt -y ; else echo "Failed to update conda" ; exit ; fi
        if [ $? == 0 ];then echo "Installed OpenROAD, Yosys, Skywater PDK, Magic and Netgen successfully" ; else echo "Failed to install conda packages" ; exit ; fi
else
	echo "Failed to install miniconda. Check above for error messages."
	exit
fi

if cat /etc/os-release | grep "ubuntu" >> /dev/null
then
	apt install bison flex libx11-dev libx11-6 libxaw7-dev libreadline6-dev autoconf libtool automake -y
	git clone http://git.code.sf.net/p/ngspice/ngspice
	cd ngspice && ./compile_linux.sh

elif cat /etc/os-release | grep "centos" >> /dev/null
then
	sudo yum install bison flex libX11-devel libX11 libXaw-devel readline-devel autoconf libtool automake -y
	git clone http://git.code.sf.net/p/ngspice/ngspice
	cd ngspice && ./compile_linux.sh
fi

if [ $? == 0 ]
then
 echo "Ngspice is installed. Checking pending. Continuing the installation...\n"
 cd ../
else
 echo "Failed to install Ngspice"
 exit
fi


if cat /etc/os-release | grep "ubuntu" >> /dev/null
then
	export DEBIAN_FRONTEND=noninteractive
	cd docker/conda/scripts
	./xyce_install.sh
elif cat /etc/os-release | grep "centos" >> /dev/null
then
	export DEBIAN_FRONTEND=noninteractive
	cd docker/conda/scripts
	./xyce_install_rhel.sh
fi

if [ $? == 0 ]
then
 echo "Xyce is installed. Checking pending. Continuing the installation...\n"
else
 echo "Failed to install Xyce"
 exit
fi

if cat /etc/os-release | grep "ubuntu" >> /dev/null
then
	apt install qt5-default qttools5-dev libqt5xmlpatterns5-dev qtmultimedia5-dev libqt5multimediawidgets5 libqt5svg5-dev ruby ruby-dev python3-dev libz-dev build-essential -y
	wget https://www.klayout.org/downloads/Ubuntu-20/klayout_0.27.10-1_amd64.deb
	dpkg -i klayout_0.27.10-1_amd64.deb
	apt install time -y
	strip --remove-section=.note.ABI-tag /usr/lib/x86_64-linux-gnu/libQt5Core.so.5 #https://stackoverflow.com/questions/63627955/cant-load-shared-library-libqt5core-so-5
elif cat /etc/os-release | grep -e "centos" >> /dev/null
then
	yum install qt5-qtbase-devel qt5-qttools-devel qt5-qtxmlpatterns-devel qt5-qtmultimedia-devel qt5-qtmultimedia-widgets-devel qt5-qtsvg-devel ruby ruby-devel python3-devel zlib-devel time -y
	wget https://www.klayout.org/downloads/CentOS_7/klayout-0.28.2-0.x86_64.rpm
	rpm -i klayout-0.28.2-0.x86_64.rpm
	yum install time -y
        strip --remove-section=.note.ABI-tag /usr/lib64/libQt5Core.so.5
else
	echo "Cannot install klayout for other linux distrbutions via this script"
fi

if [ $? == 0 ]
then
 echo "Installed Klayout successfully. Checking pending..."
else
 echo "Failed to install Klayout successfully"
 exit
fi

export PATH=/usr/bin/miniconda3/bin:$PATH

if [ -x /usr/bin/miniconda3/share/pdk/ ]
then
 export PDK_ROOT=/usr/bin/miniconda3/share/pdk/
 echo "PDK_ROOT is set to /usr/bin/miniconda3/share/pdk/. If this variable is empty, try setting PDK_ROOT variable to /usr/bin/miniconda3/share/pdk/"
else
 echo "PDK not installed"
fi
echo ""
echo ""
echo "To access the installed binaries, please run this command or add this to your .bashrc file - export PATH=/usr/bin/miniconda3/bin:\$PATH"
echo "To access xyce binary, create an alias - xyce='/opt/xyce/xyce_serial/bin/Xyce'"

echo "################################"
echo "Installation completed"
echo "Thanks for using OpenFASOC dependencies script. To submit feedback, feel free to open a github issue on OpenFASOC repo"
echo "To know more about generators, go to openfasoc.readthedocs.io"
echo "################################"
