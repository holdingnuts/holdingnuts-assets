#!/bin/bash
# release script

if [[ $# != 2 && $# != 4 ]] ; then
	echo "source package:" >&2
	echo "  mk_release.sh <src-dir> <version>" >&2
	echo "binary package:" >&2
	echo "mk_release.sh <src-dir> <build-dir> <platform> <version>" >&2
	exit 0
elif [[ $# == 2 ]] ; then
	src_release=1
fi


TRUNK=$1

if [[ ${src_release} ]] ; then
	RELVER=$2
else
	BUILD=$2
	PLATFORM=$3
	RELVER=$4
fi

if [[ ! -d ${TRUNK} ]] ; then
	echo "Error: Trunk dir does not exist." >&2
	exit 1
fi

if [[ ! ${src_release} ]] ; then
	if [[ ! -d ${BUILD} ]] ; then
		echo "Error: Build dir does not exist." >&2
		exit 1
	fi

	if [[ ${PLATFORM} != linux_x86 && ${PLATFORM} != linux_x86_64 && ${PLATFORM} != win32 ]] ; then
		echo "Error: Unsupported platform: ${PLATFORM}" >&2
		exit 1
	fi

	case ${PLATFORM} in
	win* )
		convert_text=1
		is_windows=1
		;;
	esac
	
	PKGSTR="holdingnuts-${RELVER}-${PLATFORM}"
else
	# source release filename convention
	PKGSTR="holdingnuts-${RELVER}"
fi



TMPDIR=$PKGSTR

echo "--- mk_release.sh running for ${PKGSTR} ---"

err_wait=

if [[ ! ${src_release} ]] ; then
	echo
	echo "IMPORTANT:"
	echo "Configure and build the sources with"
	echo "  cmake -DCMAKE_BUILD_TYPE=Release -DUSE_SVNREV=On"
	echo
	echo "Checking..."
	
	cmake_cachefile=${BUILD}/CMakeCache.txt
	
	cmake_build_type=$(sed -n 's/CMAKE_BUILD_TYPE:STRING=\(.*\).*/\1/p' ${cmake_cachefile})
	if [[ ${cmake_build_type} != [Rr][Ee][Ll][Ee][Aa][Ss][Ee] ]]; then
		echo "Warning: CMAKE_BUILD_TYPE is not 'Release' (value: ${cmake_build_type})"
		err_wait=1
	else
		echo "    OK: CMAKE_BUILD_TYPE=${cmake_build_type}"
	fi
	
	cmake_usesvnrev=$(sed -n 's/USE_SVNREV:BOOL=\(.*\).*/\1/p' ${cmake_cachefile})
	if [[ ${cmake_usesvnrev} != [Oo][Nn] ]]; then
		echo "Warning: USE_SVNREV is not 'On' (value: ${cmake_usesvnrev})"
		err_wait=1
	else
		echo "    OK: USE_SVNREV=${cmake_usesvnrev}"
	fi
fi

echo
echo "Checking for unmodified trunk..."
SVNREV=$(svnversion ${TRUNK})
echo "SVN revision: ${SVNREV}"

match=$(echo ${SVNREV} | grep '^[[:digit:]]*$')

if [[ -n $match ]]; then
	echo "OK."
else
	echo "Warning: The working copy was modified or is not up-to-date."
	echo
	err_wait=1
fi


SVNSTATUS=$(svn st --no-ignore ${TRUNK})

# check svn status and throw warning if modified
if [[ -n ${SVNSTATUS} ]] ; then
	echo "Warning: The working copy isn't clean:"
	echo "${SVNSTATUS}"
	echo
	err_wait=1

fi


if [[ ${err_wait} ]] ; then
	echo -n "There were warnings/errors. Continue anyway? (N/y) "
	read input
	
	[[ ${input} != y && ${input} != Y ]] && exit 1
fi


echo

if [[ -d ${TMPDIR} ]] ; then
	echo "Deleting old temporary working directory..."
	rm -rf ${TMPDIR}
fi


echo "Creating temporary working directory ${TMPDIR}..."
mkdir ${TMPDIR}


if [[ ! ${src_release} ]] ; then
	if [[ ${convert_text} ]] ; then
		echo "Copying and converting license file..."
		awk '{ sub(/$/,"\r"); print }' ${TRUNK}/LICENSE >${TMPDIR}/LICENSE.txt    # convert LF to CRLF
	else
		echo "Copying license file..."
		cp -t ${TMPDIR} ${TRUNK}/LICENSE
	fi


	if [[ ${convert_text} ]] ; then
		echo "Copying and converting ChangeLog file..."
		awk '{ sub(/$/,"\r"); print }' ${TRUNK}/ChangeLog >${TMPDIR}/ChangeLog.txt    # convert LF to CRLF
	else
		echo "Copying ChangeLog file..."
		cp -t ${TMPDIR} ${TRUNK}/ChangeLog
	fi


	echo "Copying data-dir..."
	cp -r -t ${TMPDIR} ${TRUNK}/data


	echo "Copying binaries..."
	if [[ $is_windows ]] ; then
		BINS="${BUILD}/src/client/holdingnuts.exe ${BUILD}/src/server/holdingnuts-server.exe"
		cp -t ${TMPDIR} ${BINS}
	else
		BINS="${BUILD}/src/client/holdingnuts ${BUILD}/src/server/holdingnuts-server"
		cp -t ${TMPDIR} ${BINS}
		
		# wrapper script
		cp -t ${TMPDIR} files/holdingnuts.sh
	fi
	
	
	echo "Stripping binaries..."
	strip --strip-unneeded -R .comment ${BINS}
	

	echo "Copying translations..."
	cp -t  ${TMPDIR}/data/i18n ${BUILD}/src/client/*.qm

	if [[ ! $is_windows ]] ; then
		echo "Creating empty lib directory"
		mkdir ${TMPDIR}/lib
	fi

	echo "Copying shortcuts..."
	if [[ $is_windows ]] ; then
		cp -t ${TMPDIR} files/holdingnuts.net.url
		cp -t ${TMPDIR} files/config_directory.lnk
	else
		cp -t ${TMPDIR} files/holdingnuts.net.desktop
		cp -t ${TMPDIR} files/holdingnuts.desktop
	fi

	echo "Copying icon..."
	cp -t ${TMPDIR} files/holdingnuts.png
	
	echo "!!! Do not forget to"
	echo " * copy the qt_translations (e.g. qt_de.qm) into ${TMPDIR}/data/i18n as well"
	echo " * copy the libaries (windows: *.dll into ${TMPDIR} ; linux: *.so into ${TMPDIR}/lib"
else
	echo "Copying trunk..."
	cp -r -t ${TMPDIR} ${TRUNK}/*
	
	echo "Touching svn revision info file..."
	touch ${TMPDIR}/svn_r${SVNREV}
	
	echo "Copying ChangeLog file..."
	cp -t ${TMPDIR} files/ChangeLog
	
	mkdir ${TMPDIR}/res
	
	echo "Copying Init-Script..."
	cp -t ${TMPDIR}/res files/holdingnuts-server.init
	
	echo "Copying misc..."
	cp -t ${TMPDIR}/res files/holdingnuts.png
	cp -t ${TMPDIR}/res files/holdingnuts.desktop
fi




echo "Removing svn entries..."
rm -rf $(find ${TMPDIR} -type d -name '.svn')


echo
echo "-> Now copy/remove all additional/unneeded files into/from ${TMPDIR}."
echo "Starting shell... (press ^d or type 'exit' to continue)"
PS1='\[\033[01;31m\]mk_release\[\033[01;34m\] \w \$\[\033[00m\] ' bash --norc


echo "Creating archives..."

PKG_TARGZ="tar --gzip -cf ${TMPDIR}.tar.gz ${TMPDIR}"
PKG_TARBZ2="tar --bzip2 -cf ${TMPDIR}.tar.bz2 ${TMPDIR}"
PKG_TARLZMA="tar --lzma -cf ${TMPDIR}.tar.lzma ${TMPDIR}"
PKG_ZIP="zip -r -9 -q ${TMPDIR}.zip ${TMPDIR}"

echo ${PKG_TARGZ} ; ${PKG_TARGZ}
echo ${PKG_TARBZ2} ; ${PKG_TARBZ2}
echo ${PKG_TARLZMA} ; ${PKG_TARLZMA}
echo ${PKG_ZIP} ; ${PKG_ZIP}

echo "--- mk_release.sh finished with ${PKGSTR} ---"
