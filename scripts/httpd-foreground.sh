#!/bin/sh
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

# Ensure that we have a server name defined
if [ "$HTTPD_SERVER_NAME" = "" ]; then
  HTTPD_SERVER_NAME=${HOSTNAME}; export HTTPD_SERVER_NAME
fi

if [ "$HTTPD_SERVER_ADMIN" = "" ]; then
  HTTPD_SERVER_ADMIN=admin@${HTTPD_SERVER_NAME}; export HTTPD_SERVER_ADMIN
fi

if [ ! -f /svn/config/svn-users ] && [ "$SVN_USER" != "" ] && [ "$SVN_PASSWORD" != "" ]; then
  htpasswd -cbB /svn/config/svn-users $SVN_USER $SVN_PASSWORD
fi

if [ "$SVN_REPO_NAME" != "" ] && [ ! -d /svn/repos/$SVN_REPO_NAME ]; then
  svnadmin create /svn/repos/$SVN_REPO_NAME
  chown -R httpd:httpd /svn/repos/$SVN_REPO_NAME
fi

if [ "$HTTPD_SSL" = "" ]
then
  exec httpd -DFOREGROUND
else
  exec httpd -DFOREGROUND -DSSL
fi
