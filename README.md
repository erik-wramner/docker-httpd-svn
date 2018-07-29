# Apache httpd with Subversion

This image provides Apache configured for use as a Subversion server. The docker file has been copied from [docker-library/httpd](https://github.com/docker-library/httpd)
and modified to build Subversion as well as Apache.

## Usage


## Notes

* It is important to set the ServerName option to the real external host name, as Subversion (or rather DAV) needs it for the copy command.
  Set HTTPD_SERVER_NAME when using the default configuration or be sure to set it manually. If not defined the container's host name will
  be used and that is probably wrong.
* It is a very good idea to require SSL/TLS or alternatively to use a web front with SSL. The default configuration assumes a web front.
