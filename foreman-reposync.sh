#!/bin/bash

# Written by Duane B. Vassar, Aug 2024.
#
# This script will download all Foreman repositories needed to install Foreman with Katello in an offline environment.
#
# This script expects there to be no current repositories for Foreman defined on the downloading host.
# The repositories will be installed and removed during the download process for each distribution defined.
#
# The script is designed to accept the list of server distributions and client distributions you wish to replicate.
# Simply update the variables at the beginning of the script to tune what content will be pulled including:
#
# Foreman version, Katello version, server distributions, client distributions
#
# At this time, the script is designed to pull packages for a single architecture.
#
# The script is designed to use a local Linux filesystem for the destination of the reposync command and then copy the files
# to another location for dissemination.  This is due to a file syncing issue when running reposync against a non-Linux
# filesystem, e.g. a shared folder in VirtualBox that points to a Windows folder using the vboxsf filesystem.
#
# If you are using this script within a pure Linux environment, then you can comment out the call to the copy_repos_to_share function.
# You may also update the value of the REPODIR variable to define a final destination for a point in time copy of all replicated files.
#
# Use this script at your own risk, but it has been tested with no issues at this time.


TEMPDIR=/srv/repos
REPODIR=/software/Linux/Foreman/repos

FOREMAN_HOST=yum.theforeman.org
FOREMAN_VERSION=3.11
KATELLO_VERSION=4.13
ARCH=x86_64
SRV_DISTROS="el8 el9"
CLIENT_DISTROS="el7 el8 el9"

function get_server_repos () {
	for DIST in $SRV_DISTROS; do	
		# Add temporary repository definitions
		dnf -q install -y \
		https://${FOREMAN_HOST}/releases/${FOREMAN_VERSION}/${DIST}/${ARCH}/foreman-release.rpm \
		https://${FOREMAN_HOST}/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH}/katello-repos-latest.rpm

		# Determine required version of Candlepin from the installed repository definitions
		CANDLEPIN_VERSION=$(dnf -v --disablerepo=* --enablerepo=candlepin repolist 2>/dev/null | grep "^Repo-baseurl" | grep -P -o "\d+[.]\d+")
		[ $? -ne 0 ] && (echo "Error occurred obtaining Candlepin version.  Exiting..."; exit -1)
		
		# Determine required version of Pulpcore from the installed repository definitions
		PULPCORE_VERSION=$(dnf -v --disablerepo=* --enablerepo=pulpcore repolist 2>/dev/null | grep "^Repo-baseurl" | grep -P -o "\d+[.]\d+")
		[ $? -ne 0 ] && (echo "Error occurred obtaining Pulpcore version.  Exiting..."; exit -1)

		# Create local copies of the repositories needed for an offline installation of Foremane with Katello
		dnf reposync --remote-time --delete --norepopath --download-metadata --downloadcomps --download-path ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION}/${DIST}/${ARCH} --repo foreman
		dnf reposync --remote-time --delete --norepopath --download-metadata --downloadcomps --download-path ${TEMPDIR}/Foreman/plugins/${FOREMAN_VERSION}/${DIST}/${ARCH} --repo foreman-plugins
		dnf reposync --remote-time --delete --norepopath --download-metadata --downloadcomps --download-path ${TEMPDIR}/Foreman/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH} --repo katello
		dnf reposync --remote-time --delete --norepopath --download-metadata --downloadcomps --download-path ${TEMPDIR}/Foreman/candlepin/${CANDLEPIN_VERSION}/${DIST}/${ARCH} --repo candlepin
		dnf reposync --remote-time --delete --norepopath --download-metadata --downloadcomps --download-path ${TEMPDIR}/Foreman/pulpcore/${PULPCORE_VERSION}/${DIST}/${ARCH} --repo pulpcore

		# Reposync doesn't pull content not defined in the repomd.xml
		# Therefore, manually pull the symbolically linked latest rpm files for Foreman and Katello
		# as well as the manually provided modules.yaml files and place them into the appropriate locations.
		curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION}/${DIST}/${ARCH} https://${FOREMAN_HOST}/releases/${FOREMAN_VERSION}/${DIST}/${ARCH}/foreman-release.rpm
		curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION}/${DIST}/${ARCH}/repodata https://${FOREMAN_HOST}/releases/${FOREMAN_VERSION}/${DIST}/${ARCH}/repodata/modules.yaml
		curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH} https://${FOREMAN_HOST}/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH}/katello-repos-latest.rpm
		curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH}/repodata https://${FOREMAN_HOST}/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH}/repodata/modules.yaml

		# Fix directory timestamps to retain upstream modification dates relative to last repomd.xml update.
		find ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION} -type d -exec touch -r ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION}/${DIST}/${ARCH}/repodata/repomd.xml {} \;
		find ${TEMPDIR}/Foreman/plugins/${FOREMAN_VERSION} -type d -exec touch -r ${TEMPDIR}/Foreman/plugins/${FOREMAN_VERSION}/${DIST}/${ARCH}/repodata/repomd.xml {} \;
		find ${TEMPDIR}/Foreman/katello/${KATELLO_VERSION} -type d -exec touch -r ${TEMPDIR}/Foreman/katello/${KATELLO_VERSION}/katello/${DIST}/${ARCH}/repodata/repomd.xml {} \;
		find ${TEMPDIR}/Foreman/candlepin/${CANDLEPIN_VERSION} -type d -exec touch -r ${TEMPDIR}/Foreman/candlepin/${CANDLEPIN_VERSION}/${DIST}/${ARCH}/repodata/repomd.xml {} \;
		find ${TEMPDIR}/Foreman/pulpcore/${PULPCORE_VERSION} -type d -exec touch -r ${TEMPDIR}/Foreman/pulpcore/${PULPCORE_VERSION}/${DIST}/${ARCH}/repodata/repomd.xml {} \;

		# Remove temporary repository definitions
		dnf -q remove -y foreman-release katello-repos
	done

	# Retrieve GPG keys for the current Foreman release
	curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION} https://${FOREMAN_HOST}/releases/${FOREMAN_VERSION}/RPM-GPG-KEY-foreman
	curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/candlepin/${CANDLEPIN_VERSION} https://${FOREMAN_HOST}/candlepin/${CANDLEPIN_VERSION}/RPM-GPG-KEY-candlepin
	curl -s --remote-time --remote-name --output-dir ${TEMPDIR}/Foreman/pulpcore/${PULPCORE_VERSION} https://${FOREMAN_HOST}/pulpcore/${PULPCORE_VERSION}/GPG-RPM-KEY-pulpcore
}

