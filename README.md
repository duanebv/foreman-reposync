# foreman-reposync
Download Foreman repositories for offline installation.

This script will download all Foreman repositories needed to install Foreman with Katello in an offline environment.

This script expects there to be no current repositories for Foreman defined on the downloading host.
The repositories will be installed and removed during the download process for each distribution defined.

The script is designed to accept the list of server distributions and client distributions you wish to replicate.
Simply update the variables at the beginning of the script to tune what content will be pulled including:

Foreman version, Katello version, server distributions, client distributions

At this time, the script is designed to pull packages for a single architecture.

The script is designed to use a local Linux filesystem for the destination of the reposync command and then copy the files
to another location for dissemination.  This is due to a file syncing issue when running reposync against a non-Linux
filesystem, e.g. a shared folder in VirtualBox that points to a Windows folder using the vboxsf filesystem.

If you are using this script within a pure Linux environment, then you can comment out the call to the copy_repos_to_share function.
You may also update the value of the REPODIR variable to define a final destination for a point in time copy of all replicated files.

Use this script at your own risk, but it has been tested with no issues at this time.