function get_client_repos () {
	for DIST in $CLIENT_DISTROS; do
		# Add temporary repository definitions
		dnf -q install -y \
		https://${FOREMAN_HOST}/client/${FOREMAN_VERSION}/${DIST}/${ARCH}/foreman-client-release.rpm

		# Create local copies of the repositories needed for an offline installation of the Foreman client
		dnf reposync --remote-time --delete --norepopath --download-metadata --downloadcomps --download-path ${TEMPDIR}/Foreman/client/${FOREMAN_VERSION}/${DIST}/${ARCH} --repo foreman-client
		
		# Fix directory timestamps to retain upstream modification dates relative to last repomd.xml update.
		find ${TEMPDIR}/Foreman/client/${FOREMAN_VERSION} -type d -exec touch -r ${TEMPDIR}/Foreman/client/${FOREMAN_VERSION}/${DIST}/${ARCH}/repodata/repomd.xml {} \;
		
		# Remove temporary repository definitions
		dnf -q remove -y foreman-client-release
	done
}

function copy_repos_to_share () {
	[ ! -e ${REPODIR}/releases/${FOREMAN_VERSION} ] && mkdir -p ${REPODIR}/releases/${FOREMAN_VERSION}
	[ ! -e ${REPODIR}/plugins/${FOREMAN_VERSION} ] && mkdir -p ${REPODIR}/plugins/${FOREMAN_VERSION}
	[ ! -e ${REPODIR}/katello/${KATELLO_VERSION} ] && mkdir -p ${REPODIR}/katello/${KATELLO_VERSION}
	[ ! -e ${REPODIR}/candlepin/${CANDLEPIN_VERSION} ] && mkdir -p ${REPODIR}/candlepin/${CANDLEPIN_VERSION}
	[ ! -e ${REPODIR}/pulpcore/${PULPCORE_VERSION} ] && mkdir -p ${REPODIR}/pulpcore/${PULPCORE_VERSION}
	[ ! -e ${REPODIR}/client/${FOREMAN_VERSION} ] && mkdir -p ${REPODIR}/client/${FOREMAN_VERSION}
	
	printf "\nCopying releases repository to share...\n"
	rsync -av ${TEMPDIR}/Foreman/releases/${FOREMAN_VERSION}/ ${REPODIR}/releases/${FOREMAN_VERSION}
	
	printf "\nCopying plugins repository to share...\n"
	rsync -av ${TEMPDIR}/Foreman/plugins/${FOREMAN_VERSION}/ ${REPODIR}/plugins/${FOREMAN_VERSION}
	
	printf "\nCopying katello repository to share...\n"
	rsync -av ${TEMPDIR}/Foreman/katello/${KATELLO_VERSION}/ ${REPODIR}/katello/${KATELLO_VERSION}
	
	printf "\nCopying candlepin repository to share...\n"
	rsync -av ${TEMPDIR}/Foreman/candlepin/${CANDLEPIN_VERSION}/ ${REPODIR}/candlepin/${CANDLEPIN_VERSION}
	
	printf "\nCopying pulpcore repository to share...\n"
	rsync -av ${TEMPDIR}/Foreman/pulpcore/${PULPCORE_VERSION}/ ${REPODIR}/pulpcore/${PULPCORE_VERSION}
	
	printf "\nCopying client repository to share...\n"
	rsync -av ${TEMPDIR}/Foreman/client/${FOREMAN_VERSION}/ ${REPODIR}/client/${FOREMAN_VERSION}
}

get_server_repos
get_client_repos
copy_repos_to_share
